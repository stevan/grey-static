
use v5.42;
use experimental qw[ class ];

use grey::static qw[ concurrency::util ];
use Flow::Subscription;
use Flow::Subscriber;

# Merges multiple publishers - emits from any source as soon as available
class Flow::Publisher::Merge :isa(Flow::Publisher) {
    field $sources :param;  # Arrayref of publishers

    field @source_subscriptions;
    field $completed_count = 0;
    field $total_sources;
    field $downstream_subscription;

    ADJUST {
        $total_sources = scalar @$sources;
    }

    method subscribe ($subscriber) {
        # Create our subscription to downstream
        $downstream_subscription = Flow::Subscription->new(
            publisher  => $self,
            subscriber => $subscriber,
            executor   => $self->executor,
        );

        # Subscribe to each source publisher
        for my $source (@$sources) {
            # Create custom subscriber for this source
            my $source_subscriber = Flow::Subscriber::MergeSource->new(
                merge_subscription => $downstream_subscription,
                completed_count_ref => \$completed_count,
                total_sources => $total_sources,
            );

            $source->subscribe($source_subscriber);
            push @source_subscriptions, $source_subscriber;
        }

        $self->executor->next_tick(sub {
            $subscriber->on_subscribe($downstream_subscription);
        });
    }
}

# Helper subscriber class for merge sources
class Flow::Subscriber::MergeSource {
    field $merge_subscription :param;
    field $completed_count_ref :param;
    field $total_sources :param;
    field $request_size = 1;

    field $subscription;

    method on_subscribe ($s) {
        $subscription = $s;
        # Chain source executor to merge executor so they run together
        $subscription->executor->set_next($merge_subscription->executor);
        $subscription->request($request_size);
    }

    method on_unsubscribe {
        $subscription = undef;
    }

    method on_next ($e) {
        # Forward to merge subscription
        $merge_subscription->offer($e);

        # Request more from this source
        $subscription->request($request_size) if $subscription;
    }

    method on_completed {
        # Track completion
        ${$completed_count_ref}++;

        # Complete merge when all sources complete
        if (${$completed_count_ref} >= $total_sources) {
            $merge_subscription->on_completed;
        }

        $subscription = undef;
    }

    method on_error ($e) {
        # Propagate error
        $merge_subscription->on_error($e);
        $subscription = undef;
    }
}

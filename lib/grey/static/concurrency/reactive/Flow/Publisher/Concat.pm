
use v5.42;
use experimental qw[ class ];

use grey::static qw[ concurrency::util ];
use Flow::Subscription;
use Flow::Subscriber;

# Concatenates multiple publishers - emits first fully, then second, etc.
class Flow::Publisher::Concat :isa(Flow::Publisher) {
    field $sources :param;  # Arrayref of publishers

    field $current_index = 0;
    field $current_subscriber;
    field $downstream_subscription;

    method subscribe ($subscriber) {
        # Create our subscription to downstream
        $downstream_subscription = Flow::Subscription->new(
            publisher  => $self,
            subscriber => $subscriber,
            executor   => $self->executor,
        );

        # Subscribe to first source
        $self->subscribe_to_current_source();

        $self->executor->next_tick(sub {
            $subscriber->on_subscribe($downstream_subscription);
        });
    }

    method subscribe_to_current_source {
        return unless $current_index < scalar @$sources;

        my $source = $sources->[$current_index];

        # Create subscriber for this source
        $current_subscriber = Flow::Subscriber::ConcatSource->new(
            concat => $self,
            downstream_subscription => $downstream_subscription,
        );

        $source->subscribe($current_subscriber);
    }

    method on_source_completed {
        # Move to next source
        $current_index++;

        if ($current_index < scalar @$sources) {
            # Subscribe to next source
            $self->subscribe_to_current_source();
        } else {
            # All sources complete
            $downstream_subscription->on_completed if $downstream_subscription;
        }
    }
}

# Helper subscriber class for concat sources
class Flow::Subscriber::ConcatSource {
    field $concat :param;
    field $downstream_subscription :param;
    field $request_size = 1;

    field $subscription;

    method on_subscribe ($s) {
        $subscription = $s;
        # Chain source executor to concat executor so they run together
        $subscription->executor->set_next($downstream_subscription->executor);
        $subscription->request($request_size);
    }

    method on_unsubscribe {
        $subscription = undef;
    }

    method on_next ($e) {
        # Forward to downstream
        $downstream_subscription->offer($e);

        # Request more from current source
        $subscription->request($request_size) if $subscription;
    }

    method on_completed {
        # Notify concat to move to next source
        $concat->on_source_completed();
        $subscription = undef;
    }

    method on_error ($e) {
        # Propagate error
        $downstream_subscription->on_error($e);
        $subscription = undef;
    }
}

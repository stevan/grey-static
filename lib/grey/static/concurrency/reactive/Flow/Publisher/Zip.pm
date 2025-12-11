
use v5.42;
use experimental qw[ class ];

use grey::static qw[ concurrency::util ];
use Flow::Subscription;
use Flow::Subscriber;

# Zips multiple publishers - pairs up corresponding elements
class Flow::Publisher::Zip :isa(Flow::Publisher) {
    field $sources :param;   # Arrayref of publishers
    field $combiner :param;  # BiFunction to combine elements

    field @buffers;          # One buffer per source
    field @source_subscribers;
    field $downstream_subscription;
    field $completed_count = 0;
    field $any_completed = 0;
    field $downstream_completed = 0;

    ADJUST {
        # Initialize buffers
        @buffers = map { [] } @$sources;
    }

    method subscribe ($subscriber) {
        # Create our subscription to downstream
        $downstream_subscription = Flow::Subscription->new(
            publisher  => $self,
            subscriber => $subscriber,
            executor   => $self->executor,
        );

        # Subscribe to each source
        my $source_index = 0;
        for my $source (@$sources) {
            my $idx = $source_index++;  # Capture for closure

            my $source_subscriber = Flow::Subscriber::ZipSource->new(
                zip => $self,
                source_index => $idx,
                downstream_subscription => $downstream_subscription,
            );

            $source->subscribe($source_subscriber);
            push @source_subscribers, $source_subscriber;
        }

        $self->executor->next_tick(sub {
            $subscriber->on_subscribe($downstream_subscription);
        });
    }

    method on_source_item ($source_index, $item) {
        # Buffer the item
        push @{$buffers[$source_index]}, $item;

        # Check if we can emit a combined tuple
        $self->try_emit();
    }

    method on_source_completed ($source_index) {
        $completed_count++;
        $any_completed = 1;

        # Try to emit any remaining pairs from buffered values
        $self->try_emit();

        # Check if we should complete (after all emissions are done)
        $self->check_for_completion();
    }

    method try_emit {
        # Check if all buffers have at least one element
        my $can_emit = 1;
        for my $buffer (@buffers) {
            if (@$buffer == 0) {
                $can_emit = 0;
                last;
            }
        }

        return unless $can_emit;

        # Take first element from each buffer
        my @items = map { shift @$_ } @buffers;

        # Combine elements (for 2 sources, use BiFunction)
        my $combined;
        if (@items == 2) {
            $combined = $combiner->apply($items[0], $items[1]);
        } else {
            # For N sources, pass all items as array
            # (User's combiner should handle array)
            $combined = \@items;
        }

        # Emit combined result
        if ($downstream_subscription) {
            $downstream_subscription->offer($combined);
        }

        # Check if we can emit more
        $self->try_emit();
    }

    method check_for_completion {
        # Don't complete if no source has finished yet
        return unless $any_completed;

        # Don't complete if we've already completed
        return if $downstream_completed;

        # Check if any buffer still has items (can still form pairs)
        for my $buffer (@buffers) {
            return if @$buffer > 0;
        }

        # All buffers are empty and at least one source completed
        # Safe to complete now - all possible pairs have been emitted
        $downstream_completed = 1;

        # Use double next_tick to ensure all pending offer/drain cycles complete
        # Tick 1: Allow any pending drain_buffer to run
        # Tick 2: Allow any pending on_next to run
        # Tick 3: Then signal completion
        $self->executor->next_tick(sub {
            $self->executor->next_tick(sub {
                $downstream_subscription->on_completed if $downstream_subscription;
            });
        });
    }
}

# Helper subscriber class for zip sources
class Flow::Subscriber::ZipSource {
    field $zip :param;
    field $source_index :param;
    field $downstream_subscription :param;
    field $request_size = 1;

    field $subscription;

    method on_subscribe ($s) {
        $subscription = $s;
        # Chain source executor to zip executor so they run together
        $subscription->executor->set_next($downstream_subscription->executor);
        $subscription->request($request_size);
    }

    method on_unsubscribe {
        $subscription = undef;
    }

    method on_next ($e) {
        # Forward to zip for buffering
        $zip->on_source_item($source_index, $e);

        # Request more from this source
        $subscription->request($request_size) if $subscription;
    }

    method on_completed {
        # Notify zip that this source is done
        $zip->on_source_completed($source_index);
        $subscription = undef;
    }

    method on_error ($e) {
        # Propagate error
        $downstream_subscription->on_error($e);
        $subscription = undef;
    }
}

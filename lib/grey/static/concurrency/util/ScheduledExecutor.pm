
use v5.42;
use experimental qw[ class ];

use grey::static qw[ time::wheel ];

class ScheduledExecutor :isa(Executor) {
    field $wheel = Timer::Wheel->new;
    field $current_time = 0;
    field $next_timer_id = 1;

    # Schedule callback with delay
    method schedule_delayed($callback, $delay_ticks) {
        my $timer_id = $next_timer_id++;
        # Ensure delay is at least 1 to avoid scheduling at current time
        my $actual_delay = $delay_ticks < 1 ? 1 : $delay_ticks;
        my $expiry = $current_time + $actual_delay;

        my $timer = Timer->new(
            id     => $timer_id,
            expiry => $expiry,
            event  => sub { $self->next_tick($callback) }
        );

        $wheel->add_timer($timer);
        return $timer_id;
    }

    # Cancel scheduled callback
    method cancel_scheduled($timer_id) {
        return $wheel->cancel_timer($timer_id);
    }

    # Get current time
    method current_time { $current_time }

    # Get timer wheel (for inspection/debugging)
    method wheel { $wheel }

    # Override run() to advance time
    method run {
        while (!$self->is_done || $wheel->timer_count > 0) {
            # Find next timer
            my $next_timeout = $wheel->find_next_timeout;

            if (defined $next_timeout && $next_timeout > $current_time) {
                # Advance to next timer
                my $delta = $next_timeout - $current_time;
                $wheel->advance_by($delta);
                $current_time = $next_timeout;
            }

            # Run executor tick (processes callbacks that timers added)
            $self->tick;

            # If nothing to do and no timers, we're done
            last if $self->is_done && $wheel->timer_count == 0;
        }
    }
}

1;


use v5.42;
use experimental qw[ class ];

# Simple queue-based scheduled executor
# Uses a sorted list of timers for efficient scheduling
class ScheduledExecutor :isa(Executor) {
    field $current_time = 0;
    field $next_timer_id = 1;
    field @timers;  # Array of [expiry, id, callback, cancelled]

    # Schedule callback with delay
    method schedule_delayed($callback, $delay_ticks) {
        my $timer_id = $next_timer_id++;
        my $expiry = $current_time + ($delay_ticks < 1 ? 1 : $delay_ticks);

        # Insert timer in sorted order
        my $timer = [$expiry, $timer_id, $callback, 0];  # [expiry, id, callback, cancelled]

        if (@timers == 0) {
            # Fast path: first timer
            push @timers, $timer;
        }
        elsif ($timers[-1][0] <= $expiry) {
            # Fast path: append to end (common case)
            push @timers, $timer;
        }
        else {
            # Need to insert in sorted position
            my $insert_pos = 0;
            for my $i (0..$#timers) {
                if ($timers[$i][0] > $expiry) {
                    $insert_pos = $i;
                    last;
                }
                $insert_pos = $i + 1;
            }
            splice @timers, $insert_pos, 0, $timer;
        }

        return $timer_id;
    }

    # Cancel scheduled callback
    method cancel_scheduled($timer_id) {
        # Mark as cancelled (lazy deletion)
        for my $timer (@timers) {
            if ($timer->[1] == $timer_id) {
                $timer->[3] = 1;  # Set cancelled flag
                return 1;
            }
        }
        return 0;
    }

    # Get current time
    method current_time { $current_time }

    # Find next timer expiry (skip cancelled ones)
    method _find_next_expiry {
        # Clean up cancelled timers from front
        while (@timers && $timers[0][3]) {
            shift @timers;
        }

        return @timers ? $timers[0][0] : undef;
    }

    # Get all timers that should fire now
    method _get_pending_timers {
        my @pending;

        while (@timers && $timers[0][0] <= $current_time) {
            my $timer = shift @timers;
            push @pending, $timer unless $timer->[3];  # Skip cancelled
        }

        return @pending;
    }

    # Override run() to advance time
    method run {
        while (!$self->is_done || @timers) {
            if ($ENV{DEBUG_EXECUTOR}) {
                say "[executor] Loop: time=$current_time, is_done=", $self->is_done, ", timer_count=", scalar(@timers);
            }

            # Process any queued callbacks first before advancing time
            if (!$self->is_done) {
                say "[executor] Processing tick" if $ENV{DEBUG_EXECUTOR};
                $self->tick;
                next;
            }

            # No queued callbacks - check if we should advance time
            my $next_expiry = $self->_find_next_expiry;
            say "[executor] Next expiry: ", (defined $next_expiry ? $next_expiry : "undef") if $ENV{DEBUG_EXECUTOR};

            if (defined $next_expiry && $next_expiry > $current_time) {
                # Advance to next timer
                say "[executor] Advancing from $current_time to $next_expiry" if $ENV{DEBUG_EXECUTOR};
                $current_time = $next_expiry;

                # Fire all timers at this time
                my @pending = $self->_get_pending_timers;
                for my $timer (@pending) {
                    $timer->[2]->();  # Execute callback (index 2)
                }
                next;
            }

            # No queued callbacks and no timers - we're done
            if ($self->is_done && !@timers) {
                say "[executor] Done - no callbacks and no timers" if $ENV{DEBUG_EXECUTOR};
                last;
            }

            # Safety: shouldn't reach here
            say "[executor] SAFETY EXIT" if $ENV{DEBUG_EXECUTOR};
            last;
        }
    }

    # For debugging
    method timer_count { scalar @timers }
}

1;

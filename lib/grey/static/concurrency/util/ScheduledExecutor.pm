
use v5.42;
use experimental qw[ class ];

use Time::HiRes ();

# Real-time executor with millisecond-precision scheduling
# Based on Yakt::System::Timers
class ScheduledExecutor :isa(Executor) {
    use constant TIMER_PRECISION_DECIMAL => 0.001;
    use constant TIMER_PRECISION_INT     => 1000;

    field $time;
    field $next_timer_id = 1;
    field @timers;  # Array of [end_time, id, callback, cancelled]

    ADJUST {
        # Initialize time to current monotonic clock
        $self->now;
    }

    # Get current monotonic time
    method now {
        state $MONOTONIC = Time::HiRes::CLOCK_MONOTONIC();
        $time = Time::HiRes::clock_gettime($MONOTONIC);
        return $time;
    }

    # Sleep for duration in seconds
    method wait ($duration) {
        Time::HiRes::sleep($duration) if $duration > 0;
    }

    # Check if there are active timers
    method has_active_timers {
        return !! @timers;
    }

    # Calculate end time for a timer given delay in milliseconds
    method _calculate_end_time ($delay_ms) {
        my $now      = $self->now;
        my $end_time = $now + ($delay_ms / 1000.0);  # Convert ms to seconds
        # Round to millisecond precision
        $end_time = int($end_time * TIMER_PRECISION_INT) * TIMER_PRECISION_DECIMAL;
        return $end_time;
    }

    # Schedule callback with delay in milliseconds
    method schedule_delayed ($callback, $delay_ms) {
        my $timer_id = $next_timer_id++;
        my $end_time = $self->_calculate_end_time($delay_ms < 1 ? 1 : $delay_ms);

        my $timer = [$end_time, $timer_id, $callback, 0];  # [end_time, id, callback, cancelled]

        if (@timers == 0) {
            # Fast path: first timer
            push @timers, $timer;
        }
        elsif ($timers[-1][0] == $end_time) {
            # Same time as last timer - append
            push @timers, $timer;
        }
        elsif ($timers[-1][0] < $end_time) {
            # Fast path: append to end (common case)
            push @timers, $timer;
        }
        elsif ($timers[-1][0] > $end_time) {
            # Need to sort - insert in correct position
            @timers = sort { $a->[0] <=> $b->[0] } @timers, $timer;
        }

        return $timer_id;
    }

    # Cancel scheduled callback
    method cancel_scheduled ($timer_id) {
        # Mark as cancelled (lazy deletion)
        for my $timer (@timers) {
            if ($timer->[1] == $timer_id) {
                $timer->[3] = 1;  # Set cancelled flag
                return 1;
            }
        }
        return 0;
    }

    # Get next timer, cleaning up cancelled ones
    method _get_next_timer {
        while (my $next_timer = $timers[0]) {
            # If we have timers
            if (@{$next_timer}) {
                # Check if all are cancelled
                my @active = grep { !$_->[3] } @timers;
                if (@active == 0) {
                    # All cancelled, clear and continue
                    shift @timers;
                    next;
                }
                else {
                    last;
                }
            }
            else {
                shift @timers;
            }
        }

        return $timers[0];
    }

    # Calculate how long to wait for next timer
    method should_wait {
        my $wait = 0;

        if (my $next_timer = $self->_get_next_timer) {
            $wait = $next_timer->[0] - $time;
        }

        # Do not wait for negative values
        if ($wait < TIMER_PRECISION_DECIMAL) {
            $wait = 0;
        }

        return $wait;
    }

    # Get all pending timers (ready to fire)
    method pending_timers {
        my $now = $self->now;

        my @pending;
        while (@timers && $timers[0][0] <= $now) {
            push @pending, shift @timers;
        }

        return @pending;
    }

    # Execute a timer's callback
    method _execute_timer ($timer) {
        return if $timer->[3];  # Skip cancelled

        my $callback = $timer->[2];
        eval {
            $callback->();
        };
        if ($@) {
            chomp(my $error = $@);
            warn "Timer callback failed: $error\n";
        }
    }

    # Process pending timers
    method tick {
        return unless @timers;

        my @timers_to_run = $self->pending_timers;
        return unless @timers_to_run;

        foreach my $timer (@timers_to_run) {
            $self->_execute_timer($timer);
        }
    }

    # Override run() to use real time with waiting
    method run {
        while (!$self->is_done || @timers) {
            if ($ENV{DEBUG_EXECUTOR}) {
                say "[executor] Loop: is_done=", $self->is_done, ", timer_count=", scalar(@timers);
            }

            # Process any queued callbacks first before waiting
            if (!$self->is_done) {
                say "[executor] Processing tick" if $ENV{DEBUG_EXECUTOR};
                $self->SUPER::tick;  # Call Executor's tick
                next;
            }

            # No queued callbacks - check if we should wait for timers
            my $wait_duration = $self->should_wait;

            if ($wait_duration > 0) {
                say "[executor] Waiting ${wait_duration}s for next timer" if $ENV{DEBUG_EXECUTOR};
                $self->wait($wait_duration);
            }

            # Process pending timers
            $self->tick;

            # No queued callbacks and no timers - we're done
            if ($self->is_done && !@timers) {
                say "[executor] Done - no callbacks and no timers" if $ENV{DEBUG_EXECUTOR};
                last;
            }
        }
    }

    # For debugging
    method timer_count { scalar @timers }
    method current_time { $time * 1000 }  # Return milliseconds
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

ScheduledExecutor - Real-time callback scheduler with millisecond precision

=head1 SYNOPSIS

    use grey::static qw[ concurrency::util ];

    my $executor = ScheduledExecutor->new;

    # Schedule callbacks with delays in milliseconds
    $executor->schedule_delayed(sub { say "After 100ms" }, 100);
    $executor->schedule_delayed(sub { say "After 50ms" }, 50);
    $executor->schedule_delayed(sub { say "After 150ms" }, 150);

    # Run the executor - uses real time with actual waiting
    $executor->run;
    # Output (in order, with real delays):
    # After 50ms
    # After 100ms
    # After 150ms

    # Cancel scheduled callbacks
    my $timer_id = $executor->schedule_delayed(sub { say "Won't run" }, 1000);
    $executor->cancel_scheduled($timer_id);

    # Mix delayed and immediate callbacks
    $executor->next_tick(sub { say "Immediate" });
    $executor->schedule_delayed(sub { say "Delayed" }, 100);
    $executor->run;

=head1 DESCRIPTION

C<ScheduledExecutor> extends L<Executor> to provide real-time callback scheduling
with millisecond precision. It uses C<Time::HiRes::CLOCK_MONOTONIC> for steady,
non-adjustable time measurements and actually sleeps/waits when running.

Key features:

=over 4

=item *

B<Real-time scheduling> - Uses actual wall-clock time, not simulated ticks

=item *

B<Millisecond precision> - Delays specified in milliseconds

=item *

B<Monotonic clock> - Uses CLOCK_MONOTONIC for steady time (unaffected by system time changes)

=item *

B<Efficient waiting> - Sleeps between timer events to avoid busy-waiting

=item *

B<Lazy cancellation> - Cancelled timers marked but not removed immediately

=item *

B<Executor integration> - Inherits all Executor functionality (next_tick, chaining, etc.)

=back

=head1 TIME MODEL

ScheduledExecutor operates on B<real-world time>:

=over 4

=item *

Time comes from C<Time::HiRes::CLOCK_MONOTONIC> (monotonic clock)

=item *

Delays are measured in milliseconds (converted to seconds internally)

=item *

The executor sleeps/waits for real time between timer events

=item *

Time precision is rounded to milliseconds (0.001 seconds)

=item *

Multiple timers at the same time execute in scheduling order

=back

=head1 COMPARISON WITH SIMULATEDEXECUTOR

=over 4

=item B<ScheduledExecutor>

Real-time execution with actual sleeping/waiting. Use for production code,
real-world timing, and wall-clock operations.

=item B<SimulatedExecutor>

Simulated time that jumps instantly to next event. Use for testing, deterministic
behavior, and fast-running tests.

=back

=head1 CONSTRUCTOR

=head2 new

    my $executor = ScheduledExecutor->new;
    my $executor = ScheduledExecutor->new(next => $other_executor);

Creates a new ScheduledExecutor.

B<Parameters:>

=over 4

=item C<next> (optional)

Another Executor to chain to. See L<Executor> for details on executor chaining.

=back

=head1 METHODS

=head2 Scheduling Methods

=over 4

=item C<< schedule_delayed($callback, $delay_ms) >>

Schedules a callback to execute after the specified delay in milliseconds.

B<Parameters:>

=over 4

=item C<$callback>

Code reference to execute when the timer fires.

=item C<$delay_ms>

Number of milliseconds to wait before executing. Must be >= 0.
If < 1, treated as 1.

=back

B<Returns:> A unique timer ID that can be used with C<cancel_scheduled()>.

B<Example:>

    my $id = $executor->schedule_delayed(sub {
        say "Executed after 500ms";
    }, 500);

=item C<< cancel_scheduled($timer_id) >>

Cancels a previously scheduled callback.

B<Parameters:>

=over 4

=item C<$timer_id>

The ID returned by C<schedule_delayed()>.

=back

B<Returns:> 1 if the timer was found and cancelled, 0 if not found.

B<Note:> Cancelled timers are marked but not immediately removed from the internal
queue. They are cleaned up lazily during normal timer processing.

=back

=head2 Time Methods

=over 4

=item C<now()>

Returns the current monotonic time in seconds (updates internal time).

=item C<current_time()>

Returns the cached current time in seconds (does not update).

=item C<wait($duration)>

Sleeps for the specified duration in seconds.

=item C<should_wait()>

Returns how long (in seconds) to wait before the next timer fires.

=item C<has_active_timers()>

Returns true if there are any scheduled timers.

=item C<timer_count()>

Returns the number of scheduled timers (including cancelled but not yet cleaned up).

=back

=head2 Execution Methods

All methods from L<Executor> are available:

=over 4

=item C<next_tick($callback)>

Queue an immediate callback (inherited from Executor). These execute before
any waiting occurs.

=item C<run()>

Execute callbacks and wait for timers as needed. Overrides Executor's C<run()> to
implement real-time waiting logic.

The run loop:

1. Execute all queued C<next_tick> callbacks
2. If no queued callbacks, calculate wait time for next timer
3. Sleep for the calculated duration
4. Fire all timers that are ready
5. Repeat until no callbacks and no timers remain

=item C<tick()>

Execute one batch of pending timers without processing queued callbacks.

=item C<is_done()>

Returns true if no queued callbacks remain (inherited from Executor).

=back

=head1 USAGE PATTERNS

=head2 Simple Delayed Execution

    my $executor = ScheduledExecutor->new;

    $executor->schedule_delayed(sub {
        say "This runs after 100ms";
    }, 100);

    $executor->run;

=head2 Multiple Timers

    my $executor = ScheduledExecutor->new;

    $executor->schedule_delayed(sub { say "First" }, 50);
    $executor->schedule_delayed(sub { say "Second" }, 100);
    $executor->schedule_delayed(sub { say "Third" }, 150);

    $executor->run;
    # Prints in order with real delays: First, Second, Third

=head2 Cancellation

    my $executor = ScheduledExecutor->new;

    my $id1 = $executor->schedule_delayed(sub { say "Keeps" }, 100);
    my $id2 = $executor->schedule_delayed(sub { say "Cancelled" }, 200);

    $executor->cancel_scheduled($id2);
    $executor->run;
    # Only prints: Keeps

=head1 DEBUGGING

Set the C<DEBUG_EXECUTOR> environment variable to see detailed execution traces:

    DEBUG_EXECUTOR=1 perl script.pl

=head1 DEPENDENCIES

Requires L<Time::HiRes> for high-resolution timing.

=head1 SEE ALSO

=over 4

=item *

L<Executor> - Base class providing callback queuing and executor chaining

=item *

L<SimulatedExecutor> - Simulated-time variant for testing

=item *

L<Promise> - Async promise implementation with timeout/delay support

=item *

L<Stream> - Stream API with time-based operations

=item *

L<grey::static::concurrency::util> - Feature loader for concurrency utilities

=back

=head1 AUTHOR

grey::static

=cut


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

__END__

=pod

=encoding UTF-8

=head1 NAME

ScheduledExecutor - Time-based callback scheduler with Executor integration

=head1 SYNOPSIS

    use grey::static qw[ concurrency::util ];

    my $executor = ScheduledExecutor->new;

    # Schedule callbacks with delays
    $executor->schedule_delayed(sub { say "After 10 ticks" }, 10);
    $executor->schedule_delayed(sub { say "After 5 ticks" }, 5);
    $executor->schedule_delayed(sub { say "After 15 ticks" }, 15);

    # Run the executor - time advances automatically
    $executor->run;
    # Output (in order):
    # After 5 ticks
    # After 10 ticks
    # After 15 ticks

    # Cancel scheduled callbacks
    my $timer_id = $executor->schedule_delayed(sub { say "Won't run" }, 100);
    $executor->cancel_scheduled($timer_id);

    # Mix delayed and immediate callbacks
    $executor->next_tick(sub { say "Immediate" });
    $executor->schedule_delayed(sub { say "Delayed" }, 10);
    $executor->run;

=head1 DESCRIPTION

C<ScheduledExecutor> extends L<Executor> to provide time-based callback scheduling.
It manages a simulated timeline where callbacks can be scheduled to execute after
a specified delay (measured in "ticks").

Key features:

=over 4

=item *

B<Automatic time advancement> - Time moves forward to execute scheduled callbacks

=item *

B<Efficient queue-based scheduling> - Timers stored in sorted order for O(1) next-timer lookup

=item *

B<Lazy cancellation> - Cancelled timers marked but not removed immediately

=item *

B<Executor integration> - Inherits all Executor functionality (next_tick, chaining, etc.)

=item *

B<Immediate callbacks first> - Queued callbacks via C<next_tick()> execute before time advances

=back

=head1 ARCHITECTURE

ScheduledExecutor uses a simple queue-based timer system:

=over 4

=item *

Timers stored in an array sorted by expiry time

=item *

Insertion is O(n) worst case, but O(1) for common case (appending to end)

=item *

Next-timer lookup is O(1) (always at index 0)

=item *

Cancelled timers use lazy deletion (marked but cleaned up during traversal)

=back

This design is simple, efficient for typical workloads (<100 concurrent timers),
and avoids the complexity of hierarchical timer wheels or min-heaps.

=head1 TIME MODEL

ScheduledExecutor operates on a B<simulated timeline>:

=over 4

=item *

Time starts at 0 and only advances when needed to fire timers

=item *

Time is measured in abstract "ticks" (not real-world time)

=item *

Multiple timers at the same time execute in scheduling order

=item *

Immediate callbacks (C<next_tick()>) execute at the current time before advancing

=back

Example timeline:

    Time 0:  [next_tick callbacks execute]
    Time 5:  [timer A fires]
    Time 10: [timer B fires, timer C fires]
    Time 15: [timer D fires]

=head1 CONSTRUCTOR

=head2 new

    my $executor = ScheduledExecutor->new;
    my $executor = ScheduledExecutor->new(next => $other_executor);

Creates a new ScheduledExecutor starting at time 0.

B<Parameters:>

=over 4

=item C<next> (optional)

Another Executor to chain to. When this executor completes a tick with no remaining
callbacks, execution continues to the next executor. See L<Executor> for details on
executor chaining.

=back

=head1 METHODS

=head2 Scheduling Methods

=over 4

=item C<< schedule_delayed($callback, $delay_ticks) >>

Schedules a callback to execute after the specified delay.

B<Parameters:>

=over 4

=item C<$callback>

Code reference to execute when the timer fires.

=item C<$delay_ticks>

Number of ticks to wait before executing. Must be >= 0.
If 0, the callback fires at the current time (but after any pending C<next_tick> callbacks).
If < 1, treated as 1.

=back

B<Returns:> A unique timer ID that can be used with C<cancel_scheduled()>.

B<Example:>

    my $id = $executor->schedule_delayed(sub {
        say "Executed at time: " . $executor->current_time;
    }, 50);

=item C<< cancel_scheduled($timer_id) >>

Cancels a previously scheduled callback.

B<Parameters:>

=over 4

=item C<$timer_id>

The ID returned by C<schedule_delayed()>.

=back

B<Returns:> 1 if the timer was found and cancelled, 0 if not found (already fired or
already cancelled).

B<Example:>

    my $id = $executor->schedule_delayed(sub { say "Won't execute" }, 100);
    my $cancelled = $executor->cancel_scheduled($id);
    say "Cancelled: $cancelled";  # Prints "Cancelled: 1"

B<Note:> Cancelled timers are marked but not immediately removed from the internal
queue. They are cleaned up lazily during normal timer processing. This makes
cancellation O(n) but avoids disrupting the sorted timer queue.

=back

=head2 Time Methods

=over 4

=item C<current_time()>

Returns the current simulated time in ticks.

B<Example:>

    say "Current time: " . $executor->current_time;
    $executor->run;
    say "Final time: " . $executor->current_time;

=item C<timer_count()>

Returns the number of scheduled timers (including cancelled but not yet cleaned up).
Primarily useful for debugging and testing.

=back

=head2 Execution Methods

All methods from L<Executor> are available:

=over 4

=item C<next_tick($callback)>

Queue an immediate callback (inherited from Executor). These execute at the current
time before time advances.

=item C<run()>

Execute callbacks and advance time as needed. Overrides Executor's C<run()> to
implement time advancement logic.

The run loop:

1. Execute all queued C<next_tick> callbacks at current time

2. If no queued callbacks, advance to next timer's expiry time

3. Fire all timers at the new time

4. Repeat until no callbacks and no timers remain

=item C<tick()>

Execute one batch of queued callbacks without advancing time (inherited from Executor).

=item C<is_done()>

Returns true if no queued callbacks remain (inherited from Executor). Does not
consider scheduled timers.

=back

=head1 USAGE PATTERNS

=head2 Simple Delayed Execution

    my $executor = ScheduledExecutor->new;

    $executor->schedule_delayed(sub {
        say "This runs after 10 ticks";
    }, 10);

    $executor->run;

=head2 Multiple Timers

    my $executor = ScheduledExecutor->new;

    $executor->schedule_delayed(sub { say "First" }, 5);
    $executor->schedule_delayed(sub { say "Second" }, 10);
    $executor->schedule_delayed(sub { say "Third" }, 15);

    $executor->run;
    # Prints in order: First, Second, Third

=head2 Cancellation

    my $executor = ScheduledExecutor->new;

    my $id1 = $executor->schedule_delayed(sub { say "Keeps" }, 10);
    my $id2 = $executor->schedule_delayed(sub { say "Cancelled" }, 20);

    $executor->cancel_scheduled($id2);
    $executor->run;
    # Only prints: Keeps

=head2 Callbacks Scheduling More Callbacks

    my $executor = ScheduledExecutor->new;

    $executor->schedule_delayed(sub {
        say "First callback at time " . $executor->current_time;

        # Schedule another callback relative to current time
        $executor->schedule_delayed(sub {
            say "Nested callback at time " . $executor->current_time;
        }, 5);
    }, 10);

    $executor->run;
    # Prints:
    # First callback at time 10
    # Nested callback at time 15

=head2 Mixing Immediate and Delayed

    my $executor = ScheduledExecutor->new;

    $executor->next_tick(sub { say "Immediate 1" });
    $executor->schedule_delayed(sub { say "Delayed" }, 10);
    $executor->next_tick(sub { say "Immediate 2" });

    $executor->run;
    # Prints:
    # Immediate 1
    # Immediate 2
    # Delayed

=head1 INTEGRATION WITH OTHER FEATURES

=head2 With Promises

ScheduledExecutor enables time-based promise operations:

    my $executor = ScheduledExecutor->new;
    my $promise = Promise->new(executor => $executor);

    # Add timeout to promise
    $promise->timeout(50, $executor)
        ->then(
            sub ($value) { say "Success: $value" },
            sub ($error) { say "Error: $error" }
        );

    # Resolve before timeout
    $executor->schedule_delayed(sub { $promise->resolve("Done!") }, 30);
    $executor->run;  # Prints "Success: Done!"

=head2 With Streams

ScheduledExecutor enables time-based stream operations:

    my $executor = ScheduledExecutor->new;

    # Create stream with time-based operations
    Stream->of(1, 2, 3, 4, 5)
        ->throttle(10, $executor)  # Min 10 ticks between elements
        ->for_each(sub ($x) { say $x });

=head1 PERFORMANCE CHARACTERISTICS

=over 4

=item *

B<schedule_delayed()>: O(n) insertion (O(1) for common case of increasing delays)

=item *

B<cancel_scheduled()>: O(n) marking (lazy cleanup)

=item *

B<Finding next timer>: O(1) (front of sorted queue)

=item *

B<Time advancement>: O(1) per timer that fires

=item *

B<Memory>: O(n) where n = number of active timers

=back

This implementation is optimized for typical use cases with moderate numbers of
concurrent timers (<100). For workloads with many timers, a min-heap could provide
better insertion performance, but adds complexity.

=head1 DEBUGGING

Set the C<DEBUG_EXECUTOR> environment variable to see detailed execution traces:

    DEBUG_EXECUTOR=1 perl script.pl

Output includes:

=over 4

=item *

Loop iterations with current time

=item *

Callback queue status

=item *

Timer count

=item *

Time advancement events

=back

Example output:

    [executor] Loop: time=0, is_done=0, timer_count=2
    [executor] Processing tick
    [executor] Loop: time=0, is_done=1, timer_count=2
    [executor] Next expiry: 10
    [executor] Advancing from 0 to 10

=head1 LIMITATIONS

=over 4

=item *

Time is simulated, not real-world. ScheduledExecutor is designed for testing
and coordinated async operations, not wall-clock timing.

=item *

Timer insertion is O(n) worst case. For large numbers of concurrent timers
(>1000), consider a min-heap based implementation.

=item *

Cancelled timers remain in memory until cleaned up during timer processing.
This is typically not an issue but can accumulate if many timers are cancelled
without being fired.

=back

=head1 SEE ALSO

=over 4

=item *

L<Executor> - Base class providing callback queuing and executor chaining

=item *

L<Promise> - Async promise implementation with timeout/delay support

=item *

L<Stream> - Stream API with time-based operations (throttle, debounce, timeout)

=item *

L<grey::static::concurrency::util> - Feature loader for concurrency utilities

=back

=head1 AUTHOR

grey::static

=cut

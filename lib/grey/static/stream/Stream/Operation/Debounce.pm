
use v5.42;
use experimental qw[ class ];

class Stream::Operation::Debounce :isa(Stream::Operation::Node) {
    field $source :param;
    field $quiet_delay :param;
    field $executor :param;  # ScheduledExecutor

    field $buffered_value = undef;
    field $has_buffered = false;
    field $last_update_time = undef;
    field $next;
    field $next_ready = false;

    method next {
        $next_ready = false;
        return $next;
    }

    method has_next {
        # If we already have a value ready, return true
        return true if $next_ready;

        # Pull source elements while available
        while ($source->has_next) {
            $buffered_value = $source->next;
            $has_buffered = true;
            $last_update_time = $executor->current_time;
        }

        # Check if quiet period has elapsed
        if ($has_buffered && defined $last_update_time) {
            my $current_time = $executor->current_time;
            my $elapsed = $current_time - $last_update_time;

            if ($elapsed >= $quiet_delay) {
                $next = $buffered_value;
                $next_ready = true;
                $has_buffered = false;
                $buffered_value = undef;
                return true;
            }
        }

        return false;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Stream::Operation::Debounce - Emit only after a quiet period

=head1 SYNOPSIS

    use grey::static qw[ stream concurrency::util ];

    my $executor = ScheduledExecutor->new;

    # Emit only after 10 ticks of no new elements
    Stream->of(1, 2, 3, 4, 5)
        ->debounce(10, $executor)
        ->for_each(sub ($x) {
            say "Emitted: $x at time " . $executor->current_time;
        });

    $executor->run;
    # Output: Emitted: 5 at time 10
    # (Only the last element, after quiet period)

=head1 DESCRIPTION

C<Stream::Operation::Debounce> is a stream operation that delays emission until
a "quiet period" elapses with no new elements. It buffers the most recent element
and only emits it once C<quiet_delay> ticks pass without any new arrivals.

This is useful for:

=over 4

=item *

Coalescing rapid changes (e.g., user typing, mouse movement)

=item *

Waiting for "settling" before processing

=item *

Reducing processing load for high-frequency events

=item *

Implementing "commit on idle" patterns

=back

=head1 BEHAVIOR

B<Quiet period detection:>

=over 4

=item *

Buffers the most recent element from the source

=item *

Updates the buffer each time a new element arrives

=item *

Emits the buffered element only after C<quiet_delay> ticks with no new arrivals

=item *

Time is tracked via the executor's C<current_time()>

=back

B<Example timeline:>

    Source emits: [a] [b] [c] .......... [d] [e] .......... [f]
    quiet_delay = 5

    Time 0:  Buffer 'a'
    Time 1:  Buffer 'b' (replaces 'a')
    Time 2:  Buffer 'c' (replaces 'b')
    Time 7:  Emit 'c' (5 ticks quiet since last element)
    Time 8:  Buffer 'd'
    Time 9:  Buffer 'e' (replaces 'd')
    Time 14: Emit 'e' (5 ticks quiet)
    Time 15: Buffer 'f'
    Time 20: Emit 'f' (5 ticks quiet)

=head1 CONSTRUCTOR

Created via C<Stream-E<gt>debounce()>:

    my $debounced = $stream->debounce($quiet_delay, $executor);

B<Parameters:>

=over 4

=item C<$quiet_delay>

Number of ticks with no new elements before emitting the buffered element.

=item C<$executor>

A C<ScheduledExecutor> instance that provides C<current_time()>.

=back

=head1 METHODS

=head2 has_next()

Returns true if an element is ready to emit after the quiet period.

Behavior:
1. Pulls all available elements from source, buffering the latest
2. Checks if quiet period has elapsed since last element
3. If yes, marks the buffered element as ready and returns true

=head2 next()

Returns the debounced element.

Must be called after C<has_next()> returns true. Clears the buffer.

=head1 USAGE PATTERNS

=head2 Search Input Debouncing

    my $executor = ScheduledExecutor->new;

    # Only search after user stops typing for 200ms
    $keystroke_stream
        ->debounce(200, $executor)
        ->for_each(sub ($query) {
            perform_search($query);
        });

=head2 Auto-Save After Edits

    my $executor = ScheduledExecutor->new;

    # Save only after 1000ms of no changes
    $document_changes
        ->debounce(1000, $executor)
        ->for_each(sub ($doc) {
            save_to_disk($doc);
        });

=head2 Coalescing Rapid Events

    my $executor = ScheduledExecutor->new;

    # Process mouse position only after it settles
    $mouse_movement_stream
        ->debounce(50, $executor)
        ->for_each(sub ($position) {
            update_tooltip($position);
        });

=head1 COMPARISON WITH THROTTLE

=over 4

=item B<Debounce>

Emits only after a B<quiet period> (no new elements for a specified duration).
Buffers the most recent element.

Use for: Waiting for "settling", coalescing rapid changes

=item B<Throttle>

Emits at a B<constant rate> (one element per time period). Drops elements
that arrive too quickly.

Use for: Rate limiting, periodic sampling

=back

Example:

    User types:    [a][b][c].........[d][e].........[f]
    Debounce(5):                [c]          [e]     [f]  (after quiet)
    Throttle(5):   [a]          [c]          [e]     [f]  (periodic)

=head1 ALGORITHM DETAILS

The debounce operation maintains:

=over 4

=item *

C<$buffered_value> - Most recent element from source

=item *

C<$has_buffered> - Boolean indicating if buffer has a value

=item *

C<$last_update_time> - Time when buffer was last updated

=item *

C<$next_ready> - Boolean indicating element is ready to emit

=back

On each C<has_next()> call:

1. Pull all available elements from source, keeping only the last

2. If buffer has a value and quiet period elapsed, mark as ready

3. Return true if element is ready

This ensures we always buffer the most recent element and emit it only
after the specified quiet period.

=head1 NOTES

=over 4

=item *

Debounce uses a B<pull-based> model (Stream) not push-based (Flow)

=item *

Only the B<most recent> element is emitted (earlier ones are dropped)

=item *

Requires a C<ScheduledExecutor> for time tracking

=item *

Time is simulated (executor ticks), not real-world time

=back

=head1 SEE ALSO

=over 4

=item *

L<Stream> - Stream API with C<debounce()> method

=item *

L<Stream::Operation::Throttle> - Emit at a constant rate

=item *

L<Stream::Operation::Timeout> - Fail if no element within time limit

=item *

L<ScheduledExecutor> - Time-based executor for stream operations

=back

=head1 AUTHOR

grey::static

=cut

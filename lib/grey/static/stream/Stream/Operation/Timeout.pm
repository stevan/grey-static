
use v5.42;
use experimental qw[ class ];
use grey::static::error;

class Stream::Operation::Timeout :isa(Stream::Operation::Node) {
    field $source :param;
    field $timeout_delay :param;
    field $executor :param;  # ScheduledExecutor

    field $last_element_time;
    field $next;

    ADJUST {
        # Initialize to current time so first element doesn't trigger timeout
        $last_element_time = $executor->current_time;
    }

    method next { $next }

    method has_next {
        my $current_time = $executor->current_time;
        my $elapsed = $current_time - $last_element_time;

        if ($elapsed >= $timeout_delay) {
            Error->throw(
                message => "Stream timeout",
                hint => "No element received within $timeout_delay ms"
            );
        }

        if ($source->has_next) {
            $next = $source->next;
            $last_element_time = $executor->current_time;
            return true;
        }

        return false;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Stream::Operation::Timeout - Fail if no element arrives within time limit

=head1 SYNOPSIS

    use grey::static qw[ stream concurrency::util ];

    my $executor = ScheduledExecutor->new;

    # Fail if no element arrives within 50 ticks
    Stream->of(1, 2, 3, 4, 5)
        ->timeout(50, $executor)
        ->for_each(sub ($x) { say $x });

    $executor->run;  # Succeeds (all elements available immediately)

    # Example that times out:
    my $slow_stream = ...;  # Elements arrive slowly
    $slow_stream
        ->timeout(10, $executor)
        ->for_each(sub ($x) { say $x });

    $executor->run;  # Dies with "Stream timeout" if gap exceeds 10 ticks

=head1 DESCRIPTION

C<Stream::Operation::Timeout> is a stream operation that enforces a maximum time
between consecutive elements. If C<timeout_delay> ticks elapse without receiving
the next element, an error is thrown.

This is useful for:

=over 4

=item *

Detecting stalled or hung data sources

=item *

Enforcing SLA requirements (response time guarantees)

=item *

Failing fast on slow or unresponsive operations

=item *

Testing timeout behavior

=back

=head1 BEHAVIOR

B<Timeout monitoring:>

=over 4

=item *

Tracks time of last successful element retrieval

=item *

On each C<has_next()> call, checks if timeout elapsed

=item *

If timeout exceeded, throws C<Error> with "Stream timeout" message

=item *

If element available, updates last-element-time and returns it

=item *

Time is tracked via the executor's C<current_time()>

=back

B<Example timeline:>

    timeout_delay = 10

    Time 0:  First element (baseline)
    Time 5:  Second element (ok: 5 < 10)
    Time 12: Third element (ok: 7 < 10)
    Time 25: Check for fourth element (TIMEOUT: 13 >= 10)
            Dies: "Stream timeout: No element received within 10 ticks"

=head1 CONSTRUCTOR

Created via C<Stream-E<gt>timeout()>:

    my $timed = $stream->timeout($timeout_delay, $executor);

B<Parameters:>

=over 4

=item C<$timeout_delay>

Maximum number of ticks between consecutive elements before timing out.

=item C<$executor>

A C<ScheduledExecutor> instance that provides C<current_time()>.

=back

=head1 METHODS

=head2 has_next()

Returns true if an element is available without timing out.

Behavior:
1. Check if timeout elapsed since last element
2. If yes, throw C<Error> with timeout message
3. If source has element, update last-element-time and return true
4. If no element available (but no timeout), return false

=head2 next()

Returns the next element.

Must be called after C<has_next()> returns true.

=head1 ERROR HANDLING

When a timeout occurs, C<has_next()> throws an C<Error> object:

    Error->throw(
        message => "Stream timeout",
        hint => "No element received within N ticks"
    );

This can be caught with try/catch:

    use experimental 'try';

    try {
        $stream->timeout(10, $executor)
            ->for_each(sub ($x) { say $x });
        $executor->run;
    } catch ($e) {
        say "Stream timed out: $e";
    }

=head1 USAGE PATTERNS

=head2 Enforcing Response Time

    my $executor = ScheduledExecutor->new;

    # API must respond within 1000ms
    $api_requests
        ->timeout(1000, $executor)
        ->for_each(sub ($response) {
            process_response($response);
        });

=head2 Detecting Stalled Streams

    my $executor = ScheduledExecutor->new;

    # Fail if data feed stalls for >30 seconds
    $data_feed
        ->timeout(30000, $executor)
        ->for_each(sub ($data) {
            update_dashboard($data);
        });

=head2 Testing Timeout Behavior

    my $executor = ScheduledExecutor->new;

    # Test that timeout works correctly
    my $timed_out = false;
    try {
        Stream->of(1, 2, 3)
            ->timeout(10, $executor)
            ->for_each(sub ($x) {
                # Simulate slow processing
                $executor->schedule_delayed(sub { }, 20);
            });
        $executor->run;
    } catch ($e) {
        $timed_out = true if $e =~ /timeout/i;
    }

    ok($timed_out, 'Stream timed out as expected');

=head1 COMPARISON WITH OTHER TIME OPERATIONS

=over 4

=item B<Timeout>

Enforces a B<maximum gap> between elements. Fails if gap exceeds limit.

Use for: Detecting stalls, enforcing SLAs, failing fast

=item B<Throttle>

Enforces a B<minimum gap> between elements. Drops elements that arrive too quickly.

Use for: Rate limiting, periodic sampling

=item B<Debounce>

Waits for a B<quiet period> before emitting. Buffers most recent element.

Use for: Coalescing changes, waiting for "settling"

=back

=head1 IMPLEMENTATION DETAILS

The timeout operation maintains:

=over 4

=item *

C<$last_element_time> - Time when last element was retrieved (starts at 0)

=item *

C<$timeout_delay> - Maximum allowed gap between elements

=item *

C<$executor> - ScheduledExecutor for time tracking

=back

On each C<has_next()> call:

1. Calculate elapsed = current_time - last_element_time

2. If elapsed >= timeout_delay, throw Error

3. If source has element, update last_element_time and return it

4. Otherwise return false (no element yet, but no timeout)

This ensures we detect timeouts before attempting to retrieve elements,
providing immediate failure detection.

=head1 NOTES

=over 4

=item *

Timeout uses a B<pull-based> model (Stream) not push-based (Flow)

=item *

First element can arrive at any time (timer starts at 0)

=item *

Timeout applies to B<gaps between elements>, not total stream duration

=item *

Requires a C<ScheduledExecutor> for time tracking

=item *

Time is simulated (executor ticks), not real-world time

=back

=head1 SEE ALSO

=over 4

=item *

L<Stream> - Stream API with C<timeout()> method

=item *

L<Stream::Operation::Throttle> - Enforce minimum gap between elements

=item *

L<Stream::Operation::Debounce> - Wait for quiet period before emitting

=item *

L<Promise> - Promise with C<timeout()> method for async operations

=item *

L<ScheduledExecutor> - Time-based executor for stream operations

=item *

L<Error> - Error class used for timeout exceptions

=back

=head1 AUTHOR

grey::static

=cut

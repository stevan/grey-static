
use v5.42;
use experimental qw[ class ];

class Stream::Operation::Throttle :isa(Stream::Operation::Node) {
    field $source :param;
    field $min_delay :param;
    field $executor :param;  # ScheduledExecutor

    field $last_emit_time = undef;
    field $next;

    method next { $next }

    method has_next {
        return false unless $source->has_next;

        # First element or enough time has passed
        if (!defined $last_emit_time) {
            $next = $source->next;
            $last_emit_time = $executor->current_time;
            return true;
        }

        my $current_time = $executor->current_time;
        if (($current_time - $last_emit_time) >= $min_delay) {
            $next = $source->next;
            $last_emit_time = $executor->current_time;
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

Stream::Operation::Throttle - Limit stream element emission rate

=head1 SYNOPSIS

    use grey::static qw[ stream concurrency::util ];

    my $executor = ScheduledExecutor->new;

    # Emit at most one element every 10 ticks
    Stream->of(1, 2, 3, 4, 5)
        ->throttle(10, $executor)
        ->for_each(sub ($x) {
            say "Time " . $executor->current_time . ": $x";
        });

    $executor->run;
    # Output:
    # Time 0: 1
    # Time 10: 2
    # Time 20: 3
    # Time 30: 4
    # Time 40: 5

=head1 DESCRIPTION

C<Stream::Operation::Throttle> is a stream operation that rate-limits element
emission. It ensures a minimum delay between consecutive elements, dropping
elements that arrive too quickly.

This is useful for:

=over 4

=item *

Rate-limiting API calls or resource access

=item *

Preventing overwhelming downstream consumers

=item *

Sampling high-frequency data streams

=item *

Coordinating timed operations

=back

=head1 BEHAVIOR

B<Time-based rate limiting:>

=over 4

=item *

First element passes immediately at the current time

=item *

Subsequent elements only pass if C<min_delay> ticks have elapsed since the last emission

=item *

Elements that arrive too soon are B<dropped> (not buffered)

=item *

Time is tracked via the executor's C<current_time()>

=back

B<Example timeline:>

    Source emits:  [1, 2, 3, 4, 5] (all immediately available)
    min_delay = 10

    Time 0:  Emit 1 (first element)
    Time 0:  Drop 2 (too soon: 0 < 10)
    Time 0:  Drop 3 (too soon: 0 < 10)
    Time 0:  Drop 4 (too soon: 0 < 10)
    Time 0:  Drop 5 (too soon: 0 < 10)

    [With Stream::of(), all elements are immediately available,
     so only the first passes through]

=head1 CONSTRUCTOR

Created via C<Stream-E<gt>throttle()>:

    my $throttled = $stream->throttle($min_delay, $executor);

B<Parameters:>

=over 4

=item C<$min_delay>

Minimum number of ticks between emitted elements.

=item C<$executor>

A C<ScheduledExecutor> instance that provides C<current_time()>.

=back

=head1 METHODS

=head2 has_next()

Returns true if an element is available that satisfies the throttle constraint.

Checks if:
1. Source has an element available
2. Sufficient time has elapsed since the last emission

=head2 next()

Returns the next throttled element.

Must be called after C<has_next()> returns true.

=head1 USAGE PATTERNS

=head2 Rate-Limiting API Calls

    my $executor = ScheduledExecutor->new;

    # Limit to one request every 100ms (simulated)
    Stream->of(@urls)
        ->throttle(100, $executor)
        ->map(sub ($url) { fetch_data($url) })
        ->for_each(sub ($data) { process($data) });

=head2 Sampling Sensor Data

    my $executor = ScheduledExecutor->new;

    # Sample at most once every 50 ticks
    $sensor_stream
        ->throttle(50, $executor)
        ->for_each(sub ($reading) {
            log_reading($reading);
        });

=head2 Combining with Other Operations

    my $executor = ScheduledExecutor->new;

    Stream->of(1..100)
        ->throttle(10, $executor)      # Rate limit
        ->map(sub ($x) { $x * 2 })     # Transform
        ->filter(sub ($x) { $x > 50 }) # Filter
        ->for_each(sub ($x) { say $x });

=head1 COMPARISON WITH DEBOUNCE

=over 4

=item B<Throttle>

Emits at a B<constant rate> (one element per time period). Drops elements
that arrive too quickly.

Use for: Rate limiting, periodic sampling

=item B<Debounce>

Emits only after a B<quiet period> (no new elements for a specified duration).
Buffers the most recent element.

Use for: Waiting for "settling", coalescing rapid changes

=back

Example:

    User types:    [a][b][c].........[d][e].........[f]
    Throttle(5):   [a]          [c]          [e]     [f]  (periodic)
    Debounce(5):                [c]          [e]     [f]  (after quiet)

=head1 NOTES

=over 4

=item *

Throttle uses a B<pull-based> model (Stream) not push-based (Flow)

=item *

Elements are B<dropped>, not buffered or delayed

=item *

Requires a C<ScheduledExecutor> for time tracking

=item *

Time is simulated (executor ticks), not real-world time

=back

=head1 SEE ALSO

=over 4

=item *

L<Stream> - Stream API with C<throttle()> method

=item *

L<Stream::Operation::Debounce> - Wait for quiet period before emitting

=item *

L<Stream::Operation::Timeout> - Fail if no element within time limit

=item *

L<ScheduledExecutor> - Time-based executor for stream operations

=back

=head1 AUTHOR

grey::static

=cut

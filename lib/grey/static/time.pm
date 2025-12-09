use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::time;

our $VERSION = '0.01';

use File::Basename ();

sub import {
    my ($class, @subfeatures) = @_;

    # If no subfeatures specified, do nothing
    return unless @subfeatures;

    # Load each subfeature
    for my $subfeature (@subfeatures) {
        if ($subfeature eq 'stream') {
            # Add the stream directory to @INC
            use lib File::Basename::dirname(__FILE__) . '/time/stream';

            # Load the Time stream classes
            load_module('Time');
        }
        elsif ($subfeature eq 'wheel') {
            # Add the wheel directory to @INC
            use lib File::Basename::dirname(__FILE__) . '/time/wheel';

            # Load the Timer::Wheel classes
            load_module('Timer');
            load_module('Timer::Wheel');
        }
        else {
            die "Unknown time subfeature: $subfeature";
        }
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

grey::static::time - Time and timer utilities

=head1 SYNOPSIS

    use grey::static qw[ functional stream time::stream ];

    # Epoch time stream
    my @times = Time->of_epoch()
        ->take(5)
        ->collect(Stream::Collectors->ToList);

    # Monotonic clock stream
    my @monotonic = Time->of_monotonic()
        ->take(10)
        ->collect(Stream::Collectors->ToList);

    # Delta time stream
    my @deltas = Time->of_delta()
        ->take(5)
        ->sleep_for(0.1)
        ->collect(Stream::Collectors->ToList);

    # Timer wheel for efficient timer management
    use grey::static qw[ time::wheel ];

    my $wheel = Timer::Wheel->new;
    $wheel->add_timer(Timer->new(expiry => 100, event => sub { say "Fired!" }));
    $wheel->advance_by(100);

=head1 DESCRIPTION

The C<time> feature provides time and timer utilities organized as sub-features:

=over 4

=item *

C<time::stream> - Stream-based time sources (epoch, monotonic, delta)

=item *

C<time::wheel> - Hierarchical timer wheel for efficient timer management

=back

=head1 SUB-FEATURES

=head2 time::stream

Provides C<Time> class which extends C<Stream> with time-based sources.

B<Dependencies:> Requires C<functional> and C<stream> features, plus L<Time::HiRes>.

=head2 time::wheel

Provides C<Timer> and C<Timer::Wheel> classes for efficient timer management
using a hierarchical timing wheel data structure.

B<Dependencies:> None

=head1 CLASSES

=head2 Time (time::stream)

Stream class for time-based data sources.

=head3 Class Methods

=over 4

=item C<of_epoch()>

Creates a stream of epoch time values (seconds since Unix epoch).
Each call to the stream produces the current epoch time.

=item C<of_monotonic()>

Creates a stream of monotonic clock values.
Uses C<CLOCK_MONOTONIC> for steady, non-adjustable time.

=item C<of_delta()>

Creates a stream of delta time values (time since last read).
First read returns 0, subsequent reads return seconds elapsed since previous read.

=back

=head3 Methods

=over 4

=item C<sleep_for($duration)>

Sleeps for C<$duration> seconds before producing each element.
Returns C<$self> for method chaining.

=back

=head2 Timer (time::wheel)

Represents a timer with an expiry time and event callback.

=head3 Constructor

    my $timer = Timer->new(
        expiry => 100,           # Time when timer expires
        event  => sub { ... },   # Callback to invoke on expiry
    );

=head3 Methods

=over 4

=item C<expiry()>

Returns the expiry time for this timer.

=item C<event()>

Returns the event callback for this timer.

=back

=head2 Timer::Wheel (time::wheel)

Hierarchical timing wheel for efficient timer management.

=head3 Constructor

    my $wheel = Timer::Wheel->new;

Creates a new timing wheel with 5 depth levels (gears) supporting timers
up to 10^5 time units.

=head3 Methods

=over 4

=item C<add_timer($timer)>

Adds a timer to the wheel. The timer is placed in the appropriate bucket
based on its expiry time.

=item C<advance_by($n)>

Advances the wheel by C<$n> time units, firing any timers that have expired
and moving timers between buckets as needed.

=item C<find_next_timeout()>

Returns the time until the next timer will fire, or C<undef> if no timers.

=item C<dump_wheel()>

Prints a visual representation of the wheel state (for debugging).

=back

=head2 Timer::Wheel::State (time::wheel)

Internal state management for the timing wheel.

=head3 Constructor

    my $state = Timer::Wheel::State->new(num_gears => 4);

=head3 Methods

=over 4

=item C<advance()>

Advances the wheel state by one time unit, updating gears and tracking changes.

=item C<time()>

Returns the current time value.

=item C<gears()>

Returns the array of gear values.

=item C<changes()>

Returns the array of gear changes from the last advance.

=back

=head1 DEPENDENCIES

=over 4

=item *

C<time::stream> requires L<Time::HiRes>, C<functional>, and C<stream> features

=item *

C<time::wheel> has no external dependencies

=back

=head1 SEE ALSO

L<grey::static>, L<grey::static::stream>, L<Time::HiRes>

=head1 AUTHOR

grey::static

=cut

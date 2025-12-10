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

=head1 DESCRIPTION

The C<time> feature provides time utilities organized as sub-features.

Currently available: C<time::stream> - Stream-based time sources (epoch, monotonic, delta)

=head1 SUB-FEATURES

=head2 time::stream

Provides C<Time> class which extends C<Stream> with time-based sources.

B<Dependencies:> Requires C<functional> and C<stream> features, plus L<Time::HiRes>.

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

=head1 DEPENDENCIES

C<time::stream> requires L<Time::HiRes>, C<functional>, and C<stream> features

=head1 SEE ALSO

L<grey::static>, L<grey::static::stream>, L<Time::HiRes>

=head1 AUTHOR

grey::static

=cut

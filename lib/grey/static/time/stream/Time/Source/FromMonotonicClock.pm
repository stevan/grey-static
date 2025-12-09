
use v5.42;
use experimental qw[ class ];

use Time::HiRes ();

class Time::Source::FromMonotonicClock :isa(Stream::Source) {
    my $MONOTONIC = Time::HiRes::CLOCK_MONOTONIC();

    method next { Time::HiRes::clock_gettime( $MONOTONIC ) }
    method has_next { true }
}

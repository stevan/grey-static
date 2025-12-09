
use v5.42;
use experimental qw[ class ];

use Time::HiRes ();

class Time::Source::FromDeltaTime :isa(Stream::Source) {
    field $prev;

    method next {
        $prev = [ Time::HiRes::gettimeofday() ] and return 0
            unless defined $prev;

        my $now   = [ Time::HiRes::gettimeofday() ];
        my $since = Time::HiRes::tv_interval( $prev, $now );
        $prev     = $now;
        return $since;
    }

    method has_next { true }
}

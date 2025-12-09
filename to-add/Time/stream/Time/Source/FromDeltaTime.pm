
use v5.40;
use experimental qw[ class ];

use Time::HiRes ();

class Stream::Time::Source::FromDeltaTime :isa(Stream::Source) {
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

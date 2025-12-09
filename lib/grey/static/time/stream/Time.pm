
use v5.42;
use experimental qw[ class ];

use Time::HiRes ();

use Time::Source::FromEpochTime;
use Time::Source::FromMonotonicClock;
use Time::Source::FromDeltaTime;

class Time :isa(Stream) {

    sub of_epoch ($class) {
        $class->new( source => Time::Source::FromEpochTime->new )
    }

    sub of_monotonic ($class) {
        $class->new( source => Time::Source::FromMonotonicClock->new )
    }

    sub of_delta ($class) {
        $class->new( source => Time::Source::FromDeltaTime->new )
    }


    method sleep_for ($duration) {
        $self->peek(sub { Time::HiRes::sleep($duration) })
    }
}

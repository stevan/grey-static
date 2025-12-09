
use v5.40;
use experimental qw[ class ];

use Time::HiRes ();

use Stream::Time::Source::FromEpochTime;
use Stream::Time::Source::FromMonotonicClock;
use Stream::Time::Source::FromDeltaTime;

class Stream::Time :isa(Stream) {

    sub of_epoch ($class) {
        $class->new( source => Stream::Time::Source::FromEpochTime->new )
    }

    sub of_monotonic ($class) {
        $class->new( source => Stream::Time::Source::FromMonotonicClock->new )
    }

    sub of_delta ($class) {
        $class->new( source => Stream::Time::Source::FromDeltaTime->new )
    }


    method sleep_for ($duration) {
        $self->peek(sub { Time::HiRes::sleep($duration) })
    }
}

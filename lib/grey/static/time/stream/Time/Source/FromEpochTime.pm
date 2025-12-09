
use v5.42;
use experimental qw[ class ];

use Time::HiRes ();

class Time::Source::FromEpochTime :isa(Stream::Source) {
    method     next { Time::HiRes::time() }
    method has_next { true   }
}

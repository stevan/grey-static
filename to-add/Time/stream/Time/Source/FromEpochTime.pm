
use v5.40;
use experimental qw[ class ];

use Time::HiRes ();

class Stream::Time::Source::FromEpochTime :isa(Stream::Source) {
    method     next { Time::HiRes::time() }
    method has_next { true   }
}

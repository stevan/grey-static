use v5.42;
use experimental qw[ class ];

use Actor::Signals::Signal;

class Actor::Signals::Terminated :isa(Actor::Signals::Signal) {
    field $ref        :param :reader;
    field $with_error :param :reader = undef;
}

1;

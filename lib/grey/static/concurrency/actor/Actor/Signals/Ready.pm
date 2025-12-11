use v5.42;
use experimental qw[ class ];

use Actor::Signals::Signal;

class Actor::Signals::Ready :isa(Actor::Signals::Signal) {
    field $ref :param :reader;
}

1;

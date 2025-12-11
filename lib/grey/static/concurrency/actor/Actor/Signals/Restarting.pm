use v5.42;
use experimental qw[ class ];

use Actor::Signals::Signal;

class Actor::Signals::Restarting :isa(Actor::Signals::Signal) {}

1;

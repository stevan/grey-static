use v5.42;
use experimental qw[ class ];

use Actor;
use Actor::Signals::Started;
use Actor::Signals::Ready;

class ActorSystem::Actors::Users :isa(Actor) {
    method signal ($context, $signal) {
        if ($signal isa Actor::Signals::Started) {
            $context->parent->context->notify( Actor::Signals::Ready->new( ref => $context->self ) );
        }
    }
}

1;

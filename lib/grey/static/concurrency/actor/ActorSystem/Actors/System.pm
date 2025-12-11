use v5.42;
use experimental qw[ class ];

use Scalar::Util qw[ refaddr ];

use Actor;
use Actor::Props;
use Actor::Signals::Started;
use Actor::Signals::Ready;
use ActorSystem::Actors::DeadLetterQueue;

class ActorSystem::Actors::System :isa(Actor) {
    field $dead_letter_queue;

    method signal ($context, $signal) {
        if ($signal isa Actor::Signals::Started) {
            $dead_letter_queue = $context->spawn( Actor::Props->new(
                class => 'ActorSystem::Actors::DeadLetterQueue',
                alias => '//sys/dead_letters',
            ));
        }
        elsif ($signal isa Actor::Signals::Ready) {
            if ( refaddr $signal->ref == refaddr $dead_letter_queue ) {
                $context->parent->context->notify( Actor::Signals::Ready->new( ref => $context->self ) );
            }
        }
    }
}

1;

use v5.42;
use experimental qw[ class ];

use Actor;
use Actor::Signals::Started;
use Actor::Signals::Ready;

class ActorSystem::Actors::DeadLetterQueue::DeadLetter {
    use overload '""' => \&to_string;
    field $to      :param :reader;
    field $message :param :reader;
    method to_string { sprintf '%s (%s)' => $to, $message }
}

class ActorSystem::Actors::DeadLetterQueue :isa(Actor) {
    field @dead_letters;

    method dead_letters { @dead_letters }

    method receive ($context, $message) {
        push @dead_letters => $message;
        return true;
    }

    method signal ($context, $signal) {
        if ($signal isa Actor::Signals::Started) {
            $context->parent->context->notify( Actor::Signals::Ready->new( ref => $context->self ) );
        }
    }
}

1;

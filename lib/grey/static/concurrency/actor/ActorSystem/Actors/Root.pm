use v5.42;
use experimental qw[ class ];

use Scalar::Util qw[ refaddr ];

use Actor;
use Actor::Props;
use Actor::Signals::Started;
use Actor::Signals::Ready;
use Actor::Signals::Stopping;
use Actor::Signals::Stopped;
use Actor::Signals::Terminated;
use ActorSystem::Actors::System;
use ActorSystem::Actors::Users;

class ActorSystem::Actors::Root :isa(Actor) {
    field $init :param;

    field $system;
    field $users;

    method signal ($context, $signal) {
        if ($signal isa Actor::Signals::Started) {
            $system = $context->spawn( Actor::Props->new(
                class => 'ActorSystem::Actors::System',
                alias => '//sys'
            ));
        }
        elsif ($signal isa Actor::Signals::Ready) {
            if ( refaddr $signal->ref == refaddr $system ) {
                $users = $context->spawn( Actor::Props->new(
                    class => 'ActorSystem::Actors::Users',
                    alias => '//usr',
                ));
            }
            elsif ( refaddr $signal->ref == refaddr $users ) {
                try {
                    $init->($users->context);
                } catch ($e) {
                    chomp $e;
                    $context->system->shutdown;
                }
            }
        }
        elsif ($signal isa Actor::Signals::Stopping) {
            # nothing special
        }
        elsif ($signal isa Actor::Signals::Stopped) {
            # nothing special
        }
        elsif ($signal isa Actor::Signals::Terminated) {
            my $ref = $signal->ref;
            if (refaddr $ref == refaddr $users) {
                $system->context->stop;
            }
            elsif (refaddr $ref == refaddr $system) {
                $context->stop;
            }
        }
    }
}

1;

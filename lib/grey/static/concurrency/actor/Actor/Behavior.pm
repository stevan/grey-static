use v5.42;
use experimental qw[ class ];

class Actor::Behavior {
    field $receivers :param = +{};
    field $handlers  :param = +{};

    method receivers { $receivers }
    method handlers  { $handlers  }

    method receive_message ($actor, $context, $message) {
        my $method = $receivers->{ blessed $message } // return false;
        $actor->$method( $context, $message );
        return true;
    }

    method receive_signal ($actor, $context, $signal) {
        my $method = $handlers->{ blessed $signal } // return false;
        $actor->$method( $context, $signal );
        return true;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Actor::Behavior - Message and signal routing for actors

=head1 SYNOPSIS

    use grey::static qw[ concurrency::actor ];

    # Behaviors are typically created automatically via @Receive/@Signal attributes
    class MyActor :isa(Actor) {
        method on_foo :Receive(Foo) ($context, $message) { ... }
        method on_bar :Receive(Bar) ($context, $message) { ... }
    }

    # Manual behavior creation (advanced)
    my $behavior = Actor::Behavior->new(
        receivers => {
            'Foo' => \&handle_foo,
            'Bar' => \&handle_bar,
        },
        handlers => {
            'Actor::Signals::Started' => \&on_started,
        }
    );

=head1 DESCRIPTION

C<Actor::Behavior> handles message and signal routing for actors. It maintains
dispatch tables mapping message/signal types to handler methods.

Most users won't interact with Behavior directly - it's created automatically
from the C<@Receive> and C<@Signal> attributes on actor methods.

=head1 CONSTRUCTOR

=head2 new(%options)

    my $behavior = Actor::Behavior->new(
        receivers => \%message_handlers,  # optional
        handlers  => \%signal_handlers,   # optional
    );

=over 4

=item receivers

Hash mapping message class names to method references.

=item handlers

Hash mapping signal class names to method references.

=back

=head1 METHODS

=head2 receivers

    my $receivers = $behavior->receivers;

Returns the hash reference of message class -> method mappings.

=head2 handlers

    my $handlers = $behavior->handlers;

Returns the hash reference of signal class -> method mappings.

=head2 receive_message($actor, $context, $message)

    my $handled = $behavior->receive_message($actor, $context, $message);

Dispatches a message to the appropriate handler. Returns true if handled,
false if no handler found (message goes to dead letter queue).

=head2 receive_signal($actor, $context, $signal)

    my $handled = $behavior->receive_signal($actor, $context, $signal);

Dispatches a signal to the appropriate handler. Returns true if handled,
false if no handler found (signal is ignored).

=head1 BEHAVIOR SWITCHING

Actors can switch behaviors dynamically using C<become>/C<unbecome>:

    class StatefulActor :isa(Actor) {
        method on_start :Receive(Start) ($context, $message) {
            $self->become($self->active_behavior);
        }

        method active_behavior {
            # Return a Behavior object
        }
    }

The behavior stack allows FSM-style patterns:

    Initial -> become(A) -> become(B) -> unbecome -> back to A

=head1 SEE ALSO

L<Actor>

=cut

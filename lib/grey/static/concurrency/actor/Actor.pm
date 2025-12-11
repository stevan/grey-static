use v5.42;
use experimental qw[ class ];

use Actor::Behavior;

class Actor {
    sub behavior_for;

    field $behavior;
    field @behaviors;

    ADJUST {
        $behavior = __CLASS__->behavior_for;
    }

    # Behavior stack management
    method become ($b) { unshift @behaviors => $b }
    method unbecome    { shift @behaviors }

    # Message and signal dispatch
    method receive ($context, $message) {
        return ($behaviors[0] // $behavior)->receive_message( $self, $context, $message );
    }

    method signal ($context, $signal) {
        return ($behaviors[0] // $behavior)->receive_signal( $self, $context, $signal );
    }

    # Attribute-based handler registration
    my (%BEHAVIORS,
        %RECEIVERS,
        %HANDLERS,
        %ATTRIBUTES);

    sub behavior_for ($pkg) {
        $BEHAVIORS{$pkg} //= Actor::Behavior->new(
            receivers => $RECEIVERS{$pkg},
            handlers  => $HANDLERS{$pkg},
        );
    }

    sub FETCH_CODE_ATTRIBUTES  ($pkg, $code) { $ATTRIBUTES{ $pkg }{ $code } }
    sub MODIFY_CODE_ATTRIBUTES ($pkg, $code, @attrs) {
        grep { $_ !~ /^(Receive|Signal)/ }
        map  {
            if ($_ =~ /^(Receive|Signal)/) {
                $ATTRIBUTES{ $pkg }{ $code } = $_;

                my $type;
                if ($_ =~ /^(Receive|Signal)\((.*)\)$/ ) {
                    $type = $2;
                }
                else {
                    die "You must specify a type to Receive/Signal not $_";
                }

                if ($_ =~ /^Receive/) {
                    $RECEIVERS{ $pkg }{ $type } = $code;
                } elsif ($_ =~ /^Signal/) {
                    $HANDLERS{ $pkg }{ $type } = $code;
                }
            }
            $_;
        }
        @attrs;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Actor - Base class for all actors

=head1 SYNOPSIS

    use grey::static qw[ concurrency::actor ];

    class MyActor :isa(Actor) {

        method on_started :Signal(Actor::Signals::Started) ($context, $signal) {
            # Called when the actor starts
        }

        method on_message :Receive(MyMessage) ($context, $message) {
            # Handle MyMessage
            $context->stop;  # Stop when done
        }
    }

=head1 DESCRIPTION

C<Actor> is the base class for all actors in the grey::static concurrency system.
Actors communicate via asynchronous messages and have a well-defined lifecycle
managed by signals.

=head2 Messages vs Signals

=over 4

=item B<Messages> - Business logic communication between actors. Dispatched via
C<@Receive> attribute handlers.

=item B<Signals> - Lifecycle events from the system. Dispatched via C<@Signal>
attribute handlers. Include C<Started>, C<Stopping>, C<Stopped>, C<Restarting>,
C<Terminated>.

=back

=head1 DEFINING ACTORS

Actors are defined as classes that inherit from C<Actor>:

    class Counter :isa(Actor) {
        field $count = 0;

        method on_increment :Receive(Increment) ($context, $message) {
            $count++;
        }

        method on_get :Receive(GetCount) ($context, $message) {
            $message->reply_to->send(CountResult->new( count => $count ));
        }
    }

=head2 The @Receive Attribute

Marks a method as a message handler:

    method handler_name :Receive(MessageClassName) ($context, $message) {
        # $context - the actor's Context
        # $message - the received message instance
    }

Return value is ignored unless the message is unhandled (returns false),
in which case it goes to the dead letter queue.

=head2 The @Signal Attribute

Marks a method as a signal handler:

    method handler_name :Signal(SignalClassName) ($context, $signal) {
        # Handle lifecycle signal
    }

Common signals:

    Actor::Signals::Started     # Actor has started
    Actor::Signals::Stopping    # Actor is about to stop
    Actor::Signals::Stopped     # Actor has stopped
    Actor::Signals::Restarting  # Actor is restarting
    Actor::Signals::Terminated  # A child/watched actor terminated

=head1 METHODS

=head2 become($behavior)

    $self->become(SomeBehavior->new);

Pushes a new behavior onto the behavior stack. The new behavior will handle
messages/signals until C<unbecome> is called.

=head2 unbecome

    $self->unbecome;

Pops the current behavior off the stack, reverting to the previous behavior.

=head1 BEHAVIOR STACK

Actors support behavior switching via C<become>/C<unbecome>. This allows
state-machine patterns:

    class Parser :isa(Actor) {
        method on_start :Receive(StartParsing) ($context, $message) {
            $self->become(ParsingBehavior->new);
        }
    }

    class ParsingBehavior :isa(Actor::Behavior) {
        # ... parsing handlers
    }

The behavior stack uses LIFO semantics:

    become(A) -> become(B) -> unbecome -> (back to A) -> unbecome -> (default)

=head1 ERROR HANDLING

Errors in message handlers are caught and passed to the actor's supervisor.
The supervisor decides whether to:

=over 4

=item * B<Stop> - Stop the actor (default)

=item * B<Resume> - Skip the failed message, continue processing

=item * B<Retry> - Re-deliver the failed message

=item * B<Restart> - Restart the actor and re-deliver the message

=back

Errors in signal handlers are handled specially:

=over 4

=item * C<Started> errors - Actor is stopped immediately

=item * C<Stopping>/C<Stopped>/C<Terminated> errors - Logged, shutdown continues

=item * Other signals - Deferred to supervisor

=back

=head1 INTERNAL METHODS

These are called by the Mailbox, not by user code:

=head2 receive($context, $message)

Dispatches a message to the appropriate handler.

=head2 signal($context, $signal)

Dispatches a signal to the appropriate handler.

=head1 SEE ALSO

L<Actor::Context>, L<Actor::Behavior>, L<Actor::Message>,
L<Actor::Signals::Started>

=cut

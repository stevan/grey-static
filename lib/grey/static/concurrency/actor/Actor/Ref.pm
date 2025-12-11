use v5.42;
use experimental qw[ class ];

class Actor::Ref {
    use overload '""' => \&to_string;

    field $pid :param;
    field $context;

    method set_context ($c) {
        $context = $c;
        $self
    }

    method context { $context }
    method pid     { $pid }

    method send ($message) {
        if ($context->is_stopped) {
            warn "Attempt to send($message) to stopped actor, ignoring\n";
            return;
        }
        $context->send_message( $self, $message );
    }

    method to_string {
        if ($context) {
            sprintf 'Ref(%s)[%03d]' => $context->props->class, $pid;
        } else {
            sprintf 'Ref(?)[%03d]' => $pid;
        }
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Actor::Ref - A reference to an actor

=head1 SYNOPSIS

    use grey::static qw[ concurrency::actor ];

    # Get a Ref to self
    my $self_ref = $context->self;

    # Spawn returns a Ref
    my $child_ref = $context->spawn(Actor::Props->new( class => 'Worker' ));

    # Send a message via Ref
    $child_ref->send(DoWork->new( reply_to => $self_ref ));

    # Get the PID
    my $pid = $child_ref->pid;

=head1 DESCRIPTION

C<Actor::Ref> is an actor reference - a handle used to send messages to an actor.
Refs provide location transparency: the sender doesn't need to know where the
actor is running, just has a reference to communicate with it.

=head1 METHODS

=head2 send($message)

    $ref->send(MyMessage->new);

Sends a message to the referenced actor. Messages are delivered asynchronously
to the actor's mailbox.

B<Note:> Sending to a stopped actor logs a warning and drops the message.

=head2 pid

    my $pid = $ref->pid;

Returns the actor's process ID (an integer unique within the System).

=head2 context

    my $context = $ref->context;

Returns the actor's L<Actor::Context>. Generally only used internally or for
advanced patterns like watching:

    $context->watch($other_ref);
    # is equivalent to:
    $other_ref->context->add_watcher($context->self);

=head1 STRINGIFICATION

Refs stringify to a readable format:

    Ref(MyActor)[001]

=head1 SEE ALSO

L<Actor::Context>, L<Actor>, L<Actor::Message>

=cut

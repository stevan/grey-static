use v5.42;
use experimental qw[ class ];

class Actor::Context {
    use overload '""' => \&to_string;

    field $ref     :param;
    field $system  :param;
    field $mailbox :param;

    ADJUST {
        $ref->set_context( $self );
    }

    method self     { $ref               }
    method parent   { $mailbox->parent   }
    method children { $mailbox->children }
    method props    { $mailbox->props    }

    method system { $system }

    method is_stopped { $mailbox->is_stopped }
    method is_alive   { $mailbox->is_alive   }

    method spawn ($props) {
        my $child = $system->spawn_actor($props, $ref);
        $mailbox->add_child( $child );
        return $child;
    }

    method send_message ($to, $message) {
        $system->enqueue_message( $to, $message );
    }

    method schedule (%options) { $system->schedule_timer( %options ) }

    method stop {
        $system->despawn_actor( $ref );
    }

    method watch ($to_watch) {
        $to_watch->context->add_watcher( $ref );
    }

    method add_watcher ($watcher) {
        $mailbox->add_watcher( $watcher );
    }

    method notify ($signal) {
        $mailbox->notify( $signal )
    }

    method restart { $mailbox->restart }

    method to_string {
        sprintf 'Context(%s)[%03d]' => $mailbox->props->class, $ref->pid;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Actor::Context - The actor's interface to the system

=head1 SYNOPSIS

    use grey::static qw[ concurrency::actor ];

    method on_started :Signal(Actor::Signals::Started) ($context, $signal) {
        # Spawn a child
        my $child = $context->spawn(Actor::Props->new( class => 'Worker' ));

        # Send a message
        $child->send(DoWork->new);

        # Schedule a timer
        $context->schedule(
            after    => 5.0,
            callback => sub { $context->stop }
        );

        # Watch another actor
        $context->watch($child);
    }

=head1 DESCRIPTION

C<Actor::Context> is the actor's interface to the system. It provides methods
for spawning children, sending messages, scheduling timers, and managing
the actor's lifecycle.

Each actor has exactly one Context, accessible via the C<$context> parameter
in message and signal handlers.

=head1 METHODS

=head2 self

    my $ref = $context->self;

Returns the actor's own L<Actor::Ref>. Use this to give other actors a way
to send messages back:

    $other->send(Request->new( reply_to => $context->self ));

=head2 parent

    my $parent_ref = $context->parent;

Returns the parent actor's Ref, or C<undef> for root actors.

=head2 children

    my @child_refs = $context->children;

Returns a list of Refs for all child actors.

=head2 props

    my $props = $context->props;

Returns the L<Actor::Props> used to create this actor.

=head2 spawn($props)

    my $child_ref = $context->spawn(Actor::Props->new( class => 'Child' ));

Creates a new child actor and returns its Ref. The child's lifecycle is tied
to this actor - when this actor stops, all children are stopped first.

=head2 stop

    $context->stop;

Initiates graceful shutdown of this actor. The shutdown sequence:

=over 4

=item 1. Children receive C<Stopping> signal and begin their shutdown

=item 2. Parent waits for all children to stop

=item 3. Parent receives C<Stopped> signal

=item 4. Parent notifies its parent via C<Terminated> signal

=back

=head2 restart

    $context->restart;

Manually triggers a restart of this actor. Children are stopped, actor is
re-initialized, and C<Started> signal is sent again.

=head2 schedule(%options)

    my $timer = $context->schedule(
        after    => 1.5,           # seconds
        callback => sub { ... }
    );

    # Cancel a timer
    $timer->cancel;

Schedules a timer callback. Returns a timer object that can be cancelled.

=head2 watch($ref)

    $context->watch($other_actor);

Registers to receive a C<Terminated> signal when the watched actor stops.
Useful for monitoring actors that aren't your children.

=head2 notify($signal)

    $context->notify(SomeSignal->new);

Sends a signal to this actor. Used internally and for custom signals.

=head2 system

    my $sys = $context->system;

Returns the L<ActorSystem>. Needed for low-level operations like adding
IO selectors. Prefer higher-level Context methods when available.

=head2 is_stopped

    if ($context->is_stopped) { ... }

Returns true if the actor has stopped.

=head2 is_alive

    if ($context->is_alive) { ... }

Returns true if the actor is running (not stopped/stopping).

=head1 STRINGIFICATION

Contexts stringify to a readable format:

    Context(MyActor)[001]

=head1 SEE ALSO

L<Actor>, L<Actor::Ref>, L<Actor::Props>, L<ActorSystem>

=cut

use v5.42;
use experimental qw[ class ];

use Scalar::Util qw[ refaddr ];

use Actor;
use Actor::Props;
use Actor::Ref;
use Actor::Context;

use Actor::Signals::Signal;
use Actor::Signals::Started;
use Actor::Signals::Stopping;
use Actor::Signals::Stopped;
use Actor::Signals::Restarting;
use Actor::Signals::Terminated;

class Actor::Mailbox::State {
    use constant STARTING   => 0;
    use constant ALIVE      => 1;
    use constant RUNNING    => 2;
    use constant SUSPENDED  => 3;
    use constant STOPPING   => 4;
    use constant RESTARTING => 5;
    use constant STOPPED    => 6;

    our @STATES = qw(
        STARTING
        ALIVE
        RUNNING
        SUSPENDED
        STOPPING
        RESTARTING
        STOPPED
    );
}

class Actor::Mailbox {
    use overload '""' => \&to_string;

    field $system :param :reader;
    field $props  :param :reader;
    field $parent :param :reader;
    field $pid    :param;

    field $state;

    field $context :reader;
    field $ref     :reader;

    field $supervisor;
    field $actor;

    field @children;
    field %watchers;

    field $inbox;

    field @messages;
    field @signals;

    field $halted_on;

    ADJUST {
        $state   = Actor::Mailbox::State->STARTING;
        $ref     = Actor::Ref->new( pid => $pid );
        $context = Actor::Context->new( ref => $ref, mailbox => $self, system => $system );

        $supervisor = $props->supervisor;

        $inbox = \@messages;

        push @signals => Actor::Signals::Started->new;
    }

    method to_string { sprintf "Mailbox(%s)[%03d]" => $props->class, $ref->pid }

    method children { @children }

    method add_child ($child) { push @children => $child }

    method add_watcher ($watcher) { $watchers{refaddr $watcher} = $watcher }

    method is_starting   { $state == Actor::Mailbox::State->STARTING   }
    method is_alive      { $state == Actor::Mailbox::State->ALIVE || $self->is_running }
    method is_running    { $state == Actor::Mailbox::State->RUNNING    }
    method is_suspended  { $state == Actor::Mailbox::State->SUSPENDED  }
    method is_stopping   { $state == Actor::Mailbox::State->STOPPING   }
    method is_restarting { $state == Actor::Mailbox::State->RESTARTING }
    method is_stopped    { $state == Actor::Mailbox::State->STOPPED    }

    method suspend { $state = Actor::Mailbox::State->SUSPENDED }
    method resume  { $state = Actor::Mailbox::State->ALIVE     }

    method restart {
        $self->suspend;
        push @signals => Actor::Signals::Restarting->new;
    }

    method stop {
        $self->suspend;
        push @signals => Actor::Signals::Stopping->new;
    }

    method to_be_run { @messages || @signals }

    method notify          ($signal)  { push @signals => $signal }
    method enqueue_message ($message) { push @$inbox => $message }

    method prepare {
        $inbox = [];
        $state = Actor::Mailbox::State->RUNNING
            if $state == Actor::Mailbox::State->ALIVE;
    }

    method finish {
        push @messages => @$inbox;
        $inbox = \@messages;
        $state = Actor::Mailbox::State->ALIVE
            if $state == Actor::Mailbox::State->RUNNING;
    }

    method tick {
        my @sigs = @signals;
        @signals = ();

        while (@sigs) {
            my $sig = shift @sigs;

            if ($sig isa Actor::Signals::Started) {
                $state = Actor::Mailbox::State->ALIVE;
                $actor = $props->new_actor;
            }
            elsif ($sig isa Actor::Signals::Terminated) {
                my $child = $sig->ref;

                @children = grep { $_->pid ne $child->pid } @children;

                if (@children == 0) {
                    if ($state == Actor::Mailbox::State->STOPPING) {
                        unshift @signals => Actor::Signals::Stopped->new;
                        last;
                    }
                    elsif ($state == Actor::Mailbox::State->RESTARTING) {
                        unshift @signals => Actor::Signals::Started->new;
                        last;
                    }
                }
            }

            try {
                $actor->signal($context, $sig);
            } catch ($e) {
                chomp $e;

                # Started errors are fatal - can't continue with broken initialization
                if ($sig isa Actor::Signals::Started) {
                    $halted_on = $e;
                    unshift @signals => Actor::Signals::Stopped->new;
                    last;
                }
                # Stopping/Stopped/Terminated errors - log but continue shutdown
                elsif ($sig isa Actor::Signals::Stopping
                    || $sig isa Actor::Signals::Stopped
                    || $sig isa Actor::Signals::Terminated) {
                    # Already in shutdown path, just continue
                }
                # Other signals - defer to supervisor
                else {
                    my $action = $supervisor->supervise( $self, $e );
                    if ($action == $supervisor->HALT) {
                        $halted_on = $e;
                        $self->stop;
                        last;
                    }
                    # RETRY/RESUME don't make sense for signals, treat as continue
                }
            }

            if ($sig isa Actor::Signals::Stopping) {
                if ( @children ) {
                    # wait for the children
                    $state = Actor::Mailbox::State->STOPPING;
                    $_->context->stop foreach @children;
                } else {
                    # if there are no children then
                    # make sure Stopped is the next
                    # thing processed
                    unshift @signals => Actor::Signals::Stopped->new;
                    last;
                }
            }
            elsif ($sig isa Actor::Signals::Restarting) {
                if ( @children ) {
                    # wait for the children
                    $state = Actor::Mailbox::State->RESTARTING;
                    $_->context->stop foreach @children;
                } else {
                    # if there are no children then
                    # restart the actor and make sure
                    # Started is the next signal
                    # that is processed
                    unshift @signals => Actor::Signals::Started->new;
                    last;
                }
            }
            elsif ($sig isa Actor::Signals::Stopped) {
                $state = Actor::Mailbox::State->STOPPED;
                # we can destruct the mailbox here
                $actor    = undef;
                @messages = ();

                # notify the parent of termination
                if ($parent) {
                    $parent->context->notify( Actor::Signals::Terminated->new( ref => $ref, with_error => $halted_on ) );
                }

                # notify the watchers of termination
                if (my @watchers = values %watchers) {
                    foreach my $watcher (@watchers) {
                        $watcher->context->notify( Actor::Signals::Terminated->new( ref => $ref, with_error => $halted_on ) );
                    }
                }

                # and exit
                last;
            }
        }

        unless ($self->is_alive) {
            return;
        }

        my @msgs  = @messages;
        @messages = ();

        my @unhandled;

        while (@msgs) {
            my $msg = shift @msgs;
            try {
                $actor->receive($context, $msg)
                    or push @unhandled => $msg;
            } catch ($e) {
                chomp $e;

                my $action = $supervisor->supervise( $self, $e );

                if ($action == $supervisor->RETRY) {
                    unshift @msgs => $msg;
                }
                elsif ($action == $supervisor->RESUME) {
                    next;
                }
                elsif ($action == $supervisor->HALT) {
                    unshift @messages => @msgs;
                    $halted_on = $e;
                    last;
                }
            }
        }

        return @unhandled;
    }

}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Actor::Mailbox - Actor lifecycle state machine and message queue

=head1 DESCRIPTION

C<Actor::Mailbox> is an internal class that manages an actor's lifecycle
and message processing. Each actor has exactly one Mailbox.

B<This is an internal class.> Users should interact with actors through
L<Actor::Context> and L<Actor::Ref>.

=head1 STATUS

B<Internal> - API may change. Documented for implementors.

=head1 LIFECYCLE STATES

The Mailbox implements a state machine with these states:

    STARTING    Actor is initializing, waiting for Started signal
        ↓
    ALIVE       Actor is ready to process messages
        ↓
    RUNNING     Actor is currently processing (within a tick)
        ↓
    SUSPENDED   Actor is paused (during restart or error handling)
        ↓
    STOPPING    Actor is shutting down, waiting for children
        ↓
    RESTARTING  Actor is restarting, waiting for children
        ↓
    STOPPED     Actor has terminated

=head2 State Transitions

    STARTING → ALIVE         (on Started signal processed)
    ALIVE → RUNNING          (on tick begin)
    RUNNING → ALIVE          (on tick end)
    ALIVE → SUSPENDED        (on stop/restart request)
    SUSPENDED → STOPPING     (when children done, stopping)
    SUSPENDED → RESTARTING   (when children done, restarting)
    STOPPING → STOPPED       (on Stopped signal)
    RESTARTING → STARTING    (loops back for restart)

=head1 MESSAGE PROCESSING

Each tick:

=over 4

=item 1. Process pending signals (lifecycle events)

=item 2. If alive, process pending messages

=item 3. Return unhandled messages (for dead letter queue)

=back

=head1 SIGNAL HANDLING

Signals are processed before messages. Special handling:

=over 4

=item B<Started> - Creates the actor instance, transitions to ALIVE

=item B<Stopping> - Stops children, waits, then sends Stopped

=item B<Restarting> - Stops children, waits, then sends Started

=item B<Stopped> - Destroys actor, notifies parent and watchers

=item B<Terminated> - Received when a child/watched actor stops

=back

=head1 ERROR HANDLING

Errors in signal handlers:

=over 4

=item * C<Started> errors → immediately stop the actor

=item * C<Stopping>/C<Stopped>/C<Terminated> errors → log and continue

=item * Other signals → defer to supervisor

=back

Errors in message handlers are always deferred to the supervisor.

=head1 SUPERVISION

When a message handler throws, the supervisor's C<supervise> method is called.
It returns one of:

=over 4

=item * C<HALT> - Stop the actor

=item * C<RESUME> - Skip the message, continue

=item * C<RETRY> - Re-deliver the message

=back

The C<Restart> supervisor triggers HALT then a restart cycle.

=head1 SEE ALSO

L<Actor::Mailbox::State>, L<Actor>, L<Actor::Context>

=cut

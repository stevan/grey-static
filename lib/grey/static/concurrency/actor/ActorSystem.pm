use v5.42;
use experimental qw[ class ];

use Scalar::Util qw[ refaddr ];

use Actor::Mailbox;
use Actor::Props;
use Actor::Timer;

use ActorSystem::Actors::Root;
use ActorSystem::Actors::DeadLetterQueue;

class ActorSystem {
    field $root;
    field $root_props;

    field %lookup;

    field @mailboxes;
    field $executor;

    field $shutting_down = false;
    field $pid_seq = 0;

    ADJUST {
        # We need to load ScheduledExecutor - it should be loaded via concurrency::util
        # but we create a new instance here for the actor system
        require ScheduledExecutor;
        $executor = ScheduledExecutor->new;
    }

    method executor { $executor }

    method schedule_timer (%options) {
        my $timeout  = $options{after};
        my $callback = $options{callback};

        # ScheduledExecutor uses milliseconds, Yakt API uses seconds
        my $delay_ms = int($timeout * 1000);

        my $timer_id = $executor->schedule_delayed($callback, $delay_ms);

        return Actor::Timer->new(
            executor => $executor,
            timer_id => $timer_id,
        );
    }

    method spawn_actor ($props, $parent=undef) {
        my $mailbox = Actor::Mailbox->new(
            props  => $props,
            system => $self,
            parent => $parent,
            pid    => ++$pid_seq,
        );
        $lookup{ $mailbox->ref->pid } = $mailbox;
        if (my $alias = $mailbox->props->alias ) {
            $lookup{ $alias } = $mailbox;
        }
        push @mailboxes => $mailbox;
        return $mailbox->ref;
    }

    method despawn_actor ($ref) {
        if (my $mailbox = $lookup{ $ref->pid }) {
            delete $lookup{ $ref->pid };
            if (my $alias = $mailbox->props->alias ) {
                delete $lookup{ $alias };
            }
            $mailbox->stop;
        }
    }

    method enqueue_message ($to, $message) {
        if (my $mailbox = $lookup{ $to->pid }) {
            $mailbox->enqueue_message( $message );
        }
        else {
            $lookup{ '//sys/dead_letters' }->enqueue_message(
                ActorSystem::Actors::DeadLetterQueue::DeadLetter->new(
                    to      => $to,
                    message => $message
                )
            );
        }
    }

    method shutdown {
        if ($shutting_down) {
            # already shutting down
        }
        else {
            if ( my $usr = $lookup{ '//usr' } ) {
                $usr->context->stop;
                $shutting_down = true;
            } else {
                $root->context->stop;
            }
        }
    }

    method init ($init) {
        $root_props = Actor::Props->new(
            class => 'ActorSystem::Actors::Root',
            alias => '//',
            args  => { init => $init }
        );
        $self;
    }

    method run_mailboxes {
        my @to_run = grep $_->to_be_run, @mailboxes;

        if (@to_run) {
            # run all the mailboxes ...
            $_->prepare foreach @to_run;
            my @unhandled = map $_->tick, @to_run;
            $_->finish foreach @to_run;

            # handle any unhandled messages
            if (@unhandled) {
                $lookup{ '//sys/dead_letters' }->enqueue_message($_) foreach @unhandled;
            }

            # remove the stopped ones
            @mailboxes = grep !$_->is_stopped, @mailboxes;
        }
    }

    method tick {
        # timers (via ScheduledExecutor)
        $executor->tick;
        # mailboxes
        $self->run_mailboxes;
    }

    method loop_until_done {
        $root = $self->spawn_actor( $root_props );

        while (1) {
            # tick ...
            $self->tick;

            # if we have active timers, loop again
            next if $executor->has_active_timers;

            # if any mailbox is in a transitional state, keep looping
            next if grep { $_->is_stopping || $_->is_restarting || $_->is_starting } @mailboxes;

            # if no timers, see if we have active children ...
            if ( my $usr = $lookup{ '//usr' } ) {
                if ( $usr->is_alive && !$usr->children && !(grep $_->to_be_run, @mailboxes) ) {
                    # nothing more to do
                    $usr->context->stop;
                }
            }

            # only after shutdown will we have no more
            # mailboxes, at which point we exit the loop
            last unless @mailboxes;
        }
    }

    method lookup ($key) {
        $lookup{$key};
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

ActorSystem - The actor system runtime and event loop

=head1 SYNOPSIS

    use grey::static qw[ concurrency::util concurrency::actor ];

    my $sys = ActorSystem->new->init(sub ($context) {
        # Spawn actors, set up timers, etc.
        my $actor = $context->spawn(Actor::Props->new( class => 'MyActor' ));
        $actor->send(SomeMessage->new);
    });

    $sys->loop_until_done;

=head1 DESCRIPTION

C<ActorSystem> is the main entry point for the actor framework. It manages
the event loop, actor lifecycle, and timer scheduling.

The system runs a cooperative multitasking loop that processes:

=over 4

=item 1. Timers - scheduled callbacks via ScheduledExecutor

=item 2. Mailboxes - actor message/signal processing

=back

=head1 METHODS

=head2 new

    my $sys = ActorSystem->new;

Creates a new actor system. Must call C<init> before C<loop_until_done>.

=head2 init($callback)

    $sys->init(sub ($context) { ... });

Initializes the system with a callback that receives the root context.
Use this to spawn your initial actors. Returns C<$self> for chaining.

=head2 loop_until_done

    $sys->loop_until_done;

Runs the event loop until all actors have stopped and there are no pending
timers.

=head2 spawn_actor($props, $parent?)

    my $ref = $sys->spawn_actor($props);
    my $ref = $sys->spawn_actor($props, $parent_ref);

Low-level actor spawning. Prefer using C<< $context->spawn >> instead.

=head2 despawn_actor($ref)

    $sys->despawn_actor($ref);

Stops an actor. Prefer using C<< $context->stop >> instead.

=head2 schedule_timer(%options)

    my $timer = $sys->schedule_timer(
        after    => 1.5,      # seconds
        callback => sub { ... }
    );

Schedules a timer. Returns a timer object that can be cancelled.
Prefer using C<< $context->schedule >> instead.

=head2 shutdown

    $sys->shutdown;

Initiates graceful shutdown of the system.

=head1 ARCHITECTURE

The system creates a hierarchy of actors:

    // (root)
    +-- //sys
    |   +-- //sys/dead_letters
    +-- //usr
        +-- (your actors here)

The C<//usr> actor is the parent of actors you spawn from the init callback.

=head1 SEE ALSO

L<Actor>, L<Actor::Context>, L<Actor::Props>, L<Actor::Ref>

=cut

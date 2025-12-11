#!/usr/bin/env perl

use v5.42;
use Test::More;

use grey::static qw[ concurrency::util concurrency::actor ];

subtest 'ActorSystem can be created' => sub {
    my $sys = ActorSystem->new;
    isa_ok($sys, 'ActorSystem');
    isa_ok($sys->executor, 'ScheduledExecutor');
};

subtest 'ActorSystem init and basic startup' => sub {
    my $init_called = 0;
    my $received_context;

    my $sys = ActorSystem->new->init(sub ($context) {
        $init_called = 1;
        $received_context = $context;
        # Don't spawn any actors - system should shut down gracefully
    });

    isa_ok($sys, 'ActorSystem');
    is($init_called, 0, '... init callback not yet called');

    $sys->loop_until_done;

    is($init_called, 1, '... init callback was called');
    isa_ok($received_context, 'Actor::Context', '... received a context');
};

# Define a simple counter actor for testing
{
    package CounterMessage;
    use v5.42;
    use experimental qw[ class ];
    class CounterMessage :isa(Actor::Message) {
        field $action :param :reader;
        field $amount :param :reader = 1;
    }

    package CounterActor;
    use v5.42;
    use experimental qw[ class ];
    class CounterActor :isa(Actor) {
        field $count = 0;
        method count { $count }

        method receive ($context, $message) {
            return false unless $message isa CounterMessage;

            if ($message->action eq 'increment') {
                $count += $message->amount;
            } elsif ($message->action eq 'decrement') {
                $count -= $message->amount;
            } elsif ($message->action eq 'stop') {
                $context->stop;
            }
            return true;
        }

        method signal ($context, $signal) {
            # No special handling needed
        }
    }
}

subtest 'ActorSystem with a simple actor' => sub {
    my $actor_ref;
    my @events;

    my $sys = ActorSystem->new->init(sub ($context) {
        push @events, 'init';

        $actor_ref = $context->spawn(Actor::Props->new(
            class => 'CounterActor',
        ));

        push @events, 'spawned';

        # Send some messages
        $actor_ref->send(CounterMessage->new( action => 'increment' ));
        $actor_ref->send(CounterMessage->new( action => 'increment', amount => 5 ));
        $actor_ref->send(CounterMessage->new( action => 'decrement', amount => 2 ));
        # Tell the actor to stop
        $actor_ref->send(CounterMessage->new( action => 'stop' ));

        push @events, 'sent_messages';
    });

    $sys->loop_until_done;

    ok($actor_ref, '... actor was spawned');
    is_deeply(\@events, ['init', 'spawned', 'sent_messages'], '... events in order');
};

our @LIFECYCLE_EVENTS;

{
    package LifecycleActor;
    use v5.42;
    use experimental qw[ class ];
    class LifecycleActor :isa(Actor) {
        method signal ($context, $signal) {
            if ($signal isa Actor::Signals::Started) {
                push @main::LIFECYCLE_EVENTS, 'started';
                # Stop ourselves so system can shut down
                $context->stop;
            } elsif ($signal isa Actor::Signals::Stopping) {
                push @main::LIFECYCLE_EVENTS, 'stopping';
            } elsif ($signal isa Actor::Signals::Stopped) {
                push @main::LIFECYCLE_EVENTS, 'stopped';
            }
        }
    }
}

subtest 'ActorSystem shutdown sequence' => sub {
    @LIFECYCLE_EVENTS = ();

    my $sys = ActorSystem->new->init(sub ($context) {
        my $actor = $context->spawn(Actor::Props->new(
            class => 'LifecycleActor',
        ));
    });

    $sys->loop_until_done;

    # Actor should have gone through full lifecycle
    ok(grep(/started/, @LIFECYCLE_EVENTS), '... actor received Started');
    ok(grep(/stopping/, @LIFECYCLE_EVENTS), '... actor received Stopping');
    ok(grep(/stopped/, @LIFECYCLE_EVENTS), '... actor received Stopped');
};

subtest 'ActorSystem timer scheduling' => sub {
    my $timer_fired = 0;

    my $sys = ActorSystem->new->init(sub ($context) {
        $context->schedule(
            after    => 0.01,  # 10ms
            callback => sub {
                $timer_fired = 1;
            }
        );
    });

    $sys->loop_until_done;

    is($timer_fired, 1, '... timer callback was fired');
};

done_testing;

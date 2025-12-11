#!/usr/bin/env perl

use v5.42;
use Test::More;

use grey::static qw[ concurrency::util concurrency::actor ];

subtest 'Actor::Mailbox::State constants' => sub {
    is(Actor::Mailbox::State->STARTING,   0, 'STARTING is 0');
    is(Actor::Mailbox::State->ALIVE,      1, 'ALIVE is 1');
    is(Actor::Mailbox::State->RUNNING,    2, 'RUNNING is 2');
    is(Actor::Mailbox::State->SUSPENDED,  3, 'SUSPENDED is 3');
    is(Actor::Mailbox::State->STOPPING,   4, 'STOPPING is 4');
    is(Actor::Mailbox::State->RESTARTING, 5, 'RESTARTING is 5');
    is(Actor::Mailbox::State->STOPPED,    6, 'STOPPED is 6');
};

subtest 'Actor::Mailbox basic creation' => sub {
    my $props = Actor::Props->new(
        class => 'Actor',
    );

    # We need a mock system for testing
    my $mock_system = bless {}, 'MockSystem';

    my $mailbox = Actor::Mailbox->new(
        props  => $props,
        system => $mock_system,
        parent => undef,
        pid    => 1,
    );

    isa_ok($mailbox, 'Actor::Mailbox');
    ok($mailbox->is_starting, '... mailbox starts in STARTING state');
    ok($mailbox->to_be_run, '... mailbox has signals to process (Started)');
    is($mailbox->ref->pid, 1, '... ref has correct pid');
};

subtest 'Actor::Signals all loaded' => sub {
    isa_ok(Actor::Signals::Signal->new, 'Actor::Signals::Signal');
    isa_ok(Actor::Signals::Started->new, 'Actor::Signals::Started');
    isa_ok(Actor::Signals::Stopping->new, 'Actor::Signals::Stopping');
    isa_ok(Actor::Signals::Stopped->new, 'Actor::Signals::Stopped');
    isa_ok(Actor::Signals::Restarting->new, 'Actor::Signals::Restarting');

    my $ref = Actor::Ref->new(pid => 99);
    isa_ok(Actor::Signals::Terminated->new(ref => $ref), 'Actor::Signals::Terminated');
    isa_ok(Actor::Signals::Ready->new(ref => $ref), 'Actor::Signals::Ready');
};

subtest 'Actor::Supervisors all loaded' => sub {
    isa_ok(Actor::Supervisors::Stop->new, 'Actor::Supervisors::Stop');
    isa_ok(Actor::Supervisors::Resume->new, 'Actor::Supervisors::Resume');
    isa_ok(Actor::Supervisors::Retry->new, 'Actor::Supervisors::Retry');
    isa_ok(Actor::Supervisors::Restart->new, 'Actor::Supervisors::Restart');
};

done_testing;

#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;

use lib 'lib';
use lib 'lib/grey/static/concurrency/util';
use lib 'lib/grey/static/concurrency/actor';

use Executor;
use ScheduledExecutor;
use Actor::Timer;

subtest 'Actor::Timer basic construction' => sub {
    my $executor = ScheduledExecutor->new;
    my $timer_id = $executor->schedule_delayed(sub { }, 100);

    my $timer = Actor::Timer->new(
        executor => $executor,
        timer_id => $timer_id
    );

    ok($timer, '... timer created');
    is($timer->timer_id, $timer_id, '... timer_id matches');
    ok(!$timer->cancelled, '... timer not cancelled initially');
};

subtest 'Actor::Timer cancel' => sub {
    my $executor = ScheduledExecutor->new;
    my $fired = 0;

    my $timer_id = $executor->schedule_delayed(sub { $fired++ }, 10);

    my $timer = Actor::Timer->new(
        executor => $executor,
        timer_id => $timer_id
    );

    ok(!$timer->cancelled, '... timer not cancelled initially');

    $timer->cancel;

    ok($timer->cancelled, '... timer is cancelled after cancel()');

    # Run the executor - timer should not fire
    $executor->run;

    is($fired, 0, '... cancelled timer did not fire');
};

subtest 'Actor::Timer cancel is idempotent' => sub {
    my $executor = ScheduledExecutor->new;
    my $timer_id = $executor->schedule_delayed(sub { }, 100);

    my $timer = Actor::Timer->new(
        executor => $executor,
        timer_id => $timer_id
    );

    # Cancel multiple times - should not error
    $timer->cancel;
    ok($timer->cancelled, '... cancelled after first cancel');

    $timer->cancel;
    ok($timer->cancelled, '... still cancelled after second cancel');

    $timer->cancel;
    ok($timer->cancelled, '... still cancelled after third cancel');
};

subtest 'Non-cancelled timer fires normally' => sub {
    my $executor = ScheduledExecutor->new;
    my $fired = 0;

    my $timer_id = $executor->schedule_delayed(sub { $fired++ }, 5);

    my $timer = Actor::Timer->new(
        executor => $executor,
        timer_id => $timer_id
    );

    # Don't cancel - let it fire
    $executor->run;

    is($fired, 1, '... non-cancelled timer fired');
    ok(!$timer->cancelled, '... timer not marked as cancelled');
};

done_testing;

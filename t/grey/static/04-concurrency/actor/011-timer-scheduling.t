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

# Helper function that bridges Yakt-style API to ScheduledExecutor
# This will be moved to ActorSystem when that's ported
sub schedule_timer ($executor, %options) {
    my $timeout  = $options{after};     # seconds (float)
    my $callback = $options{callback};

    # Convert seconds to milliseconds
    my $delay_ms = int($timeout * 1000);

    # Ensure minimum of 1ms
    $delay_ms = 1 if $delay_ms < 1;

    my $timer_id = $executor->schedule_delayed($callback, $delay_ms);

    return Actor::Timer->new(
        executor => $executor,
        timer_id => $timer_id
    );
}

subtest 'schedule_timer with Yakt-style API' => sub {
    my $executor = ScheduledExecutor->new;
    my $fired = 0;

    my $timer = schedule_timer($executor,
        after    => 0.01,  # 10 milliseconds
        callback => sub { $fired++ }
    );

    isa_ok($timer, 'Actor::Timer');
    ok(!$timer->cancelled, '... timer not cancelled');

    $executor->run;

    is($fired, 1, '... timer fired');
};

subtest 'Multiple timers fire in order' => sub {
    my $executor = ScheduledExecutor->new;
    my @order;

    schedule_timer($executor, after => 0.03, callback => sub { push @order => 3 });
    schedule_timer($executor, after => 0.01, callback => sub { push @order => 1 });
    schedule_timer($executor, after => 0.02, callback => sub { push @order => 2 });

    $executor->run;

    is_deeply(\@order, [1, 2, 3], '... timers fired in correct order');
};

subtest 'Cancelled timer does not fire' => sub {
    my $executor = ScheduledExecutor->new;
    my $fired = 0;
    my $not_cancelled_fired = 0;

    my $timer = schedule_timer($executor,
        after    => 0.02,
        callback => sub { $fired++ }
    );

    # Cancel immediately
    $timer->cancel;

    # Schedule another timer that will fire
    schedule_timer($executor,
        after    => 0.01,
        callback => sub { $not_cancelled_fired++ }
    );

    $executor->run;

    is($fired, 0, '... cancelled timer did not fire');
    is($not_cancelled_fired, 1, '... non-cancelled timer fired');
};

subtest 'Timer can be cancelled by another timer' => sub {
    my $executor = ScheduledExecutor->new;
    my $fired = 0;

    my $timer = schedule_timer($executor,
        after    => 0.05,
        callback => sub { $fired++ }
    );

    # Schedule a timer to cancel the first one
    schedule_timer($executor,
        after    => 0.01,
        callback => sub { $timer->cancel }
    );

    $executor->run;

    is($fired, 0, '... timer cancelled before it could fire');
};

subtest 'Timer with zero delay' => sub {
    my $executor = ScheduledExecutor->new;
    my $fired = 0;

    # Zero delay should be treated as minimum (1ms)
    schedule_timer($executor,
        after    => 0,
        callback => sub { $fired++ }
    );

    $executor->run;

    is($fired, 1, '... zero-delay timer fired');
};

subtest 'Timer with very small delay' => sub {
    my $executor = ScheduledExecutor->new;
    my $fired = 0;

    # Sub-millisecond delay should be treated as minimum (1ms)
    schedule_timer($executor,
        after    => 0.0001,
        callback => sub { $fired++ }
    );

    $executor->run;

    is($fired, 1, '... sub-millisecond timer fired');
};

subtest 'Multiple timers at same time' => sub {
    my $executor = ScheduledExecutor->new;
    my @fired;

    # All at 10ms
    schedule_timer($executor, after => 0.01, callback => sub { push @fired => 'a' });
    schedule_timer($executor, after => 0.01, callback => sub { push @fired => 'b' });
    schedule_timer($executor, after => 0.01, callback => sub { push @fired => 'c' });

    $executor->run;

    is(scalar(@fired), 3, '... all three timers fired');
    is_deeply([sort @fired], ['a', 'b', 'c'], '... all timers present');
};

subtest 'Timer callback can schedule more timers' => sub {
    my $executor = ScheduledExecutor->new;
    my $count = 0;

    schedule_timer($executor,
        after    => 0.01,
        callback => sub {
            $count++;
            if ($count < 3) {
                schedule_timer($executor,
                    after    => 0.01,
                    callback => __SUB__  # Recurse
                );
            }
        }
    );

    $executor->run;

    is($count, 3, '... timer scheduled more timers recursively');
};

done_testing;

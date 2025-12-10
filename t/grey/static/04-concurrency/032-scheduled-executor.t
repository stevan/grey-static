#!/usr/bin/env perl
# Test ScheduledExecutor - Real-time timer scheduling with Executor

use v5.42;
use Test::More;
use Time::HiRes ();

use grey::static qw[ concurrency::util ];

# Test ScheduledExecutor construction
subtest 'ScheduledExecutor construction' => sub {
    my $executor = ScheduledExecutor->new;

    isa_ok($executor, 'ScheduledExecutor');
    isa_ok($executor, 'Executor', 'ScheduledExecutor extends Executor');
    ok($executor->current_time > 0, 'starts with current monotonic time');
    is($executor->timer_count, 0, 'starts with no timers');
};

# Test basic delayed execution
subtest 'schedule_delayed basic functionality' => sub {
    my $executor = ScheduledExecutor->new;
    my @results;
    my $start = $executor->now;

    $executor->schedule_delayed(sub { push @results, 'A' }, 100);
    $executor->schedule_delayed(sub { push @results, 'B' }, 50);
    $executor->schedule_delayed(sub { push @results, 'C' }, 150);

    is_deeply(\@results, [], 'callbacks not executed yet');

    $executor->run;

    is_deeply(\@results, ['B', 'A', 'C'], 'callbacks executed in time order');

    my $elapsed = ($executor->now - $start) * 1000;  # Convert to ms
    cmp_ok($elapsed, '>=', 150, 'at least 150ms elapsed');
    cmp_ok($elapsed, '<', 250, 'but less than 250ms (with margin)');
};

# Test now() returns current monotonic time
subtest 'now() returns current monotonic time' => sub {
    my $executor = ScheduledExecutor->new;

    my $t1 = $executor->now;
    Time::HiRes::sleep(0.01);  # Sleep 10ms
    my $t2 = $executor->now;

    ok($t2 > $t1, 'time advances with real time');
    my $diff = ($t2 - $t1) * 1000;
    cmp_ok($diff, '>=', 10, 'at least 10ms passed');
};

# Test wait() actually sleeps
subtest 'wait() sleeps for duration' => sub {
    my $executor = ScheduledExecutor->new;

    my $start = $executor->now;
    $executor->wait(0.05);  # Wait 50ms
    my $end = $executor->now;

    my $elapsed = ($end - $start) * 1000;
    cmp_ok($elapsed, '>=', 50, 'at least 50ms elapsed');
    cmp_ok($elapsed, '<', 100, 'but less than 100ms');
};

# Test cancel_scheduled
subtest 'cancel scheduled callback' => sub {
    my $executor = ScheduledExecutor->new;
    my @results;

    my $id1 = $executor->schedule_delayed(sub { push @results, 'A' }, 100);
    my $id2 = $executor->schedule_delayed(sub { push @results, 'B' }, 50);
    my $id3 = $executor->schedule_delayed(sub { push @results, 'C' }, 150);

    # Cancel the middle callback
    my $cancelled = $executor->cancel_scheduled($id2);
    is($cancelled, 1, 'cancel_scheduled returns 1 for success');

    $executor->run;

    is_deeply(\@results, ['A', 'C'], 'cancelled callback did not execute');
};

# Test cancelling non-existent timer
subtest 'cancel non-existent timer' => sub {
    my $executor = ScheduledExecutor->new;

    my $cancelled = $executor->cancel_scheduled(999);
    is($cancelled, 0, 'cancel_scheduled returns 0 for non-existent timer');
};

# Test immediate callbacks (delay = 0)
subtest 'immediate callbacks (delay 0)' => sub {
    my $executor = ScheduledExecutor->new;
    my @results;

    $executor->schedule_delayed(sub { push @results, 'immediate' }, 0);
    $executor->schedule_delayed(sub { push @results, 'delayed' }, 50);

    $executor->run;

    is_deeply(\@results, ['immediate', 'delayed'], 'delay-0 callback executes first');
};

# Test chaining callbacks
subtest 'callbacks can schedule more callbacks' => sub {
    my $executor = ScheduledExecutor->new;
    my @results;

    $executor->schedule_delayed(sub {
        push @results, 'first';
        $executor->schedule_delayed(sub { push @results, 'nested' }, 50);
    }, 50);

    $executor->run;

    is_deeply(\@results, ['first', 'nested'], 'nested callback executes');
};

# Test empty executor completes immediately
subtest 'empty executor completes immediately' => sub {
    my $executor = ScheduledExecutor->new;

    my $start = $executor->now;
    $executor->run;
    my $end = $executor->now;

    my $elapsed = ($end - $start) * 1000;
    cmp_ok($elapsed, '<', 10, 'completes quickly (< 10ms)');
    pass('run() completed without hanging');
};

# Test multiple timers at same time
subtest 'multiple callbacks at same time' => sub {
    my $executor = ScheduledExecutor->new;
    my @results;

    $executor->schedule_delayed(sub { push @results, 'A' }, 100);
    $executor->schedule_delayed(sub { push @results, 'B' }, 100);
    $executor->schedule_delayed(sub { push @results, 'C' }, 100);

    $executor->run;

    is(scalar @results, 3, 'all three callbacks executed');
    is_deeply([sort @results], ['A', 'B', 'C'], 'all callbacks fired');
};

# Test executor integration with next_tick
subtest 'schedule_delayed works with next_tick' => sub {
    my $executor = ScheduledExecutor->new;
    my @results;

    # Mix delayed and immediate callbacks
    $executor->next_tick(sub { push @results, 'tick1' });
    $executor->schedule_delayed(sub { push @results, 'delayed1' }, 100);
    $executor->next_tick(sub { push @results, 'tick2' });
    $executor->schedule_delayed(sub { push @results, 'delayed2' }, 50);

    $executor->run;

    is_deeply(\@results, ['tick1', 'tick2', 'delayed2', 'delayed1'],
        'next_tick callbacks run before delayed timers');
};

# Test schedule_delayed returns unique IDs
subtest 'schedule_delayed returns unique IDs' => sub {
    my $executor = ScheduledExecutor->new;

    my $id1 = $executor->schedule_delayed(sub { }, 100);
    my $id2 = $executor->schedule_delayed(sub { }, 200);
    my $id3 = $executor->schedule_delayed(sub { }, 300);

    isnt($id1, $id2, 'ID 1 and 2 are different');
    isnt($id2, $id3, 'ID 2 and 3 are different');
    isnt($id1, $id3, 'ID 1 and 3 are different');
};

# Test timer tracking
subtest 'timer tracking' => sub {
    my $executor = ScheduledExecutor->new;

    $executor->schedule_delayed(sub { }, 100);
    $executor->schedule_delayed(sub { }, 200);

    is($executor->timer_count, 2, 'executor tracks scheduled timers');

    $executor->run;

    is($executor->timer_count, 0, 'executor empty after all timers fire');
};

# Test has_active_timers
subtest 'has_active_timers' => sub {
    my $executor = ScheduledExecutor->new;

    ok(!$executor->has_active_timers, 'no active timers initially');

    $executor->schedule_delayed(sub { }, 100);

    ok($executor->has_active_timers, 'has active timers after scheduling');

    $executor->run;

    ok(!$executor->has_active_timers, 'no active timers after run completes');
};

# Test should_wait calculation
subtest 'should_wait calculation' => sub {
    my $executor = ScheduledExecutor->new;

    is($executor->should_wait, 0, 'should_wait is 0 with no timers');

    $executor->schedule_delayed(sub { }, 100);

    my $wait = $executor->should_wait;
    cmp_ok($wait, '>', 0, 'should_wait is positive with pending timer');
    cmp_ok($wait, '<=', 0.1, 'should_wait is <= 100ms (0.1s)');
};

done_testing;

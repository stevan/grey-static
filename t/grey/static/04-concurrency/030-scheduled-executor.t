#!/usr/bin/env perl
# Test ScheduledExecutor - Timer::Wheel + Executor integration

use v5.42;
use Test::More;

use grey::static qw[ concurrency::util ];

# Test ScheduledExecutor construction
subtest 'ScheduledExecutor construction' => sub {
    my $executor = ScheduledExecutor->new;

    isa_ok($executor, 'ScheduledExecutor');
    isa_ok($executor, 'Executor', 'ScheduledExecutor extends Executor');
    is($executor->current_time, 0, 'starts at time 0');
    is($executor->timer_count, 0, 'starts with no timers');
};

# Test basic delayed execution
subtest 'schedule_delayed basic functionality' => sub {
    my $executor = ScheduledExecutor->new;
    my @results;

    $executor->schedule_delayed(sub { push @results, 'A' }, 10);
    $executor->schedule_delayed(sub { push @results, 'B' }, 5);
    $executor->schedule_delayed(sub { push @results, 'C' }, 15);

    is_deeply(\@results, [], 'callbacks not executed yet');

    $executor->run;

    is_deeply(\@results, ['B', 'A', 'C'], 'callbacks executed in time order');
    is($executor->current_time, 15, 'time advanced to last callback');
};

# Test current_time tracking
subtest 'current_time advances correctly' => sub {
    my $executor = ScheduledExecutor->new;
    my @times;

    $executor->schedule_delayed(sub { push @times, $executor->current_time }, 5);
    $executor->schedule_delayed(sub { push @times, $executor->current_time }, 10);
    $executor->schedule_delayed(sub { push @times, $executor->current_time }, 20);

    $executor->run;

    is_deeply(\@times, [5, 10, 20], 'time tracks correctly at each callback');
};

# Test cancel_scheduled
subtest 'cancel scheduled callback' => sub {
    my $executor = ScheduledExecutor->new;
    my @results;

    my $id1 = $executor->schedule_delayed(sub { push @results, 'A' }, 10);
    my $id2 = $executor->schedule_delayed(sub { push @results, 'B' }, 5);
    my $id3 = $executor->schedule_delayed(sub { push @results, 'C' }, 15);

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
    $executor->schedule_delayed(sub { push @results, 'delayed' }, 5);

    $executor->run;

    is_deeply(\@results, ['immediate', 'delayed'], 'delay-0 callback executes first');
};

# Test chaining callbacks
subtest 'callbacks can schedule more callbacks' => sub {
    my $executor = ScheduledExecutor->new;
    my @results;

    $executor->schedule_delayed(sub {
        push @results, 'first';
        $executor->schedule_delayed(sub { push @results, 'nested' }, 5);
    }, 10);

    $executor->run;

    is_deeply(\@results, ['first', 'nested'], 'nested callback executes');
    is($executor->current_time, 15, 'time advances for nested callback');
};

# Test empty executor completes immediately
subtest 'empty executor completes immediately' => sub {
    my $executor = ScheduledExecutor->new;

    # This should return immediately
    $executor->run;

    is($executor->current_time, 0, 'time unchanged for empty executor');
    pass('run() completed without hanging');
};

# Test multiple timers at same time
subtest 'multiple callbacks at same time' => sub {
    my $executor = ScheduledExecutor->new;
    my @results;

    $executor->schedule_delayed(sub { push @results, 'A' }, 10);
    $executor->schedule_delayed(sub { push @results, 'B' }, 10);
    $executor->schedule_delayed(sub { push @results, 'C' }, 10);

    $executor->run;

    is(scalar @results, 3, 'all three callbacks executed');
    is_deeply([sort @results], ['A', 'B', 'C'], 'all callbacks fired (order may vary)');
};

# Test large time values
subtest 'large delay values' => sub {
    my $executor = ScheduledExecutor->new;
    my $fired = 0;

    $executor->schedule_delayed(sub { $fired = 1 }, 1000);
    $executor->run;

    is($fired, 1, 'callback with large delay executed');
    is($executor->current_time, 1000, 'time advanced to large value');
};

# Test executor integration with next_tick
subtest 'schedule_delayed works with next_tick' => sub {
    my $executor = ScheduledExecutor->new;
    my @results;

    # Mix delayed and immediate callbacks
    $executor->next_tick(sub { push @results, 'tick1' });
    $executor->schedule_delayed(sub { push @results, 'delayed1' }, 10);
    $executor->next_tick(sub { push @results, 'tick2' });
    $executor->schedule_delayed(sub { push @results, 'delayed2' }, 5);

    $executor->run;

    is_deeply(\@results, ['tick1', 'tick2', 'delayed2', 'delayed1'],
        'next_tick callbacks run before advancing time');
};

# Test schedule_delayed returns unique IDs
subtest 'schedule_delayed returns unique IDs' => sub {
    my $executor = ScheduledExecutor->new;

    my $id1 = $executor->schedule_delayed(sub { }, 10);
    my $id2 = $executor->schedule_delayed(sub { }, 20);
    my $id3 = $executor->schedule_delayed(sub { }, 30);

    isnt($id1, $id2, 'ID 1 and 2 are different');
    isnt($id2, $id3, 'ID 2 and 3 are different');
    isnt($id1, $id3, 'ID 1 and 3 are different');
};

# Test timer tracking
subtest 'timer tracking' => sub {
    my $executor = ScheduledExecutor->new;

    $executor->schedule_delayed(sub { }, 10);
    $executor->schedule_delayed(sub { }, 20);

    is($executor->timer_count, 2, 'executor tracks scheduled timers');

    $executor->run;

    is($executor->timer_count, 0, 'executor empty after all timers fire');
};

done_testing;

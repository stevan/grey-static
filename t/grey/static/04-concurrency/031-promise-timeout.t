#!/usr/bin/env perl
# Test Promise timeout() and delay() methods

use v5.42;
use Test::More;

use grey::static qw[ concurrency::util ];

# Test timeout() with promise that resolves before timeout
subtest 'timeout - promise resolves before timeout' => sub {
    my $executor = ScheduledExecutor->new;
    my $promise = Promise->new(executor => $executor);
    my $result;

    $promise->timeout(100, $executor)
        ->then(
            sub ($value) { $result = "Success: $value" },
            sub ($error) { $result = "Error: $error" }
        );

    # Resolve after 50ms (before 100ms timeout)
    my $start = $executor->current_time;
    $executor->schedule_delayed(sub { $promise->resolve("Done!") }, 50);

    $executor->run;

    my $elapsed = $executor->current_time - $start;
    is($result, "Success: Done!", 'promise resolved before timeout');
    cmp_ok($elapsed, '>=', 50, 'at least 50ms elapsed');
    cmp_ok($elapsed, '<', 100, 'less than 100ms elapsed');
};

# Test timeout() with promise that times out
subtest 'timeout - promise times out' => sub {
    my $executor = ScheduledExecutor->new;
    my $promise = Promise->new(executor => $executor);
    my $result;

    $promise->timeout(30, $executor)
        ->then(
            sub ($value) { $result = "Success: $value" },
            sub ($error) { $result = "Error: $error" }
        );

    # Resolve after 50ms (after 30ms timeout)
    my $start = $executor->current_time;
    $executor->schedule_delayed(sub { $promise->resolve("Too late!") }, 50);

    $executor->run;

    my $elapsed = $executor->current_time - $start;
    like($result, qr/Error: Timeout after 30ms/, 'promise timed out');
    cmp_ok($elapsed, '>=', 30, 'at least 30ms elapsed (timed out)');
};

# Test timeout() with promise that rejects before timeout
subtest 'timeout - promise rejects before timeout' => sub {
    my $executor = ScheduledExecutor->new;
    my $promise = Promise->new(executor => $executor);
    my $result;

    $promise->timeout(100, $executor)
        ->then(
            sub ($value) { $result = "Success: $value" },
            sub ($error) { $result = "Error: $error" }
        );

    # Reject after 50ms (before 100ms timeout)
    my $start = $executor->current_time;
    $executor->schedule_delayed(sub { $promise->reject("Failed!") }, 50);

    $executor->run;

    my $elapsed = $executor->current_time - $start;
    is($result, "Error: Failed!", 'promise rejected before timeout');
    cmp_ok($elapsed, '>=', 50, 'at least 50ms elapsed');
    cmp_ok($elapsed, '<', 100, 'less than 100ms elapsed');
};

# Test timeout() with immediately resolved promise
subtest 'timeout - immediately resolved promise' => sub {
    my $executor = ScheduledExecutor->new;
    my $promise = Promise->new(executor => $executor);
    my $result;

    # Resolve immediately
    $promise->resolve("Immediate!");

    my $start = $executor->current_time;
    $promise->timeout(100, $executor)
        ->then(
            sub ($value) { $result = "Success: $value" },
            sub ($error) { $result = "Error: $error" }
        );

    $executor->run;

    my $elapsed = $executor->current_time - $start;
    is($result, "Success: Immediate!", 'immediately resolved promise works with timeout');
    cmp_ok($elapsed, '<', 5, 'minimal time elapsed (no delays scheduled)');
};

# Test delay() factory method
subtest 'delay - basic delayed resolution' => sub {
    my $executor = ScheduledExecutor->new;
    my $result;

    my $start = $executor->current_time;
    Promise->delay("Hello", 10, $executor)
        ->then(sub ($msg) { $result = $msg });

    $executor->run;

    my $elapsed = $executor->current_time - $start;
    is($result, "Hello", 'delayed promise resolved with correct value');
    cmp_ok($elapsed, '>=', 10, 'at least 10ms elapsed');
    cmp_ok($elapsed, '<', 30, 'less than 30ms elapsed');
};

# Test delay() with promise chaining
subtest 'delay - chaining with transformations' => sub {
    my $executor = ScheduledExecutor->new;
    my $result;

    my $start = $executor->current_time;
    Promise->delay(5, 10, $executor)
        ->then(sub ($x) { $x * 2 })
        ->then(sub ($x) { $x + 3 })
        ->then(sub ($x) { $result = $x });

    $executor->run;

    my $elapsed = $executor->current_time - $start;
    is($result, 13, 'delayed promise chains correctly');
    cmp_ok($elapsed, '>=', 10, 'at least 10ms elapsed');
    cmp_ok($elapsed, '<', 30, 'less than 30ms elapsed');
};

# Test delay() with zero delay
subtest 'delay - zero delay' => sub {
    my $executor = ScheduledExecutor->new;
    my $result;

    my $start = $executor->current_time;
    Promise->delay("Immediate", 0, $executor)
        ->then(sub ($msg) { $result = $msg });

    $executor->run;

    my $elapsed = $executor->current_time - $start;
    is($result, "Immediate", 'zero delay works (enforced minimum of 1ms)');
    # With real-time execution, callback may fire very quickly
    cmp_ok($elapsed, '<', 10, 'completes quickly (< 10ms)');
};

# Test chaining delayed promises
subtest 'delay - chaining multiple delays' => sub {
    my $executor = ScheduledExecutor->new;
    my @results;

    my $start = $executor->current_time;
    Promise->delay("A", 10, $executor)
        ->then(sub ($x) {
            push @results, $x;
            return Promise->delay("B", 5, $executor);
        })
        ->then(sub ($x) {
            push @results, $x;
        });

    $executor->run;

    my $elapsed = $executor->current_time - $start;
    is_deeply(\@results, ["A", "B"], 'multiple delays chain correctly');
    cmp_ok($elapsed, '>=', 15, 'at least 15ms elapsed (10+5)');
    cmp_ok($elapsed, '<', 40, 'less than 40ms elapsed');
};

# Test timeout() with delayed promise
subtest 'timeout - delayed promise completes before timeout' => sub {
    my $executor = ScheduledExecutor->new;
    my $result;

    my $start = $executor->current_time;
    Promise->delay("Success", 20, $executor)
        ->timeout(50, $executor)
        ->then(
            sub ($value) { $result = "Got: $value" },
            sub ($error) { $result = "Error: $error" }
        );

    $executor->run;

    my $elapsed = $executor->current_time - $start;
    is($result, "Got: Success", 'delayed promise completes before timeout');
    cmp_ok($elapsed, '>=', 20, 'at least 20ms elapsed');
    cmp_ok($elapsed, '<', 50, 'less than 50ms elapsed (no timeout)');
};

# Test timeout() with delayed promise that times out
subtest 'timeout - delayed promise times out' => sub {
    my $executor = ScheduledExecutor->new;
    my $result;

    my $start = $executor->current_time;
    Promise->delay("Too slow", 100, $executor)
        ->timeout(30, $executor)
        ->then(
            sub ($value) { $result = "Got: $value" },
            sub ($error) { $result = "Error: $error" }
        );

    $executor->run;

    my $elapsed = $executor->current_time - $start;
    like($result, qr/Error: Timeout after 30ms/, 'delayed promise times out');
    cmp_ok($elapsed, '>=', 30, 'at least 30ms elapsed (timed out)');
};

# Test complex promise chain with multiple timeouts
subtest 'timeout - complex promise chain' => sub {
    my $executor = ScheduledExecutor->new;
    my @results;

    my $fetch_user = sub ($id) {
        return Promise->delay("User_$id", 10, $executor)
            ->timeout(20, $executor);
    };

    my $fetch_posts = sub ($user) {
        push @results, $user;
        return Promise->delay(["Post1", "Post2"], 15, $executor)
            ->timeout(25, $executor);
    };

    my $start = $executor->current_time;
    $fetch_user->(123)
        ->then($fetch_posts)
        ->then(
            sub ($posts) { push @results, join(",", @$posts) },
            sub ($err)   { push @results, "Failed: $err" }
        );

    $executor->run;

    my $elapsed = $executor->current_time - $start;
    is_deeply(\@results, ["User_123", "Post1,Post2"], 'complex chain with timeouts works');
    cmp_ok($elapsed, '>=', 25, 'at least 25ms elapsed (10+15)');
    cmp_ok($elapsed, '<', 60, 'less than 60ms elapsed');
};

# Test timeout() with invalid executor
subtest 'timeout - invalid executor type' => sub {
    my $executor = Executor->new;  # Regular Executor, not ScheduledExecutor
    my $promise = Promise->new(executor => $executor);

    eval { $promise->timeout(10, $executor) };

    like($@, qr/Invalid executor for timeout/, 'rejects non-ScheduledExecutor');
};

# Test delay() with invalid executor
subtest 'delay - invalid executor type' => sub {
    my $executor = Executor->new;  # Regular Executor, not ScheduledExecutor

    eval { Promise->delay("test", 10, $executor) };

    like($@, qr/Invalid executor for delay/, 'rejects non-ScheduledExecutor');
};

# Test timeout timer is properly cancelled
subtest 'timeout - timer cancellation' => sub {
    my $executor = ScheduledExecutor->new;
    my $promise = Promise->new(executor => $executor);
    my $result;

    $promise->timeout(100, $executor)
        ->then(
            sub ($value) { $result = "Success: $value" },
            sub ($error) { $result = "Error: $error" }
        );

    # Resolve before timeout
    $executor->schedule_delayed(sub { $promise->resolve("Done!") }, 50);

    $executor->run;

    # Check that timer was cancelled (executor should be empty)
    is($executor->timer_count, 0, 'timeout timer was cancelled after resolution');
    is($result, "Success: Done!", 'promise resolved successfully');
};

# Test multiple handlers on timeout promise
subtest 'timeout - multiple handlers' => sub {
    my $executor = ScheduledExecutor->new;
    my $promise = Promise->new(executor => $executor);
    my @results;

    my $timeout_promise = $promise->timeout(100, $executor);

    $timeout_promise->then(sub ($x) { push @results, "Handler1: $x" });
    $timeout_promise->then(sub ($x) { push @results, "Handler2: $x" });
    $timeout_promise->then(sub ($x) { push @results, "Handler3: $x" });

    $executor->schedule_delayed(sub { $promise->resolve("Done!") }, 50);

    $executor->run;

    is_deeply(
        [sort @results],
        ["Handler1: Done!", "Handler2: Done!", "Handler3: Done!"],
        'multiple handlers work on timeout promise'
    );
};

done_testing;

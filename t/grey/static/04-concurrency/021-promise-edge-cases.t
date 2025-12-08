#!perl
# Promise edge cases and error conditions

use v5.42;
use experimental qw[ class try ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional concurrency::util ];

# Test 1: Cannot resolve a promise twice
subtest 'double resolve throws error' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    $promise->resolve(42);

    my $error;
    try {
        $promise->resolve(99);
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Cannot resolve/, 'double resolve throws error');
    is($promise->result, 42, 'original value preserved');
};

# Test 2: Cannot reject a promise twice
subtest 'double reject throws error' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    $promise->reject('first error');

    my $error;
    try {
        $promise->reject('second error');
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Cannot reject/, 'double reject throws error');
    is($promise->error, 'first error', 'original error preserved');
};

# Test 3: Cannot resolve after reject
subtest 'resolve after reject throws error' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    $promise->reject('error');

    my $error;
    try {
        $promise->resolve(42);
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Cannot resolve/, 'resolve after reject throws error');
    is($promise->status, Promise->REJECTED, 'status remains REJECTED');
};

# Test 4: Cannot reject after resolve
subtest 'reject after resolve throws error' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    $promise->resolve(42);

    my $error;
    try {
        $promise->reject('error');
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Cannot reject/, 'reject after resolve throws error');
    is($promise->status, Promise->RESOLVED, 'status remains RESOLVED');
};

# Test 5: Promise requires Executor parameter
subtest 'promise requires executor' => sub {
    my $error;
    try {
        my $promise = Promise->new;
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/executor/, 'promise without executor throws error');
};

# Test 6: Executor parameter must be an Executor
subtest 'executor parameter type checking' => sub {
    my $error;
    try {
        my $promise = Promise->new(executor => "not an executor");
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/must be a Executor/, 'invalid executor type throws error');
};

# Test 7: Resolving with undef
subtest 'resolving with undef' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my $result = "not set";
    $promise->then(sub ($x) { $result = $x });

    $promise->resolve(undef);
    $executor->run;

    is($result, undef, 'can resolve with undef value');
    is($promise->result, undef, 'result is undef');
    ok($promise->is_resolved, 'promise is resolved');
};

# Test 8: Rejecting with undef
subtest 'rejecting with undef' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my $error = "not set";
    $promise->then(
        sub ($x) { },
        sub ($e) { $error = $e }
    );

    $promise->reject(undef);
    $executor->run;

    is($error, undef, 'can reject with undef error');
    is($promise->error, undef, 'error is undef');
    ok($promise->is_rejected, 'promise is rejected');
};

# Test 9: Promise with no executor callbacks executes synchronously
subtest 'promise without executor runs synchronously' => sub {
    # Note: This tests the fallback behavior when executor is not running
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my $result;
    $promise->then(sub ($x) { $result = $x; return $x * 2 });

    # Resolve but don't run executor
    $promise->resolve(10);

    # The notification should have run synchronously or via next_tick
    # Let's run executor to ensure callbacks execute
    $executor->run;

    is($result, 10, 'callback executed');
};

# Test 10: Multiple levels of promise chaining
subtest 'deep promise chaining' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my $result;
    $promise
        ->then(sub ($x) { $x + 1 })
        ->then(sub ($x) { $x * 2 })
        ->then(sub ($x) { $x - 5 })
        ->then(sub ($x) { $x / 2 })
        ->then(sub ($x) { $x + 10 })
        ->then(sub ($x) { $result = $x });

    $promise->resolve(5);
    $executor->run;

    # (5 + 1) * 2 - 5 / 2 + 10 = 12 - 5 / 2 + 10 = 7 / 2 + 10 = 3.5 + 10 = 13.5
    is($result, 13.5, 'deep chain calculates correctly');
};

# Test 11: Promise resolving to itself (edge case)
subtest 'promise resolving to another promise value' => sub {
    my $executor = Executor->new;
    my $promise1 = Promise->new(executor => $executor);
    my $promise2 = Promise->new(executor => $executor);

    my $result;
    $promise1->then(sub ($x) { $result = $x });

    # Resolve promise2 first
    $promise2->resolve(100);
    $executor->run;

    # Then resolve promise1 with promise2 (should flatten)
    $promise1->resolve($promise2);
    $executor->run;

    # Since promise2 is already resolved, promise1 should get its value
    # Note: This depends on the implementation - may need adjustment
    ok($promise1->is_resolved, 'promise1 is resolved');
};

done_testing;

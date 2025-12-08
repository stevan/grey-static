#!perl
# Basic Promise tests - creation, resolve, reject, then chaining

use v5.42;
use experimental qw[ class try ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional concurrency::util ];

# Test 1: Promise creation
subtest 'promise creation' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    ok($promise, 'created a Promise');
    isa_ok($promise, 'Promise', 'correct type');
    is($promise->status, Promise->IN_PROGRESS, 'starts in IN_PROGRESS state');
    ok($promise->is_in_progress, 'is_in_progress returns true');
    ok(!$promise->is_resolved, 'is_resolved returns false');
    ok(!$promise->is_rejected, 'is_rejected returns false');
    is($promise->result, undef, 'result is undef initially');
    is($promise->error, undef, 'error is undef initially');
};

# Test 2: Promise resolution
subtest 'promise resolution' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my $resolved_value;
    $promise->then(sub ($value) { $resolved_value = $value });

    $promise->resolve(42);
    $executor->run;

    is($promise->status, Promise->RESOLVED, 'status is RESOLVED');
    ok($promise->is_resolved, 'is_resolved returns true');
    ok(!$promise->is_in_progress, 'is_in_progress returns false');
    ok(!$promise->is_rejected, 'is_rejected returns false');
    is($promise->result, 42, 'result is set correctly');
    is($resolved_value, 42, 'then callback received correct value');
};

# Test 3: Promise rejection
subtest 'promise rejection' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my $rejected_value;
    $promise->then(
        sub ($value) { },
        sub ($error) { $rejected_value = $error }
    );

    $promise->reject('error message');
    $executor->run;

    is($promise->status, Promise->REJECTED, 'status is REJECTED');
    ok($promise->is_rejected, 'is_rejected returns true');
    ok(!$promise->is_in_progress, 'is_in_progress returns false');
    ok(!$promise->is_resolved, 'is_resolved returns false');
    is($promise->error, 'error message', 'error is set correctly');
    is($rejected_value, 'error message', 'catch callback received correct error');
};

# Test 4: Promise chaining
subtest 'promise chaining' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my @results;
    $promise
        ->then(sub ($x) { push @results => "first:$x"; $x * 2 })
        ->then(sub ($x) { push @results => "second:$x"; $x + 1 })
        ->then(sub ($x) { push @results => "third:$x"; $x });

    $promise->resolve(5);
    $executor->run;

    eq_or_diff(
        \@results,
        ['first:5', 'second:10', 'third:11'],
        'chained promises execute in order with correct values'
    );
};

# Test 5: then with only resolve callback
subtest 'then with only resolve callback' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my $result;
    $promise->then(sub ($value) { $result = $value });

    $promise->resolve('success');
    $executor->run;

    is($result, 'success', 'resolve callback executed');
};

# Test 6: Multiple then calls on same promise
subtest 'multiple then calls on same promise' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my @results;
    $promise->then(sub ($x) { push @results => "a:$x" });
    $promise->then(sub ($x) { push @results => "b:$x" });
    $promise->then(sub ($x) { push @results => "c:$x" });

    $promise->resolve(42);
    $executor->run;

    eq_or_diff(
        [sort @results],
        ['a:42', 'b:42', 'c:42'],
        'all then callbacks are executed'
    );
};

# Test 7: then called after promise is resolved
subtest 'then called after promise is resolved' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    $promise->resolve(10);
    $executor->run;

    my $result;
    $promise->then(sub ($x) { $result = $x });
    $executor->run;

    is($result, 10, 'then callback executes even when added after resolution');
};

# Test 8: then called after promise is rejected
subtest 'then called after promise is rejected' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    $promise->reject('error');
    $executor->run;

    my $error;
    $promise->then(
        sub ($x) { },
        sub ($e) { $error = $e }
    );
    $executor->run;

    is($error, 'error', 'catch callback executes even when added after rejection');
};

done_testing;

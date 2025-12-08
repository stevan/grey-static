#!perl
# Advanced Promise tests - flattening, error propagation, edge cases

use v5.42;
use experimental qw[ class try ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional concurrency::util ];

# Test 1: Promise flattening - then returns a promise
subtest 'promise flattening' => sub {
    my $executor = Executor->new;
    my $promise1 = Promise->new(executor => $executor);

    my @results;
    $promise1
        ->then(sub ($x) {
            push @results => "first:$x";
            my $inner = Promise->new(executor => $executor);
            $executor->next_tick(sub { $inner->resolve($x * 2) });
            return $inner;
        })
        ->then(sub ($x) {
            push @results => "second:$x";
            return $x + 1;
        });

    $promise1->resolve(5);
    $executor->run;

    eq_or_diff(
        \@results,
        ['first:5', 'second:10'],
        'promise returned from then is flattened correctly'
    );
};

# Test 2: Error in then callback propagates to catch
subtest 'error in then callback propagates' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my $caught_error;
    $promise
        ->then(sub ($x) { die "intentional error\n" })
        ->then(
            sub ($x) { fail('should not execute resolve callback') },
            sub ($e) { $caught_error = $e }
        );

    $promise->resolve(42);
    $executor->run;

    is($caught_error, 'intentional error', 'error from then callback caught');
};

# Test 3: Error propagation through chain
subtest 'error propagation through chain' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my @results;
    $promise
        ->then(sub ($x) { push @results => "first"; die "error\n" })
        ->then(sub ($x) { push @results => "second:skip"; $x })
        ->then(sub ($x) { push @results => "third:skip"; $x })
        ->then(
            sub ($x) { push @results => "fourth:skip" },
            sub ($e) { push @results => "caught:$e" }
        );

    $promise->resolve(1);
    $executor->run;

    eq_or_diff(
        \@results,
        ['first', 'caught:error'],
        'error skips intermediate then callbacks until caught'
    );
};

# Test 4: Rejection propagates through chain
subtest 'rejection propagation through chain' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my @results;
    $promise
        ->then(sub ($x) { push @results => "skip"; $x })
        ->then(sub ($x) { push @results => "skip2"; $x })
        ->then(
            sub ($x) { push @results => "skip3" },
            sub ($e) { push @results => "caught:$e" }
        );

    $promise->reject('initial error');
    $executor->run;

    eq_or_diff(
        \@results,
        ['caught:initial error'],
        'rejection propagates directly to catch handler'
    );
};

# Test 5: Catch handler can recover and continue chain
subtest 'catch handler recovery' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my @results;
    $promise
        ->then(sub ($x) { die "error\n" })
        ->then(
            sub ($x) { push @results => "skip" },
            sub ($e) {
                push @results => "caught";
                return 100;  # Recover with new value
            }
        )
        ->then(sub ($x) { push @results => "continued:$x"; $x });

    $promise->resolve(1);
    $executor->run;

    eq_or_diff(
        \@results,
        ['caught', 'continued:100'],
        'catch handler can recover and continue promise chain'
    );
};

# Test 6: Nested promise flattening
SKIP: {
    skip 'Deeply nested promise flattening not yet implemented', 1;

    subtest 'nested promise flattening' => sub {
        my $executor = Executor->new;
        my $promise = Promise->new(executor => $executor);

        my $result;
        $promise
            ->then(sub ($x) {
                my $inner1 = Promise->new(executor => $executor);
                $executor->next_tick(sub {
                    my $inner2 = Promise->new(executor => $executor);
                    $executor->next_tick(sub { $inner2->resolve($x * 3) });
                    $inner1->resolve($inner2);
                });
                return $inner1;
            })
            ->then(sub ($x) { $result = $x });

        $promise->resolve(7);
        $executor->run;

        is($result, 21, 'deeply nested promises are flattened');
    };
}

# Test 7: Promise returned from catch handler
subtest 'promise returned from catch handler' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    my $result;
    $promise
        ->then(sub ($x) { die "error\n" })
        ->then(
            sub ($x) { },
            sub ($e) {
                my $recovery = Promise->new(executor => $executor);
                $executor->next_tick(sub { $recovery->resolve(999) });
                return $recovery;
            }
        )
        ->then(sub ($x) { $result = $x });

    $promise->resolve(1);
    $executor->run;

    is($result, 999, 'promise returned from catch handler is flattened');
};

# Test 8: Empty catch handler (default behavior)
subtest 'empty catch handler' => sub {
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    # Should not crash with default empty catch
    $promise->then(sub ($x) { $x * 2 });

    $promise->reject('error');
    $executor->run;

    pass('promise with rejection and no catch handler does not crash');
};

done_testing;

#!perl
# Unit tests for Flow::Executor edge cases and fixes

use v5.42;
use experimental qw[ class try ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional concurrency ];

# Test 1: Basic functionality - callbacks execute in order
subtest 'basic callback execution' => sub {
    my $exe = Flow::Executor->new;
    my @executed;

    $exe->next_tick(sub { push @executed => 1 });
    $exe->next_tick(sub { push @executed => 2 });
    $exe->next_tick(sub { push @executed => 3 });

    is($exe->remaining, 3, '... three callbacks queued');
    is($exe->is_done, 0, '... not done yet');

    $exe->tick;

    is($exe->remaining, 0, '... all callbacks executed');
    is($exe->is_done, 1, '... is done');
    eq_or_diff(\@executed, [1, 2, 3], '... callbacks executed in order');
};

# Test 2: Callbacks added during tick run in next tick
subtest 'callbacks added during tick' => sub {
    my $exe = Flow::Executor->new;
    my @executed;

    $exe->next_tick(sub {
        push @executed => 1;
        $exe->next_tick(sub { push @executed => 3 });
    });
    $exe->next_tick(sub { push @executed => 2 });

    $exe->tick;
    eq_or_diff(\@executed, [1, 2], '... first tick executed only initial callbacks');

    $exe->tick;
    eq_or_diff(\@executed, [1, 2, 3], '... second tick executed callback added during first tick');
};

# Test 3: Exception in callback preserves remaining callbacks
subtest 'exception handling preserves callbacks' => sub {
    my $exe = Flow::Executor->new;
    my @executed;

    $exe->next_tick(sub { push @executed => 1 });
    $exe->next_tick(sub { die "callback error\n" });
    $exe->next_tick(sub { push @executed => 3 });

    try {
        $exe->tick;
        fail('... should have thrown exception');
    }
    catch ($e) {
        like($e, qr/callback error/, '... correct exception message');
    }

    eq_or_diff(\@executed, [1], '... only first callback executed');
    is($exe->remaining, 1, '... remaining callback preserved');

    $exe->tick;
    eq_or_diff(\@executed, [1, 3], '... remaining callback executed after exception');
};

# Test 4: Multiple exceptions - each preserves remaining callbacks
subtest 'multiple exceptions' => sub {
    my $exe = Flow::Executor->new;
    my @executed;

    $exe->next_tick(sub { push @executed => 1 });
    $exe->next_tick(sub { die "error 1\n" });
    $exe->next_tick(sub { die "error 2\n" });
    $exe->next_tick(sub { push @executed => 4 });

    # First exception
    try {
        $exe->tick;
    }
    catch ($e) {
        like($e, qr/error 1/, '... first exception caught');
    }

    is($exe->remaining, 2, '... two callbacks remain after first exception');

    # Second exception
    try {
        $exe->tick;
    }
    catch ($e) {
        like($e, qr/error 2/, '... second exception caught');
    }

    is($exe->remaining, 1, '... one callback remains after second exception');

    # Final successful tick
    $exe->tick;
    eq_or_diff(\@executed, [1, 4], '... successful callbacks executed');
};

# Test 5: set_next prevents circular chains
subtest 'set_next prevents circular chain' => sub {
    my $exe2 = Flow::Executor->new;
    my $exe1 = Flow::Executor->new(next => $exe2);

    try {
        $exe2->set_next($exe1);  # Would create cycle: exe1 -> exe2 -> exe1
        fail('... should have thrown exception');
    }
    catch ($e) {
        like($e, qr/Circular executor chain detected/, '... circular chain prevented');
    }

    is($exe2->next, undef, '... exe2->next remains undef');
};

# Test 6: Chain with work executes correctly
subtest 'chain with work executes correctly' => sub {
    my $exe2 = Flow::Executor->new;
    my $exe1 = Flow::Executor->new(next => $exe2);

    my @executed;

    # Queue work on both executors
    $exe1->next_tick(sub {
        push @executed => "exe1-callback1";
        $exe2->next_tick(sub {
            push @executed => "exe2-callback1";
        });
    });

    $exe1->next_tick(sub {
        push @executed => "exe1-callback2";
    });

    $exe2->next_tick(sub {
        push @executed => "exe2-callback2";
    });

    $exe1->run;

    eq_or_diff(\@executed,
        ['exe1-callback1', 'exe1-callback2', 'exe2-callback2', 'exe2-callback1'],
        '... chain with work executed correctly');
};

# Test 7: find_next_undone with chain
subtest 'find_next_undone with chain' => sub {
    my $exe2 = Flow::Executor->new;
    my $exe1 = Flow::Executor->new(next => $exe2);

    # No work - should return undef
    my $found = $exe1->find_next_undone;
    is($found, undef, '... no work found in chain');

    # Add work to exe2
    $exe2->next_tick(sub { });
    $found = $exe1->find_next_undone;
    is($found, $exe2, '... found work in exe2');

    # Clear and add work to exe1
    $exe2->tick;
    $exe1->next_tick(sub { });
    $found = $exe1->find_next_undone;
    is($found, $exe1, '... found work in exe1');
};

# Test 8: collect_all with chain
subtest 'collect_all with chain' => sub {
    my $exe2 = Flow::Executor->new;
    my $exe1 = Flow::Executor->new(next => $exe2);

    my @all = $exe1->collect_all;
    is(scalar @all, 2, '... collected both executors');

    my %addrs = map { refaddr($_) => 1 } @all;
    ok($addrs{refaddr($exe1)}, '... exe1 in collection');
    ok($addrs{refaddr($exe2)}, '... exe2 in collection');
};

# Test 9: Long chain without cycle
subtest 'long chain without cycle' => sub {
    my $last = Flow::Executor->new;
    my $first = $last;

    # Create a chain of 100 executors
    for (1..100) {
        $first = Flow::Executor->new(next => $first);
    }

    # Add work to the last executor
    $last->next_tick(sub { });

    my $found = $first->find_next_undone;
    is($found, $last, '... found work at end of long chain');

    my @all = $first->collect_all;
    is(scalar @all, 101, '... collected all 101 executors');
};

# Test 10: Ping-pong between executors
subtest 'ping-pong between executors' => sub {
    my $exe2 = Flow::Executor->new;
    my $exe1 = Flow::Executor->new(next => $exe2);

    my @got;

    my ($ping, $pong);

    $ping = sub ($n) {
        sub {
            push @got => "ping($n)";
            $exe2->next_tick($pong->($n - 1)) if $n > 0;
        }
    };

    $pong = sub ($n) {
        sub {
            push @got => "pong($n)";
            $exe1->next_tick($ping->($n - 1)) if $n > 0;
        }
    };

    $exe1->next_tick($ping->(5));
    $exe1->run;

    eq_or_diff(
        \@got,
        [qw[ ping(5) pong(4) ping(3) pong(2) ping(1) pong(0) ]],
        '... ping-pong executed correctly'
    );
};

# Test 11: Self-referential executor prevented
subtest 'self-referential executor prevented' => sub {
    my $exe = Flow::Executor->new;

    try {
        $exe->set_next($exe);  # Try to point to itself
        fail('... should have thrown exception');
    }
    catch ($e) {
        like($e, qr/Circular executor chain detected/, '... self-reference prevented');
    }

    is($exe->next, undef, '... next remains undef');
};

# Test 12: Three-way chain (no cycle)
subtest 'three-way chain' => sub {
    my $exe3 = Flow::Executor->new;
    my $exe2 = Flow::Executor->new(next => $exe3);
    my $exe1 = Flow::Executor->new(next => $exe2);

    my @executed;
    $exe1->next_tick(sub { push @executed => 1 });
    $exe2->next_tick(sub { push @executed => 2 });
    $exe3->next_tick(sub { push @executed => 3 });

    $exe1->run;

    eq_or_diff([sort @executed], [1, 2, 3], '... all three executors ran');
};

# Test 13: Empty executor chain
subtest 'empty executor run' => sub {
    my $exe = Flow::Executor->new;

    $exe->run;  # Should not hang

    pass('... empty executor run completed');
    is($exe->is_done, 1, '... executor is done');
};

# Test 14: diag method with chain
subtest 'diag with chain' => sub {
    my $exe2 = Flow::Executor->new;
    my $exe1 = Flow::Executor->new(next => $exe2);

    # Should not hang or crash
    $exe1->diag;

    pass('... diag completed with chain');
};

done_testing;

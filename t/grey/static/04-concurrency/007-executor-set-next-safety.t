#!perl
# Unit tests for Flow::Executor set_next cycle detection

use v5.42;
use experimental qw[ class try ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional concurrency ];

# Test 1: Setting next to undef should work
subtest 'set_next to undef' => sub {
    my $exe = Flow::Executor->new;
    $exe->set_next(undef);

    is($exe->next, undef, '... next is undef');
};

# Test 2: Simple chain (no cycle) should work
subtest 'set_next simple chain' => sub {
    my $exe2 = Flow::Executor->new;
    my $exe1 = Flow::Executor->new;

    $exe1->set_next($exe2);

    is($exe1->next, $exe2, '... exe1->next is exe2');
    is($exe2->next, undef, '... exe2->next is undef');
};

# Test 3: Direct self-reference should fail
subtest 'set_next self-reference' => sub {
    my $exe = Flow::Executor->new;

    try {
        $exe->set_next($exe);
        fail('... should have thrown exception');
    }
    catch ($e) {
        like($e, qr/Circular executor chain detected/, '... correct exception message');
    }
};

# Test 4: Two-executor cycle should fail
subtest 'set_next two-executor cycle' => sub {
    my $exe2 = Flow::Executor->new;
    my $exe1 = Flow::Executor->new(next => $exe2);

    try {
        $exe2->set_next($exe1);  # Would create: exe1 -> exe2 -> exe1
        fail('... should have thrown exception');
    }
    catch ($e) {
        like($e, qr/Circular executor chain detected/, '... correct exception message');
    }

    is($exe2->next, undef, '... exe2->next remains undef');
};

# Test 5: Three-executor cycle should fail
subtest 'set_next three-executor cycle' => sub {
    my $exe3 = Flow::Executor->new;
    my $exe2 = Flow::Executor->new(next => $exe3);
    my $exe1 = Flow::Executor->new(next => $exe2);

    try {
        $exe3->set_next($exe1);  # Would create: exe1 -> exe2 -> exe3 -> exe1
        fail('... should have thrown exception');
    }
    catch ($e) {
        like($e, qr/Circular executor chain detected/, '... correct exception message');
    }

    is($exe3->next, undef, '... exe3->next remains undef');
};

# Test 6: Long chain cycle should fail
subtest 'set_next long chain cycle' => sub {
    my $exe5 = Flow::Executor->new;
    my $exe4 = Flow::Executor->new(next => $exe5);
    my $exe3 = Flow::Executor->new(next => $exe4);
    my $exe2 = Flow::Executor->new(next => $exe3);
    my $exe1 = Flow::Executor->new(next => $exe2);

    try {
        $exe5->set_next($exe2);  # Would create cycle at exe2
        fail('... should have thrown exception');
    }
    catch ($e) {
        like($e, qr/Circular executor chain detected/, '... correct exception message');
    }

    is($exe5->next, undef, '... exe5->next remains undef');
};

# Test 7: Setting to executor with existing (non-conflicting) cycle should work
subtest 'set_next to executor with existing cycle' => sub {
    my $exe3 = Flow::Executor->new;
    my $exe2 = Flow::Executor->new;

    # Create a separate cycle: exe2 -> exe3 -> exe2
    $exe2->set_next($exe3);
    try {
        $exe3->set_next($exe2);  # This creates a cycle, should fail
        fail('... should have thrown exception for exe3->exe2');
    }
    catch ($e) {
        like($e, qr/Circular executor chain detected/, '... correct exception for creating cycle');
    }

    # Now exe1 pointing to exe2 should work (even though exe2 might be part of a cycle)
    my $exe1 = Flow::Executor->new;
    $exe1->set_next($exe2);  # This should work

    is($exe1->next, $exe2, '... exe1->next is exe2');
};

# Test 8: Replacing next should work
subtest 'replacing next' => sub {
    my $exe3 = Flow::Executor->new;
    my $exe2 = Flow::Executor->new;
    my $exe1 = Flow::Executor->new(next => $exe2);

    is($exe1->next, $exe2, '... initially exe1->next is exe2');

    $exe1->set_next($exe3);
    is($exe1->next, $exe3, '... after set_next, exe1->next is exe3');
};

# Test 9: Complex chain rearrangement
subtest 'complex chain rearrangement' => sub {
    my $exe4 = Flow::Executor->new;
    my $exe3 = Flow::Executor->new(next => $exe4);
    my $exe2 = Flow::Executor->new(next => $exe3);
    my $exe1 = Flow::Executor->new(next => $exe2);

    # Initial chain: exe1 -> exe2 -> exe3 -> exe4
    is($exe1->next, $exe2, '... exe1 -> exe2');
    is($exe2->next, $exe3, '... exe2 -> exe3');
    is($exe3->next, $exe4, '... exe3 -> exe4');

    # Rearrange to: exe1 -> exe4, exe2 -> exe3 -> exe4
    $exe1->set_next($exe4);
    is($exe1->next, $exe4, '... exe1 now points to exe4');

    # This should still be safe
    $exe2->set_next($exe3);
    is($exe2->next, $exe3, '... exe2 still points to exe3');
};

done_testing;

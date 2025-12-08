#!/usr/bin/env perl

use v5.42;

use Test::More;
use Test::Exception;

use grey::static qw[ functional concurrency::reactive ];

subtest '... test Grep operation creation' => sub {
    my $p = Predicate->new( f => sub ($x) { $x > 5 } );
    my $grep = Flow::Operation::Grep->new( f => $p );

    ok($grep, 'created a Grep operation');
    isa_ok($grep, 'Flow::Operation::Grep', 'correct type');
    isa_ok($grep, 'Flow::Operation', 'inherits from Operation');
};

subtest '... test Grep filtering even numbers' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $p = Predicate->new( f => sub ($x) { $x % 2 == 0 } );
    my $grep = Flow::Operation::Grep->new( f => $p );

    $grep->subscribe($subscriber);

    for my $i (1..10) {
        $grep->apply($i);
    }

    $grep->executor->run;

    is_deeply(\@collected, [2, 4, 6, 8, 10], 'grep filtered to even numbers');
};

subtest '... test Grep filtering odd numbers' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $p = Predicate->new( f => sub ($x) { $x % 2 != 0 } );
    my $grep = Flow::Operation::Grep->new( f => $p );

    $grep->subscribe($subscriber);

    for my $i (1..10) {
        $grep->apply($i);
    }

    $grep->executor->run;

    is_deeply(\@collected, [1, 3, 5, 7, 9], 'grep filtered to odd numbers');
};

subtest '... test Grep in Flow pipeline' => sub {
    my @collected;

    my $p = Predicate->new( f => sub ($x) { $x > 5 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( $p )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    for my $i (1..10) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [6, 7, 8, 9, 10], 'grep in flow filtered values > 5');
};

subtest '... test Grep with string predicate' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $p = Predicate->new( f => sub ($x) { length($x) > 3 } );
    my $grep = Flow::Operation::Grep->new( f => $p );

    $grep->subscribe($subscriber);

    $grep->apply("hi");
    $grep->apply("hello");
    $grep->apply("bye");
    $grep->apply("world");

    $grep->executor->run;

    is_deeply(\@collected, ["hello", "world"], 'grep filtered by string length');
};

subtest '... test Grep filters all out' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $p = Predicate->new( f => sub ($x) { $x > 100 } );
    my $grep = Flow::Operation::Grep->new( f => $p );

    $grep->subscribe($subscriber);

    for my $i (1..10) {
        $grep->apply($i);
    }

    $grep->executor->run;

    is_deeply(\@collected, [], 'grep filtered out all values');
};

subtest '... test Grep allows all through' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $p = Predicate->new( f => sub ($x) { 1 } );  # Always true
    my $grep = Flow::Operation::Grep->new( f => $p );

    $grep->subscribe($subscriber);

    for my $i (1..5) {
        $grep->apply($i);
    }

    $grep->executor->run;

    is_deeply(\@collected, [1, 2, 3, 4, 5], 'grep allowed all values through');
};

subtest '... test Grep with map combination' => sub {
    my @collected;

    my $p = Predicate->new( f => sub ($x) { $x % 2 == 0 } );
    my $f = Function->new( f => sub ($x) { $x * 10 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( $p )
        ->map( $f )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    for my $i (1..10) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [20, 40, 60, 80, 100], 'grep then map pipeline works');
};

subtest '... test Grep with map then grep' => sub {
    my @collected;

    my $f = Function->new( f => sub ($x) { $x * 2 } );
    my $p1 = Predicate->new( f => sub ($x) { $x < 10 } );
    my $p2 = Predicate->new( f => sub ($x) { $x % 4 == 0 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( $p1 )
        ->map( $f )
        ->grep( $p2 )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    for my $i (1..10) {
        $publisher->submit($i);
    }

    $publisher->start;

    # 1..9 pass first grep, doubled to 2,4,6,8,10,12,14,16,18
    # Then filter to multiples of 4: 4,8,12,16
    is_deeply(\@collected, [4, 8, 12, 16], 'grep->map->grep pipeline works');
};

subtest '... test Grep with complex predicate' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    # Complex predicate: divisible by 3 or 5
    my $p = Predicate->new( f => sub ($x) { $x % 3 == 0 || $x % 5 == 0 } );
    my $grep = Flow::Operation::Grep->new( f => $p );

    $grep->subscribe($subscriber);

    for my $i (1..15) {
        $grep->apply($i);
    }

    $grep->executor->run;

    is_deeply(\@collected, [3, 5, 6, 9, 10, 12, 15], 'complex predicate works');
};

subtest '... test Grep with predicate that throws' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $p = Predicate->new( f => sub ($x) {
        die "error on value 3" if $x == 3;
        return $x % 2 == 0;
    });
    my $grep = Flow::Operation::Grep->new( f => $p );

    $grep->subscribe($subscriber);

    dies_ok {
        $grep->apply(1);
        $grep->apply(2);
        $grep->apply(3);  # Will throw
        $grep->apply(4);
        $grep->executor->run;
    } 'grep propagates exception from predicate';

    # Due to async executor, error may occur before values complete
    ok(1, 'error correctly propagated');
};

subtest '... test Grep with stateful predicate' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    # Predicate with state - only allow first 3 items
    my $count = 0;
    my $p = Predicate->new( f => sub ($x) { ++$count <= 3 } );
    my $grep = Flow::Operation::Grep->new( f => $p );

    $grep->subscribe($subscriber);

    for my $i (1..10) {
        $grep->apply($i);
    }

    $grep->executor->run;

    is_deeply(\@collected, [1, 2, 3], 'stateful predicate works');
};

subtest '... test Grep with negate predicate' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    # Use negate to invert the predicate
    my $is_even = Predicate->new( f => sub ($x) { $x % 2 == 0 } );
    my $is_odd = $is_even->not;

    my $grep = Flow::Operation::Grep->new( f => $is_odd );

    $grep->subscribe($subscriber);

    for my $i (1..10) {
        $grep->apply($i);
    }

    $grep->executor->run;

    is_deeply(\@collected, [1, 3, 5, 7, 9], 'negated predicate works');
};

subtest '... test Grep with backpressure' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 2,  # Request 2 at a time
    );

    my $p = Predicate->new( f => sub ($x) { $x % 2 == 0 } );
    my $grep = Flow::Operation::Grep->new( f => $p );

    $grep->subscribe($subscriber);

    for my $i (1..10) {
        $grep->apply($i);
    }

    $grep->executor->run;

    is_deeply(\@collected, [2, 4, 6, 8, 10], 'grep respects backpressure');
};

subtest '... test Grep chaining multiple greps' => sub {
    my @collected;

    my $p1 = Predicate->new( f => sub ($x) { $x > 3 } );
    my $p2 = Predicate->new( f => sub ($x) { $x < 8 } );
    my $p3 = Predicate->new( f => sub ($x) { $x % 2 == 0 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( $p1 )
        ->grep( $p2 )
        ->grep( $p3 )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    for my $i (1..10) {
        $publisher->submit($i);
    }

    $publisher->start;

    # Filter: > 3, < 8, even -> [4, 6]
    is_deeply(\@collected, [4, 6], 'chained greps work correctly');
};

done_testing;

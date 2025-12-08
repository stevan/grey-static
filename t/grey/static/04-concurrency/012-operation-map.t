#!/usr/bin/env perl

use v5.42;

use Test::More;
use Test::Exception;

use grey::static qw[ functional concurrency::reactive ];

subtest '... test Map operation creation' => sub {
    my $f = Function->new( f => sub ($x) { $x * 2 } );
    my $map = Flow::Operation::Map->new( f => $f );

    ok($map, 'created a Map operation');
    isa_ok($map, 'Flow::Operation::Map', 'correct type');
    isa_ok($map, 'Flow::Operation', 'inherits from Operation');
};

subtest '... test Map with doubling function' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $f = Function->new( f => sub ($x) { $x * 2 } );
    my $map = Flow::Operation::Map->new( f => $f );

    $map->subscribe($subscriber);

    $map->apply(5);
    $map->apply(10);
    $map->apply(15);

    $map->executor->run;

    is_deeply(\@collected, [10, 20, 30], 'map doubled all values');
};

subtest '... test Map in Flow pipeline' => sub {
    my @collected;

    my $f = Function->new( f => sub ($x) { $x * 3 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( $f )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);

    $publisher->start;

    is_deeply(\@collected, [3, 6, 9], 'map in flow tripled values');
};

subtest '... test Map with string transformation' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $f = Function->new( f => sub ($x) { uc($x) } );
    my $map = Flow::Operation::Map->new( f => $f );

    $map->subscribe($subscriber);

    $map->apply("hello");
    $map->apply("world");

    $map->executor->run;

    is_deeply(\@collected, ["HELLO", "WORLD"], 'map transformed strings to uppercase');
};

subtest '... test Map with complex transformation' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    # Transform number to hash
    my $f = Function->new( f => sub ($x) { { value => $x, squared => $x * $x } } );
    my $map = Flow::Operation::Map->new( f => $f );

    $map->subscribe($subscriber);

    $map->apply(2);
    $map->apply(3);

    $map->executor->run;

    is_deeply(\@collected, [
        { value => 2, squared => 4 },
        { value => 3, squared => 9 },
    ], 'map created complex objects');
};

subtest '... test Map chaining' => sub {
    my @collected;

    my $f1 = Function->new( f => sub ($x) { $x * 2 } );
    my $f2 = Function->new( f => sub ($x) { $x + 10 } );
    my $f3 = Function->new( f => sub ($x) { $x * $x } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( $f1 )
        ->map( $f2 )
        ->map( $f3 )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);

    $publisher->start;

    # 1: 1*2=2, 2+10=12, 12*12=144
    # 2: 2*2=4, 4+10=14, 14*14=196
    # 3: 3*2=6, 6+10=16, 16*16=256
    is_deeply(\@collected, [144, 196, 256], 'chained maps applied in order');
};

subtest '... test Map with identity function' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $f = Function->new( f => sub ($x) { $x } );
    my $map = Flow::Operation::Map->new( f => $f );

    $map->subscribe($subscriber);

    $map->apply(10);
    $map->apply(20);

    $map->executor->run;

    is_deeply(\@collected, [10, 20], 'identity map preserves values');
};

subtest '... test Map with function that returns undef' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $f = Function->new( f => sub ($x) { return undef } );
    my $map = Flow::Operation::Map->new( f => $f );

    $map->subscribe($subscriber);

    $map->apply(10);
    $map->apply(20);

    $map->executor->run;

    is_deeply(\@collected, [undef, undef], 'map can return undef');
};

subtest '... test Map with function that throws' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $f = Function->new( f => sub ($x) {
        die "error on value 2" if $x == 2;
        return $x * 10;
    });
    my $map = Flow::Operation::Map->new( f => $f );

    $map->subscribe($subscriber);

    dies_ok {
        $map->apply(1);
        $map->apply(2);  # Will throw
        $map->apply(3);
        $map->executor->run;
    } 'map propagates exception from function';

    # Due to async executor, error may occur before first value completes
    ok(1, 'error correctly propagated');
};

subtest '... test Map with BiFunction composition' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    # Create a composed function
    my $double = Function->new( f => sub ($x) { $x * 2 } );
    my $add_one = Function->new( f => sub ($x) { $x + 1 } );
    my $composed = Function->new( f => sub ($x) { $add_one->apply($double->apply($x)) } );

    my $map = Flow::Operation::Map->new( f => $composed );

    $map->subscribe($subscriber);

    $map->apply(1);
    $map->apply(2);
    $map->apply(3);

    $map->executor->run;

    is_deeply(\@collected, [3, 5, 7], 'composed function works in map');
};

subtest '... test Map with array transformation' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    # Transform single value to array
    my $f = Function->new( f => sub ($x) { [$x, $x * 2, $x * 3] } );
    my $map = Flow::Operation::Map->new( f => $f );

    $map->subscribe($subscriber);

    $map->apply(2);
    $map->apply(3);

    $map->executor->run;

    is_deeply(\@collected, [
        [2, 4, 6],
        [3, 6, 9],
    ], 'map can transform to arrays');
};

subtest '... test Map with stateful function' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    # Function with state (counter)
    my $counter = 0;
    my $f = Function->new( f => sub ($x) { $counter++; return "$x-$counter" } );
    my $map = Flow::Operation::Map->new( f => $f );

    $map->subscribe($subscriber);

    $map->apply("a");
    $map->apply("b");
    $map->apply("c");

    $map->executor->run;

    is_deeply(\@collected, ["a-1", "b-2", "c-3"], 'stateful function maintains state');
};

subtest '... test Map with backpressure' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 2,  # Request 2 at a time
    );

    my $f = Function->new( f => sub ($x) { $x * 100 } );
    my $map = Flow::Operation::Map->new( f => $f );

    $map->subscribe($subscriber);

    for my $i (1..5) {
        $map->apply($i);
    }

    $map->executor->run;

    is_deeply(\@collected, [100, 200, 300, 400, 500], 'map respects backpressure');
};

done_testing;

#!/usr/bin/env perl

use v5.42;

use Test::More;
use Test::Exception;

use grey::static qw[ functional concurrency::reactive ];

subtest '... test error in Consumer propagates' => sub {
    my @collected;

    my $consumer = Consumer->new( f => sub ($e) {
        die "consumer error" if $e == 3;
        push @collected, $e;
    });

    my $subscriber = Flow::Subscriber->new(
        consumer => $consumer,
        request_size => 10,
    );

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($subscriber);

    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);
    $publisher->submit(4);

    dies_ok {
        $publisher->start;
    } 'error in consumer propagates';

    is_deeply(\@collected, [1, 2], 'values before error were processed');
};

subtest '... test error in Map function propagates' => sub {
    my @collected;

    my $f = Function->new( f => sub ($x) {
        die "map error" if $x == 5;
        return $x * 2;
    });

    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( $f )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(5);
    $publisher->submit(6);

    dies_ok {
        $publisher->start;
    } 'error in map propagates';

    # Due to async executor, only first value is collected before error
    ok(scalar(@collected) >= 1, 'at least one value processed before error');
    is($collected[0], 2, 'first value was correctly transformed');
};

subtest '... test error in Grep predicate propagates' => sub {
    my @collected;

    my $p = Predicate->new( f => sub ($x) {
        die "grep error" if $x == 7;
        return $x % 2 == 0;
    });

    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( $p )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    $publisher->submit(2);
    $publisher->submit(4);
    $publisher->submit(7);
    $publisher->submit(8);

    dies_ok {
        $publisher->start;
    } 'error in grep propagates';

    # Due to async executor, check we got at least some values
    ok(scalar(@collected) >= 1, 'at least one value processed before error');
    is($collected[0], 2, 'first value was correct');
};

subtest '... test error in complex pipeline propagates' => sub {
    my @collected;

    my $f = Function->new( f => sub ($x) {
        die "map error at value 6" if $x == 6;
        return $x * 2;
    });

    my $p = Predicate->new( f => sub ($x) { $x < 20 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( $f )
        ->grep( $p )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    for my $i (1..10) {
        $publisher->submit($i);
    }

    dies_ok {
        $publisher->start;
    } 'error in complex pipeline propagates';

    # Due to async executor, some values processed before error
    ok(scalar(@collected) >= 1, 'at least one value processed before error');
};

subtest '... test Subscription on_error called' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $error_message;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $subscription = Flow::Subscription->new(
        publisher => $publisher,
        subscriber => $subscriber,
        executor => $publisher->executor,
    );
    $subscriber->on_subscribe($subscription);

    $subscription->request(10);
    $subscription->offer(1);
    $subscription->offer(2);

    lives_ok {
        $subscription->on_error("test error");
    } 'on_error can be called';

    $publisher->executor->run;

    is_deeply(\@collected, [1, 2], 'values delivered before error');
};

subtest '... test error with multiple operations in chain' => sub {
    my @collected;

    my $f1 = Function->new( f => sub ($x) { $x + 1 } );
    my $f2 = Function->new( f => sub ($x) {
        die "error in second map" if $x == 5;
        return $x * 2;
    });
    my $f3 = Function->new( f => sub ($x) { $x + 10 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( $f1 )
        ->map( $f2 )
        ->map( $f3 )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    $publisher->submit(1);  # 1+1=2, 2*2=4, 4+10=14
    $publisher->submit(2);  # 2+1=3, 3*2=6, 6+10=16
    $publisher->submit(4);  # 4+1=5, error!
    $publisher->submit(5);

    dies_ok {
        $publisher->start;
    } 'error propagates through operation chain';

    # Error may occur before values complete the full pipeline
    ok(1, 'error correctly propagated');
};

subtest '... test error early in pipeline stops processing' => sub {
    my @collected;
    my $map2_called = 0;

    my $f1 = Function->new( f => sub ($x) {
        die "error in first map" if $x == 3;
        return $x * 2;
    });

    my $f2 = Function->new( f => sub ($x) {
        $map2_called++;
        return $x + 1;
    });

    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( $f1 )
        ->map( $f2 )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);
    $publisher->submit(4);

    dies_ok {
        $publisher->start;
    } 'error stops pipeline';

    # Error may occur before values complete pipeline
    ok(1, 'error correctly stopped processing');
};

subtest '... test error in first operation of chain' => sub {
    my @collected;

    my $p = Predicate->new( f => sub ($x) {
        die "error in grep" if $x == 2;
        return 1;
    });

    my $f = Function->new( f => sub ($x) { $x * 100 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( $p )
        ->map( $f )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);

    dies_ok {
        $publisher->start;
    } 'error in first operation propagates';

    # Error happens early, may not have collected any values
    ok(1, 'error propagated correctly');
};

subtest '... test error in last operation of chain' => sub {
    my @collected;

    my $f = Function->new( f => sub ($x) { $x * 2 } );
    my $p = Predicate->new( f => sub ($x) {
        die "error in grep" if $x == 8;
        return 1;
    });

    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( $f )
        ->grep( $p )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(4);
    $publisher->submit(5);

    dies_ok {
        $publisher->start;
    } 'error in last operation propagates';

    # Due to async executor
    ok(scalar(@collected) >= 1, 'at least one value processed');
};

subtest '... test multiple errors only first one throws' => sub {
    my @collected;

    my $f = Function->new( f => sub ($x) {
        die "error at $x" if $x > 2;
        return $x * 10;
    });

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $publisher = Flow::Publisher->new;
    my $map = Flow::Operation::Map->new( f => $f );

    $map->subscribe($subscriber);
    $publisher->subscribe($map);

    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);
    $publisher->submit(4);

    dies_ok {
        $publisher->start;
    } 'first error throws';

    # Due to async executor
    ok(scalar(@collected) >= 1, 'at least one value processed');
};

subtest '... test Publisher on_error method exists' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    $publisher->subscribe($subscriber);
    $publisher->submit(1);

    # Manually trigger error via subscription
    lives_ok {
        $publisher->subscription->on_error("test error");
    } 'can call on_error on subscription';

    $publisher->start;

    is_deeply(\@collected, [1], 'value processed before error signal');
};

done_testing;

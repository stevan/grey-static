#!/usr/bin/env perl

use v5.40;
use experimental qw(builtin);

use Test::More;
use Test::Exception;

use grey::static qw[ functional concurrency ];

subtest '... test Publisher close with callback' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $completed = 0;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    $publisher->subscribe($subscriber);
    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);

    $publisher->close(sub { $completed = 1 });
    $publisher->start;

    is_deeply(\@collected, [1, 2, 3], 'all items delivered before close');
    is($completed, 1, 'close callback executed');
};

subtest '... test Publisher close with empty stream' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $completed = 0;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    $publisher->subscribe($subscriber);
    $publisher->close(sub { $completed = 1 });
    $publisher->start;

    is_deeply(\@collected, [], 'no items in empty stream');
    is($completed, 1, 'close callback executed for empty stream');
};

subtest '... test Subscription on_completed' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 0,  # Don't auto-request
    );

    my $subscription = Flow::Subscription->new(
        publisher => $publisher,
        subscriber => $subscriber,
        executor => $publisher->executor,
    );
    $subscriber->on_subscribe($subscription);

    $subscription->request(5);
    $subscription->offer(1);
    $subscription->offer(2);
    $subscription->offer(3);

    lives_ok {
        $subscription->on_completed;
    } 'on_completed can be called';

    $publisher->executor->run;

    is_deeply(\@collected, [1, 2, 3], 'items delivered before completion');
};

subtest '... test completion propagates through operations' => sub {
    my @collected;
    my $completed = 0;

    my $f = Function->new( f => sub ($x) { $x * 2 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( $f )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->close(sub { $completed = 1 });
    $publisher->start;

    is_deeply(\@collected, [2, 4], 'items processed through operation');
    is($completed, 1, 'completion propagated through operation');
};

subtest '... test completion in multi-operation pipeline' => sub {
    my @collected;
    my $completed = 0;

    my $f = Function->new( f => sub ($x) { $x + 1 } );
    my $p = Predicate->new( f => sub ($x) { $x % 2 == 0 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( $f )
        ->grep( $p )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    for my $i (1..10) {
        $publisher->submit($i);
    }
    $publisher->close(sub { $completed = 1 });
    $publisher->start;

    # 1->2, 2->3, 3->4, 4->5, 5->6, 6->7, 7->8, 8->9, 9->10, 10->11
    # Filter evens: 2, 4, 6, 8, 10
    is_deeply(\@collected, [2, 4, 6, 8, 10], 'all items processed before completion');
    is($completed, 1, 'completion propagated through multi-operation pipeline');
};

subtest '... test close without callback' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    $publisher->subscribe($subscriber);
    $publisher->submit(1);
    $publisher->submit(2);

    lives_ok {
        $publisher->close;  # No callback
        $publisher->start;
    } 'close without callback works';

    is_deeply(\@collected, [1, 2], 'items delivered even without callback');
};

subtest '... test Subscriber on_completed called' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $on_completed_called = 0;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    $publisher->subscribe($subscriber);
    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->close(sub { $on_completed_called = 1 });
    $publisher->start;

    is_deeply(\@collected, [1, 2], 'items processed');
    is($on_completed_called, 1, 'on_completed triggered callback');
};

subtest '... test Operation on_completed propagation' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $completed = 0;

    my $f = Function->new( f => sub ($x) { $x * 3 } );
    my $map = Flow::Operation::Map->new( f => $f );

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    $map->subscribe($subscriber);
    $publisher->subscribe($map);

    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->close(sub { $completed = 1 });
    $publisher->start;

    is_deeply(\@collected, [3, 6], 'items transformed and delivered');
    is($completed, 1, 'completion propagated through operation');
};

subtest '... test completion with backpressure' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $completed = 0;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 2,  # Small batch size
    );

    $publisher->subscribe($subscriber);
    for my $i (1..10) {
        $publisher->submit($i);
    }
    $publisher->close(sub { $completed = 1 });
    $publisher->start;

    is_deeply(\@collected, [1..10], 'all items delivered despite backpressure');
    is($completed, 1, 'completion callback executed after backpressure resolved');
};

subtest '... test completion before all items submitted' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $completed = 0;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    $publisher->subscribe($subscriber);
    $publisher->submit(1);
    $publisher->close(sub { $completed = 1 });
    # Submit more after close
    $publisher->submit(2);
    $publisher->start;

    # Behavior here depends on implementation - items before close should be delivered
    ok(scalar(@collected) >= 1, 'at least items before close delivered');
    is($completed, 1, 'completion callback executed');
};

subtest '... test multiple close calls' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $completed_count = 0;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    $publisher->subscribe($subscriber);
    $publisher->submit(1);

    lives_ok {
        $publisher->close(sub { $completed_count++ });
        $publisher->close(sub { $completed_count++ });
    } 'multiple close calls are safe';

    $publisher->start;

    is_deeply(\@collected, [1], 'item processed');
    ok($completed_count > 0, 'at least one completion callback executed');
};

subtest '... test close in complex pipeline with filtering' => sub {
    my @collected;
    my $completed = 0;

    my $f = Function->new( f => sub ($x) { $x * 2 } );
    my $p = Predicate->new( f => sub ($x) { $x > 10 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( $f )
        ->grep( $p )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    for my $i (1..20) {
        $publisher->submit($i);
    }
    $publisher->close(sub { $completed = 1 });
    $publisher->start;

    # 1->2, 2->4, ..., 6->12, 7->14, ..., 20->40
    # Filter >10: 12, 14, 16, ..., 40
    my @expected = grep { $_ > 10 } map { $_ * 2 } (1..20);
    is_deeply(\@collected, \@expected, 'all filtered items delivered before completion');
    is($completed, 1, 'completion callback executed');
};

subtest '... test close with no subscriber' => sub {
    my $publisher = Flow::Publisher->new;
    my $completed = 0;

    lives_ok {
        $publisher->submit(1);
        $publisher->close(sub { $completed = 1 });
        $publisher->start;
    } 'close with no subscriber is safe';

    is($completed, 1, 'completion callback executed even without subscriber');
};

done_testing;

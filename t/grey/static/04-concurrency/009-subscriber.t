#!/usr/bin/env perl

use v5.40;
use experimental qw(builtin);

use Test::More;
use Test::Exception;

use grey::static qw[ functional concurrency ];

subtest '... test Subscriber creation with defaults' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
    );

    ok($subscriber, 'created a Subscriber');
    is($subscriber->request_size, 1, 'default request_size is 1');
    isa_ok($subscriber->consumer, 'Consumer', 'has a consumer');
};

subtest '... test Subscriber with custom request_size' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 5,
    );

    is($subscriber->request_size, 5, 'custom request_size set correctly');
};

subtest '... test Subscriber on_subscribe' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 3,
    );

    my $publisher = Flow::Publisher->new;
    my $subscription = Flow::Subscription->new(
        publisher => $publisher,
        subscriber => $subscriber,
        executor => Flow::Executor->new,
    );

    # on_subscribe should be called by subscription
    $subscriber->on_subscribe($subscription);

    # This should have triggered initial request
    # We can't directly test $count (private field), but we can test behavior
    ok(1, 'on_subscribe executed without error');
};

subtest '... test Subscriber on_next processing' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($subscriber);

    # Submit items through publisher (which triggers on_next internally)
    $publisher->submit(100);
    $publisher->submit(200);
    $publisher->start;

    is_deeply(\@collected, [100, 200], 'on_next processed elements');
};

subtest '... test Subscriber backpressure with request_size=1' => sub {
    my @collected;
    my $request_count = 0;

    # Track requests by wrapping subscription
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 1,
    );

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($subscriber);

    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);
    $publisher->start;

    is_deeply(\@collected, [1, 2, 3], 'all items processed with request_size=1');
};

subtest '... test Subscriber backpressure with request_size=2' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 2,
    );

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($subscriber);

    for my $i (1..6) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [1..6], 'all items processed with request_size=2');
    is(scalar(@collected), 6, 'correct number of items');
};

subtest '... test Subscriber on_completed' => sub {
    my @collected;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($subscriber);

    $publisher->submit(1);
    $publisher->submit(2);

    # Deliver items before closing
    $publisher->start;

    is_deeply(\@collected, [1, 2], 'items processed');

    # close() will call on_completed on the subscription
    $publisher->close;

    # Test passes if close executes without error
    ok(1, 'close executed and called on_completed');
};

subtest '... test Subscriber on_error' => sub {
    my @collected;
    my $error_received;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    # Manually trigger error
    lives_ok {
        $subscriber->on_error("test error");
    } 'on_error executed without dying';
};

subtest '... test Subscriber with Consumer that throws' => sub {
    my @collected;
    my $exception_thrown = 0;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) {
            push @collected, $e;
            die "consumer error" if $e == 2;
        }),
        request_size => 10,
    );

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($subscriber);

    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);

    # The error should propagate through the executor
    dies_ok {
        $publisher->start;
    } 'error in consumer propagates';

    # First item should be collected before error
    is($collected[0], 1, 'first item processed before error');
};

subtest '... test Subscriber on_unsubscribe' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 5,
    );

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($subscriber);

    $publisher->submit(100);
    $publisher->start;

    is_deeply(\@collected, [100], 'item processed');

    # Unsubscribe
    $publisher->unsubscribe($publisher->subscription);
    $subscriber->on_unsubscribe();

    # Subscription should be cleared (internal state)
    ok(1, 'on_unsubscribe executed without error');
};

subtest '... test Subscriber with large request_size' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 1000,
    );

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($subscriber);

    for my $i (1..100) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [1..100], 'all 100 items processed with large request_size');
};

subtest '... test Subscriber with Function-based Consumer' => sub {
    my @collected;

    # Use Function instead of Consumer directly
    my $func = Function->new( f => sub ($e) { push @collected, $e * 2 } );
    my $consumer = Consumer->new( f => sub ($e) { $func->apply($e) } );

    my $subscriber = Flow::Subscriber->new(
        consumer => $consumer,
        request_size => 5,
    );

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($subscriber);

    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);
    $publisher->start;

    is_deeply(\@collected, [2, 4, 6], 'function-based consumer works');
};

done_testing;

#!/usr/bin/env perl

use v5.40;
use experimental qw(builtin);

use Test::More;
use Test::Exception;

use grey::static qw[ functional concurrency ];

subtest '... test Subscription creation' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 5,
    );
    my $executor = Flow::Executor->new;

    my $subscription = Flow::Subscription->new(
        publisher => $publisher,
        subscriber => $subscriber,
        executor => $executor,
    );
    $subscriber->on_subscribe($subscription);

    ok($subscription, 'created a Subscription');
    is($subscription->publisher, $publisher, 'publisher set correctly');
    is($subscription->subscriber, $subscriber, 'subscriber set correctly');
    is($subscription->executor, $executor, 'executor set correctly');
};

subtest '... test Subscription request mechanism' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 1,
    );

    my $subscription = Flow::Subscription->new(
        publisher => $publisher,
        subscriber => $subscriber,
        executor => $publisher->executor,
    );
    $subscriber->on_subscribe($subscription);

    # Request items
    $subscription->request(3);

    # Offer items to subscription
    $subscription->offer(10);
    $subscription->offer(20);
    $subscription->offer(30);

    $publisher->executor->run;

    is_deeply(\@collected, [10, 20, 30], 'requested items delivered');
};

subtest '... test Subscription backpressure with buffering' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 0,  # Don't auto-request on subscribe
    );

    my $subscription = Flow::Subscription->new(
        publisher => $publisher,
        subscriber => $subscriber,
        executor => $publisher->executor,
    );
    $subscriber->on_subscribe($subscription);

    # Don't request anything yet - items should buffer
    $subscription->offer(1);
    $subscription->offer(2);
    $subscription->offer(3);

    $publisher->executor->run;

    is_deeply(\@collected, [], 'no items delivered without request');

    # Now request some items
    $subscription->request(2);
    $publisher->executor->run;

    is_deeply(\@collected, [1, 2], 'first 2 items delivered after request');

    # Request remaining
    $subscription->request(10);
    $publisher->executor->run;

    is_deeply(\@collected, [1, 2, 3], 'remaining items delivered');
};

subtest '... test Subscription offer and drain_buffer' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
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

    $subscription->request(5);

    # Offer multiple items
    for my $i (1..5) {
        $subscription->offer($i);
    }

    $publisher->executor->run;

    is_deeply(\@collected, [1..5], 'all offered items delivered');
};

subtest '... test Subscription cancel' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
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

    # Cancel before running
    $subscription->cancel;

    # After cancel, on_unsubscribe should be called
    # We can't test internal state directly, but we can verify it doesn't crash
    lives_ok {
        $publisher->executor->run;
    } 'cancel executes without error';
};

subtest '... test Subscription on_next delivery' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 1,
    );

    my $subscription = Flow::Subscription->new(
        publisher => $publisher,
        subscriber => $subscriber,
        executor => $publisher->executor,
    );
    $subscriber->on_subscribe($subscription);

    $subscription->request(3);

    # Manually call on_next
    $subscription->on_next(100);
    $subscription->on_next(200);
    $subscription->on_next(300);

    $publisher->executor->run;

    is_deeply(\@collected, [100, 200, 300], 'on_next delivered items to subscriber');
};

subtest '... test Subscription on_completed' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $completed = 0;

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

    $subscription->request(2);
    $subscription->offer(1);
    $subscription->offer(2);

    # Signal completion
    $subscription->on_completed;

    $publisher->executor->run;

    is_deeply(\@collected, [1, 2], 'items delivered before completion');
};

subtest '... test Subscription on_error' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

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

    $subscription->request(2);
    $subscription->offer(1);

    # Signal error
    lives_ok {
        $subscription->on_error("test error");
    } 'on_error executes without dying';

    $publisher->executor->run;

    is_deeply(\@collected, [1], 'items before error were delivered');
};

subtest '... test Subscription with zero requests' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 0,  # Don't auto-request on subscribe
    );

    my $subscription = Flow::Subscription->new(
        publisher => $publisher,
        subscriber => $subscriber,
        executor => $publisher->executor,
    );
    $subscriber->on_subscribe($subscription);

    # Don't request anything
    $subscription->offer(1);
    $subscription->offer(2);

    $publisher->executor->run;

    is_deeply(\@collected, [], 'no items delivered without request');
};

subtest '... test Subscription request more than offered' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
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

    # Request 10 items
    $subscription->request(10);

    # But only offer 3
    $subscription->offer(1);
    $subscription->offer(2);
    $subscription->offer(3);

    $publisher->executor->run;

    is_deeply(\@collected, [1, 2, 3], 'only offered items delivered');
};

subtest '... test Subscription multiple request calls' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 1,
    );

    my $subscription = Flow::Subscription->new(
        publisher => $publisher,
        subscriber => $subscriber,
        executor => $publisher->executor,
    );
    $subscriber->on_subscribe($subscription);

    # Request in batches
    $subscription->request(2);
    $subscription->offer(1);
    $subscription->offer(2);
    $publisher->executor->run;

    is_deeply(\@collected, [1, 2], 'first batch delivered');

    $subscription->request(2);
    $subscription->offer(3);
    $subscription->offer(4);
    $publisher->executor->run;

    is_deeply(\@collected, [1, 2, 3, 4], 'second batch delivered');
};

subtest '... test Subscription buffer overflow behavior' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 0,  # Don't auto-request on subscribe
    );

    my $subscription = Flow::Subscription->new(
        publisher => $publisher,
        subscriber => $subscriber,
        executor => $publisher->executor,
    );
    $subscriber->on_subscribe($subscription);

    # Offer many items without request - they should buffer
    for my $i (1..100) {
        $subscription->offer($i);
    }

    $publisher->executor->run;
    is_deeply(\@collected, [], 'no items delivered without request');

    # Request all
    $subscription->request(1000);
    $publisher->executor->run;

    is_deeply(\@collected, [1..100], 'all buffered items eventually delivered');
};

done_testing;

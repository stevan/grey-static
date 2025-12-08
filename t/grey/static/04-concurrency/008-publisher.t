#!/usr/bin/env perl

use v5.42;

use Test::More;
use Test::Exception;

use grey::static qw[ functional concurrency ];

subtest '... test Publisher creation' => sub {
    my $publisher = Flow::Publisher->new;
    ok($publisher, 'created a Publisher');
    isa_ok($publisher->executor, 'Flow::Executor', 'has an executor');
    is($publisher->subscription, undef, 'no subscription initially');
};

subtest '... test Publisher submit and buffer' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    # Subscribe first, then submit
    $publisher->subscribe($subscriber);

    $publisher->submit(10);
    $publisher->submit(20);
    $publisher->submit(30);

    $publisher->start;

    is_deeply(\@collected, [10, 20, 30], 'buffered items delivered to subscriber');
};

subtest '... test Publisher subscribe/unsubscribe' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 5,
    );

    $publisher->subscribe($subscriber);
    ok($publisher->subscription, 'subscription created');
    isa_ok($publisher->subscription, 'Flow::Subscription', 'correct subscription type');

    $publisher->submit(100);
    $publisher->start;

    is_deeply(\@collected, [100], 'subscriber received data');

    # Unsubscribe
    my $old_subscription = $publisher->subscription;
    $publisher->unsubscribe($old_subscription);
    is($publisher->subscription, undef, 'subscription cleared after unsubscribe');
};

subtest '... test Publisher with no subscriber' => sub {
    my $publisher = Flow::Publisher->new;

    # Should be able to submit without subscriber (buffering)
    lives_ok { $publisher->submit(1) } 'submit without subscriber lives';
    lives_ok { $publisher->submit(2) } 'submit another without subscriber lives';

    # Items submitted before subscription are buffered and will be delivered
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    $publisher->subscribe($subscriber);
    $publisher->submit(3);
    $publisher->submit(4);
    $publisher->start;

    is_deeply(\@collected, [1, 2, 3, 4], 'all buffered items delivered including pre-subscription items');
};

subtest '... test Publisher close' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    $publisher->subscribe($subscriber);

    # Deliver some items first
    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->start;

    is_deeply(\@collected, [1, 2], 'items delivered before close');

    # Submit more items then close
    $publisher->submit(3);
    $publisher->submit(4);

    # Note: close() now delivers buffered items before completing
    $publisher->close;

    is_deeply(\@collected, [1, 2, 3, 4], 'close delivers remaining buffer items');
};

subtest '... test Publisher executor integration' => sub {
    my $publisher = Flow::Publisher->new;
    my $executor = $publisher->executor;

    isa_ok($executor, 'Flow::Executor', 'has executor');

    my @order;
    $executor->next_tick(sub { push @order, 'first' });
    $executor->next_tick(sub { push @order, 'second' });

    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    $publisher->subscribe($subscriber);
    $publisher->submit(100);
    $publisher->start;

    # Executor callbacks and drain_buffer should all execute
    ok(scalar(@order) >= 2, 'executor callbacks executed');
    is_deeply(\@collected, [100], 'data delivered');
};

subtest '... test Publisher multiple submits between ticks' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 100,
    );

    $publisher->subscribe($subscriber);

    # Submit multiple items
    for my $i (1..10) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [1..10], 'all items delivered in order');
};

subtest '... test Publisher with slow consumer (backpressure)' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    # Request only 2 items at a time
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 2,
    );

    $publisher->subscribe($subscriber);

    # Submit 5 items
    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);
    $publisher->submit(4);
    $publisher->submit(5);

    $publisher->start;

    # All items should eventually be delivered
    is_deeply(\@collected, [1, 2, 3, 4, 5], 'all items delivered despite backpressure');
};

done_testing;

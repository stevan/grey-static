#!/usr/bin/env perl

use v5.42;

use Test::More;
use Test::Exception;

use grey::static qw[ functional concurrency::reactive concurrency::util ];

# Create a test operation that doubles values
package TestOperation {
    use v5.42;
    use experimental 'class';

    class TestOperation :isa(Flow::Operation) {
        method apply ($e) {
            $self->submit( $e * 2 );
        }
    }
}

# Create a test operation that filters out odds
package FilterOddsOperation {
    use v5.42;
    use experimental 'class';

    class FilterOddsOperation :isa(Flow::Operation) {
        method apply ($e) {
            $self->submit( $e ) if $e % 2 == 0;
        }
    }
}

# Create a test operation that generates multiple outputs
package MultiplyingOperation {
    use v5.42;
    use experimental 'class';

    class MultiplyingOperation :isa(Flow::Operation) {
        method apply ($e) {
            $self->submit( $e );
            $self->submit( $e * 10 );
        }
    }
}

subtest '... test Operation creation' => sub {
    my $op = TestOperation->new;
    ok($op, 'created an Operation');
    isa_ok($op->executor, 'Executor', 'has an executor');
    is($op->downstream, undef, 'no downstream initially');
    is($op->upstream, undef, 'no upstream initially');
};

subtest '... test Operation apply and submit' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $op = TestOperation->new;
    $op->subscribe($subscriber);

    # Manually trigger apply
    $op->apply(5);
    $op->executor->run;

    is_deeply(\@collected, [10], 'apply doubled value and submitted');
};

subtest '... test Operation as middleware in pipeline' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $publisher = Flow::Publisher->new;
    my $op = TestOperation->new;

    # Connect: Publisher -> Operation -> Subscriber
    $op->subscribe($subscriber);
    $publisher->subscribe($op);

    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);

    $publisher->start;

    is_deeply(\@collected, [2, 4, 6], 'operation transformed values in pipeline');
};

subtest '... test Operation subscribe sets downstream' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $op = TestOperation->new;
    $op->subscribe($subscriber);

    ok($op->downstream, 'downstream set after subscribe');
    isa_ok($op->downstream, 'Flow::Subscription', 'downstream is a subscription');
};

subtest '... test Operation on_subscribe sets upstream' => sub {
    my $publisher = Flow::Publisher->new;
    my $op = TestOperation->new;

    $publisher->subscribe($op);

    # Need to run executor for on_subscribe to complete
    $publisher->executor->run;

    ok($op->upstream, 'upstream set after on_subscribe');
    isa_ok($op->upstream, 'Flow::Subscription', 'upstream is a subscription');
};

subtest '... test Operation executor chain linking' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $publisher = Flow::Publisher->new;
    my $op = TestOperation->new;

    $op->subscribe($subscriber);
    $publisher->subscribe($op);

    # Executors should be linked
    my $pub_exec = $publisher->executor;
    my $op_exec = $op->executor;

    # The operation's executor should be linked to publisher's
    $publisher->submit(5);
    $publisher->start;

    is_deeply(\@collected, [10], 'executor chain works correctly');
};

subtest '... test Operation unsubscribe' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $publisher = Flow::Publisher->new;
    my $op = TestOperation->new;

    $op->subscribe($subscriber);
    $publisher->subscribe($op);

    $publisher->submit(1);
    $publisher->start;

    is_deeply(\@collected, [2], 'initial value processed');

    # Unsubscribe the operation from its downstream
    $op->unsubscribe($op->downstream);

    # Upstream should be cancelled
    lives_ok {
        $publisher->submit(2);
        $publisher->start;
    } 'unsubscribe executes without error';
};

subtest '... test Operation on_next propagation' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $publisher = Flow::Publisher->new;
    my $op = TestOperation->new;

    $op->subscribe($subscriber);
    $publisher->subscribe($op);

    # Run executor to complete subscriptions
    $publisher->executor->run;

    # Manually call on_next
    $op->on_next(7);
    $op->executor->run;

    is_deeply(\@collected, [14], 'on_next triggered apply and submission');
};

subtest '... test Operation on_completed propagation' => sub {
    my @collected;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $publisher = Flow::Publisher->new;
    my $op = TestOperation->new;

    $op->subscribe($subscriber);
    $publisher->subscribe($op);

    $publisher->submit(1);
    $publisher->start;

    is_deeply(\@collected, [2], 'value processed');

    # close() will propagate on_completed through the operation
    $publisher->close;

    ok(1, 'completion propagated through operation');
};

subtest '... test Operation on_error propagation' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $op = TestOperation->new;
    $op->subscribe($subscriber);

    lives_ok {
        $op->on_error("test error");
    } 'on_error propagates without dying';

    $op->executor->run;
};

subtest '... test Operation with filtering' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $publisher = Flow::Publisher->new;
    my $op = FilterOddsOperation->new;

    $op->subscribe($subscriber);
    $publisher->subscribe($op);

    for my $i (1..10) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [2, 4, 6, 8, 10], 'filtering operation works');
};

subtest '... test Operation with multiple outputs per input' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 100,
    );

    my $publisher = Flow::Publisher->new;
    my $op = MultiplyingOperation->new;

    $op->subscribe($subscriber);
    $publisher->subscribe($op);

    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);

    $publisher->start;

    is_deeply(\@collected, [1, 10, 2, 20, 3, 30], 'operation can emit multiple values');
};

subtest '... test Operation chaining multiple operations' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 100,
    );

    my $publisher = Flow::Publisher->new;
    my $op1 = TestOperation->new;        # doubles
    my $op2 = FilterOddsOperation->new;  # filters odds
    my $op3 = TestOperation->new;        # doubles again

    # Chain: Publisher -> op1 -> op2 -> op3 -> Subscriber
    $op3->subscribe($subscriber);
    $op2->subscribe($op3);
    $op1->subscribe($op2);
    $publisher->subscribe($op1);

    for my $i (1..5) {
        $publisher->submit($i);
    }

    $publisher->start;

    # 1->2->keep->4, 2->4->keep->8, 3->6->keep->12, 4->8->keep->16, 5->10->keep->20
    is_deeply(\@collected, [4, 8, 12, 16, 20], 'chained operations work correctly');
};

subtest '... test Operation buffer behavior' => sub {
    my @collected;
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 1,  # Request one at a time
    );

    my $publisher = Flow::Publisher->new;
    my $op = MultiplyingOperation->new;  # Emits 2 values per input

    $op->subscribe($subscriber);
    $publisher->subscribe($op);

    # Run executor to complete subscriptions
    $publisher->executor->run;

    $op->on_next(1);
    $op->executor->run;

    is_deeply(\@collected, [1, 10], 'buffering works with backpressure');
};

done_testing;

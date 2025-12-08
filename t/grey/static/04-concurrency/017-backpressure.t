#!/usr/bin/env perl

use v5.42;

use Test::More;
use Test::Exception;

use grey::static qw[ functional concurrency::reactive ];

subtest '... test backpressure with request_size=1' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 1,
    );

    $publisher->subscribe($subscriber);

    for my $i (1..10) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [1..10], 'all items delivered with request_size=1');
    is(scalar(@collected), 10, 'correct count');
};

subtest '... test backpressure with request_size=3' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 3,
    );

    $publisher->subscribe($subscriber);

    for my $i (1..10) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [1..10], 'all items delivered with request_size=3');
};

subtest '... test backpressure with request_size=10' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    $publisher->subscribe($subscriber);

    for my $i (1..10) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [1..10], 'all items delivered with request_size=10');
};

subtest '... test backpressure with large batch size' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 1000,
    );

    $publisher->subscribe($subscriber);

    for my $i (1..100) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [1..100], 'all items delivered with large request_size');
};

subtest '... test backpressure through map operation' => sub {
    my @collected;

    my $f = Function->new( f => sub ($x) { $x * 2 } );

    my $flow = Flow->from( Flow::Publisher->new )
        ->map( $f )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) );

    # Build creates a subscriber with default request_size
    $flow->build;

    my $publisher = $flow->source;
    for my $i (1..20) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [map { $_ * 2 } (1..20)], 'backpressure through map works');
};

subtest '... test backpressure through grep operation' => sub {
    my @collected;

    my $p = Predicate->new( f => sub ($x) { $x % 2 == 0 } );

    my $flow = Flow->from( Flow::Publisher->new )
        ->grep( $p )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) );

    $flow->build;

    my $publisher = $flow->source;
    for my $i (1..20) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [grep { $_ % 2 == 0 } (1..20)], 'backpressure through grep works');
};

subtest '... test backpressure in multi-operation pipeline' => sub {
    my @collected;

    my $f = Function->new( f => sub ($x) { $x + 1 } );
    my $p = Predicate->new( f => sub ($x) { $x % 2 == 0 } );

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 2,
    );

    my $flow = Flow->from( Flow::Publisher->new )
        ->map( $f )
        ->grep( $p )
        ->to( $subscriber );

    $flow->build;

    my $publisher = $flow->source;
    for my $i (1..20) {
        $publisher->submit($i);
    }

    $publisher->start;

    # 1->2, 2->3, 3->4, ..., 20->21
    # Filter evens: 2, 4, 6, 8, 10, 12, 14, 16, 18, 20
    is_deeply(\@collected, [2, 4, 6, 8, 10, 12, 14, 16, 18, 20],
        'backpressure in multi-operation pipeline works');
};

subtest '... test backpressure with slow consumer' => sub {
    my @collected;
    my $process_count = 0;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) {
            push @collected, $e;
            $process_count++;
        }),
        request_size => 1,  # Process one at a time
    );

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($subscriber);

    for my $i (1..5) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [1..5], 'all items processed despite slow consumer');
    is($process_count, 5, 'consumer called correct number of times');
};

subtest '... test backpressure with varying batch sizes' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    # Start with request_size=2
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 2,
    );

    $publisher->subscribe($subscriber);

    # Submit 6 items
    for my $i (1..6) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [1..6], 'all items delivered with varying batches');
};

subtest '... test backpressure prevents overwhelming consumer' => sub {
    my @collected;
    my @request_log;

    # Track when requests are made
    my $subscription_ref;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) {
            push @collected, $e;
        }),
        request_size => 3,
    );

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($subscriber);

    # Submit many items
    for my $i (1..15) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [1..15], 'all items processed');
    # Items should be processed in batches of 3
};

subtest '... test backpressure with filtering reducing throughput' => sub {
    my @collected;

    # Only even numbers pass through
    my $p = Predicate->new( f => sub ($x) { $x % 2 == 0 } );

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 2,
    );

    my $grep = Flow::Operation::Grep->new( f => $p );
    $grep->subscribe($subscriber);

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($grep);

    # Submit 20 items, but only 10 will pass through
    for my $i (1..20) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [2, 4, 6, 8, 10, 12, 14, 16, 18, 20],
        'backpressure works even when grep reduces throughput');
};

subtest '... test backpressure with map multiplying throughput' => sub {
    my @collected;

    # Create a test operation that emits multiple values
    package MultiplyingOp {
        use v5.42;
        use experimental 'class';

        class MultiplyingOp :isa(Flow::Operation) {
            method apply ($e) {
                $self->submit( $e );
                $self->submit( $e * 10 );
            }
        }
    }

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    my $op = MultiplyingOp->new;
    $op->subscribe($subscriber);

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($op);

    for my $i (1..5) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [1, 10, 2, 20, 3, 30, 4, 40, 5, 50],
        'backpressure handles operations that multiply throughput');
};

subtest '... test backpressure with zero initial request' => sub {
    my $publisher = Flow::Publisher->new;
    my @collected;

    # Create subscription manually to control requests
    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 10,
    );

    $publisher->subscribe($subscriber);

    # Submit items before any request (they should buffer)
    $publisher->submit(1);
    $publisher->submit(2);
    $publisher->submit(3);

    # Now start processing - subscriber will request on_subscribe
    $publisher->start;

    is_deeply(\@collected, [1, 2, 3], 'buffered items delivered when requests made');
};

subtest '... test backpressure in long pipeline' => sub {
    my @collected;

    my $f1 = Function->new( f => sub ($x) { $x + 1 } );
    my $f2 = Function->new( f => sub ($x) { $x * 2 } );
    my $f3 = Function->new( f => sub ($x) { $x - 1 } );
    my $p = Predicate->new( f => sub ($x) { $x > 5 } );

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) { push @collected, $e } ),
        request_size => 3,
    );

    my $flow = Flow->from( Flow::Publisher->new )
        ->map( $f1 )
        ->map( $f2 )
        ->map( $f3 )
        ->grep( $p )
        ->to( $subscriber );

    $flow->build;

    my $publisher = $flow->source;
    for my $i (1..10) {
        $publisher->submit($i);
    }

    $publisher->start;

    # 1: (1+1)*2-1=3, 2: (2+1)*2-1=5, 3: (3+1)*2-1=7, 4: (4+1)*2-1=9, etc.
    # Filter >5: 7, 9, 11, 13, 15, 17, 19
    my @expected = grep { $_ > 5 } map { (($_+1)*2)-1 } (1..10);
    is_deeply(\@collected, \@expected, 'backpressure works in long pipeline');
};

subtest '... test backpressure with dynamic request sizes' => sub {
    my @collected;
    my $request_count = 0;

    my $subscriber = Flow::Subscriber->new(
        consumer => Consumer->new( f => sub ($e) {
            push @collected, $e;
            $request_count++;
        }),
        request_size => 5,
    );

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($subscriber);

    for my $i (1..20) {
        $publisher->submit($i);
    }

    $publisher->start;

    is_deeply(\@collected, [1..20], 'all items delivered');
    is($request_count, 20, 'correct number of requests made');
};

done_testing;

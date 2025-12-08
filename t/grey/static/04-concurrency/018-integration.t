#!/usr/bin/env perl

use v5.42;

use Test::More;
use Test::Exception;

use grey::static qw[ functional concurrency ];

subtest '... test data transformation pipeline' => sub {
    my @collected;

    # Scenario: Transform numbers, filter, and collect results
    my $double = Function->new( f => sub ($x) { $x * 2 } );
    my $is_large = Predicate->new( f => sub ($x) { $x > 10 } );
    my $add_suffix = Function->new( f => sub ($x) { "value=$x" } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( $double )
        ->grep( $is_large )
        ->map( $add_suffix )
        ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )

        ->build;
    for my $i (1..10) {
        $publisher->submit($i);
    }
    $publisher->start;

    # 1->2, 2->4, 3->6, 4->8, 5->10, 6->12, 7->14, 8->16, 9->18, 10->20
    # Filter >10: 12, 14, 16, 18, 20
    # Add suffix: value=12, value=14, ...
    is_deeply(\@collected, [
        'value=12', 'value=14', 'value=16', 'value=18', 'value=20'
    ], 'data transformation pipeline works');
};

subtest '... test event processing pipeline' => sub {
    my @events;

    # Scenario: Process events, filter by type, extract data
    my $is_important = Predicate->new( f => sub ($e) {
        ref($e) eq 'HASH' && $e->{priority} && $e->{priority} eq 'high'
    });

    my $extract_message = Function->new( f => sub ($e) {
        uc($e->{message})
    });

    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( $is_important )
        ->map( $extract_message )
        ->to( Consumer->new( f => sub ($e) { push @events, $e } ) )

        ->build;
    $publisher->submit({ priority => 'low', message => 'debug info' });
    $publisher->submit({ priority => 'high', message => 'critical error' });
    $publisher->submit({ priority => 'medium', message => 'warning' });
    $publisher->submit({ priority => 'high', message => 'system failure' });
    $publisher->start;

    is_deeply(\@events, ['CRITICAL ERROR', 'SYSTEM FAILURE'],
        'event processing pipeline works');
};

subtest '... test number sequence processing' => sub {
    my @results;

    # Scenario: Generate fibonacci-like sequence using reactive flow
    my $sum = 0;
    my $count = 0;

    my $accumulate = Consumer->new( f => sub ($e) {
        $sum += $e;
        $count++;
        push @results, $e;
    });

    my $is_even = Predicate->new( f => sub ($x) { $x % 2 == 0 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( $is_even )
        ->to( $accumulate )

        ->build;
    for my $i (1..20) {
        $publisher->submit($i);
    }
    $publisher->start;

    is_deeply(\@results, [2, 4, 6, 8, 10, 12, 14, 16, 18, 20],
        'sequence processing works');
    is($sum, 110, 'accumulated sum correct');
    is($count, 10, 'count correct');
};

subtest '... test string processing pipeline' => sub {
    my @words;

    # Scenario: Process text, filter, transform
    my $is_long = Predicate->new( f => sub ($s) { length($s) > 4 } );
    my $capitalize = Function->new( f => sub ($s) { ucfirst(lc($s)) } );
    my $add_punctuation = Function->new( f => sub ($s) { "$s!" } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( $is_long )
        ->map( $capitalize )
        ->map( $add_punctuation )
        ->to( Consumer->new( f => sub ($e) { push @words, $e } ) )

        ->build;
    for my $word (qw(the quick brown fox jumps over lazy dog)) {
        $publisher->submit($word);
    }
    $publisher->start;

    is_deeply(\@words, ['Quick!', 'Brown!', 'Jumps!'],
        'string processing pipeline works');
};

subtest '... test data aggregation with side effects' => sub {
    my @all_values;
    my $max = 0;
    my $min = 999999;

    my $track_stats = Consumer->new( f => sub ($e) {
        push @all_values, $e;
        $max = $e if $e > $max;
        $min = $e if $e < $min;
    });

    my $double = Function->new( f => sub ($x) { $x * 2 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( $double )
        ->to( $track_stats )

        ->build;
    for my $i (1..10) {
        $publisher->submit($i);
    }
    $publisher->start;

    is_deeply(\@all_values, [map { $_ * 2 } (1..10)],
        'all values collected');
    is($max, 20, 'max value tracked');
    is($min, 2, 'min value tracked');
};

subtest '... test multi-stage filtering' => sub {
    my @results;

    # Scenario: Multiple filter stages for complex criteria
    my $is_positive = Predicate->new( f => sub ($x) { $x > 0 } );
    my $is_not_divisible_by_3 = Predicate->new( f => sub ($x) { $x % 3 != 0 } );
    my $is_less_than_20 = Predicate->new( f => sub ($x) { $x < 20 } );

    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( $is_positive )
        ->grep( $is_not_divisible_by_3 )
        ->grep( $is_less_than_20 )
        ->to( Consumer->new( f => sub ($e) { push @results, $e } ) )

        ->build;
    for my $i (-5..25) {
        $publisher->submit($i);
    }
    $publisher->start;

    # Positive, not divisible by 3, less than 20
    # 1,2,4,5,7,8,10,11,13,14,16,17,19
    my @expected = grep { $_ > 0 && $_ % 3 != 0 && $_ < 20 } (-5..25);
    is_deeply(\@results, \@expected, 'multi-stage filtering works');
};

subtest '... test data validation and transformation' => sub {
    my @valid_data;
    my @errors;

    # Scenario: Validate input, transform valid data, collect errors
    my $is_valid_hash = Predicate->new( f => sub ($x) {
        ref($x) eq 'HASH' && exists $x->{id} && exists $x->{value}
    });

    my $extract_and_format = Function->new( f => sub ($x) {
        { id => $x->{id}, doubled => $x->{value} * 2 }
    });

    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( $is_valid_hash )
        ->map( $extract_and_format )
        ->to( Consumer->new( f => sub ($e) { push @valid_data, $e } ) )

        ->build;
    $publisher->submit({ id => 1, value => 10 });
    $publisher->submit("invalid");
    $publisher->submit({ id => 2, value => 20 });
    $publisher->submit({ id => 3 });  # Missing value
    $publisher->submit({ id => 4, value => 30 });
    $publisher->start;

    is_deeply(\@valid_data, [
        { id => 1, doubled => 20 },
        { id => 2, doubled => 40 },
        { id => 4, doubled => 60 },
    ], 'data validation and transformation works');
};

subtest '... test reactive counter with feedback' => sub {
    my @sequence;
    my $publisher = Flow::Publisher->new;

    my $counter = 0;
    my $generate_next = Consumer->new( f => sub ($e) {
        push @sequence, $e;
        $counter++;
        $publisher->submit($e + 1) if $counter < 10;
    });

    my $subscriber = Flow::Subscriber->new(
        consumer => $generate_next,
        request_size => 1,
    );

    $publisher->subscribe($subscriber);
    $publisher->submit(1);
    $publisher->start;

    is_deeply(\@sequence, [1..10], 'reactive counter with feedback works');
};

subtest '... test complex business logic pipeline' => sub {
    my @processed_orders;

    # Scenario: Order processing system
    my $is_valid_order = Predicate->new( f => sub ($o) {
        ref($o) eq 'HASH' && $o->{amount} && $o->{amount} > 0
    });

    my $is_large_order = Predicate->new( f => sub ($o) {
        $o->{amount} > 100
    });

    my $add_priority = Function->new( f => sub ($o) {
        return { %$o, priority => 'high' };
    });

    my $calculate_shipping = Function->new( f => sub ($o) {
        my $shipping = $o->{amount} > 200 ? 0 : 10;
        return { %$o, shipping => $shipping, total => $o->{amount} + $shipping };
    });

    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( $is_valid_order )
        ->grep( $is_large_order )
        ->map( $add_priority )
        ->map( $calculate_shipping )
        ->to( Consumer->new( f => sub ($e) { push @processed_orders, $e } ) )

        ->build;
    $publisher->submit({ id => 1, amount => 50 });    # Too small
    $publisher->submit({ id => 2, amount => 150 });   # Large
    $publisher->submit({ id => 3, amount => -10 });   # Invalid
    $publisher->submit({ id => 4, amount => 250 });   # Large, free shipping
    $publisher->submit({ id => 5 });                  # Invalid
    $publisher->submit({ id => 6, amount => 120 });   # Large
    $publisher->start;

    is(scalar(@processed_orders), 3, 'correct number of orders processed');
    is($processed_orders[0]{priority}, 'high', 'priority added');
    is($processed_orders[0]{total}, 160, 'shipping calculated (150+10)');
    is($processed_orders[1]{total}, 250, 'free shipping for large order');
    is($processed_orders[2]{total}, 130, 'shipping calculated (120+10)');
};

subtest '... test sensor data processing' => sub {
    my @alerts;
    my @readings;

    # Scenario: Process sensor data, detect anomalies
    my $is_valid_reading = Predicate->new( f => sub ($r) {
        ref($r) eq 'HASH' && defined $r->{temp}
    });

    my $is_anomaly = Predicate->new( f => sub ($r) {
        $r->{temp} > 100 || $r->{temp} < 0
    });

    my $create_alert = Function->new( f => sub ($r) {
        {
            timestamp => time,
            sensor => $r->{sensor} // 'unknown',
            temp => $r->{temp},
            severity => $r->{temp} > 100 ? 'critical' : 'warning'
        }
    });

    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( $is_valid_reading )
        ->grep( $is_anomaly )
        ->map( $create_alert )
        ->to( Consumer->new( f => sub ($e) { push @alerts, $e } ) )

        ->build;
    $publisher->submit({ sensor => 'A', temp => 25 });
    $publisher->submit({ sensor => 'B', temp => 150 });
    $publisher->submit({ sensor => 'C', temp => -5 });
    $publisher->submit({ sensor => 'D', temp => 30 });
    $publisher->submit({ sensor => 'E', temp => 200 });
    $publisher->start;

    is(scalar(@alerts), 3, 'correct number of alerts');
    is($alerts[0]{severity}, 'critical', 'high temp alert');
    is($alerts[1]{severity}, 'warning', 'low temp alert');
    is($alerts[2]{severity}, 'critical', 'very high temp alert');
};

subtest '... test batch processing with completion' => sub {
    my @batches;
    my $current_batch = [];

    my $batch_collector = Consumer->new( f => sub ($e) {
        push @$current_batch, $e;
        if (scalar(@$current_batch) >= 5) {
            push @batches, [@$current_batch];
            $current_batch = [];
        }
    });

    my $subscriber = Flow::Subscriber->new(
        consumer => $batch_collector,
        request_size => 10,
    );

    my $publisher = Flow::Publisher->new;
    $publisher->subscribe($subscriber);

    for my $i (1..13) {
        $publisher->submit($i);
    }

    # Deliver all items
    $publisher->start;

    # Flush final partial batch
    push @batches, [@$current_batch] if @$current_batch;

    # Now close
    $publisher->close;

    is(scalar(@batches), 3, 'correct number of batches');
    is_deeply($batches[0], [1,2,3,4,5], 'first batch');
    is_deeply($batches[1], [6,7,8,9,10], 'second batch');
    is_deeply($batches[2], [11,12,13], 'final partial batch');
};

done_testing;

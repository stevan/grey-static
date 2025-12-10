#!/usr/bin/env perl

use v5.42;
use lib 'lib';
use Benchmark qw(cmpthese timethese);
use grey::static qw[ functional stream concurrency::reactive ];

say "=" x 80;
say "Benchmark 4: Stream vs Flow Comparison";
say "=" x 80;
say "";

# Test 1: Simple transformation
say "Test 1: Simple Transformation (map)";
say "-" x 80;

my $results = timethese(1000, {
    'Stream_map' => sub {
        my @result = Stream->of(1..100)
            ->map(sub ($x) { $x * 2 })
            ->collect(Stream::Collectors->ToList);
    },

    'Flow_map' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->map( sub ($x) { $x * 2 } )
            ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )
            ->build;

        for (1..100) {
            $publisher->submit($_);
        }
        $publisher->close;
    },
});

say "";
say "Comparison:";
cmpthese($results);

# Test 2: Filter and transform
say "";
say "Test 2: Filter and Transform (grep + map)";
say "-" x 80;

my $filter_results = timethese(1000, {
    'Stream_grep_map' => sub {
        my @result = Stream->of(1..100)
            ->grep(sub ($x) { $x % 2 == 0 })
            ->map(sub ($x) { $x * 2 })
            ->collect(Stream::Collectors->ToList);
    },

    'Flow_grep_map' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->grep( sub ($x) { $x % 2 == 0 } )
            ->map( sub ($x) { $x * 2 } )
            ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )
            ->build;

        for (1..100) {
            $publisher->submit($_);
        }
        $publisher->close;
    },
});

say "";
say "Comparison:";
cmpthese($filter_results);

# Test 3: Complex pipeline
say "";
say "Test 3: Complex Pipeline (multiple operations)";
say "-" x 80;

my $complex_results = timethese(500, {
    'Stream_complex' => sub {
        my @result = Stream->of(1..1000)
            ->map(sub ($x) { $x * 2 })
            ->grep(sub ($x) { $x > 100 })
            ->map(sub ($x) { $x + 10 })
            ->grep(sub ($x) { $x % 2 == 0 })
            ->map(sub ($x) { $x / 2 })
            ->collect(Stream::Collectors->ToList);
    },

    'Flow_complex' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->map( sub ($x) { $x * 2 } )
            ->grep( sub ($x) { $x > 100 } )
            ->map( sub ($x) { $x + 10 } )
            ->grep( sub ($x) { $x % 2 == 0 } )
            ->map( sub ($x) { $x / 2 } )
            ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )
            ->build;

        for (1..1000) {
            $publisher->submit($_);
        }
        $publisher->close;
    },
});

say "";
say "Comparison:";
cmpthese($complex_results);

# Test 4: Lazy vs eager evaluation
say "";
say "Test 4: Lazy Evaluation (take early exit)";
say "-" x 80;

my $lazy_results = timethese(10000, {
    'Stream_lazy_take' => sub {
        # Stream is lazy - only processes 10 elements
        my @result = Stream->of(1..1000000)
            ->map(sub ($x) { $x * 2 })
            ->map(sub ($x) { $x + 1 })
            ->take(10)
            ->collect(Stream::Collectors->ToList);
    },

    'Flow_early_exit' => sub {
        # Flow processes all submitted elements
        my @collected;
        my $count = 0;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->map( sub ($x) { $x * 2 } )
            ->map( sub ($x) { $x + 1 } )
            ->to( Consumer->new( f => sub ($e) {
                push @collected, $e;
                $count++;
            } ) )
            ->build;

        # Only submit 10 elements
        for (1..10) {
            $publisher->submit($_);
        }
        $publisher->close;
    },
});

say "";
say "Comparison:";
cmpthese($lazy_results);

# Test 5: Reduction operation
say "";
say "Test 5: Reduction (sum)";
say "-" x 80;

my $reduce_results = timethese(1000, {
    'Stream_reduce' => sub {
        my $sum = Stream->of(1..100)
            ->reduce(0, sub ($acc, $x) { $acc + $x });
    },

    'Flow_accumulate' => sub {
        my $sum = 0;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->to( Consumer->new( f => sub ($e) { $sum += $e } ) )
            ->build;

        for (1..100) {
            $publisher->submit($_);
        }
        $publisher->close;
    },
});

say "";
say "Comparison:";
cmpthese($reduce_results);

# Test 6: Large dataset
say "";
say "Test 6: Large Dataset (10,000 elements)";
say "-" x 80;

my $large_results = timethese(100, {
    'Stream_large' => sub {
        my @result = Stream->of(1..10000)
            ->map(sub ($x) { $x * 2 })
            ->grep(sub ($x) { $x % 3 == 0 })
            ->collect(Stream::Collectors->ToList);
    },

    'Flow_large' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->map( sub ($x) { $x * 2 } )
            ->grep( sub ($x) { $x % 3 == 0 } )
            ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )
            ->build;

        for (1..10000) {
            $publisher->submit($_);
        }
        $publisher->close;
    },
});

say "";
say "Comparison:";
cmpthese($large_results);

say "";
say "=" x 80;
say "Benchmark 4 Complete";
say "=" x 80;
say "";
say "INTERPRETATION GUIDE:";
say "- Stream (pull-based): Lazy evaluation, good for early exits";
say "- Flow (push-based): Async/reactive, good for event streams";
say "- Stream typically faster for batch processing";
say "- Flow better for real-time event handling with backpressure";

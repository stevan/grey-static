#!/usr/bin/env perl

use v5.42;
use lib 'lib';
use Benchmark qw(cmpthese timethese);
use grey::static qw[ functional concurrency::reactive ];

say "=" x 80;
say "Benchmark 3: Flow Throughput";
say "=" x 80;
say "";

# Test 1: Simple pipeline throughput
say "Test 1: Simple Pipeline (Publisher -> Subscriber)";
say "-" x 80;

my $results = timethese(100, {
    '100_elements' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )
            ->build;

        for (1..100) {
            $publisher->submit($_);
        }
        $publisher->close;
    },

    '1000_elements' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )
            ->build;

        for (1..1000) {
            $publisher->submit($_);
        }
        $publisher->close;
    },

    '10000_elements' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
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
cmpthese($results);

# Test 2: Pipeline with operations
say "";
say "Test 2: Pipeline with Map Operations";
say "-" x 80;

my $map_results = timethese(100, {
    'no_ops' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )
            ->build;

        for (1..1000) {
            $publisher->submit($_);
        }
        $publisher->close;
    },

    'one_map' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->map( sub ($x) { $x * 2 } )
            ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )
            ->build;

        for (1..1000) {
            $publisher->submit($_);
        }
        $publisher->close;
    },

    'three_maps' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->map( sub ($x) { $x * 2 } )
            ->map( sub ($x) { $x + 1 } )
            ->map( sub ($x) { $x / 2 } )
            ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )
            ->build;

        for (1..1000) {
            $publisher->submit($_);
        }
        $publisher->close;
    },

    'five_maps' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->map( sub ($x) { $x * 2 } )
            ->map( sub ($x) { $x + 1 } )
            ->map( sub ($x) { $x / 2 } )
            ->map( sub ($x) { $x - 1 } )
            ->map( sub ($x) { $x * 3 } )
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
cmpthese($map_results);

# Test 3: Pipeline with Grep (filtering)
say "";
say "Test 3: Pipeline with Grep (Filtering)";
say "-" x 80;

my $grep_results = timethese(100, {
    'grep_50_percent' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->grep( sub ($x) { $x % 2 == 0 } )  # Keep evens (50%)
            ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )
            ->build;

        for (1..1000) {
            $publisher->submit($_);
        }
        $publisher->close;
    },

    'grep_10_percent' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->grep( sub ($x) { $x % 10 == 0 } )  # Keep 10%
            ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )
            ->build;

        for (1..1000) {
            $publisher->submit($_);
        }
        $publisher->close;
    },

    'grep_1_percent' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->grep( sub ($x) { $x % 100 == 0 } )  # Keep 1%
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
cmpthese($grep_results);

# Test 4: Complex pipeline
say "";
say "Test 4: Complex Pipeline (Map + Grep combinations)";
say "-" x 80;

my $complex_results = timethese(100, {
    'map_then_grep' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->map( sub ($x) { $x * 2 } )
            ->grep( sub ($x) { $x > 100 } )
            ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )
            ->build;

        for (1..1000) {
            $publisher->submit($_);
        }
        $publisher->close;
    },

    'grep_then_map' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->grep( sub ($x) { $x > 50 } )
            ->map( sub ($x) { $x * 2 } )
            ->to( Consumer->new( f => sub ($e) { push @collected, $e } ) )
            ->build;

        for (1..1000) {
            $publisher->submit($_);
        }
        $publisher->close;
    },

    'alternating' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->map( sub ($x) { $x * 2 } )
            ->grep( sub ($x) { $x > 50 } )
            ->map( sub ($x) { $x + 10 } )
            ->grep( sub ($x) { $x % 2 == 0 } )
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

# Test 5: Backpressure impact
say "";
say "Test 5: Backpressure (Request Size Impact)";
say "-" x 80;

my $backpressure_results = timethese(100, {
    'request_size_1' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->to(
                Consumer->new( f => sub ($e) { push @collected, $e } ),
                request_size => 1
            )
            ->build;

        for (1..100) {
            $publisher->submit($_);
        }
        $publisher->close;
    },

    'request_size_10' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->to(
                Consumer->new( f => sub ($e) { push @collected, $e } ),
                request_size => 10
            )
            ->build;

        for (1..100) {
            $publisher->submit($_);
        }
        $publisher->close;
    },

    'request_size_100' => sub {
        my @collected;
        my $publisher = Flow->from( Flow::Publisher->new )
            ->to(
                Consumer->new( f => sub ($e) { push @collected, $e } ),
                request_size => 100
            )
            ->build;

        for (1..100) {
            $publisher->submit($_);
        }
        $publisher->close;
    },
});

say "";
say "Comparison:";
cmpthese($backpressure_results);

say "";
say "=" x 80;
say "Benchmark 3 Complete";
say "=" x 80;

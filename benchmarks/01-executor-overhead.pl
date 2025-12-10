#!/usr/bin/env perl

use v5.42;
use lib 'lib';
use Benchmark qw(cmpthese timethese);
use grey::static qw[ concurrency::util ];

say "=" x 80;
say "Benchmark 1: Executor Overhead";
say "=" x 80;
say "";

# Test 1: Single executor vs multiple executors
say "Test 1: Callback execution - Single vs Multiple Executors";
say "-" x 80;

my $iterations = 10_000;

my $results = timethese($iterations, {
    'single_executor' => sub {
        my $exe = Executor->new;
        for (1..100) {
            $exe->next_tick(sub { my $x = $_ * 2 });
        }
        $exe->run;
    },

    'multiple_executors' => sub {
        my @exes = map { Executor->new } 1..10;

        # Chain them
        for my $i (0..8) {
            $exes[$i]->set_next($exes[$i+1]);
        }

        # Add 10 callbacks to each
        for my $exe (@exes) {
            for (1..10) {
                $exe->next_tick(sub { my $x = $_ * 2 });
            }
        }

        $exes[0]->run;
    },
});

say "";
say "Comparison:";
cmpthese($results);

# Test 2: Memory overhead
say "";
say "Test 2: Memory Usage";
say "-" x 80;

use Memory::Usage;
my $mu = Memory::Usage->new;

$mu->record('baseline');

# Create 1000 executors
my @executors;
for (1..1000) {
    push @executors, Executor->new;
}

$mu->record('1000 executors');

# Chain them
for my $i (0..998) {
    $executors[$i]->set_next($executors[$i+1]);
}

$mu->record('1000 chained executors');

$mu->dump;

# Test 3: Chaining depth impact
say "";
say "Test 3: Chain Depth Impact";
say "-" x 80;

sub test_chain_depth {
    my ($depth) = @_;

    my @exes = map { Executor->new } 1..$depth;
    for my $i (0..$depth-2) {
        $exes[$i]->set_next($exes[$i+1]);
    }

    # Add callback to first executor
    $exes[0]->next_tick(sub { 1 + 1 });

    $exes[0]->run;
}

my $depth_results = timethese(1000, {
    'depth_1'  => sub { test_chain_depth(1) },
    'depth_5'  => sub { test_chain_depth(5) },
    'depth_10' => sub { test_chain_depth(10) },
    'depth_20' => sub { test_chain_depth(20) },
});

say "";
say "Comparison:";
cmpthese($depth_results);

say "";
say "=" x 80;
say "Benchmark 1 Complete";
say "=" x 80;

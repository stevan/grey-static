#!/usr/bin/env perl

use v5.42;
use experimental qw[ class ];
use Benchmark qw(cmpthese timethese);

use grey::static qw[ functional ];

say "=" x 70;
say "Functional Composition Overhead Benchmarks";
say "=" x 70;
say "";

# Benchmark 1: Direct CODE ref vs Function->apply()
say "=== Benchmark 1: Function call overhead ===";

my $code_ref = sub ($x) { $x * 2 };
my $function = Function->new(f => $code_ref);

my $results = timethese(100_000, {
    'Direct_coderef' => sub {
        $code_ref->(42);
    },
    'Function_apply' => sub {
        $function->apply(42);
    },
});
cmpthese($results);
say "";

# Benchmark 2: Composition overhead
say "=== Benchmark 2: Composition vs manual chaining ===";

my $double = Function->new(f => sub ($x) { $x * 2 });
my $add10  = Function->new(f => sub ($x) { $x + 10 });
my $composed = $double->and_then($add10);

my $manual_chain = sub ($x) { ($x * 2) + 10 };

$results = timethese(50_000, {
    'Manual_chain' => sub {
        $manual_chain->(42);
    },
    'Composed_Functions' => sub {
        $composed->apply(42);
    },
    'Separate_calls' => sub {
        $add10->apply($double->apply(42));
    },
});
cmpthese($results);
say "";

# Benchmark 3: Predicate combinators
say "=== Benchmark 3: Predicate combinators vs manual logic ===";

my $is_positive = Predicate->new(f => sub ($x) { $x > 0 });
my $is_even     = Predicate->new(f => sub ($x) { $x % 2 == 0 });
my $combined    = $is_positive->and($is_even);

my $manual_pred = sub ($x) { $x > 0 && $x % 2 == 0 };

$results = timethese(50_000, {
    'Manual_predicate' => sub {
        $manual_pred->(42);
    },
    'Combined_Predicate' => sub {
        $combined->test(42);
    },
    'Separate_tests' => sub {
        $is_positive->test(42) && $is_even->test(42);
    },
});
cmpthese($results);
say "";

say "=" x 70;
say "Benchmark complete!";
say "=" x 70;

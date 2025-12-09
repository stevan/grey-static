#!/usr/bin/env perl

use v5.42;
use experimental qw[ class ];
use Benchmark qw(cmpthese timethese);

use grey::static qw[ functional stream ];

say "=" x 70;
say "Stream Performance Benchmarks";
say "=" x 70;
say "";

# Benchmark 1: Basic map/grep/collect vs plain Perl
say "=== Benchmark 1: map+grep+collect vs plain Perl (10k elements) ===";
my @data_10k = (1..10_000);

my $results = timethese(1000, {
    'Stream_API' => sub {
        my @result = Stream->of(@data_10k)
            ->map(sub ($x) { $x * 2 })
            ->grep(sub ($x) { $x > 5000 })
            ->collect(Stream::Collectors->ToList);
    },
    'Plain_Perl' => sub {
        my @result = grep { $_ > 5000 } map { $_ * 2 } @data_10k;
    },
});
cmpthese($results);
say "";

# Benchmark 2: Long chains vs short chains
say "=== Benchmark 2: Chain length impact (1k elements) ===";
my @data_1k = (1..1_000);

$results = timethese(5000, {
    'Short_Chain_2ops' => sub {
        my @result = Stream->of(@data_1k)
            ->map(sub ($x) { $x * 2 })
            ->collect(Stream::Collectors->ToList);
    },
    'Long_Chain_5ops' => sub {
        my @result = Stream->of(@data_1k)
            ->map(sub ($x) { $x * 2 })
            ->grep(sub ($x) { $x > 100 })
            ->map(sub ($x) { $x + 10 })
            ->grep(sub ($x) { $x % 3 == 0 })
            ->collect(Stream::Collectors->ToList);
    },
});
cmpthese($results);
say "";

# Benchmark 3: Lazy evaluation benefit (early termination)
say "=== Benchmark 3: Lazy evaluation with take() (100k elements) ===";
my @data_100k = (1..100_000);

$results = timethese(1000, {
    'Stream_take10' => sub {
        my @result = Stream->of(@data_100k)
            ->map(sub ($x) { $x * 2 })
            ->grep(sub ($x) { $x > 50 })
            ->take(10)
            ->collect(Stream::Collectors->ToList);
    },
    'Plain_Perl_full' => sub {
        my @temp = grep { $_ > 50 } map { $_ * 2 } @data_100k;
        my @result = @temp[0..9];
    },
});
cmpthese($results);
say "";

# Benchmark 4: Stream source overhead
say "=== Benchmark 4: Different stream sources (1k elements) ===";

$results = timethese(5000, {
    'FromArray' => sub {
        my @result = Stream->of(1..1_000)
            ->map(sub ($x) { $x * 2 })
            ->collect(Stream::Collectors->ToList);
    },
    'FromRange' => sub {
        my @result = Stream->range(1, 1_000)
            ->map(sub ($x) { $x * 2 })
            ->collect(Stream::Collectors->ToList);
    },
    'iterate+take' => sub {
        my @result = Stream->iterate(1, sub ($x) { $x + 1 })
            ->take(1_000)
            ->map(sub ($x) { $x * 2 })
            ->collect(Stream::Collectors->ToList);
    },
});
cmpthese($results);
say "";

# Benchmark 5: Simple collect performance
say "=== Benchmark 5: ToList collect vs array copy (10k elements) ===";

$results = timethese(2000, {
    'Stream_collect' => sub {
        my @result = Stream->of(@data_10k)
            ->collect(Stream::Collectors->ToList);
    },
    'Array_copy' => sub {
        my @result = @data_10k;
    },
});
cmpthese($results);
say "";

say "=" x 70;
say "Benchmark complete!";
say "=" x 70;

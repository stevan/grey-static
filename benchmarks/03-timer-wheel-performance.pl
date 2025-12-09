#!/usr/bin/env perl

use v5.42;
use experimental qw[ class ];
use Benchmark qw(timethese);
use Time::HiRes qw(time);

use grey::static qw[ time::wheel ];

say "=" x 70;
say "Timer::Wheel Performance Benchmarks";
say "=" x 70;
say "";

# Benchmark 1: add_timer performance at different scales
say "=== Benchmark 1: add_timer() performance ===";

for my $count (100, 1_000, 5_000, 10_000) {
    my $wheel = Timer::Wheel->new;

    my $start = time();
    for my $i (1..$count) {
        my $timer = Timer->new(
            expiry => ($i % 1000) + 1,  # Keep expiry times reasonable
            event => sub { }
        );
        $wheel->add_timer($timer);
    }
    my $elapsed = time() - $start;

    my $per_timer = ($elapsed / $count) * 1_000_000; # microseconds
    printf "  %6d timers: %.4fs total (%.2f us/timer)\n",
           $count, $elapsed, $per_timer;
}
say "";

# Benchmark 2: advance_by performance with varying timer counts
say "=== Benchmark 2: advance_by() performance ===";

for my $count (100, 1_000, 5_000) {
    my $wheel = Timer::Wheel->new;
    my $fired = 0;

    # Add timers spread across time
    for my $i (1..$count) {
        my $expiry = int(rand(100)) + 1;
        my $timer = Timer->new(
            expiry => $expiry,
            event => sub { $fired++ }
        );
        $wheel->add_timer($timer);
    }

    my $start = time();
    $wheel->advance_by(100);
    my $elapsed = time() - $start;

    printf "  %6d timers: %.4fs to advance 100 ticks (%d fired)\n",
           $count, $elapsed, $fired;
}
say "";

# Benchmark 3: Find performance degradation point
say "=== Benchmark 3: Performance scaling test ===";
say "Testing timer counts: 1k, 2k, 4k, 8k, 10k";
say "";

my @counts = (1_000, 2_000, 4_000, 8_000, 10_000);
my @add_times;
my @advance_times;

for my $count (@counts) {
    my $wheel = Timer::Wheel->new;

    # Time adding timers
    my $start = time();
    for my $i (1..$count) {
        my $timer = Timer->new(
            expiry => int(rand(1000)) + 1,
            event => sub { }
        );
        $wheel->add_timer($timer);
    }
    my $add_elapsed = time() - $start;
    push @add_times, $add_elapsed;

    # Time advancing
    $start = time();
    $wheel->advance_by(1000);
    my $advance_elapsed = time() - $start;
    push @advance_times, $advance_elapsed;
}

# Print results table
printf "\n%6s | %12s | %12s | %10s\n", "Count", "add_timer", "advance_by", "Total";
say "-" x 60;
for my $i (0..$#counts) {
    my $count = $counts[$i];
    my $add = $add_times[$i];
    my $advance = $advance_times[$i];
    my $total = $add + $advance;

    printf "%6d | %8.4fs | %8.4fs | %8.4fs\n",
           $count, $add, $advance, $total;
}
say "";

# Calculate if performance degrades non-linearly
say "=== Scaling Analysis ===";
for my $i (1..$#counts) {
    my $prev_count = $counts[$i-1];
    my $curr_count = $counts[$i];
    my $count_ratio = $curr_count / $prev_count;

    my $prev_time = $add_times[$i-1] + $advance_times[$i-1];
    my $curr_time = $add_times[$i] + $advance_times[$i];
    my $time_ratio = $curr_time / $prev_time;

    printf "%dk -> %dk: %.2fx timers, %.2fx time",
           $prev_count/1000, $curr_count/1000, $count_ratio, $time_ratio;

    if ($time_ratio > $count_ratio * 1.2) {
        say " [WARNING] Degrading";
    } elsif ($time_ratio < $count_ratio * 0.8) {
        say " [OK] Improving";
    } else {
        say " [OK] Linear";
    }
}
say "";

# Benchmark 4: timer_count() overhead
say "=== Benchmark 4: timer_count() overhead ===";
my $wheel = Timer::Wheel->new;
for my $i (1..1000) {
    $wheel->add_timer(Timer->new(expiry => $i, event => sub {}));
}

my $result = timethese(100_000, {
    'timer_count' => sub {
        my $count = $wheel->timer_count();
    },
});
say "";

say "=" x 70;
say "Benchmark complete!";
say "=" x 70;

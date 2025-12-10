#!/usr/bin/env perl
#
# Benchmark: Timer::Wheel find_next_timeout performance
#
# Tests the performance impact of the find_next_timeout fix which now
# scans all timers to find the minimum expiry instead of calculating
# from bucket indices.

use v5.42;
use Time::HiRes qw[ time ];
use grey::static qw[ time::wheel ];

sub benchmark {
    my ($name, $code) = @_;
    my $start = time;
    $code->();
    my $elapsed = time - $start;
    printf "%-50s: %.6f seconds\n", $name, $elapsed;
    return $elapsed;
}

say "=" x 70;
say "Timer::Wheel find_next_timeout Benchmark";
say "=" x 70;
say "";

# Benchmark 1: find_next_timeout with varying timer counts
say "--- Benchmark: find_next_timeout with N timers ---";
for my $n (10, 100, 1000, 5000, 10000) {
    my $wheel = Timer::Wheel->new;

    # Add N timers with random expiry times
    for my $i (1..$n) {
        $wheel->add_timer(Timer->new(
            id => "timer$i",
            expiry => int(rand(10000)),
            event => sub { }
        ));
    }

    # Benchmark find_next_timeout calls
    benchmark("find_next_timeout() with $n timers", sub {
        for (1..1000) {
            my $timeout = $wheel->find_next_timeout;
        }
    });
}

say "";
say "--- Benchmark: ScheduledExecutor with N timers ---";
use grey::static qw[ concurrency::util ];

for my $n (10, 100, 500, 1000) {
    my $count = 0;

    benchmark("ScheduledExecutor run() with $n timers", sub {
        my $executor = ScheduledExecutor->new;

        # Schedule N timers
        for my $i (1..$n) {
            $executor->schedule_delayed(sub { $count++ }, int(rand(1000)));
        }

        # Run the executor
        $executor->run;
    });

    say "  Timers fired: $count";
}

say "";
say "--- Benchmark: Timer cancellation overhead ---";
for my $n (100, 1000, 5000) {
    my $wheel = Timer::Wheel->new;
    my @timer_ids;

    # Add timers
    for my $i (1..$n) {
        $wheel->add_timer(Timer->new(
            id => "timer$i",
            expiry => int(rand(10000)),
            event => sub { }
        ));
        push @timer_ids, "timer$i";
    }

    # Benchmark cancellation
    benchmark("Cancel $n timers", sub {
        for my $id (@timer_ids) {
            $wheel->cancel_timer($id);
        }
    });
}

say "";
say "=" x 70;
say "Benchmark complete";
say "=" x 70;

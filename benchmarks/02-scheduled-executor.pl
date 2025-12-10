#!/usr/bin/env perl

use v5.42;
use lib 'lib';
use Benchmark qw(cmpthese timethese);
use grey::static qw[ concurrency::util ];

say "=" x 80;
say "Benchmark 2: ScheduledExecutor Performance";
say "=" x 80;
say "";

# Test 1: Timer insertion performance
say "Test 1: Timer Insertion (sorted queue)";
say "-" x 80;

my $results = timethese(1000, {
    'insert_10_timers' => sub {
        my $exe = ScheduledExecutor->new;
        for (1..10) {
            $exe->schedule_delayed(sub { 1 }, $_);
        }
    },

    'insert_100_timers' => sub {
        my $exe = ScheduledExecutor->new;
        for (1..100) {
            $exe->schedule_delayed(sub { 1 }, $_);
        }
    },

    'insert_1000_timers' => sub {
        my $exe = ScheduledExecutor->new;
        for (1..1000) {
            $exe->schedule_delayed(sub { 1 }, $_);
        }
    },
});

say "";
say "Comparison:";
cmpthese($results);

# Test 2: Insertion order impact (best case vs worst case)
say "";
say "Test 2: Insertion Order Impact";
say "-" x 80;

my $order_results = timethese(1000, {
    'ascending_order' => sub {
        my $exe = ScheduledExecutor->new;
        # Best case - append to end
        for (1..100) {
            $exe->schedule_delayed(sub { 1 }, $_);
        }
    },

    'descending_order' => sub {
        my $exe = ScheduledExecutor->new;
        # Worst case - insert at beginning
        for (reverse 1..100) {
            $exe->schedule_delayed(sub { 1 }, $_);
        }
    },

    'random_order' => sub {
        my $exe = ScheduledExecutor->new;
        my @order = (1..100);
        # Fisher-Yates shuffle
        for my $i (reverse 0..$#order) {
            my $j = int(rand($i + 1));
            @order[$i, $j] = @order[$j, $i];
        }
        for (@order) {
            $exe->schedule_delayed(sub { 1 }, $_);
        }
    },
});

say "";
say "Comparison:";
cmpthese($order_results);

# Test 3: Timer execution performance
say "";
say "Test 3: Timer Execution";
say "-" x 80;

my $exec_results = timethese(100, {
    'execute_10_timers' => sub {
        my $exe = ScheduledExecutor->new;
        my $count = 0;
        for (1..10) {
            $exe->schedule_delayed(sub { $count++ }, $_);
        }
        $exe->run;
    },

    'execute_100_timers' => sub {
        my $exe = ScheduledExecutor->new;
        my $count = 0;
        for (1..100) {
            $exe->schedule_delayed(sub { $count++ }, $_);
        }
        $exe->run;
    },

    'execute_1000_timers' => sub {
        my $exe = ScheduledExecutor->new;
        my $count = 0;
        for (1..1000) {
            $exe->schedule_delayed(sub { $count++ }, $_);
        }
        $exe->run;
    },
});

say "";
say "Comparison:";
cmpthese($exec_results);

# Test 4: Cancellation performance
say "";
say "Test 4: Timer Cancellation";
say "-" x 80;

my $cancel_results = timethese(1000, {
    'cancel_50_percent' => sub {
        my $exe = ScheduledExecutor->new;
        my @ids;
        for (1..100) {
            push @ids, $exe->schedule_delayed(sub { 1 }, $_);
        }
        # Cancel half
        for my $i (0..49) {
            $exe->cancel_scheduled($ids[$i]);
        }
        $exe->run;
    },

    'cancel_90_percent' => sub {
        my $exe = ScheduledExecutor->new;
        my @ids;
        for (1..100) {
            push @ids, $exe->schedule_delayed(sub { 1 }, $_);
        }
        # Cancel most
        for my $i (0..89) {
            $exe->cancel_scheduled($ids[$i]);
        }
        $exe->run;
    },
});

say "";
say "Comparison:";
cmpthese($cancel_results);

# Test 5: Dynamic timer addition (timers adding timers)
say "";
say "Test 5: Dynamic Timer Addition";
say "-" x 80;

my $dynamic_results = timethese(100, {
    'dynamic_nested' => sub {
        my $exe = ScheduledExecutor->new;
        my $count = 0;

        my $schedule_recursive;
        $schedule_recursive = sub {
            $count++;
            if ($count < 100) {
                $exe->schedule_delayed($schedule_recursive, 1);
            }
        };

        $exe->schedule_delayed($schedule_recursive, 1);
        $exe->run;
    },

    'dynamic_tree' => sub {
        my $exe = ScheduledExecutor->new;
        my $count = 0;

        my $schedule_tree;
        $schedule_tree = sub {
            my ($depth) = @_;
            $count++;
            if ($depth < 5) {
                # Each timer spawns 2 more
                $exe->schedule_delayed(sub { $schedule_tree->($depth + 1) }, 1);
                $exe->schedule_delayed(sub { $schedule_tree->($depth + 1) }, 1);
            }
        };

        $exe->schedule_delayed(sub { $schedule_tree->(0) }, 1);
        $exe->run;
    },
});

say "";
say "Comparison:";
cmpthese($dynamic_results);

say "";
say "=" x 80;
say "Benchmark 2 Complete";
say "=" x 80;

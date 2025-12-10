#!/usr/bin/env perl

use v5.42;
use lib 'lib';
use Benchmark qw(cmpthese timethese);
use grey::static qw[ concurrency::util ];

say "=" x 80;
say "Benchmark 5: Promise + ScheduledExecutor";
say "=" x 80;
say "";

# Test 1: Basic promise operations
say "Test 1: Basic Promise Operations";
say "-" x 80;

my $results = timethese(1000, {
    'resolve_immediate' => sub {
        my $executor = Executor->new;
        my $promise = Promise->new(executor => $executor);
        my $result;
        $promise->then(sub ($v) { $result = $v });
        $promise->resolve(42);
        $executor->run;
    },

    'reject_immediate' => sub {
        my $executor = Executor->new;
        my $promise = Promise->new(executor => $executor);
        my $error;
        $promise->then(undef, sub ($e) { $error = $e });
        $promise->reject("error");
        $executor->run;
    },

    'chain_then' => sub {
        my $executor = Executor->new;
        my $promise = Promise->new(executor => $executor);
        my $result;
        $promise
            ->then(sub ($v) { $v * 2 })
            ->then(sub ($v) { $v + 1 })
            ->then(sub ($v) { $result = $v });
        $promise->resolve(10);
        $executor->run;
    },
});

say "";
say "Comparison:";
cmpthese($results);

# Test 2: Promise->delay performance
say "";
say "Test 2: Promise->delay()";
say "-" x 80;

my $delay_results = timethese(500, {
    'delay_1_tick' => sub {
        my $executor = ScheduledExecutor->new;
        my $result;
        Promise->delay(42, 1, $executor)
            ->then(sub ($v) { $result = $v });
        $executor->run;
    },

    'delay_10_ticks' => sub {
        my $executor = ScheduledExecutor->new;
        my $result;
        Promise->delay(42, 10, $executor)
            ->then(sub ($v) { $result = $v });
        $executor->run;
    },

    'delay_100_ticks' => sub {
        my $executor = ScheduledExecutor->new;
        my $result;
        Promise->delay(42, 100, $executor)
            ->then(sub ($v) { $result = $v });
        $executor->run;
    },
});

say "";
say "Comparison:";
cmpthese($delay_results);

# Test 3: Promise->timeout performance
say "";
say "Test 3: Promise->timeout()";
say "-" x 80;

my $timeout_results = timethese(500, {
    'timeout_success' => sub {
        my $executor = ScheduledExecutor->new;
        my $promise = Promise->new(executor => $executor);
        my $result;

        $promise->timeout(100, $executor)
            ->then(sub ($v) { $result = $v });

        $executor->schedule_delayed(sub { $promise->resolve(42) }, 50);
        $executor->run;
    },

    'timeout_failure' => sub {
        my $executor = ScheduledExecutor->new;
        my $promise = Promise->new(executor => $executor);
        my $error;

        $promise->timeout(50, $executor)
            ->then(undef, sub ($e) { $error = $e });

        $executor->schedule_delayed(sub { $promise->resolve(42) }, 100);
        $executor->run;
    },

    'timeout_cancel' => sub {
        my $executor = ScheduledExecutor->new;
        my $promise = Promise->new(executor => $executor);
        my $result;

        $promise->timeout(100, $executor)
            ->then(sub ($v) { $result = $v });

        # Resolve immediately - timeout should be cancelled
        $promise->resolve(42);
        $executor->run;
    },
});

say "";
say "Comparison:";
cmpthese($timeout_results);

# Test 4: Chained delayed promises
say "";
say "Test 4: Chained Delayed Promises";
say "-" x 80;

my $chain_results = timethese(300, {
    'chain_2_delays' => sub {
        my $executor = ScheduledExecutor->new;
        my $result;

        Promise->delay(1, 10, $executor)
            ->then(sub ($v) {
                return Promise->delay($v + 1, 10, $executor);
            })
            ->then(sub ($v) { $result = $v });

        $executor->run;
    },

    'chain_5_delays' => sub {
        my $executor = ScheduledExecutor->new;
        my $result;

        Promise->delay(1, 5, $executor)
            ->then(sub ($v) { return Promise->delay($v + 1, 5, $executor) })
            ->then(sub ($v) { return Promise->delay($v + 1, 5, $executor) })
            ->then(sub ($v) { return Promise->delay($v + 1, 5, $executor) })
            ->then(sub ($v) { return Promise->delay($v + 1, 5, $executor) })
            ->then(sub ($v) { $result = $v });

        $executor->run;
    },

    'chain_10_delays' => sub {
        my $executor = ScheduledExecutor->new;
        my $result;

        my $p = Promise->delay(1, 2, $executor);
        for (1..9) {
            $p = $p->then(sub ($v) { return Promise->delay($v + 1, 2, $executor) });
        }
        $p->then(sub ($v) { $result = $v });

        $executor->run;
    },
});

say "";
say "Comparison:";
cmpthese($chain_results);

# Test 5: Multiple concurrent promises
say "";
say "Test 5: Multiple Concurrent Promises";
say "-" x 80;

my $concurrent_results = timethese(200, {
    'concurrent_10' => sub {
        my $executor = ScheduledExecutor->new;
        my @results;

        for (1..10) {
            Promise->delay($_, $_ * 5, $executor)
                ->then(sub ($v) { push @results, $v });
        }

        $executor->run;
    },

    'concurrent_50' => sub {
        my $executor = ScheduledExecutor->new;
        my @results;

        for (1..50) {
            Promise->delay($_, $_ * 2, $executor)
                ->then(sub ($v) { push @results, $v });
        }

        $executor->run;
    },

    'concurrent_100' => sub {
        my $executor = ScheduledExecutor->new;
        my @results;

        for (1..100) {
            Promise->delay($_, $_, $executor)
                ->then(sub ($v) { push @results, $v });
        }

        $executor->run;
    },
});

say "";
say "Comparison:";
cmpthese($concurrent_results);

# Test 6: Complex promise patterns
say "";
say "Test 6: Complex Promise Patterns";
say "-" x 80;

my $complex_results = timethese(200, {
    'delay_with_timeout' => sub {
        my $executor = ScheduledExecutor->new;
        my $result;

        Promise->delay(42, 10, $executor)
            ->timeout(50, $executor)
            ->then(sub ($v) { $result = $v });

        $executor->run;
    },

    'chain_with_timeouts' => sub {
        my $executor = ScheduledExecutor->new;
        my $result;

        Promise->delay(1, 10, $executor)
            ->timeout(50, $executor)
            ->then(sub ($v) {
                return Promise->delay($v + 1, 10, $executor)
                    ->timeout(50, $executor);
            })
            ->then(sub ($v) { $result = $v });

        $executor->run;
    },

    'mixed_operations' => sub {
        my $executor = ScheduledExecutor->new;
        my $result;

        Promise->delay(10, 5, $executor)
            ->then(sub ($v) { $v * 2 })
            ->timeout(50, $executor)
            ->then(sub ($v) { return Promise->delay($v + 5, 5, $executor) })
            ->then(sub ($v) { $v / 5 })
            ->then(sub ($v) { $result = $v });

        $executor->run;
    },
});

say "";
say "Comparison:";
cmpthese($complex_results);

say "";
say "=" x 80;
say "Benchmark 5 Complete";
say "=" x 80;

#!/usr/bin/env perl

use v5.42;
use lib 'lib';
use grey::static qw[ functional stream concurrency::reactive concurrency::util ];

say "=" x 80;
say "Concurrency Integration Examples";
say "Demonstrating how ScheduledExecutor, Flow, and Promises work together";
say "=" x 80;
say "";

## Example 1: Flow for event processing + Promise for async operations
say "Example 1: Event Processing with Async Operations";
say "-" x 80;
{
    my $executor = ScheduledExecutor->new;
    my @results;

    # Flow processes events
    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( sub ($event) {
            say "Processing event: $event";
            return $event * 2;
        })
        ->to( Consumer->new( f => sub ($value) {
            # Each processed event triggers an async operation
            Promise->delay($value, 5, $executor)
                ->then(sub ($v) {
                    say "  Async completed: $v";
                    push @results, $v;
                });
        }))
        ->build;

    # Submit events
    for (1..5) {
        $publisher->submit($_);
    }

    # Start Flow processing
    $publisher->start;

    # Run scheduled executor to complete promises
    $executor->run;

    say "Results: @results";
}

say "";

## Example 2: Stream for data transformation + Flow for event distribution
say "Example 2: Batch Processing + Event Distribution";
say "-" x 80;
{
    # Use Stream for efficient batch processing
    my @processed = Stream->of(1..10)
        ->map(sub ($x) { $x * 2 })
        ->grep(sub ($x) { $x > 10 })
        ->collect(Stream::Collectors->ToList);

    say "Stream processed: @processed";

    # Use Flow to distribute results as events
    my @subscribers;
    my $publisher = Flow->from( Flow::Publisher->new )
        ->map( sub ($x) { "Event: $x" } )
        ->to( Consumer->new( f => sub ($e) { push @subscribers, $e } ) )
        ->build;

    for (@processed) {
        $publisher->submit($_);
    }
    $publisher->close;

    say "Flow distributed: @subscribers";
}

say "";

## Example 3: Promise chains with timeouts
say "Example 3: Promise Chains with Timeouts";
say "-" x 80;
{
    my $executor = ScheduledExecutor->new;
    my $result;

    # Simulate multi-step async operation with timeout protection
    my $fetch_user = sub ($id) {
        say "Fetching user $id...";
        return Promise->delay("User$id", 10, $executor);
    };

    my $fetch_posts = sub ($user) {
        say "Fetching posts for $user...";
        return Promise->delay("Posts for $user", 10, $executor);
    };

    my $enrich_data = sub ($posts) {
        say "Enriching data: $posts...";
        return Promise->delay("Enriched: $posts", 10, $executor);
    };

    # Chain with timeout at each step
    $fetch_user->(123)
        ->timeout(50, $executor)
        ->then($fetch_posts)
        ->timeout(50, $executor)
        ->then($enrich_data)
        ->timeout(50, $executor)
        ->then(
            sub ($final) {
                say "Success: $final";
                $result = $final;
            },
            sub ($error) {
                say "Error: $error";
            }
        );

    $executor->run;
}

say "";

## Example 4: Stream time operations (different from Flow!)
say "Example 4: Stream Time Operations (Pull-Based)";
say "-" x 80;
{
    my $executor = ScheduledExecutor->new;

    # Stream uses time operations for pull-based processing
    my $stream = Stream->of(1..100)
        ->throttle(5, $executor)
        ->map(sub ($x) { $x * 2 })
        ->take(5);

    say "Stream with throttle:";
    while ($stream->source->has_next) {
        my $value = $stream->source->next;
        say "  Value: $value (time: ", $executor->current_time, ")";
        $executor->schedule_delayed(sub {}, 5);  # Advance time
        $executor->run;
    }
}

say "";

## Example 5: Concurrent promises with coordination
say "Example 5: Concurrent Promises with Coordination";
say "-" x 80;
{
    my $executor = ScheduledExecutor->new;
    my @results;
    my $completed = 0;
    my $total = 5;

    # Launch multiple concurrent async operations
    for my $i (1..$total) {
        my $delay = int(rand(20)) + 5;
        Promise->delay("Task$i", $delay, $executor)
            ->then(sub ($v) {
                say "Completed: $v (time: ", $executor->current_time, ")";
                push @results, $v;
                $completed++;
            });
    }

    $executor->run;

    say "All tasks completed: @results";
}

say "";

## Example 6: Flow with filtered events + Promise for expensive operations
say "Example 6: Event Filtering + Selective Async Processing";
say "-" x 80;
{
    my $executor = ScheduledExecutor->new;
    my @processed;

    # Flow filters events, only important ones trigger async work
    my $publisher = Flow->from( Flow::Publisher->new )
        ->grep( sub ($x) {
            # Only process "important" events
            return $x % 3 == 0;
        })
        ->map( sub ($x) {
            say "Important event: $x";
            return $x;
        })
        ->to( Consumer->new( f => sub ($important) {
            # Expensive async operation only for important events
            Promise->delay($important * 10, 10, $executor)
                ->timeout(50, $executor)
                ->then(sub ($result) {
                    say "  Processed: $result";
                    push @processed, $result;
                });
        }))
        ->build;

    # Submit many events
    for (1..20) {
        $publisher->submit($_);
    }
    $publisher->close;

    # Run scheduled executor to complete async work
    $executor->run;

    say "Processed important events: @processed";
}

say "";

## Example 7: Error handling across systems
say "Example 7: Error Handling and Recovery";
say "-" x 80;
{
    my $executor = ScheduledExecutor->new;
    my $success_count = 0;
    my $error_count = 0;

    # Simulate operations that might fail
    for my $i (1..10) {
        Promise->delay($i, 5, $executor)
            ->then(sub ($v) {
                # Simulate failure for some values
                if ($v % 4 == 0) {
                    die "Simulated failure for $v";
                }
                return $v * 2;
            })
            ->then(
                sub ($result) {
                    say "Success: $result";
                    $success_count++;
                },
                sub ($error) {
                    say "Handled error: $error";
                    $error_count++;
                }
            );
    }

    $executor->run;

    say "Success: $success_count, Errors: $error_count";
}

say "";

## Example 8: Real-world pattern - API with retry logic
say "Example 8: API Call with Retry and Timeout";
say "-" x 80;
{
    my $executor = ScheduledExecutor->new;

    my $api_call;
    $api_call = sub ($id, $attempt = 1) {
        say "API call for $id (attempt $attempt)...";

        # Simulate API call with timeout
        return Promise->delay("Data for $id", 15, $executor)
            ->timeout(30, $executor)
            ->then(
                sub ($data) { return $data },  # Success
                sub ($error) {  # Failure - add retry logic
                    if ($attempt < 3) {
                        say "  Retry after failure: $error";
                        # Exponential backoff
                        my $backoff = $attempt * 10;
                        return Promise->delay(undef, $backoff, $executor)
                            ->then(sub {
                                return $api_call->($id, $attempt + 1);
                            });
                    } else {
                        die "Failed after 3 attempts: $error";
                    }
                }
            );
    };

    $api_call->(456)
        ->then(
            sub ($data) {
                say "Final result: $data";
            },
            sub ($error) {
                say "Gave up: $error";
            }
        );

    $executor->run;
}

say "";
say "=" x 80;
say "Integration Examples Complete";
say "=" x 80;
say "";
say "KEY TAKEAWAYS:";
say "- Stream: Fast batch processing (12-19x faster than Flow)";
say "- Flow: Reactive event streams with backpressure";
say "- Promise: Async operations with timeout/delay";
say "- ScheduledExecutor: Time-based simulation for testing";
say "";
say "USE TOGETHER:";
say "- Flow processes events -> Promise for async operations";
say "- Stream transforms data -> Flow distributes results";
say "- Promise chains with timeouts for reliable async";
say "- Stream time operations for pull-based throttling";

#!/usr/bin/env perl
# Test Flow operations: map, filter, take, skip

use v5.42;
use Test::More;

use grey::static qw[ functional concurrency::reactive ];

## -------------------------------------------------------------------------
## Map Tests
## -------------------------------------------------------------------------

subtest 'map - basic transformation' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->map(sub ($x) { $x * 2 })
        ->to(sub ($x) { push @results, $x })
        ->build;

    # Submit values
    $publisher->submit($_) for 1 .. 5;
    $publisher->close;

    is_deeply(\@results, [2, 4, 6, 8, 10], 'map doubles each value');
};

subtest 'map - with Function object' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->map(Function->new(f => sub ($x) { $x + 10 }))
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 3;
    $publisher->close;

    is_deeply(\@results, [11, 12, 13], 'map with Function object');
};

subtest 'map - chaining multiple maps' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->map(sub ($x) { $x * 2 })
        ->map(sub ($x) { $x + 1 })
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 4;
    $publisher->close;

    is_deeply(\@results, [3, 5, 7, 9], 'chained maps work correctly');
};

## -------------------------------------------------------------------------
## Filter (Grep) Tests
## -------------------------------------------------------------------------

subtest 'filter - basic filtering' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->filter(sub ($x) { $x % 2 == 0 })
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 10;
    $publisher->close;

    is_deeply(\@results, [2, 4, 6, 8, 10], 'filter keeps even numbers');
};

subtest 'filter - with Predicate object' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->filter(Predicate->new(f => sub ($x) { $x > 5 }))
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 10;
    $publisher->close;

    is_deeply(\@results, [6, 7, 8, 9, 10], 'filter with Predicate object');
};

subtest 'grep - alias for filter' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->grep(sub ($x) { $x < 5 })
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 10;
    $publisher->close;

    is_deeply(\@results, [1, 2, 3, 4], 'grep works as alias for filter');
};

subtest 'filter - filters all out' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->filter(sub ($x) { $x > 100 })
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 10;
    $publisher->close;

    is_deeply(\@results, [], 'filter can filter out all elements');
};

## -------------------------------------------------------------------------
## Take Tests
## -------------------------------------------------------------------------

subtest 'take - basic limiting' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->take(3)
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 10;
    $publisher->close;

    is_deeply(\@results, [1, 2, 3], 'take limits to first 3 elements');
};

subtest 'take - take more than available' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->take(10)
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 5;
    $publisher->close;

    is_deeply(\@results, [1, 2, 3, 4, 5], 'take handles fewer elements than limit');
};

subtest 'take - take zero elements' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->take(0)
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 5;
    $publisher->close;

    is_deeply(\@results, [], 'take(0) emits no elements');
};

subtest 'take - take one element' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->take(1)
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 5;
    $publisher->close;

    is_deeply(\@results, [1], 'take(1) emits only first element');
};

## -------------------------------------------------------------------------
## Skip Tests
## -------------------------------------------------------------------------

subtest 'skip - basic skipping' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->skip(3)
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 6;
    $publisher->close;

    is_deeply(\@results, [4, 5, 6], 'skip skips first 3 elements');
};

subtest 'skip - skip more than available' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->skip(10)
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 5;
    $publisher->close;

    is_deeply(\@results, [], 'skip handles skipping more than available');
};

subtest 'skip - skip zero elements' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->skip(0)
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 5;
    $publisher->close;

    is_deeply(\@results, [1, 2, 3, 4, 5], 'skip(0) emits all elements');
};

subtest 'skip - skip all but one' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->skip(4)
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 5;
    $publisher->close;

    is_deeply(\@results, [5], 'skip can leave just one element');
};

## -------------------------------------------------------------------------
## Combined Operations Tests
## -------------------------------------------------------------------------

subtest 'combined - map and filter' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->map(sub ($x) { $x * 2 })
        ->filter(sub ($x) { $x > 5 })
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 5;
    $publisher->close;

    is_deeply(\@results, [6, 8, 10], 'map then filter works');
};

subtest 'combined - filter and map' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->filter(sub ($x) { $x % 2 == 0 })
        ->map(sub ($x) { $x * 10 })
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 5;
    $publisher->close;

    is_deeply(\@results, [20, 40], 'filter then map works');
};

subtest 'combined - map, filter, take' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->map(sub ($x) { $x * 2 })
        ->filter(sub ($x) { $x % 3 == 0 })
        ->take(2)
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 10;
    $publisher->close;

    is_deeply(\@results, [6, 12], 'map, filter, take chain');
};

subtest 'combined - skip and take' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->skip(2)
        ->take(3)
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 10;
    $publisher->close;

    is_deeply(\@results, [3, 4, 5], 'skip then take (slice operation)');
};

subtest 'combined - all four operations' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->skip(1)              # Skip first element
        ->map(sub ($x) { $x * 2 })    # Double remaining
        ->filter(sub ($x) { $x > 5 }) # Keep > 5
        ->take(3)              # Take first 3
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 10;
    $publisher->close;

    is_deeply(\@results, [6, 8, 10], 'skip, map, filter, take chain');
};

subtest 'combined - multiple maps and filters' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->map(sub ($x) { $x + 1 })
        ->filter(sub ($x) { $x % 2 == 0 })
        ->map(sub ($x) { $x / 2 })
        ->filter(sub ($x) { $x <= 3 })
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 10;
    $publisher->close;

    is_deeply(\@results, [1, 2, 3], 'multiple maps and filters');
};

## -------------------------------------------------------------------------
## Edge Cases
## -------------------------------------------------------------------------

subtest 'edge - empty stream' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->map(sub ($x) { $x * 2 })
        ->filter(sub ($x) { $x > 0 })
        ->take(5)
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->close;

    is_deeply(\@results, [], 'empty stream handled correctly');
};

subtest 'edge - single element' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->map(sub ($x) { $x * 3 })
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit(7);
    $publisher->close;

    is_deeply(\@results, [21], 'single element stream works');
};

subtest 'edge - take then skip (no output)' => sub {
    my $publisher = Flow::Publisher->new;
    my @results;

    Flow->from($publisher)
        ->take(3)
        ->skip(5)
        ->to(sub ($x) { push @results, $x })
        ->build;

    $publisher->submit($_) for 1 .. 10;
    $publisher->close;

    is_deeply(\@results, [], 'take then skip more than taken produces nothing');
};

done_testing;

#!/usr/bin/env perl
# Test Flow combining operations: merge, concat, zip

use v5.42;
use Test::More;

use grey::static qw[ functional concurrency::reactive ];

## -------------------------------------------------------------------------
## Merge Tests
## -------------------------------------------------------------------------

subtest 'merge - two publishers' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->merge($pub1, $pub2))
        ->to(sub ($x) { push @results, $x })
        ->build;

    # Submit to both publishers
    $pub1->submit(1);
    $pub2->submit(10);
    $pub1->submit(2);
    $pub2->submit(20);
    $pub1->submit(3);

    # Close both
    $pub1->close;
    $pub2->close;

    # Results are interleaved
    is_deeply([sort { $a <=> $b } @results], [1, 2, 3, 10, 20], 'merge combines both publishers');
};

subtest 'merge - three publishers' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my $pub3 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->merge($pub1, $pub2, $pub3))
        ->to(sub ($x) { push @results, $x })
        ->build;

    $pub1->submit(1);
    $pub2->submit(10);
    $pub3->submit(100);
    $pub1->submit(2);
    $pub2->submit(20);

    $pub1->close;
    $pub2->close;
    $pub3->close;

    is_deeply([sort { $a <=> $b } @results], [1, 2, 10, 20, 100], 'merge works with three publishers');
};

subtest 'merge - with operations' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->merge($pub1, $pub2))
        ->map(sub ($x) { $x * 2 })
        ->filter(sub ($x) { $x > 10 })
        ->to(sub ($x) { push @results, $x })
        ->build;

    $pub1->submit($_) for 1 .. 5;
    $pub2->submit($_) for 6 .. 10;

    $pub1->close;
    $pub2->close;

    is_deeply([sort { $a <=> $b } @results], [12, 14, 16, 18, 20], 'merge works with operations');
};

subtest 'merge - one empty publisher' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->merge($pub1, $pub2))
        ->to(sub ($x) { push @results, $x })
        ->build;

    $pub1->submit($_) for 1 .. 3;
    # pub2 is empty

    $pub1->close;
    $pub2->close;

    is_deeply(\@results, [1, 2, 3], 'merge handles empty publisher');
};

## -------------------------------------------------------------------------
## Concat Tests
## -------------------------------------------------------------------------

subtest 'concat - two publishers' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->concat($pub1, $pub2))
        ->to(sub ($x) { push @results, $x })
        ->build;

    # Submit to first publisher
    $pub1->submit(1);
    $pub1->submit(2);
    $pub1->submit(3);
    $pub1->close;  # First must complete before second starts

    # Now submit to second
    $pub2->submit(10);
    $pub2->submit(20);
    $pub2->close;

    is_deeply(\@results, [1, 2, 3, 10, 20], 'concat emits first then second');
};

subtest 'concat - three publishers' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my $pub3 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->concat($pub1, $pub2, $pub3))
        ->to(sub ($x) { push @results, $x })
        ->build;

    $pub1->submit(1);
    $pub1->submit(2);
    $pub1->close;

    $pub2->submit(10);
    $pub2->close;

    $pub3->submit(100);
    $pub3->submit(200);
    $pub3->close;

    is_deeply(\@results, [1, 2, 10, 100, 200], 'concat works with three publishers');
};

subtest 'concat - with operations' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->concat($pub1, $pub2))
        ->map(sub ($x) { $x * 2 })
        ->to(sub ($x) { push @results, $x })
        ->build;

    $pub1->submit($_) for 1 .. 3;
    $pub1->close;

    $pub2->submit($_) for 4 .. 6;
    $pub2->close;

    is_deeply(\@results, [2, 4, 6, 8, 10, 12], 'concat works with operations');
};

subtest 'concat - first empty' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->concat($pub1, $pub2))
        ->to(sub ($x) { push @results, $x })
        ->build;

    $pub1->close;  # Empty first publisher

    $pub2->submit($_) for 1 .. 3;
    $pub2->close;

    is_deeply(\@results, [1, 2, 3], 'concat handles empty first publisher');
};

subtest 'concat - second empty' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->concat($pub1, $pub2))
        ->to(sub ($x) { push @results, $x })
        ->build;

    $pub1->submit($_) for 1 .. 3;
    $pub1->close;

    $pub2->close;  # Empty second publisher

    is_deeply(\@results, [1, 2, 3], 'concat handles empty second publisher');
};

## -------------------------------------------------------------------------
## Zip Tests
## -------------------------------------------------------------------------

subtest 'zip - two publishers with BiFunction' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->zip($pub1, $pub2, sub ($a, $b) {
        return "$a-$b";
    }))
        ->to(sub ($x) { push @results, $x })
        ->build;

    $pub1->submit(1);
    $pub2->submit(10);
    $pub1->submit(2);
    $pub2->submit(20);
    $pub1->submit(3);
    $pub2->submit(30);

    $pub1->close;
    $pub2->close;

    is_deeply(\@results, ['1-10', '2-20', '3-30'], 'zip pairs up corresponding elements');
};

subtest 'zip - uneven lengths' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->zip($pub1, $pub2, sub ($a, $b) {
        return $a + $b;
    }))
        ->to(sub ($x) { push @results, $x })
        ->build;

    $pub1->submit(1);
    $pub2->submit(10);
    $pub1->submit(2);
    $pub2->submit(20);
    $pub1->submit(3);
    # pub2 only has 2 elements

    $pub1->close;
    $pub2->close;

    is_deeply(\@results, [11, 22], 'zip completes when shortest completes');
};

subtest 'zip - with BiFunction object' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->zip(
        $pub1, $pub2,
        BiFunction->new(f => sub ($a, $b) { $a * $b })
    ))
        ->to(sub ($x) { push @results, $x })
        ->build;

    $pub1->submit($_) for 1 .. 4;
    $pub2->submit($_) for 2 .. 5;

    $pub1->close;
    $pub2->close;

    is_deeply(\@results, [2, 6, 12, 20], 'zip works with BiFunction object');
};

subtest 'zip - with operations' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->zip($pub1, $pub2, sub ($a, $b) {
        return [$a, $b];
    }))
        ->map(sub ($pair) { $pair->[0] + $pair->[1] })
        ->filter(sub ($sum) { $sum > 15 })
        ->to(sub ($x) { push @results, $x })
        ->build;

    $pub1->submit($_) for 1 .. 5;
    $pub2->submit($_) for 10 .. 14;

    $pub1->close;
    $pub2->close;

    is_deeply(\@results, [13, 16, 19], 'zip works with operations');
};

## -------------------------------------------------------------------------
## Combined Tests
## -------------------------------------------------------------------------

subtest 'merge then take' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->merge($pub1, $pub2))
        ->take(5)
        ->to(sub ($x) { push @results, $x })
        ->build;

    $pub1->submit($_) for 1 .. 10;
    $pub2->submit($_) for 11 .. 20;

    $pub1->close;
    $pub2->close;

    is(scalar(@results), 5, 'merge with take limits output');
};

subtest 'concat then filter' => sub {
    my $pub1 = Flow::Publisher->new;
    my $pub2 = Flow::Publisher->new;
    my @results;

    Flow->from(Flow::Publishers->concat($pub1, $pub2))
        ->filter(sub ($x) { $x % 2 == 0 })
        ->to(sub ($x) { push @results, $x })
        ->build;

    $pub1->submit($_) for 1 .. 5;
    $pub1->close;

    $pub2->submit($_) for 6 .. 10;
    $pub2->close;

    is_deeply(\@results, [2, 4, 6, 8, 10], 'concat with filter');
};

done_testing;

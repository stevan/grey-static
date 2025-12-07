#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream ];

subtest '... empty stream' => sub {
    my @result = Stream->of()
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [], '... empty stream collects to empty array');
};

subtest '... empty stream with operations' => sub {
    my @result = Stream->of()
        ->map(sub ($x) { $x * 2 })
        ->grep(sub ($x) { true })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [], '... empty stream remains empty through operations');
};

subtest '... single element stream' => sub {
    my @result = Stream->of(42)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [42], '... single element stream');
};

subtest '... single element with operations' => sub {
    my @result = Stream->of(5)
        ->map(sub ($x) { $x * 2 })
        ->grep(sub ($x) { ($x % 2) == 0 })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [10], '... single element through operations');
};

subtest '... chaining multiple maps' => sub {
    my @result = Stream->of( 1 .. 5 )
        ->map(sub ($x) { $x + 1 })
        ->map(sub ($x) { $x * 2 })
        ->map(sub ($x) { $x - 1 })
        ->collect( Stream::Collectors->ToList );

    # (1+1)*2-1=3, (2+1)*2-1=5, (3+1)*2-1=7, (4+1)*2-1=9, (5+1)*2-1=11
    eq_or_diff(\@result, [3, 5, 7, 9, 11], '... chained maps work correctly');
};

subtest '... chaining multiple greps' => sub {
    my @result = Stream->of( 1 .. 20 )
        ->grep(sub ($x) { ($x % 2) == 0 })  # evens
        ->grep(sub ($x) { $x > 5 })          # > 5
        ->grep(sub ($x) { $x < 15 })         # < 15
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [6, 8, 10, 12, 14], '... chained greps filter correctly');
};

subtest '... grep that filters everything' => sub {
    my @result = Stream->of( 1 .. 10 )
        ->grep(sub ($x) { false })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [], '... grep with always-false produces empty stream');
};

subtest '... take more than available' => sub {
    my @result = Stream->of( 1 .. 5 )
        ->take(100)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1 .. 5], '... take more than available returns all');
};

subtest '... take one' => sub {
    my @result = Stream->of( 1 .. 10 )
        ->take(1)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1], '... take(1) produces single element');
};

subtest '... reduce on empty stream' => sub {
    my $result = Stream->of()
        ->reduce(0, sub ($acc, $x) { $acc + $x });

    is($result, 0, '... reduce on empty stream returns initial value');
};

subtest '... reduce on single element' => sub {
    my $result = Stream->of(42)
        ->reduce(0, sub ($acc, $x) { $acc + $x });

    is($result, 42, '... reduce on single element');
};

subtest '... foreach on empty stream' => sub {
    my $count = 0;

    Stream->of()
        ->foreach(sub ($x) { $count++ });

    is($count, 0, '... foreach on empty stream does nothing');
};

subtest '... complex operation chain' => sub {
    my @result = Stream->of( 1 .. 20 )
        ->grep(sub ($x) { ($x % 2) == 0 })
        ->map(sub ($x) { $x * 2 })
        ->grep(sub ($x) { $x > 10 })
        ->map(sub ($x) { $x / 2 })
        ->take(3)
        ->collect( Stream::Collectors->ToList );

    # Start: 1..20
    # After grep evens: 2,4,6,8,10,12,14,16,18,20
    # After map *2: 4,8,12,16,20,24,28,32,36,40
    # After grep >10: 12,16,20,24,28,32,36,40
    # After map /2: 6,8,10,12,14,16,18,20
    # After take 3: 6,8,10
    eq_or_diff(\@result, [6, 8, 10], '... complex chain works correctly');
};

done_testing;

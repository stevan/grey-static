#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream ];

subtest '... when with predicate' => sub {
    my @collected;

    my @result = Stream->of( 1 .. 10 )
        ->when(sub ($x) { ($x % 2) == 0 }, sub ($x) { push @collected => $x })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@collected, [2, 4, 6, 8, 10], '... collected only even numbers');
    eq_or_diff(\@result, [1 .. 10], '... stream still contains all elements');
};

subtest '... when with Predicate and Consumer' => sub {
    my @collected;

    my @result = Stream->of( 1 .. 10 )
        ->when(
            Predicate->new( f => sub ($x) { $x > 5 } ),
            Consumer->new( f => sub ($x) { push @collected => $x * 2 } )
        )
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@collected, [12, 14, 16, 18, 20], '... collected doubled values > 5');
    eq_or_diff(\@result, [1 .. 10], '... stream still contains all elements');
};

subtest '... when with multiple conditions' => sub {
    my @evens;
    my @odds;

    my @result = Stream->of( 1 .. 10 )
        ->when(sub ($x) { ($x % 2) == 0 }, sub ($x) { push @evens => $x })
        ->when(sub ($x) { ($x % 2) == 1 }, sub ($x) { push @odds => $x })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@evens, [2, 4, 6, 8, 10], '... collected evens');
    eq_or_diff(\@odds, [1, 3, 5, 7, 9], '... collected odds');
    eq_or_diff(\@result, [1 .. 10], '... stream still contains all elements');
};

subtest '... when that never matches' => sub {
    my @collected;

    my @result = Stream->of( 1 .. 5 )
        ->when(sub ($x) { $x > 100 }, sub ($x) { push @collected => $x })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@collected, [], '... collected nothing');
    eq_or_diff(\@result, [1 .. 5], '... stream still contains all elements');
};

done_testing;

#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream ];

subtest '... every 3rd element' => sub {
    # Note: every(N) triggers on elements at positions N, 2N, 3N (1-indexed: N+1, 2N+1, etc.)
    my @collected;

    my @result = Stream->of( 1 .. 10 )
        ->every(3, sub ($x) { push @collected => $x })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@collected, [4, 7, 10], '... collected every 3rd element (positions 4, 7, 10)');
    eq_or_diff(\@result, [1 .. 10], '... stream still contains all elements');
};

subtest '... every 2nd element' => sub {
    my @collected;

    my @result = Stream->of( 1 .. 10 )
        ->every(2, sub ($x) { push @collected => $x })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@collected, [3, 5, 7, 9], '... collected every 2nd element (positions 3, 5, 7, 9)');
    eq_or_diff(\@result, [1 .. 10], '... stream still contains all elements');
};

subtest '... every 1st element' => sub {
    my @collected;

    my @result = Stream->of( 1 .. 5 )
        ->every(1, sub ($x) { push @collected => $x })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@collected, [2, 3, 4, 5], '... collected every 1st element (all but first)');
    eq_or_diff(\@result, [1 .. 5], '... stream still contains all elements');
};

subtest '... every with Consumer' => sub {
    my @collected;

    my @result = Stream->of( 'a' .. 'j' )
        ->every(5, Consumer->new( f => sub ($x) { push @collected => uc($x) } ))
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@collected, ['F'], '... collected every 5th element (position 6)');
    eq_or_diff(\@result, ['a' .. 'j'], '... stream still contains all elements');
};

done_testing;

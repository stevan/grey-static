#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream ];

subtest '... take_until with predicate' => sub {
    # Note: take_until includes the element that satisfies the predicate
    my @result = Stream->of( 1 .. 20 )
        ->take_until(sub ($x) { $x > 5 })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1 .. 6], '... took until x > 5 (includes 6)');
};

subtest '... take_until with Predicate object' => sub {
    my @result = Stream->of( 1 .. 20 )
        ->take_until(Predicate->new( f => sub ($x) { $x > 10 } ))
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1 .. 11], '... took until x > 10 (includes 11)');
};

subtest '... take_until on infinite stream' => sub {
    my @result = Stream->generate(sub { state $x = 0; ++$x })
        ->take_until(sub ($x) { $x > 5 })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1 .. 6], '... took until x > 5 from infinite stream (includes 6)');
};

subtest '... take_until with no match (takes all)' => sub {
    my @result = Stream->of( 1 .. 5 )
        ->take_until(sub ($x) { $x > 100 })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1 .. 5], '... took all when predicate never matches');
};

subtest '... take_until immediately true' => sub {
    my @result = Stream->of( 1 .. 10 )
        ->take_until(sub ($x) { true })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1], '... took first element when predicate immediately true');
};

done_testing;

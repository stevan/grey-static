#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream ];

subtest '... range with custom step' => sub {
    my @result = Stream->range(0, 10, 2)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [0, 2, 4, 6, 8, 10], '... range with step 2');
};

subtest '... range with step 3' => sub {
    my @result = Stream->range(1, 10, 3)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1, 4, 7, 10], '... range with step 3');
};

subtest '... range single value' => sub {
    my @result = Stream->range(5, 5)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [5], '... range with start == end');
};

subtest '... range with large step' => sub {
    my @result = Stream->range(0, 20, 5)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [0, 5, 10, 15, 20], '... range with step 5');
};

subtest '... concat multiple streams' => sub {
    my @result = Stream->concat(
        Stream->of( 1 .. 3 ),
        Stream->of( 4 .. 6 ),
        Stream->of( 7 .. 9 )
    )->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1 .. 9], '... concatenated three streams');
};

subtest '... concat with empty streams' => sub {
    my @result = Stream->concat(
        Stream->of( 1 .. 3 ),
        Stream->of(),
        Stream->of( 4 .. 6 )
    )->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1 .. 6], '... concatenated with empty stream in middle');
};

subtest '... concat different types' => sub {
    my @result = Stream->concat(
        Stream->of( 1 .. 3 ),
        Stream->range(4, 6),
        Stream->generate(sub { state $x = 6; ++$x })->take(3)
    )->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1 .. 9], '... concatenated different source types');
};

subtest '... generate with stateful supplier' => sub {
    my @result = Stream->generate(sub {
            state $x = 0;
            ++$x;
        })
        ->take(5)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1 .. 5], '... generate with counter');
};

subtest '... generate with Supplier object' => sub {
    my @result = Stream->generate(
            Supplier->new( f => sub { state $x = 10; --$x } )
        )
        ->take(5)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [9, 8, 7, 6, 5], '... generate with Supplier object');
};

subtest '... iterate with Function object (infinite)' => sub {
    # Note: iterate does not include the seed value
    my @result = Stream->iterate(
            1,
            Function->new( f => sub ($x) { $x * 2 } )
        )
        ->take(5)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [2, 4, 8, 16, 32], '... iterate with Function (powers of 2, no seed)');
};

subtest '... iterate with Predicate and Function (finite)' => sub {
    # Note: iterate does not include the seed value
    my @result = Stream->iterate(
            1,
            Predicate->new( f => sub ($x) { $x < 100 } ),
            Function->new( f => sub ($x) { $x * 2 } )
        )
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [2, 4, 8, 16, 32, 64, 128], '... iterate finite with objects (no seed)');
};

subtest '... of with array ref' => sub {
    my $array = [1 .. 5];
    my @result = Stream->of($array)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1 .. 5], '... of with array ref');
};

subtest '... of with mixed types' => sub {
    my @result = Stream->of( 1, 'foo', 2.5, undef, 'bar' )
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(
        \@result,
        [1, 'foo', 2.5, undef, 'bar'],
        '... of with mixed types'
    );
};

done_testing;

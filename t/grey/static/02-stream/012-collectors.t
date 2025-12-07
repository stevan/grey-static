#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream ];

subtest '... ToList collector' => sub {
    my @result = Stream->of( 1 .. 5 )
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, [1 .. 5], '... collected to list');
};

subtest '... JoinWith collector (no separator)' => sub {
    my $result = Stream->of( 'a', 'b', 'c', 'd', 'e' )
        ->collect( Stream::Collectors->JoinWith('') );

    is($result, 'abcde', '... joined with no separator');
};

subtest '... JoinWith collector (comma separator)' => sub {
    my $result = Stream->of( 1 .. 5 )
        ->collect( Stream::Collectors->JoinWith(', ') );

    is($result, '1, 2, 3, 4, 5', '... joined with comma separator');
};

subtest '... JoinWith collector (pipe separator)' => sub {
    my $result = Stream->of( 'foo', 'bar', 'baz' )
        ->collect( Stream::Collectors->JoinWith(' | ') );

    is($result, 'foo | bar | baz', '... joined with pipe separator');
};

subtest '... JoinWith with map' => sub {
    my $result = Stream->of( 1 .. 5 )
        ->map(sub ($x) { $x * $x })
        ->collect( Stream::Collectors->JoinWith('-') );

    is($result, '1-4-9-16-25', '... joined mapped values');
};

subtest '... JoinWith empty stream' => sub {
    my $result = Stream->of()
        ->collect( Stream::Collectors->JoinWith(', ') );

    is($result, '', '... empty stream produces empty string');
};

done_testing;

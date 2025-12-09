#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream ];

subtest '... testing recurse with tree structure' => sub {
    # Test recursing through a tree-like structure
    # Each node can contain a value and children

    class TreeNode {
        field $value    :param :reader;
        field $children :param :reader = [];
    }

    # Build a tree:
    #       1
    #      / \
    #     2   3
    #    /     \
    #   4       5

    my $tree = TreeNode->new(
        value => 1,
        children => [
            TreeNode->new(
                value => 2,
                children => [
                    TreeNode->new(value => 4)
                ]
            ),
            TreeNode->new(
                value => 3,
                children => [
                    TreeNode->new(value => 5)
                ]
            ),
        ]
    );

    # Flatten the tree by recursing through nodes that have children
    # Note: recurse expects a function that returns a SOURCE, not a Stream
    my @values = Stream->of($tree)
        ->recurse(
            sub ($node) { scalar $node->children->@* > 0 },  # can_recurse: has children?
            sub ($node) {                                     # recurse: return a SOURCE
                Stream::Source::FromArray->new(
                    array => $node->children
                )
            }
        )
        ->map(sub ($node) { $node->value })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff \@values, [1, 2, 4, 3, 5], '... got all nodes in depth-first order';
};

subtest '... testing recurse with nested arrays' => sub {
    # Test traversing nested arrays
    # Note: recurse returns ALL items (arrays AND their elements), not just leaves
    my $nested = [
        1,
        [2, 3],
        [4, [5, 6]],
        7
    ];

    my @all_items = Stream->of(@$nested)
        ->recurse(
            sub ($item) { ref($item) eq 'ARRAY' },           # can_recurse: is array?
            sub ($item) {                                    # recurse: return a SOURCE
                Stream::Source::FromArray->new(
                    array => $item
                )
            }
        )
        ->collect( Stream::Collectors->ToList );

    # Returns: 1, [2,3], 2, 3, [4,[5,6]], 4, [5,6], 5, 6, 7
    # Filter to just scalars for cleaner test
    my @scalars = grep { !ref($_) } @all_items;
    eq_or_diff \@scalars, [1, 2, 3, 4, 5, 6, 7], '... got all scalar values from nested structure';

    # Verify arrays are also returned
    my @arrays = grep { ref($_) eq 'ARRAY' } @all_items;
    ok(scalar @arrays > 0, '... arrays themselves are also returned');
};

subtest '... testing recurse with no recursion needed' => sub {
    # Test when can_recurse always returns false
    my @values = Stream->of(1, 2, 3)
        ->recurse(
            sub ($x) { 0 },                 # never recurse
            sub ($x) {                      # shouldn't be called
                Stream::Source::FromArray->new( array => [] )
            }
        )
        ->collect( Stream::Collectors->ToList );

    eq_or_diff \@values, [1, 2, 3], '... no recursion occurred';
};

subtest '... testing recurse with empty stream' => sub {
    my @values = Stream->of()
        ->recurse(
            sub ($x) { 1 },
            sub ($x) {
                Stream::Source::FromArray->new( array => [] )
            }
        )
        ->collect( Stream::Collectors->ToList );

    eq_or_diff \@values, [], '... empty stream stays empty';
};

subtest '... testing recurse with conditional recursion' => sub {
    # Only recurse on even numbers, generating children n-1 and n-2
    # This generates: 5 (odd, no recurse) -> returns just [5]
    # Let's start with 4 instead to see recursion happen
    my @values = Stream->of(4)
        ->recurse(
            sub ($n) { $n % 2 == 0 && $n > 0 },              # only recurse on even numbers
            sub ($n) {                                       # generate children
                Stream::Source::FromArray->new(
                    array => [ $n - 1, $n - 2 ]
                )
            }
        )
        ->take(10)  # limit to prevent infinite recursion
        ->collect( Stream::Collectors->ToList );

    # Returns: 4 (even, recurses), 3, 2 (even, recurses), 1, 0
    eq_or_diff \@values, [4, 3, 2, 1, 0], '... conditional recursion worked';
};

done_testing;

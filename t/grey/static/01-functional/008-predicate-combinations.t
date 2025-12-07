use v5.40;
use Test::More;
use Test::Differences;

use grey::static qw[ functional ];

# Test complex predicate combinations with and, or, not
my @expected = (
    false,  # 3: not (>5 and <20)
    true,   # 10: >5 and <20
    false,  # 25: not (>5 and <20)
    true,   # 3: (>5 and <20) or ==3
    true,   # 10: (>5 and <20) or ==3
    false,  # 25: not ((>5 and <20) or ==3)
    true,   # 3: not (>5 and <20)
    true,   # 7: NOT(>10 OR <5) = between 5 and 10
);

my @got;

# Create base predicates
my $greater_than_5 = Predicate->new( f => sub ($x) { $x > 5 } );
my $less_than_20   = Predicate->new( f => sub ($x) { $x < 20 } );
my $equals_3       = Predicate->new( f => sub ($x) { $x == 3 } );

# Test: (x > 5) AND (x < 20)
my $between_5_and_20 = $greater_than_5->and($less_than_20);
isa_ok($between_5_and_20, 'Predicate');

push @got => $between_5_and_20->test(3);   # false
push @got => $between_5_and_20->test(10);  # true
push @got => $between_5_and_20->test(25);  # false

# Test: ((x > 5) AND (x < 20)) OR (x == 3)
my $between_or_3 = $between_5_and_20->or($equals_3);
isa_ok($between_or_3, 'Predicate');

push @got => $between_or_3->test(3);   # true (matches ==3)
push @got => $between_or_3->test(10);  # true (matches between)
push @got => $between_or_3->test(25);  # false

# Test: NOT ((x > 5) AND (x < 20))
my $not_between = $between_5_and_20->not;
isa_ok($not_between, 'Predicate');

push @got => $not_between->test(3);   # true (3 is NOT between 5 and 20)

# Test chaining not operations
my $greater_than_10 = Predicate->new( f => sub ($x) { $x > 10 } );
my $less_than_5     = Predicate->new( f => sub ($x) { $x < 5 } );
my $outside_range   = $greater_than_10->or($less_than_5);
my $inside_range    = $outside_range->not;  # NOT (x > 10 OR x < 5) = (x >= 5 AND x <= 10)
isa_ok($inside_range, 'Predicate');

push @got => $inside_range->test(7);   # true (7 is between 5 and 10 inclusive)

eq_or_diff(\@got, \@expected, '... got the expected output');

done_testing;

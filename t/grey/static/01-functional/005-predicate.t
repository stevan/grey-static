use v5.40;
use Test::More;
use Test::Differences;

use grey::static qw[ functional ];

my @expected = (true, false, false, true, true, false, false, true, true, false);

my @got;

my $p1 = Predicate->new( f => sub ($x) { $x > 5 } );
isa_ok($p1, 'Predicate');

push @got => $p1->test(10);
push @got => $p1->test(3);

my $p2 = $p1->not;
isa_ok($p2, 'Predicate');

push @got => $p2->test(10);
push @got => $p2->test(3);

# Test and() method
my $p3 = Predicate->new( f => sub ($x) { $x < 20 } );
my $p4 = $p1->and($p3);  # x > 5 AND x < 20
isa_ok($p4, 'Predicate');

push @got => $p4->test(10);  # true (10 > 5 AND 10 < 20)
push @got => $p4->test(3);   # false (3 not > 5)
push @got => $p4->test(25);  # false (25 not < 20)

# Test or() method
my $p5 = Predicate->new( f => sub ($x) { $x == 3 } );
my $p6 = $p1->or($p5);  # x > 5 OR x == 3
isa_ok($p6, 'Predicate');

push @got => $p6->test(10);  # true (10 > 5)
push @got => $p6->test(3);   # true (3 == 3)
push @got => $p6->test(4);   # false (4 not > 5 and 4 != 3)

eq_or_diff(\@got, \@expected, '... got the expected output');

done_testing;

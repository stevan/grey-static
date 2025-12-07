use v5.40;
use Test::More;
use Test::Differences;

use grey::static qw[ functional ];

my @expected = (-1, 0, 1, 1, 0, -1, -1, 0, 1, -1, 0, 1, 1, 0, -1);

my @got;

my $c1 = Comparator->new( f => sub ($l, $r) { $l <=> $r } );
isa_ok($c1, 'Comparator');

push @got => $c1->compare(2, 3);
push @got => $c1->compare(2, 2);
push @got => $c1->compare(2, 1);

my $c2 = $c1->reversed;
isa_ok($c2, 'Comparator');

push @got => $c2->compare(2, 3);
push @got => $c2->compare(2, 2);
push @got => $c2->compare(2, 1);

# Test numeric() class method
my $c3 = Comparator->numeric;
isa_ok($c3, 'Comparator');

push @got => $c3->compare(2, 3);
push @got => $c3->compare(2, 2);
push @got => $c3->compare(2, 1);

# Test alpha() class method
my $c4 = Comparator->alpha;
isa_ok($c4, 'Comparator');

push @got => $c4->compare('a', 'b');
push @got => $c4->compare('a', 'a');
push @got => $c4->compare('b', 'a');

# Test reversed with alpha
my $c5 = $c4->reversed;
isa_ok($c5, 'Comparator');

push @got => $c5->compare('a', 'b');
push @got => $c5->compare('a', 'a');
push @got => $c5->compare('b', 'a');

eq_or_diff(\@got, \@expected, '... got the expected output');

done_testing;

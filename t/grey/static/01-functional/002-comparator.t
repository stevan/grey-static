use v5.40;
use Test::More;
use Test::Differences;

use grey::static qw[ functional ];

my @expected = (-1, 0, 1, 1, 0, -1);

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

eq_or_diff(\@got, \@expected, '... got the expected output');

done_testing;

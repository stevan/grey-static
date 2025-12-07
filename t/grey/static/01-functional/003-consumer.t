use v5.40;
use Test::More;
use Test::Differences;

use grey::static qw[ functional ];

my @expected = (10, 10);

my @got;
my sub capture ($x) { push @got => $x }

my $c1 = Consumer->new( f => \&capture );
my $c2 = $c1->and_then(Consumer->new( f => \&capture ));

$c2->accept(10);

eq_or_diff(\@got, \@expected, '... got the expected output');

done_testing;

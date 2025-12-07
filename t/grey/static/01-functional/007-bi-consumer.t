use v5.40;
use Test::More;
use Test::Differences;

use grey::static qw[ functional ];

my @expected = (10, 20, 10, 20, 10, 20);

my @got;
my sub capture ($x, $y) { push @got => $x, $y }

my $c1 = BiConsumer->new( f => \&capture );
isa_ok($c1, 'BiConsumer');

$c1->accept(10, 20);

my $c2 = $c1->and_then(BiConsumer->new( f => \&capture ));
isa_ok($c2, 'BiConsumer');

$c2->accept(10, 20);

eq_or_diff(\@got, \@expected, '... got the expected output');

done_testing;

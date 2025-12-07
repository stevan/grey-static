use v5.40;
use Test::More;
use Test::Differences;

use grey::static qw[ functional ];

my @expected = (true, false, false, true);

my @got;

my $p1 = Predicate->new( f => sub ($x) { $x > 5 } );
isa_ok($p1, 'Predicate');

push @got => $p1->test(10);
push @got => $p1->test(3);

my $p2 = $p1->not;
isa_ok($p2, 'Predicate');

push @got => $p2->test(10);
push @got => $p2->test(3);

eq_or_diff(\@got, \@expected, '... got the expected output');

done_testing;

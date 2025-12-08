use v5.42;
use Test::More;
use Test::Differences;

use grey::static qw[ functional ];

my @expected = qw[ 510 1012 510 1020 THEN(100200) ];

my @got;

my $b1 = BiFunction->new( f => sub ($t, $u) { "$t$u" });
isa_ok($b1, 'BiFunction');

push @got => $b1->apply(5, 10);

my $b2 = $b1->curry(10);
isa_ok($b2, 'Function');

push @got => $b2->apply(12);

my $b3 = $b1->rcurry(10);
isa_ok($b3, 'Function');

push @got => $b3->apply(5);

my $b4 = $b2->curry(20);
isa_ok($b4, 'Supplier');

push @got => $b4->get;

my $b5 = $b1->and_then(Function->new( f => sub ($x) { "THEN($x)" }));
isa_ok($b5, 'BiFunction');

push @got => $b5->apply(100, 200);

eq_or_diff(\@got, \@expected, '... got the expected output');

done_testing;

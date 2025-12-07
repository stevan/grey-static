use v5.40;
use Test::More;
use Test::Differences;

use grey::static qw[ functional ];

my @expected = (10, 11, 12);

my @got;
my $s1 = Supplier->new( f => sub { state $i = 10; $i++ } );
isa_ok($s1, 'Supplier');

push @got => $s1->get;
push @got => $s1->get;
push @got => $s1->get;

eq_or_diff(\@got, \@expected, '... got the expected output');

done_testing;

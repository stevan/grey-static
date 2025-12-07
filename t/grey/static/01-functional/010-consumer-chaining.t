use v5.40;
use Test::More;
use Test::Differences;

use grey::static qw[ functional ];

# Test chaining multiple consumers and bi-consumers
my @expected = (
    'log:10', 'validate:10', 'process:10',
    'log:5,15', 'sum:5,15', 'product:5,15',
);

my @got;

# Test Consumer chaining
my sub log_val ($x) { push @got => "log:$x" }
my sub validate_val ($x) { push @got => "validate:$x" }
my sub process_val ($x) { push @got => "process:$x" }

my $c1 = Consumer->new( f => \&log_val );
my $c2 = Consumer->new( f => \&validate_val );
my $c3 = Consumer->new( f => \&process_val );

my $pipeline = $c1->and_then($c2)->and_then($c3);
isa_ok($pipeline, 'Consumer');

$pipeline->accept(10);  # Should call all three in order

# Test BiConsumer chaining
my sub log_pair ($x, $y) { push @got => "log:$x,$y" }
my sub sum_pair ($x, $y) { push @got => "sum:$x,$y" }
my sub product_pair ($x, $y) { push @got => "product:$x,$y" }

my $bc1 = BiConsumer->new( f => \&log_pair );
my $bc2 = BiConsumer->new( f => \&sum_pair );
my $bc3 = BiConsumer->new( f => \&product_pair );

my $bi_pipeline = $bc1->and_then($bc2)->and_then($bc3);
isa_ok($bi_pipeline, 'BiConsumer');

$bi_pipeline->accept(5, 15);  # Should call all three in order

eq_or_diff(\@got, \@expected, '... got the expected output');

done_testing;

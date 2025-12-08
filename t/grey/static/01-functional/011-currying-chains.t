use v5.42;
use Test::More;
use Test::Differences;

use grey::static qw[ functional ];

# Test currying chains: BiFunction -> Function -> Supplier
my @expected = ('AB', 'A1', 'A2', 'XY', 'XY', 'XY');

my @got;

# Create a BiFunction that concatenates strings
my $concat = BiFunction->new( f => sub ($a, $b) { "$a$b" } );
isa_ok($concat, 'BiFunction');

# Apply directly
push @got => $concat->apply('A', 'B');  # 'AB'

# Curry once to get a Function
my $concat_A = $concat->curry('A');
isa_ok($concat_A, 'Function');

push @got => $concat_A->apply('1');  # 'A1'
push @got => $concat_A->apply('2');  # 'A2'

# Right curry to get a Function
my $concat_Y = $concat->rcurry('Y');
isa_ok($concat_Y, 'Function');

push @got => $concat_Y->apply('X');  # 'XY'

# Curry twice to get a Supplier
my $concat_XY = $concat->curry('X')->curry('Y');
isa_ok($concat_XY, 'Supplier');

push @got => $concat_XY->get;  # 'XY'
push @got => $concat_XY->get;  # 'XY' (can call multiple times)

eq_or_diff(\@got, \@expected, '... got the expected output');

done_testing;

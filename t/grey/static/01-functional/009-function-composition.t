use v5.42;
use Test::More;
use Test::Differences;

use grey::static qw[ functional ];

my @expected = (15, 30, 30, 40, 30, 30);

my @got;

# Create base functions
my $add_10 = Function->new( f => sub ($x) { $x + 10 } );
my $mul_2  = Function->new( f => sub ($x) { $x * 2 } );
my $div_2  = Function->new( f => sub ($x) { $x / 2 } );

# Test basic function application
push @got => $add_10->apply(5);  # 15

# Test compose: f->compose(g) means f(g(x))
# So mul_2->compose(add_10) means mul_2(add_10(x))
my $double_then_add = $add_10->compose($mul_2);  # add_10(mul_2(x))
isa_ok($double_then_add, 'Function');

push @got => $double_then_add->apply(10);  # add_10(mul_2(10)) = add_10(20) = 30

# Test and_then: f->and_then(g) means g(f(x))
# So add_10->and_then(mul_2) means mul_2(add_10(x))
my $add_then_double = $add_10->and_then($mul_2);  # mul_2(add_10(x))
isa_ok($add_then_double, 'Function');

push @got => $add_then_double->apply(5);  # mul_2(add_10(5)) = mul_2(15) = 30

# Test chaining multiple operations
# (x / 2) then (+ 10) then (* 2)
my $complex = $div_2->and_then($add_10)->and_then($mul_2);
isa_ok($complex, 'Function');

push @got => $complex->apply(20);  # div_2(20)=10, add_10(10)=20, mul_2(20)=40

# Test compose vs and_then difference
# compose: f->compose(g) = f(g(x))
# and_then: f->and_then(g) = g(f(x))
my $compose_chain = $mul_2->compose($add_10);     # mul_2(add_10(x))
my $and_then_chain = $add_10->and_then($mul_2);   # mul_2(add_10(x))

push @got => $compose_chain->apply(5);   # mul_2(add_10(5)) = mul_2(15) = 30
push @got => $and_then_chain->apply(5);  # mul_2(add_10(5)) = mul_2(15) = 30

# They should be the same in this case!

done_testing;

use v5.40;
use Test::More;
use Test::Differences;

use grey::static qw[ functional ];

# Test common functional patterns: identity, constant, always true/false
my @expected = (
    42,          # identity(42)
    'hello',     # identity('hello')
    100,         # constant(100) called with any arg
    100,         # constant(100) called with different arg
    true,        # always_true(anything)
    true,        # always_true(anything)
    false,       # always_false(anything)
    false,       # always_false(anything)
    5,           # identity composed with add should work
);

my @got;

# Identity function: f(x) = x
my $identity = Function->new( f => sub ($x) { $x } );
isa_ok($identity, 'Function');

push @got => $identity->apply(42);
push @got => $identity->apply('hello');

# Constant function: f(x) = c (ignores input)
my $constant_100 = Function->new( f => sub ($x) { 100 } );
isa_ok($constant_100, 'Function');

push @got => $constant_100->apply(1);
push @got => $constant_100->apply(999);

# Always true predicate
my $always_true = Predicate->new( f => sub ($x) { true } );
isa_ok($always_true, 'Predicate');

push @got => $always_true->test(0);
push @got => $always_true->test(undef);

# Always false predicate
my $always_false = Predicate->new( f => sub ($x) { false } );
isa_ok($always_false, 'Predicate');

push @got => $always_false->test(1);
push @got => $always_false->test('anything');

# Identity should compose properly
my $add_5 = Function->new( f => sub ($x) { $x + 5 } );
my $identity_then_add = $identity->and_then($add_5);
isa_ok($identity_then_add, 'Function');

push @got => $identity_then_add->apply(0);  # identity(0) = 0, then add 5 = 5

eq_or_diff(\@got, \@expected, '... got the expected output');

done_testing;

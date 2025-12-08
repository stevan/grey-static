use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::functional;

our $VERSION = '0.01';

use File::Basename ();
use lib File::Basename::dirname(__FILE__) . '/functional';

load_module('Supplier');
load_module('Function');
load_module('BiFunction');
load_module('Predicate');
load_module('Consumer');
load_module('BiConsumer');
load_module('Comparator');

sub import { }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

grey::static::functional - Functional programming primitives

=head1 SYNOPSIS

    use grey::static qw[ functional ];

    # Function - wraps a unary function
    my $double = Function->new(f => sub ($x) { $x * 2 });
    say $double->apply(5);  # 10

    # Predicate - wraps a boolean test
    my $is_even = Predicate->new(f => sub ($x) { $x % 2 == 0 });
    say $is_even->test(4);  # 1 (true)

    # Consumer - wraps a side-effect operation
    my $printer = Consumer->new(f => sub ($x) { say "Value: $x" });
    $printer->accept(42);   # prints "Value: 42"

    # Supplier - wraps a value provider
    my $counter = do {
        my $i = 0;
        Supplier->new(f => sub { $i++ });
    };
    say $counter->get;  # 0
    say $counter->get;  # 1

=head1 DESCRIPTION

The C<functional> feature provides a set of functional programming primitives.
Each class wraps a code reference and provides methods for composition and
transformation.

=head1 CLASSES

=head2 Function

Represents a unary function that takes one argument and returns a value.

=head3 Constructor

    my $fn = Function->new(f => sub ($t) { ... });

=head3 Methods

=over 4

=item C<apply($t)>

Applies the function to the given argument and returns the result.

    my $result = $fn->apply($value);

=item C<curry($t)>

Partially applies the function with the given argument, returning a C<Supplier>
that will apply the function when called.

    my $supplier = $fn->curry(10);
    my $result = $supplier->get;  # equivalent to $fn->apply(10)

=item C<compose($g)>

Returns a new C<Function> that first applies C<$g>, then applies this function
to the result. Implements mathematical function composition: C<f ∘ g>.

    my $add_one = Function->new(f => sub ($x) { $x + 1 });
    my $double  = Function->new(f => sub ($x) { $x * 2 });
    my $composed = $add_one->compose($double);
    say $composed->apply(5);  # 11 (double first: 10, then add one: 11)

=item C<and_then($g)>

Returns a new C<Function> that first applies this function, then applies C<$g>
to the result. Implements pipeline composition: C<g ∘ f>.

    my $add_one = Function->new(f => sub ($x) { $x + 1 });
    my $double  = Function->new(f => sub ($x) { $x * 2 });
    my $piped = $add_one->and_then($double);
    say $piped->apply(5);  # 12 (add one first: 6, then double: 12)

=back

=head2 BiFunction

Represents a binary function that takes two arguments and returns a value.

=head3 Constructor

    my $bifn = BiFunction->new(f => sub ($t, $u) { ... });

=head3 Methods

=over 4

=item C<apply($t, $u)>

Applies the function to the given arguments and returns the result.

    my $result = $bifn->apply($val1, $val2);

=item C<curry($t)>

Partially applies the function with the first argument, returning a C<Function>
that takes the second argument.

    my $add = BiFunction->new(f => sub ($x, $y) { $x + $y });
    my $add_10 = $add->curry(10);
    say $add_10->apply(5);  # 15

=item C<rcurry($u)>

Partially applies the function with the second argument (right curry), returning
a C<Function> that takes the first argument.

    my $subtract = BiFunction->new(f => sub ($x, $y) { $x - $y });
    my $subtract_from_10 = $subtract->rcurry(10);
    say $subtract_from_10->apply(15);  # 5 (15 - 10)

=item C<and_then($g)>

Returns a new C<BiFunction> that first applies this function to two arguments,
then applies the unary function C<$g> to the result.

    my $add = BiFunction->new(f => sub ($x, $y) { $x + $y });
    my $double = Function->new(f => sub ($x) { $x * 2 });
    my $add_then_double = $add->and_then($double);
    say $add_then_double->apply(3, 4);  # 14 ((3 + 4) * 2)

=back

=head2 Predicate

Represents a boolean-valued function that tests a condition.

=head3 Constructor

    my $pred = Predicate->new(f => sub ($t) { ... });

=head3 Methods

=over 4

=item C<test($t)>

Tests the predicate on the given value, returning a boolean.

    my $result = $pred->test($value);

=item C<not()>

Returns a new C<Predicate> that is the logical negation of this predicate.

    my $is_even = Predicate->new(f => sub ($x) { $x % 2 == 0 });
    my $is_odd = $is_even->not;
    say $is_odd->test(3);  # 1 (true)

=item C<and($p)>

Returns a new C<Predicate> that represents the logical AND of this predicate
and C<$p>.

    my $is_positive = Predicate->new(f => sub ($x) { $x > 0 });
    my $is_even = Predicate->new(f => sub ($x) { $x % 2 == 0 });
    my $is_positive_even = $is_positive->and($is_even);
    say $is_positive_even->test(4);   # 1 (true)
    say $is_positive_even->test(-4);  # 0 (false)

=item C<or($p)>

Returns a new C<Predicate> that represents the logical OR of this predicate
and C<$p>.

    my $is_zero = Predicate->new(f => sub ($x) { $x == 0 });
    my $is_positive = Predicate->new(f => sub ($x) { $x > 0 });
    my $is_non_negative = $is_zero->or($is_positive);
    say $is_non_negative->test(0);   # 1 (true)
    say $is_non_negative->test(-5);  # 0 (false)

=back

=head2 Consumer

Represents an operation that accepts a single input argument and returns no result
(performs side effects).

=head3 Constructor

    my $consumer = Consumer->new(f => sub ($t) { ... });

=head3 Methods

=over 4

=item C<accept($t)>

Performs the operation on the given argument. Returns nothing.

    $consumer->accept($value);

=item C<and_then($g)>

Returns a new C<Consumer> that first performs this operation, then performs
the operation C<$g>.

    my $print = Consumer->new(f => sub ($x) { say "Value: $x" });
    my $log = Consumer->new(f => sub ($x) { warn "Logged: $x" });
    my $print_and_log = $print->and_then($log);
    $print_and_log->accept(42);  # both prints and logs

=back

=head2 BiConsumer

Represents an operation that accepts two input arguments and returns no result
(performs side effects).

=head3 Constructor

    my $biconsumer = BiConsumer->new(f => sub ($t, $u) { ... });

=head3 Methods

=over 4

=item C<accept($t, $u)>

Performs the operation on the given arguments. Returns nothing.

    $biconsumer->accept($val1, $val2);

=item C<and_then($g)>

Returns a new C<BiConsumer> that first performs this operation, then performs
the operation C<$g>.

    my $print_both = BiConsumer->new(f => sub ($x, $y) {
        say "First: $x, Second: $y"
    });
    my $log_both = BiConsumer->new(f => sub ($x, $y) {
        warn "Logged: $x, $y"
    });
    my $combined = $print_both->and_then($log_both);
    $combined->accept(1, 2);  # both prints and logs

=back

=head2 Supplier

Represents a supplier of values that takes no arguments.

=head3 Constructor

    my $supplier = Supplier->new(f => sub { ... });

=head3 Methods

=over 4

=item C<get()>

Gets a value from the supplier.

    my $value = $supplier->get;

=back

=head2 Comparator

Represents a comparison function that imposes a total ordering on objects.

=head3 Constructor

    my $comp = Comparator->new(f => sub ($l, $r) { ... });

The function should return a negative number if C<$l E<lt> $r>, zero if C<$l == $r>,
and a positive number if C<$l E<gt> $r>.

=head3 Class Methods

=over 4

=item C<numeric()>

Returns a singleton C<Comparator> for numeric comparison (using C<< <=> >>).

    my $comp = Comparator->numeric;
    my @sorted = sort { $comp->compare($a, $b) } @numbers;

=item C<alpha()>

Returns a singleton C<Comparator> for alphabetic comparison (using C<cmp>).

    my $comp = Comparator->alpha;
    my @sorted = sort { $comp->compare($a, $b) } @strings;

=back

=head3 Methods

=over 4

=item C<compare($l, $r)>

Compares the two arguments and returns a negative number, zero, or positive
number as described above.

    my $result = $comp->compare($left, $right);

=item C<reversed()>

Returns a new C<Comparator> that imposes the reverse ordering of this comparator.

    my $reverse_numeric = Comparator->numeric->reversed;
    my @sorted = sort { $reverse_numeric->compare($a, $b) } @numbers;
    # @sorted is now in descending order

=back

=head1 SEE ALSO

L<grey::static>

=head1 AUTHOR

grey::static

=cut


use v5.42;
use utf8;
use experimental qw[ class keyword_any keyword_all ];
use grey::static::error;

class Stack {
    use overload (
        '""' => sub ($self, @) { $self->to_string() },
        fallback => 1,
    );

    field $items :param;

    ADJUST {
        Error->throw("items must be an arrayref") unless ref $items eq 'ARRAY';
        $items = [@$items];  # defensive copy
    }

    # --------------------------------------------------------------------------
    # Class methods (constructors)
    # --------------------------------------------------------------------------

    sub of ($class, @values) {
        return $class->new(items => [@values]);
    }

    sub empty ($class) {
        return $class->new(items => []);
    }

    # --------------------------------------------------------------------------
    # Core operations
    # --------------------------------------------------------------------------

    method size () {
        return scalar @$items;
    }

    method is_empty () {
        return $self->size() == 0;
    }

    method push (@values) {
        return Stack->new(items => [@$items, @values]);
    }

    method pop () {
        Error->throw("Cannot pop from empty stack")
            if $self->is_empty();
        my @new_items = @$items[0 .. $#$items - 1];
        return [$items->[-1], Stack->new(items => \@new_items)];
    }

    method peek () {
        return Option->new() if $self->is_empty();
        return Option->new(some => $items->[-1]);
    }

    # --------------------------------------------------------------------------
    # Functional operations
    # --------------------------------------------------------------------------

    method map ($function) {
        Error->throw("map requires a Function") unless defined $function;
        return Stack->new(items => [ map { $function->apply($_) } @$items ]);
    }

    method grep ($predicate) {
        Error->throw("grep requires a Predicate") unless defined $predicate;
        return Stack->new(items => [ grep { $predicate->test($_) } @$items ]);
    }

    method foreach ($consumer) {
        Error->throw("foreach requires a Consumer") unless defined $consumer;
        for my $item (@$items) {
            $consumer->accept($item);
        }
        return;
    }

    method find ($predicate) {
        Error->throw("find requires a Predicate") unless defined $predicate;
        for my $item (@$items) {
            return Option->new(some => $item) if $predicate->test($item);
        }
        return Option->new();
    }

    method contains ($value) {
        return any { $_ eq $value } @$items;
    }

    # --------------------------------------------------------------------------
    # Conversion
    # --------------------------------------------------------------------------

    method to_stream () {
        return Stream->from_array([@$items]);
    }

    method to_array () {
        return [@$items];
    }

    method to_list () {
        return @$items;
    }

    method to_string () {
        my $contents = join(', ', map { defined $_ ? $_ : 'undef' } @$items);
        return "Stack[$contents]";
    }
}

__END__

=encoding UTF-8

=head1 NAME

Stack - Immutable LIFO (Last-In-First-Out) collection

=head1 SYNOPSIS

    use grey::static qw[ functional datatypes::collections ];

    # Create stacks
    my $stack = Stack->of(1, 2, 3);
    my $empty = Stack->empty();
    my $stack2 = Stack->new(items => [10, 20, 30]);

    # Basic operations
    say $stack->size();         # 3
    say $stack->is_empty();     # false

    # Push elements (returns new Stack)
    my $pushed = $stack->push(4, 5);
    say $pushed;  # Stack[1, 2, 3, 4, 5]

    # Pop element (returns [value, new_stack])
    my ($value, $new_stack) = $stack->pop()->@*;
    say $value;      # 3
    say $new_stack;  # Stack[1, 2]

    # Peek at top without removing
    my $top = $stack->peek();
    say $top->get() if $top->is_some();  # 3

    # Functional operations
    my $doubled = $stack->map(Function->new(f => sub ($x) { $x * 2 }));
    my $evens = $stack->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));

    # Conversion
    my $stream = $stack->to_stream();
    my $arrayref = $stack->to_array();

=head1 DESCRIPTION

C<Stack> is an immutable LIFO (Last-In-First-Out) collection that wraps a Perl
arrayref. All operations return new Stack instances, preserving immutability.

In a stack, the most recently added element is the first to be removed (like a
stack of plates - you add and remove from the top).

Key features:

=over 4

=item *

B<Immutable> - All operations return new Stack instances

=item *

B<LIFO semantics> - Last In, First Out

=item *

B<Functional operations> - map, grep, foreach, find

=item *

B<Stream integration> - Convert to Stream for complex pipelines

=item *

B<Type-safe> - All functional operations require proper Function/Predicate objects

=back

=head1 CONSTRUCTORS

=head2 new

    my $stack = Stack->new(items => \@array);

Standard constructor that takes a hashref with an C<items> field.

B<Parameters:>

=over 4

=item C<items> (required)

An arrayref of elements. A defensive copy is made to ensure ownership.
Elements are stored in the order provided, with the last element being the top.

=back

B<Dies> if C<items> is not an arrayref.

=head2 of

    my $stack = Stack->of(@values);

Convenience constructor that creates a Stack from values. The last value becomes
the top of the stack.

B<Example:>

    my $stack = Stack->of(1, 2, 3);
    say $stack->peek()->get();  # 3 (top of stack)

=head2 empty

    my $stack = Stack->empty();

Creates an empty Stack.

=head1 CORE OPERATIONS

=head2 size

    my $n = $stack->size();

Returns the number of elements in the stack.

=head2 is_empty

    my $empty = $stack->is_empty();

Returns true if the stack contains no elements.

=head2 push

    my $new_stack = $stack->push(@values);

Returns a new Stack with the given values pushed onto the top. Multiple values
are pushed in order, with the last value ending up on top.

B<Example:>

    my $stack = Stack->of(1, 2);
    my $pushed = $stack->push(3, 4);
    say $pushed->peek()->get();  # 4 (last pushed value is on top)

=head2 pop

    my ($value, $new_stack) = $stack->pop()->@*;

Removes and returns the top element along with a new Stack without that element.

Returns an arrayref containing:

=over 4

=item C<$value>

The top element that was removed.

=item C<$new_stack>

A new Stack instance without the popped element.

=back

B<Dies> if the stack is empty.

B<Example:>

    my $stack = Stack->of(1, 2, 3);
    my ($top, $rest) = $stack->pop()->@*;
    say $top;   # 3
    say $rest;  # Stack[1, 2]

=head2 peek

    my $option = $stack->peek();

Returns an Option containing the top element without removing it.

B<Returns:> Option::Some containing the top element if the stack is not empty,
Option::None if empty.

B<Example:>

    my $stack = Stack->of(1, 2, 3);
    my $top = $stack->peek();
    if ($top->is_some()) {
        say $top->get();  # 3
    }

    my $empty = Stack->empty();
    say $empty->peek()->is_none();  # true

=head1 FUNCTIONAL OPERATIONS

All functional operations require proper Function/Predicate/Consumer objects.
Operations return new Stack instances (except foreach which returns nothing).

=head2 map

    my $new_stack = $stack->map($function);

Transforms each element using the given Function, returning a new Stack.

B<Dies> if C<$function> is not provided.

B<Example:>

    my $stack = Stack->of(1, 2, 3);
    my $doubled = $stack->map(Function->new(f => sub ($x) { $x * 2 }));
    say $doubled;  # Stack[2, 4, 6]

=head2 grep

    my $filtered = $stack->grep($predicate);

Filters elements based on the given Predicate, returning a new Stack.

B<Dies> if C<$predicate> is not provided.

B<Example:>

    my $stack = Stack->of(1, 2, 3, 4, 5);
    my $evens = $stack->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));
    say $evens;  # Stack[2, 4]

=head2 foreach

    $stack->foreach($consumer);

Applies the Consumer to each element for side effects. Returns nothing.

B<Dies> if C<$consumer> is not provided.

B<Example:>

    my $stack = Stack->of(1, 2, 3);
    $stack->foreach(Consumer->new(f => sub ($x) { say $x }));
    # Prints: 1, 2, 3 (bottom to top)

=head2 find

    my $option = $stack->find($predicate);

Returns an Option containing the first element (from bottom) matching the Predicate.

B<Dies> if C<$predicate> is not provided.

B<Returns:> An Option::Some containing the matching element, or Option::None.

=head2 contains

    my $bool = $stack->contains($value);

Returns true if the stack contains the given value (using string equality).

=head1 CONVERSION

=head2 to_stream

    my $stream = $stack->to_stream();

Converts the Stack to a Stream for complex pipeline operations. Elements are
streamed from bottom to top.

=head2 to_array

    my $arrayref = $stack->to_array();

Returns an arrayref containing the stack's elements (bottom to top).

=head2 to_list

    my @values = $stack->to_list();

Returns a Perl list of the elements (bottom to top).

=head2 to_string

    my $str = $stack->to_string();
    say $stack;  # Automatically stringifies

Returns a string representation of the Stack. Also used for string overloading.

B<Example:>

    my $stack = Stack->of(1, 2, 3);
    say $stack;  # Stack[1, 2, 3]

=head1 EXAMPLES

=head2 Basic Stack Operations

    my $stack = Stack->empty();

    # Build up the stack
    $stack = $stack->push(1);
    $stack = $stack->push(2);
    $stack = $stack->push(3);
    say $stack;  # Stack[1, 2, 3]

    # Pop elements
    my ($val1, $stack2) = $stack->pop()->@*;
    say $val1;    # 3
    my ($val2, $stack3) = $stack2->pop()->@*;
    say $val2;    # 2
    my ($val3, $stack4) = $stack3->pop()->@*;
    say $val3;    # 1
    say $stack4->is_empty();  # true

=head2 Using peek

    my $stack = Stack->of(10, 20, 30);

    # Check top without removing
    my $top = $stack->peek();
    say $top->get() if $top->is_some();  # 30

    # Stack unchanged
    say $stack->size();  # 3

=head2 Functional Operations

    my $stack = Stack->of(1, 2, 3, 4, 5);

    # Transform
    my $doubled = $stack->map(Function->new(f => sub ($x) { $x * 2 }));
    say $doubled;  # Stack[2, 4, 6, 8, 10]

    # Filter
    my $evens = $stack->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));
    say $evens;  # Stack[2, 4]

    # Find
    my $found = $stack->find(Predicate->new(f => sub ($x) { $x > 3 }));
    say $found->get() if $found->is_some();  # 4

=head2 Processing Stack Elements

    my $stack = Stack->of('apple', 'banana', 'cherry');

    # Process all elements
    $stack->foreach(Consumer->new(f => sub ($item) {
        say "Item: $item";
    }));
    # Prints:
    # Item: apple
    # Item: banana
    # Item: cherry

=head2 Chaining Operations

    my $result = Stack->of(1, 2, 3, 4, 5)
        ->push(6, 7, 8)
        ->map(Function->new(f => sub ($x) { $x * 2 }))
        ->grep(Predicate->new(f => sub ($x) { $x > 10 }))
        ->peek();

    say $result->get() if $result->is_some();  # 16

=head1 STACK vs LIST

Use Stack when:

=over 4

=item *

You need LIFO semantics

=item *

You're implementing algorithms that use stack data structure

=item *

You need peek() to inspect the top element

=back

Use List when:

=over 4

=item *

You need indexed access (at, slice)

=item *

You need to work with elements in order

=item *

You need more complex operations (reduce, sort, etc.)

=back

=head1 SEE ALSO

=over 4

=item *

L<List> - Ordered collection with indexed access

=item *

L<Queue> - FIFO collection

=item *

L<Set> - Unordered unique elements

=item *

L<Map> - Key-value pairs

=item *

L<Stream> - Lazy stream processing

=back

=head1 AUTHOR

grey::static

=cut

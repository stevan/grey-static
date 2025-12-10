
use v5.42;
use utf8;
use experimental qw[ class keyword_any keyword_all ];
use grey::static::error;

class List {
    use overload (
        '""' => sub ($self, @) { $self->to_string() },
        fallback => 1,
    );

    field $items :param;

    ADJUST {
        # Validate and copy the items arrayref to ensure ownership
        Error->throw("items must be an arrayref") unless ref $items eq 'ARRAY';
        $items = [@$items];  # defensive copy
    }

    # --------------------------------------------------------------------------
    # Class methods (constructors)
    # --------------------------------------------------------------------------

    sub of {
        my ($class, @values) = @_;
        return List->new(items => [@values]);
    }

    sub empty {
        my ($class) = @_;
        return List->new(items => []);
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

    method at ($index) {
        Error->throw("Index out of bounds: $index")
            if $index < 0 || $index >= $self->size();
        return $items->[$index];
    }

    method first () {
        Error->throw("Cannot get first element of empty list")
            if $self->is_empty();
        return $items->[0];
    }

    method last () {
        Error->throw("Cannot get last element of empty list")
            if $self->is_empty();
        return $items->[-1];
    }

    method slice ($start, $end) {
        Error->throw("Invalid slice range: start=$start, end=$end")
            if $start < 0 || $end < $start || $end > $self->size();
        return List->new(items => [@$items[$start .. $end - 1]]);
    }

    method push (@values) {
        return List->new(items => [@$items, @values]);
    }

    method pop () {
        Error->throw("Cannot pop from empty list")
            if $self->is_empty();
        my @new_items = @$items[0 .. $#$items - 1];
        return [$items->[-1], List->new(items => \@new_items)];
    }

    method shift () {
        Error->throw("Cannot shift from empty list")
            if $self->is_empty();
        my @new_items = @$items[1 .. $#$items];
        return [$items->[0], List->new(items => \@new_items)];
    }

    method unshift (@values) {
        return List->new(items => [@values, @$items]);
    }

    method reverse () {
        return List->new(items => [reverse @$items]);
    }

    method sort ($comparator = undef) {
        if (defined $comparator) {
            # Comparator is expected to be a Comparator object with compare($a, $b)
            my @sorted = sort { $comparator->compare($a, $b) } @$items;
            return List->new(items => \@sorted);
        } else {
            # Default sort
            my @sorted = sort @$items;
            return List->new(items => \@sorted);
        }
    }

    # --------------------------------------------------------------------------
    # Functional operations
    # --------------------------------------------------------------------------

    method map ($function) {
        Error->throw("map requires a Function") unless defined $function;
        return List->new(items => [ map { $function->apply($_) } @$items ]);
    }

    method grep ($predicate) {
        Error->throw("grep requires a Predicate") unless defined $predicate;
        return List->new(items => [ grep { $predicate->test($_) } @$items ]);
    }

    method reduce ($initial, $bifunction) {
        Error->throw("reduce requires a BiFunction") unless defined $bifunction;
        my $acc = $initial;
        for my $item (@$items) {
            $acc = $bifunction->apply($acc, $item);
        }
        return $acc;
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
        return Option->new(); # None
    }

    method contains ($value) {
        return any { $_ eq $value } @$items;
    }

    method any ($predicate) {
        Error->throw("any requires a Predicate") unless defined $predicate;
        return any { $predicate->test($_) } @$items;
    }

    method all ($predicate) {
        Error->throw("all requires a Predicate") unless defined $predicate;
        return all { $predicate->test($_) } @$items;
    }

    method none ($predicate) {
        Error->throw("none requires a Predicate") unless defined $predicate;
        return !any { $predicate->test($_) } @$items;
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
        return "List[$contents]";
    }
}

__END__

=encoding UTF-8

=head1 NAME

List - Immutable ordered collection with functional operations

=head1 SYNOPSIS

    use grey::static qw[ functional datatypes::collections ];

    # Create lists
    my $list = List->of(1, 2, 3, 4, 5);
    my $empty = List->empty();
    my $list2 = List->new(items => [10, 20, 30]);

    # Access elements
    say $list->size();          # 5
    say $list->at(0);           # 1
    say $list->first();         # 1
    say $list->last();          # 5
    say $list->is_empty();      # false

    # Functional operations
    my $doubled = $list->map(Function->new(f => sub ($x) { $x * 2 }));
    say $doubled;  # List[2, 4, 6, 8, 10]

    my $evens = $list->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));
    say $evens;    # List[2, 4]

    my $sum = $list->reduce(0, BiFunction->new(f => sub ($a, $b) { $a + $b }));
    say $sum;      # 15

    # Core operations (all return new Lists)
    my $pushed = $list->push(6, 7);
    my ($value, $popped) = $list->pop()->@*;
    my $reversed = $list->reverse();
    my $sorted = $list->sort();

    # Conversion
    my $stream = $list->to_stream();
    my $arrayref = $list->to_array();
    my @values = $list->to_list();

=head1 DESCRIPTION

C<List> is an immutable ordered collection that wraps a Perl arrayref and provides
functional operations. All operations return new List instances, preserving
immutability.

Key features:

=over 4

=item *

B<Immutable> - All operations return new List instances

=item *

B<Functional operations> - map, grep, reduce, find, any, all, none

=item *

B<Rich API> - Comprehensive set of list operations

=item *

B<Stream integration> - Convert to Stream for complex pipelines

=item *

B<Type-safe> - All functional operations require proper Function/Predicate objects

=back

=head1 CONSTRUCTORS

=head2 new

    my $list = List->new(items => \@array);

Standard constructor that takes a hashref with an C<items> field.

B<Parameters:>

=over 4

=item C<items> (required)

An arrayref of elements. A defensive copy is made to ensure ownership.

=back

B<Dies> if C<items> is not an arrayref.

=head2 of

    my $list = List->of(@values);

Convenience constructor that creates a List from values.

B<Parameters:>

=over 4

=item C<@values>

Zero or more values to include in the list.

=back

B<Example:>

    my $list = List->of(1, 2, 3);
    my $names = List->of('Alice', 'Bob', 'Charlie');

=head2 empty

    my $list = List->empty();

Creates an empty List.

=head1 CORE OPERATIONS

=head2 size

    my $n = $list->size();

Returns the number of elements in the list.

=head2 is_empty

    my $empty = $list->is_empty();

Returns true if the list contains no elements.

=head2 at

    my $value = $list->at($index);

Returns the element at the given index (0-based).

B<Dies> if the index is out of bounds.

=head2 first

    my $value = $list->first();

Returns the first element in the list.

B<Dies> if the list is empty.

=head2 last

    my $value = $list->last();

Returns the last element in the list.

B<Dies> if the list is empty.

=head2 slice

    my $sublist = $list->slice($start, $end);

Returns a new List containing elements from C<$start> (inclusive) to C<$end> (exclusive).

B<Dies> if the range is invalid.

B<Example:>

    my $list = List->of(1, 2, 3, 4, 5);
    my $slice = $list->slice(1, 4);  # List[2, 3, 4]

=head2 push

    my $new_list = $list->push(@values);

Returns a new List with the given values appended to the end.

=head2 pop

    my ($value, $new_list) = $list->pop()->@*;

Returns an arrayref containing the last element and a new List without that element.

B<Dies> if the list is empty.

=head2 shift

    my ($value, $new_list) = $list->shift()->@*;

Returns an arrayref containing the first element and a new List without that element.

B<Dies> if the list is empty.

=head2 unshift

    my $new_list = $list->unshift(@values);

Returns a new List with the given values prepended to the beginning.

=head2 reverse

    my $reversed = $list->reverse();

Returns a new List with elements in reverse order.

=head2 sort

    my $sorted = $list->sort();
    my $sorted = $list->sort($comparator);

Returns a new List with elements sorted. Without arguments, uses default Perl sort.
With a Comparator, uses the comparator's compare method.

B<Example:>

    my $nums = List->of(3, 1, 4, 1, 5);
    my $sorted = $nums->sort();  # List[1, 1, 3, 4, 5]

    my $comp = Comparator->new(c => sub ($a, $b) { $b <=> $a });
    my $desc = $nums->sort($comp);  # List[5, 4, 3, 1, 1]

=head1 FUNCTIONAL OPERATIONS

All functional operations require proper Function/Predicate/Consumer objects.
Operations return new List instances (except foreach which returns nothing).

=head2 map

    my $new_list = $list->map($function);

Transforms each element using the given Function, returning a new List.

B<Parameters:>

=over 4

=item C<$function>

A Function object whose apply() method will be called for each element.

=back

B<Dies> if C<$function> is not provided.

B<Example:>

    my $list = List->of(1, 2, 3);
    my $doubled = $list->map(Function->new(f => sub ($x) { $x * 2 }));
    say $doubled;  # List[2, 4, 6]

=head2 grep

    my $filtered = $list->grep($predicate);

Filters elements based on the given Predicate, returning a new List.

B<Parameters:>

=over 4

=item C<$predicate>

A Predicate object whose test() method determines if an element is included.

=back

B<Dies> if C<$predicate> is not provided.

B<Example:>

    my $list = List->of(1, 2, 3, 4, 5);
    my $evens = $list->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));
    say $evens;  # List[2, 4]

=head2 reduce

    my $result = $list->reduce($initial, $bifunction);

Reduces the list to a single value by repeatedly applying the BiFunction.

B<Parameters:>

=over 4

=item C<$initial>

The initial accumulator value.

=item C<$bifunction>

A BiFunction object whose apply($accumulator, $element) method combines values.

=back

B<Dies> if C<$bifunction> is not provided.

B<Example:>

    my $list = List->of(1, 2, 3, 4, 5);
    my $sum = $list->reduce(0, BiFunction->new(f => sub ($a, $b) { $a + $b }));
    say $sum;  # 15

    my $product = $list->reduce(1, BiFunction->new(f => sub ($a, $b) { $a * $b }));
    say $product;  # 120

=head2 foreach

    $list->foreach($consumer);

Applies the Consumer to each element for side effects. Returns nothing.

B<Parameters:>

=over 4

=item C<$consumer>

A Consumer object whose accept() method is called for each element.

=back

B<Dies> if C<$consumer> is not provided.

B<Example:>

    my $list = List->of(1, 2, 3);
    $list->foreach(Consumer->new(f => sub ($x) { say $x }));
    # Prints:
    # 1
    # 2
    # 3

=head2 find

    my $option = $list->find($predicate);

Returns an Option containing the first element matching the Predicate, or None.

B<Parameters:>

=over 4

=item C<$predicate>

A Predicate object whose test() method identifies the desired element.

=back

B<Dies> if C<$predicate> is not provided.

B<Returns:> An Option::Some containing the matching element, or Option::None.

B<Example:>

    my $list = List->of(1, 2, 3, 4, 5);
    my $found = $list->find(Predicate->new(f => sub ($x) { $x > 3 }));
    say $found->get();  # 4

=head2 contains

    my $bool = $list->contains($value);

Returns true if the list contains the given value (using string equality).

=head2 any

    my $bool = $list->any($predicate);

Returns true if any element matches the Predicate.

B<Dies> if C<$predicate> is not provided.

=head2 all

    my $bool = $list->all($predicate);

Returns true if all elements match the Predicate.

B<Dies> if C<$predicate> is not provided.

=head2 none

    my $bool = $list->none($predicate);

Returns true if no elements match the Predicate.

B<Dies> if C<$predicate> is not provided.

=head1 CONVERSION

=head2 to_stream

    my $stream = $list->to_stream();

Converts the List to a Stream for complex pipeline operations.

B<Note:> Collection methods and Stream operations use compatible parameter types
but return different types. You cannot insert to_stream() mid-chain.

B<Example:>

    # This works - stream throughout
    my $result = $list->to_stream()
                      ->map($f)
                      ->flatmap($g)
                      ->take(10)
                      ->collect(ToList->new());

    # This works - collection methods throughout
    my $result = $list->map($f)->grep($p)->first();

=head2 to_array

    my $arrayref = $list->to_array();

Returns an arrayref containing the list's elements.

=head2 to_list

    my @values = $list->to_list();

Returns a Perl list of the elements.

=head2 to_string

    my $str = $list->to_string();
    say $list;  # Automatically stringifies

Returns a string representation of the List. Also used for string overloading.

B<Example:>

    my $list = List->of(1, 2, 3);
    say $list;  # List[1, 2, 3]

=head1 WHEN TO USE COLLECTIONS VS STREAMS

Use List methods for:

=over 4

=item *

Simple transformations (one or two operations)

=item *

When you want the result in List form

=item *

When performance isn't critical

=back

Use to_stream() for:

=over 4

=item *

Complex pipelines (three or more operations)

=item *

Operations not available on List (flatmap, flatten, take, etc.)

=item *

Lazy evaluation

=item *

Large datasets

=back

=head1 EXAMPLES

=head2 Basic Operations

    my $list = List->of(1, 2, 3, 4, 5);

    # Transform
    my $doubled = $list->map(Function->new(f => sub ($x) { $x * 2 }));
    say $doubled;  # List[2, 4, 6, 8, 10]

    # Filter
    my $evens = $list->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));
    say $evens;  # List[2, 4]

    # Reduce
    my $sum = $list->reduce(0, BiFunction->new(f => sub ($a, $b) { $a + $b }));
    say $sum;  # 15

=head2 Chaining Operations

    my $result = List->of(1, 2, 3, 4, 5)
        ->map(Function->new(f => sub ($x) { $x * 2 }))
        ->grep(Predicate->new(f => sub ($x) { $x > 5 }))
        ->reverse();
    say $result;  # List[10, 8, 6]

=head2 Finding Elements

    my $list = List->of(1, 2, 3, 4, 5);

    my $found = $list->find(Predicate->new(f => sub ($x) { $x > 3 }));
    if ($found->is_some()) {
        say "Found: ", $found->get();  # Found: 4
    }

    say $list->any(Predicate->new(f => sub ($x) { $x > 10 }));   # false
    say $list->all(Predicate->new(f => sub ($x) { $x > 0 }));    # true
    say $list->none(Predicate->new(f => sub ($x) { $x < 0 }));   # true

=head2 Building Lists

    my $list = List->empty()
        ->push(1, 2, 3)
        ->unshift(0)
        ->push(4, 5);
    say $list;  # List[0, 1, 2, 3, 4, 5]

=head2 Stream Integration

    my $list = List->of(1, 2, 3, 4, 5);

    # Use stream for complex operations
    my $result = $list->to_stream()
        ->flatmap(Function->new(f => sub ($x) {
            Stream->of($x, $x * 2)
        }))
        ->take(5)
        ->collect(ToList->new());
    say $result;  # List[1, 2, 2, 4, 3]

=head1 SEE ALSO

=over 4

=item *

L<Stack> - LIFO collection

=item *

L<Queue> - FIFO collection

=item *

L<Set> - Unordered unique elements

=item *

L<Map> - Key-value pairs

=item *

L<Stream> - Lazy stream processing

=item *

L<grey::static::functional> - Functional primitives

=back

=head1 AUTHOR

grey::static

=cut

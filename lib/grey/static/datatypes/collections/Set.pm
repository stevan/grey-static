
use v5.42;
use utf8;
use experimental qw[ class keyword_any keyword_all ];
use grey::static::error;

class Set {
    use overload (
        '""' => sub ($self, @) { $self->to_string() },
        fallback => 1,
    );

    field $items :param;

    ADJUST {
        Error->throw("items must be an arrayref") unless ref $items eq 'ARRAY';
        # Create hash from array for uniqueness
        my %unique = map { $_ => 1 } @$items;
        $items = \%unique;
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
        return scalar keys %$items;
    }

    method is_empty () {
        return $self->size() == 0;
    }

    method contains ($value) {
        return exists $items->{$value};
    }

    method add (@values) {
        my %new_items = %$items;
        $new_items{$_} = 1 for @values;
        return Set->new(items => [keys %new_items]);
    }

    method remove (@values) {
        my %new_items = %$items;
        delete $new_items{$_} for @values;
        return Set->new(items => [keys %new_items]);
    }

    method union ($other_set) {
        Error->throw("union requires a Set") unless $other_set isa Set;
        my %new_items = %$items;
        $new_items{$_} = 1 for $other_set->to_list();
        return Set->new(items => [keys %new_items]);
    }

    method intersection ($other_set) {
        Error->throw("intersection requires a Set") unless $other_set isa Set;
        my @common = grep { $other_set->contains($_) } keys %$items;
        return Set->new(items => \@common);
    }

    method difference ($other_set) {
        Error->throw("difference requires a Set") unless $other_set isa Set;
        my @diff = grep { !$other_set->contains($_) } keys %$items;
        return Set->new(items => \@diff);
    }

    method is_subset ($other_set) {
        Error->throw("is_subset requires a Set") unless $other_set isa Set;
        return all { $other_set->contains($_) } keys %$items;
    }

    method is_superset ($other_set) {
        Error->throw("is_superset requires a Set") unless $other_set isa Set;
        return $other_set->is_subset($self);
    }

    # --------------------------------------------------------------------------
    # Functional operations
    # --------------------------------------------------------------------------

    method map ($function) {
        Error->throw("map requires a Function") unless defined $function;
        my @values = map { $function->apply($_) } keys %$items;
        return Set->new(items => \@values);
    }

    method grep ($predicate) {
        Error->throw("grep requires a Predicate") unless defined $predicate;
        my @values = grep { $predicate->test($_) } keys %$items;
        return Set->new(items => \@values);
    }

    method foreach ($consumer) {
        Error->throw("foreach requires a Consumer") unless defined $consumer;
        for my $item (keys %$items) {
            $consumer->accept($item);
        }
        return;
    }

    method find ($predicate) {
        Error->throw("find requires a Predicate") unless defined $predicate;
        for my $item (keys %$items) {
            return Option->new(some => $item) if $predicate->test($item);
        }
        return Option->new();
    }

    method any ($predicate) {
        Error->throw("any requires a Predicate") unless defined $predicate;
        return any { $predicate->test($_) } keys %$items;
    }

    method all ($predicate) {
        Error->throw("all requires a Predicate") unless defined $predicate;
        return all { $predicate->test($_) } keys %$items;
    }

    method none ($predicate) {
        Error->throw("none requires a Predicate") unless defined $predicate;
        return !any { $predicate->test($_) } keys %$items;
    }

    # --------------------------------------------------------------------------
    # Conversion
    # --------------------------------------------------------------------------

    method to_stream () {
        return Stream->from_array([keys %$items]);
    }

    method to_array () {
        return [keys %$items];
    }

    method to_list () {
        return keys %$items;
    }

    method to_string () {
        my $contents = join(', ', sort keys %$items);
        return "Set{$contents}";
    }
}

__END__

=encoding UTF-8

=head1 NAME

Set - Immutable unordered collection of unique elements

=head1 SYNOPSIS

    use grey::static qw[ functional datatypes::collections ];

    # Create sets
    my $set = Set->of(1, 2, 3, 2, 1);  # Duplicates removed
    my $empty = Set->empty();
    my $set2 = Set->new(items => [10, 20, 30]);

    # Basic operations
    say $set->size();           # 3
    say $set->contains(2);      # true
    say $set->is_empty();       # false

    # Modify (returns new Set)
    my $added = $set->add(4, 5);
    my $removed = $set->remove(2);

    # Set operations
    my $set_a = Set->of(1, 2, 3);
    my $set_b = Set->of(2, 3, 4);

    my $union = $set_a->union($set_b);          # Set{1, 2, 3, 4}
    my $inter = $set_a->intersection($set_b);   # Set{2, 3}
    my $diff  = $set_a->difference($set_b);     # Set{1}

    say $set_a->is_subset($set_b);      # false
    say $set_b->is_superset($set_a);    # false

    # Functional operations
    my $doubled = $set->map(Function->new(f => sub ($x) { $x * 2 }));
    my $evens = $set->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));

    # Conversion
    my $stream = $set->to_stream();
    my $arrayref = $set->to_array();

=head1 DESCRIPTION

C<Set> is an immutable unordered collection of unique elements that wraps a Perl
hash. All operations return new Set instances, preserving immutability.

Sets automatically eliminate duplicates and do not maintain insertion order.

Key features:

=over 4

=item *

B<Immutable> - All operations return new Set instances

=item *

B<Unique elements> - Duplicates automatically removed

=item *

B<Unordered> - No guaranteed element order

=item *

B<Set operations> - union, intersection, difference, subset, superset

=item *

B<Functional operations> - map, grep, foreach, find, any, all, none

=item *

B<Stream integration> - Convert to Stream for complex pipelines

=back

=head1 CONSTRUCTORS

=head2 new

    my $set = Set->new(items => \@array);

Standard constructor that takes a hashref with an C<items> field.

B<Parameters:>

=over 4

=item C<items> (required)

An arrayref of elements. Duplicates are automatically removed. A defensive copy
is made to ensure ownership.

=back

B<Dies> if C<items> is not an arrayref.

=head2 of

    my $set = Set->of(@values);

Convenience constructor that creates a Set from values. Duplicates are removed.

B<Example:>

    my $set = Set->of(1, 2, 3, 2, 1);
    say $set->size();  # 3 (duplicates removed)

=head2 empty

    my $set = Set->empty();

Creates an empty Set.

=head1 CORE OPERATIONS

=head2 size

    my $n = $set->size();

Returns the number of elements in the set.

=head2 is_empty

    my $empty = $set->is_empty();

Returns true if the set contains no elements.

=head2 contains

    my $bool = $set->contains($value);

Returns true if the set contains the given value.

=head2 add

    my $new_set = $set->add(@values);

Returns a new Set with the given values added. Duplicate values (including
those already in the set) are handled automatically.

B<Example:>

    my $set = Set->of(1, 2, 3);
    my $added = $set->add(3, 4, 5);  # 3 already exists
    say $added;  # Set{1, 2, 3, 4, 5}

=head2 remove

    my $new_set = $set->remove(@values);

Returns a new Set with the given values removed. It's safe to remove values
that don't exist.

B<Example:>

    my $set = Set->of(1, 2, 3, 4, 5);
    my $removed = $set->remove(2, 4, 99);  # 99 doesn't exist
    say $removed;  # Set{1, 3, 5}

=head1 SET OPERATIONS

=head2 union

    my $result = $set_a->union($set_b);

Returns a new Set containing all elements from both sets.

B<Dies> if C<$set_b> is not a Set.

B<Example:>

    my $a = Set->of(1, 2, 3);
    my $b = Set->of(3, 4, 5);
    my $union = $a->union($b);
    say $union;  # Set{1, 2, 3, 4, 5}

=head2 intersection

    my $result = $set_a->intersection($set_b);

Returns a new Set containing only elements present in both sets.

B<Dies> if C<$set_b> is not a Set.

B<Example:>

    my $a = Set->of(1, 2, 3);
    my $b = Set->of(2, 3, 4);
    my $inter = $a->intersection($b);
    say $inter;  # Set{2, 3}

=head2 difference

    my $result = $set_a->difference($set_b);

Returns a new Set containing elements in C<$set_a> but not in C<$set_b>.

B<Dies> if C<$set_b> is not a Set.

B<Example:>

    my $a = Set->of(1, 2, 3, 4);
    my $b = Set->of(3, 4, 5);
    my $diff = $a->difference($b);
    say $diff;  # Set{1, 2}

=head2 is_subset

    my $bool = $set_a->is_subset($set_b);

Returns true if all elements of C<$set_a> are also in C<$set_b>.

B<Dies> if C<$set_b> is not a Set.

B<Example:>

    my $a = Set->of(1, 2);
    my $b = Set->of(1, 2, 3, 4);
    say $a->is_subset($b);  # true
    say $b->is_subset($a);  # false

=head2 is_superset

    my $bool = $set_a->is_superset($set_b);

Returns true if C<$set_a> contains all elements of C<$set_b>.

B<Dies> if C<$set_b> is not a Set.

B<Example:>

    my $a = Set->of(1, 2, 3, 4);
    my $b = Set->of(2, 3);
    say $a->is_superset($b);  # true
    say $b->is_superset($a);  # false

=head1 FUNCTIONAL OPERATIONS

All functional operations require proper Function/Predicate/Consumer objects.
Operations return new Set instances (except foreach which returns nothing).

=head2 map

    my $new_set = $set->map($function);

Transforms each element using the given Function, returning a new Set.
If the transformation produces duplicates, they are automatically removed.

B<Dies> if C<$function> is not provided.

B<Example:>

    my $set = Set->of(1, 2, 3);
    my $doubled = $set->map(Function->new(f => sub ($x) { $x * 2 }));
    say $doubled;  # Set{2, 4, 6}

=head2 grep

    my $filtered = $set->grep($predicate);

Filters elements based on the given Predicate, returning a new Set.

B<Dies> if C<$predicate> is not provided.

B<Example:>

    my $set = Set->of(1, 2, 3, 4, 5);
    my $evens = $set->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));
    say $evens;  # Set{2, 4}

=head2 foreach

    $set->foreach($consumer);

Applies the Consumer to each element for side effects. Returns nothing.
Elements are processed in arbitrary order.

B<Dies> if C<$consumer> is not provided.

=head2 find

    my $option = $set->find($predicate);

Returns an Option containing an arbitrary element matching the Predicate.
The specific element returned is unspecified due to set's unordered nature.

B<Dies> if C<$predicate> is not provided.

B<Returns:> An Option::Some containing a matching element, or Option::None.

=head2 any

    my $bool = $set->any($predicate);

Returns true if any element matches the Predicate.

B<Dies> if C<$predicate> is not provided.

=head2 all

    my $bool = $set->all($predicate);

Returns true if all elements match the Predicate.

B<Dies> if C<$predicate> is not provided.

=head2 none

    my $bool = $set->none($predicate);

Returns true if no elements match the Predicate.

B<Dies> if C<$predicate> is not provided.

=head1 CONVERSION

=head2 to_stream

    my $stream = $set->to_stream();

Converts the Set to a Stream for complex pipeline operations. Elements are
streamed in arbitrary order.

=head2 to_array

    my $arrayref = $set->to_array();

Returns an arrayref containing the set's elements in arbitrary order.

=head2 to_list

    my @values = $set->to_list();

Returns a Perl list of the elements in arbitrary order.

=head2 to_string

    my $str = $set->to_string();
    say $set;  # Automatically stringifies

Returns a string representation of the Set. Also used for string overloading.
Elements are sorted for consistent output.

B<Example:>

    my $set = Set->of(3, 1, 2);
    say $set;  # Set{1, 2, 3} (sorted for display)

=head1 EXAMPLES

=head2 Basic Set Operations

    my $set = Set->of(1, 2, 3, 2, 1);
    say $set;  # Set{1, 2, 3} (duplicates removed)

    say $set->contains(2);      # true
    say $set->contains(99);     # false

    my $added = $set->add(4, 5);
    say $added;  # Set{1, 2, 3, 4, 5}

    my $removed = $set->remove(2);
    say $removed;  # Set{1, 3}

=head2 Set Algebra

    my $primes = Set->of(2, 3, 5, 7);
    my $evens = Set->of(2, 4, 6, 8);

    # Union: all elements
    my $union = $primes->union($evens);
    say $union;  # Set{2, 3, 4, 5, 6, 7, 8}

    # Intersection: common elements
    my $both = $primes->intersection($evens);
    say $both;  # Set{2}

    # Difference: in primes but not evens
    my $odd_primes = $primes->difference($evens);
    say $odd_primes;  # Set{3, 5, 7}

=head2 Subset and Superset

    my $small = Set->of(1, 2);
    my $large = Set->of(1, 2, 3, 4, 5);

    say $small->is_subset($large);      # true
    say $large->is_superset($small);    # true

    say $small->is_superset($large);    # false
    say $large->is_subset($small);      # false

=head2 Functional Operations

    my $set = Set->of(1, 2, 3, 4, 5);

    # Transform
    my $doubled = $set->map(Function->new(f => sub ($x) { $x * 2 }));
    say $doubled;  # Set{2, 4, 6, 8, 10}

    # Filter
    my $evens = $set->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));
    say $evens;  # Set{2, 4}

    # Test predicates
    say $set->any(Predicate->new(f => sub ($x) { $x > 3 }));   # true
    say $set->all(Predicate->new(f => sub ($x) { $x > 0 }));   # true
    say $set->none(Predicate->new(f => sub ($x) { $x < 0 }));  # true

=head2 Chaining Operations

    my $result = Set->of(1, 2, 3, 4, 5)
        ->add(6, 7, 8)
        ->remove(1, 2)
        ->map(Function->new(f => sub ($x) { $x * 2 }))
        ->grep(Predicate->new(f => sub ($x) { $x > 10 }));

    say $result;  # Set{12, 14, 16}

=head2 Removing Duplicates

    my @data = (1, 2, 2, 3, 3, 3, 4, 5, 5);
    my $set = Set->of(@data);
    my @unique = $set->to_list();
    # @unique contains unique values (in arbitrary order)

=head1 IMPORTANT NOTES

=over 4

=item *

B<Unordered> - Sets do not maintain insertion order. Use List if order matters.

=item *

B<String keys> - Elements are stored using string representation as hash keys.
This works well for scalars but may have unexpected behavior for references.

=item *

B<Arbitrary iteration order> - foreach, find, and to_list/to_array produce
elements in arbitrary (hash) order. Only to_string sorts for consistent display.

=back

=head1 SEE ALSO

=over 4

=item *

L<List> - Ordered collection with indexed access

=item *

L<Stack> - LIFO collection

=item *

L<Queue> - FIFO collection

=item *

L<Map> - Key-value pairs

=item *

L<Stream> - Lazy stream processing

=back

=head1 AUTHOR

grey::static

=cut

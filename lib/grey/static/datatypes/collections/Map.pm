
use v5.42;
use utf8;
use experimental qw[ class keyword_any keyword_all ];
use grey::static::error;

class Map {
    use overload (
        '""' => sub ($self, @) { $self->to_string() },
        fallback => 1,
    );

    field $entries :param;

    ADJUST {
        Error->throw("entries must be a hashref") unless ref $entries eq 'HASH';
        $entries = {%$entries};  # defensive copy
    }

    # --------------------------------------------------------------------------
    # Class methods (constructors)
    # --------------------------------------------------------------------------

    sub of ($class, @pairs) {
        Error->throw("of() requires an even number of arguments")
            if @pairs % 2 != 0;
        my %hash = @pairs;
        return $class->new(entries => \%hash);
    }

    sub empty ($class) {
        return $class->new(entries => {});
    }

    # --------------------------------------------------------------------------
    # Core operations
    # --------------------------------------------------------------------------

    method size () {
        return scalar keys %$entries;
    }

    method is_empty () {
        return $self->size() == 0;
    }

    method get ($key) {
        return Option->new() unless exists $entries->{$key};
        return Option->new(some => $entries->{$key});
    }

    method contains_key ($key) {
        return exists $entries->{$key};
    }

    method contains_value ($value) {
        return any { $_ eq $value } values %$entries;
    }

    method put ($key, $value) {
        my %new_entries = %$entries;
        $new_entries{$key} = $value;
        return Map->new(entries => \%new_entries);
    }

    method remove (@keys) {
        my %new_entries = %$entries;
        delete $new_entries{$_} for @keys;
        return Map->new(entries => \%new_entries);
    }

    method keys () {
        require Set;
        return Set->new(items => [keys %$entries]);
    }

    method values () {
        require List;
        return List->new(items => [values %$entries]);
    }

    method entries () {
        require List;
        my @pairs = map { [$_, $entries->{$_}] } keys %$entries;
        return List->new(items => \@pairs);
    }

    # --------------------------------------------------------------------------
    # Functional operations
    # --------------------------------------------------------------------------

    method map ($bifunction) {
        Error->throw("map requires a BiFunction") unless defined $bifunction;
        my %new_entries = map { $_ => $bifunction->apply($_, $entries->{$_}) } keys %$entries;
        return Map->new(entries => \%new_entries);
    }

    method map_keys ($function) {
        Error->throw("map_keys requires a Function") unless defined $function;
        my %new_entries = map { $function->apply($_) => $entries->{$_} } keys %$entries;
        return Map->new(entries => \%new_entries);
    }

    method map_entries ($bifunction) {
        Error->throw("map_entries requires a BiFunction") unless defined $bifunction;
        my %new_entries;
        for my $key (keys %$entries) {
            my ($new_key, $new_value) = $bifunction->apply($key, $entries->{$key});
            $new_entries{$new_key} = $new_value;
        }
        return Map->new(entries => \%new_entries);
    }

    method grep ($bipredicate) {
        Error->throw("grep requires a BiPredicate") unless defined $bipredicate;
        my %new_entries;
        for my $key (keys %$entries) {
            $new_entries{$key} = $entries->{$key}
                if $bipredicate->test($key, $entries->{$key});
        }
        return Map->new(entries => \%new_entries);
    }

    method foreach ($biconsumer) {
        Error->throw("foreach requires a BiConsumer") unless defined $biconsumer;
        for my $key (keys %$entries) {
            $biconsumer->accept($key, $entries->{$key});
        }
        return;
    }

    method find ($bipredicate) {
        Error->throw("find requires a BiPredicate") unless defined $bipredicate;
        for my $key (keys %$entries) {
            return Option->new(some => [$key, $entries->{$key}])
                if $bipredicate->test($key, $entries->{$key});
        }
        return Option->new();
    }

    method reduce ($initial, $trifunction) {
        Error->throw("reduce requires a function") unless defined $trifunction;
        my $acc = $initial;
        for my $key (keys %$entries) {
            $acc = $trifunction->($acc, $key, $entries->{$key});
        }
        return $acc;
    }

    # --------------------------------------------------------------------------
    # Conversion
    # --------------------------------------------------------------------------

    method to_stream () {
        my @pairs = map { [$_, $entries->{$_}] } keys %$entries;
        return Stream->from_array(\@pairs);
    }

    method to_hash () {
        return {%$entries};
    }

    method to_string () {
        my @pairs = map { "$_=>" . (defined $entries->{$_} ? $entries->{$_} : 'undef') }
                    sort keys %$entries;
        my $contents = join(', ', @pairs);
        return "Map{$contents}";
    }
}

__END__

=encoding UTF-8

=head1 NAME

Map - Immutable key-value collection

=head1 SYNOPSIS

    use grey::static qw[ functional datatypes::collections ];

    # Create maps
    my $map = Map->of(
        name => 'Alice',
        age => 30,
        city => 'Boston'
    );
    my $empty = Map->empty();
    my $map2 = Map->new(entries => { x => 1, y => 2 });

    # Basic operations
    say $map->size();              # 3
    say $map->is_empty();          # false
    say $map->contains_key('name'); # true

    # Access values
    my $name = $map->get('name');
    say $name->get() if $name->is_some();  # Alice

    # Modify (returns new Map)
    my $updated = $map->put(state => 'MA');
    my $removed = $map->remove('age');

    # Extract keys and values
    my $keys = $map->keys();      # Returns Set
    my $values = $map->values();  # Returns List
    my $entries = $map->entries(); # Returns List of [$key, $value] pairs

    # Functional operations
    my $doubled = $map->map(BiFunction->new(f => sub ($k, $v) { $v * 2 }));
    my $filtered = $map->grep(BiPredicate->new(f => sub ($k, $v) { $v > 10 }));

    # Conversion
    my $stream = $map->to_stream();  # Stream of [$key, $value] pairs
    my $hashref = $map->to_hash();

=head1 DESCRIPTION

C<Map> is an immutable key-value collection that wraps a Perl hash. All operations
return new Map instances, preserving immutability.

Maps associate keys with values and provide efficient lookup by key.

Key features:

=over 4

=item *

B<Immutable> - All operations return new Map instances

=item *

B<Key-value pairs> - Associate keys with values

=item *

B<Unordered> - No guaranteed entry order

=item *

B<Functional operations> - map, grep, foreach, find, reduce

=item *

B<Stream integration> - Convert to Stream for complex pipelines

=item *

B<Type-safe> - All functional operations require proper BiFunction/BiPredicate objects

=back

=head1 CONSTRUCTORS

=head2 new

    my $map = Map->new(entries => \%hash);

Standard constructor that takes a hashref with an C<entries> field.

B<Parameters:>

=over 4

=item C<entries> (required)

A hashref of key-value pairs. A defensive copy is made to ensure ownership.

=back

B<Dies> if C<entries> is not a hashref.

=head2 of

    my $map = Map->of(@pairs);

Convenience constructor that creates a Map from a flat list of key-value pairs.

B<Parameters:>

=over 4

=item C<@pairs>

Alternating keys and values (k1, v1, k2, v2, ...). Must have an even number of elements.

=back

B<Dies> if the number of arguments is odd.

B<Example:>

    my $map = Map->of(
        name => 'Alice',
        age => 30,
        city => 'Boston'
    );

=head2 empty

    my $map = Map->empty();

Creates an empty Map.

=head1 CORE OPERATIONS

=head2 size

    my $n = $map->size();

Returns the number of key-value pairs in the map.

=head2 is_empty

    my $empty = $map->is_empty();

Returns true if the map contains no entries.

=head2 get

    my $option = $map->get($key);

Returns an Option containing the value associated with the key, or None if the
key doesn't exist.

B<Example:>

    my $map = Map->of(x => 10, y => 20);
    my $x = $map->get('x');
    if ($x->is_some()) {
        say $x->get();  # 10
    }

    my $z = $map->get('z');
    say $z->is_none();  # true

=head2 contains_key

    my $bool = $map->contains_key($key);

Returns true if the map contains the given key.

=head2 contains_value

    my $bool = $map->contains_value($value);

Returns true if the map contains the given value (using string equality).

B<Note:> This requires scanning all values and is O(n).

=head2 put

    my $new_map = $map->put($key, $value);

Returns a new Map with the key-value pair added. If the key already exists,
its value is replaced.

B<Example:>

    my $map = Map->of(x => 10);
    my $updated = $map->put(y => 20);
    say $updated;  # Map{x=>10, y=>20}

    my $replaced = $map->put(x => 99);
    say $replaced;  # Map{x=>99}

=head2 remove

    my $new_map = $map->remove(@keys);

Returns a new Map with the given keys removed. It's safe to remove keys that
don't exist.

B<Example:>

    my $map = Map->of(x => 10, y => 20, z => 30);
    my $removed = $map->remove('y', 'z');
    say $removed;  # Map{x=>10}

=head2 keys

    my $set = $map->keys();

Returns a Set containing all keys in the map.

B<Example:>

    my $map = Map->of(x => 10, y => 20, z => 30);
    my $keys = $map->keys();
    say $keys;  # Set{x, y, z}

=head2 values

    my $list = $map->values();

Returns a List containing all values in the map (in arbitrary order).

B<Example:>

    my $map = Map->of(x => 10, y => 20, z => 30);
    my $values = $map->values();
    # $values contains List[10, 20, 30] (order unspecified)

=head2 entries

    my $list = $map->entries();

Returns a List of [$key, $value] arrayrefs representing all entries (in arbitrary order).

B<Example:>

    my $map = Map->of(x => 10, y => 20);
    my $entries = $map->entries();
    $entries->foreach(Consumer->new(f => sub ($pair) {
        my ($k, $v) = @$pair;
        say "$k => $v";
    }));

=head1 FUNCTIONAL OPERATIONS

All functional operations require proper BiFunction/BiPredicate/BiConsumer objects
that operate on key-value pairs. Operations return new Map instances (except
foreach which returns nothing).

=head2 map

    my $new_map = $map->map($bifunction);

Transforms values using the given BiFunction, returning a new Map with transformed values.
Keys remain unchanged.

B<Parameters:>

=over 4

=item C<$bifunction>

A BiFunction whose apply($key, $value) method transforms the value.

=back

B<Dies> if C<$bifunction> is not provided.

B<Example:>

    my $map = Map->of(x => 10, y => 20);
    my $doubled = $map->map(BiFunction->new(f => sub ($k, $v) { $v * 2 }));
    say $doubled;  # Map{x=>20, y=>40}

=head2 map_keys

    my $new_map = $map->map_keys($function);

Transforms keys using the given Function, returning a new Map with transformed keys.
Values remain unchanged.

B<Parameters:>

=over 4

=item C<$function>

A Function whose apply($key) method transforms the key.

=back

B<Dies> if C<$function> is not provided.

B<Warning:> If the transformation produces duplicate keys, later values will
overwrite earlier ones.

=head2 map_entries

    my $new_map = $map->map_entries($bifunction);

Transforms both keys and values using the given BiFunction, returning a new Map.

B<Parameters:>

=over 4

=item C<$bifunction>

A BiFunction whose apply($key, $value) method returns [$new_key, $new_value].

=back

B<Dies> if C<$bifunction> is not provided.

B<Example:>

    my $map = Map->of(x => 10, y => 20);
    my $transformed = $map->map_entries(BiFunction->new(f => sub ($k, $v) {
        return [uc($k), $v * 2];
    }));
    say $transformed;  # Map{X=>20, Y=>40}

=head2 grep

    my $filtered = $map->grep($bipredicate);

Filters entries based on the given BiPredicate, returning a new Map.

B<Parameters:>

=over 4

=item C<$bipredicate>

A BiPredicate whose test($key, $value) method determines if an entry is included.

=back

B<Dies> if C<$bipredicate> is not provided.

B<Example:>

    my $map = Map->of(x => 5, y => 15, z => 25);
    my $large = $map->grep(BiPredicate->new(f => sub ($k, $v) { $v > 10 }));
    say $large;  # Map{y=>15, z=>25}

=head2 foreach

    $map->foreach($biconsumer);

Applies the BiConsumer to each entry for side effects. Returns nothing.
Entries are processed in arbitrary order.

B<Parameters:>

=over 4

=item C<$biconsumer>

A BiConsumer whose accept($key, $value) method is called for each entry.

=back

B<Dies> if C<$biconsumer> is not provided.

B<Example:>

    my $map = Map->of(x => 10, y => 20);
    $map->foreach(BiConsumer->new(f => sub ($k, $v) {
        say "$k => $v";
    }));

=head2 find

    my $option = $map->find($bipredicate);

Returns an Option containing the first entry [$key, $value] matching the BiPredicate.
The specific entry returned is unspecified due to map's unordered nature.

B<Parameters:>

=over 4

=item C<$bipredicate>

A BiPredicate whose test($key, $value) method identifies the desired entry.

=back

B<Dies> if C<$bipredicate> is not provided.

B<Returns:> An Option::Some containing [$key, $value], or Option::None.

=head2 reduce

    my $result = $map->reduce($initial, $trifunction);

Reduces the map to a single value by repeatedly applying the trifunction.

B<Parameters:>

=over 4

=item C<$initial>

The initial accumulator value.

=item C<$trifunction>

A coderef whose signature is ($accumulator, $key, $value) => $new_accumulator.

=back

B<Dies> if C<$trifunction> is not provided.

B<Example:>

    my $map = Map->of(x => 10, y => 20, z => 30);
    my $sum = $map->reduce(0, sub ($acc, $k, $v) { $acc + $v });
    say $sum;  # 60

=head1 CONVERSION

=head2 to_stream

    my $stream = $map->to_stream();

Converts the Map to a Stream of [$key, $value] pairs for complex pipeline operations.
Entries are streamed in arbitrary order.

B<Example:>

    my $stream = $map->to_stream()
        ->map(Function->new(f => sub ($pair) {
            my ($k, $v) = @$pair;
            return "$k=$v";
        }))
        ->collect(ToList->new());

=head2 to_hash

    my $hashref = $map->to_hash();

Returns a hashref containing the map's entries.

=head2 to_string

    my $str = $map->to_string();
    say $map;  # Automatically stringifies

Returns a string representation of the Map. Also used for string overloading.
Entries are sorted by key for consistent output.

B<Example:>

    my $map = Map->of(z => 3, a => 1, m => 2);
    say $map;  # Map{a=>1, m=>2, z=>3} (sorted by key)

=head1 EXAMPLES

=head2 Basic Map Operations

    my $map = Map->of(
        name => 'Alice',
        age => 30,
        city => 'Boston'
    );

    say $map->size();  # 3
    say $map->contains_key('name');  # true

    my $name = $map->get('name');
    say $name->get();  # Alice

    my $updated = $map->put(state => 'MA');
    my $removed = $map->remove('age');

=head2 Transforming Maps

    my $prices = Map->of(
        apple => 1.50,
        banana => 0.75,
        orange => 2.00
    );

    # Double all prices
    my $doubled = $prices->map(BiFunction->new(f => sub ($k, $v) { $v * 2 }));
    say $doubled;  # Map{apple=>3.00, banana=>1.50, orange=>4.00}

    # Filter expensive items
    my $expensive = $prices->grep(BiPredicate->new(f => sub ($k, $v) { $v >= 1.50 }));
    say $expensive;  # Map{apple=>1.50, orange=>2.00}

=head2 Working with Keys and Values

    my $map = Map->of(x => 10, y => 20, z => 30);

    # Get all keys as a Set
    my $keys = $map->keys();
    say $keys;  # Set{x, y, z}

    # Get all values as a List
    my $values = $map->values();
    # List[10, 20, 30] (order unspecified)

    # Process entries
    my $entries = $map->entries();
    $entries->foreach(Consumer->new(f => sub ($pair) {
        my ($k, $v) = @$pair;
        say "$k => $v";
    }));

=head2 Reducing a Map

    my $inventory = Map->of(
        apples => 50,
        bananas => 30,
        oranges => 20
    );

    # Count total items
    my $total = $inventory->reduce(0, sub ($acc, $k, $v) { $acc + $v });
    say $total;  # 100

    # Build a string
    my $summary = $inventory->reduce('', sub ($acc, $k, $v) {
        $acc . ($acc ? ', ' : '') . "$k: $v"
    });
    say $summary;  # "apples: 50, bananas: 30, oranges: 20"

=head2 Chaining Operations

    my $result = Map->of(a => 1, b => 2, c => 3, d => 4)
        ->map(BiFunction->new(f => sub ($k, $v) { $v * 10 }))
        ->grep(BiPredicate->new(f => sub ($k, $v) { $v > 20 }))
        ->put(e => 50);

    say $result;  # Map{c=>30, d=>40, e=>50}

=head2 Stream Integration

    my $map = Map->of(x => 10, y => 20, z => 30);

    # Convert to stream and process
    my $result = $map->to_stream()
        ->map(Function->new(f => sub ($pair) {
            my ($k, $v) = @$pair;
            return "$k=$v";
        }))
        ->collect(ToList->new());

    say $result;  # List["x=10", "y=20", "z=30"]

=head1 IMPORTANT NOTES

=over 4

=item *

B<Unordered> - Maps do not maintain insertion order. Use List of pairs if order matters.

=item *

B<String keys> - Keys are stored using string representation as hash keys.
This works well for scalars but may have unexpected behavior for references.

=item *

B<Arbitrary iteration order> - foreach, find, values(), entries(), and to_stream()
produce elements in arbitrary (hash) order. Only to_string sorts by key for
consistent display.

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

L<Set> - Unordered unique elements

=item *

L<Stream> - Lazy stream processing

=item *

L<BiFunction> - Two-argument function for transforming map values

=item *

L<BiPredicate> - Two-argument predicate for filtering map entries

=item *

L<BiConsumer> - Two-argument consumer for processing map entries

=back

=head1 AUTHOR

grey::static

=cut

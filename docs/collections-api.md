# Collections API Design

## Overview

Collections wrap builtin Perl arrays and hashes with functional operations and Stream integration.

## Coding Standards (IMPORTANT)

**Perl 5.42+ Modern Practices:**

1. ALWAYS use signatures in subs - NEVER use @_
   ```perl
   # GOOD
   sub of ($class, @values) { ... }

   # BAD
   sub of { my ($class, @values) = @_; ... }
   ```

2. DO NOT include trailing `1;` in modules - not needed in 5.42
   ```perl
   # GOOD
   class Foo { ... }
   # End of file - no 1;

   # BAD
   class Foo { ... }
   1;
   ```

3. USE builtin functions where applicable
   ```perl
   use builtin qw[ true false blessed reftype indexed ];
   ```

4. PREFER core map/grep and keyword any/all over foreach loops
   ```perl
   # GOOD - use experimental pragma for keyword_any and keyword_all
   use experimental qw[ class keyword_any keyword_all ];
   return any { $predicate->test($_) } @$items;
   return all { $predicate->test($_) } @$items;

   # BAD
   for my $item (@$items) {
       return 1 if $predicate->test($item);
   }
   return 0;
   ```

## Design Principles

- Use `field $items :param` for scalar fields with :param attribute
- Copy refs on construction to ensure ownership
- All collections have `to_string()` and `""` overload
- Provide method equivalents for Perl builtins
- Provide method equivalents for Stream operations where sensible
- Provide `to_stream()` for Stream integration
- Single-word method names preferred
- Immutable by default (return new instances)
- Use `new()` for standard field-based construction (cannot override in Perl 5.42)
- Use `of()` and `empty()` as convenience constructors

## Classes

### List

Ordered collection of elements (wraps array).

Construction:
- `List->new(items => \@array)` - standard constructor with fields
- `List->of(@values)` - from values
- `List->empty()` - empty list

Core operations:
- `size()` - number of elements
- `is_empty()` - true if empty
- `at($index)` - element at index
- `first()` - first element
- `last()` - last element
- `slice($start, $end)` - sublist
- `push(@values)` - append elements (returns new List)
- `pop()` - remove last element (returns new List)
- `shift()` - remove first element (returns new List)
- `unshift(@values)` - prepend elements (returns new List)
- `reverse()` - reversed list
- `sort($comparator)` - sorted list

Functional operations:
- `map($function)` - transform elements, returns new List
- `grep($predicate)` - filter elements, returns new List
- `reduce($initial, $bifunction)` - fold to single value
- `foreach($consumer)` - iterate with side effects (for side effects only)
- `find($predicate)` - first matching element (returns Option)
- `contains($value)` - true if contains value
- `any($predicate)` - true if any match
- `all($predicate)` - true if all match
- `none($predicate)` - true if none match

Note: All operations take Function/Predicate/Consumer objects compatible with Stream API. Complex operations like flatmap, flatten, take are only available via `to_stream()`.

Conversion:
- `to_stream()` - convert to Stream
- `to_array()` - get arrayref
- `to_list()` - get list of values
- `to_string()` - string representation

### Stack

LIFO (Last-In-First-Out) collection (wraps array).

Construction:
- `Stack->new(items => \@array)` - standard constructor with fields
- `Stack->of(@values)` - from values
- `Stack->empty()` - empty stack

Core operations:
- `size()` - number of elements
- `is_empty()` - true if empty
- `push(@values)` - push elements (returns new Stack)
- `pop()` - pop top element (returns [$value, $new_stack])
- `peek()` - view top element without removing (Option)

Functional operations:
- `map($function)` - transform elements, returns new Stack
- `grep($predicate)` - filter elements, returns new Stack
- `foreach($consumer)` - iterate with side effects
- `find($predicate)` - first matching element (Option)
- `contains($value)` - true if contains value

Note: All operations take Function/Predicate/Consumer objects. Complex stream operations available via `to_stream()`.

Conversion:
- `to_stream()` - convert to Stream
- `to_array()` - get arrayref
- `to_list()` - get list of values (top to bottom)
- `to_string()` - string representation

### Queue

FIFO (First-In-First-Out) collection (wraps array).

Construction:
- `Queue->new(items => \@array)` - standard constructor with fields
- `Queue->of(@values)` - from values
- `Queue->empty()` - empty queue

Core operations:
- `size()` - number of elements
- `is_empty()` - true if empty
- `enqueue(@values)` - add elements to back (returns new Queue)
- `dequeue()` - remove from front (returns [$value, $new_queue])
- `peek()` - view front element without removing (Option)

Functional operations:
- `map($function)` - transform elements, returns new Queue
- `grep($predicate)` - filter elements, returns new Queue
- `foreach($consumer)` - iterate with side effects
- `find($predicate)` - first matching element (Option)
- `contains($value)` - true if contains value

Note: All operations take Function/Predicate/Consumer objects. Complex stream operations available via `to_stream()`.

Conversion:
- `to_stream()` - convert to Stream
- `to_array()` - get arrayref
- `to_list()` - get list of values (front to back)
- `to_string()` - string representation

### Set

Unordered collection of unique elements (wraps hash).

Construction:
- `Set->new(items => \@array)` - standard constructor with fields (creates set from array)
- `Set->of(@values)` - from values
- `Set->empty()` - empty set

Core operations:
- `size()` - number of elements
- `is_empty()` - true if empty
- `contains($value)` - true if contains value
- `add(@values)` - add elements (returns new Set)
- `remove(@values)` - remove elements (returns new Set)
- `union($other_set)` - union of two sets
- `intersection($other_set)` - intersection of two sets
- `difference($other_set)` - difference of two sets
- `is_subset($other_set)` - true if subset
- `is_superset($other_set)` - true if superset

Functional operations:
- `map($function)` - transform elements, returns new Set
- `grep($predicate)` - filter elements, returns new Set
- `foreach($consumer)` - iterate with side effects
- `find($predicate)` - arbitrary matching element (Option)
- `any($predicate)` - true if any match
- `all($predicate)` - true if all match
- `none($predicate)` - true if none match

Note: All operations take Function/Predicate/Consumer objects. Complex stream operations available via `to_stream()`.

Conversion:
- `to_stream()` - convert to Stream
- `to_array()` - get arrayref (arbitrary order)
- `to_list()` - get list of values (arbitrary order)
- `to_string()` - string representation

### Map

Key-value collection (wraps hash).

Construction:
- `Map->new(entries => \%hash)` - standard constructor with fields
- `Map->of(@pairs)` - from key-value pairs (flat list: k1, v1, k2, v2, ...)
- `Map->empty()` - empty map

Core operations:
- `size()` - number of entries
- `is_empty()` - true if empty
- `get($key)` - value for key (Option)
- `contains_key($key)` - true if key exists
- `contains_value($value)` - true if value exists
- `put($key, $value)` - add entry (returns new Map)
- `remove(@keys)` - remove entries (returns new Map)
- `keys()` - Set of keys
- `values()` - List of values
- `entries()` - List of [$key, $value] pairs

Functional operations:
- `map($bifunction)` - transform values, returns new Map
- `map_keys($function)` - transform keys, returns new Map
- `map_entries($bifunction)` - transform key-value pairs, returns new Map
- `grep($bipredicate)` - filter entries, returns new Map
- `foreach($biconsumer)` - iterate with side effects
- `find($bipredicate)` - first matching entry (Option of [$key, $value])
- `reduce($initial, $trifunction)` - fold over entries to single value

Note: All operations take Function/BiFunction/Predicate objects. Complex stream operations available via `to_stream()`.

Conversion:
- `to_stream()` - convert entries to Stream (of [$key, $value] pairs)
- `to_hash()` - get hashref
- `to_string()` - string representation

## Alignment with datatypes::numeric

The numeric types (Tensor, Scalar, Vector, Matrix) already align well with collection patterns:

Existing alignment:
- Constructor patterns: field-based `new()` with validation in ADJUST
- `to_string()` and `""` overload
- `at()` for indexed access (Vector, Matrix)
- Functional methods: operations return new instances
- Validation in ADJUST blocks

Collections follow the same patterns for consistency.

## Stream Integration

All collections provide `to_stream()` which creates a Stream from the collection's elements.

### API Compatibility

Collection methods and Stream operations use compatible parameter types:
- Both accept Function, Predicate, Consumer, BiFunction, etc.
- Collection methods return collection instances (List returns List, Set returns Set)
- Stream operations return Stream instances (until terminal operation)

This means you CANNOT insert `to_stream()` mid-chain:
```perl
# This WORKS - collection methods throughout:
my $result = $list->map($f)->grep($p)->first();

# This WORKS - stream operations throughout:
my $result = $list->to_stream()->map($f)->grep($p)->collect(ToList->new());

# This BREAKS - cannot mix collection and stream chains:
my $result = $list->map($f)->to_stream()->grep($p); # ERROR: List has no to_stream() method on result
```

### When to Use Collections vs Streams

Use collection methods for:
- Simple transformations (one or two operations)
- When you want the result in the same collection type
- When performance isn't critical

Use streams for:
- Complex pipelines (three or more operations)
- Operations not available on collections (flatmap, flatten, take, gather, etc.)
- When you need lazy evaluation
- When working with large datasets

Example - simple operation stays on collection:
```perl
my $doubled = $list->map(Function->new(f => sub { $_[0] * 2 }));
```

Example - complex operation uses stream:
```perl
my $result = $list->to_stream()
                  ->flatmap(Function->new(f => sub { ... }))
                  ->take(10)
                  ->grep(Predicate->new(p => sub { $_[0] > 5 }))
                  ->collect(ToList->new());
```

## Design Decisions

1. Collections are immutable (always return new instances) - matches functional style

2. No mutable variants initially - can add later if needed

3. Start with five basic collections - add specialized ones based on need

4. Set and Map do not maintain insertion order - use List if order matters

5. Set/Map use string representation as key for non-scalar values


use v5.42;
use utf8;
use experimental qw[ class keyword_any keyword_all ];
use grey::static::error;

class Queue {
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

    method enqueue (@values) {
        return Queue->new(items => [@$items, @values]);
    }

    method dequeue () {
        Error->throw("Cannot dequeue from empty queue")
            if $self->is_empty();
        my @new_items = @$items[1 .. $#$items];
        return [$items->[0], Queue->new(items => \@new_items)];
    }

    method peek () {
        return Option->new() if $self->is_empty();
        return Option->new(some => $items->[0]);
    }

    # --------------------------------------------------------------------------
    # Functional operations
    # --------------------------------------------------------------------------

    method map ($function) {
        Error->throw("map requires a Function") unless defined $function;
        return Queue->new(items => [ map { $function->apply($_) } @$items ]);
    }

    method grep ($predicate) {
        Error->throw("grep requires a Predicate") unless defined $predicate;
        return Queue->new(items => [ grep { $predicate->test($_) } @$items ]);
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
        return "Queue[$contents]";
    }
}

__END__

=encoding UTF-8

=head1 NAME

Queue - Immutable FIFO (First-In-First-Out) collection

=head1 SYNOPSIS

    use grey::static qw[ functional datatypes::collections ];

    # Create queues
    my $queue = Queue->of(1, 2, 3);
    my $empty = Queue->empty();
    my $queue2 = Queue->new(items => [10, 20, 30]);

    # Basic operations
    say $queue->size();         # 3
    say $queue->is_empty();     # false

    # Enqueue elements (add to back)
    my $enqueued = $queue->enqueue(4, 5);
    say $enqueued;  # Queue[1, 2, 3, 4, 5]

    # Dequeue element (remove from front)
    my ($value, $new_queue) = $queue->dequeue()->@*;
    say $value;       # 1
    say $new_queue;   # Queue[2, 3]

    # Peek at front without removing
    my $front = $queue->peek();
    say $front->get() if $front->is_some();  # 1

    # Functional operations
    my $doubled = $queue->map(Function->new(f => sub ($x) { $x * 2 }));
    my $evens = $queue->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));

    # Conversion
    my $stream = $queue->to_stream();
    my $arrayref = $queue->to_array();

=head1 DESCRIPTION

C<Queue> is an immutable FIFO (First-In-First-Out) collection that wraps a Perl
arrayref. All operations return new Queue instances, preserving immutability.

In a queue, elements are added at the back and removed from the front (like a
line at a store - first person in line is first served).

Key features:

=over 4

=item *

B<Immutable> - All operations return new Queue instances

=item *

B<FIFO semantics> - First In, First Out

=item *

B<Functional operations> - map, grep, foreach, find

=item *

B<Stream integration> - Convert to Stream for complex pipelines

=item *

B<Type-safe> - All functional operations require proper Function/Predicate objects

=back

=head1 CONSTRUCTORS

=head2 new

    my $queue = Queue->new(items => \@array);

Standard constructor that takes a hashref with an C<items> field.

B<Parameters:>

=over 4

=item C<items> (required)

An arrayref of elements. A defensive copy is made to ensure ownership.
Elements are stored in the order provided, with the first element at the front.

=back

B<Dies> if C<items> is not an arrayref.

=head2 of

    my $queue = Queue->of(@values);

Convenience constructor that creates a Queue from values. The first value becomes
the front of the queue.

B<Example:>

    my $queue = Queue->of(1, 2, 3);
    say $queue->peek()->get();  # 1 (front of queue)

=head2 empty

    my $queue = Queue->empty();

Creates an empty Queue.

=head1 CORE OPERATIONS

=head2 size

    my $n = $queue->size();

Returns the number of elements in the queue.

=head2 is_empty

    my $empty = $queue->is_empty();

Returns true if the queue contains no elements.

=head2 enqueue

    my $new_queue = $queue->enqueue(@values);

Returns a new Queue with the given values added to the back. Multiple values
are enqueued in order.

B<Example:>

    my $queue = Queue->of(1, 2);
    my $enqueued = $queue->enqueue(3, 4);
    say $enqueued;  # Queue[1, 2, 3, 4]

=head2 dequeue

    my ($value, $new_queue) = $queue->dequeue()->@*;

Removes and returns the front element along with a new Queue without that element.

Returns an arrayref containing:

=over 4

=item C<$value>

The front element that was removed.

=item C<$new_queue>

A new Queue instance without the dequeued element.

=back

B<Dies> if the queue is empty.

B<Example:>

    my $queue = Queue->of(1, 2, 3);
    my ($front, $rest) = $queue->dequeue()->@*;
    say $front;  # 1
    say $rest;   # Queue[2, 3]

=head2 peek

    my $option = $queue->peek();

Returns an Option containing the front element without removing it.

B<Returns:> Option::Some containing the front element if the queue is not empty,
Option::None if empty.

B<Example:>

    my $queue = Queue->of(1, 2, 3);
    my $front = $queue->peek();
    if ($front->is_some()) {
        say $front->get();  # 1
    }

    my $empty = Queue->empty();
    say $empty->peek()->is_none();  # true

=head1 FUNCTIONAL OPERATIONS

All functional operations require proper Function/Predicate/Consumer objects.
Operations return new Queue instances (except foreach which returns nothing).

=head2 map

    my $new_queue = $queue->map($function);

Transforms each element using the given Function, returning a new Queue.

B<Dies> if C<$function> is not provided.

B<Example:>

    my $queue = Queue->of(1, 2, 3);
    my $doubled = $queue->map(Function->new(f => sub ($x) { $x * 2 }));
    say $doubled;  # Queue[2, 4, 6]

=head2 grep

    my $filtered = $queue->grep($predicate);

Filters elements based on the given Predicate, returning a new Queue.

B<Dies> if C<$predicate> is not provided.

B<Example:>

    my $queue = Queue->of(1, 2, 3, 4, 5);
    my $evens = $queue->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));
    say $evens;  # Queue[2, 4]

=head2 foreach

    $queue->foreach($consumer);

Applies the Consumer to each element for side effects. Returns nothing.

B<Dies> if C<$consumer> is not provided.

B<Example:>

    my $queue = Queue->of(1, 2, 3);
    $queue->foreach(Consumer->new(f => sub ($x) { say $x }));
    # Prints: 1, 2, 3 (front to back)

=head2 find

    my $option = $queue->find($predicate);

Returns an Option containing the first element (from front) matching the Predicate.

B<Dies> if C<$predicate> is not provided.

B<Returns:> An Option::Some containing the matching element, or Option::None.

=head2 contains

    my $bool = $queue->contains($value);

Returns true if the queue contains the given value (using string equality).

=head1 CONVERSION

=head2 to_stream

    my $stream = $queue->to_stream();

Converts the Queue to a Stream for complex pipeline operations. Elements are
streamed from front to back.

=head2 to_array

    my $arrayref = $queue->to_array();

Returns an arrayref containing the queue's elements (front to back).

=head2 to_list

    my @values = $queue->to_list();

Returns a Perl list of the elements (front to back).

=head2 to_string

    my $str = $queue->to_string();
    say $queue;  # Automatically stringifies

Returns a string representation of the Queue. Also used for string overloading.

B<Example:>

    my $queue = Queue->of(1, 2, 3);
    say $queue;  # Queue[1, 2, 3]

=head1 EXAMPLES

=head2 Basic Queue Operations

    my $queue = Queue->empty();

    # Build up the queue
    $queue = $queue->enqueue(1);
    $queue = $queue->enqueue(2);
    $queue = $queue->enqueue(3);
    say $queue;  # Queue[1, 2, 3]

    # Dequeue elements
    my ($val1, $queue2) = $queue->dequeue()->@*;
    say $val1;    # 1
    my ($val2, $queue3) = $queue2->dequeue()->@*;
    say $val2;    # 2
    my ($val3, $queue4) = $queue3->dequeue()->@*;
    say $val3;    # 3
    say $queue4->is_empty();  # true

=head2 Using peek

    my $queue = Queue->of(10, 20, 30);

    # Check front without removing
    my $front = $queue->peek();
    say $front->get() if $front->is_some();  # 10

    # Queue unchanged
    say $queue->size();  # 3

=head2 Functional Operations

    my $queue = Queue->of(1, 2, 3, 4, 5);

    # Transform
    my $doubled = $queue->map(Function->new(f => sub ($x) { $x * 2 }));
    say $doubled;  # Queue[2, 4, 6, 8, 10]

    # Filter
    my $evens = $queue->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));
    say $evens;  # Queue[2, 4]

    # Find
    my $found = $queue->find(Predicate->new(f => sub ($x) { $x > 3 }));
    say $found->get() if $found->is_some();  # 4

=head2 Processing Queue Elements

    my $queue = Queue->of('apple', 'banana', 'cherry');

    # Process all elements
    $queue->foreach(Consumer->new(f => sub ($item) {
        say "Item: $item";
    }));
    # Prints:
    # Item: apple
    # Item: banana
    # Item: cherry

=head2 Chaining Operations

    my $result = Queue->of(1, 2, 3, 4, 5)
        ->enqueue(6, 7, 8)
        ->map(Function->new(f => sub ($x) { $x * 2 }))
        ->grep(Predicate->new(f => sub ($x) { $x < 10 }))
        ->peek();

    say $result->get() if $result->is_some();  # 2

=head1 QUEUE vs STACK

Use Queue when:

=over 4

=item *

You need FIFO semantics

=item *

You're implementing algorithms that need fair ordering

=item *

You need to process items in arrival order

=back

Use Stack when:

=over 4

=item *

You need LIFO semantics

=item *

You're implementing algorithms that use stack data structure

=item *

You need to process most recent items first

=back

=head1 SEE ALSO

=over 4

=item *

L<List> - Ordered collection with indexed access

=item *

L<Stack> - LIFO collection

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

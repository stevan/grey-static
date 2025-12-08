use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::stream;

our $VERSION = '0.01';

use File::Basename ();
use lib File::Basename::dirname(__FILE__) . '/stream';

load_module('Stream');

sub import { }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

grey::static::stream - Lazy stream processing API

=head1 SYNOPSIS

    use grey::static qw[ functional stream ];

    # Create streams from various sources
    my @results = Stream
        ->of(1, 2, 3, 4, 5)
        ->map(sub ($x) { $x * 2 })
        ->grep(sub ($x) { $x > 5 })
        ->collect(Stream::Collectors->ToList);
    # [6, 8, 10]

    # Infinite streams
    Stream->iterate(1, sub ($x) { $x + 1 })
        ->take(5)
        ->foreach(sub ($x) { say $x });
    # Prints 1, 2, 3, 4, 5

    # Stream from range
    my $sum = Stream
        ->range(1, 100)
        ->reduce(0, sub ($acc, $x) { $acc + $x });

    # Pattern matching
    use Stream::Match;

    my $result = Stream->of(1, 2, 3, 4, 5)
        ->match(Stream::Match->build
            ->when(sub ($x) { $x % 2 == 0 }, sub { "even" })
            ->when(sub ($x) { $x % 2 != 0 }, sub { "odd" })
        )
        ->collect(Stream::Collectors->ToList);

=head1 DESCRIPTION

The C<stream> feature provides a lazy, functional stream processing API inspired
by Java's Stream API. Streams represent sequences of elements supporting
sequential operations in a pipeline pattern.

Key characteristics:

=over 4

=item *

B<Lazy evaluation> - Elements are produced and processed on demand

=item *

B<Fluent API> - Operations chain together for readable pipelines

=item *

B<Functional> - Operations use Function, Predicate, and Consumer primitives

=item *

B<Terminal operations> - Trigger computation and produce results

=back

=head1 STREAM LIFECYCLE

A stream pipeline consists of:

=over 4

=item 1. B<Source> - Where elements come from (array, range, generator, etc.)

=item 2. B<Intermediate operations> - Transform, filter, or manipulate elements (lazy)

=item 3. B<Terminal operation> - Triggers computation and produces a result

=back

Example:

    Stream->of(1, 2, 3)      # Source
        ->map(sub { ... })   # Intermediate
        ->grep(sub { ... })  # Intermediate
        ->collect(...)       # Terminal

=head1 STREAM CLASS

=head2 Stream Constructors

=over 4

=item C<< Stream->of(@elements) >>

=item C<< Stream->of(\@array) >>

Creates a finite stream from a list or arrayref.

    my $stream = Stream->of(1, 2, 3, 4, 5);

=item C<< Stream->range($start, $end) >>

=item C<< Stream->range($start, $end, $step) >>

Creates a stream from a numeric range (inclusive).

    my $stream = Stream->range(1, 10);        # 1..10
    my $stream = Stream->range(0, 100, 10);   # 0, 10, 20, ..., 100

=item C<< Stream->iterate($seed, $next) >>

Creates an infinite stream by repeatedly applying C<$next> to generate values.

    my $stream = Stream->iterate(1, sub ($x) { $x * 2 });  # 1, 2, 4, 8, ...

=item C<< Stream->iterate($seed, $hasNext, $next) >>

Creates a finite stream that continues while C<$hasNext> is true.

    my $stream = Stream->iterate(
        1,
        sub ($x) { $x <= 100 },
        sub ($x) { $x * 2 }
    );  # 1, 2, 4, 8, 16, 32, 64

=item C<< Stream->generate($supplier) >>

Creates an infinite stream from a supplier function.

    my $stream = Stream->generate(sub { rand(100) });

=item C<< Stream->concat(@streams) >>

Concatenates multiple streams into one.

    my $stream = Stream->concat(
        Stream->of(1, 2, 3),
        Stream->of(4, 5, 6)
    );  # 1, 2, 3, 4, 5, 6

=item C<< Stream->new(source => $source) >>

Creates a stream from a custom source. The source must implement the
C<Stream::Source> interface.

=back

=head2 Intermediate Operations

Intermediate operations are lazy - they return a new stream without processing
elements until a terminal operation is called.

=over 4

=item C<< map($f) >>

Transforms each element using the function C<$f>.

    ->map(sub ($x) { $x * 2 })

=item C<< grep($f) >>

Filters elements using the predicate C<$f>.

    ->grep(sub ($x) { $x > 10 })

=item C<< flat_map($f) >>

Maps each element to a stream and flattens the results.

    ->flat_map(sub ($x) { Stream->of($x, $x * 2) })

=item C<< flatten($f) >>

Flattens nested structures using function C<$f>.

    ->flatten(sub ($arr) { @$arr })

=item C<< take($n) >>

Takes only the first C<$n> elements.

    ->take(10)

=item C<< take_until($predicate) >>

Takes elements until C<$predicate> returns true.

    ->take_until(sub ($x) { $x > 100 })

=item C<< peek($f) >>

Performs a side effect without modifying the stream.

    ->peek(sub ($x) { say "Processing: $x" })

=item C<< when($predicate, $consumer) >>

Performs C<$consumer> on elements matching C<$predicate>.

    ->when(sub ($x) { $x % 10 == 0 }, sub ($x) { say "Milestone: $x" })

=item C<< every($n, $consumer) >>

Performs C<$consumer> every C<$n> elements.

    ->every(100, sub ($x) { say "Processed $x so far" })

=item C<< buffered($size) >>

Buffers elements in chunks of C<$size>.

    ->buffered(10)

=item C<< recurse($canRecurse, $recurse) >>

Recursively expands elements. If C<$canRecurse> returns true for an element,
applies C<$recurse> to generate child elements.

    ->recurse(
        sub ($dir) { $dir->is_dir },
        sub ($dir) { IO::Stream::Directories->files($dir)->source }
    )

=item C<< gather($init, $reduce, $finish) >>

Accumulates elements into groups using stateful accumulation.

=back

=head2 Terminal Operations

Terminal operations trigger stream processing and produce a result.

=over 4

=item C<< collect($collector) >>

Collects elements using a C<Stream::Collector>.

    ->collect(Stream::Collectors->ToList)
    ->collect(Stream::Collectors->ToHash)

=item C<< reduce($initial, $reducer) >>

Reduces elements to a single value using C<$reducer> bifunction.

    ->reduce(0, sub ($acc, $x) { $acc + $x })

=item C<< foreach($consumer) >>

Performs C<$consumer> on each element, returns nothing.

    ->foreach(sub ($x) { say $x })

=item C<< match($matcher) >>

Applies pattern matching using a C<Stream::Match> matcher.

    ->match(Stream::Match->build->when(...)->otherwise(...))

=back

=head2 Lifecycle Hooks

=over 4

=item C<< on_open($consumer) >>

Registers a callback to run when the stream starts processing.

=item C<< on_close($consumer) >>

Registers a callback to run when the stream finishes processing.

=back

=head1 COLLECTORS

C<Stream::Collectors> provides common collection strategies:

=over 4

=item C<< Stream::Collectors->ToList >>

Collects elements into an arrayref.

=item C<< Stream::Collectors->ToHash >>

Collects key-value pairs into a hashref.

=back

=head1 PATTERN MATCHING

C<Stream::Match> provides pattern matching on stream elements:

    use Stream::Match;

    my $matcher = Stream::Match->build
        ->when($predicate1, $handler1)
        ->when($predicate2, $handler2)
        ->otherwise($default_handler);

    $stream->match($matcher);

=head1 SOURCES

Streams can be created from various sources in the C<Stream::Source> namespace:

=over 4

=item C<Stream::Source::FromArray> - From an array

=item C<Stream::Source::FromRange> - From a numeric range

=item C<Stream::Source::FromIterator> - From an iterator

=item C<Stream::Source::FromSupplier> - From a supplier function

=item C<Stream::Source::FromArray::OfStreams> - Concatenation of streams

=back

=head1 OPERATIONS

Stream operations are implemented in the C<Stream::Operation> namespace:

=over 4

=item C<Stream::Operation::Map> - Element transformation

=item C<Stream::Operation::Grep> - Element filtering

=item C<Stream::Operation::FlatMap> - Map and flatten

=item C<Stream::Operation::Take> - Limit elements

=item C<Stream::Operation::Reduce> - Fold to single value

=item C<Stream::Operation::ForEach> - Side effects

=item C<Stream::Operation::Collect> - Accumulation

=back

And many more specialized operations.

=head1 DEPENDENCIES

Requires the C<functional> feature for C<Function>, C<Predicate>, C<Consumer>,
C<BiFunction>, and C<Supplier> classes.

=head1 SEE ALSO

L<grey::static>, L<grey::static::functional>, L<grey::static::io>

=head1 AUTHOR

grey::static

=cut

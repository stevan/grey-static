use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static;

our $VERSION = '0.01';

# Load core utilities
load_module('importer');

sub import {
    my ($class, @features) = @_;
    my ($caller_package, $caller_file) = caller;

    # Always load and initialize source caching
    load_module('grey::static::source');
    grey::static::source->cache_file($caller_file);

    # Load each requested feature
    for my $feature (@features) {
        # Check if this is a sub-feature (contains ::)
        if ($feature =~ /^([^:]+)::(.+)$/) {
            my $base_feature = $1;
            my $subfeature = $2;

            # Load the base feature module
            my $module = "grey::static::${base_feature}";
            load_module($module);

            # Call its import with the subfeature
            $module->import($subfeature);
        }
        else {
            # Simple feature without sub-features
            my $module = "grey::static::${feature}";
            load_module($module);
            $module->import();
        }
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

grey::static - Opinionated Perl module loader with curated features

=head1 SYNOPSIS

    use grey::static qw[ diagnostics functional stream ];

    # Enhanced error messages with source context and stack traces
    die "Something went wrong";

    # Functional programming primitives
    my $double = Function->new(f => sub ($x) { $x * 2 });
    say $double->apply(5);  # 10

    # Lazy stream processing
    my @results = Stream->of(1, 2, 3, 4, 5)
        ->map(sub ($x) { $x * 2 })
        ->grep(sub ($x) { $x > 5 })
        ->collect(Stream::Collectors->ToList);

    # All features together
    use grey::static qw[
        diagnostics
        functional
        logging
        stream
        io::stream
        concurrency
        datatypes::ml
        datatypes::util
    ];

=head1 DESCRIPTION

C<grey::static> is an opinionated Perl module loader that provides curated
"features" for modern Perl development. Features are loaded via the import
list, and their classes become globally available without further imports.

The module automatically manages source file caching through C<grey::static::source>
and loads requested features on demand. Features may be simple (single-level)
or hierarchical (using C<::> notation for sub-features).

=head2 Design Philosophy

=over 4

=item *

B<Curated features> - Carefully selected functionality for common tasks

=item *

B<Explicit loading> - Features are opt-in via import list

=item *

B<Global classes> - No need for additional imports once a feature is loaded

=item *

B<Source caching> - Automatic caching of caller's source for diagnostics

=back

=head1 REQUIREMENTS

=over 4

=item *

Perl v5.42+ (uses the C<class> feature from C<experimental>)

=item *

L<Path::Tiny> (required for C<io::stream> feature)

=back

=head1 FEATURES

grey::static provides the following features:

=head2 diagnostics

B<Load with:> C<use grey::static qw[ diagnostics ];>

Enhanced error and warning diagnostics with Rust-style error messages.

B<Provides:>

=over 4

=item *

Source code context around error locations

=item *

Syntax-highlighted source code display

=item *

Stack backtraces with function arguments

=item *

Colorized output with Unicode box-drawing characters

=back

B<Classes:>

=over 4

=item *

C<grey::static::diagnostics::StackFrame> - Represents a call stack frame

=item *

C<grey::static::diagnostics::Formatter> - Formats errors/warnings with context

=back

B<Configuration:>

    $grey::static::diagnostics::NO_COLOR = 1;
    $grey::static::diagnostics::NO_BACKTRACE = 1;
    $grey::static::diagnostics::NO_SYNTAX_HIGHLIGHT = 1;

B<See also:> L<grey::static::diagnostics>

=head2 functional

B<Load with:> C<use grey::static qw[ functional ];>

Functional programming primitives inspired by Java's functional interfaces.

B<Classes:>

=over 4

=item *

C<Function> - Wraps a unary function with composition support

=item *

C<BiFunction> - Wraps a binary function with currying support

=item *

C<Predicate> - Boolean-valued function with logical combinators

=item *

C<Consumer> - Side-effect operation accepting one argument

=item *

C<BiConsumer> - Side-effect operation accepting two arguments

=item *

C<Supplier> - Value provider taking no arguments

=item *

C<Comparator> - Comparison function with reversal support

=back

B<Example:>

    my $double = Function->new(f => sub ($x) { $x * 2 });
    my $add_one = Function->new(f => sub ($x) { $x + 1 });
    my $composed = $double->and_then($add_one);
    say $composed->apply(5);  # 11

B<See also:> L<grey::static::functional>

=head2 logging

B<Load with:> C<use grey::static qw[ logging ];>

Debug logging utilities with colorized output and automatic depth tracking.

B<Exported functions:>

=over 4

=item *

C<LOG($from, $msg, \%params)> - Log a message with depth tracking

=item *

C<INFO($msg, \%params)> - Log informational message

=item *

C<DIV($label)> - Print visual divider

=item *

C<OPEN($from)> / C<CLOSE($from)> - Lifecycle markers

=item *

C<TICK($from)> - Progress ticks with counter

=item *

C<DEBUG> - Compile-time constant controlled by C<$ENV{DEBUG}>

=back

B<Example:>

    LOG $self, "processing data", { count => 42 };
    INFO "application started";
    DIV "Main Section";

B<See also:> L<grey::static::logging>

=head2 stream

B<Load with:> C<use grey::static qw[ stream ];>

Lazy, functional stream processing API inspired by Java's Stream API.

B<Classes:>

=over 4

=item *

C<Stream> - Main stream class with fluent API

=item *

C<Stream::Collectors> - Collection strategies (ToList, ToHash, etc.)

=item *

C<Stream::Match> - Pattern matching on stream elements

=item *

C<Stream::Source::*> - Various stream sources

=item *

C<Stream::Operation::*> - Stream operation implementations

=back

B<Example:>

    my @results = Stream->of(1, 2, 3, 4, 5)
        ->map(sub ($x) { $x * 2 })
        ->grep(sub ($x) { $x > 5 })
        ->take(3)
        ->collect(Stream::Collectors->ToList);

B<Key characteristics:>

=over 4

=item *

Lazy evaluation - elements produced on demand

=item *

Fluent API - operations chain together

=item *

Functional - uses Function, Predicate, Consumer primitives

=item *

Terminal operations - trigger computation

=back

B<See also:> L<grey::static::stream>

=head2 io::stream

B<Load with:> C<use grey::static qw[ io::stream ];>

Stream-based file and directory operations using Path::Tiny.

B<Classes:>

=over 4

=item *

C<IO::Stream::Files> - Factory for file-based streams

=item *

C<IO::Stream::Directories> - Factory for directory-based streams

=back

B<Example:>

    # Read file as stream of lines
    my @lines = IO::Stream::Files->lines('/path/to/file.txt')
        ->collect(Stream::Collectors->ToList);

    # Stream files from directory
    my @txt_files = IO::Stream::Directories->files('/path/to/dir')
        ->grep(sub ($path) { $path =~ /\.txt$/ })
        ->collect(Stream::Collectors->ToList);

    # Recursively walk directory tree
    my @all_files = IO::Stream::Directories->walk('/path/to/dir')
        ->collect(Stream::Collectors->ToList);

B<Dependencies:> Requires C<stream> feature and L<Path::Tiny>

B<See also:> L<grey::static::io>

=head2 concurrency

B<Load with:> C<use grey::static qw[ concurrency ];>

Reactive flow-based concurrency primitives based on the Reactive Streams
specification.

B<Classes:>

=over 4

=item *

C<Flow> - Fluent builder for reactive pipelines

=item *

C<Flow::Publisher> - Publishes values with backpressure support

=item *

C<Flow::Subscriber> - Consumes values with demand-based flow control

=item *

C<Flow::Subscription> - Manages publisher-subscriber connection

=item *

C<Flow::Executor> - Event loop executor for async tasks

=item *

C<Flow::Operation::*> - Flow operation implementations (Map, Grep)

=back

B<Example:>

    my $publisher = Flow::Publisher->new;

    Flow->from($publisher)
        ->map(sub ($x) { $x * 2 })
        ->grep(sub ($x) { $x > 10 })
        ->to(sub ($x) { say "Result: $x" }, request_size => 5)
        ->build;

    $publisher->submit(10);
    $publisher->start;
    $publisher->close;

B<Key features:>

=over 4

=item *

Backpressure - demand-based flow control

=item *

Async execution - event loop with task scheduling

=item *

Reactive streams - publisher-subscriber pattern

=back

B<Dependencies:> Requires C<functional> feature

B<See also:> L<grey::static::concurrency>

=head2 datatypes::ml

B<Load with:> C<use grey::static qw[ datatypes::ml ];>

Machine learning oriented datatypes for numerical computation.

B<Classes:>

=over 4

=item *

C<Tensor> - N-dimensional array with broadcasting

=item *

C<Scalar> - 0-dimensional tensor (scalar value)

=item *

C<Vector> - 1-dimensional tensor with vector operations

=item *

C<Matrix> - 2-dimensional tensor with matrix operations

=back

B<Example:>

    my $tensor = Tensor->initialize([2, 3], [1, 2, 3, 4, 5, 6]);
    my $vector = Vector->new([1, 2, 3]);
    my $matrix = Matrix->new([[1, 2], [3, 4]]);

    my $result = $matrix * $vector;

B<See also:> L<grey::static::datatypes>

=head2 datatypes::util

B<Load with:> C<use grey::static qw[ datatypes::util ];>

Utility types for safer data handling.

B<Classes:>

=over 4

=item *

C<Option> - Represents an optional value (Some/None)

=item *

C<Result> - Represents success/failure (Ok/Error)

=back

B<Exported functions:>

=over 4

=item *

C<Some($value)> - Create Some variant

=item *

C<None()> - Create None variant

=item *

C<Ok($value)> - Create Ok variant

=item *

C<Error($error)> - Create Error variant

=back

B<Example:>

    my $some = Some(42);
    my $none = None();

    say $some->get;              # 42
    say $none->get_or_else(0);   # 0

    my $ok = Ok(100);
    my $err = Error("failed");

    say $ok->get_or_else(0);     # 100
    say $err->get_or_else(0);    # 0

B<See also:> L<grey::static::datatypes>

=head1 FEATURE ARCHITECTURE

grey::static supports two types of features:

=head2 Simple Features

Single-level features loaded directly:

    use grey::static qw[ functional ];

Implementation: C<lib/grey/static/FEATURE.pm>

The feature module loads its classes and provides an empty C<import()> method.

=head2 Sub-Features

Hierarchical features using C<::> notation:

    use grey::static qw[ io::stream ];

Implementation:

=over 4

=item *

Base loader at C<lib/grey/static/BASE.pm>

=item *

Classes in C<lib/grey/static/BASE/SUBFEATURE/>

=item *

Base loader's C<import()> receives sub-feature name

=back

B<Example base loader:>

    package grey::static::io;

    sub import {
        my ($class, @subfeatures) = @_;
        for my $subfeature (@subfeatures) {
            if ($subfeature eq 'stream') {
                # Load io::stream classes
            }
        }
    }

=head1 SOURCE CACHING

grey::static automatically loads and caches the caller's source file for use
by the diagnostics feature. Source caching is managed by
C<grey::static::source>.

=head1 EXAMPLE USAGE

=head2 Basic Usage

    use grey::static qw[ diagnostics functional ];

    my $double = Function->new(f => sub ($x) { $x * 2 });
    die "Error: " . $double->apply(21);  # Enhanced error display

=head2 Stream Processing

    use grey::static qw[ functional stream ];

    my $sum = Stream->range(1, 100)
        ->grep(sub ($x) { $x % 2 == 0 })
        ->reduce(0, sub ($acc, $x) { $acc + $x });

=head2 File Processing

    use grey::static qw[ functional stream io::stream ];

    IO::Stream::Files->lines('/var/log/app.log')
        ->grep(sub ($line) { $line =~ /ERROR/ })
        ->foreach(sub ($line) { warn $line });

=head2 Reactive Flows

    use grey::static qw[ functional concurrency ];

    my $publisher = Flow::Publisher->new;

    Flow->from($publisher)
        ->map(sub ($x) { process($x) })
        ->to(sub ($result) { say $result })
        ->build;

    $publisher->submit($_) for 1..10;
    $publisher->start;
    $publisher->close;

=head2 Error Handling with Datatypes

    use grey::static qw[ datatypes::util ];

    sub divide ($a, $b) {
        return Error("division by zero") if $b == 0;
        return Ok($a / $b);
    }

    my $result = divide(10, 2);
    say $result->get_or_else(0);  # 5

=head1 SEE ALSO

=over 4

=item *

L<grey::static::diagnostics> - Enhanced error diagnostics

=item *

L<grey::static::functional> - Functional programming primitives

=item *

L<grey::static::logging> - Debug logging utilities

=item *

L<grey::static::stream> - Lazy stream processing

=item *

L<grey::static::io> - IO utilities

=item *

L<grey::static::concurrency> - Reactive concurrency

=item *

L<grey::static::datatypes> - Data type utilities

=item *

L<grey::static::source> - Source file caching

=back

=head1 VERSION

0.01

=head1 AUTHOR

grey::static

=cut

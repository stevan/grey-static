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

    use grey::static qw[ error functional stream ];

    # Structured errors with beautiful formatting
    Error->throw(message => "Something went wrong");

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
        error
        functional
        logging
        stream
        io::stream
        concurrency::reactive
        concurrency::util
        datatypes::ml
        datatypes::util
        tty::ansi
        time::stream
        mop
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

=head2 error

B<Load with:> C<use grey::static qw[ error ];>

Structured error objects with beautiful formatting inspired by Rust's error messages.

B<Provides:>

=over 4

=item *

C<Error> class - Structured errors that stringify beautifully

=item *

Source code context around error locations

=item *

Syntax-highlighted source code display

=item *

Stack backtraces with function arguments

=item *

Colorized output with Unicode box-drawing characters

=back

B<Usage:>

    Error->throw(
        message => "Invalid argument",
        hint => "Expected a positive integer"
    );

B<Configuration:>

    $grey::static::error::NO_COLOR = 1;
    $grey::static::error::NO_BACKTRACE = 1;
    $grey::static::error::NO_SYNTAX_HIGHLIGHT = 1;

B<See also:> L<grey::static::error>

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

=head2 concurrency::reactive

B<Load with:> C<use grey::static qw[ concurrency::reactive ];>

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

B<Key features:> Backpressure, async execution, reactive streams pattern

B<Dependencies:> Requires C<functional> feature

B<See also:> L<grey::static::concurrency>

=head2 concurrency::util

B<Load with:> C<use grey::static qw[ concurrency::util ];>

Concurrency utilities including async primitives.

B<Classes:>

=over 4

=item *

C<Executor> - Event loop executor for callback scheduling

=item *

C<Promise> - Asynchronous promise implementation

=back

B<Example:>

    # Promises
    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    $promise
        ->then(sub ($x) { $x * 2 })
        ->then(sub ($x) { say "Result: $x" });

    $promise->resolve(21);
    $executor->run;  # Prints "Result: 42"

    # Executor
    $executor->next_tick(sub { say "First" });
    $executor->next_tick(sub { say "Second" });
    $executor->run;

B<Key features:> Promise chaining, error propagation, promise flattening, event loop scheduling

B<See also:> L<grey::static::concurrency>, L<Promise>, L<Executor>

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

=head2 tty::ansi

B<Load with:> C<use grey::static qw[ tty::ansi ];>

Terminal (TTY) control using ANSI escape sequences.

B<Provides:>

=over 4

=item *

Terminal size and read mode control via L<Term::ReadKey>

=item *

Screen control (clear, hide/show cursor, alternate buffer)

=item *

Cursor movement and positioning

=item *

RGB color control for foreground and background

=item *

Mouse tracking support

=back

B<Functions:> All functions are exported lexically and return ANSI escape sequences.

Terminal operations: C<get_terminal_size()>, C<set_output_to_utf8($fh)>,
C<set_read_mode_to_raw($fh)>, etc.

Screen control: C<clear_screen()>, C<hide_cursor()>, C<show_cursor()>,
C<enable_alt_buf()>, C<disable_alt_buf()>

Colors: C<format_fg_color($rgb)>, C<format_bg_color($rgb)>, C<format_reset()>

Cursor: C<home_cursor()>, C<format_move_cursor($row, $col)>, C<format_move_up($n)>

Mouse: C<enable_mouse_tracking($type)>, C<disable_mouse_tracking($type)>

B<Example:>

    use grey::static qw[ tty::ansi ];

    print enable_alt_buf();
    print clear_screen();
    print format_move_cursor(5, 10);
    print format_fg_color([255, 0, 0]);
    print "Red text!";
    print format_reset();

B<Dependencies:> Requires L<Term::ReadKey>

B<See also:> L<grey::static::tty>

=head2 time::stream

B<Load with:> C<use grey::static qw[ functional stream time::stream ];>

Time-based stream sources using high-resolution time.

B<Classes:>

=over 4

=item *

C<Time> - Stream class with time-based sources

=back

B<Factory methods:>

=over 4

=item *

C<Time-E<gt>of_epoch()> - Stream of epoch timestamps

=item *

C<Time-E<gt>of_monotonic()> - Stream of monotonic clock values

=item *

C<Time-E<gt>of_delta()> - Stream of time deltas (time between reads)

=back

B<Example:>

    my @times = Time->of_epoch()
        ->take(5)
        ->collect(Stream::Collectors->ToList);

    my @deltas = Time->of_delta()
        ->sleep_for(0.1)
        ->take(5)
        ->collect(Stream::Collectors->ToList);

B<Dependencies:> Requires C<functional>, C<stream> features and L<Time::HiRes>

B<See also:> L<grey::static::time>

=head2 mop

B<Load with:> C<use grey::static qw[ functional stream mop ];>

Meta-Object Protocol utilities for introspecting Perl packages and symbol tables.

B<Classes:>

=over 4

=item *

C<MOP> - Stream class for package introspection

=item *

C<MOP::Glob> - Wrapper around globs with introspection methods

=item *

C<MOP::Symbol> - Represents a symbol (SCALAR, ARRAY, HASH, CODE) from a glob

=back

B<Example:>

    # Get all methods from a package
    my @methods = MOP->namespace('MyClass')
        ->expand_symbols(qw[ CODE ])
        ->map(sub ($s) { $s->glob->name })
        ->collect(Stream::Collectors->ToList);

    # Walk entire package hierarchy
    my @all = MOP->namespace('MyApp')
        ->walk()
        ->expand_symbols()
        ->collect(Stream::Collectors->ToList);

    # Method resolution order
    my @mro = MOP->mro('MyClass')
        ->expand_symbols(qw[ CODE ])
        ->collect(Stream::Collectors->ToList);

B<Dependencies:> Requires C<functional>, C<stream> features and L<B>

B<See also:> L<grey::static::mop>

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
by the error formatting system. Source caching is managed by
C<grey::static::source>.

=head1 EXAMPLE USAGE

=head2 Basic Usage

    use grey::static qw[ error functional ];

    my $double = Function->new(f => sub ($x) { $x * 2 });
    Error->throw(message => "Got: " . $double->apply(21));

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

L<grey::static::error> - Structured error objects with formatting

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

L<grey::static::tty> - Terminal control and ANSI escape sequences

=item *

L<grey::static::time> - Time and timer utilities

=item *

L<grey::static::mop> - Meta-Object Protocol utilities

=item *

L<grey::static::source> - Source file caching

=back

=head1 VERSION

0.01

=head1 AUTHOR

grey::static

=cut

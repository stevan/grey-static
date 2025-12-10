# grey::static

**Opinionated Perl module loader with curated features**

grey::static is a modern Perl module loader that provides carefully curated "features" for contemporary Perl development. Instead of manually importing dozens of modules, load complete feature sets with a single import statement.

## Features

- **error** - Structured error handling with beautiful formatting, source context, and stack traces
- **functional** - Functional programming primitives (Function, Predicate, Consumer, BiFunction, etc.) with input validation
- **stream** - Lazy stream processing API inspired by Java Streams with validated sources
- **io::stream** - File and directory streaming with Path::Tiny integration and automatic handle cleanup
- **concurrency::reactive** - Reactive Flow API with backpressure and async execution
- **concurrency::util** - Promises, ScheduledExecutor (time simulation), and event loop executor
- **datatypes::numeric** - Numeric datatypes (Tensor, Scalar, Vector, Matrix) with broadcasting and bounds checking
- **datatypes::util** - Option (Some/None) and Result (Ok/Error) types
- **tty::ansi** - Terminal control (colors, cursor, screen, mouse)
- **time::stream** - Time-based streams (epoch, monotonic, delta)
- **mop** - Meta-Object Protocol for package introspection
- **logging** - Debug logging with colorization and automatic depth tracking
- **source** - Source file caching with LRU eviction (100 file limit)

## Requirements

- **Perl v5.42+** (uses the `class` feature from experimental)
- **CPAN modules:**
  - Path::Tiny (for io::stream)
  - Time::HiRes (for time::stream)
  - Term::ReadKey (for tty::ansi)
  - B (core module, for mop)

## Installation

### From CPAN (when published)

```bash
cpanm grey::static
```

### From source

```bash
perl Makefile.PL
make
make test
make install
```

## Quick Start

### Structured Error Handling

```perl
use grey::static qw[ error ];

# Throw structured errors with beautiful formatting
Error->throw(
    message => "Invalid user ID: $id",
    hint => "User IDs must be positive integers"
);

# Errors display with source context, syntax highlighting, and stack traces
```

### Functional Programming

```perl
use grey::static qw[ functional ];

# Create reusable functions
my $double = Function->new(f => sub ($x) { $x * 2 });
my $is_even = Predicate->new(f => sub ($x) { $x % 2 == 0 });

say $double->apply(5);      # 10
say $is_even->test(4);      # 1 (true)

# Compose functions
my $quad = $double->and_then($double);
say $quad->apply(3);        # 12

# Chain predicates
my $is_positive = Predicate->new(f => sub ($x) { $x > 0 });
my $is_positive_even = $is_positive->and($is_even);
```

### Stream Processing

```perl
use grey::static qw[ functional stream ];

# Lazy evaluation - only processes what's needed
my @results = Stream->of(1, 2, 3, 4, 5)
    ->map(sub ($x) { $x * 2 })
    ->grep(sub ($x) { $x > 5 })
    ->collect(Stream::Collectors->ToList);
# [6, 8, 10]

# Infinite streams
Stream->iterate(0, sub ($x) { $x + 1 })
    ->grep(sub ($x) { $x % 2 == 0 })
    ->take(5)
    ->collect(Stream::Collectors->ToList);
# [0, 2, 4, 6, 8]

# Time-based operations
use grey::static qw[ stream concurrency::util ];

my $executor = ScheduledExecutor->new;
Stream->of(1, 2, 3, 4, 5)
    ->throttle(10, $executor)    # Rate limit
    ->debounce(5, $executor)     # Coalesce changes
    ->timeout(50, $executor)     # Enforce time limit
    ->collect(Stream::Collectors->ToList);
```

### File I/O

```perl
use grey::static qw[ stream io::stream ];

# Read and process file lines
IO::Stream::Files
    ->lines('access.log')
    ->grep(sub ($line) { $line =~ /ERROR/ })
    ->map(sub ($line) { parse_log($line) })
    ->collect(Stream::Collectors->ToList);

# Walk directory tree recursively
my @all_files = IO::Stream::Directories
    ->walk('/path/to/dir')
    ->grep(sub ($path) { $path->is_file })
    ->collect(Stream::Collectors->ToList);
```

### Reactive Streams

```perl
use grey::static qw[ concurrency::reactive concurrency::util ];

my $executor = Executor->new;

# Create a reactive publisher
my $pub = Flow::Publisher->new(
    executor => $executor,
    generator => sub ($n) { $n * 2 }
);

# Transform with operations
$pub->map(sub ($x) { $x + 1 })
    ->grep(sub ($x) { $x > 5 })
    ->subscribe(
        on_next => sub ($x) { say "Got: $x" },
        on_complete => sub { say "Done!" }
    );

# Drive the event loop
$executor->tick for 1 .. 10;
```

### Promises and Scheduling

```perl
use grey::static qw[ concurrency::util ];

# Basic promises
my $executor = Executor->new;
Promise->resolved($executor, 42)
    ->then(sub ($x) { $x * 2 })
    ->then(sub ($x) { say "Result: $x" })  # Result: 84
    ->catch(sub ($err) { warn "Error: $err" });
$executor->run_until_empty;

# Time-based operations with ScheduledExecutor
my $scheduled = ScheduledExecutor->new;

# Delayed execution
$scheduled->schedule_delayed(sub { say "After 10 ticks" }, 10);
$scheduled->run();

# Promise with timeout
my $promise = Promise->new(executor => $scheduled);
$promise->timeout(50, $scheduled)
    ->then(
        sub ($value) { say "Success: $value" },
        sub ($error) { say "Timeout: $error" }
    );

# Delayed promise
Promise->delay("Hello", 10, $scheduled)
    ->then(sub ($msg) { say $msg });
$scheduled->run();
```

### Numeric Datatypes

```perl
use grey::static qw[ datatypes::numeric ];

# Vectors and matrices with broadcasting
my $v1 = Vector->new([1, 2, 3]);
my $v2 = Vector->new([4, 5, 6]);

my $sum = $v1->add($v2);           # [5, 7, 9]
my $dot = $v1->dot($v2);           # 32

# Matrix operations
my $m = Matrix->new([[1, 2], [3, 4]]);
my $transposed = $m->transpose;    # [[1, 3], [2, 4]]
my $product = $m->matmul($transposed);
```

### Option and Result Types

```perl
use grey::static qw[ datatypes::util ];

# Option type for nullable values
my $some = Option::Some->new(42);
my $none = Option::None->new;

say $some->get;                    # 42
say $none->is_none;                # 1

# Result type for error handling
my $ok = Result::Ok->new("success");
my $err = Result::Error->new("failed");

say $ok->unwrap;                   # "success"
say $err->is_error;                # 1
```

## All Features Together

```perl
use grey::static qw[
    diagnostics
    functional
    stream
    io::stream
    concurrency::reactive
    concurrency::util
    datatypes::numeric
    datatypes::util
    tty::ansi
    time::stream
    mop
    logging
];

# All classes are now globally available
```

## Examples

See the `examples/` directory for complete working examples:

- **examples/logstats/** - Log analysis with streams and time-series processing
- **examples/events/** - Event-driven architecture with reactive flows
- **examples/time/** - Timer wheel and animation examples
- **examples/error-demo.pl** - Diagnostic error display showcase

## Testing

Run the full test suite:

```bash
prove -lr t/
```

Run a specific test:

```bash
prove -lv t/grey/static/02-stream/001-basic.t
```

## Documentation

Each feature has extensive POD documentation:

```bash
perldoc grey::static
perldoc grey::static::diagnostics
perldoc grey::static::functional
perldoc grey::static::stream
perldoc grey::static::concurrency
# ... etc
```

## Design Philosophy

grey::static provides opinionated, curated features that work well together:

- **Modern Perl** - Leverages Perl v5.42's `class` feature
- **Lazy evaluation** - Streams process data on-demand
- **Functional style** - First-class functions, immutability where appropriate
- **Type-inspired** - Borrows concepts from Rust (Option/Result) and Java (Streams, Functional interfaces)
- **Reactive** - Backpressure and async execution for concurrent workflows

## Limitations

- **Not thread-safe** - Designed for single-threaded use only
- **Simulated time** - ScheduledExecutor uses simulated ticks, not real-world time
- **Memory unbounded** - Source file cache and some operations have no built-in size limits

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass: `prove -lr t/`
5. Submit a pull request

## Repository

https://github.com/stevan/grey-static

## Bug Reports

https://github.com/stevan/grey-static/issues

## Author

Stevan Little <stevan@cpan.org>

## License

This is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

See http://dev.perl.org/licenses/ for more information.

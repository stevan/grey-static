# Changelog

All notable changes to grey::static will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.01] - 2025-12-09

### Added

#### Core Infrastructure
- Feature loader with hierarchical sub-feature support (e.g., `io::stream`, `datatypes::ml`)
- Source file caching for enhanced diagnostics
- Lexical module importing utility

#### Features

**diagnostics**
- Rust-style error and warning display with source context
- Syntax highlighting in error messages
- Full stack backtraces with file/line information
- Configurable via package globals (`$NO_COLOR`, `$NO_BACKTRACE`, `$NO_SYNTAX_HIGHLIGHT`)

**functional**
- Function, BiFunction - Function wrappers with composition
- Predicate - Boolean test functions with combinators (and, or, negate)
- Consumer, BiConsumer - Side-effect functions with chaining
- Supplier - Zero-argument value suppliers
- Comparator - Comparison functions with reversal and chaining
- Full combinator support (compose, and_then, curry, etc.)

**stream**
- Lazy stream processing API
- Sources: FromArray, FromRange, FromIterator, FromSupplier, OfStreams
- Operations: map, grep, flatMap, flatten, take, takeUntil, peek, when, every, buffered, gather, reduce, forEach, collect, recurse
- Collectors: ToList, ToHash
- Pattern matching with Match and Match::Builder
- Depth-first tree traversal with `recurse`

**io::stream**
- IO::Stream::Files - Read file lines or bytes as streams
- IO::Stream::Directories - List directory contents, recursive walking
- Integration with Path::Tiny for file system operations

**concurrency::reactive**
- Reactive Streams implementation (Flow API)
- Flow::Publisher - Data source with backpressure
- Flow::Subscriber - Data consumer with lifecycle hooks
- Flow::Subscription - Backpressure token management
- Flow::Executor - Single-threaded event loop
- Operations: map, grep
- Async execution with proper error propagation

**concurrency::util**
- Executor - Event loop with callback scheduling
- Promise - JavaScript-style promises with chaining
- Promise combinators: then, catch, finally
- Promise factories: resolved, rejected
- Automatic promise flattening in chains

**datatypes::ml**
- Tensor - N-dimensional array operations
- Scalar - 0-dimensional tensor
- Vector - 1-dimensional tensor with dot product, norms
- Matrix - 2-dimensional tensor with matmul, transpose
- Broadcasting support for mathematical operations
- Element-wise operations: add, sub, mul, div, pow
- Reductions: sum, mean, min, max, product
- Comparisons: eq, ne, lt, le, gt, ge
- Logical operations: and, or, xor, not

**datatypes::util**
- Option type with Some and None variants
- Result type with Ok and Error variants
- Safe unwrapping with error messages

**tty::ansi**
- ANSI escape sequence generation
- ANSI::Color - RGB colors, palettes, text styling
- ANSI::Cursor - Cursor positioning and movement
- ANSI::Screen - Screen control (clear, scroll, alternate buffer)
- ANSI::Mouse - Mouse tracking modes

**time::stream**
- Time-based stream sources
- Epoch time streams
- Monotonic clock streams
- Delta time streams for frame-rate independent animation

**time::wheel**
- Hierarchical timing wheel implementation
- O(1) timer insertion and removal
- Configurable depth and tick units
- Supports 10^5 time units with default configuration

**mop**
- Meta-Object Protocol for package introspection
- MOP::Glob - Symbol table glob wrapper
- MOP::Symbol - Individual symbol representation
- Package walking with MRO support
- Symbol expansion by slot type
- Stream-based stash traversal

**logging**
- Debug logging with LOG, INFO, DIV, TICK macros
- Automatic depth tracking for nested calls
- Colorized output with context-aware formatting
- OPEN/CLOSE for explicit depth control

### Testing
- 873 tests across 94 test files
- Comprehensive coverage of all features
- Integration tests for feature combinations
- Edge case testing for boundary conditions

### Documentation
- Complete POD documentation for all major modules
- README with quick start examples
- Working examples in examples/ directory:
  - logstats - Log analysis with streams
  - events - Event-driven architecture
  - time - Timer wheel and animations

### Known Limitations
- **Not thread-safe** - All features designed for single-threaded use
- **No cancellation** - Promises cannot be cancelled once started
- **Unbounded caching** - Source file cache has no size limit
- **Memory management** - Some operations do not limit memory usage

### Requirements
- Perl v5.42+ (uses experimental `class` feature)
- Path::Tiny 0.144+ (for io::stream)
- Time::HiRes 1.9764+ (for time::stream)
- Term::ReadKey 2.38+ (for tty::ansi)
- B (core module, for mop)

## [0.00] - Development

Internal development version, not publicly released.

[Unreleased]: https://github.com/stevan/grey-static/compare/v0.01...HEAD
[0.01]: https://github.com/stevan/grey-static/releases/tag/v0.01

# Changelog

All notable changes to grey::static will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **ScheduledExecutor** - Queue-based time simulator for testing async operations
  - `schedule_delayed()` - Schedule callbacks with simulated delays
  - `cancel_scheduled()` - Cancel pending timers
  - `current_time()` - Track simulated time
  - Efficient O(1) next-timer lookup with sorted queue
  - Lazy timer cancellation

- **Stream time operations** - Time-based stream processing with ScheduledExecutor
  - `throttle()` - Rate-limit element emission (minimum delay between elements)
  - `debounce()` - Emit only after quiet period (coalesce rapid changes)
  - `timeout()` - Fail if no element within time limit

- **Promise enhancements**
  - `timeout()` - Add timeout to promises with automatic timer cancellation
  - `delay()` - Factory for delayed promises
  - Recursive promise flattening - Deeply nested promises (3+ levels) now fully flatten

### Changed
- **Timer architecture redesign** - Replaced hierarchical Timer::Wheel with simple queue-based system
  - Better suited for sparse time simulation vs real-time tick processing
  - Simpler implementation, easier to maintain
  - Adequate performance for typical use cases (<1000 concurrent timers)

### Fixed
- **Promise flattening** - Fixed deeply nested promise resolution (Promise → Promise → Promise → Value)
- **Promise timeout chaining** - timeout() no longer creates intermediate promises, works correctly in chains

### Removed
- **time::wheel** feature - Replaced with simpler ScheduledExecutor
  - Hierarchical timer wheel was overcomplicated for sparse time simulation needs
  - Queue-based approach more appropriate for test/simulation use cases

### Documentation
- Comprehensive POD documentation added:
  - **ScheduledExecutor** - Architecture, usage patterns, performance characteristics
  - **Executor** - Event loop model, chaining, cycle detection
  - **Stream time operations** - Throttle, Debounce, Timeout with usage examples
  - All POD includes integration examples and comparison sections
- TEST_AUDIT_RESULTS.md - Complete test suite audit report

### Testing
- **937 tests** across 98 test files (up from 904)
- 100% passing - no skipped tests, no TODOs
- Comprehensive test audit completed
- All time-based operations thoroughly tested

## [0.01] - 2025-12-09

### Added

#### Core Infrastructure
- Feature loader with hierarchical sub-feature support (e.g., `io::stream`, `datatypes::numeric`)
- Source file caching with LRU eviction (100 file limit, configurable via `$MAX_CACHE_SIZE`)
- Cache statistics tracking (hits, misses, evictions, hit rate)
- Lexical module importing utility

#### Features

**error**
- Structured error objects with automatic stringification
- Beautiful error formatting with source context and syntax highlighting
- Full stack backtraces with file/line information
- `Error->throw()` for throwing structured errors with optional hints
- Automatic caller location capture

**functional**
- Function, BiFunction - Function wrappers with composition and input validation
- Predicate - Boolean test functions with combinators (and, or, negate) and validation
- Consumer, BiConsumer - Side-effect functions with chaining and validation
- Supplier - Zero-argument value suppliers with validation
- Comparator - Comparison functions with reversal and chaining and validation
- Full combinator support (compose, and_then, curry, etc.)
- All classes validate parameters are CODE references with helpful error messages

**stream**
- Lazy stream processing API
- Sources: FromArray, FromRange, FromIterator, FromSupplier, OfStreams (all with input validation)
  - FromArray validates ARRAY references
  - FromRange validates numeric parameters and non-zero step
  - FromIterator validates callable next/has_next (CODE ref or Function/Predicate objects)
- Operations: map, grep, flatMap, flatten, take, takeUntil, peek, when, every, buffered, gather, reduce, forEach, collect, recurse
- Collectors: ToList, ToHash
- Pattern matching with Match and Match::Builder
- Depth-first tree traversal with `recurse`

**io::stream**
- IO::Stream::Files - Read file lines or bytes as streams
- IO::Stream::Directories - List directory contents, recursive walking
- Integration with Path::Tiny for file system operations
- Automatic file/directory handle cleanup when streams are garbage collected
- Proper error handling with Error objects for directory open failures

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
- Promise - JavaScript-style promises with chaining and validation
  - Validates executor parameter is an Executor object
  - Prevents double resolution/rejection with clear error messages
- Promise combinators: then, catch, finally
- Promise factories: resolved, rejected
- Automatic promise flattening in chains

**datatypes::numeric**
- Tensor - N-dimensional array operations with validation
  - Data size validation (must match shape dimensions)
  - Index bounds checking with helpful error messages
  - Slice bounds validation
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
- 937 tests across 98 test files
- Comprehensive coverage of all features
- Integration tests for feature combinations
- Edge case testing for boundary conditions
- Input validation tests for all critical classes
- Resource management tests (cache eviction, timer limits)
- Error handling tests with structured Error objects

### Documentation
- Complete POD documentation for all major modules
- README with quick start examples
- Working examples in examples/ directory:
  - logstats - Log analysis with streams
  - events - Event-driven architecture
  - time - Timer wheel and animations

### Known Limitations
- **Not thread-safe** - All features designed for single-threaded use
- **Cache eviction** - Source file cache uses simple LRU (may evict frequently used files in large codebases)

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

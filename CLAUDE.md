# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

grey::static is an opinionated Perl module loader that provides curated "features" for development. Features are loaded via the import list and classes become globally available.

Currently implemented features:
- **diagnostics** - Rust-style error/warning messages with source context, syntax highlighting, and stack backtraces
- **functional** - Function, BiFunction, Predicate, Consumer, BiConsumer, Supplier, Comparator
- **logging** - Debug logging utilities
- **stream** - Java-style Stream API with sources, operations, and collectors

## Requirements

- Perl v5.40+ (uses `class` feature from `experimental`)
- No CPAN dependencies beyond core modules

## Commands

Run all tests:
```
prove -lr t/
```

Run a single test:
```
prove -lv t/grey/static/01-source.t
```

Run the demo:
```
cd examples && perl demo.pl
```

## Architecture

```
lib/grey/static.pm                    # Feature loader
lib/grey/static/source.pm             # Source file reading/caching
lib/grey/static/diagnostics.pm        # Error/warning handlers
lib/grey/static/logging.pm            # Debug logging
lib/grey/static/functional.pm         # Functional classes loader
lib/grey/static/functional/           # Individual functional classes
lib/grey/static/stream.pm             # Stream feature loader
lib/grey/static/stream/               # Stream classes (mirroring p7 structure)
```

### grey::static

Main entry point. Always loads `grey::static::source` and caches the caller's source file. Loads requested features and calls their `import()`.

### grey::static::source

- `grey::static::source::File` class - Loads and caches source file contents
- `cache_file($path)` - Eagerly load and cache a file
- `get_source($path)` - Get cached source (lazy load if needed)

### grey::static::diagnostics

- `grey::static::diagnostics::StackFrame` - Represents a call stack frame
- `grey::static::diagnostics::Formatter` - Formats errors/warnings with source context
- Installs `$SIG{__DIE__}` and `$SIG{__WARN__}` handlers on import

Configuration via package globals:
```perl
$grey::static::diagnostics::NO_COLOR = 1;
$grey::static::diagnostics::NO_BACKTRACE = 1;
$grey::static::diagnostics::NO_SYNTAX_HIGHLIGHT = 1;
```

## Usage

```perl
use grey::static qw[diagnostics functional stream];

# Errors and warnings now display with source context and stack traces
# Functional classes (Function, Predicate, etc.) are globally available
# Stream API is available
```

## Design Document

See `docs/grey-static-v0-design.md` for the full design specification.

## Porting from p7

This project ports code from the p7 project located at `/Users/stevan/Projects/perl/p7`.

### Porting Guidelines

1. **Preserve file and folder structure** - Mirror the p7 directory layout exactly
   - p7: `lib/org/p7/util/stream/Stream/Source/FromArray.pm`
   - grey::static: `lib/grey/static/stream/Stream/Source/FromArray.pm`

2. **Preserve formatting** - Keep the original code formatting from p7

3. **Copy tests directly** - Port tests from p7 with minimal changes:
   - Change import from `use org::p7::util::stream qw[ Stream ]` to `use grey::static qw[ functional stream ]`
   - Keep all test logic and assertions identical

4. **Remove p7-specific lines** - Strip these from ported files:
   - `use module qw[ org::p7::... ]` - p7's custom module loader
   - `use org::p7::core::util qw[ Logging ]` - p7's logging (replace with grey::static::logging if needed)
   - `LOG $self if DEBUG` statements - remove or adapt for grey::static::logging
   - `TICK $self if DEBUG` statements - remove

5. **Fix method calls in combinators** - p7 code sometimes calls `$g->($x)` directly on function objects. These must use the proper method:
   - `$g->($x)` → `$g->apply($x)` for Function/BiFunction
   - `$p->($x)` → `$p->test($x)` for Predicate
   - `$c->($x)` → `$c->accept($x)` for Consumer/BiConsumer

6. **Feature loader pattern** - Each feature uses this pattern:
   ```perl
   use v5.40;
   use experimental qw(builtin);
   use builtin qw(load_module);

   package grey::static::FEATURE;

   use File::Basename ();
   use lib File::Basename::dirname(__FILE__) . '/FEATURE';

   load_module('ClassName');
   # ... load other classes

   sub import { }

   1;
   ```

### p7 Reference Locations

- Functional: `/Users/stevan/Projects/perl/p7/lib/org/p7/util/function/`
- Stream: `/Users/stevan/Projects/perl/p7/lib/org/p7/util/stream/`
- Stream tests: `/Users/stevan/Projects/perl/p7/t/org/p7/util/stream/`

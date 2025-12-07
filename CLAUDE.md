# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

grey::static is an opinionated Perl module loader that provides curated "features" for development. Features are loaded via the import list and classes become globally available.

Currently implemented features:
- **diagnostics** - Rust-style error/warning messages with source context, syntax highlighting, and stack backtraces

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
lib/grey/static.pm              # Feature loader
lib/grey/static/source.pm       # Source file reading/caching
lib/grey/static/diagnostics.pm  # Error/warning handlers
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
use grey::static qw[diagnostics];

# Errors and warnings now display with source context and stack traces
```

## Design Document

See `docs/grey-static-v0-design.md` for the full design specification.

# grey::static v0 Design

## Overview

`grey::static` is a top-level module loader that provides curated "features" for Perl development. Features are loaded via the import list and configure themselves automatically.

## Module Structure

```
lib/grey/static.pm              # Feature loader, always loads source
lib/grey/static/source.pm       # Source file reading/caching (eager load)
lib/grey/static/diagnostics.pm  # Error/warning handlers
lib/grey/static/stream.pm       # Stream API feature loader
lib/grey/static/stream/...      # Stream classes
```

## Usage

```perl
use grey::static qw[diagnostics];
```

Features are loaded by name. Multiple features can be loaded:

```perl
use grey::static qw[diagnostics stream];
```

After loading, classes are available globally:

```perl
use grey::static qw[stream];

# Stream is now in the global namespace
my $result = Stream->of(1, 2, 3)
    ->map(sub { $_ * 2 })
    ->collect(Stream::Collectors->to_list);
```

## Import Flow

1. Perl loads `grey::static`
2. `grey::static->import(@features)` called
3. `grey::static` loads `grey::static::source` (always, automatically)
4. `grey::static::source` eagerly caches the caller's source file
5. For each feature, `grey::static` loads `grey::static::$feature`
6. Each feature's `import()` is called to perform setup (install handlers, load classes, etc.)

## Configuration

Features use package globals for configuration, giving users maximum flexibility:

```perl
# Before loading
$grey::static::diagnostics::NO_COLOR = 1;
use grey::static qw[diagnostics];

# Or at runtime
$grey::static::diagnostics::NO_BACKTRACE = 1;
```

## Module Dependencies

```
grey::static
    └── grey::static::source (loaded automatically, always)
    └── grey::static::diagnostics (loaded on request)
            └── uses grey::static::source for context
    └── grey::static::stream (loaded on request)
            └── loads Stream and all related classes into global namespace
```

## Design Principles

1. **Opinionated** - Features are curated and work well together
2. **Eager loading** - Pay startup cost upfront, not at runtime
3. **Simple interface** - `use grey::static qw[feature]` is the only API
4. **Global namespace** - Classes become globally available, no exports needed
5. **Global configuration** - Package variables for flexibility
6. **Feature = collection** - A single feature loads all related classes

## Comparison with p7 Module System

| p7 | grey::static |
|---|---|
| `use module qw[...]` then `use mod qw[Class]` | `use grey::static qw[feature]` |
| User chooses which classes to load | Feature loads all related classes |
| @INC manipulation for short names | Standard Perl module paths |
| Flexible, generic | Opinionated, curated |
| Lexical imports via `export_lexically` | Global namespace |

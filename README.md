# grey::static

An opinionated Perl module loader that provides curated features for development.

## Requirements

- Perl v5.40+

## Installation

```perl
use lib '/path/to/grey-static/lib';
use grey::static qw[diagnostics];
```

## Features

### diagnostics

Rust-style error and warning messages with source context, syntax highlighting, and stack backtraces.

```perl
use grey::static qw[diagnostics];

sub get_user {
    my ($id) = @_;
    return undef if $id < 0;
    return { name => "User $id" };
}

sub process {
    my $user = get_user(-1);
    $user->{name};  # Error: Can't use undef as a HASH reference
}

process();
```

Output:

```
error: Can't use an undefined value as a HASH reference
    ╭─[script.pl:10]
  8 │sub process {
  9 │    my $user = get_user(-1);
 10 │    $user->{name};
    │    ╰──────────── error occurred here
 11 │}
    ╰

stack backtrace:
   ├─[0] main::process()
   │    at script.pl:13
   │    13 │process();
   ╰─[1] main::__ANON__
        at script.pl:13
```

#### Configuration

```perl
# Disable colors
$grey::static::diagnostics::NO_COLOR = 1;

# Disable stack traces
$grey::static::diagnostics::NO_BACKTRACE = 1;

# Disable syntax highlighting on the error line
$grey::static::diagnostics::NO_SYNTAX_HIGHLIGHT = 1;
```

## Design

grey::static is deliberately opinionated:

- **Single import** - `use grey::static qw[feature]` loads everything you need
- **Global namespace** - Classes are loaded into the global namespace, no exports
- **No opt-out** - Once loaded, features stay active
- **Eager loading** - Source files are cached upfront to avoid runtime costs

## License

Same terms as Perl itself.

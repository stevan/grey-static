use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::mop;

our $VERSION = '0.01';

use File::Basename ();

# Add the mop directory to @INC
use lib File::Basename::dirname(__FILE__) . '/mop';

# Load the MOP class
load_module('MOP');

sub import { }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

grey::static::mop - Meta-Object Protocol utilities for introspecting Perl packages

=head1 SYNOPSIS

    use grey::static qw[ functional stream mop ];

    # Introspect a package's symbol table
    my @symbols = MOP->namespace('Foo::Bar')
        ->expand_symbols(qw[ CODE ])  # Get all code symbols
        ->collect(Stream::Collectors->ToList);

    # Walk the entire package hierarchy
    my @all_symbols = MOP->namespace('MyApp')
        ->walk()                      # Recursively walk namespaces
        ->expand_symbols()            # Get all symbols (default: all types)
        ->collect(Stream::Collectors->ToList);

    # Get all classes in a method resolution order
    my @mro_symbols = MOP->mro('MyClass')
        ->expand_symbols(qw[ CODE ])  # Get all methods
        ->collect(Stream::Collectors->ToList);

=head1 DESCRIPTION

The C<mop> feature provides meta-object protocol utilities for introspecting
Perl packages and symbol tables using streams. It allows you to explore
namespaces, globs, and symbols in a functional, stream-based way.

B<Dependencies:> Requires C<functional> and C<stream> features.

=head1 CLASSES

=head2 MOP

Stream class for meta-object protocol operations.

=head3 Class Methods

=over 4

=item C<namespace($package)>

Creates a stream of globs from the specified package's symbol table.

B<Parameters:>

=over 4

=item C<$package>

A package name (string) or stash reference (HASH ref).
If a string is provided, it's converted to a stash reference.

=back

B<Returns:> A C<MOP> stream where each element is a C<MOP::Glob> object.

=item C<mro($class)>

Creates a stream that walks the method resolution order (MRO) of a class,
returning globs from all packages in the inheritance hierarchy.

B<Parameters:>

=over 4

=item C<$class>

A class name (string).

=back

B<Returns:> A C<MOP> stream where each element is a C<MOP::Glob> object
from the class and all its ancestors.

=back

=head3 Methods

=over 4

=item C<expand_symbols(@slots)>

Expands each glob into its individual symbols.

B<Parameters:>

=over 4

=item C<@slots>

Optional list of slot types to expand. Valid values: C<SCALAR>, C<ARRAY>,
C<HASH>, C<CODE>. If not specified, all slot types are expanded.

=back

B<Returns:> A stream where each element is a C<MOP::Symbol> object.

B<Example:>

    MOP->namespace('Foo')
        ->expand_symbols(qw[ CODE ])  # Only expand CODE slots (methods)

=item C<walk()>

Recursively walks through nested namespaces (packages ending with C<::>).

B<Returns:> A stream of C<MOP::Glob> objects from the current namespace
and all nested namespaces.

=back

=head2 MOP::Glob

Represents a glob entry in a symbol table.

=head3 Constructor

    my $glob = MOP::Glob->new(glob => \*Foo::bar);

=head3 Methods

=over 4

=item C<glob()>

Returns the underlying glob reference.

=item C<name()>

Returns the simple name of the glob (without package).

=item C<stash()>

Returns the package name this glob belongs to.

=item C<full_name()>

Returns the fully qualified name (C<Package::name>).

=item C<is_stash()>

Returns true if this glob represents a nested namespace (name ends with C<::>).

=item C<has_scalar()>, C<has_array()>, C<has_hash()>, C<has_code()>

Returns true if the glob has the corresponding slot type defined.

=item C<get_scalar_symbol()>, C<get_array_symbol()>, C<get_hash_symbol()>, C<get_code_symbol()>

Returns a C<MOP::Symbol> object for the corresponding slot.

=item C<get_all_symbols(@slots)>

Returns a list of C<MOP::Symbol> objects for all defined slots.

B<Parameters:>

=over 4

=item C<@slots>

Optional list of slot types to get. Defaults to all types.

=back

=item C<has_slot_value($slot)>

Returns true if the specified slot is defined.

=item C<get_slot_value($slot)>

Returns the raw value for the specified slot.

=back

=head2 MOP::Symbol

Represents a specific symbol (SCALAR, ARRAY, HASH, or CODE) from a glob.

=head3 Constructor

    my $symbol = MOP::Symbol->new(glob => $glob_obj, ref => $ref);

=head3 Methods

=over 4

=item C<glob()>

Returns the C<MOP::Glob> object this symbol belongs to.

=item C<ref()>

Returns the reference to the symbol's value.

=item C<type()>

Returns the reference type (C<SCALAR>, C<ARRAY>, C<HASH>, C<CODE>, etc.).

=item C<sigil()>

Returns the Perl sigil for this symbol type (C<$>, C<@>, C<%>, C<&>, C<*>).

=back

=head2 MOP::Source::GlobsFromStash

Stream source that produces globs from a package's symbol table.

=head3 Constructor

    my $source = MOP::Source::GlobsFromStash->new(stash => \%Foo::);

=head3 Methods

=over 4

=item C<stash()>

Returns the stash reference.

=item C<next()>

Returns the next C<MOP::Glob> from the stash.

=item C<has_next()>

Returns true if more globs are available.

=back

=head1 EXAMPLE USAGE

=head2 Find All Methods in a Package

    my @methods = MOP->namespace('MyClass')
        ->expand_symbols(qw[ CODE ])
        ->map(sub ($symbol) {
            { name => $symbol->glob->name, code => $symbol->ref }
        })
        ->collect(Stream::Collectors->ToList);

=head2 Find All Package Variables

    my @variables = MOP->namespace('MyApp::Config')
        ->expand_symbols(qw[ SCALAR ARRAY HASH ])
        ->map(sub ($symbol) {
            $symbol->sigil . $symbol->glob->name
        })
        ->collect(Stream::Collectors->ToList);

=head2 Walk Entire Package Hierarchy

    my @all_packages = MOP->namespace('MyApp')
        ->walk()
        ->grep(sub ($glob) { $glob->is_stash })
        ->map(sub ($glob) { $glob->full_name })
        ->collect(Stream::Collectors->ToList);

=head2 Inspect Method Resolution Order

    my @inherited_methods = MOP->mro('MyClass')
        ->expand_symbols(qw[ CODE ])
        ->map(sub ($symbol) { $symbol->glob->full_name })
        ->collect(Stream::Collectors->ToList);

=head1 DEPENDENCIES

Requires:

=over 4

=item *

C<functional> feature

=item *

C<stream> feature

=item *

L<B> - Perl compiler backend

=back

=head1 SEE ALSO

L<grey::static>, L<grey::static::stream>, L<B>

=head1 AUTHOR

grey::static

=cut

use v5.42;
use experimental qw(builtin);
use builtin      qw[ export_lexically load_module ];

package importer {
    sub import ($, $from = undef, @imports) {
        return unless defined $from;
        no warnings 'shadow';
        load_module($from)
            && export_lexically( map { ("&${_}" => $from->can($_)) } @imports )
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

importer - Lexical module importing utility

=head1 SYNOPSIS

    use importer 'Scalar::Util' => qw[ blessed refaddr ];
    use importer 'List::Util'   => qw[ min max sum ];

    # Now blessed, refaddr, min, max, sum are available as lexical imports

    my $ref = bless {}, 'Foo';
    say blessed($ref);  # 'Foo'
    say refaddr($ref);  # 0x12345678

=head1 DESCRIPTION

C<importer> is a lightweight utility for importing functions from modules into
the current lexical scope using C<export_lexically>. It provides a cleaner
alternative to traditional C<use Module qw[ ... ]> when you want lexical
imports rather than package imports.

This module is automatically loaded by C<grey::static> and is used throughout
the grey::static ecosystem for importing utilities without polluting the
package namespace.

=head1 USAGE

The basic syntax is:

    use importer $module_name => @function_names;

B<Parameters:>

=over 4

=item C<$module_name>

The name of the module to import from (e.g., C<'Scalar::Util'>).

The module will be loaded automatically using C<load_module>.

=item C<@function_names>

List of function names to import from the module.

=back

B<Behavior:>

=over 4

=item 1.

Loads the specified module using C<load_module>

=item 2.

Retrieves the named functions using C<< $module->can($name) >>

=item 3.

Exports them lexically using C<export_lexically> with C<&> sigils

=item 4.

Functions are available in the current scope only (lexical, not package)

=back

=head1 EXAMPLES

=head2 Basic Import

    use importer 'List::Util' => qw[ sum min max ];

    my $total = sum(1, 2, 3, 4, 5);      # 15
    my $minimum = min(10, 20, 5, 30);    # 5
    my $maximum = max(10, 20, 5, 30);    # 30

=head2 Multiple Imports

    use importer 'Scalar::Util' => qw[ blessed refaddr ];
    use importer 'List::Util'   => qw[ any all none ];

    my $obj = bless {}, 'MyClass';
    say "Blessed!" if blessed($obj);

    my @numbers = (2, 4, 6, 8);
    say "All even!" if all { $_ % 2 == 0 } @numbers;

=head2 Usage in grey::static Modules

The C<importer> module is commonly used within grey::static features to import
utilities without package-level imports:

    # From grey::static::logging
    use importer 'Scalar::Util' => qw[ blessed refaddr ];
    use importer 'List::Util'   => qw[ min max ];

    # Functions are now available lexically in this module only

=head1 COMPARISON WITH TRADITIONAL USE

=head2 Traditional package import:

    use Scalar::Util qw[ blessed ];
    # blessed is now in the package namespace

=head2 Lexical import with importer:

    use importer 'Scalar::Util' => qw[ blessed ];
    # blessed is only in the lexical scope

The lexical approach:

=over 4

=item *

Keeps the package namespace clean

=item *

Makes dependencies explicit at point of use

=item *

Prevents accidental export of imported functions

=item *

Provides better encapsulation in large codebases

=back

=head1 IMPLEMENTATION

The implementation uses Perl 5.42's built-in C<export_lexically> and
C<load_module> functions:

    sub import ($, $from = undef, @imports) {
        return unless defined $from;
        no warnings 'shadow';
        load_module($from)
            && export_lexically(
                map { ("&${_}" => $from->can($_)) } @imports
            )
    }

B<Key points:>

=over 4

=item *

Uses signature unpacking with C<$class> in anonymous position

=item *

Returns early if no module name provided

=item *

Disables C<shadow> warnings to allow re-importing

=item *

Uses C<can> to retrieve function references safely

=item *

Adds C<&> sigil for function exports

=back

=head1 REQUIREMENTS

=over 4

=item *

Perl v5.42+ (uses C<export_lexically> and C<load_module> from C<builtin>)

=back

=head1 CAVEATS

=over 4

=item *

Only works with functions, not variables or other symbols

=item *

The imported module must support C<< ->can($name) >> lookup

=item *

Functions must be defined when the module is loaded (no autoloading)

=back

=head1 SEE ALSO

=over 4

=item *

L<builtin> - Core module providing C<export_lexically> and C<load_module>

=item *

L<grey::static> - Main grey::static module loader

=item *

L<Exporter::Tiny> - More feature-rich exporting system

=back

=head1 VERSION

Part of grey::static 0.01

=head1 AUTHOR

grey::static

=cut

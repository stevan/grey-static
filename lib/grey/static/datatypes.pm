use v5.42;
use experimental qw[ builtin ];
use builtin qw[ load_module export_lexically ];

package grey::static::datatypes;

our $VERSION = '0.01';

use File::Basename ();

sub import {
    my ($class, @subfeatures) = @_;

    # If no subfeatures specified, do nothing
    return unless @subfeatures;

    # Load each subfeature
    for my $subfeature (@subfeatures) {
        if ($subfeature eq 'numeric') {
            # Add the numeric directory to @INC
            use lib File::Basename::dirname(__FILE__) . '/datatypes/numeric';

            # Load the numeric datatype classes
            load_module('Tensor');
            load_module('Scalar');
            load_module('Vector');
            load_module('Matrix');
        }
        elsif ($subfeature eq 'collections') {
            # Add the collections directory to @INC
            use lib File::Basename::dirname(__FILE__) . '/datatypes/collections';

            # Load the collection classes
            load_module('List');
            load_module('Stack');
            load_module('Queue');
            load_module('Set');
            load_module('Map');
        }
        elsif ($subfeature eq 'util') {
            use lib File::Basename::dirname(__FILE__) . '/datatypes/util';
            load_module('Result');
            load_module('Option');

            export_lexically(
                '&None'   => sub ()       { Option->new },
                '&Some'   => sub ($value) { Option->new(some  => $value) },
                '&Ok'     => sub ($value) { Result->new(ok    => $value) },
                '&Error'  => sub ($error) { Result->new(error => $error) },

            );
        }
        else {
            die "Unknown datatypes subfeature: $subfeature";
        }
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

grey::static::datatypes - Data type utilities

=head1 SYNOPSIS

    use grey::static qw[ datatypes::util ];

    # Option type
    my $some = Some(42);
    my $none = None();

    say $some->get;              # 42
    say $some->get_or_else(0);   # 42
    say $none->get_or_else(0);   # 0

    # Result type
    my $ok = Ok(42);
    my $err = Error("failed");

    say $ok->get_or_else(0);     # 42
    say $err->get_or_else(0);    # 0

    # Using with numeric datatypes
    use grey::static qw[ datatypes::numeric ];

    my $tensor = Tensor->initialize([2, 3], [1, 2, 3, 4, 5, 6]);
    my $vector = Vector->new([1, 2, 3]);
    my $matrix = Matrix->new([[1, 2], [3, 4]]);

=head1 DESCRIPTION

The C<datatypes> feature provides data type utilities organized as sub-features.

=head1 SUB-FEATURES

=head2 datatypes::util

Provides utility types for safer data handling: C<Option> and C<Result>.

=head2 datatypes::numeric

Provides numeric computation datatypes: C<Tensor>, C<Scalar>, C<Vector>,
and C<Matrix>.

=head1 CLASSES (datatypes::util)

=head2 Option

Represents an optional value - either C<Some(value)> or C<None>.

=head3 Constructors

    my $some = Some($value);    # Create Some variant
    my $none = None();          # Create None variant

These are exported lexical functions when loading C<datatypes::util>.

Direct construction is also supported:

    my $opt = Option->new(some => $value);  # Some
    my $opt = Option->new;                  # None

=head3 Methods

=over 4

=item C<defined()>

Returns true if the option contains a value (is C<Some>), false otherwise.

=item C<empty()>

Returns true if the option is C<None>, false otherwise.

=item C<get()>

Returns the contained value if C<Some>.

B<Dies> if called on C<None> with error: "Runtime Error: calling get on None"

=item C<get_or_else($default)>

Returns the contained value if C<Some>, otherwise returns C<$default>.

If C<$default> is a code reference, it is called to produce the default value.

=item C<or_else($f)>

Returns this C<Option> if it's C<Some>, otherwise returns the result of C<$f>.

If C<$f> is a code reference, it is called to produce an alternative C<Option>.

=item C<map($f)>

If C<Some>, applies C<$f> to the contained value and wraps the result in C<Some>.
If C<None>, returns C<None>.

    my $doubled = Some(21)->map(sub ($x) { $x * 2 });  # Some(42)
    my $none = None()->map(sub ($x) { $x * 2 });       # None

=item C<to_string()>

Returns a string representation: C<"Some(value)"> or C<"None()">.

Also available via stringification overload.

=back

=head2 Result

Represents the result of an operation - either C<Ok(value)> or C<Error(error)>.

=head3 Constructors

    my $ok = Ok($value);      # Create Ok variant
    my $err = Error($error);  # Create Error variant

These are exported lexical functions when loading C<datatypes::util>.

Direct construction is also supported:

    my $res = Result->new(ok => $value);      # Ok
    my $res = Result->new(error => $error);   # Error

=head3 Methods

=over 4

=item C<success()>

Returns true if the result is C<Ok>, false otherwise.

=item C<failure()>

Returns true if the result is C<Error>, false otherwise.

=item C<ok()>

Returns the C<Ok> value if present, C<undef> otherwise. This is a field reader.

=item C<error()>

Returns the C<Error> value if present, C<undef> otherwise. This is a field reader.

=item C<get_or_else($default)>

Returns the C<Ok> value if present, otherwise returns C<$default>.

If C<$default> is a code reference, it is called to produce the default value.

=item C<or_else($f)>

Returns this C<Result> if it's C<Ok>, otherwise returns the result of C<$f>.

If C<$f> is a code reference, it is called to produce an alternative C<Result>.

=item C<map($f)>

If C<Ok>, applies C<$f> to the contained value and wraps the result in C<Ok>.
If C<Error>, returns the same C<Error> unchanged.

    my $doubled = Ok(21)->map(sub ($x) { $x * 2 });        # Ok(42)
    my $err = Error("fail")->map(sub ($x) { $x * 2 });     # Error("fail")

=item C<to_string()>

Returns a string representation: C<"Ok(value)"> or C<"Error(error)">.

Also available via stringification overload.

=back

=head1 CLASSES (datatypes::numeric)

The C<datatypes::numeric> sub-feature provides the following classes for numerical
computations:

=head2 Tensor

N-dimensional array with broadcasting and mathematical operations.

Key methods: C<initialize>, C<at>, C<dim_at>, C<shape>, C<rank>, C<size>,
C<to_list>, mathematical operators.

=head2 Scalar

0-dimensional tensor (scalar value) compatible with Vector and Matrix operations.

=head2 Vector

1-dimensional tensor with vector-specific operations.

Key methods: C<new>, C<at>, C<length>, C<dot>, C<magnitude>, mathematical operators.

=head2 Matrix

2-dimensional tensor with matrix-specific operations.

Key methods: C<new>, C<at>, C<rows>, C<cols>, C<transpose>, mathematical operators.

=head1 SEE ALSO

L<grey::static>

=head1 AUTHOR

grey::static

=cut

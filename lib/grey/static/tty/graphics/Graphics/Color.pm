
use v5.42;
use experimental qw[ class ];

class Graphics::Color {
    field $r :param;
    field $g :param;
    field $b :param;

    method r { $r }
    method g { $g }
    method b { $b }

    method rgb { $r, $g, $b }

    method equals ($c) { $r == $c->r && $g == $c->g && $b == $c->b }

    method clone { Graphics::Color->new( r => $r, g => $g, b => $b ) }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Graphics::Color - RGB color representation

=head1 SYNOPSIS

    use grey::static qw[ tty::graphics ];

    my $red = Graphics::Color->new(r => 1.0, g => 0.0, b => 0.0);

    my $r = $red->r;
    my $g = $red->g;
    my $b = $red->b;
    my ($r, $g, $b) = $red->rgb;

    my $red2 = Graphics::Color->new(r => 1.0, g => 0.0, b => 0.0);
    if ($red->equals($red2)) {
        say "Colors are equal";
    }

=head1 DESCRIPTION

C<Graphics::Color> represents an RGB color with red, green, and blue components.
Color values are normalized to the range [0, 1], where 0 is minimum intensity
and 1 is maximum intensity.

=head1 CONSTRUCTOR

=head2 new

    my $color = Graphics::Color->new(r => $r, g => $g, b => $b);

Creates a new color with the specified RGB components. Values should be in
the range [0, 1].

Examples:

    my $red   = Graphics::Color->new(r => 1.0, g => 0.0, b => 0.0);
    my $green = Graphics::Color->new(r => 0.0, g => 1.0, b => 0.0);
    my $blue  = Graphics::Color->new(r => 0.0, g => 0.0, b => 1.0);
    my $white = Graphics::Color->new(r => 1.0, g => 1.0, b => 1.0);
    my $black = Graphics::Color->new(r => 0.0, g => 0.0, b => 0.0);
    my $gray  = Graphics::Color->new(r => 0.5, g => 0.5, b => 0.5);

=head1 METHODS

=head2 r

    my $red_component = $color->r;

Returns the red component (0-1).

=head2 g

    my $green_component = $color->g;

Returns the green component (0-1).

=head2 b

    my $blue_component = $color->b;

Returns the blue component (0-1).

=head2 rgb

    my ($r, $g, $b) = $color->rgb;

Returns all three color components as a list (r, g, b).

=head2 equals

    if ($color1->equals($color2)) {
        ...
    }

Returns true if this color has the same RGB values as another color.

=head2 clone

    my $copy = $color->clone;

Creates a copy of this color.

=head1 COLOR VALUES

Graphics::Color uses normalized color values in the range [0, 1]:

=over 4

=item * 0.0 = Minimum intensity (off)

=item * 1.0 = Maximum intensity (full)

=item * 0.5 = Half intensity

=back

This is different from the traditional 0-255 range used in many graphics APIs.
To convert from 0-255 to 0-1, divide by 255:

    my $color = Graphics::Color->new(
        r => 255 / 255,  # 1.0
        g => 128 / 255,  # 0.5
        b => 64 / 255,   # 0.25
    );

=head1 SEE ALSO

L<Graphics>, L<Graphics::Point>, L<Graphics::Shader>

=cut

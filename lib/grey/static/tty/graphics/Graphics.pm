package Graphics;

use v5.42;
use experimental qw[ builtin ];
use builtin      qw[ export_lexically ];

use Graphics::Point  ();
use Graphics::Color  ();
use Graphics::Shader ();
use Graphics::Sprite ();
use Graphics::Tools::Shaders ();
use Graphics::Tools::ArrowKeys ();

# Import from_matrices from Sprite
require Graphics::Sprite;

sub import {
    export_lexically(
        # Core classes
        '&Point'      => sub { Graphics::Point->new(@_) },
        '&Color'      => sub { Graphics::Color->new(@_) },
        '&Shader'     => sub { Graphics::Shader->new(@_) },
        '&Sprite'     => sub { Graphics::Sprite->new(@_) },
        '&ArrowKeys'  => sub { Graphics::Tools::ArrowKeys->new(@_) },

        # Graphics utility functions from Tools::Shaders
        '&fract'      => \&Graphics::Tools::Shaders::fract,
        '&distance'   => \&Graphics::Tools::Shaders::distance,
        '&clamp'      => \&Graphics::Tools::Shaders::clamp,
        '&smooth'     => \&Graphics::Tools::Shaders::smooth,
        '&smoothstep' => \&Graphics::Tools::Shaders::smoothstep,
        '&mix'        => \&Graphics::Tools::Shaders::mix,

        # Sprite utility function
        '&from_matrices' => \&Graphics::Sprite::from_matrices,
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Graphics - Terminal graphics rendering with shaders and sprites

=head1 SYNOPSIS

    use grey::static qw[ tty::graphics ];

    # Create a shader-based animation
    my $shader = Graphics::Shader->new(
        height       => 60,
        width        => 120,
        coord_system => Graphics::Shader->CENTERED,
        shader       => sub ($point, $time) {
            my ($x, $y) = $point->xy;
            return Graphics::Color->new(
                r => abs(sin($time + $x)),
                g => abs(sin($time + $y)),
                b => abs(cos($time)),
            );
        }
    );

    $shader->clear_screen;
    $shader->hide_cursor;

    while (1) {
        my $t = time;
        $shader->draw($t);
    }

    $shader->show_cursor;

=head1 DESCRIPTION

The C<Graphics> module provides high-level terminal graphics capabilities
built on top of C<tty::ansi>. It implements a shader-based rendering system
for creating animated terminal graphics using Unicode characters and 24-bit
color.

=head1 CORE CONCEPTS

=head2 Shader-Based Rendering

Graphics uses a functional shader approach where you define a function that
computes the color for each point on the screen:

    shader => sub ($point, $time) {
        # Compute and return a Graphics::Color
    }

The shader function receives:

=over 4

=item * C<$point> - A Graphics::Point with x,y coordinates

=item * C<$time> - A scalar time value (typically from C<time()>)

=back

=head2 Coordinate Systems

Graphics supports two coordinate systems:

=over 4

=item * C<TOP_LEFT> - (0,0) at top-left, pixel coordinates

=item * C<CENTERED> - (0,0) at center, normalized coordinates (-1 to 1)

=back

=head2 Unicode Rendering

Graphics uses the Unicode half-block character (▀) to render two pixels
vertically in each terminal character cell, effectively doubling vertical
resolution.

=head1 EXPORTED CLASSES

=head2 Graphics::Point

Represents 2D coordinates.

    my $p = Graphics::Point->new(x => 10, y => 20);
    my ($x, $y) = $p->xy;
    my $dist = $p->distance;  # Distance from origin

=head2 Graphics::Color

Represents RGB colors (0-1 normalized).

    my $red = Graphics::Color->new(r => 1.0, g => 0.0, b => 0.0);
    my ($r, $g, $b) = $red->rgb;

=head2 Graphics::Shader

The core rendering engine.

    my $shader = Graphics::Shader->new(
        height => 60,
        width => 120,
        coord_system => Graphics::Shader->CENTERED,
        shader => sub ($p, $t) { ... }
    );

    $shader->draw($time);

=head1 EXPORTED UTILITY FUNCTIONS

Graphics exports several utility functions useful for shader programming:

=over 4

=item C<fract($x)>

Returns the fractional part of C<$x>.

=item C<distance($x, $y)>

Returns the distance from origin: C<sqrt(x*x + y*y)>.

=item C<clamp($x, $min, $max)>

Clamps C<$x> to the range [C<$min>, C<$max>].

=item C<smooth($x)>

Smooth interpolation: C<3*x^2 - 2*x^3>.

=item C<smoothstep($edge0, $edge1, $x)>

Smooth Hermite interpolation between C<$edge0> and C<$edge1>.

=item C<mix($a, $b, $t)>

Linear interpolation: C<$a * (1 - $t) + $b * $t>.

=back

=head1 EXAMPLE USAGE

=head2 Simple Gradient

    use grey::static qw[ tty::graphics ];

    my $shader = Graphics::Shader->new(
        height => 40,
        width => 80,
        shader => sub ($p, $t) {
            my ($x, $y) = $p->xy;
            return Graphics::Color->new(
                r => $x,
                g => $y,
                b => 0.5,
            );
        }
    );

    $shader->draw(0);

=head2 Animated Pattern

    use grey::static qw[ tty::graphics ];
    use Time::HiRes qw[ time sleep ];

    my $shader = Graphics::Shader->new(
        height => 60,
        width => 120,
        coord_system => Graphics::Shader->CENTERED,
        shader => sub ($p, $t) {
            my ($x, $y) = $p->xy;
            my $d = distance($x, $y);
            my $wave = sin($d * 10 - $t * 3);
            return Graphics::Color->new(
                r => smoothstep(-1, 1, $wave),
                g => smoothstep(-1, 1, cos($t + $d)),
                b => 0.3,
            );
        }
    );

    $shader->clear_screen;
    $shader->hide_cursor;

    while (1) {
        $shader->draw(time);
        sleep 0.033;  # ~30 FPS
    }

=head1 INTEGRATION

Graphics integrates seamlessly with other grey::static features:

=head2 With datatypes::numeric

    use grey::static qw[ tty::graphics datatypes::numeric ];

    my $data = Matrix->random([20, 40], 0, 1);

    my $heatmap = Graphics::Shader->new(
        height => 20,
        width => 40,
        shader => sub ($p, $t) {
            my ($x, $y) = $p->xy;
            my $value = $data->at($y, $x);
            return Graphics::Color->new(r => $value, g => 0, b => 1 - $value);
        }
    );

=head2 With functional

    use grey::static qw[ tty::graphics functional ];

    my $color_fn = Function->new(sub ($p) {
        my $d = $p->distance;
        return Graphics::Color->new(r => $d, g => $d, b => $d);
    });

=head1 DEPENDENCIES

Graphics requires:

=over 4

=item * C<tty::ansi> - For ANSI terminal control (automatically loaded)

=item * Perl v5.42+

=back

=head1 SEE ALSO

L<grey::static>, L<grey::static::tty::ansi>, L<Graphics::Shader>, L<Graphics::Point>, L<Graphics::Color>

=head1 AUTHOR

grey::static

=cut

package Graphics::Tools::Shaders;

use v5.42;
use experimental qw[ builtin ];
use List::Util qw[ min max ];

sub fract ($v) {
    return $v - floor($v);
}

sub distance ($x, $y) {
    return sqrt(($x*$x) + ($y*$y))
}

sub clamp ($x, $min, $max) {
    return max( $min, min( $max, $x ) );
}

sub smooth ($x) {
    return ($x ** 2) * (3 - (2 * $x))
}

sub smoothstep ($edge0, $edge1, $x) {
    my $t = max( 0, min( 1, (($x - $edge0) / ($edge1 - $edge0)) ) );
    return ($t ** 2) * (3 - (2 * $t));
}

sub mix ($a, $b, $t) {
    return $a * (1 - $t) + $b * $t;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Graphics::Tools::Shaders - Utility functions for shader programming

=head1 SYNOPSIS

    use grey::static qw[ tty::graphics ];

    # All functions are exported lexically
    my $f = fract(3.7);         # 0.7
    my $d = distance(3, 4);     # 5
    my $c = clamp(5, 0, 10);    # 5
    my $s = smooth(0.5);        # 0.5
    my $ss = smoothstep(0, 1, 0.5);  # 0.5
    my $m = mix(0, 100, 0.3);   # 30

=head1 DESCRIPTION

C<Graphics::Tools::Shaders> provides utility functions commonly used in
shader programming and graphics operations. All functions are exported
lexically when you load the C<tty::graphics> feature.

=head1 FUNCTIONS

=head2 fract

    my $fractional_part = fract($value);

Returns the fractional part of a number. For example:

    fract(3.7)  # 0.7
    fract(5.0)  # 0.0
    fract(-2.3) # 0.7

=head2 distance

    my $dist = distance($x, $y);

Returns the Euclidean distance from the origin (0, 0):

    distance(3, 4)  # 5
    distance(1, 1)  # sqrt(2) ≈ 1.414

=head2 clamp

    my $clamped = clamp($value, $min, $max);

Clamps a value to the specified range [min, max]:

    clamp(5, 0, 10)   # 5
    clamp(-1, 0, 10)  # 0
    clamp(15, 0, 10)  # 10

=head2 smooth

    my $smoothed = smooth($x);

Applies smooth (Hermite) interpolation: C<3*x^2 - 2*x^3>.
Input should typically be in the range [0, 1]:

    smooth(0.0)  # 0.0
    smooth(0.5)  # 0.5
    smooth(1.0)  # 1.0

=head2 smoothstep

    my $result = smoothstep($edge0, $edge1, $x);

Performs smooth Hermite interpolation between two edge values.
Returns 0 if C<$x> <= C<$edge0>, 1 if C<$x> >= C<$edge1>,
and a smooth interpolation in between:

    smoothstep(0, 1, 0.5)   # 0.5
    smoothstep(0, 1, -1)    # 0.0
    smoothstep(0, 1, 2)     # 1.0
    smoothstep(0, 10, 5)    # 0.5

=head2 mix

    my $interpolated = mix($a, $b, $t);

Linear interpolation (lerp) between two values:
Returns C<$a * (1 - $t) + $b * $t>

    mix(0, 100, 0.0)   # 0
    mix(0, 100, 0.5)   # 50
    mix(0, 100, 1.0)   # 100
    mix(10, 20, 0.3)   # 13

=head1 COMMON PATTERNS

=head2 Color Gradients

    my $shader = Graphics::Shader->new(
        shader => sub ($p, $t) {
            my ($x, $y) = $p->xy;
            return Graphics::Color->new(
                r => mix(0.2, 0.8, $x),
                g => mix(0.3, 0.9, $y),
                b => 0.5
            );
        }
    );

=head2 Pulsing Effects

    my $shader = Graphics::Shader->new(
        shader => sub ($p, $t) {
            my $pulse = smoothstep(-1, 1, sin($t * 2));
            my $brightness = mix(0.2, 1.0, $pulse);
            return Graphics::Color->new(r => $brightness, g => 0, b => 0);
        }
    );

=head2 Distance-Based Effects

    my $shader = Graphics::Shader->new(
        shader => sub ($p, $t) {
            my ($x, $y) = $p->xy;
            my $d = distance($x, $y);
            my $intensity = clamp(1 - $d, 0, 1);
            return Graphics::Color->new(r => $intensity, g => $intensity, b => $intensity);
        }
    );

=head1 SEE ALSO

L<Graphics>, L<Graphics::Shader>, L<Graphics::Color>

=cut

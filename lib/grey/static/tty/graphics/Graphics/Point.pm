
use v5.42;
use experimental qw[ class ];

class Graphics::Point {
    field $x :param;
    field $y :param;

    method x { $x }
    method y { $y }

    method xy { $x, $y }
    method yx { $y, $x }

    method distance { sqrt(($x*$x) + ($y*$y)) }

    method equals ($p) { $x == $p->x && $y == $p->y }

    method clone { Graphics::Point->new( x => $x, y => $y ) }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Graphics::Point - 2D coordinate representation

=head1 SYNOPSIS

    use grey::static qw[ tty::graphics ];

    my $p = Graphics::Point->new(x => 10, y => 20);

    my $x = $p->x;
    my $y = $p->y;
    my ($x, $y) = $p->xy;

    my $dist = $p->distance;  # Distance from origin

    my $p2 = Graphics::Point->new(x => 10, y => 20);
    if ($p->equals($p2)) {
        say "Points are equal";
    }

=head1 DESCRIPTION

C<Graphics::Point> represents a 2D coordinate with x and y values.

=head1 CONSTRUCTOR

=head2 new

    my $point = Graphics::Point->new(x => $x, y => $y);

Creates a new point with the specified x and y coordinates.

=head1 METHODS

=head2 x

    my $x = $point->x;

Returns the x coordinate.

=head2 y

    my $y = $point->y;

Returns the y coordinate.

=head2 xy

    my ($x, $y) = $point->xy;

Returns both coordinates as a list (x, y).

=head2 yx

    my ($y, $x) = $point->yx;

Returns both coordinates as a list (y, x).

=head2 distance

    my $dist = $point->distance;

Returns the Euclidean distance from the origin (0, 0).

=head2 equals

    if ($point->equals($other_point)) {
        ...
    }

Returns true if this point has the same coordinates as another point.

=head2 clone

    my $copy = $point->clone;

Creates a copy of this point.

=head1 SEE ALSO

L<Graphics>, L<Graphics::Color>, L<Graphics::Shader>

=cut

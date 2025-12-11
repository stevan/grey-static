
use v5.42;
use experimental qw[ class builtin ];
use builtin qw[ load_module ];

use Graphics::Point;
use Graphics::Color;

# Load Matrix dynamically - will be available when datatypes::numeric is loaded
BEGIN {
    # Matrix should be available if the user loaded datatypes::numeric
    # We'll check for it at runtime in ADJUST
}

class Graphics::Sprite {
    use Carp qw[ confess ];

    field $top    :param;  # Y coordinate
    field $left   :param;  # X coordinate

    # Matrix storage: three separate matrices for R, G, B channels
    field $r_matrix :param = undef;
    field $g_matrix :param = undef;
    field $b_matrix :param = undef;

    # Alternative: accept bitmap array for backwards compatibility
    field $bitmap :param = undef;

    # Cache bounds
    field $bottom;
    field $right;

    # Track sprite orientation
    field $flipped  = 0;
    field $mirrored = 0;

    ADJUST {
        # Check if Matrix is available
        unless (Matrix->can('new')) {
            confess 'Matrix class not available - did you load datatypes::numeric?';
        }

        # If bitmap provided, convert to matrices
        if (defined $bitmap) {
            confess 'bitmap must be an ARRAY ref' unless ref $bitmap eq 'ARRAY';
            confess 'bitmap must not be empty' unless @$bitmap;
            confess 'bitmap rows must be ARRAY refs' unless ref $bitmap->[0] eq 'ARRAY';

            my $height = scalar @$bitmap;
            my $width  = scalar @{$bitmap->[0]};

            # Extract R, G, B channels from Color objects
            my (@r_data, @g_data, @b_data);

            for my $y (0 .. $height - 1) {
                for my $x (0 .. $width - 1) {
                    my $color = $bitmap->[$y]->[$x];
                    if (defined $color) {
                        push @r_data, $color->r;
                        push @g_data, $color->g;
                        push @b_data, $color->b;
                    } else {
                        # Transparent/empty pixel
                        push @r_data, 0;
                        push @g_data, 0;
                        push @b_data, 0;
                    }
                }
            }

            $r_matrix = Matrix->initialize([$height, $width], \@r_data);
            $g_matrix = Matrix->initialize([$height, $width], \@g_data);
            $b_matrix = Matrix->initialize([$height, $width], \@b_data);
        }

        # Ensure we have matrices
        confess 'Sprite requires either bitmap or r_matrix/g_matrix/b_matrix'
            unless defined $r_matrix && defined $g_matrix && defined $b_matrix;

        # Validate matrix dimensions match
        my $r_shape = $r_matrix->shape;
        my $g_shape = $g_matrix->shape;
        my $b_shape = $b_matrix->shape;

        confess 'R, G, B matrices must have same dimensions'
            unless ($r_shape->[0] == $g_shape->[0] && $g_shape->[0] == $b_shape->[0] &&
                    $r_shape->[1] == $g_shape->[1] && $g_shape->[1] == $b_shape->[1]);

        $bottom = $top  + $self->height;
        $right  = $left + $self->width;
    }

    method height { $r_matrix->rows }
    method width  { $r_matrix->cols }

    method draw_at ($p) {
        my ($x, $y) = $p->xy;

        # Check bounds
        return unless $y >= $top  && $y < $bottom;
        return unless $x >= $left && $x < $right;

        # Get color from matrices
        my $row = $y - $top;
        my $col = $x - $left;

        my $r = $r_matrix->at($row, $col);
        my $g = $g_matrix->at($row, $col);
        my $b = $b_matrix->at($row, $col);

        return Graphics::Color->new(r => $r, g => $g, b => $b);
    }

    method is_mirrored { $mirrored }
    method is_flipped  { $flipped  }

    method mirror {
        # Horizontal flip: reverse each row
        # For matrices, we need to reverse the columns
        for my $row_idx (0 .. $self->height - 1) {
            my @r_row = reverse $r_matrix->row_at($row_idx);
            my @g_row = reverse $g_matrix->row_at($row_idx);
            my @b_row = reverse $b_matrix->row_at($row_idx);

            for my $col_idx (0 .. $self->width - 1) {
                # Set the reversed values back
                my $r_idx = $r_matrix->index($row_idx, $col_idx);
                my $g_idx = $g_matrix->index($row_idx, $col_idx);
                my $b_idx = $b_matrix->index($row_idx, $col_idx);

                $r_matrix->data->[$r_idx] = $r_row[$col_idx];
                $g_matrix->data->[$g_idx] = $g_row[$col_idx];
                $b_matrix->data->[$b_idx] = $b_row[$col_idx];
            }
        }

        $mirrored = $mirrored ? 0 : 1;
        return $self;
    }

    method flip {
        # Vertical flip: reverse the rows
        # For matrices, we reverse the row order
        my @r_rows = map { [ $r_matrix->row_at($_) ] } (0 .. $self->height - 1);
        my @g_rows = map { [ $g_matrix->row_at($_) ] } (0 .. $self->height - 1);
        my @b_rows = map { [ $b_matrix->row_at($_) ] } (0 .. $self->height - 1);

        @r_rows = reverse @r_rows;
        @g_rows = reverse @g_rows;
        @b_rows = reverse @b_rows;

        # Rebuild the matrices
        my @r_data = map { @$_ } @r_rows;
        my @g_data = map { @$_ } @g_rows;
        my @b_data = map { @$_ } @b_rows;

        $r_matrix = Matrix->initialize([$self->height, $self->width], \@r_data);
        $g_matrix = Matrix->initialize([$self->height, $self->width], \@g_data);
        $b_matrix = Matrix->initialize([$self->height, $self->width], \@b_data);

        $flipped = $flipped ? 0 : 1;
        return $self;
    }

    # Matrix conversion methods

    method to_matrices {
        return ($r_matrix, $g_matrix, $b_matrix);
    }

    method to_bitmap {
        my @bitmap;
        for my $row (0 .. $self->height - 1) {
            my @row_colors;
            for my $col (0 .. $self->width - 1) {
                my $r = $r_matrix->at($row, $col);
                my $g = $g_matrix->at($row, $col);
                my $b = $b_matrix->at($row, $col);

                push @row_colors, Graphics::Color->new(r => $r, g => $g, b => $b);
            }
            push @bitmap, \@row_colors;
        }
        return \@bitmap;
    }
}

# Package-level subroutine for creating sprites from matrices
sub from_matrices ($r, $g, $b, %params) {
    return Graphics::Sprite->new(
        top => $params{top} // 0,
        left => $params{left} // 0,
        r_matrix => $r,
        g_matrix => $g,
        b_matrix => $b,
    );
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Graphics::Sprite - 2D bitmap sprite graphics with Matrix storage

=head1 SYNOPSIS

    use grey::static qw[ tty::graphics datatypes::numeric ];

    # Create from bitmap (array of Color objects)
    my $sprite = Graphics::Sprite->new(
        top => 10,
        left => 20,
        bitmap => [
            [ Graphics::Color->new(r => 1, g => 0, b => 0), ... ],
            [ Graphics::Color->new(r => 0, g => 1, b => 0), ... ],
            ...
        ]
    );

    # Or create from matrices directly
    my $r_matrix = Matrix->ones([5, 5]);
    my $g_matrix = Matrix->zeros([5, 5]);
    my $b_matrix = Matrix->zeros([5, 5]);

    my $sprite = Graphics::Sprite->from_matrices(
        $r_matrix, $g_matrix, $b_matrix,
        top => 10, left => 20
    );

    # Draw sprite at a point
    my $color = $sprite->draw_at(Graphics::Point->new(x => 15, y => 12));

    # Transform sprite
    $sprite->flip;    # Vertical flip
    $sprite->mirror;  # Horizontal flip

=head1 DESCRIPTION

C<Graphics::Sprite> represents 2D bitmap graphics using Matrix storage
for efficient transformations and operations. Sprites can be created from
traditional bitmap arrays or directly from Matrix datatypes.

Internally, sprites store three separate matrices for R, G, and B color
channels, enabling efficient mathematical operations on sprite data.

=head1 CONSTRUCTOR

=head2 new

    my $sprite = Graphics::Sprite->new(
        top    => $y,
        left   => $x,
        bitmap => $bitmap,  # Array of arrays of Graphics::Color
    );

    # Or with matrices:
    my $sprite = Graphics::Sprite->new(
        top      => $y,
        left     => $x,
        r_matrix => $r,
        g_matrix => $g,
        b_matrix => $b,
    );

Creates a new sprite at the specified position. You can provide either:

=over 4

=item * C<bitmap> - Array of arrays of C<Graphics::Color> objects

=item * C<r_matrix>, C<g_matrix>, C<b_matrix> - Three Matrix objects

=back

=head2 from_matrices

    my $sprite = Graphics::Sprite->from_matrices(
        $r_matrix, $g_matrix, $b_matrix,
        top => $y, left => $x
    );

Class method to create a sprite directly from three Matrix objects.

=head1 METHODS

=head2 height

    my $h = $sprite->height;

Returns the sprite height in pixels.

=head2 width

    my $w = $sprite->width;

Returns the sprite width in pixels.

=head2 draw_at

    my $color = $sprite->draw_at($point);

Returns the C<Graphics::Color> at the given point, or C<undef> if the
point is outside the sprite bounds or the pixel is transparent.

=head2 flip

    $sprite->flip;

Flips the sprite vertically (upside down). Returns C<$self> for chaining.
Toggles the C<is_flipped> state.

=head2 mirror

    $sprite->mirror;

Mirrors the sprite horizontally (left-right). Returns C<$self> for chaining.
Toggles the C<is_mirrored> state.

=head2 is_flipped

    if ($sprite->is_flipped) { ... }

Returns true if the sprite has been flipped.

=head2 is_mirrored

    if ($sprite->is_mirrored) { ... }

Returns true if the sprite has been mirrored.

=head2 to_matrices

    my ($r, $g, $b) = $sprite->to_matrices;

Returns the three internal Matrix objects (R, G, B channels).

=head2 to_bitmap

    my $bitmap = $sprite->to_bitmap;

Converts the sprite back to bitmap format (array of arrays of Color objects).

=head1 MATRIX INTEGRATION

Sprites internally use three Matrix objects for R, G, and B color channels.
This enables:

=over 4

=item * Efficient transformations using Matrix operations

=item * Mathematical operations on sprite data

=item * Integration with numerical computing features

=back

Example - Creating a gradient sprite from matrices:

    use grey::static qw[ tty::graphics datatypes::numeric ];

    my $size = 10;
    my $r_matrix = Matrix->construct([$size, $size], sub {
        my ($row, $col) = @_;
        return $col / ($size - 1);
    });
    my $g_matrix = Matrix->zeros([$size, $size]);
    my $b_matrix = Matrix->zeros([$size, $size]);

    my $sprite = Graphics::Sprite->from_matrices(
        $r_matrix, $g_matrix, $b_matrix,
        top => 0, left => 0
    );

=head1 EXAMPLE USAGE

=head2 Creating and Drawing a Simple Sprite

    use grey::static qw[ tty::graphics ];

    my $red   = Graphics::Color->new(r => 1, g => 0, b => 0);
    my $green = Graphics::Color->new(r => 0, g => 1, b => 0);
    my $blue  = Graphics::Color->new(r => 0, g => 0, b => 1);

    my $sprite = Graphics::Sprite->new(
        top => 0,
        left => 0,
        bitmap => [
            [ $red,   $green, $blue  ],
            [ $green, $blue,  $red   ],
            [ $blue,  $red,   $green ],
        ]
    );

    # Get color at point
    my $p = Graphics::Point->new(x => 1, y => 1);
    my $color = $sprite->draw_at($p);  # Returns blue

=head2 Transforming Sprites

    $sprite->flip;      # Flip vertically
    $sprite->mirror;    # Mirror horizontally
    $sprite->flip;      # Flip back

    say "Flipped: ", $sprite->is_flipped;    # false
    say "Mirrored: ", $sprite->is_mirrored;  # true

=head2 Using with Shader

    my $shader = Graphics::Shader->new(
        height => 60,
        width => 120,
        shader => sub ($p, $t) {
            # Try to get sprite color at this point
            my $sprite_color = $sprite->draw_at($p);
            return $sprite_color if defined $sprite_color;

            # Otherwise, return background color
            return Graphics::Color->new(r => 0, g => 0, b => 0.2);
        }
    );

=head1 SEE ALSO

L<Graphics>, L<Graphics::Shader>, L<Graphics::Color>, L<Matrix>

=cut

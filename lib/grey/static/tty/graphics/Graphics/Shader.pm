
use v5.42;
use utf8;
use experimental qw[ class for_list ];

$|++;

use Graphics::Point;
use Graphics::Color;

# Load ANSI modules directly for terminal control
use File::Basename ();
use lib File::Basename::dirname(__FILE__) . '/../../../tty/ansi';

use ANSI::Screen ();
use ANSI::Color ();
use ANSI::Cursor ();

class Graphics::Shader {
    use Carp qw[ confess ];

    field $height   :param;
    field $width    :param;
    field $shader   :param;

    field %coords;
    field $newline;
    field @cols;
    field @rows;

    use constant TOP_LEFT => 1;
    use constant CENTERED => 2;

    field $coord_system :param = TOP_LEFT;

    ADJUST {
        $height > 0           || confess 'The `height` must be a greater than 0';
        $width  > 0           || confess 'The `width` must be a greater than 0';
        ref $shader eq 'CODE' || confess 'The `shader` must be a CODE ref';

        # Ensure odd dimensions for symmetric rendering
        $height -= 1 if $height % 2 == 0;
        $width  -= 1 if $width  % 2 == 0;

        # Newline: move down 1, left (width+1) - using ANSI cursor control
        $newline = ANSI::Cursor::format_move_down(1) . ANSI::Cursor::format_move_left($width + 1);

        if ($coord_system == TOP_LEFT) {
            @cols = ( 0 .. $width  );
            @rows = ( 0 .. $height );
        }
        elsif ($coord_system == CENTERED) {
            @cols = map { (($_ / $width ) * 2.0) - 1.0 } ( 0 .. $width  );
            @rows = map { (($_ / $height) * 2.0) - 1.0 } ( 0 .. $height );
        }
        else {
            confess "Unknown Coord System: $coord_system";
        }

        foreach my $y ( @rows ) {
            foreach my $x ( @cols ) {
                $coords{"${x}:${y}"} = Graphics::Point->new( x => $x, y => $y );
            }
        }
    }

    method rows { $height }
    method cols { $width  }

    method clear_screen       { print ANSI::Screen::clear_screen()    }
    method hide_cursor        { print ANSI::Screen::hide_cursor()     }
    method show_cursor        { print ANSI::Screen::show_cursor()     }
    method home_cursor        { print ANSI::Cursor::home_cursor()     }
    method enable_alt_buffer  { print ANSI::Screen::enable_alt_buf()  }
    method disable_alt_buffer { print ANSI::Screen::disable_alt_buf() }

    method draw ($t, $origin=undef) {
        my @out;
        foreach my ($y1, $y2) ( @rows ) {
            push @out => ((map {
                my $x = $_;

                # Get RGB values for both pixels (foreground and background)
                my ($r1, $g1, $b1) = map { int(255 * $_) } $shader->( $coords{"${x}:${y1}"}, $t )->rgb;
                my ($r2, $g2, $b2) = map { int(255 * $_) } $shader->( $coords{"${x}:${y2}"}, $t )->rgb;

                # Use ANSI color formatting
                ANSI::Color::format_color([$r1, $g1, $b1], [$r2, $g2, $b2]) . '▀';
            } @cols),
            $newline);
        }

        print((defined $origin
                ? ANSI::Cursor::format_move_cursor($origin->x, $origin->y)
                : ANSI::Cursor::home_cursor())
            . (join '' => @out)
            . ANSI::Color::format_reset());
    }

}

__END__

=pod

=encoding UTF-8

=head1 NAME

Graphics::Shader - Shader-based terminal rendering engine

=head1 SYNOPSIS

    use grey::static qw[ tty::graphics ];

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

C<Graphics::Shader> is the core rendering engine for terminal graphics.
It implements a shader-based approach where you define a function that
computes the color for each point on the screen.

The shader function is called for every pixel pair (using Unicode half-blocks
to render two pixels per terminal character), making it possible to create
animated, procedural graphics in the terminal.

=head1 CONSTRUCTOR

=head2 new

    my $shader = Graphics::Shader->new(
        height       => $height,
        width        => $width,
        coord_system => $coord_system,  # Optional, default: TOP_LEFT
        shader       => sub ($point, $time) { ... }
    );

Creates a new shader rendering engine.

B<Parameters:>

=over 4

=item * C<height> - Screen height in pixels (must be > 0)

=item * C<width> - Screen width in pixels (must be > 0)

=item * C<coord_system> - Coordinate system (C<TOP_LEFT> or C<CENTERED>)

=item * C<shader> - Code reference that computes colors

=back

The shader function receives:

=over 4

=item * C<$point> - A C<Graphics::Point> with x,y coordinates

=item * C<$time> - A scalar time value (typically from C<time()>)

=back

And must return a C<Graphics::Color> object.

B<Note:> Height and width will be adjusted to odd numbers if even values
are provided, ensuring symmetric rendering.

=head1 CONSTANTS

=head2 TOP_LEFT

    my $shader = Graphics::Shader->new(
        coord_system => Graphics::Shader->TOP_LEFT,
        ...
    );

Coordinate system where (0,0) is at the top-left corner. Coordinates
range from 0 to width-1 and 0 to height-1.

=head2 CENTERED

    my $shader = Graphics::Shader->new(
        coord_system => Graphics::Shader->CENTERED,
        ...
    );

Coordinate system where (0,0) is at the center. Coordinates are
normalized to the range [-1, 1] for both x and y.

=head1 METHODS

=head2 rows

    my $num_rows = $shader->rows;

Returns the number of rows (height).

=head2 cols

    my $num_cols = $shader->cols;

Returns the number of columns (width).

=head2 draw

    $shader->draw($time);

Renders a frame by calling the shader function for each pixel and
outputting the result to the terminal.

The C<$time> parameter is passed to the shader function and is typically
C<time()> for animated effects.

=head2 clear_screen

    $shader->clear_screen;

Clears the terminal screen.

=head2 hide_cursor

    $shader->hide_cursor;

Hides the terminal cursor (useful during rendering).

=head2 show_cursor

    $shader->show_cursor;

Shows the terminal cursor.

=head2 home_cursor

    $shader->home_cursor;

Moves the cursor to the home position (0,0).

=head2 enable_alt_buffer

    $shader->enable_alt_buffer;

Enables the alternate screen buffer. This allows you to render without
disturbing the main terminal content.

=head2 disable_alt_buffer

    $shader->disable_alt_buffer;

Disables the alternate screen buffer and returns to the main buffer.

=head1 RENDERING TECHNIQUE

Graphics::Shader uses the Unicode half-block character (▀) to render two
pixels vertically in each terminal character cell:

=over 4

=item * The foreground color is the top pixel

=item * The background color is the bottom pixel

=back

This effectively doubles the vertical resolution while maintaining full
24-bit RGB color for each pixel.

=head1 EXAMPLE USAGE

=head2 Simple Static Pattern

    use grey::static qw[ tty::graphics ];

    my $shader = Graphics::Shader->new(
        height => 40,
        width => 80,
        shader => sub ($p, $t) {
            my ($x, $y) = $p->xy;
            return Graphics::Color->new(
                r => $x / 80,
                g => $y / 40,
                b => 0.5,
            );
        }
    );

    $shader->draw(0);

=head2 Animated Wave Pattern

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
                g => 0.3,
                b => 0.5,
            );
        }
    );

    $shader->clear_screen;
    $shader->hide_cursor;

    while (1) {
        $shader->draw(time);
        sleep 0.033;  # ~30 FPS
    }

    $shader->show_cursor;

=head2 Interactive Application

    use grey::static qw[ tty::graphics ];

    my $shader = Graphics::Shader->new(
        height => 60,
        width => 120,
        shader => sub ($p, $t) {
            # Your rendering logic here
        }
    );

    $shader->enable_alt_buffer;
    $shader->clear_screen;
    $shader->hide_cursor;

    # Render loop...

    $shader->show_cursor;
    $shader->disable_alt_buffer;

=head1 PERFORMANCE

The shader function is called twice per terminal character (once for each
pixel in the vertical pair). For a 120x60 screen, this means 7,200 shader
function calls per frame.

For best performance:

=over 4

=item * Keep shader functions simple

=item * Pre-compute values outside the shader when possible

=item * Use appropriate frame rates (30 FPS is typically sufficient)

=item * Consider smaller screen sizes for complex shaders

=back

=head1 DEPENDENCIES

Graphics::Shader requires:

=over 4

=item * C<tty::ansi> - For terminal control (automatically loaded)

=item * C<Graphics::Point> - For coordinate representation

=item * C<Graphics::Color> - For color values

=back

=head1 SEE ALSO

L<Graphics>, L<Graphics::Point>, L<Graphics::Color>, L<Graphics::Tools::Shaders>

=cut

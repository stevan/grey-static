use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::tty;

our $VERSION = '0.01';

use File::Basename ();

sub import {
    my ($class, @subfeatures) = @_;

    # If no subfeatures specified, do nothing
    return unless @subfeatures;

    # Load each subfeature
    for my $subfeature (@subfeatures) {
        if ($subfeature eq 'ansi') {
            # Add the ansi directory to @INC
            use lib File::Basename::dirname(__FILE__) . '/tty/ansi';

            # Load the ANSI module
            load_module('ANSI');
            ANSI->import();
        }
        elsif ($subfeature eq 'graphics') {
            # Add the graphics directory to @INC
            use lib File::Basename::dirname(__FILE__) . '/tty/graphics';

            # Load the Graphics module
            load_module('Graphics');
            Graphics->import();
        }
        else {
            die "Unknown tty subfeature: $subfeature";
        }
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

grey::static::tty - Terminal (TTY) utilities and ANSI escape sequences

=head1 SYNOPSIS

    use grey::static qw[ tty::ansi ];

    # Terminal operations
    my ($width, $height) = get_terminal_size();
    set_output_to_utf8();

    # Screen control
    print clear_screen();
    print hide_cursor();
    print show_cursor();
    print enable_alt_buf();

    # Cursor movement
    print home_cursor();
    print format_move_cursor(10, 20);
    print format_move_down(5);

    # Colors
    print format_fg_color([255, 0, 0]);  # Red text
    print format_bg_color([0, 0, 255]);  # Blue background
    print format_reset();

    # Mouse tracking
    print enable_mouse_tracking(ON_BUTTON_PRESS);
    print disable_mouse_tracking(ON_BUTTON_PRESS);

=head1 DESCRIPTION

The C<tty> feature provides terminal utilities organized as sub-features.
Currently only the C<tty::ansi> sub-feature is available, which provides
ANSI escape sequences and terminal control functions.

=head1 SUB-FEATURES

=head2 tty::ansi

Provides ANSI escape sequences and terminal control functions. All functions
are exported lexically when the feature is loaded.

B<Dependencies:> Requires L<Term::ReadKey> for terminal size and read mode operations.

=head1 CLASSES AND FUNCTIONS

=head2 Terminal Operations

=over 4

=item C<get_terminal_size()>

Returns the current terminal size as C<($width, $height)>.

=item C<set_output_to_utf8($fh)>

Sets the output encoding to UTF-8 for the specified file handle.
Defaults to C<STDOUT> if not specified.

=item C<restore_read_mode($fh)>

Restores the terminal read mode to its previous state.
Defaults to C<STDIN> if not specified.

=item C<set_read_mode_to_normal($fh)>

Sets the terminal to normal read mode.
Defaults to C<STDIN> if not specified.

=item C<set_read_mode_to_noecho($fh)>

Sets the terminal to no-echo mode (input not displayed).
Defaults to C<STDIN> if not specified.

=item C<set_read_mode_to_raw($fh)>

Sets the terminal to raw (cbreak) mode for character-by-character input.
Defaults to C<STDIN> if not specified.

=back

=head2 Screen Control (ANSI::Screen)

=over 4

=item C<clear_screen()>

Returns the ANSI escape sequence to clear the screen.

=item C<hide_cursor()>

Returns the ANSI escape sequence to hide the cursor.

=item C<show_cursor()>

Returns the ANSI escape sequence to show the cursor.

=item C<enable_alt_buf()>

Returns the ANSI escape sequence to enable the alternate screen buffer.

=item C<disable_alt_buf()>

Returns the ANSI escape sequence to disable the alternate screen buffer.

=item C<format_line_break($width)>

Returns the ANSI escape sequence for a line break with the specified width.

=item C<format_shift_left($count)>

Returns the ANSI escape sequence to shift content left by C<$count> characters.

=item C<format_shift_right($count)>

Returns the ANSI escape sequence to shift content right by C<$count> characters.

=item C<format_insert_line($count)>

Returns the ANSI escape sequence to insert C<$count> blank lines.

=item C<format_delete_line($count)>

Returns the ANSI escape sequence to delete C<$count> lines.

=item C<format_delete_chars($count)>

Returns the ANSI escape sequence to delete C<$count> characters.

=item C<format_erase_chars($count)>

Returns the ANSI escape sequence to erase C<$count> characters.

=item C<format_repeat_char($char, $count)>

Returns the ANSI escape sequence to repeat C<$char> C<$count> times.

=back

=head2 Color Control (ANSI::Color)

=over 4

=item C<format_reset()>

Returns the ANSI escape sequence to reset all formatting.

=item C<format_fg_color($color)>

Returns the ANSI escape sequence to set the foreground (text) color.
C<$color> is an array ref of RGB values: C<[$red, $green, $blue]>.

=item C<format_bg_color($color)>

Returns the ANSI escape sequence to set the background color.
C<$color> is an array ref of RGB values: C<[$red, $green, $blue]>.

=item C<format_color($fg, $bg)>

Returns the ANSI escape sequence to set both foreground and background colors.
Both C<$fg> and C<$bg> are array refs of RGB values.

=back

=head2 Cursor Control (ANSI::Cursor)

=over 4

=item C<home_cursor()>

Returns the ANSI escape sequence to move the cursor to home position (0,0).

=item C<format_move_cursor($row, $col)>

Returns the ANSI escape sequence to move the cursor to the specified position.

=item C<format_move_up($by)>

Returns the ANSI escape sequence to move the cursor up by C<$by> rows.

=item C<format_move_down($by)>

Returns the ANSI escape sequence to move the cursor down by C<$by> rows.

=item C<format_move_left($by)>

Returns the ANSI escape sequence to move the cursor left by C<$by> columns.

=item C<format_move_right($by)>

Returns the ANSI escape sequence to move the cursor right by C<$by> columns.

=back

=head2 Mouse Control (ANSI::Mouse)

=over 4

=item C<enable_mouse_tracking($type)>

Returns the ANSI escape sequence to enable mouse tracking of the specified type.

=item C<disable_mouse_tracking($type)>

Returns the ANSI escape sequence to disable mouse tracking of the specified type.

=item C<ON_BUTTON_PRESS>

Constant for mouse tracking mode: track button press events only.

=item C<EVENTS_ON_BUTTON_PRESS>

Constant for mouse tracking mode: track button press and release events.

=item C<ALL_EVENTS>

Constant for mouse tracking mode: track all mouse events including motion.

=back

=head1 DEPENDENCIES

The C<tty::ansi> sub-feature requires:

=over 4

=item *

L<Term::ReadKey> - For terminal size and read mode operations

=back

=head1 EXAMPLE USAGE

=head2 Basic Terminal Control

    use grey::static qw[ tty::ansi ];

    # Setup terminal
    set_output_to_utf8();
    set_read_mode_to_raw();

    # Use alternate screen buffer
    print enable_alt_buf();
    print clear_screen();
    print hide_cursor();

    # Draw some colored text
    print format_move_cursor(5, 10);
    print format_fg_color([255, 0, 0]);
    print "Hello, World!";
    print format_reset();

    # Cleanup
    print show_cursor();
    print disable_alt_buf();
    restore_read_mode();

=head2 Interactive Application

    use grey::static qw[ tty::ansi ];

    # Initialize
    set_output_to_utf8();
    set_read_mode_to_raw();
    print enable_alt_buf();
    print clear_screen();
    print enable_mouse_tracking(ON_BUTTON_PRESS);

    my ($width, $height) = get_terminal_size();
    print format_move_cursor(1, 1);
    print "Terminal size: ${width}x${height}";

    # Your interactive loop here...

    # Cleanup
    print disable_mouse_tracking(ON_BUTTON_PRESS);
    print disable_alt_buf();
    restore_read_mode();

=head1 SEE ALSO

L<grey::static>, L<Term::ReadKey>

=head1 AUTHOR

grey::static

=cut

package ANSI;

use v5.42;
use experimental qw[ builtin ];
use builtin      qw[ export_lexically ];

use ANSI::Screen ();
use ANSI::Color  ();
use ANSI::Cursor ();
use ANSI::Mouse  ();

use Term::ReadKey qw[ GetTerminalSize ReadMode ];

sub import {
    export_lexically(
        # Terminal operations
        '&get_terminal_size'       => \&get_terminal_size,
        '&restore_read_mode'       => \&restore_read_mode,
        '&set_read_mode_to_normal' => \&set_read_mode_to_normal,
        '&set_read_mode_to_noecho' => \&set_read_mode_to_noecho,
        '&set_read_mode_to_raw'    => \&set_read_mode_to_raw,
        '&set_output_to_utf8'      => \&set_output_to_utf8,

        # Screen control
        '&clear_screen'            => \&ANSI::Screen::clear_screen,
        '&hide_cursor'             => \&ANSI::Screen::hide_cursor,
        '&show_cursor'             => \&ANSI::Screen::show_cursor,
        '&enable_alt_buf'          => \&ANSI::Screen::enable_alt_buf,
        '&disable_alt_buf'         => \&ANSI::Screen::disable_alt_buf,
        '&format_line_break'       => \&ANSI::Screen::format_line_break,
        '&format_shift_left'       => \&ANSI::Screen::format_shift_left,
        '&format_shift_right'      => \&ANSI::Screen::format_shift_right,
        '&format_insert_line'      => \&ANSI::Screen::format_insert_line,
        '&format_delete_line'      => \&ANSI::Screen::format_delete_line,
        '&format_delete_chars'     => \&ANSI::Screen::format_delete_chars,
        '&format_erase_chars'      => \&ANSI::Screen::format_erase_chars,
        '&format_repeat_char'      => \&ANSI::Screen::format_repeat_char,

        # Color control
        '&format_reset'            => \&ANSI::Color::format_reset,
        '&format_bg_color'         => \&ANSI::Color::format_bg_color,
        '&format_fg_color'         => \&ANSI::Color::format_fg_color,
        '&format_color'            => \&ANSI::Color::format_color,

        # Cursor control
        '&home_cursor'             => \&ANSI::Cursor::home_cursor,
        '&format_move_cursor'      => \&ANSI::Cursor::format_move_cursor,
        '&format_move_up'          => \&ANSI::Cursor::format_move_up,
        '&format_move_down'        => \&ANSI::Cursor::format_move_down,
        '&format_move_left'        => \&ANSI::Cursor::format_move_left,
        '&format_move_right'       => \&ANSI::Cursor::format_move_right,

        # Mouse control
        '&enable_mouse_tracking'   => \&ANSI::Mouse::enable_mouse_tracking,
        '&disable_mouse_tracking'  => \&ANSI::Mouse::disable_mouse_tracking,
        '&ON_BUTTON_PRESS'         => \&ANSI::Mouse::ON_BUTTON_PRESS,
        '&EVENTS_ON_BUTTON_PRESS'  => \&ANSI::Mouse::EVENTS_ON_BUTTON_PRESS,
        '&ALL_EVENTS'              => \&ANSI::Mouse::ALL_EVENTS,
    );
}


sub get_terminal_size { GetTerminalSize() }

sub set_output_to_utf8 ($fh=*STDOUT) { binmode($fh, ":encoding(UTF-8)") }

sub restore_read_mode       ($fh=*STDIN) { ReadMode restore => $fh }
sub set_read_mode_to_normal ($fh=*STDIN) { ReadMode normal  => $fh }
sub set_read_mode_to_noecho ($fh=*STDIN) { ReadMode noecho  => $fh }
sub set_read_mode_to_raw    ($fh=*STDIN) { ReadMode cbreak  => $fh }



__END__

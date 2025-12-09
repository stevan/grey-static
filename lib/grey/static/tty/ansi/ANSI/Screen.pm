package ANSI::Screen;

use v5.42;
use experimental qw[ builtin ];
use builtin      qw[ export_lexically ];

sub import {
    export_lexically(
        '&clear_screen'    => \&clear_screen,

        '&hide_cursor'     => \&hide_cursor,
        '&show_cursor'     => \&show_cursor,

        '&enable_alt_buf'  => \&enable_alt_buf,
        '&disable_alt_buf' => \&disable_alt_buf,

        '&format_line_break'   => \&format_line_break,

        '&format_shift_left'   => \&format_shift_left,
        '&format_shift_right'  => \&format_shift_right,

        '&format_insert_line'  => \&format_insert_line,
        '&format_delete_line'  => \&format_delete_line,

        '&format_delete_chars' => \&format_delete_chars,
        '&format_erase_chars'  => \&format_erase_chars,
        '&format_repeat_char'  => \&format_repeat_char,
    );
}

sub clear_screen { "\e[2J" }

sub hide_cursor  { "\e[?25l" }
sub show_cursor  { "\e[?25h" }

sub enable_alt_buf  { "\e[?1049h" }
sub disable_alt_buf { "\e[?1049l" }

sub format_line_break ($width) { sprintf "\e[B\e[%dD" => $width }

sub format_shift_left  ($count=0) { sprintf "\e[%d \@"  => $count }
sub format_shift_right ($count=0) { sprintf "\e[%d A"  => $count }

sub format_insert_line  ($count=1) { sprintf "\e[%dL"  => $count }
sub format_delete_line  ($count=1) { sprintf "\e[%dM"  => $count }

sub format_delete_chars ($count=1) { sprintf "\e[%dP"  => $count }
sub format_erase_chars ($count=0) { sprintf "\e[%dX"  => $count }
sub format_repeat_char ($char, $count=0) { sprintf "%s\e[%db"  => $char, $count }

__END__

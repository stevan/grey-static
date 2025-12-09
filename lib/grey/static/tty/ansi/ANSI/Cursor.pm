package ANSI::Cursor;

use v5.42;
use experimental qw[ builtin ];
use builtin      qw[ export_lexically ];

sub import {
    export_lexically(
        '&home_cursor'         => \&home_cursor,
        '&format_move_cursor'  => \&format_move_cursor,

        '&format_move_up'      => \&format_move_up,
        '&format_move_down'    => \&format_move_down,
        '&format_move_left'    => \&format_move_left,
        '&format_move_right'   => \&format_move_right,
    );
}

sub home_cursor  { "\e[H" }

sub format_move_cursor   (@to) { sprintf "\e[%d;%dH"  => @to    }

sub format_move_up    ($by) { sprintf "\e[%dA"  => $by }
sub format_move_down  ($by) { sprintf "\e[%dB"  => $by }
sub format_move_left  ($by) { sprintf "\e[%dD"  => $by }
sub format_move_right ($by) { sprintf "\e[%dC"  => $by }


__END__

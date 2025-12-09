#!perl
# Basic ANSI functionality tests

use v5.42;
use Test::More;

use grey::static qw[ tty::ansi ];

# Test screen control functions
subtest 'screen control' => sub {
    is(clear_screen(), "\e[2J", 'clear_screen returns correct sequence');
    is(hide_cursor(), "\e[?25l", 'hide_cursor returns correct sequence');
    is(show_cursor(), "\e[?25h", 'show_cursor returns correct sequence');
    is(enable_alt_buf(), "\e[?1049h", 'enable_alt_buf returns correct sequence');
    is(disable_alt_buf(), "\e[?1049l", 'disable_alt_buf returns correct sequence');
};

# Test color functions
subtest 'color control' => sub {
    is(format_reset(), "\e[0m", 'format_reset returns correct sequence');
    is(format_fg_color([255, 0, 0]), "\e[38;2;255;0;0;m", 'format_fg_color red');
    is(format_bg_color([0, 255, 0]), "\e[48;2;0;255;0;m", 'format_bg_color green');
    is(format_color([255, 0, 0], [0, 0, 255]),
       "\e[38;2;255;0;0;48;2;0;0;255;m",
       'format_color combined');
};

# Test cursor control functions
subtest 'cursor control' => sub {
    is(home_cursor(), "\e[H", 'home_cursor returns correct sequence');
    is(format_move_cursor(10, 20), "\e[10;20H", 'format_move_cursor');
    is(format_move_up(5), "\e[5A", 'format_move_up');
    is(format_move_down(3), "\e[3B", 'format_move_down');
    is(format_move_left(2), "\e[2D", 'format_move_left');
    is(format_move_right(7), "\e[7C", 'format_move_right');
};

# Test mouse tracking functions
subtest 'mouse control' => sub {
    is(enable_mouse_tracking(ON_BUTTON_PRESS), "\e[?1001;1006h",
       'enable_mouse_tracking ON_BUTTON_PRESS');
    is(disable_mouse_tracking(ON_BUTTON_PRESS), "\e[?1001;1006l",
       'disable_mouse_tracking ON_BUTTON_PRESS');

    # Test constants
    is(ON_BUTTON_PRESS, 1001, 'ON_BUTTON_PRESS constant');
    is(EVENTS_ON_BUTTON_PRESS, 1002, 'EVENTS_ON_BUTTON_PRESS constant');
    is(ALL_EVENTS, 1003, 'ALL_EVENTS constant');
};

# Test terminal operations
subtest 'terminal operations' => sub {
    # get_terminal_size requires a terminal, so we just check it exists
    ok(defined &get_terminal_size, 'get_terminal_size function exists');
    ok(defined &set_output_to_utf8, 'set_output_to_utf8 function exists');
    ok(defined &restore_read_mode, 'restore_read_mode function exists');
    ok(defined &set_read_mode_to_normal, 'set_read_mode_to_normal function exists');
    ok(defined &set_read_mode_to_noecho, 'set_read_mode_to_noecho function exists');
    ok(defined &set_read_mode_to_raw, 'set_read_mode_to_raw function exists');
};

done_testing;

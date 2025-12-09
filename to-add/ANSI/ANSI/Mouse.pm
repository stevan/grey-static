package ANSI::Mouse;

use v5.38;
use experimental qw[ builtin ];
use builtin      qw[ export_lexically ];

sub import {
    export_lexically(
        '&enable_mouse_tracking'  => \&enable_mouse_tracking,
        '&disable_mouse_tracking' => \&disable_mouse_tracking,

        '&ON_BUTTON_PRESS'        => \&ON_BUTTON_PRESS,
        '&EVENTS_ON_BUTTON_PRESS' => \&EVENTS_ON_BUTTON_PRESS,
        '&ALL_EVENTS'             => \&ALL_EVENTS,
    );
}

use constant ON_BUTTON_PRESS        => 1001;
use constant EVENTS_ON_BUTTON_PRESS => 1002;
use constant ALL_EVENTS             => 1003;

sub enable_mouse_tracking  ($type) { "\e[?${type};1006h" }
sub disable_mouse_tracking ($type) { "\e[?${type};1006l" }


__END__

package ANSI::Color;

use v5.42;
use experimental qw[ builtin ];
use builtin      qw[ export_lexically ];

sub import {
    export_lexically(
        '&format_reset'        => \&format_reset,
        '&format_bg_color'     => \&format_bg_color,
        '&format_fg_color'     => \&format_fg_color,
        '&format_color'        => \&format_color,
    );
}

sub format_reset               { "\e[0m" }
sub format_bg_color ($color)   { sprintf "\e[48;2;%d;%d;%d;m" => @$color }
sub format_fg_color ($color)   { sprintf "\e[38;2;%d;%d;%d;m" => @$color }
sub format_color    ($fg, $bg) { sprintf "\e[38;2;%d;%d;%d;48;2;%d;%d;%d;m"  => @$fg, @$bg }

__END__

use v5.40;
use experimental qw[ builtin ];
use builtin      qw[ export_lexically ];
no warnings 'shadow';

use importer 'Scalar::Util' => qw[ blessed refaddr ];
use importer 'List::Util'   => qw[ min max ];

package grey::static::logging;

our $VERSION = '0.01';

my $TERM_WIDTH = eval { (require Term::ReadKey && Term::ReadKey::GetTerminalSize())[0] } // 80;
my %TARGET_TO_COLOR;

my sub get_color_for($t) {
    $TARGET_TO_COLOR{ $t } //= [ map { 100 + (int(rand(15)) * 10) } 1,2,3 ]
}

my sub colorize ($target) {
    sprintf "\e[38;2;%d;%d;%d;m%s\e[0m" => get_color_for($target)->@*, $target;
}

my sub colorize_from_target ($target, $string) {
    sprintf "\e[38;2;%d;%d;%d;m%s\e[0m" => get_color_for($target)->@*, $string;
}

my sub colorize_by_depth ($depth, $string) {
   sprintf "\e[48;2;%d;%d;0m%s\e[0m",
        min(255, (50  + ($depth * 5))),
        max(0,   (200 - ($depth * 5))),
        $string;
}

my sub decorate ($msg) {
    $msg =~ s/\n/\\n/g;
    $msg =~ s/([A-Z][A-Za-z::]+)\=OBJECT\(0x([0-9a-f]+)\)/colorize($1.'['.$2.']')/ge;
    $msg =~ s/([A-Z][A-Za-z]+\:\:)\s/colorize($1) /ge;
    $msg =~ s/m\<([A-Za-z0-9,\@\(\)]+)\>/'m<'.colorize($1).'>'/ge;
    $msg =~ s/^(\d+)/colorize_by_depth($1, sprintf "[%02d]" => $1)/ge;
    $msg =~ s/INFO\((.*)\)/colorize('INFO').'('.colorize($1).')'/ge;
    $msg =~ s/\s\-\>\s(\w+)\s/' -> '.colorize($1).' '/ge;
    $msg =~ s/(\# .*)$/"\e[36m$1\e[0m"/ge;
    $msg;
}

my sub format_parameters ($args) {
    return '' unless $args;
    my $params = join ', ' => map {
        sprintf '%s : %s' => $_, (blessed $args->{$_}
            ? $args->{$_}
            : '<'.($args->{$_} // '~').'>')
    } sort { $a cmp $b } keys %$args;
    $params = "($params)";
    $params;
}

my sub format_message ($depth, $from, $msg, $params) {
    return sprintf "%s%s%s -> %s %s" =>
            $depth,
            (' ' x $depth),
            $from, $msg, format_parameters( $params );
}

sub DIV ($label) {
    my $width = ($TERM_WIDTH - ((length $label) + 6));
    $width = 10 if $width < 10;
    say "\e[2m",'====[', $label, ']', ('=' x $width),"\e[0m";
}

sub INFO ($msg, $params=undef) {
    my $depth = 0;
    1 while (caller($depth++));

    say decorate format_message(
        $depth,
        (sprintf 'INFO(%s)' => scalar(caller())),
        $msg,
        $params
    );
}

sub LOG ($from, @rest) {
    my $depth = 0;
    1 while (caller($depth++));

    $from .= '::' unless blessed $from;

    my $params;
    if (ref $rest[-1]) {
        $params = pop @rest;
    }

    my ($msg) = @rest;
    $msg //= (split '::', (caller(1))[3])[-1];

    say decorate format_message(
        $depth - 1,
        $from,
        $msg,
        $params
    );
}

sub OPEN ($from) {
    my $depth = 0;
    1 while (caller($depth++));

    my $sender = $from;
    my $label  = '[0]open ! ';
    my $width  = ($TERM_WIDTH - (length($sender) + length($label) + $depth + 3));
    $width = 10 if $width < 10;

    say sprintf '%s%s%s%s%s' => (
        colorize_by_depth($depth, sprintf "\e[7m<%02d>\e[0m" => $depth),
        colorize_from_target($sender, ('▓' x ($depth - 1))),
        colorize_from_target($sender, $label),
        decorate($sender),
        colorize_from_target($sender, ('▓' x $width)),
    );
}

sub CLOSE ($from) {
    my $depth = 0;
    1 while (caller($depth++));

    my $sender = $from;
    my $label  = '[-]close ! ';
    my $width  = ($TERM_WIDTH - (length($sender) + length($label) + $depth + 3));
    $width = 10 if $width < 10;

    say sprintf '%s%s%s%s%s' => (
        colorize_by_depth($depth, sprintf "\e[7m<%02d>\e[0m" => $depth),
        colorize_from_target($sender, ('▓' x ($depth - 1))),
        colorize_from_target($sender, $label),
        decorate($sender),
        colorize_from_target($sender, ('▓' x $width)),
    );
}

sub TICK ($from) {
    state %counter;

    my $depth = 0;
    1 while (caller($depth++));

    my $count = $counter{ refaddr $from }++;

    my $sender = $from;
    my $label  = sprintf '[%d]tick ! ' => $count;
    my $width  = ($TERM_WIDTH - (length($sender) + length($label) + $depth + 3));
    $width = 10 if $width < 10;

    say sprintf '%s%s%s%s%s' => (
        colorize_by_depth($depth, sprintf "\e[7m<%02d>\e[0m" => $depth),
        colorize_from_target($sender, ('░' x ($depth - 1))),
        colorize_from_target($sender, $label),
        decorate($sender),
        colorize_from_target($sender, ('░' x $width)),
    );
}

sub import {
    my $class = shift;
    export_lexically(
        '&LOG'   => \&LOG,
        '&INFO'  => \&INFO,
        '&DIV'   => \&DIV,
        '&TICK'  => \&TICK,
        '&OPEN'  => \&OPEN,
        '&CLOSE' => \&CLOSE,
        '&DEBUG' => $ENV{DEBUG} ? sub :const { 1 } : sub :const { 0 },
    );
}

1;

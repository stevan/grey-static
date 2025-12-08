use v5.42;
use utf8;
use experimental qw(builtin);
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

__END__

=pod

=encoding UTF-8

=head1 NAME

grey::static::logging - Debug logging utilities

=head1 SYNOPSIS

    use grey::static qw[ logging ];

    # Basic logging
    LOG $self, "processing data";
    LOG $self, "found item", { id => 42, name => "foo" };

    # Info logging
    INFO "application started";
    INFO "config loaded", { port => 8080, host => "localhost" };

    # Visual dividers
    DIV "Section Title";

    # Lifecycle tracking
    OPEN $self;   # Mark object/section opening
    TICK $self;   # Mark progress tick
    CLOSE $self;  # Mark object/section closing

    # Conditional logging with DEBUG
    LOG $self, "expensive debug info" if DEBUG;

=head1 DESCRIPTION

The C<logging> feature provides debug logging utilities with colorized output
and automatic call depth tracking. All functions are exported lexically into
the calling scope.

Logging output is controlled by the C<DEBUG> environment variable. When
C<DEBUG> is not set, the C<DEBUG> constant is false, allowing the compiler to
optimize away conditional logging code.

=head1 EXPORTED FUNCTIONS

=head2 LOG

    LOG $from, $message;
    LOG $from, $message, \%params;

Logs a message with automatic depth tracking and colorization.

=over 4

=item C<$from>

The object or package name to log from. If an object (blessed reference), uses
the class name. If a string, appends C<::> to format as a package name.

=item C<$message>

The message to log. If not provided, uses the calling subroutine name.

=item C<\%params>

Optional hashref of parameters to display with the message.

=back

Output format: C<< <depth> <from> -> <message> <params> >>

=head2 INFO

    INFO $message;
    INFO $message, \%params;

Logs an informational message from the current package.

=over 4

=item C<$message>

The message to log.

=item C<\%params>

Optional hashref of parameters to display with the message.

=back

Output is prefixed with C<INFO(Package::Name)>.

=head2 DIV

    DIV $label;

Prints a visual divider line with the given label.

=over 4

=item C<$label>

Text to display in the divider.

=back

Output format: C<====[label]=====================================>

=head2 OPEN

    OPEN $from;

Marks the opening of a section or object lifecycle with a visual banner.

=over 4

=item C<$from>

The object or identifier for the section being opened.

=back

=head2 CLOSE

    CLOSE $from;

Marks the closing of a section or object lifecycle with a visual banner.

=over 4

=item C<$from>

The object or identifier for the section being closed.

=back

=head2 TICK

    TICK $from;

Marks a progress tick for the given object, with automatic counter increment.

=over 4

=item C<$from>

The object to track ticks for. Maintains a separate counter per object (by refaddr).

=back

Each call increments the tick counter for that object, displayed as C<[n]tick>.

=head2 DEBUG

    if (DEBUG) {
        # expensive debug operations
    }

Constant boolean indicating whether debug mode is enabled. Returns true if
the C<DEBUG> environment variable is set, false otherwise.

This is a compile-time constant, allowing the Perl compiler to optimize away
entire debug blocks when C<DEBUG> is false.

=head1 OUTPUT COLORIZATION

All output is automatically colorized using ANSI escape codes with RGB colors.
Colors are:

=over 4

=item *

Depth indicators use a gradient from green to yellow based on call depth

=item *

Object/package names are assigned consistent random colors

=item *

Special patterns (class names, method calls, info tags) are highlighted

=back

=head1 ENVIRONMENT

=over 4

=item C<DEBUG>

When set to a true value, enables the C<DEBUG> constant. When not set or false,
C<DEBUG> is a compile-time constant false, allowing the compiler to eliminate
debug code.

=back

=head1 SEE ALSO

L<grey::static>, L<grey::static::diagnostics>

=head1 AUTHOR

grey::static

=cut

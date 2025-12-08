use v5.42;
use utf8;
use experimental qw(class);
use Scalar::Util qw(refaddr blessed);

package grey::static::diagnostics;

our $VERSION = '0.01';

# Configuration via package globals
our $NO_COLOR = 0;
our $NO_BACKTRACE = 0;
our $NO_SYNTAX_HIGHLIGHT = 0;

# ANSI color codes
my %COLORS = (
    reset       => "\e[0m",
    bold        => "\e[1m",
    dim         => "\e[2m",
    red         => "\e[31m",
    green       => "\e[32m",
    yellow      => "\e[33m",
    blue        => "\e[34m",
    magenta     => "\e[35m",
    cyan        => "\e[36m",
    white       => "\e[37m",
    bold_red    => "\e[1;31m",
    bold_yellow => "\e[1;33m",
    bold_blue   => "\e[1;34m",
    bold_cyan   => "\e[1;36m",
    bold_green  => "\e[1;32m",
    bold_magenta => "\e[1;35m",
    # Syntax highlighting colors
    syn_keyword => "\e[1;35m",   # bold magenta for keywords
    syn_string  => "\e[32m",     # green for strings
    syn_comment => "\e[2;37m",   # dim white for comments
    syn_var     => "\e[36m",     # cyan for variables
    syn_number  => "\e[33m",     # yellow for numbers
    syn_sub     => "\e[1;33m",   # bold yellow for sub names
);

# Unicode box drawing characters
my %BOX = (
    v_line     => '│',
    h_line     => '─',
    top_left   => '╭',
    top_right  => '╮',
    bot_left   => '╰',
    bot_right  => '╯',
    tee_right  => '├',
    tee_left   => '┤',
    arrow      => '▶',
    dot        => '•',
);

# Perl keywords for syntax highlighting
my $KEYWORDS = qr/\b(
    my|our|local|state|
    sub|method|field|class|role|
    if|elsif|else|unless|
    while|until|for|foreach|loop|
    do|given|when|default|
    return|last|next|redo|goto|
    use|no|require|package|
    die|warn|print|say|
    defined|undef|ref|bless|
    push|pop|shift|unshift|splice|
    keys|values|each|exists|delete|
    open|close|read|write|seek|tell|
    chomp|chop|length|substr|index|
    split|join|sort|reverse|map|grep|
    scalar|wantarray|caller|
    eval|try|catch|finally|
    BEGIN|END|CHECK|INIT|UNITCHECK|
    DESTROY|AUTOLOAD|
    and|or|not|eq|ne|lt|gt|le|ge|cmp|
    true|false|isa
)\b/x;

# Whether to use colors (check if terminal supports it)
my $use_colors = -t STDERR;

sub _use_colors { !$NO_COLOR && $use_colors }
sub _show_backtrace { !$NO_BACKTRACE }
sub _syntax_highlight { !$NO_SYNTAX_HIGHLIGHT }

# Syntax highlight a line of Perl code
sub _highlight_syntax {
    my ($line) = @_;
    return $line unless _use_colors() && _syntax_highlight();

    my $reset = $COLORS{reset};
    my $result = '';
    my $pos = 0;

    while ($pos < length($line)) {
        my $rest = substr($line, $pos);

        # Comments - must check first, highest priority
        if ($rest =~ /^(\#.*)/) {
            $result .= $COLORS{syn_comment} . $1 . $reset;
            $pos += length($1);
        }
        # Double-quoted strings
        elsif ($rest =~ /^("(?:[^"\\]|\\.)*")/) {
            $result .= $COLORS{syn_string} . $1 . $reset;
            $pos += length($1);
        }
        # Single-quoted strings
        elsif ($rest =~ /^('(?:[^'\\]|\\.)*')/) {
            $result .= $COLORS{syn_string} . $1 . $reset;
            $pos += length($1);
        }
        # qw// strings
        elsif ($rest =~ /^(qw\s*[\(\[\{\/\|].*?[\)\]\}\/\|])/) {
            $result .= $COLORS{syn_string} . $1 . $reset;
            $pos += length($1);
        }
        # Variables: $scalar, @array, %hash, $obj->method
        elsif ($rest =~ /^([\$\@\%][\w:]+(?:->[\w]+)?)/) {
            $result .= $COLORS{syn_var} . $1 . $reset;
            $pos += length($1);
        }
        # Special variables: $_, $1, $$, etc
        elsif ($rest =~ /^(\$(?:\d+|[_\$\&\`\'\+\.\,\;\"\\\|]))/) {
            $result .= $COLORS{syn_var} . $1 . $reset;
            $pos += length($1);
        }
        # Sub definitions: sub name, method name
        elsif ($rest =~ /^((?:sub|method|field)\s+)(\w+)/) {
            $result .= $COLORS{syn_keyword} . $1 . $reset;
            $result .= $COLORS{syn_sub} . $2 . $reset;
            $pos += length($1) + length($2);
        }
        # Keywords
        elsif ($rest =~ /^$KEYWORDS/) {
            my $kw = $1;
            $result .= $COLORS{syn_keyword} . $kw . $reset;
            $pos += length($kw);
        }
        # Numbers
        elsif ($rest =~ /^(0x[0-9a-fA-F_]+|0b[01_]+|0[0-7_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?)/) {
            $result .= $COLORS{syn_number} . $1 . $reset;
            $pos += length($1);
        }
        # Default: single character
        else {
            $result .= substr($line, $pos, 1);
            $pos++;
        }
    }

    return $result;
}

# Format a single argument value for display
sub _format_arg {
    my ($arg) = @_;

    return 'undef' unless defined $arg;

    my $ref = ref $arg;
    if (!$ref) {
        my $str = "$arg";
        if (length($str) > 50) {
            $str = substr($str, 0, 47) . '...';
        }
        if ($str =~ /[^0-9.\-+eE]/ || $str eq '') {
            $str =~ s/\\/\\\\/g;
            $str =~ s/"/\\"/g;
            $str =~ s/\n/\\n/g;
            $str =~ s/\t/\\t/g;
            return qq{"$str"};
        }
        return $str;
    }

    my $addr = refaddr($arg);
    my $addr_hex = sprintf("0x%x", $addr);

    if (blessed($arg)) {
        return "$ref($addr_hex)";
    }

    return "$ref($addr_hex)";
}

sub _format_args {
    my ($args) = @_;
    return '' unless $args && @$args;

    my @formatted = map { _format_arg($_) } @$args;
    return '(' . join(', ', @formatted) . ')';
}

# Capture the current stack trace using DB package to get args
sub _capture_stack {
    my ($skip_levels) = @_;
    $skip_levels //= 0;

    my @frames;
    my $level = $skip_levels;

    package DB {
        while (my @caller_info = caller($level)) {
            my ($package, $filename, $line, $subroutine, $hasargs, $wantarray) = @caller_info;

            my @args_copy;
            if ($hasargs && @DB::args) {
                @args_copy = @DB::args;
            }

            my $skip = 0;
            $skip = 1 if $subroutine && $subroutine =~ /^grey::static::/;
            $skip = 1 if $filename =~ /^\(eval/;

            unless ($skip) {
                push @frames, grey::static::diagnostics::StackFrame->new(
                    package    => $package,
                    filename   => $filename,
                    line       => $line,
                    subroutine => $subroutine // "${package}::__ANON__",
                    hasargs    => $hasargs // 0,
                    wantarray  => $wantarray,
                    args       => $hasargs ? \@args_copy : undef,
                );
            }
            $level++;
        }
    }

    return \@frames;
}

# Parse error message to extract file and line information
sub _parse_error {
    my ($error) = @_;

    chomp($error);

    if ($error =~ /^(.+?)\s+at\s+(.+?)\s+line\s+(\d+)/) {
        my ($message, $file, $line) = ($1, $2, $3);
        return ($message, $file, $line);
    }

    return ($error, undef, undef);
}

# The die handler
sub _die_handler {
    my ($error) = @_;

    return if $^S;

    my $frames = _capture_stack(1);

    my ($message, $file, $line) = _parse_error($error);

    if (!defined $file || !defined $line) {
        my $level = 0;
        while (my @caller = caller($level)) {
            if ($caller[0] !~ /^grey::static::/ && $caller[1] !~ /^\(eval/) {
                $file //= $caller[1];
                $line //= $caller[2];
                last;
            }
            $level++;
        }
    }

    my $formatter = grey::static::diagnostics::Formatter->new(context_lines => 2);
    my $formatted = $formatter->format_error($message, $file // 'unknown', $line // 0, $frames);

    die $formatted;
}

# The warn handler
sub _warn_handler {
    my ($warning) = @_;

    my $frames = _capture_stack(1);

    my ($message, $file, $line) = _parse_error($warning);

    if (!defined $file || !defined $line) {
        my $level = 0;
        while (my @caller = caller($level)) {
            if ($caller[0] !~ /^grey::static::/ && $caller[1] !~ /^\(eval/) {
                $file //= $caller[1];
                $line //= $caller[2];
                last;
            }
            $level++;
        }
    }

    my $formatter = grey::static::diagnostics::Formatter->new(context_lines => 2);
    my $formatted = $formatter->format_warning($message, $file // 'unknown', $line // 0, $frames);

    warn $formatted;
}

sub import {
    my $class = shift;
    $SIG{__DIE__} = \&_die_handler;
    $SIG{__WARN__} = \&_warn_handler;
}


class grey::static::diagnostics::StackFrame {
    field $package :param;
    field $filename :param;
    field $line :param;
    field $subroutine :param;
    field $hasargs :param = 0;
    field $wantarray :param = undef;
    field $args :param = undef;

    method package    { $package }
    method filename   { $filename }
    method line       { $line }
    method subroutine { $subroutine }
    method hasargs    { $hasargs }
    method wantarray  { $wantarray }
    method args       { $args }

    method short_sub {
        my $sub = $subroutine // '(main)';
        return $sub;
    }
}

class grey::static::diagnostics::Formatter {
    field $context_lines :param = 2;

    method color ($name, $text) {
        return $text unless grey::static::diagnostics::_use_colors();
        return ($COLORS{$name} // '') . $text . $COLORS{reset};
    }

    method format_error ($message, $file, $line, $frames = undef) {
        return $self->_format_message('error', 'bold_red', $message, $file, $line, $frames);
    }

    method format_warning ($message, $file, $line, $frames = undef) {
        return $self->_format_message('warning', 'bold_yellow', $message, $file, $line, $frames);
    }

    method _format_message ($level, $level_color, $message, $file, $line, $frames = undef) {
        my $output = "";

        $output .= $self->color($level_color, $level) . ': ';
        $output .= $self->color('bold', $message) . "\n";

        $output .= '   ' . $self->color('bold_blue', " $BOX{top_left}$BOX{h_line}\[") ;
        $output .= $self->color('cyan', "$file:$line");
        $output .= $self->color('bold_blue', ']') . "\n";

        my $source = grey::static::source->get_source($file);
        if ($source && $line > 0) {
            $output .= $self->_format_source_context($source, $line, $level_color, $level);
        } else {
            $output .= '   ' . $self->color('bold_blue', $BOX{bot_left}) . "\n";
        }

        if ($frames && @$frames && grey::static::diagnostics::_show_backtrace()) {
            $output .= $self->_format_backtrace($frames);
        }

        return $output;
    }

    method _format_backtrace ($frames) {
        my $output = "\n";
        $output .= $self->color('bold', "stack backtrace:") . "\n";

        my $frame_num = 0;
        my $last_frame = $#$frames;

        for my $frame (@$frames) {
            my $is_last = ($frame_num == $last_frame);

            my $connector = $is_last ? $BOX{bot_left} : $BOX{tee_right};
            my $continue  = $is_last ? ' ' : $BOX{v_line};

            $output .= '   ' . $self->color('bold_blue', "$connector$BOX{h_line}");
            $output .= $self->color('bold_cyan', "[$frame_num]") . ' ';
            $output .= $self->color('bold', $frame->short_sub);

            if ($frame->args && @{$frame->args}) {
                $output .= $self->color('cyan', grey::static::diagnostics::_format_args($frame->args));
            }
            $output .= "\n";

            $output .= '   ' . $self->color('bold_blue', "$continue    ");
            $output .= $self->color('cyan', 'at ');
            $output .= $frame->filename . ':' . $frame->line . "\n";

            my $source = grey::static::source->get_source($frame->filename);
            if ($source && $frame->line > 0) {
                my $line_content = $source->get_line($frame->line);
                if (defined $line_content) {
                    my $line_num = $frame->line;
                    $output .= '   ' . $self->color('bold_blue', "$continue    ");
                    $output .= $self->color('dim', "$line_num $BOX{v_line}$line_content");
                }
            }

            $output .= "\n" if !$is_last;
            $frame_num++;
        }

        return $output."\n";
    }

    method _format_source_context ($source, $error_line, $level_color = 'bold_red', $level = 'error') {
        my $output = "";
        my $line_count = $source->line_count;

        my $start = $error_line - $context_lines;
        my $end = $error_line + $context_lines;

        $start = 1 if $start < 1;
        $end = $line_count if $end > $line_count;

        my $gutter_width = length($end);
        my $gutter_pad = ' ' x $gutter_width;

        for my $num ($start .. $end) {
            my $line_content = $source->get_line($num) // '';
            my $gutter = sprintf("%${gutter_width}d", $num);

            if ($num == $error_line) {
                $output .= $self->color('bold_blue', " $gutter $BOX{v_line}");
                $output .= grey::static::diagnostics::_highlight_syntax($line_content) . "\n";

                my $content_length = length($line_content);
                $content_length = 1 if $content_length == 0;

                my $leading_space = $line_content =~ /^(\s*)/ ? length($1) : 0;
                my $pointer_length = $content_length - $leading_space;
                $pointer_length = 1 if $pointer_length < 1;

                $output .= $self->color('bold_blue', " $gutter_pad $BOX{v_line}");
                $output .= ' ' x $leading_space;
                $output .= $self->color($level_color, "$BOX{bot_left}" . ($BOX{h_line} x ($pointer_length - 1)));
                $output .= $self->color($level_color, " $level occurred here");
                $output .= "\n";
            } else {
                $output .= $self->color('bold_blue', " $gutter $BOX{v_line}");
                $output .= $self->color('dim', $line_content) . "\n";
            }
        }

        $output .= $self->color('bold_blue', " $gutter_pad $BOX{bot_left}") . "\n";

        return $output;
    }
}

1;

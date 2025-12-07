use v5.40;
use experimental qw(class);
use Scalar::Util qw(refaddr blessed);

package BetterErrors;

our $VERSION = '0.01';

# ANSI color codes
my %COLORS = (
    reset     => "\e[0m",
    bold      => "\e[1m",
    dim       => "\e[2m",
    red       => "\e[31m",
    green     => "\e[32m",
    yellow    => "\e[33m",
    blue      => "\e[34m",
    magenta   => "\e[35m",
    cyan      => "\e[36m",
    white     => "\e[37m",
    bold_red  => "\e[1;31m",
    bold_blue => "\e[1;34m",
    bold_cyan => "\e[1;36m",
);

# Unicode box drawing characters
my %BOX = (
    v_line     => '│',   # vertical line
    h_line     => '─',   # horizontal line
    top_left   => '╭',   # rounded top-left corner
    top_right  => '╮',   # rounded top-right corner
    bot_left   => '╰',   # rounded bottom-left corner
    bot_right  => '╯',   # rounded bottom-right corner
    tee_right  => '├',   # tee pointing right
    tee_left   => '┤',   # tee pointing left
    arrow      => '▶',   # arrow pointer
    dot        => '•',   # bullet point
);

# Global source cache
my %SOURCE_CACHE;

# Whether to use colors (check if terminal supports it)
my $USE_COLORS = -t STDERR;

# Whether to show stack traces
my $SHOW_BACKTRACE = 1;

class BetterErrors::SourceFile {
    field $path :param;
    field @lines;
    field $loaded = 0;

    method path { $path }

    method load {
        return if $loaded;

        if (open my $fh, '<', $path) {
            @lines = <$fh>;
            close $fh;
            chomp @lines;
        }
        $loaded = 1;
    }

    method get_line ($line_num) {
        $self->load;
        return undef if $line_num < 1 || $line_num > @lines;
        return $lines[$line_num - 1];
    }

    method get_lines ($start, $end) {
        $self->load;
        $start = 1 if $start < 1;
        $end = @lines if $end > @lines;
        return () if $start > $end;
        return @lines[$start - 1 .. $end - 1];
    }

    method line_count {
        $self->load;
        return scalar @lines;
    }
}

class BetterErrors::StackFrame {
    field $package :param;
    field $filename :param;
    field $line :param;
    field $subroutine :param;
    field $hasargs :param = 0;
    field $wantarray :param = undef;
    field $args :param = undef;  # arrayref of arguments

    method package    { $package }
    method filename   { $filename }
    method line       { $line }
    method subroutine { $subroutine }
    method hasargs    { $hasargs }
    method wantarray  { $wantarray }
    method args       { $args }

    method short_sub {
        # Return just the subroutine name without package for display
        my $sub = $subroutine // '(main)';
        return $sub;
    }
}

class BetterErrors::ErrorFormatter {
    field $context_lines :param = 2;

    method color ($name, $text) {
        return $text unless $USE_COLORS;
        return ($COLORS{$name} // '') . $text . $COLORS{reset};
    }

    method format_error ($message, $file, $line, $frames = undef) {
        my $output = "";

        # Header: error: message
        $output .= $self->color('bold_red', 'error') . ': ';
        $output .= $self->color('bold', $message) . "\n";

        # Location header with box drawing
        $output .= '   ' . $self->color('bold_blue', " $BOX{top_left}$BOX{h_line}\[") ;
        $output .= $self->color('cyan', "$file:$line");
        $output .= $self->color('bold_blue', ']') . "\n";

        # Get source context
        my $source = $self->_get_source($file);
        if ($source && $line > 0) {
            $output .= $self->_format_source_context($source, $line);
        } else {
            $output .= '   ' . $self->color('bold_blue', $BOX{bot_left}) . "\n";
        }

        # Add stack backtrace if frames provided
        if ($frames && @$frames && $SHOW_BACKTRACE) {
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

            # Frame connector
            my $connector = $is_last ? $BOX{bot_left} : $BOX{tee_right};
            my $continue  = $is_last ? ' ' : $BOX{v_line};

            # Frame number and subroutine
            $output .= '   ' . $self->color('bold_blue', "$connector$BOX{h_line}");
            $output .= $self->color('bold_cyan', "[$frame_num]") . ' ';
            $output .= $self->color('bold', $frame->short_sub);

            # Add formatted arguments if available
            if ($frame->args && @{$frame->args}) {
                $output .= $self->color('cyan', BetterErrors::_format_args($frame->args));
            }
            $output .= "\n";

            # Location line
            $output .= '   ' . $self->color('bold_blue', "$continue    ");
            $output .= $self->color('cyan', 'at ');
            $output .= $frame->filename . ':' . $frame->line . "\n";

            # Show source context for this frame
            my $source = $self->_get_source($frame->filename);
            if ($source && $frame->line > 0) {
                my $line_content = $source->get_line($frame->line);
                if (defined $line_content) {
                    my $line_num = $frame->line;
                    $output .= '   ' . $self->color('bold_blue', "$continue    ");
                    $output .= $self->color('dim', "$line_num $BOX{v_line}");
                    $output .= $self->color('dim', $line_content);
                }
            }

            $output .= "\n" if !$is_last;  # Add spacing between frames
            $frame_num++;
        }

        return $output."\n";
    }

    method _get_source ($file) {
        return undef unless defined $file && -f $file;

        $SOURCE_CACHE{$file} //= BetterErrors::SourceFile->new(path => $file);
        return $SOURCE_CACHE{$file};
    }

    method _format_source_context ($source, $error_line) {
        my $output = "";
        my $line_count = $source->line_count;

        my $start = $error_line - $context_lines;
        my $end = $error_line + $context_lines;

        $start = 1 if $start < 1;
        $end = $line_count if $end > $line_count;

        # Calculate gutter width for line numbers
        my $gutter_width = length($end);
        my $gutter_pad = ' ' x $gutter_width;

        for my $num ($start .. $end) {
            my $line_content = $source->get_line($num) // '';
            my $gutter = sprintf("%${gutter_width}d", $num);

            if ($num == $error_line) {
                # Highlight the error line
                $output .= $self->color('bold_blue', " $gutter $BOX{v_line}");
                $output .= $self->color('bold', $line_content) . "\n";

                # Add the pointer line with box drawing
                my $content_length = length($line_content);
                $content_length = 1 if $content_length == 0;

                # Point to the whole line (we don't know exact column)
                my $leading_space = $line_content =~ /^(\s*)/ ? length($1) : 0;
                my $pointer_length = $content_length - $leading_space;
                $pointer_length = 1 if $pointer_length < 1;

                $output .= $self->color('bold_blue', " $gutter_pad $BOX{v_line}");
                $output .= ' ' x $leading_space;
                $output .= $self->color('bold_red', "$BOX{bot_left}" . ($BOX{h_line} x ($pointer_length - 1)));
                $output .= $self->color('bold_red', " error occurred here");
                $output .= "\n";
            } else {
                $output .= $self->color('bold_blue', " $gutter $BOX{v_line}");
                $output .= $self->color('dim', $line_content) . "\n";
            }
        }

        # Closing line
        $output .= $self->color('bold_blue', " $gutter_pad $BOX{bot_left}") . "\n";

        return $output;
    }
}

# Format a single argument value for display
sub _format_arg {
    my ($arg) = @_;

    return 'undef' unless defined $arg;

    my $ref = ref $arg;
    if (!$ref) {
        # Scalar value - truncate if too long
        my $str = "$arg";
        if (length($str) > 50) {
            $str = substr($str, 0, 47) . '...';
        }
        # Quote strings that look like strings
        if ($str =~ /[^0-9.\-+eE]/ || $str eq '') {
            $str =~ s/\\/\\\\/g;
            $str =~ s/"/\\"/g;
            $str =~ s/\n/\\n/g;
            $str =~ s/\t/\\t/g;
            return qq{"$str"};
        }
        return $str;
    }

    # It's a reference
    my $addr = refaddr($arg);
    my $addr_hex = sprintf("0x%x", $addr);

    if (blessed($arg)) {
        # It's an object
        return "$ref($addr_hex)";
    }

    # Plain reference
    return "$ref($addr_hex)";
}

# Format all arguments for a frame
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

    # Use package DB to enable @DB::args capture
    package DB {
        while (my @caller_info = caller($level)) {
            my ($package, $filename, $line, $subroutine, $hasargs, $wantarray) = @caller_info;

            # Capture args if available (copy to avoid issues)
            my @args_copy;
            if ($hasargs && @DB::args) {
                @args_copy = @DB::args;
            }

            # Skip internal BetterErrors frames and eval frames
            my $skip = 0;
            $skip = 1 if $subroutine && $subroutine =~ /^BetterErrors::/;
            $skip = 1 if $filename =~ /^\(eval/;

            unless ($skip) {
                push @frames, BetterErrors::StackFrame->new(
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

    # Remove trailing newline if present
    chomp($error);

    # Common patterns:
    # "message at file line N."
    # "message at file line N, <FH> line M."
    # "message at file line N, near "..."

    if ($error =~ /^(.+?)\s+at\s+(.+?)\s+line\s+(\d+)/) {
        my ($message, $file, $line) = ($1, $2, $3);
        return ($message, $file, $line);
    }

    # If we can't parse it, return the whole message
    return ($error, undef, undef);
}

# The die handler
sub _die_handler {
    my ($error) = @_;

    # Don't interfere if we're in an eval
    return if $^S;

    # Capture stack trace early before we lose context
    my $frames = _capture_stack(1);

    my ($message, $file, $line) = _parse_error($error);

    # If we couldn't determine file/line from error, try caller
    if (!defined $file || !defined $line) {
        my $level = 0;
        while (my @caller = caller($level)) {
            if ($caller[0] ne 'BetterErrors' && $caller[1] !~ /^\(eval/) {
                $file //= $caller[1];
                $line //= $caller[2];
                last;
            }
            $level++;
        }
    }

    my $formatter = BetterErrors::ErrorFormatter->new(context_lines => 2);
    my $formatted = $formatter->format_error($message, $file // 'unknown', $line // 0, $frames);

    die $formatted;
}

# Store original handlers per package
my %ORIGINAL_HANDLERS;

sub import {
    my $class = shift;
    my %opts = @_;

    my ($caller_package, $caller_file) = caller;

    # Pre-cache the caller's source file
    if (-f $caller_file) {
        $SOURCE_CACHE{$caller_file} = BetterErrors::SourceFile->new(path => $caller_file);
        $SOURCE_CACHE{$caller_file}->load;
    }

    # Save any existing handler
    $ORIGINAL_HANDLERS{$caller_package} = $SIG{__DIE__};

    # Install our handler
    $SIG{__DIE__} = \&_die_handler;

    # Handle options
    $USE_COLORS = 0 if $opts{no_color};
    $USE_COLORS = 1 if $opts{color};
    $SHOW_BACKTRACE = 0 if $opts{no_backtrace};
    $SHOW_BACKTRACE = 1 if $opts{backtrace};
}

sub unimport {
    my $class = shift;
    my ($caller_package) = caller;

    # Restore original handler
    if (exists $ORIGINAL_HANDLERS{$caller_package}) {
        $SIG{__DIE__} = $ORIGINAL_HANDLERS{$caller_package};
        delete $ORIGINAL_HANDLERS{$caller_package};
    } else {
        $SIG{__DIE__} = undef;
    }
}

# Allow manual formatting of errors
sub format_error {
    my ($message, $file, $line) = @_;
    my $formatter = BetterErrors::ErrorFormatter->new(context_lines => 2);
    return $formatter->format_error($message, $file, $line);
}

# Enable/disable colors
sub set_colors { $USE_COLORS = $_[0] ? 1 : 0 }

# Enable/disable backtrace
sub set_backtrace { $SHOW_BACKTRACE = $_[0] ? 1 : 0 }

1;

__END__

=head1 NAME

BetterErrors - Rust-style error messages for Perl

=head1 SYNOPSIS

    use v5.40;
    use BetterErrors;

    # Now die() will produce Rust-style error messages:
    #
    # error: Can't call method "foo" on an undefined value
    #   --> script.pl:10
    #    |
    #  8 |     my $obj = get_object();
    #  9 |
    # 10 |     $obj->foo();
    #    |     ^^^^^^^^^^^ error occurred here
    # 11 |
    #    |
    #
    # stack backtrace:
    #    0: main::get_object
    #              at script.pl:10
    #    1: main::process
    #              at script.pl:15

    my $x = undef;
    $x->method();  # This will show a beautiful error

=head1 DESCRIPTION

BetterErrors overrides Perl's default die handler to provide Rust-style
error messages with source context. When an error occurs, you'll see:

=over 4

=item * A clear error message

=item * The file and line number where the error occurred

=item * The surrounding source code with the error line highlighted

=item * A visual pointer to the problematic code

=item * A full stack backtrace showing the call chain

=back

=head1 IMPORT OPTIONS

    use BetterErrors color => 1;        # Force colors on
    use BetterErrors no_color => 1;     # Force colors off
    use BetterErrors backtrace => 1;    # Force backtrace on (default)
    use BetterErrors no_backtrace => 1; # Disable backtrace

By default, colors are enabled when STDERR is a terminal, and
stack backtraces are always shown.

=head1 FUNCTIONS

=head2 format_error($message, $file, $line)

Manually format an error message in Rust style.

=head2 set_colors($bool)

Enable or disable colored output.

=head2 set_backtrace($bool)

Enable or disable stack backtrace display.

=head1 AUTHOR

Your Name

=head1 LICENSE

This is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

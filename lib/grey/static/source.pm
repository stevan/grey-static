use v5.40;
use experimental qw(class);

package grey::static::source;

our $VERSION = '0.01';

# Global source cache
my %CACHE;

sub import { }

sub cache_file {
    my ($class, $path) = @_;
    return unless defined $path && -f $path;
    $CACHE{$path} //= grey::static::source::File->new(path => $path);
    $CACHE{$path}->load;
    return $CACHE{$path};
}

sub get_source {
    my ($class, $path) = @_;
    return undef unless defined $path && -f $path;
    $CACHE{$path} //= grey::static::source::File->new(path => $path);
    return $CACHE{$path};
}

class grey::static::source::File {
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

1;

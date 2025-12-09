use v5.42;
use experimental qw(class);

package grey::static::source;

our $VERSION = '0.01';

# Global source cache with LRU eviction
my %CACHE;
my %ACCESS_TIME;
my $ACCESS_COUNTER = 0;

# Cache configuration
our $MAX_CACHE_SIZE = 100;

# Cache statistics
my $CACHE_HITS = 0;
my $CACHE_MISSES = 0;
my $CACHE_EVICTIONS = 0;

sub import { }

sub cache_file {
    my ($class, $path) = @_;
    return unless defined $path && -f $path;

    if (exists $CACHE{$path}) {
        $CACHE_HITS++;
        $ACCESS_TIME{$path} = ++$ACCESS_COUNTER;
        $CACHE{$path}->load;
        return $CACHE{$path};
    }

    $CACHE_MISSES++;
    _evict_if_needed();

    $CACHE{$path} = grey::static::source::File->new(path => $path);
    $ACCESS_TIME{$path} = ++$ACCESS_COUNTER;
    $CACHE{$path}->load;
    return $CACHE{$path};
}

sub get_source {
    my ($class, $path) = @_;
    return undef unless defined $path && -f $path;

    if (exists $CACHE{$path}) {
        $CACHE_HITS++;
        $ACCESS_TIME{$path} = ++$ACCESS_COUNTER;
        return $CACHE{$path};
    }

    $CACHE_MISSES++;
    _evict_if_needed();

    $CACHE{$path} = grey::static::source::File->new(path => $path);
    $ACCESS_TIME{$path} = ++$ACCESS_COUNTER;
    return $CACHE{$path};
}

sub _evict_if_needed {
    return if keys(%CACHE) < $MAX_CACHE_SIZE;

    # Find least recently used entry
    my $lru_path = (sort { $ACCESS_TIME{$a} <=> $ACCESS_TIME{$b} } keys %CACHE)[0];

    delete $CACHE{$lru_path};
    delete $ACCESS_TIME{$lru_path};
    $CACHE_EVICTIONS++;
}

sub clear_cache {
    %CACHE = ();
    %ACCESS_TIME = ();
    $ACCESS_COUNTER = 0;
    $CACHE_HITS = 0;
    $CACHE_MISSES = 0;
    $CACHE_EVICTIONS = 0;
}

sub cache_stats {
    return {
        size => scalar(keys %CACHE),
        max_size => $MAX_CACHE_SIZE,
        hits => $CACHE_HITS,
        misses => $CACHE_MISSES,
        evictions => $CACHE_EVICTIONS,
        hit_rate => $CACHE_HITS + $CACHE_MISSES > 0
            ? sprintf("%.2f", $CACHE_HITS / ($CACHE_HITS + $CACHE_MISSES) * 100)
            : 0,
    };
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

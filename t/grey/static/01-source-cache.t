#!/usr/bin/env perl

use v5.42;
use experimental qw[ class ];

use Test::More;

use grey::static::source;

# Test cache statistics
{
    grey::static::source->clear_cache();

    my $stats = grey::static::source->cache_stats();
    is($stats->{size}, 0, 'cache starts empty');
    is($stats->{hits}, 0, 'no hits initially');
    is($stats->{misses}, 0, 'no misses initially');
    is($stats->{evictions}, 0, 'no evictions initially');
}

# Test cache hit/miss tracking
{
    grey::static::source->clear_cache();

    # First access is a miss
    my $file1 = grey::static::source->get_source('lib/grey/static.pm');
    my $stats = grey::static::source->cache_stats();
    is($stats->{misses}, 1, 'first access is a miss');
    is($stats->{hits}, 0, 'no hits yet');
    is($stats->{size}, 1, 'cache has 1 entry');

    # Second access is a hit
    my $file2 = grey::static::source->get_source('lib/grey/static.pm');
    $stats = grey::static::source->cache_stats();
    is($stats->{hits}, 1, 'second access is a hit');
    is($stats->{misses}, 1, 'still 1 miss');
    is($stats->{size}, 1, 'cache still has 1 entry');
}

# Test LRU eviction
{
    grey::static::source->clear_cache();

    # Set small cache size for testing
    local $grey::static::source::MAX_CACHE_SIZE = 3;

    # Fill cache
    grey::static::source->get_source('lib/grey/static.pm');
    grey::static::source->get_source('lib/grey/static/source.pm');
    grey::static::source->get_source('lib/grey/static/error.pm');

    my $stats = grey::static::source->cache_stats();
    is($stats->{size}, 3, 'cache is full');
    is($stats->{evictions}, 0, 'no evictions yet');

    # Access first file again to make it recently used
    grey::static::source->get_source('lib/grey/static.pm');

    # Add fourth file - should evict lib/grey/static/source.pm (least recently used)
    grey::static::source->get_source('lib/grey/static/functional.pm');

    $stats = grey::static::source->cache_stats();
    is($stats->{size}, 3, 'cache size stays at max');
    is($stats->{evictions}, 1, 'one eviction occurred');

    # Try to access the evicted file - should be a miss
    my $before_misses = $stats->{misses};
    grey::static::source->get_source('lib/grey/static/source.pm');
    $stats = grey::static::source->cache_stats();
    is($stats->{misses}, $before_misses + 1, 'accessing evicted file is a miss');
}

# Test clear_cache
{
    grey::static::source->clear_cache();
    grey::static::source->get_source('lib/grey/static.pm');

    my $stats = grey::static::source->cache_stats();
    ok($stats->{size} > 0, 'cache has entries');

    grey::static::source->clear_cache();
    $stats = grey::static::source->cache_stats();
    is($stats->{size}, 0, 'cache is empty after clear');
    is($stats->{hits}, 0, 'stats reset after clear');
    is($stats->{misses}, 0, 'stats reset after clear');
}

# Test hit rate calculation
{
    grey::static::source->clear_cache();

    # 1 miss
    grey::static::source->get_source('lib/grey/static.pm');
    # 1 hit
    grey::static::source->get_source('lib/grey/static.pm');
    # 1 hit
    grey::static::source->get_source('lib/grey/static.pm');

    my $stats = grey::static::source->cache_stats();
    is($stats->{hits}, 2, '2 hits');
    is($stats->{misses}, 1, '1 miss');
    is($stats->{hit_rate}, '66.67', 'hit rate is 66.67%');
}

done_testing;

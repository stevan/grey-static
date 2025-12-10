#!/usr/bin/env perl

use v5.42;
use utf8;
use experimental qw[ class keyword_any keyword_all ];
use Benchmark qw[ cmpthese timethese ];

# Version 1: Using field $items (arrayref) - current implementation
class ListWithRef {
    field $items :param;

    ADJUST {
        $items = [@$items];
    }

    sub of ($class, @values) {
        return $class->new(items => [@values]);
    }

    method size () {
        return scalar @$items;
    }

    method at ($index) {
        return $items->[$index];
    }

    method map ($func) {
        return ListWithRef->new(items => [ map { $func->($_) } @$items ]);
    }

    method grep ($pred) {
        return ListWithRef->new(items => [ grep { $pred->($_) } @$items ]);
    }

    method foreach ($consumer) {
        for my $item (@$items) {
            $consumer->($item);
        }
    }

    method push (@values) {
        return ListWithRef->new(items => [@$items, @values]);
    }
}

# Version 2: Using field @items (plain array) - capture via $items param, copy to @items
class ListWithArray {
    field $items :param;  # capture arrayref parameter
    field @items;         # actual array storage

    ADJUST {
        @items = $items->@*;  # copy arrayref contents to array
    }

    sub of ($class, @values) {
        return $class->new(items => [@values]);
    }

    method size () {
        return scalar @items;
    }

    method at ($index) {
        return $items[$index];  # direct array access, no dereference
    }

    method map ($func) {
        return ListWithArray->new(items => [ map { $func->($_) } @items ]);
    }

    method grep ($pred) {
        return ListWithArray->new(items => [ grep { $pred->($_) } @items ]);
    }

    method foreach ($consumer) {
        for my $item (@items) {
            $consumer->($item);
        }
    }

    method push (@values) {
        return ListWithArray->new(items => [@items, @values]);
    }
}

# Test data
my @test_data = (1..1000);
my $double = sub ($x) { $x * 2 };
my $is_even = sub ($x) { $x % 2 == 0 };
my $sum = 0;
my $consumer = sub ($x) { $sum += $x };

say "Benchmarking List implementations: field \$items (ref) vs field \@items (array)";
say "=" x 80;
say "";

# Benchmark 1: Construction
say "1. Construction (creating list from 1000 elements):";
cmpthese(10000, {
    'ref'   => sub { my $list = ListWithRef->of(@test_data) },
    'array' => sub { my $list = ListWithArray->of(@test_data) },
});
say "";

# Benchmark 2: Element access
my $list_ref = ListWithRef->of(@test_data);
my $list_arr = ListWithArray->of(@test_data);

say "2. Element access (accessing 100 random elements):";
cmpthese(10000, {
    'ref'   => sub { for (1..100) { my $x = $list_ref->at(int(rand(1000))) } },
    'array' => sub { for (1..100) { my $x = $list_arr->at(int(rand(1000))) } },
});
say "";

# Benchmark 3: Iteration
say "3. Iteration (foreach over 1000 elements):";
cmpthese(1000, {
    'ref'   => sub { $sum = 0; $list_ref->foreach($consumer) },
    'array' => sub { $sum = 0; $list_arr->foreach($consumer) },
});
say "";

# Benchmark 4: Map operation
say "4. Map operation (doubling 1000 elements):";
cmpthese(1000, {
    'ref'   => sub { my $doubled = $list_ref->map($double) },
    'array' => sub { my $doubled = $list_arr->map($double) },
});
say "";

# Benchmark 5: Grep operation
say "5. Grep operation (filtering 1000 elements):";
cmpthese(1000, {
    'ref'   => sub { my $evens = $list_ref->grep($is_even) },
    'array' => sub { my $evens = $list_arr->grep($is_even) },
});
say "";

# Benchmark 6: Immutable push
say "6. Push operation (appending 10 elements):";
my @push_data = (1..10);
cmpthese(5000, {
    'ref'   => sub { my $pushed = $list_ref->push(@push_data) },
    'array' => sub { my $pushed = $list_arr->push(@push_data) },
});
say "";

say "=" x 80;
say "Note: 'ref' = field \$items (arrayref), 'array' = field \@items (plain array)";
say "Higher rate (ops/sec) is better";

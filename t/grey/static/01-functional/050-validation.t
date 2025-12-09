#!/usr/bin/env perl

use v5.42;
use experimental qw[ class try ];

use Test::More;

use grey::static qw[ functional ];

# Test Function validation
subtest 'Function parameter validation' => sub {
    my $error;

    # Valid CODE ref should work
    my $f = Function->new(f => sub { 1 });
    isa_ok($f, 'Function', 'Function accepts CODE ref');

    # Invalid parameter should throw Error
    try {
        Function->new(f => "not a coderef");
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid 'f' parameter for Function/, 'throws error for non-CODE ref');
    like($error, qr/Expected a CODE reference/, 'error includes hint');
};

# Test Predicate validation
subtest 'Predicate parameter validation' => sub {
    my $error;

    # Valid CODE ref should work
    my $p = Predicate->new(f => sub { 1 });
    isa_ok($p, 'Predicate', 'Predicate accepts CODE ref');

    # Invalid parameter should throw Error
    try {
        Predicate->new(f => []);
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid 'f' parameter for Predicate/, 'throws error for ARRAY ref');
    like($error, qr/got: ARRAY/, 'error shows received type');
};

# Test Consumer validation
subtest 'Consumer parameter validation' => sub {
    my $error;

    # Valid CODE ref should work
    my $c = Consumer->new(f => sub { });
    isa_ok($c, 'Consumer', 'Consumer accepts CODE ref');

    # Invalid parameter should throw Error
    try {
        Consumer->new(f => {});
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid 'f' parameter for Consumer/, 'throws error for HASH ref');
};

# Test BiFunction validation
subtest 'BiFunction parameter validation' => sub {
    my $error;

    # Valid CODE ref should work
    my $bf = BiFunction->new(f => sub { 1 });
    isa_ok($bf, 'BiFunction', 'BiFunction accepts CODE ref');

    # Invalid parameter should throw Error
    try {
        BiFunction->new(f => 123);
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid 'f' parameter for BiFunction/, 'throws error for scalar');
    like($error, qr/got: scalar/, 'error identifies scalar value');
};

# Test BiConsumer validation
subtest 'BiConsumer parameter validation' => sub {
    my $error;

    # Valid CODE ref should work
    my $bc = BiConsumer->new(f => sub { });
    isa_ok($bc, 'BiConsumer', 'BiConsumer accepts CODE ref');

    # Invalid parameter should throw Error
    try {
        BiConsumer->new(f => undef);
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid 'f' parameter for BiConsumer/, 'throws error for undef');
};

# Test Supplier validation
subtest 'Supplier parameter validation' => sub {
    my $error;

    # Valid CODE ref should work
    my $s = Supplier->new(f => sub { 42 });
    isa_ok($s, 'Supplier', 'Supplier accepts CODE ref');

    # Invalid parameter should throw Error
    try {
        Supplier->new(f => \"string ref");
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid 'f' parameter for Supplier/, 'throws error for SCALAR ref');
};

# Test Comparator validation
subtest 'Comparator parameter validation' => sub {
    my $error;

    # Valid CODE ref should work
    my $cmp = Comparator->new(f => sub { $_[0] <=> $_[1] });
    isa_ok($cmp, 'Comparator', 'Comparator accepts CODE ref');

    # Invalid parameter should throw Error
    try {
        Comparator->new(f => *STDOUT);
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid 'f' parameter for Comparator/, 'throws error for GLOB');
};

done_testing;

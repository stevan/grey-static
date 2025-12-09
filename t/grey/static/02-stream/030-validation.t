#!/usr/bin/env perl

use v5.42;
use experimental qw[ class try ];

use Test::More;

use grey::static qw[ functional stream ];

# Test Stream::Source::FromArray validation
subtest 'FromArray parameter validation' => sub {
    my $error;

    # Valid ARRAY ref should work
    my $source = Stream::Source::FromArray->new(array => [1, 2, 3]);
    isa_ok($source, 'Stream::Source::FromArray', 'FromArray accepts ARRAY ref');

    # Invalid parameter should throw Error
    try {
        Stream::Source::FromArray->new(array => "not an array");
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid 'array' parameter/, 'throws error for non-ARRAY');
    like($error, qr/Expected an ARRAY reference/, 'error includes hint');
};

# Test Stream::Source::FromRange validation
subtest 'FromRange parameter validation' => sub {
    my $error;

    # Valid numbers should work
    my $source = Stream::Source::FromRange->new(start => 1, end => 10);
    isa_ok($source, 'Stream::Source::FromRange', 'FromRange accepts numbers');

    # Invalid start parameter
    try {
        Stream::Source::FromRange->new(start => "not a number", end => 10);
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid 'start' parameter/, 'throws error for non-numeric start');
    like($error, qr/Expected a number/, 'error includes hint');

    # Invalid end parameter
    try {
        Stream::Source::FromRange->new(start => 1, end => "ten");
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid 'end' parameter/, 'throws error for non-numeric end');

    # Invalid step parameter
    try {
        Stream::Source::FromRange->new(start => 1, end => 10, step => 0);
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid 'step' parameter/, 'throws error for zero step');
    like($error, qr/must be a non-zero number/, 'error explains step requirement');
};

# Test Stream::Source::FromIterator validation
subtest 'FromIterator parameter validation' => sub {
    my $error;

    # Valid CODE ref should work
    my $source = Stream::Source::FromIterator->new(
        seed => 0,
        next => sub { $_[0] + 1 },
        has_next => undef
    );
    isa_ok($source, 'Stream::Source::FromIterator', 'FromIterator accepts CODE ref');

    # Valid Function object should work
    my $source2 = Stream::Source::FromIterator->new(
        seed => 0,
        next => Function->new(f => sub { $_[0] + 1 }),
        has_next => undef
    );
    isa_ok($source2, 'Stream::Source::FromIterator', 'FromIterator accepts Function object');

    # Invalid next parameter
    try {
        Stream::Source::FromIterator->new(seed => 0, next => "not callable", has_next => undef);
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid 'next' parameter/, 'throws error for non-callable next');
    like($error, qr/Expected a Function object or CODE reference/, 'error includes hint');

    # Invalid has_next parameter
    try {
        Stream::Source::FromIterator->new(
            seed => 0,
            next => sub { 1 },
            has_next => 42
        );
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid 'has_next' parameter/, 'throws error for non-callable has_next');
    like($error, qr/Expected a Predicate object or CODE reference/, 'error includes hint for has_next');
};

done_testing;

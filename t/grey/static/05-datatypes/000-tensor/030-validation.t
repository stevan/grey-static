#!/usr/bin/env perl

use v5.42;
use experimental qw[ class try ];

use Test::More;

use grey::static qw[ datatypes::numeric ];

# Test Tensor data size validation
subtest 'Tensor data size validation' => sub {
    my $error;

    # Valid tensor should work
    my $t = Tensor->new(data => [1, 2, 3, 4], shape => [2, 2]);
    isa_ok($t, 'Tensor', 'Tensor with matching data size works');

    # Invalid data size should throw Error
    try {
        Tensor->new(data => [1, 2, 3], shape => [2, 2]);
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Invalid data size for Tensor/, 'throws error for mismatched size');
    like($error, qr/Expected 4 elements, got 3/, 'error shows expected vs actual');
};

# Test Tensor index bounds validation
subtest 'Tensor index bounds checking' => sub {
    my $error;
    my $t = Tensor->new(data => [1, 2, 3, 4], shape => [2, 2]);

    # Valid index should work
    my $val = $t->index_data_array(0);
    is($val, 1, 'index 0 is valid');

    $val = $t->index_data_array(3);
    is($val, 4, 'index 3 is valid');

    # Out of bounds (negative)
    try {
        $t->index_data_array(-1);
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Tensor index out of bounds/, 'throws error for negative index');
    like($error, qr/Index -1 is outside valid range/, 'error shows the invalid index');

    # Out of bounds (too large)
    try {
        $t->index_data_array(4);
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Tensor index out of bounds/, 'throws error for index >= size');
    like($error, qr/Index 4 is outside valid range \[0, 3\]/, 'error shows valid range');
};

# Test Tensor slice bounds validation
subtest 'Tensor slice bounds checking' => sub {
    my $error;
    my $t = Tensor->new(data => [1, 2, 3, 4, 5], shape => [5]);

    # Valid slice should work
    my @vals = $t->slice_data_array(0, 2, 4);
    is_deeply(\@vals, [1, 3, 5], 'valid slice works');

    # Out of bounds in slice
    try {
        $t->slice_data_array(0, 2, 10);
    } catch ($e) {
        $error = $e;
    }

    like($error, qr/Tensor index out of bounds/, 'throws error for out of bounds slice');
    like($error, qr/Index 10 is outside valid range/, 'error identifies the bad index');
};

done_testing;

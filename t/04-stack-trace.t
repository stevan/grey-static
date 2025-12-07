#!/usr/bin/env perl
use v5.40;
use Test::More;
use File::Temp qw(tempfile);

use_ok('BetterErrors');

# Disable colors for predictable output
BetterErrors::set_colors(0);

subtest 'StackFrame class' => sub {
    my $frame = BetterErrors::StackFrame->new(
        package    => 'MyApp::User',
        filename   => '/path/to/file.pm',
        line       => 42,
        subroutine => 'MyApp::User::validate',
    );

    isa_ok($frame, 'BetterErrors::StackFrame');
    is($frame->package, 'MyApp::User', 'package accessor');
    is($frame->filename, '/path/to/file.pm', 'filename accessor');
    is($frame->line, 42, 'line accessor');
    is($frame->subroutine, 'MyApp::User::validate', 'subroutine accessor');
    is($frame->short_sub, 'MyApp::User::validate', 'short_sub returns full name');
};

subtest 'stack capture' => sub {
    # Test stack capture directly
    my $frames = BetterErrors::_capture_stack(0);

    ok($frames, 'frames captured');
    ok(ref $frames eq 'ARRAY', 'frames is an arrayref');
    ok(@$frames >= 1, 'at least 1 frame captured');

    # Verify frame structure
    my $first_frame = $frames->[0];
    isa_ok($first_frame, 'BetterErrors::StackFrame');
    ok(defined $first_frame->filename, 'frame has filename');
    ok(defined $first_frame->line, 'frame has line number');
};

subtest 'backtrace in formatted output' => sub {
    my $formatter = BetterErrors::ErrorFormatter->new(context_lines => 1);

    # Create mock frames
    my @frames = (
        BetterErrors::StackFrame->new(
            package    => 'main',
            filename   => 'test.pl',
            line       => 10,
            subroutine => 'main::foo',
        ),
        BetterErrors::StackFrame->new(
            package    => 'main',
            filename   => 'test.pl',
            line       => 20,
            subroutine => 'main::bar',
        ),
    );

    BetterErrors::set_backtrace(1);
    my $output = $formatter->format_error("Test error", "/nonexistent", 1, \@frames);

    like($output, qr/stack backtrace:/, 'contains backtrace header');
    like($output, qr/main::foo/, 'contains first frame subroutine');
    like($output, qr/main::bar/, 'contains second frame subroutine');
    like($output, qr/at test\.pl:10/, 'contains first frame location');
    like($output, qr/at test\.pl:20/, 'contains second frame location');
};

subtest 'backtrace can be disabled' => sub {
    my $formatter = BetterErrors::ErrorFormatter->new();

    my @frames = (
        BetterErrors::StackFrame->new(
            package    => 'main',
            filename   => 'test.pl',
            line       => 10,
            subroutine => 'main::foo',
        ),
    );

    BetterErrors::set_backtrace(0);
    my $output = $formatter->format_error("Test error", "/nonexistent", 1, \@frames);

    unlike($output, qr/stack backtrace:/, 'no backtrace when disabled');

    # Re-enable for other tests
    BetterErrors::set_backtrace(1);
};

subtest 'set_backtrace function' => sub {
    BetterErrors::set_backtrace(0);
    # Can't easily test the internal state, but we can test via formatter output

    BetterErrors::set_backtrace(1);
    pass('set_backtrace toggles without error');
};

subtest 'argument formatting' => sub {
    # Test _format_arg directly
    is(BetterErrors::_format_arg(undef), 'undef', 'formats undef');
    is(BetterErrors::_format_arg(42), '42', 'formats integer');
    is(BetterErrors::_format_arg(3.14), '3.14', 'formats float');
    is(BetterErrors::_format_arg("hello"), '"hello"', 'formats string with quotes');
    is(BetterErrors::_format_arg(""), '""', 'formats empty string');

    # Test reference formatting
    my $hashref = { foo => 1 };
    my $formatted = BetterErrors::_format_arg($hashref);
    like($formatted, qr/^HASH\(0x[0-9a-f]+\)$/, 'formats hashref with address');

    my $arrayref = [1, 2, 3];
    $formatted = BetterErrors::_format_arg($arrayref);
    like($formatted, qr/^ARRAY\(0x[0-9a-f]+\)$/, 'formats arrayref with address');

    # Test object formatting
    my $obj = bless {}, 'MyClass';
    $formatted = BetterErrors::_format_arg($obj);
    like($formatted, qr/^MyClass\(0x[0-9a-f]+\)$/, 'formats object with class and address');

    # Test string escaping
    is(BetterErrors::_format_arg("line1\nline2"), '"line1\\nline2"', 'escapes newlines');
    is(BetterErrors::_format_arg("tab\there"), '"tab\\there"', 'escapes tabs');
};

subtest '_format_args' => sub {
    is(BetterErrors::_format_args(undef), '', 'returns empty for undef');
    is(BetterErrors::_format_args([]), '', 'returns empty for empty array');

    my $result = BetterErrors::_format_args([1, "two", undef]);
    is($result, '(1, "two", undef)', 'formats multiple args');
};

subtest 'backtrace shows args and source' => sub {
    my $formatter = BetterErrors::ErrorFormatter->new(context_lines => 1);

    # Create mock frames with args
    my @frames = (
        BetterErrors::StackFrame->new(
            package    => 'main',
            filename   => '/nonexistent/test.pl',
            line       => 10,
            subroutine => 'main::foo',
            hasargs    => 1,
            args       => [42, "hello"],
        ),
    );

    BetterErrors::set_backtrace(1);
    my $output = $formatter->format_error("Test error", "/nonexistent", 1, \@frames);

    like($output, qr/main::foo/, 'contains subroutine name');
    like($output, qr/42/, 'contains numeric arg');
    like($output, qr/"hello"/, 'contains string arg');
};

done_testing;

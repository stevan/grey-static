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

done_testing;

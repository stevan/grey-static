#!/usr/bin/env perl
use v5.42;
use Test::More;

# Test loading diagnostics
use grey::static qw[diagnostics];

# Check that handlers are installed
ok(defined $SIG{__DIE__}, '__DIE__ handler is installed');
ok(defined $SIG{__WARN__}, '__WARN__ handler is installed');

# Test configuration globals exist
ok(defined $grey::static::diagnostics::NO_COLOR, 'NO_COLOR global exists');
ok(defined $grey::static::diagnostics::NO_BACKTRACE, 'NO_BACKTRACE global exists');
ok(defined $grey::static::diagnostics::NO_SYNTAX_HIGHLIGHT, 'NO_SYNTAX_HIGHLIGHT global exists');

# Test StackFrame class
my $frame = grey::static::diagnostics::StackFrame->new(
    package    => 'main',
    filename   => 'test.pl',
    line       => 42,
    subroutine => 'main::test_sub',
);

is($frame->package, 'main', 'StackFrame package');
is($frame->filename, 'test.pl', 'StackFrame filename');
is($frame->line, 42, 'StackFrame line');
is($frame->subroutine, 'main::test_sub', 'StackFrame subroutine');
is($frame->short_sub, 'main::test_sub', 'StackFrame short_sub');

# Test Formatter class
my $formatter = grey::static::diagnostics::Formatter->new(context_lines => 2);
ok($formatter, 'Formatter created');

done_testing;

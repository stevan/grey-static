#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream ];

subtest '... buffered stream with rewind' => sub {
    my $stream = Stream->of( 1 .. 5 )->buffered;
    my $source = $stream->source;

    # Start buffering
    $source->start_buffering;

    # Read some elements
    my @first_read;
    push @first_read => $source->next while @first_read < 3;

    eq_or_diff(\@first_read, [1, 2, 3], '... read first 3 elements');

    # Rewind to replay buffered elements
    $source->rewind;

    # Read again - should get buffered elements
    my @second_read;
    push @second_read => $source->next while @second_read < 3;

    eq_or_diff(\@second_read, [1, 2, 3], '... replayed buffered elements');

    # Continue reading - should get remaining elements
    my @remaining;
    push @remaining => $source->next while $source->has_next;

    eq_or_diff(\@remaining, [4, 5], '... read remaining elements');
};

subtest '... buffered stream buffer control' => sub {
    my $stream = Stream->of( 1 .. 5 )->buffered;
    my $source = $stream->source;

    # Start buffering
    $source->start_buffering;
    my $val1 = $source->next;
    my $val2 = $source->next;

    is($val1, 1, '... got first value');
    is($val2, 2, '... got second value');

    # Check buffer contains what we read
    eq_or_diff([$source->buffer], [1, 2], '... buffer contains read values');

    # Clear buffer
    $source->clear_buffer;
    eq_or_diff([$source->buffer], [], '... buffer is cleared');

    # Continue reading
    my $val3 = $source->next;
    is($val3, 3, '... got third value');

    # Buffer should contain only new read
    eq_or_diff([$source->buffer], [3], '... buffer contains only new read');
};

subtest '... buffered stream stop buffering' => sub {
    my $stream = Stream->of( 1 .. 5 )->buffered;
    my $source = $stream->source;

    # Start buffering
    $source->start_buffering;
    $source->next;  # Read 1
    $source->next;  # Read 2

    eq_or_diff([$source->buffer], [1, 2], '... buffer contains values');

    # Stop buffering
    $source->stop_buffering;
    $source->next;  # Read 3

    eq_or_diff([$source->buffer], [1, 2], '... buffer unchanged after stop');
};

done_testing;

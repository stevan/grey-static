use v5.42;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../../lib";

use grey::static qw[ functional concurrency::reactive datatypes::util ];
use EventGenerator;
use EventProcessor;

subtest 'filter events by type' => sub {
    my $processor = EventProcessor->new;
    my @filtered;

    #  Create empty publisher and build Flow first
    my $publisher = Flow::Publisher->new;

    my $flow = $processor->filter_by_type($publisher, 'temperature', sub ($event) {
        push @filtered, $event;
    });

    # Now submit mixed events after Flow is built
    for my $i (1..20) {
        my $type = [qw[ temperature humidity motion ]]->[int(rand(3))];
        $publisher->submit({
            type => $type,
            value => int(rand(100)),
            timestamp => time + $i,
        });
    }

    $flow->start;
    $flow->close;

    ok(scalar(@filtered) > 0, 'filtered some events');
    for my $event (@filtered) {
        is($event->{type}, 'temperature', 'all filtered events are temperature');
    }
};

subtest 'validate events' => sub {
    my $processor = EventProcessor->new;

    # Valid temperature event
    my $result1 = $processor->validate_event({
        type => 'temperature',
        value => 25,
        timestamp => time,
    });
    ok($result1->success, 'valid temperature event passes');

    # Invalid - missing value
    my $result2 = $processor->validate_event({
        type => 'temperature',
        timestamp => time,
    });
    ok($result2->failure, 'temperature without value fails');

    # Valid alert event
    my $result3 = $processor->validate_event({
        type => 'alert',
        severity => 'high',
        message => 'Test alert',
        timestamp => time,
    });
    ok($result3->success, 'valid alert event passes');

    # Invalid - missing message
    my $result4 = $processor->validate_event({
        type => 'alert',
        severity => 'high',
        timestamp => time,
    });
    ok($result4->failure, 'alert without message fails');
};

subtest 'transform events' => sub {
    my $processor = EventProcessor->new;
    my @transformed;

    my $publisher = Flow::Publisher->new;

    my $flow = $processor->transform_temperature($publisher, sub ($event) {
        push @transformed, $event;
    });

    # Submit temperature events
    for my $i (1..5) {
        $publisher->submit({
            type => 'temperature',
            value => int(rand(100)) - 50,
            timestamp => time + $i,
        });
    }

    $flow->start;
    $flow->close;

    is(scalar(@transformed), 5, 'transformed 5 events');
    for my $event (@transformed) {
        ok(exists $event->{celsius}, 'has celsius value');
        ok(exists $event->{fahrenheit}, 'has fahrenheit value');
        is($event->{fahrenheit}, $event->{celsius} * 9/5 + 32, 'correct conversion');
    }
};

subtest 'filter and validate pipeline' => sub {
    my $processor = EventProcessor->new;
    my @valid;
    my @invalid;

    my $publisher = Flow::Publisher->new;

    my $flow = $processor->filter_and_validate(
        $publisher,
        'temperature',
        sub ($event) { push @valid, $event; },
        sub ($error) { push @invalid, $error; }
    );

    # Submit mixed events
    for my $i (1..20) {
        my $type = [qw[ temperature humidity motion ]]->[int(rand(3))];
        $publisher->submit({
            type => $type,
            value => int(rand(100)),
            timestamp => time + $i,
        });
    }

    $flow->start;
    $flow->close;

    ok(scalar(@valid) > 0, 'got some valid events');
    for my $event (@valid) {
        is($event->{type}, 'temperature', 'valid events are temperature');
        ok(exists $event->{value}, 'valid events have value');
    }
};

done_testing;

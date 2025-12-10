use v5.42;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../../lib";

use grey::static qw[ functional concurrency::reactive ];
use EventGenerator;

subtest 'generate temperature events' => sub {
    my $generator = EventGenerator->new;
    my @events;

    my $publisher = $generator->temperature_events(count => 5);
    $publisher->subscribe(Flow::Subscriber->new(
        request_size => 100,  # Request all events
        consumer => Consumer->new(f => sub ($event) {
            push @events, $event;
        })
    ));

    $publisher->start;
    $publisher->close;

    is(scalar(@events), 5, 'generated 5 events');

    for my $event (@events) {
        is($event->{type}, 'temperature', 'event type is temperature');
        ok(exists $event->{value}, 'event has value');
        ok(exists $event->{timestamp}, 'event has timestamp');
        ok($event->{value} >= -50 && $event->{value} <= 50, 'temperature in reasonable range');
    }
};

subtest 'generate humidity events' => sub {
    my $generator = EventGenerator->new;
    my @events;

    my $publisher = $generator->humidity_events(count => 3);
    $publisher->subscribe(Flow::Subscriber->new(
        request_size => 100,
        consumer => Consumer->new(f => sub ($event) {
            push @events, $event;
        })
    ));

    $publisher->start;
    $publisher->close;

    is(scalar(@events), 3, 'generated 3 events');

    for my $event (@events) {
        is($event->{type}, 'humidity', 'event type is humidity');
        ok($event->{value} >= 0 && $event->{value} <= 100, 'humidity in 0-100 range');
    }
};

subtest 'generate motion events' => sub {
    my $generator = EventGenerator->new;
    my @events;

    my $publisher = $generator->motion_events(count => 2);
    $publisher->subscribe(Flow::Subscriber->new(
        request_size => 100,
        consumer => Consumer->new(f => sub ($event) {
            push @events, $event;
        })
    ));

    $publisher->start;
    $publisher->close;

    is(scalar(@events), 2, 'generated 2 events');

    for my $event (@events) {
        is($event->{type}, 'motion', 'event type is motion');
        ok($event->{detected} eq 'yes' || $event->{detected} eq 'no', 'motion detected is yes/no');
    }
};

subtest 'generate alert events' => sub {
    my $generator = EventGenerator->new;
    my @events;

    my $publisher = $generator->alert_events(count => 2);
    $publisher->subscribe(Flow::Subscriber->new(
        request_size => 100,
        consumer => Consumer->new(f => sub ($event) {
            push @events, $event;
        })
    ));

    $publisher->start;
    $publisher->close;

    is(scalar(@events), 2, 'generated 2 events');

    for my $event (@events) {
        is($event->{type}, 'alert', 'event type is alert');
        ok(exists $event->{message}, 'alert has message');
        ok(exists $event->{severity}, 'alert has severity');
    }
};

subtest 'generate mixed events' => sub {
    my $generator = EventGenerator->new;
    my @events;

    my $publisher = $generator->mixed_events(count => 10);
    $publisher->subscribe(Flow::Subscriber->new(
        request_size => 100,
        consumer => Consumer->new(f => sub ($event) {
            push @events, $event;
        })
    ));

    $publisher->start;
    $publisher->close;

    is(scalar(@events), 10, 'generated 10 events');

    my %types;
    for my $event (@events) {
        $types{$event->{type}}++;
        ok(exists $event->{timestamp}, 'event has timestamp');
    }

    ok(keys %types > 1, 'generated multiple event types');
};

done_testing;

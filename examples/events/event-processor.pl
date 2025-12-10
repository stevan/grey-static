#!/usr/bin/env perl
use v5.42;
use utf8;
use experimental qw[ class ];

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../../lib";

use grey::static qw[
    functional
    concurrency
    datatypes::numeric
];

use EventGenerator;
use EventProcessor;
use EventAggregator;
use EventReporter;

say "Event Stream Processor\n";

# Components
my $generator = EventGenerator->new;
my $processor = EventProcessor->new;
my $aggregator = EventAggregator->new;
my $reporter = EventReporter->new;

# Collect events through reactive pipeline
my @all_events;
my @temperature_events;

# Create publisher for mixed events
my $publisher = $generator->mixed_events(count => 100);

# Pipeline 1: Filter and collect temperature events
my $temp_flow = $processor->filter_by_type($publisher, 'temperature', sub ($event) {
    push @temperature_events, $event;
});

# Pipeline 2: Collect all events
$publisher->subscribe(Flow::Subscriber->new(
    request_size => 200,
    consumer => Consumer->new(f => sub ($event) {
        push @all_events, $event;
    })
));

say "Processing events through reactive pipeline...\n";

# Start processing
$temp_flow->start;
$temp_flow->close;

# Aggregate statistics
my $stats = $aggregator->aggregate(\@all_events);

# Generate report
my $report = $reporter->generate_report($stats);
say $report;

say "\n✓ Processed $stats->{total} events using Flow::Publisher and Flow::Subscriber";
say "✓ Filtered ", scalar(@temperature_events), " temperature events through reactive pipeline";
say "✓ Demonstrated backpressure handling with request_size";

# Event Stream Processor Example

A reactive event processing system demonstrating grey::static's concurrency features with Flow::Publisher and Flow::Subscriber.

## Features Showcased

- **concurrency** - Flow::Publisher, Flow::Subscriber, reactive pipelines
- **functional** - Predicate for filtering, Consumer for event handling
- **datatypes::util** - Result for validation
- **datatypes::numeric** - Vector for statistical analysis
- **diagnostics** - Error handling with source context

## What It Does

Simulates a sensor monitoring system that:
1. **Generates events** - Temperature, humidity, motion, alerts
2. **Processes reactively** - Uses Flow to filter and transform events
3. **Demonstrates backpressure** - Controls flow with request_size
4. **Aggregates statistics** - Computes means, min/max with Vector
5. **Reports results** - Formatted summary of processed events

## Event Types

- `temperature` - Sensor readings (-50°C to 50°C)
- `humidity` - Humidity levels (0-100%)
- `motion` - Motion detection (yes/no)
- `alert` - System alerts with severity levels

## Architecture

```
examples/events/
├── event-processor.pl      # Main reactive pipeline
├── lib/
│   ├── EventGenerator.pm  # Flow::Publisher - generates events
│   ├── EventProcessor.pm  # Flow operations (grep, map)
│   ├── EventAggregator.pm # Statistics with Vector
│   └── EventReporter.pm   # Report formatting
└── t/
    ├── 01-generator.t     # Publisher tests
    └── 02-processor.t     # Flow pipeline tests
```

## Usage

### Run the Event Processor

```bash
cd examples/events
perl event-processor.pl
```

Output:
```
Event Stream Processor

Processing events through reactive pipeline...

Event Stream Processing Report
==================================================

Total events processed: 100

Events by type:
  alert           26
  humidity        22
  motion          31
  temperature     21

Temperature statistics:
  Count: 21
  Mean:  7.3°C
  Min:   -49.0°C
  Max:   49.0°C

✓ Processed 100 events using Flow::Publisher and Flow::Subscriber
✓ Filtered temperature events through reactive pipeline
✓ Demonstrated backpressure handling with request_size
```

### Run Tests

```bash
# Run all tests
prove -lr t/

# Run individual tests
prove -lv t/01-generator.t
prove -lv t/02-processor.t
```

## Implementation Highlights

### Flow::Publisher - Event Generation

```perl
# Create publisher and submit events
my $publisher = Flow::Publisher->new;

for my $i (1..10) {
    $publisher->submit({
        type => 'temperature',
        value => rand(100) - 50,
        timestamp => time + $i,
    });
}
```

### Flow Pipeline - Filter and Transform

```perl
# Build reactive pipeline with grep and map
my $flow = Flow
    ->from($publisher)
    ->grep(sub ($event) {
        $event->{type} eq 'temperature';
    })
    ->map(sub ($event) {
        return {
            %$event,
            fahrenheit => $event->{value} * 9/5 + 32,
        };
    })
    ->to(sub ($event) {
        # Process filtered & transformed events
    })
    ->build;

$flow->start;
$flow->close;
```

### Flow::Subscriber - Backpressure Control

```perl
# Control event flow with request_size
$publisher->subscribe(Flow::Subscriber->new(
    request_size => 10,  # Request 10 events at a time
    consumer => Consumer->new(f => sub ($event) {
        # Process events with backpressure
    })
));
```

### Result Types for Validation

```perl
# Validate events returning Result
method validate_event ($event) {
    return Error('Missing value')
        unless exists $event->{value};

    return Ok($event);
}
```

### Vector for Statistics

```perl
my @temperatures = map { $_->{value} } @temp_events;
my $vector = Vector->initialize(scalar(@temperatures), \@temperatures);

my $stats = {
    mean => $vector->mean,
    min  => $vector->min_value,
    max  => $vector->max_value,
};
```

## Key Concepts Demonstrated

### Reactive Streams
- **Push-based processing** - Events flow through pipeline
- **Backpressure** - Subscribers control rate with request_size
- **Pipeline composition** - Chain grep, map, and other operations

### Publisher/Subscriber Pattern
- **Publisher** - Emits events to subscribers
- **Subscriber** - Consumes events with backpressure
- **Consumer** - Functional interface for event handling

### Flow Operations
- **`->grep()`** - Filter events by predicate
- **`->map()`** - Transform events
- **`->to()`** - Terminal consumer
- **`->build()`** - Build the reactive pipeline

## Testing Philosophy

Tests demonstrate:
- Publisher event generation
- Flow pipeline operations (filter, transform)
- Result-based validation
- Pipeline composition

## Dependencies

- Perl v5.42+
- grey::static module

## License

Same as grey::static

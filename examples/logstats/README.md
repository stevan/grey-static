# Log Analyzer Example

A command-line log file analyzer that demonstrates the grey::static Perl module features working together.

## Features

This example showcases:

- **io::stream** - Reading log files and walking directory trees
- **stream** - Processing log lines lazily with map/grep/reduce
- **functional** - Using Predicate for filtering
- **datatypes::util** - Using Result for safe parsing with error handling
- **datatypes::ml** - Using Vector for time series anomaly detection
- **diagnostics** - Beautiful error messages for malformed log entries

## What It Does

1. **Finds log files** - Uses `IO::Stream::Directories->walk()` to recursively find `.log` files
2. **Parses log entries** - Extracts timestamp, level (ERROR/WARN/INFO), and message using Result types
3. **Computes statistics** - Counts events by level, tracks time range
4. **Detects anomalies** - Uses Vector math to find unusual error spikes (mean + 2σ)
5. **Generates report** - Summary with anomalies and parse errors

## Log Format

Expected format:
```
YYYY-MM-DD HH:MM:SS [LEVEL] message
```

Example:
```
2024-01-15 09:23:45 [ERROR] Database connection timeout
2024-01-15 09:23:46 [WARN] Retrying connection (attempt 2/3)
2024-01-15 09:23:47 [INFO] Connection established
```

## Usage

### Generate Sample Logs

```bash
cd examples/logstats
perl generate-sample-logs.pl
```

This creates:
- `sample-logs/app.log` - Main application logs
- `sample-logs/errors.log` - Error-focused logs
- `sample-logs/services/auth.log` - Authentication service
- `sample-logs/services/api.log` - API service

The sample data includes anomalous error spikes at hours 14 and 18 for testing.

### Run the Analyzer

```bash
perl logstats.pl sample-logs/
```

Output:
```
Log Analysis Report
==================================================

Files analyzed: 4
Time range: 2024-01-15 00:00:03 - 2024-01-15 23:59:49

Event counts:
  ERROR:  602
  WARN:   382
  INFO:   3,820

Anomaly detection (hourly errors):
  Mean: 25.1 errors/hour
  Threshold: 92.6 (mean + 2σ)

  ⚠ Hour 14: 152 errors
  ⚠ Hour 18: 120 errors

Parse errors:
  - sample-logs/app.log: Malformed log line
```

### Analyze Your Own Logs

```bash
perl logstats.pl /path/to/your/logs
```

## Running Tests

The example includes comprehensive tests for each component:

```bash
# Run all tests
prove -lr t/

# Run individual test files
prove -lv t/01-logparser.t
prove -lv t/02-timeseries.t
prove -lv t/03-reporter.t
```

## Architecture

```
logstats.pl              # Main script - orchestrates everything
lib/
  LogParser.pm           # Parses log lines, returns Result types
  TimeSeriesAnalyzer.pm  # Anomaly detection using Vector
  Reporter.pm            # Generates formatted summary report
t/
  01-logparser.t         # LogParser tests
  02-timeseries.t        # TimeSeriesAnalyzer tests
  03-reporter.t          # Reporter tests
sample-logs/             # Generated test data
```

## Implementation Highlights

### Single Unified Stream Pipeline

The entire log analysis is performed as **one continuous stream pipeline**:

```perl
# walk -> filter -> stringify -> read lines -> parse -> accumulate
my $stats = IO::Stream::Directories
    ->walk($log_dir)
    ->grep(sub ($path) { $path =~ /\.log$/ })
    ->map(sub ($path) { $path->stringify })
    ->flat_map(sub ($log_file) {
        IO::Stream::Files
            ->lines($log_file)
            ->grep(sub ($line) { $line !~ /^\s*$/ })
            ->map(sub ($line) {
                return {
                    file   => $log_file,
                    result => $parser->parse_line($line),
                };
            });
    })
    ->reduce(
        {
            files_analyzed => [],
            event_counts   => {},
            hourly_errors  => {},
            parse_errors   => [],
            earliest_time  => undef,
            latest_time    => undef,
        },
        sub ($item, $acc) {
            # Accumulate all statistics
            # ...
            return $acc;
        }
    );

# $stats now contains all accumulated data
# No intermediate variables or loops needed!
```

This single pipeline:
- Finds all .log files recursively
- Reads and filters lines from each file
- Parses each line with Result types
- Accumulates all statistics in one pass
- Returns a complete stats object

### Result Types for Safe Parsing

```perl
my $result = $parser->parse_line($line);

if ($result->success) {
    my $entry = $result->ok;
    # Process valid entry
} else {
    # Handle parse error
    my $error = $result->error;
}
```

### Vector Math for Anomaly Detection

```perl
my $vector = Vector->initialize(scalar(@counts), \@counts);
my $mean = $vector->mean;
my $stddev = calculate_stddev($vector, $mean);
my $threshold = $mean + (2 * $stddev);

# Detect values above threshold
```

### Stream Operations Used

The pipeline demonstrates all major stream operations:

- **`->grep()`** - Filter paths and empty lines
- **`->map()`** - Transform paths and parse lines
- **`->flat_map()`** - Flatten nested streams (files → lines)
- **`->reduce()`** - Fold entire stream into single result
- **Stream composition** - Nested streams (IO::Stream::Files inside flat_map)

### Diagnostics for Malformed Logs

Malformed log entries automatically trigger diagnostics with:
- Source context highlighting
- Line numbers
- Stack backtraces
- Syntax highlighting

## Dependencies

- Perl v5.42+
- grey::static module
- Path::Tiny (for recursive file finding)

## License

Same as grey::static

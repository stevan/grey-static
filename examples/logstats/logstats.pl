#!/usr/bin/env perl
use v5.42;
use utf8;
use experimental qw[ class ];

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../../lib";

use grey::static qw[
    functional
    stream
    io::stream
    datatypes::util
    datatypes::ml
];

use LogParser;
use TimeSeriesAnalyzer;
use Reporter;

# Get directory from command line, default to sample-logs
my $log_dir = shift @ARGV || "$FindBin::Bin/sample-logs";

die "Directory not found: $log_dir\n" unless -d $log_dir;

say "Analyzing logs in: $log_dir\n";

# Initialize components
my $parser = LogParser->new;
my $analyzer = TimeSeriesAnalyzer->new;
my $reporter = Reporter->new;

say "Analyzing logs...\n";

# Single continuous stream pipeline:
# walk directory -> filter .log files -> read lines -> parse -> accumulate stats
my $stats = IO::Stream::Directories
    ->walk($log_dir)
    ->grep(sub ($path) { $path =~ /\.log$/ })
    ->map(sub ($path) { $path->stringify })
    ->flat_map(sub ($log_file) {
        say "Processing: $log_file";

        # Return stream of {file, result} for each line in the file
        IO::Stream::Files
            ->lines($log_file)
            ->grep(sub ($line) { $line !~ /^\s*$/ })  # Skip empty lines
            ->map(sub ($line) {
                return {
                    file   => $log_file,
                    result => $parser->parse_line($line),
                };
            });
    })
    ->reduce(
        # Initial accumulator value
        {
            files_analyzed => [],
            event_counts   => {},
            hourly_errors  => {},
            parse_errors   => [],
            earliest_time  => undef,
            latest_time    => undef,
        },
        # Reduction function: accumulate statistics
        sub ($item, $acc) {
            my $result = $item->{result};
            my $file = $item->{file};

            # Track which files we've seen
            if (!grep { $_ eq $file } @{$acc->{files_analyzed}}) {
                push @{$acc->{files_analyzed}}, $file;
            }

            if ($result->success) {
                my $entry = $result->ok;

                # Count by level
                $acc->{event_counts}{$entry->{level}}++;

                # Track time range
                if (!defined $acc->{earliest_time} || $entry->{timestamp} lt $acc->{earliest_time}) {
                    $acc->{earliest_time} = $entry->{timestamp};
                }
                if (!defined $acc->{latest_time} || $entry->{timestamp} gt $acc->{latest_time}) {
                    $acc->{latest_time} = $entry->{timestamp};
                }

                # Count errors by hour
                if ($entry->{level} eq 'ERROR') {
                    my $hour = $parser->extract_hour($entry->{timestamp});
                    $acc->{hourly_errors}{$hour}++;
                }
            }
            else {
                # Parse error - record it
                push @{$acc->{parse_errors}}, "$file: " . $result->error;
            }

            return $acc;  # Return accumulator for next iteration
        }
    );

say "\nFound ", scalar(@{$stats->{files_analyzed}}), " log files\n";

# Perform anomaly detection on hourly error counts
$stats->{anomaly_result} = $analyzer->detect_anomalies($stats->{hourly_errors});

# Add time_range structure for reporter
$stats->{time_range} = {
    earliest => $stats->{earliest_time},
    latest   => $stats->{latest_time},
};

# Generate and display report
my $report = $reporter->generate($stats);
say $report;

# Demonstrate diagnostics by triggering a warning for parse errors
if (@{$stats->{parse_errors}}) {
    warn "Found " . scalar(@{$stats->{parse_errors}}) . " malformed log lines\n";
}

say "Analysis complete!";

use v5.42;
use utf8;
use experimental qw[ class ];

class Reporter {

    # Generate a summary report from analysis statistics
    # Input: hashref with {
    #   files_analyzed => [...],
    #   event_counts   => { ERROR => n, WARN => n, INFO => n },
    #   time_range     => { earliest => timestamp, latest => timestamp },
    #   anomaly_result => { mean, stddev, threshold, anomalies => [...] },
    #   parse_errors   => [...],
    # }
    # Output: formatted report string
    method generate ($stats) {
        my @lines;

        # Header
        push @lines, "Log Analysis Report";
        push @lines, "=" x 50;
        push @lines, "";

        # Files analyzed
        my $file_count = scalar @{$stats->{files_analyzed}};
        push @lines, "Files analyzed: $file_count";

        # Time range
        if ($stats->{time_range}) {
            my $earliest = $stats->{time_range}{earliest};
            my $latest = $stats->{time_range}{latest};
            push @lines, "Time range: $earliest - $latest";
        }
        push @lines, "";

        # Event counts
        push @lines, "Event counts:";
        for my $level (qw[ ERROR WARN INFO ]) {
            my $count = $stats->{event_counts}{$level} // 0;
            my $formatted = $self->format_number($count);
            push @lines, sprintf("  %-7s %s", "$level:", $formatted);
        }
        push @lines, "";

        # Anomaly detection
        my $anomaly = $stats->{anomaly_result};
        if ($anomaly) {
            push @lines, "Anomaly detection (hourly errors):";
            push @lines, sprintf("  Mean: %.1f errors/hour", $anomaly->{mean});
            push @lines, sprintf("  Threshold: %.1f (mean + 2σ)", $anomaly->{threshold});
            push @lines, "";

            if (@{$anomaly->{anomalies}}) {
                for my $a (@{$anomaly->{anomalies}}) {
                    push @lines, sprintf("  ⚠ Hour %d: %d errors", $a->{hour}, $a->{count});
                }
            } else {
                push @lines, "  No anomalies detected";
            }
            push @lines, "";
        }

        # Parse errors
        if ($stats->{parse_errors} && @{$stats->{parse_errors}}) {
            push @lines, "Parse errors:";
            for my $error (@{$stats->{parse_errors}}) {
                push @lines, "  - $error";
            }
            push @lines, "";
        }

        return join("\n", @lines);
    }

    # Format number with comma separators
    method format_number ($num) {
        # Add commas to thousands
        my $text = reverse $num;
        $text =~ s/(\d{3})(?=\d)/$1,/g;
        return reverse $text;
    }
}

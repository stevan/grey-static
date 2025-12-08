use v5.42;
use utf8;
use experimental qw[ class ];

class EventReporter {

    # Generate a report from aggregated statistics
    method generate_report ($stats) {
        my @lines;

        push @lines, "Event Stream Processing Report";
        push @lines, "=" x 50;
        push @lines, "";
        push @lines, "Total events processed: $stats->{total}";
        push @lines, "";

        push @lines, "Events by type:";
        for my $type (sort keys %{$stats->{by_type}}) {
            push @lines, sprintf("  %-15s %d", $type, $stats->{by_type}{$type});
        }
        push @lines, "";

        if ($stats->{temperature}) {
            push @lines, "Temperature statistics:";
            push @lines, sprintf("  Count: %d", $stats->{temperature}{count});
            push @lines, sprintf("  Mean:  %.1f°C", $stats->{temperature}{mean});
            push @lines, sprintf("  Min:   %.1f°C", $stats->{temperature}{min});
            push @lines, sprintf("  Max:   %.1f°C", $stats->{temperature}{max});
        }

        return join("\n", @lines);
    }
}

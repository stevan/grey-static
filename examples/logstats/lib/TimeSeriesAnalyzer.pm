use v5.42;
use experimental qw[ class ];

use grey::static qw[ datatypes::numeric ];

class TimeSeriesAnalyzer {

    # Detect anomalies in hourly error counts using simple statistical analysis
    # Input: hashref of { hour => count }
    # Output: hashref with { mean, stddev, threshold, anomalies => [ { hour, count }, ... ] }
    method detect_anomalies ($hourly_counts) {
        my @hours = sort { $a <=> $b } keys %$hourly_counts;
        my @counts = map { $hourly_counts->{$_} } @hours;

        return {
            mean      => 0,
            stddev    => 0,
            threshold => 0,
            anomalies => [],
        } if @counts == 0;

        # Create Vector from counts
        my $vector = Vector->initialize(scalar(@counts), \@counts);

        # Calculate mean
        my $mean = $vector->mean;

        # Calculate standard deviation
        my $stddev = $self->calculate_stddev($vector, $mean);

        # Threshold for anomaly: mean + 2 * stddev
        my $threshold = $mean + (2 * $stddev);

        # Find anomalies
        my @anomalies;
        for my $i (0..$#hours) {
            my $hour = $hours[$i];
            my $count = $counts[$i];

            if ($count > $threshold) {
                push @anomalies, {
                    hour  => $hour,
                    count => $count,
                };
            }
        }

        return {
            mean      => $mean,
            stddev    => $stddev,
            threshold => $threshold,
            anomalies => \@anomalies,
        };
    }

    # Calculate standard deviation: sqrt(mean((x - mean)^2))
    method calculate_stddev ($vector, $mean) {
        return 0 if $vector->size == 0;
        return 0 if $vector->size == 1;

        # Calculate variance: mean of squared differences from mean
        my $sum_squared_diff = 0;
        for my $i (0..$vector->size - 1) {
            my $diff = $vector->at($i) - $mean;
            $sum_squared_diff += $diff * $diff;
        }

        my $variance = $sum_squared_diff / $vector->size;

        return sqrt($variance);
    }
}

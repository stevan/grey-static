use v5.42;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../../lib";

use grey::static qw[ datatypes::ml ];
use TimeSeriesAnalyzer;

subtest 'analyze with no anomalies' => sub {
    my $analyzer = TimeSeriesAnalyzer->new;

    # Hourly error counts: fairly uniform, no outliers
    my %hourly_counts = (
        0  => 10,
        1  => 12,
        2  => 11,
        3  => 9,
        4  => 10,
        5  => 11,
        6  => 10,
        7  => 12,
        8  => 11,
        9  => 10,
        10 => 9,
        11 => 11,
        12 => 10,
        13 => 12,
        14 => 11,
        15 => 10,
        16 => 9,
        17 => 11,
        18 => 10,
        19 => 12,
        20 => 11,
        21 => 10,
        22 => 9,
        23 => 11,
    );

    my $result = $analyzer->detect_anomalies(\%hourly_counts);

    ok($result, 'result returned');
    is($result->{mean}, 10.5, 'mean calculated correctly');
    ok($result->{stddev} > 0, 'stddev calculated');
    is(scalar @{$result->{anomalies}}, 0, 'no anomalies detected');
};

subtest 'analyze with anomalies' => sub {
    my $analyzer = TimeSeriesAnalyzer->new;

    # Hourly error counts with anomalies at hours 14 and 18
    my %hourly_counts = (
        0  => 10,
        1  => 12,
        2  => 11,
        3  => 9,
        4  => 10,
        5  => 11,
        6  => 10,
        7  => 12,
        8  => 11,
        9  => 10,
        10 => 9,
        11 => 11,
        12 => 10,
        13 => 12,
        14 => 89,  # ANOMALY!
        15 => 10,
        16 => 9,
        17 => 11,
        18 => 67,  # ANOMALY!
        19 => 12,
        20 => 11,
        21 => 10,
        22 => 9,
        23 => 11,
    );

    my $result = $analyzer->detect_anomalies(\%hourly_counts);

    ok($result, 'result returned');
    ok($result->{mean} > 10, 'mean is higher due to anomalies');
    ok($result->{stddev} > 0, 'stddev calculated');
    ok($result->{threshold} > $result->{mean}, 'threshold is mean + 2*stddev');

    is(scalar @{$result->{anomalies}}, 2, 'two anomalies detected');

    my @anomalies = sort { $a->{hour} <=> $b->{hour} } @{$result->{anomalies}};

    is($anomalies[0]->{hour}, 14, 'first anomaly is hour 14');
    is($anomalies[0]->{count}, 89, 'first anomaly count is 89');

    is($anomalies[1]->{hour}, 18, 'second anomaly is hour 18');
    is($anomalies[1]->{count}, 67, 'second anomaly count is 67');
};

subtest 'analyze with single anomaly' => sub {
    my $analyzer = TimeSeriesAnalyzer->new;

    my %hourly_counts = map { $_ => 5 } (0..23);
    $hourly_counts{15} = 100;  # Single spike

    my $result = $analyzer->detect_anomalies(\%hourly_counts);

    is(scalar @{$result->{anomalies}}, 1, 'one anomaly detected');
    is($result->{anomalies}[0]->{hour}, 15, 'anomaly at hour 15');
    is($result->{anomalies}[0]->{count}, 100, 'anomaly count is 100');
};

subtest 'analyze with empty hours' => sub {
    my $analyzer = TimeSeriesAnalyzer->new;

    # Only some hours have data
    my %hourly_counts = (
        8  => 10,
        9  => 12,
        10 => 11,
        14 => 89,  # Should still be an anomaly
        17 => 10,
        18 => 11,
    );

    my $result = $analyzer->detect_anomalies(\%hourly_counts);

    ok($result, 'result returned for sparse data');
    ok(scalar @{$result->{anomalies}} > 0, 'anomaly detected in sparse data');
};

subtest 'analyze with all zeros' => sub {
    my $analyzer = TimeSeriesAnalyzer->new;

    my %hourly_counts = map { $_ => 0 } (0..23);

    my $result = $analyzer->detect_anomalies(\%hourly_counts);

    is($result->{mean}, 0, 'mean is 0 for all zeros');
    is($result->{stddev}, 0, 'stddev is 0 for all zeros');
    is(scalar @{$result->{anomalies}}, 0, 'no anomalies in uniform data');
};

subtest 'analyze with single data point' => sub {
    my $analyzer = TimeSeriesAnalyzer->new;

    my %hourly_counts = ( 12 => 50 );

    my $result = $analyzer->detect_anomalies(\%hourly_counts);

    ok($result, 'handles single data point');
    is($result->{mean}, 50, 'mean is the single value');
    is($result->{stddev}, 0, 'stddev is 0 for single value');
};

done_testing;

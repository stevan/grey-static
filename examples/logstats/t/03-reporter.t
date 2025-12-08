use v5.42;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../../lib";

use Reporter;

subtest 'generate basic report' => sub {
    my $reporter = Reporter->new;

    my $stats = {
        files_analyzed => ['app.log', 'errors.log'],
        event_counts   => { ERROR => 145, WARN => 432, INFO => 15234 },
        time_range     => {
            earliest => '2024-01-15 00:00:12',
            latest   => '2024-01-15 23:59:45',
        },
        anomaly_result => {
            mean      => 12.3,
            stddev    => 5.2,
            threshold => 22.7,
            anomalies => [],
        },
        parse_errors   => [],
    };

    my $report = $reporter->generate($stats);

    ok($report, 'report generated');
    like($report, qr/Log Analysis Report/, 'report has title');
    like($report, qr/Files analyzed:\s+2/, 'shows file count');
    like($report, qr/ERROR:\s+145/, 'shows ERROR count');
    like($report, qr/WARN:\s+432/, 'shows WARN count');
    like($report, qr/INFO:\s+15,?234/, 'shows INFO count with comma separator');
    like($report, qr/2024-01-15 00:00/, 'shows earliest time');
    like($report, qr/2024-01-15 23:59/, 'shows latest time');
    like($report, qr/Mean:\s+12\.3/, 'shows mean errors/hour');
};

subtest 'generate report with anomalies' => sub {
    my $reporter = Reporter->new;

    my $stats = {
        files_analyzed => ['app.log'],
        event_counts   => { ERROR => 200, WARN => 100, INFO => 1000 },
        time_range     => {
            earliest => '2024-01-15 08:00:00',
            latest   => '2024-01-15 18:00:00',
        },
        anomaly_result => {
            mean      => 12.3,
            stddev    => 6.2,
            threshold => 24.7,
            anomalies => [
                { hour => 14, count => 89 },
                { hour => 18, count => 67 },
            ],
        },
        parse_errors   => [],
    };

    my $report = $reporter->generate($stats);

    ok($report, 'report generated');
    like($report, qr/Anomaly detection/, 'has anomaly section');
    like($report, qr/Threshold:\s+24\.7/, 'shows threshold');
    like($report, qr/Hour 14.*89 errors/i, 'shows first anomaly');
    like($report, qr/Hour 18.*67 errors/i, 'shows second anomaly');
};

subtest 'generate report with parse errors' => sub {
    my $reporter = Reporter->new;

    my $stats = {
        files_analyzed => ['app.log'],
        event_counts   => { ERROR => 10, WARN => 20, INFO => 100 },
        time_range     => {
            earliest => '2024-01-15 09:00:00',
            latest   => '2024-01-15 17:00:00',
        },
        anomaly_result => {
            mean      => 5.0,
            stddev    => 1.0,
            threshold => 7.0,
            anomalies => [],
        },
        parse_errors   => [
            'Invalid log format at line 45',
            'Missing timestamp at line 102',
        ],
    };

    my $report = $reporter->generate($stats);

    ok($report, 'report generated');
    like($report, qr/Parse errors/i, 'has parse errors section');
    like($report, qr/line 45/, 'shows first parse error');
    like($report, qr/line 102/, 'shows second parse error');
};

subtest 'generate report with no anomalies' => sub {
    my $reporter = Reporter->new;

    my $stats = {
        files_analyzed => ['app.log'],
        event_counts   => { ERROR => 50, WARN => 100, INFO => 1000 },
        time_range     => {
            earliest => '2024-01-15 00:00:00',
            latest   => '2024-01-15 23:59:59',
        },
        anomaly_result => {
            mean      => 10.0,
            stddev    => 2.0,
            threshold => 14.0,
            anomalies => [],
        },
        parse_errors   => [],
    };

    my $report = $reporter->generate($stats);

    ok($report, 'report generated');
    like($report, qr/No anomalies detected/i, 'indicates no anomalies');
};

subtest 'format number with commas' => sub {
    my $reporter = Reporter->new;

    is($reporter->format_number(123), '123', 'small number no comma');
    is($reporter->format_number(1234), '1,234', 'thousand with comma');
    is($reporter->format_number(12345), '12,345', 'ten thousand with comma');
    is($reporter->format_number(123456), '123,456', 'hundred thousand with comma');
    is($reporter->format_number(1234567), '1,234,567', 'million with commas');
};

done_testing;

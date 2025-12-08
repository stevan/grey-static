#!/usr/bin/env perl
use v5.42;

# Script to generate sample log files for testing the log analyzer

my $date = '2024-01-15';

# Generate app.log with normal activity and anomalies
generate_app_log();

# Generate errors.log
generate_errors_log();

# Generate services logs
generate_auth_log();
generate_api_log();

say "Sample logs generated successfully!";

sub generate_app_log {
    open my $fh, '>', 'sample-logs/app.log' or die $!;

    # Generate logs for each hour
    for my $hour (0..23) {
        my $error_count = 5;  # Normal error count

        # Create anomalies at hours 14 and 18
        $error_count = 89 if $hour == 14;
        $error_count = 67 if $hour == 18;

        # Generate INFO messages (most common)
        for (1..50) {
            my $min = int(rand(60));
            my $sec = int(rand(60));
            printf $fh "%s %02d:%02d:%02d [INFO] Request processed successfully\n",
                $date, $hour, $min, $sec;
        }

        # Generate WARN messages
        for (1..10) {
            my $min = int(rand(60));
            my $sec = int(rand(60));
            printf $fh "%s %02d:%02d:%02d [WARN] Cache miss for key user_%d\n",
                $date, $hour, $min, $sec, int(rand(1000));
        }

        # Generate ERROR messages
        for (1..$error_count) {
            my $min = int(rand(60));
            my $sec = int(rand(60));
            printf $fh "%s %02d:%02d:%02d [ERROR] Database query timeout after 5000ms\n",
                $date, $hour, $min, $sec;
        }
    }

    # Add some malformed lines
    say $fh "[ERROR] This line is missing a timestamp";
    say $fh "$date 12:34:56 Missing log level here";
    say $fh "   ";  # Empty line with whitespace

    close $fh;
    say "Generated sample-logs/app.log";
}

sub generate_errors_log {
    open my $fh, '>', 'sample-logs/errors.log' or die $!;

    for my $hour (0..23) {
        for (1..5) {
            my $min = int(rand(60));
            my $sec = int(rand(60));
            printf $fh "%s %02d:%02d:%02d [ERROR] Connection refused: unable to connect to database\n",
                $date, $hour, $min, $sec;
        }

        for (1..3) {
            my $min = int(rand(60));
            my $sec = int(rand(60));
            printf $fh "%s %02d:%02d:%02d [ERROR] Request failed: HTTP 500 - Internal Server Error\n",
                $date, $hour, $min, $sec;
        }
    }

    close $fh;
    say "Generated sample-logs/errors.log";
}

sub generate_auth_log {
    open my $fh, '>', 'sample-logs/services/auth.log' or die $!;

    for my $hour (8..18) {  # Auth service only during business hours
        for (1..20) {
            my $min = int(rand(60));
            my $sec = int(rand(60));
            printf $fh "%s %02d:%02d:%02d [INFO] User authentication successful for user_%d\n",
                $date, $hour, $min, $sec, int(rand(100));
        }

        for (1..2) {
            my $min = int(rand(60));
            my $sec = int(rand(60));
            printf $fh "%s %02d:%02d:%02d [WARN] Failed login attempt for user_%d\n",
                $date, $hour, $min, $sec, int(rand(100));
        }

        # More failures during anomaly hours
        if ($hour == 14 or $hour == 18) {
            for (1..25) {
                my $min = int(rand(60));
                my $sec = int(rand(60));
                printf $fh "%s %02d:%02d:%02d [ERROR] Authentication service timeout\n",
                    $date, $hour, $min, $sec;
            }
        }
    }

    close $fh;
    say "Generated sample-logs/services/auth.log";
}

sub generate_api_log {
    open my $fh, '>', 'sample-logs/services/api.log' or die $!;

    for my $hour (0..23) {
        for (1..100) {
            my $min = int(rand(60));
            my $sec = int(rand(60));
            printf $fh "%s %02d:%02d:%02d [INFO] GET /api/v1/users - 200 OK\n",
                $date, $hour, $min, $sec;
        }

        for (1..5) {
            my $min = int(rand(60));
            my $sec = int(rand(60));
            printf $fh "%s %02d:%02d:%02d [WARN] Rate limit exceeded for IP 192.168.1.%d\n",
                $date, $hour, $min, $sec, int(rand(255));
        }

        # Spike in API errors during anomaly hours
        my $error_count = 2;
        $error_count = 30 if $hour == 14;
        $error_count = 20 if $hour == 18;

        for (1..$error_count) {
            my $min = int(rand(60));
            my $sec = int(rand(60));
            printf $fh "%s %02d:%02d:%02d [ERROR] API gateway error: upstream service unavailable\n",
                $date, $hour, $min, $sec;
        }
    }

    close $fh;
    say "Generated sample-logs/services/api.log";
}

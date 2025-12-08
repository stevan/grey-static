use v5.42;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../../lib";

use grey::static qw[ datatypes::util ];
use LogParser;

subtest 'parse valid log lines' => sub {
    my $parser = LogParser->new;

    subtest 'parse INFO level' => sub {
        my $result = $parser->parse_line('2024-01-15 09:23:45 [INFO] Connection established');

        ok($result->success, 'parsing succeeds');

        my $entry = $result->ok;
        is($entry->{timestamp}, '2024-01-15 09:23:45', 'timestamp extracted');
        is($entry->{level}, 'INFO', 'level extracted');
        is($entry->{message}, 'Connection established', 'message extracted');
    };

    subtest 'parse ERROR level' => sub {
        my $result = $parser->parse_line('2024-01-15 09:23:45 [ERROR] Database connection timeout');

        ok($result->success, 'parsing succeeds');

        my $entry = $result->ok;
        is($entry->{level}, 'ERROR', 'ERROR level extracted');
        is($entry->{message}, 'Database connection timeout', 'error message extracted');
    };

    subtest 'parse WARN level' => sub {
        my $result = $parser->parse_line('2024-01-15 09:23:46 [WARN] Retrying connection (attempt 2/3)');

        ok($result->success, 'parsing succeeds');

        my $entry = $result->ok;
        is($entry->{level}, 'WARN', 'WARN level extracted');
        is($entry->{message}, 'Retrying connection (attempt 2/3)', 'warning message extracted');
    };

    subtest 'parse with complex message' => sub {
        my $result = $parser->parse_line('2024-01-15 14:35:22 [ERROR] Request failed: HTTP 500 - Internal Server Error');

        ok($result->success, 'parsing succeeds');

        my $entry = $result->ok;
        is($entry->{message}, 'Request failed: HTTP 500 - Internal Server Error', 'complex message preserved');
    };
};

subtest 'parse malformed log lines' => sub {
    my $parser = LogParser->new;

    subtest 'missing timestamp' => sub {
        my $result = $parser->parse_line('[ERROR] Something went wrong');

        ok($result->failure, 'parsing fails for missing timestamp');
        like($result->error, qr/malformed/i, 'error message mentions malformed');
    };

    subtest 'missing level' => sub {
        my $result = $parser->parse_line('2024-01-15 09:23:45 Something went wrong');

        ok($result->failure, 'parsing fails for missing level');
    };

    subtest 'invalid timestamp format' => sub {
        my $result = $parser->parse_line('15-01-2024 09:23 [INFO] Message');

        ok($result->failure, 'parsing fails for invalid timestamp');
    };

    subtest 'empty line' => sub {
        my $result = $parser->parse_line('');

        ok($result->failure, 'parsing fails for empty line');
    };

    subtest 'whitespace only' => sub {
        my $result = $parser->parse_line('   ');

        ok($result->failure, 'parsing fails for whitespace');
    };
};

subtest 'extract hour from timestamp' => sub {
    my $parser = LogParser->new;

    subtest 'extract hour 9' => sub {
        my $result = $parser->parse_line('2024-01-15 09:23:45 [INFO] Test');
        my $entry = $result->ok;

        is($parser->extract_hour($entry->{timestamp}), 9, 'hour 9 extracted');
    };

    subtest 'extract hour 14' => sub {
        my $result = $parser->parse_line('2024-01-15 14:35:22 [ERROR] Test');
        my $entry = $result->ok;

        is($parser->extract_hour($entry->{timestamp}), 14, 'hour 14 extracted');
    };

    subtest 'extract hour 0' => sub {
        my $result = $parser->parse_line('2024-01-15 00:15:30 [INFO] Test');
        my $entry = $result->ok;

        is($parser->extract_hour($entry->{timestamp}), 0, 'hour 0 extracted');
    };

    subtest 'extract hour 23' => sub {
        my $result = $parser->parse_line('2024-01-15 23:59:59 [WARN] Test');
        my $entry = $result->ok;

        is($parser->extract_hour($entry->{timestamp}), 23, 'hour 23 extracted');
    };
};

done_testing;

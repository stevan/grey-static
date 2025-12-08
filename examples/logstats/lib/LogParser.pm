use v5.42;
use experimental qw[ class ];

use grey::static qw[ datatypes::util ];

class LogParser {

    # Parse a log line in format: YYYY-MM-DD HH:MM:SS [LEVEL] message
    # Returns Result with ok => { timestamp, level, message } or error => reason
    method parse_line ($line) {
        # Trim whitespace
        $line =~ s/^\s+|\s+$//g;

        # Check for empty line
        return Error('Malformed log line: empty or whitespace only')
            if $line eq '';

        # Expected format: YYYY-MM-DD HH:MM:SS [LEVEL] message
        # Pattern: timestamp (19 chars), space, [LEVEL], space, message
        if ($line =~ /^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(\w+)\] (.+)$/) {
            my ($timestamp, $level, $message) = ($1, $2, $3);

            return Ok({
                timestamp => $timestamp,
                level     => $level,
                message   => $message,
            });
        }

        return Error('Malformed log line: does not match expected format');
    }

    # Extract hour (0-23) from timestamp string
    method extract_hour ($timestamp) {
        if ($timestamp =~ /^\d{4}-\d{2}-\d{2} (\d{2}):\d{2}:\d{2}$/) {
            return int($1);
        }
        return undef;
    }
}

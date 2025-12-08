use v5.42;
use experimental qw[ class ];

use grey::static qw[ functional concurrency datatypes::util ];

class EventProcessor {

    # Filter events by type using Flow::grep
    # Returns the built Flow (which wraps the publisher)
    method filter_by_type ($publisher, $event_type, $consumer_fn) {
        return Flow
            ->from($publisher)
            ->grep(sub ($event) {
                $event->{type} eq $event_type;
            })
            ->to($consumer_fn)
            ->build;
    }

    # Validate an event based on its type
    method validate_event ($event) {
        my $type = $event->{type};

        # Check common required fields
        return Error('Missing timestamp') unless exists $event->{timestamp};
        return Error('Missing type') unless defined $type;

        # Type-specific validation
        if ($type eq 'temperature' || $type eq 'humidity') {
            return Error("Missing value for $type event")
                unless exists $event->{value};
        }
        elsif ($type eq 'alert') {
            return Error('Missing severity for alert event')
                unless exists $event->{severity};
            return Error('Missing message for alert event')
                unless exists $event->{message};
        }
        elsif ($type eq 'motion') {
            return Error('Missing detected field for motion event')
                unless exists $event->{detected};
        }

        return Ok($event);
    }

    # Transform temperature events to include Fahrenheit
    method transform_temperature ($publisher, $consumer_fn) {
        return Flow
            ->from($publisher)
            ->map(sub ($event) {
                my $celsius = $event->{value};
                my $fahrenheit = $celsius * 9/5 + 32;

                return {
                    %$event,
                    celsius    => $celsius,
                    fahrenheit => $fahrenheit,
                };
            })
            ->to($consumer_fn)
            ->build;
    }

    # Filter by type and validate, separating valid from invalid events
    method filter_and_validate ($publisher, $event_type, $valid_consumer, $invalid_consumer) {
        return Flow
            ->from($publisher)
            ->grep(sub ($event) {
                $event->{type} eq $event_type;
            })
            ->to(sub ($event) {
                my $result = $self->validate_event($event);

                if ($result->success) {
                    $valid_consumer->($result->ok);
                } else {
                    $invalid_consumer->($result->error);
                }
            })
            ->build;
    }
}

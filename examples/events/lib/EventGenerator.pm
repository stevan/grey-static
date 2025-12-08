use v5.42;
use experimental qw[ class ];

use grey::static qw[ concurrency ];

class EventGenerator {

    # Generate temperature events
    method temperature_events (%args) {
        my $count = $args{count} // 10;
        my $publisher = Flow::Publisher->new;

        for my $i (1..$count) {
            my $event = {
                type      => 'temperature',
                value     => int(rand(100)) - 50,  # -50 to 50
                timestamp => time + $i,
                id        => $i,
            };
            $publisher->submit($event);
        }

        return $publisher;
    }

    # Generate humidity events
    method humidity_events (%args) {
        my $count = $args{count} // 10;
        my $publisher = Flow::Publisher->new;

        for my $i (1..$count) {
            my $event = {
                type      => 'humidity',
                value     => int(rand(101)),  # 0-100
                timestamp => time + $i,
                id        => $i,
            };
            $publisher->submit($event);
        }

        return $publisher;
    }

    # Generate motion detection events
    method motion_events (%args) {
        my $count = $args{count} // 10;
        my $publisher = Flow::Publisher->new;

        for my $i (1..$count) {
            my $event = {
                type      => 'motion',
                detected  => (rand() > 0.5) ? 'yes' : 'no',
                timestamp => time + $i,
                id        => $i,
            };
            $publisher->submit($event);
        }

        return $publisher;
    }

    # Generate alert events
    method alert_events (%args) {
        my $count = $args{count} // 10;
        my $publisher = Flow::Publisher->new;

        my @severities = qw[ low medium high critical ];
        my @messages = (
            'Temperature threshold exceeded',
            'Humidity out of range',
            'Motion detected in restricted area',
            'System health check failed',
        );

        for my $i (1..$count) {
            my $event = {
                type      => 'alert',
                severity  => $severities[int(rand(@severities))],
                message   => $messages[int(rand(@messages))],
                timestamp => time + $i,
                id        => $i,
            };
            $publisher->submit($event);
        }

        return $publisher;
    }

    # Generate mixed event types
    method mixed_events (%args) {
        my $count = $args{count} // 100;
        my $publisher = Flow::Publisher->new;

        my @types = qw[ temperature humidity motion alert ];

        for my $i (1..$count) {
            my $type = $types[int(rand(@types))];
            my $event = {
                timestamp => time + $i,
                id        => $i,
            };

            if ($type eq 'temperature') {
                $event->{type} = 'temperature';
                $event->{value} = int(rand(100)) - 50;
            }
            elsif ($type eq 'humidity') {
                $event->{type} = 'humidity';
                $event->{value} = int(rand(101));
            }
            elsif ($type eq 'motion') {
                $event->{type} = 'motion';
                $event->{detected} = (rand() > 0.5) ? 'yes' : 'no';
            }
            else {  # alert
                $event->{type} = 'alert';
                $event->{severity} = [qw[ low medium high critical ]]->[int(rand(4))];
                $event->{message} = 'System alert';
            }

            $publisher->submit($event);
        }

        return $publisher;
    }
}

use v5.42;
use experimental qw[ class ];

use grey::static qw[ datatypes::numeric ];

class EventAggregator {

    # Aggregate event statistics
    method aggregate ($events) {
        my %stats = (
            total => scalar(@$events),
            by_type => {},
        );

        # Count by type
        for my $event (@$events) {
            $stats{by_type}{$event->{type}}++;
        }

        # Temperature statistics
        my @temps = map { $_->{value} } grep { $_->{type} eq 'temperature' } @$events;
        if (@temps) {
            my $vector = Vector->initialize(scalar(@temps), \@temps);
            $stats{temperature} = {
                count => scalar(@temps),
                mean => $vector->mean,
                min => $vector->min_value,
                max => $vector->max_value,
            };
        }

        return \%stats;
    }
}


use v5.42;
use experimental qw[ class ];

use Flow::Publisher::Merge;
use Flow::Publisher::Concat;
use Flow::Publisher::Zip;

# Factory class for creating publishers from multiple sources
class Flow::Publishers {

    # Merge multiple publishers - emit from any as soon as available
    sub merge ($class, @publishers) {
        return Flow::Publisher::Merge->new(
            sources => \@publishers
        );
    }

    # Concatenate publishers - emit first fully, then second, etc.
    sub concat ($class, @publishers) {
        return Flow::Publisher::Concat->new(
            sources => \@publishers
        );
    }

    # Zip publishers - pair up corresponding elements
    sub zip ($class, @args) {
        # Last argument is the combiner function/bifunction
        my $combiner = pop @args;
        my @publishers = @args;

        # Convert combiner to BiFunction if needed
        if (!blessed $combiner) {
            $combiner = BiFunction->new(f => $combiner);
        }

        return Flow::Publisher::Zip->new(
            sources  => \@publishers,
            combiner => $combiner
        );
    }
}


use v5.42;
use experimental qw[ class ];

use MOP::Source::GlobsFromStash;

class MOP :isa(Stream) {

    sub namespace ($class, $stash) {
        unless (ref $stash) {
            no strict 'refs';
            $stash = \%{ $stash . '::' };
        }

        $class->new(
            source => MOP::Source::GlobsFromStash->new(
                stash => $stash
            )
        )
    }

    sub mro ($class, $klass) {
        $class->of( mro::get_linear_isa( $klass )->@* )
              ->flat_map( sub ($c) { $class->namespace( $c ) } )
    }

    ## -------------------------------------------------------------------------

    method expand_symbols (@slots) {
        $self->flatten(sub ($g) { $g->get_all_symbols( @slots ) })
    }

    method walk {
        $self->recurse(
            sub ($g) { $g->is_stash },
            sub ($g) { MOP::Source::GlobsFromStash->new(
                stash => $g->get_slot_value('HASH')
            )}
        )
    }

}

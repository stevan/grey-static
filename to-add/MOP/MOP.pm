
use v5.40;
use experimental qw[ class ];

use Stream::MOP::Source::GlobsFromStash;

class Stream::MOP :isa(Stream) {

    sub namespace ($class, $stash) {
        unless (ref $stash) {
            no strict 'refs';
            $stash = \%{ $stash . '::' };
        }

        $class->new(
            source => Stream::MOP::Source::GlobsFromStash->new(
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
            sub ($g) { Stream::MOP::Source::GlobsFromStash->new(
                stash => $g->get_slot_value('HASH')
            )}
        )
    }

}

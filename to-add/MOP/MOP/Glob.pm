
use v5.40;
use experimental qw[ class ];

use B ();

class Stream::MOP::Glob {
    use overload '""' => \&to_string;

    field $glob :param :reader;

    field $b;
    ADJUST {
        $b = B::svref_2object($glob);
    }

    method name      { $b->SAFENAME    }
    method stash     { $b->STASH->NAME }
    method full_name { join '::' => $self->stash, $self->name }
    method is_stash  { $self->name =~ m/\:\:$/ }

    method has_scalar {
        my $scalar = $self->get_slot_value('SCALAR');
        #warn "!!!!!!!!!!! has SCALAR ".$scalar // '~';
        return false if not defined $scalar;
        return defined $scalar->$*;
    }

    method has_array  { $self->has_slot_value('ARRAY')  }
    method has_hash   { $self->has_slot_value('HASH')   }
    method has_code   { $self->has_slot_value('CODE')   }

    method get_scalar_symbol { Stream::MOP::Symbol->new( glob => $self, ref => $self->get_slot_value('SCALAR') ) }
    method get_array_symbol  { Stream::MOP::Symbol->new( glob => $self, ref => $self->get_slot_value('ARRAY')  ) }
    method get_hash_symbol   { Stream::MOP::Symbol->new( glob => $self, ref => $self->get_slot_value('HASH')   ) }
    method get_code_symbol   { Stream::MOP::Symbol->new( glob => $self, ref => $self->get_slot_value('CODE')   ) }

    method get_all_symbols (@slots) {
        @slots = qw[ SCALAR ARRAY HASH CODE ] unless @slots;
        map  { Stream::MOP::Symbol->new( glob => $self, ref => $_ ) }
        map  { $self->get_slot_value($_) }
        grep { $self->has_slot_value($_) }
        @slots;
    }

    method has_slot_value ($slot) {
        return defined *{ $glob }{ $slot } unless $slot eq 'SCALAR';
        my $scalar = *{ $glob }{ $slot };
        return false if not defined $scalar;
        return defined $scalar->$*;
    }

    method get_slot_value ($slot) { *{ $glob }{$slot} }

    method to_string { '*'.$self->full_name }
}

class Stream::MOP::Symbol {
    use overload '""' => \&to_string;

    field $glob :param :reader;
    field $ref  :param :reader;

    method type { reftype $ref }
    method sigil {
        return +{
            SCALAR => '$',
            ARRAY  => '@',
            HASH   => '%',
            CODE   => '&',
            GLOB   => '*',
            REF    => '\\',
        }->{ reftype $ref }
    }

    method to_string { $self->sigil . $glob->full_name }
}

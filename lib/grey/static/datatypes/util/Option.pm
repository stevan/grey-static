
use v5.42;
use utf8;
use experimental qw[ class ];

class Option {
    use overload '""' => \&to_string;

    field $some :param = undef;

    method defined {  defined($some) }
    method empty   { !defined($some) }

    method get { $some // die 'Runtime Error: calling get on None' }

    method get_or_else ($f) { $some // (ref $f eq 'CODE' ? $f->() : $f) }
    method or_else     ($f) { Option->new(some => $some) // (ref $f eq 'CODE' ? $f->() : $f) }

    method map ($f) { defined $some ? Option->new(some => $f->($some)) : Option->new }

    method to_string {
        return defined $some
            ? sprintf 'Some(%s)' => $some
            : 'None()';
    }
}



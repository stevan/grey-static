
use v5.42;
use utf8;
use experimental qw[ class ];

class Result {
    use overload '""' => \&to_string;

    field $ok    :param :reader = undef;
    field $error :param :reader = undef;

    method failure { defined $error }
    method success { defined $ok    }

    method get_or_else ($f) { $ok // (ref $f eq 'CODE' ? $f->() : $f) }
    method or_else     ($f) { defined $ok ? Result->new(ok => $ok) : (ref $f eq 'CODE' ? $f->() : $f) }

    method map ($f) { defined $ok ? Result->new(ok => $f->($ok)) : Result->new(error => $error) }

    method to_string {
        return defined $ok
            ? sprintf 'Ok(%s)'    => $ok
            : sprintf 'Error(%s)' => $error;
    }
}

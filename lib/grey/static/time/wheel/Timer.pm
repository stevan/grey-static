
use v5.42;
use experimental qw[ class ];

class Timer {
    use overload '""' => \&to_string;
    field $expiry :param :reader;
    field $event  :param :reader;

    method to_string {
        sprintf 'Timer[%d]' => $expiry;
    }
}

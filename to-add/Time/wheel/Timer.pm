
use v5.40;
use experimental qw[ class ];

class VM::Kernel::Timer {
    use overload '""' => \&to_string;
    field $expiry :param :reader;
    field $event  :param :reader;

    method to_string {
        sprintf 'Timer[%d]' => $expiry;
    }
}

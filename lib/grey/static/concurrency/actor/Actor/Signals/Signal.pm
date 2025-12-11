use v5.42;
use experimental qw[ class ];

class Actor::Signals::Signal {
    use overload '""' => 'to_string';

    method to_string { blessed $self }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Actor::Signals::Signal - Base class for actor lifecycle signals

=head1 DESCRIPTION

C<Actor::Signals::Signal> is the base class for all lifecycle signals
in the actor system. Signals are distinct from messages - they represent
system events rather than business logic.

=head1 STRINGIFICATION

Signals stringify to their class name:

    Actor::Signals::Started

=head1 SEE ALSO

L<Actor::Signals::Started>, L<Actor::Signals::Stopping>,
L<Actor::Signals::Stopped>, L<Actor::Signals::Terminated>

=cut

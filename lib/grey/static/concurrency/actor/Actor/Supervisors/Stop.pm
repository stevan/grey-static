use v5.42;
use experimental qw[ class ];

use Actor::Supervisors::Supervisor;

class Actor::Supervisors::Stop :isa(Actor::Supervisors::Supervisor) {
    method supervise ($context, $e) {
        $context->stop;
        return $self->HALT;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Actor::Supervisors::Stop - Stop the actor on error

=head1 SYNOPSIS

    use grey::static qw[ concurrency::actor ];

    my $props = Actor::Props->new(
        class      => 'MyActor',
        supervisor => Actor::Supervisors::Stop->new
    );

=head1 DESCRIPTION

C<Actor::Supervisors::Stop> is the default supervisor strategy. When a message
handler throws an exception, the actor is stopped.

=head1 BEHAVIOR

When C<supervise()> is called:

1. Calls C<< $context->stop >> to initiate actor shutdown
2. Returns C<HALT> to stop message processing

=head1 SEE ALSO

L<Actor::Supervisors::Supervisor>, L<Actor::Props>

=cut

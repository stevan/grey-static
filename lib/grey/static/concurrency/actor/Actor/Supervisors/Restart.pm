use v5.42;
use experimental qw[ class ];

use Actor::Supervisors::Supervisor;

class Actor::Supervisors::Restart :isa(Actor::Supervisors::Supervisor) {
    method supervise ($context, $e) {
        $context->restart;
        return $self->HALT;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Actor::Supervisors::Restart - Restart the actor and re-deliver the message

=head1 SYNOPSIS

    use grey::static qw[ concurrency::actor ];

    my $props = Actor::Props->new(
        class      => 'MyActor',
        supervisor => Actor::Supervisors::Restart->new
    );

=head1 DESCRIPTION

C<Actor::Supervisors::Restart> triggers a full restart of the actor.
Children are stopped, state is reset, and the actor receives a fresh
C<Started> signal. The failed message is re-delivered after restart.

=head1 BEHAVIOR

When C<supervise()> is called:

1. Calls C<< $context->restart >> to initiate restart sequence
2. Returns C<HALT> to stop message processing
3. Children are stopped and waited for
4. Actor is re-created from Props
5. C<Started> signal is sent
6. Failed message is re-delivered

=head1 USE CASES

Use Restart when:

=over 4

=item * The actor may be in a corrupted state

=item * Failures can be resolved by resetting actor state

=item * You want Erlang-style "let it crash" resilience

=back

=head1 SEE ALSO

L<Actor::Supervisors::Supervisor>, L<Actor::Supervisors::Stop>,
L<Actor::Supervisors::Resume>, L<Actor::Supervisors::Retry>

=cut

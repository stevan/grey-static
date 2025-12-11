use v5.42;
use experimental qw[ class ];

use Actor::Supervisors::Supervisor;

class Actor::Supervisors::Retry :isa(Actor::Supervisors::Supervisor) {
    method supervise ($context, $e) {
        return $self->RETRY;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Actor::Supervisors::Retry - Re-deliver the failed message

=head1 SYNOPSIS

    use grey::static qw[ concurrency::actor ];

    my $props = Actor::Props->new(
        class      => 'MyActor',
        supervisor => Actor::Supervisors::Retry->new
    );

=head1 DESCRIPTION

C<Actor::Supervisors::Retry> re-delivers the message that caused an error.
The same message will be processed again.

B<Warning:> This can cause infinite loops if the message always fails!

=head1 BEHAVIOR

When C<supervise()> is called:

1. Returns C<RETRY> to re-deliver the failed message
2. Message is placed back at the front of the queue
3. Actor processes the same message again

=head1 USE CASES

Use Retry when:

=over 4

=item * Failures are transient (network hiccups, temporary resource unavailability)

=item * Processing is idempotent

=item * You have a bounded retry count (implement in message handler)

=back

B<Avoid> using Retry for:

=over 4

=item * Logic errors that will always fail

=item * Validation failures

=back

=head1 SEE ALSO

L<Actor::Supervisors::Supervisor>, L<Actor::Supervisors::Stop>,
L<Actor::Supervisors::Resume>, L<Actor::Supervisors::Restart>

=cut

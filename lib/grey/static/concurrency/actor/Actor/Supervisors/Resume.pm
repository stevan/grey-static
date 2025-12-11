use v5.42;
use experimental qw[ class ];

use Actor::Supervisors::Supervisor;

class Actor::Supervisors::Resume :isa(Actor::Supervisors::Supervisor) {
    method supervise ($context, $e) {
        return $self->RESUME;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Actor::Supervisors::Resume - Skip the failed message and continue

=head1 SYNOPSIS

    use grey::static qw[ concurrency::actor ];

    my $props = Actor::Props->new(
        class      => 'MyActor',
        supervisor => Actor::Supervisors::Resume->new
    );

=head1 DESCRIPTION

C<Actor::Supervisors::Resume> skips the message that caused an error and
continues processing the next message. The failed message is lost.

=head1 BEHAVIOR

When C<supervise()> is called:

1. Returns C<RESUME> to skip the failed message
2. Actor continues processing remaining messages

=head1 USE CASES

Use Resume when:

=over 4

=item * Individual message failures are acceptable

=item * Messages are independent and later messages can succeed even if earlier ones fail

=item * You have separate error handling/logging

=back

=head1 SEE ALSO

L<Actor::Supervisors::Supervisor>, L<Actor::Supervisors::Stop>,
L<Actor::Supervisors::Retry>, L<Actor::Supervisors::Restart>

=cut

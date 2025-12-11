use v5.42;
use experimental qw[ class ];

class Actor::Supervisors::Supervisor {
    use constant RESUME => 1;
    use constant RETRY  => 2;
    use constant HALT   => 3;

    method supervise ($context, $e) {
        # Base implementation - subclasses override this
        warn "Supervisor got error: $e\n";
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Actor::Supervisors::Supervisor - Base class for actor supervisors

=head1 DESCRIPTION

C<Actor::Supervisors::Supervisor> is the base class for all supervisor strategies.
Supervisors determine how to handle errors in actor message handlers.

=head1 CONSTANTS

=over 4

=item C<RESUME>

Skip the failed message and continue processing.

=item C<RETRY>

Re-deliver the failed message.

=item C<HALT>

Stop processing (actor may stop or restart depending on supervisor).

=back

=head1 METHODS

=head2 supervise($context, $error)

Called when a message handler throws an exception. Must return one of
C<RESUME>, C<RETRY>, or C<HALT>.

=head1 SEE ALSO

L<Actor::Supervisors::Stop>, L<Actor::Supervisors::Resume>,
L<Actor::Supervisors::Retry>, L<Actor::Supervisors::Restart>

=cut

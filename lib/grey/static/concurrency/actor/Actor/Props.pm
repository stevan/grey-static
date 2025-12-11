use v5.42;
use experimental qw[ class ];

use Actor::Supervisors::Stop;

class Actor::Props {
    use overload '""' => \&to_string;

    field $class      :param;
    field $args       :param = {};
    field $alias      :param = undef;
    field $supervisor :param = undef;

    method class { $class }
    method alias { $alias }
    method args  { $args  }

    method with_supervisor ($s) { $supervisor = $s; $self }
    method supervisor           { $supervisor //= Actor::Supervisors::Stop->new }

    method new_actor {
        $class->new( %$args );
    }

    method to_string { "Props[$class]" }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Actor::Props - Actor configuration and factory

=head1 SYNOPSIS

    use grey::static qw[ concurrency::actor ];

    # Basic Props
    my $props = Actor::Props->new( class => 'MyActor' );

    # With constructor args
    my $props = Actor::Props->new(
        class => 'Counter',
        args  => { initial_count => 10 }
    );

    # With an alias for lookup
    my $props = Actor::Props->new(
        class => 'Logger',
        alias => '//usr/logger'
    );

    # With a custom supervisor
    my $props = Actor::Props->new(
        class      => 'Worker',
        supervisor => Actor::Supervisors::Restart->new
    );

    # Fluent supervisor configuration
    my $props = Actor::Props->new( class => 'Worker' )
        ->with_supervisor(Actor::Supervisors::Retry->new);

    # Spawn from Props
    my $ref = $context->spawn($props);

=head1 DESCRIPTION

C<Actor::Props> is the configuration object used to create actors. It specifies
the actor class, constructor arguments, optional alias, and supervision strategy.

Props are immutable recipes - you can reuse the same Props to spawn multiple
identical actors.

=head1 CONSTRUCTOR

=head2 new(%options)

    my $props = Actor::Props->new(
        class      => 'MyActor',       # required
        args       => { ... },          # optional, passed to actor constructor
        alias      => '//usr/name',     # optional, for lookup
        supervisor => $supervisor_obj,  # optional, default is Stop
    );

=head1 METHODS

=head2 class

    my $class_name = $props->class;

Returns the actor class name.

=head2 alias

    my $alias = $props->alias;

Returns the alias, or C<undef> if none set.

=head2 args

    my $args = $props->args;

Returns the constructor arguments hash reference.

=head2 supervisor

    my $supervisor = $props->supervisor;

Returns the supervisor strategy. Defaults to L<Actor::Supervisors::Stop>.

=head2 with_supervisor($supervisor)

    $props->with_supervisor(Actor::Supervisors::Restart->new);

Sets the supervisor and returns C<$self> for chaining.

=head2 new_actor

    my $actor = $props->new_actor;

Creates a new actor instance. Called internally by the Mailbox.

=head1 SUPERVISION STRATEGIES

Four built-in supervisors are available:

=over 4

=item L<Actor::Supervisors::Stop> (default)

Stops the actor when a message handler throws.

=item L<Actor::Supervisors::Resume>

Skips the failed message and continues processing.

=item L<Actor::Supervisors::Retry>

Re-delivers the failed message (careful of infinite loops!).

=item L<Actor::Supervisors::Restart>

Restarts the actor and re-delivers the message.

=back

=head1 ALIASES

Aliases provide named lookup for actors. The alias namespace is flat and
global to the System. Convention uses path-like strings:

    //usr/workers/pool
    //sys/metrics

Aliases are registered when the actor is spawned and unregistered when it stops.

=head1 STRINGIFICATION

Props stringify to a readable format:

    Props[MyActor]

=head1 SEE ALSO

L<Actor>, L<Actor::Context>, L<Actor::Supervisors::Supervisor>

=cut

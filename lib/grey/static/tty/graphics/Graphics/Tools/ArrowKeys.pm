
use v5.42;
use experimental qw[ class builtin ];
use builtin qw[ load_module ];

class Graphics::Tools::ArrowKeys {
    use Carp qw[ confess ];
    use Term::ReadKey qw[ ReadMode ReadKey ];

    # ANSI arrow key escape sequences
    my $UP_ARROW    = "\e[A";
    my $DOWN_ARROW  = "\e[B";
    my $RIGHT_ARROW = "\e[C";
    my $LEFT_ARROW  = "\e[D";
    my $ESCAPE      = "\e";

    field $fh :param = \*STDIN;

    # Consumers for each direction
    # Each consumer receives the key string (e.g., "\e[A")
    field $on_up    :param = undef;
    field $on_down  :param = undef;
    field $on_left  :param = undef;
    field $on_right :param = undef;

    # Optional: single consumer that receives all keys
    # Receives a hashref: { key => "\e[A", direction => 'up' }
    field $on_key :param = undef;

    ADJUST {
        # Validate that at least one handler is provided
        unless (defined $on_up || defined $on_down || defined $on_left ||
                defined $on_right || defined $on_key) {
            confess 'ArrowKeys requires at least one handler (on_up, on_down, on_left, on_right, or on_key)';
        }
    }

    method turn_echo_off { ReadMode('cbreak', $fh); return $self }
    method turn_echo_on  { ReadMode('restore', $fh); return $self }

    method capture_keypress {
        my $key = ReadKey(-1, $fh);
        return unless defined $key;

        # Arrow keys are escape sequences: ESC [ A/B/C/D
        if ($key eq $ESCAPE) {
            my $bracket = ReadKey(-1, $fh);
            return unless defined $bracket && $bracket eq '[';

            my $code = ReadKey(-1, $fh);
            return unless defined $code;

            $key = $ESCAPE . $bracket . $code;
        }

        # Dispatch to appropriate handlers
        if ($key eq $UP_ARROW) {
            $on_up->accept($key) if defined $on_up;
            $on_key->accept({ key => $key, direction => 'up' }) if defined $on_key;
            return 'up';
        }
        elsif ($key eq $DOWN_ARROW) {
            $on_down->accept($key) if defined $on_down;
            $on_key->accept({ key => $key, direction => 'down' }) if defined $on_key;
            return 'down';
        }
        elsif ($key eq $LEFT_ARROW) {
            $on_left->accept($key) if defined $on_left;
            $on_key->accept({ key => $key, direction => 'left' }) if defined $on_key;
            return 'left';
        }
        elsif ($key eq $RIGHT_ARROW) {
            $on_right->accept($key) if defined $on_right;
            $on_key->accept({ key => $key, direction => 'right' }) if defined $on_key;
            return 'right';
        }

        # Return undef for non-arrow keys
        return;
    }

    method poll {
        # Convenience method to poll for keypresses in a loop
        # Returns true if a key was captured, false otherwise
        my $result = $self->capture_keypress;
        return defined $result;
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Graphics::Tools::ArrowKeys - Capture arrow key input with functional callbacks

=head1 SYNOPSIS

    use grey::static qw[ tty::graphics functional ];

    # Create consumers for each direction
    my $up_handler = Consumer->new(f => sub ($key) {
        say "Up arrow pressed: $key";
    });

    my $keys = Graphics::Tools::ArrowKeys->new(
        on_up => $up_handler,
    );

    # Or use a single handler for all directions
    my $all_keys = Graphics::Tools::ArrowKeys->new(
        on_key => Consumer->new(f => sub ($event) {
            say "Key: $event->{direction}";
        })
    );

    # Enable raw input mode
    $keys->turn_echo_off;

    # Poll for keypresses (non-blocking)
    while (1) {
        $keys->capture_keypress;
        # ... do other work
    }

    # Restore normal input mode
    $keys->turn_echo_on;

=head1 DESCRIPTION

C<Graphics::Tools::ArrowKeys> captures arrow key input from the terminal using
Term::ReadKey and dispatches events to functional Consumer objects. This enables
reactive keyboard handling in terminal applications.

The class provides two callback styles:

=over 4

=item * Direction-specific consumers (C<on_up>, C<on_down>, C<on_left>, C<on_right>)

=item * Unified consumer (C<on_key>) that receives all arrow key events

=back

All callbacks use the Consumer pattern from grey::static's functional feature,
enabling functional composition and integration with other reactive features.

=head1 CONSTRUCTOR

=head2 new

    my $keys = Graphics::Tools::ArrowKeys->new(
        fh       => \*STDIN,        # Optional: filehandle (default: STDIN)
        on_up    => $up_consumer,   # Optional: Consumer for up arrow
        on_down  => $down_consumer, # Optional: Consumer for down arrow
        on_left  => $left_consumer, # Optional: Consumer for left arrow
        on_right => $right_consumer,# Optional: Consumer for right arrow
        on_key   => $all_consumer,  # Optional: Consumer for all keys
    );

Creates a new arrow key handler. At least one callback consumer must be provided.

=head3 Parameters

=over 4

=item * C<fh> - Filehandle to read from (default: STDIN)

=item * C<on_up> - Consumer called when up arrow is pressed (receives key string)

=item * C<on_down> - Consumer called when down arrow is pressed

=item * C<on_left> - Consumer called when left arrow is pressed

=item * C<on_right> - Consumer called when right arrow is pressed

=item * C<on_key> - Consumer called for any arrow key (receives hashref with 'key' and 'direction')

=back

=head1 METHODS

=head2 turn_echo_off

    $keys->turn_echo_off;

Enables raw input mode (cbreak mode) where keypresses are immediately available
without requiring Enter. Returns C<$self> for chaining.

=head2 turn_echo_on

    $keys->turn_echo_on;

Restores normal input mode. Returns C<$self> for chaining.

B<Important:> Always call this before your program exits to restore terminal state.

=head2 capture_keypress

    my $direction = $keys->capture_keypress;

Non-blocking capture of a single keypress. Reads from the filehandle and:

=over 4

=item * Detects arrow key escape sequences

=item * Calls appropriate Consumer callbacks

=item * Returns the direction string ('up', 'down', 'left', 'right') or undef

=back

This method is non-blocking - it returns immediately if no key is available.

=head2 poll

    my $got_key = $keys->poll;

Convenience method that calls C<capture_keypress> and returns true if a key
was captured, false otherwise.

=head1 EXAMPLES

=head2 Basic Arrow Key Handling

    use grey::static qw[ tty::graphics functional ];

    my $position = { x => 0, y => 0 };

    my $keys = Graphics::Tools::ArrowKeys->new(
        on_up    => Consumer->new(f => sub { $position->{y}-- }),
        on_down  => Consumer->new(f => sub { $position->{y}++ }),
        on_left  => Consumer->new(f => sub { $position->{x}-- }),
        on_right => Consumer->new(f => sub { $position->{x}++ }),
    );

    $keys->turn_echo_off;

    while (1) {
        if ($keys->poll) {
            say "Position: $position->{x}, $position->{y}";
        }
        # ... render graphics, etc.
    }

=head2 Unified Key Handler

    use grey::static qw[ tty::graphics functional ];

    my $handler = Consumer->new(f => sub ($event) {
        say "Arrow key: $event->{direction}";
        say "Raw key: $event->{key}";
    });

    my $keys = Graphics::Tools::ArrowKeys->new(on_key => $handler);

    $keys->turn_echo_off;
    while (1) {
        $keys->capture_keypress;
    }

=head2 Integration with Sprite Movement

    use grey::static qw[ tty::graphics datatypes::numeric functional ];

    my $sprite = Graphics::Sprite->new(
        top => 10,
        left => 20,
        bitmap => [ ... ]
    );

    my $keys = Graphics::Tools::ArrowKeys->new(
        on_up    => Consumer->new(f => sub { $sprite->{top}-- }),
        on_down  => Consumer->new(f => sub { $sprite->{top}++ }),
        on_left  => Consumer->new(f => sub { $sprite->{left}-- }),
        on_right => Consumer->new(f => sub { $sprite->{left}++ }),
    );

    my $shader = Graphics::Shader->new(
        height => 60,
        width => 120,
        shader => sub ($p, $t) {
            my $color = $sprite->draw_at($p);
            return $color // Graphics::Color->new(r => 0, g => 0, b => 0);
        }
    );

    $keys->turn_echo_off;
    $shader->clear_screen;

    while (1) {
        $keys->capture_keypress;
        $shader->draw(time);
        select(undef, undef, undef, 0.016); # ~60 FPS
    }

=head1 TERMINAL STATE

Always restore terminal state before exiting:

    my $keys = Graphics::Tools::ArrowKeys->new( ... );
    $keys->turn_echo_off;

    eval {
        # ... your application logic
    };

    $keys->turn_echo_on;
    die $@ if $@;

Or use a cleanup handler:

    use Scope::Guard;

    my $keys = Graphics::Tools::ArrowKeys->new( ... );
    $keys->turn_echo_off;
    my $guard = Scope::Guard->new(sub { $keys->turn_echo_on });

    # ... application logic
    # Terminal restored automatically on scope exit

=head1 SEE ALSO

L<Graphics>, L<Graphics::Shader>, L<Graphics::Sprite>, L<Consumer>

L<Term::ReadKey> - Used for raw terminal input

=head1 NOTES

=over 4

=item * This class uses non-blocking I/O via Term::ReadKey

=item * Arrow keys are detected via ANSI escape sequences (ESC [ A/B/C/D)

=item * Always restore terminal state with C<turn_echo_on> before exiting

=item * Consumers must be from grey::static's functional feature

=back

=cut

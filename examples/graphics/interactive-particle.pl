#!/usr/bin/env perl

use v5.42;
use utf8;

use Time::HiRes ();

use grey::static qw[
    stream
    time::stream
    tty::graphics
    functional
];

# ============================================================================
# Interactive Particle - Event Loop Example
# ============================================================================
# Demonstrates:
# - ArrowKeys for input with Consumer callbacks
# - Time::of_delta() for frame timing
# - Shader for rendering
# - Stream-based game loop architecture
# ============================================================================

# Game state
my $state = {
    # Particle position
    x => 60,
    y => 30,

    # Particle velocity
    vx => 0,
    vy => 0,

    # Acceleration from input
    ax => 0,
    ay => 0,
};

# Constants
my $ACCELERATION = 100;  # Pixels per second squared
my $FRICTION = 0.95;     # Velocity dampening
my $MAX_SPEED = 50;      # Maximum velocity

# Input handlers using Consumer
my $keys = ArrowKeys(
    on_up    => Consumer->new(f => sub {
        $state->{ay} = -$ACCELERATION;
    }),
    on_down  => Consumer->new(f => sub {
        $state->{ay} = $ACCELERATION;
    }),
    on_left  => Consumer->new(f => sub {
        $state->{ax} = -$ACCELERATION;
    }),
    on_right => Consumer->new(f => sub {
        $state->{ax} = $ACCELERATION;
    }),
);

# Shader for rendering
my $shader = Shader(
    height => 60,
    width => 120,
    shader => sub ($p, $t) {
        my ($px, $py) = $p->xy;

        # Distance from particle
        my $d = distance($px - $state->{x}, $py - $state->{y});

        # Particle core (bright red)
        if ($d < 2) {
            return Color(r => 1, g => 0, b => 0);
        }

        # Particle glow (fades with distance)
        if ($d < 8) {
            my $intensity = clamp((8 - $d) / 6, 0, 1);
            return Color(
                r => $intensity * 0.8,
                g => $intensity * 0.2,
                b => $intensity * 0.1
            );
        }

        # Velocity indicator (trail)
        my $trail_x = $state->{x} - $state->{vx} * 0.5;
        my $trail_y = $state->{y} - $state->{vy} * 0.5;
        my $trail_d = distance($px - $trail_x, $py - $trail_y);

        if ($trail_d < 3) {
            return Color(r => 0.3, g => 0.3, b => 0.5);
        }

        # Background grid
        my $grid = (int($px / 10) + int($py / 10)) % 2;
        return Color(r => 0, g => 0, b => $grid * 0.05);
    }
);

# Physics update
sub update_physics ($dt) {
    # Apply acceleration
    $state->{vx} += $state->{ax} * $dt;
    $state->{vy} += $state->{ay} * $dt;

    # Apply friction
    $state->{vx} *= $FRICTION;
    $state->{vy} *= $FRICTION;

    # Clamp velocity
    my $speed = sqrt($state->{vx}**2 + $state->{vy}**2);
    if ($speed > $MAX_SPEED) {
        my $scale = $MAX_SPEED / $speed;
        $state->{vx} *= $scale;
        $state->{vy} *= $scale;
    }

    # Update position
    $state->{x} += $state->{vx} * $dt;
    $state->{y} += $state->{vy} * $dt;

    # Bounce off walls
    if ($state->{x} < 0) {
        $state->{x} = 0;
        $state->{vx} = -$state->{vx} * 0.8;
    }
    if ($state->{x} > 120) {
        $state->{x} = 120;
        $state->{vx} = -$state->{vx} * 0.8;
    }
    if ($state->{y} < 0) {
        $state->{y} = 0;
        $state->{vy} = -$state->{vy} * 0.8;
    }
    if ($state->{y} > 60) {
        $state->{y} = 60;
        $state->{vy} = -$state->{vy} * 0.8;
    }

    # Reset acceleration (input must be continuous)
    $state->{ax} = 0;
    $state->{ay} = 0;
}

# Initialize graphics
$keys->turn_echo_off;
$shader->clear_screen;
$shader->hide_cursor;

say "Interactive Particle Demo";
say "Use arrow keys to move the particle";
say "Press Ctrl+C to exit";
say "";

# Main event loop using time::stream
my $frame_count = 0;
my $start_time = Time::HiRes::time();

Time->of_delta()
    ->peek(sub ($dt) {
        # 1. Process input (non-blocking poll)
        $keys->capture_keypress;
    })
    ->peek(sub ($dt) {
        # 2. Update physics
        update_physics($dt);
    })
    ->peek(sub ($dt) {
        # 3. Render
        $shader->draw(Time::HiRes::time());
        $frame_count++;
    })
    ->sleep_for(0.016)  # Target ~60 FPS (16ms per frame)
    ->take(3600)        # Run for 60 seconds at 60 FPS
    ->foreach(Consumer->new(f => sub ($dt) {
        # Optional: Show FPS every 60 frames
        if ($frame_count % 60 == 0) {
            my $elapsed = Time::HiRes::time() - $start_time;
            my $fps = $frame_count / $elapsed;
            # Could display FPS in corner
        }
    }));

# Cleanup
$shader->show_cursor;
$keys->turn_echo_on;

say "\nDemo completed!";
say "Total frames: $frame_count";
my $total_time = Time::HiRes::time() - $start_time;
my $avg_fps = $frame_count / $total_time;
say sprintf("Average FPS: %.2f", $avg_fps);

__END__

=head1 NAME

interactive-particle.pl - Interactive particle demo using event loop pattern

=head1 DESCRIPTION

Demonstrates the recommended event loop pattern for interactive terminal graphics:

=over 4

=item 1. Use C<ArrowKeys> with Consumer callbacks for input

=item 2. Use C<Time::of_delta()> for frame timing

=item 3. Use C<peek()> operations to structure the game loop

=item 4. Use C<sleep_for()> to control frame rate

=back

The pattern creates a clean, composable event loop that separates concerns:

  Input → Physics → Rendering

=head1 ARCHITECTURE

  Time::of_delta()              # Stream of delta times
    ->peek(process_input)       # Poll keyboard
    ->peek(update_physics)      # Update state
    ->peek(render)              # Draw to screen
    ->sleep_for(0.016)          # 60 FPS
    ->for_each(...)             # Execute loop

=head1 FEATURES

=over 4

=item * Smooth physics with delta time integration

=item * Friction and velocity clamping

=item * Wall bouncing with energy loss

=item * Visual particle glow effect

=item * Velocity trail indicator

=item * Background grid

=back

=head1 CONTROLS

=over 4

=item * Arrow Keys - Accelerate particle

=item * Ctrl+C - Exit

=back

=head1 SEE ALSO

L<docs/tty-graphics-event-loop-patterns.md> - Complete pattern documentation

=cut

#!/usr/bin/env perl

use v5.42;
use utf8;
use experimental qw[ class ];

use open ':std', ':encoding(UTF-8)';

use FindBin;
use lib "$FindBin::Bin/../../lib";

use grey::static qw[
    concurrency::util
    concurrency::actor
    tty::ansi
    tty::graphics
];
use Time::HiRes qw[ time ];

# =============================================================================
# Messages
# =============================================================================

class Tick :isa(Actor::Message) {}

class QueryState :isa(Actor::Message) {
    field $generation :param :reader;
}

class ReportState :isa(Actor::Message) {
    field $x :param :reader;
    field $y :param :reader;
    field $alive :param :reader;
    field $age :param :reader;
    field $generation :param :reader;
}

class ComputeNextState :isa(Actor::Message) {
    field $live_neighbors :param :reader;
}

class SetNeighbors :isa(Actor::Message) {
    field $neighbors :param :reader;
}

# =============================================================================
# Cell Actor - each cell is an independent actor
# =============================================================================

class Cell :isa(Actor) {
    field $x :param;
    field $y :param;
    field $alive :param = 0;
    field $age = 0;

    field @neighbors;

    method signal ($context, $signal) {
        # Cell is ready when started
    }

    method receive ($context, $message) {
        if ($message isa SetNeighbors) {
            @neighbors = $message->neighbors->@*;
            return true;
        }
        elsif ($message isa QueryState) {
            $message->reply_to->send(ReportState->new(
                x          => $x,
                y          => $y,
                alive      => $alive,
                age        => $age,
                generation => $message->generation,
            ));
            return true;
        }
        elsif ($message isa ComputeNextState) {
            my $live = $message->live_neighbors;

            # Conway's rules
            my $was_alive = $alive;

            if ($alive) {
                $alive = ($live == 2 || $live == 3) ? 1 : 0;
            } else {
                $alive = ($live == 3) ? 1 : 0;
            }

            # Update age
            if ($alive) {
                $age = $was_alive ? $age + 1 : 0;
            } else {
                $age = 0;
            }
            return true;
        }
        return false;
    }
}

# =============================================================================
# World Actor - coordinates the simulation using Shader for rendering
# =============================================================================

class World :isa(Actor) {
    field $width  :param;
    field $height :param;
    field $tick_interval :param = 0.2;
    field $initial_pattern :param = 'glider';

    field @cells;
    field $shader :reader;
    field $generation = 0;
    field $live_count = 0;

    field @pending_reports;
    field $expected_reports;

    # Current grid state for shader rendering
    field @grid;
    field @ages;

    # FPS tracking - using frame count over time window
    field $fps_window_start;
    field $fps_frame_count = 0;
    field $current_fps = 0;

    # Message count tracking - using message count over time window
    field $message_count = 0;
    field $mps_window_start;
    field $mps_msg_count_start = 0;
    field $msgs_per_sec = 0;

    # Age-based colors for shader
    my @AGE_COLORS = (
        [0.0, 1.0, 0.0],    # 0: bright green (newborn)
        [0.2, 1.0, 0.0],    # 1: green-yellow
        [0.4, 1.0, 0.0],    # 2: yellow-green
        [0.6, 1.0, 0.0],    # 3: lime
        [0.8, 1.0, 0.0],    # 4: yellow-lime
        [1.0, 1.0, 0.0],    # 5: yellow
        [1.0, 0.8, 0.0],    # 6: gold
        [1.0, 0.6, 0.0],    # 7: orange
        [1.0, 0.4, 0.0],    # 8: red-orange
        [1.0, 0.2, 0.0],    # 9+: red (ancient)
    );

    method signal ($context, $signal) {
        if ($signal isa Actor::Signals::Started) {
            # Initialize the shader for rendering
            $shader = Graphics::Shader->new(
                height       => $height,
                width        => $width,
                coord_system => Graphics::Shader->TOP_LEFT,
                shader       => sub ($point, $t) {
                    my ($px, $py) = map { int } $point->xy;
                    # px = x = column (0 to width-1)
                    # py = y = row (0 to height-1)
                    return Graphics::Color->new(r => 0.05, g => 0.05, b => 0.1)
                        if $px < 0 || $px >= $width || $py < 0 || $py >= $height;

                    if ($grid[$py][$px]) {
                        my $age = $ages[$py][$px] // 0;
                        my $idx = $age > $#AGE_COLORS ? $#AGE_COLORS : $age;
                        my ($r, $g, $b) = @{$AGE_COLORS[$idx]};
                        return Graphics::Color->new(r => $r, g => $g, b => $b);
                    } else {
                        return Graphics::Color->new(r => 0.05, g => 0.05, b => 0.1);
                    }
                }
            );



            $shader->enable_alt_buffer;
            $shader->hide_cursor;
            $shader->clear_screen;

            # Initialize grid
            @grid = map { [(0) x $width] } 1 .. $height;
            @ages = map { [(0) x $width] } 1 .. $height;

            # Spawn all cells
            for my $y (0 .. $height - 1) {
                for my $x (0 .. $width - 1) {
                    my $cell = $context->spawn(Actor::Props->new(
                        class => 'Cell',
                        args  => { x => $x, y => $y, alive => 0 },
                    ));
                    $cells[$y][$x] = $cell;
                }
            }

            # Set up neighbors for each cell (toroidal wrap)
            for my $y (0 .. $height - 1) {
                for my $x (0 .. $width - 1) {
                    my @neighbors;
                    for my $dy (-1, 0, 1) {
                        for my $dx (-1, 0, 1) {
                            next if $dx == 0 && $dy == 0;
                            my $nx = ($x + $dx) % $width;
                            my $ny = ($y + $dy) % $height;
                            push @neighbors => $cells[$ny][$nx];
                        }
                    }
                    $cells[$y][$x]->send(SetNeighbors->new(neighbors => \@neighbors));
                }
            }

            # Set initial pattern
            $self->set_pattern($context, $initial_pattern);

            # Start the tick loop
            $expected_reports = $width * $height;
            $context->schedule(after => 0.1, callback => sub {
                $context->self->send(Tick->new);
            });
        }
        elsif ($signal isa Actor::Signals::Stopping) {
            $shader->show_cursor;
            $shader->disable_alt_buffer;
        }
    }

    method set_pattern ($context, $pattern) {
        my @coords;

        if ($pattern eq 'glider') {
            my $ox = int($width / 4);
            my $oy = int($height / 4);
            @coords = (
                [$ox+1, $oy], [$ox+2, $oy+1], [$ox, $oy+2], [$ox+1, $oy+2], [$ox+2, $oy+2]
            );
        }
        elsif ($pattern eq 'blinker') {
            my $ox = int($width / 2);
            my $oy = int($height / 2);
            @coords = ([$ox, $oy-1], [$ox, $oy], [$ox, $oy+1]);
        }
        elsif ($pattern eq 'pulsar') {
            my $ox = int($width / 2) - 6;
            my $oy = int($height / 2) - 6;
            # Pulsar pattern (period 3 oscillator)
            my @rel = (
                [2,0],[3,0],[4,0],[8,0],[9,0],[10,0],
                [0,2],[5,2],[7,2],[12,2],
                [0,3],[5,3],[7,3],[12,3],
                [0,4],[5,4],[7,4],[12,4],
                [2,5],[3,5],[4,5],[8,5],[9,5],[10,5],
                [2,7],[3,7],[4,7],[8,7],[9,7],[10,7],
                [0,8],[5,8],[7,8],[12,8],
                [0,9],[5,9],[7,9],[12,9],
                [0,10],[5,10],[7,10],[12,10],
                [2,12],[3,12],[4,12],[8,12],[9,12],[10,12],
            );
            @coords = map { [$ox + $_->[0], $oy + $_->[1]] } @rel;
        }
        elsif ($pattern eq 'spaceship') {
            # Lightweight spaceship (LWSS)
            my $ox = int($width / 4);
            my $oy = int($height / 2);
            @coords = (
                [$ox+1, $oy], [$ox+4, $oy],
                [$ox, $oy+1],
                [$ox, $oy+2], [$ox+4, $oy+2],
                [$ox, $oy+3], [$ox+1, $oy+3], [$ox+2, $oy+3], [$ox+3, $oy+3],
            );
        }
        elsif ($pattern eq 'r_pentomino') {
            # R-pentomino - only 5 cells but runs for 1103 generations
            my $ox = int($width / 2);
            my $oy = int($height / 2);
            @coords = (
                [$ox+1, $oy], [$ox+2, $oy],
                [$ox, $oy+1], [$ox+1, $oy+1],
                [$ox+1, $oy+2],
            );
        }
        elsif ($pattern eq 'acorn') {
            # Acorn - small pattern that takes 5206 generations to stabilize
            my $ox = int($width / 2) - 3;
            my $oy = int($height / 2);
            @coords = (
                [$ox+1, $oy], [$ox+3, $oy+1],
                [$ox, $oy+2], [$ox+1, $oy+2], [$ox+4, $oy+2], [$ox+5, $oy+2], [$ox+6, $oy+2],
            );
        }
        elsif ($pattern eq 'diehard') {
            # Diehard - disappears after 130 generations
            my $ox = int($width / 2) - 4;
            my $oy = int($height / 2);
            @coords = (
                [$ox+6, $oy],
                [$ox, $oy+1], [$ox+1, $oy+1],
                [$ox+1, $oy+2], [$ox+5, $oy+2], [$ox+6, $oy+2], [$ox+7, $oy+2],
            );
        }
        elsif ($pattern eq 'rabbits') {
            # Rabbits - exponential growth pattern
            my $ox = int($width / 2) - 3;
            my $oy = int($height / 2) - 1;
            @coords = (
                [$ox, $oy], [$ox+4, $oy], [$ox+5, $oy], [$ox+6, $oy],
                [$ox, $oy+1], [$ox+1, $oy+1], [$ox+2, $oy+1], [$ox+5, $oy+1],
                [$ox+1, $oy+2],
            );
        }
        elsif ($pattern eq 'lidka') {
            # Lidka - runs for 29,053 generations! (needs big grid ~150x150)
            my $ox = int($width / 2) - 6;
            my $oy = int($height / 2) - 2;
            @coords = (
                [$ox+1, $oy],
                [$ox+3, $oy+1],
                [$ox, $oy+2], [$ox+1, $oy+2],
                [$ox+3, $oy+2], [$ox+4, $oy+2], [$ox+5, $oy+2],
                [$ox+10, $oy+2], [$ox+11, $oy+2], [$ox+12, $oy+2],
                [$ox+10, $oy+3],
                [$ox+11, $oy+4],
            );
        }
        elsif ($pattern eq 'infinite1') {
            # Infinite growth pattern 1 - grows forever
            my $ox = int($width / 2) - 4;
            my $oy = int($height / 2) - 2;
            @coords = (
                [$ox+6, $oy], [$ox+4, $oy+1], [$ox+6, $oy+1], [$ox+7, $oy+1],
                [$ox+4, $oy+2], [$ox+6, $oy+2],
                [$ox+4, $oy+3],
                [$ox+2, $oy+4],
                [$ox, $oy+5], [$ox+2, $oy+5],
            );
        }
        elsif ($pattern eq 'infinite2') {
            # 5x5 infinite growth pattern
            my $ox = int($width / 2) - 2;
            my $oy = int($height / 2) - 2;
            @coords = (
                [$ox, $oy], [$ox+1, $oy], [$ox+2, $oy], [$ox+4, $oy],
                [$ox, $oy+1],
                [$ox+3, $oy+2], [$ox+4, $oy+2],
                [$ox+1, $oy+3], [$ox+2, $oy+3], [$ox+4, $oy+3],
                [$ox, $oy+4], [$ox+2, $oy+4], [$ox+4, $oy+4],
            );
        }
        elsif ($pattern eq 'noah') {
            # Noah's Ark - a large, chaotic methuselah
            my $ox = int($width / 2) - 8;
            my $oy = int($height / 2) - 3;
            @coords = (
                [$ox, $oy], [$ox+1, $oy], [$ox+8, $oy], [$ox+9, $oy], [$ox+10, $oy], [$ox+16, $oy],
                [$ox, $oy+1], [$ox+8, $oy+1], [$ox+10, $oy+1], [$ox+14, $oy+1], [$ox+16, $oy+1],
                [$ox+1, $oy+2], [$ox+9, $oy+2], [$ox+14, $oy+2], [$ox+15, $oy+2], [$ox+16, $oy+2],
                [$ox+5, $oy+4], [$ox+6, $oy+4],
                [$ox+5, $oy+5],
                [$ox+6, $oy+6],
            );
        }
        elsif ($pattern eq 'blom') {
            # Blom - chaotic pattern that runs for thousands of generations
            my $ox = int($width / 2) - 7;
            my $oy = int($height / 2) - 2;
            @coords = (
                [$ox, $oy], [$ox+2, $oy],
                [$ox+1, $oy+1],
                [$ox+4, $oy+2],
                [$ox+5, $oy+3], [$ox+6, $oy+3], [$ox+7, $oy+3],
                [$ox+8, $oy+3], [$ox+9, $oy+3], [$ox+10, $oy+3], [$ox+11, $oy+3],
                [$ox+12, $oy+3], [$ox+13, $oy+3], [$ox+14, $oy+3],
            );
        }
        elsif ($pattern eq 'glider_gun') {
            my $ox = 2;
            my $oy = 2;
            @coords = (
                [$ox+0, $oy+4], [$ox+0, $oy+5], [$ox+1, $oy+4], [$ox+1, $oy+5],
                [$ox+10, $oy+4], [$ox+10, $oy+5], [$ox+10, $oy+6],
                [$ox+11, $oy+3], [$ox+11, $oy+7],
                [$ox+12, $oy+2], [$ox+12, $oy+8],
                [$ox+13, $oy+2], [$ox+13, $oy+8],
                [$ox+14, $oy+5],
                [$ox+15, $oy+3], [$ox+15, $oy+7],
                [$ox+16, $oy+4], [$ox+16, $oy+5], [$ox+16, $oy+6],
                [$ox+17, $oy+5],
                [$ox+20, $oy+2], [$ox+20, $oy+3], [$ox+20, $oy+4],
                [$ox+21, $oy+2], [$ox+21, $oy+3], [$ox+21, $oy+4],
                [$ox+22, $oy+1], [$ox+22, $oy+5],
                [$ox+24, $oy+0], [$ox+24, $oy+1], [$ox+24, $oy+5], [$ox+24, $oy+6],
                [$ox+34, $oy+2], [$ox+34, $oy+3], [$ox+35, $oy+2], [$ox+35, $oy+3],
            );
        }
        elsif ($pattern eq 'random') {
            for my $y (0 .. $height - 1) {
                for my $x (0 .. $width - 1) {
                    push @coords => [$x, $y] if rand() < 0.3;
                }
            }
        }

        # Send initial alive state
        for my $coord (@coords) {
            my ($x, $y) = @$coord;
            next if $x < 0 || $x >= $width || $y < 0 || $y >= $height;
            $cells[$y][$x]->send(ComputeNextState->new(live_neighbors => 3));
        }
    }

    method tick :Receive(Tick) ($context, $message) {
        $message_count++;  # Count incoming Tick message

        # Query all cells for their current state
        @pending_reports = ();

        for my $y (0 .. $height - 1) {
            for my $x (0 .. $width - 1) {
                $cells[$y][$x]->send(QueryState->new(
                    reply_to   => $context->self,
                    generation => $generation,
                ));
                $message_count++;  # Count outgoing QueryState message
            }
        }
    }

    method report_state :Receive(ReportState) ($context, $message) {
        push @pending_reports => $message;
        $message_count++;  # Count incoming ReportState message

        if (@pending_reports == $expected_reports) {
            # Calculate FPS and MPS using time windows
            my $now = time;
            $fps_frame_count++;

            # Initialize windows on first frame
            $fps_window_start //= $now;
            $mps_window_start //= $now;

            # Calculate FPS over a rolling window (update every 0.5 seconds)
            my $fps_elapsed = $now - $fps_window_start;
            if ($fps_elapsed >= 0.5) {
                $current_fps = $fps_frame_count / $fps_elapsed;
                $fps_window_start = $now;
                $fps_frame_count = 0;
            }

            # Calculate MPS over a rolling window (update every 0.5 seconds)
            my $mps_elapsed = $now - $mps_window_start;
            if ($mps_elapsed >= 0.5) {
                my $msgs_in_window = $message_count - $mps_msg_count_start;
                $msgs_per_sec = $msgs_in_window / $mps_elapsed;
                $mps_window_start = $now;
                $mps_msg_count_start = $message_count;
            }

            # Build grid for rendering
            my %alive_cells;
            $live_count = 0;

            for my $report (@pending_reports) {
                my ($x, $y, $alive, $age) = ($report->x, $report->y, $report->alive, $report->age);
                $grid[$y][$x] = $alive;
                $ages[$y][$x] = $age;
                if ($alive) {
                    $alive_cells{"$x,$y"} = 1;
                    $live_count++;
                }
            }

            # Render using shader
            $shader->draw($generation);

            # render stats ..
            my $actor_count = ($width * $height) + 1;  # cells + world
            $self->display_stats(
                generation   => $generation,
                live_count   => $live_count,
                actor_count  => $actor_count,
                msg_count    => $message_count,
                msgs_per_sec => $msgs_per_sec,
                fps          => $current_fps,
                target_fps   => 1 / $tick_interval,
            );

            # Compute next state for each cell
            for my $y (0 .. $height - 1) {
                for my $x (0 .. $width - 1) {
                    my $live_neighbors = 0;
                    for my $dy (-1, 0, 1) {
                        for my $dx (-1, 0, 1) {
                            next if $dx == 0 && $dy == 0;
                            my $nx = ($x + $dx) % $width;
                            my $ny = ($y + $dy) % $height;
                            $live_neighbors++ if $alive_cells{"$nx,$ny"};
                        }
                    }
                    $cells[$y][$x]->send(ComputeNextState->new(
                        live_neighbors => $live_neighbors
                    ));
                }
            }

            $generation++;
            @pending_reports = ();

            if ($tick_interval < 0.01) {
                # less than 60FPS, don't bother scheduling ...
                $context->self->send(Tick->new);
            } else {
                # Schedule next tick
                $context->schedule(after => $tick_interval, callback => sub {
                    $context->self->send(Tick->new);
                });
            }
        }
    }

    method display_stats (%stats) {
        # Status bar with enhanced metrics
        say "\n",sprintf(
            "Gen: %d | Live: %d | Actors: %d | Msgs: %d (%.0f/s) | FPS: %.1f (target: %.0f)",
            $stats{generation},
            $stats{live_count},
            $stats{actor_count},
            $stats{msg_count},
            $stats{msgs_per_sec},
            $stats{fps},
            $stats{target_fps},
        ),"\n";
    }
}

# =============================================================================
# Main
# =============================================================================

my $width   = $ARGV[0] // 40;
my $height  = $ARGV[1] // 20;
my $pattern = $ARGV[2] // 'glider';
my $speed   = $ARGV[3] // 0.15;

say "Game of Life (Actor + Shader) - ${width}x${height}";
say "Pattern: $pattern | Speed: ${speed}s";
say "";
say "Patterns:";
say "  Simple:     glider, blinker, spaceship";
say "  Oscillator: pulsar";
say "  Methuselah: r_pentomino, acorn, diehard, rabbits, lidka, noah, blom";
say "  Infinite:   infinite1, infinite2, glider_gun";
say "  Random:     random";
say "";
say "Press Ctrl+C to quit";
say "";
sleep 2;

my $system;

$SIG{INT} = sub {
    print ANSI::Screen::disable_alt_buf();
    print ANSI::Screen::show_cursor();
    print ANSI::Color::format_reset();
    print "\n\nShutting down...\n";
    $system->shutdown if $system;
    exit 0;
};

$system = ActorSystem->new->init(sub ($context) {
    $context->spawn(Actor::Props->new(
        class => 'World',
        args  => {
            width           => $width,
            height          => $height,
            tick_interval   => $speed,
            initial_pattern => $pattern,
        },
    ));
});

$system->loop_until_done;

print "\e[?25h\e[0m";
say "\nDone!";

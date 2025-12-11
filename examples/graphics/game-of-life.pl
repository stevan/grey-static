#!/usr/bin/env perl

use v5.42;
use utf8;
use experimental qw[ class ];

use FindBin;
use lib "$FindBin::Bin/../../lib";

use grey::static qw[ datatypes::numeric tty::graphics ];
use Time::HiRes qw[ sleep time ];

# =============================================================================
# Conway's Game of Life
# Using Matrix for state, Shader for rendering
# =============================================================================

my $WIDTH  = 80;
my $HEIGHT = 40;
my $GENERATIONS = 200;
my $DELAY = 0.1;  # seconds between frames

# -----------------------------------------------------------------------------
# Initialize the world with random cells
# -----------------------------------------------------------------------------

sub random_world ($rows, $cols, $density = 0.3) {
    Matrix->construct(
        [$rows, $cols],
        sub ($x, $y) { rand() < $density ? 1 : 0 }
    );
}

# Classic patterns using construct (Tensors are immutable)
sub glider ($rows, $cols) {
    my $ox = 5;  # offset
    my $oy = 5;
    my %alive = map { $_ => 1 } (
        "${ox}:" . ($oy+1),
        ($ox+1) . ":" . ($oy+2),
        ($ox+2) . ":${oy}",
        ($ox+2) . ":" . ($oy+1),
        ($ox+2) . ":" . ($oy+2),
    );
    return Matrix->construct(
        [$rows, $cols],
        sub ($x, $y) { $alive{"${x}:${y}"} ? 1 : 0 }
    );
}

sub r_pentomino ($rows, $cols) {
    my $cx = int($rows / 2);
    my $cy = int($cols / 2);
    my %alive = map { $_ => 1 } (
        ($cx-1) . ":${cy}",
        ($cx-1) . ":" . ($cy+1),
        "${cx}:" . ($cy-1),
        "${cx}:${cy}",
        ($cx+1) . ":${cy}",
    );
    return Matrix->construct(
        [$rows, $cols],
        sub ($x, $y) { $alive{"${x}:${y}"} ? 1 : 0 }
    );
}

# -----------------------------------------------------------------------------
# Game of Life rules
# -----------------------------------------------------------------------------

sub count_neighbors ($world, $x, $y) {
    my $rows = $world->rows;
    my $cols = $world->cols;
    my $count = 0;

    for my $dx (-1, 0, 1) {
        for my $dy (-1, 0, 1) {
            next if $dx == 0 && $dy == 0;

            # Wrap around (toroidal)
            my $nx = ($x + $dx + $rows) % $rows;
            my $ny = ($y + $dy + $cols) % $cols;

            $count += $world->at($nx, $ny);
        }
    }
    return $count;
}

sub next_generation ($world) {
    my $rows = $world->rows;
    my $cols = $world->cols;

    return Matrix->construct(
        [$rows, $cols],
        sub ($x, $y) {
            my $alive = $world->at($x, $y);
            my $neighbors = count_neighbors($world, $x, $y);

            # Conway's rules:
            # 1. Live cell with 2 or 3 neighbors survives
            # 2. Dead cell with exactly 3 neighbors becomes alive
            # 3. All other cells die or stay dead
            if ($alive) {
                return ($neighbors == 2 || $neighbors == 3) ? 1 : 0;
            } else {
                return ($neighbors == 3) ? 1 : 0;
            }
        }
    );
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

# Initialize world
my $world = random_world($HEIGHT, $WIDTH, 0.25);
# Or use a classic pattern:
# my $world = r_pentomino($HEIGHT, $WIDTH);

# Create shader that reads from the world matrix
my $shader = Graphics::Shader->new(
    height => $HEIGHT,
    width  => $WIDTH,
    coord_system => Graphics::Shader->TOP_LEFT,
    shader => sub ($point, $gen) {
        my ($x, $y) = map { int } $point->xy;

        # Bounds check
        return Graphics::Color->new(r => 0, g => 0, b => 0)
            if $x < 0 || $x >= $HEIGHT || $y < 0 || $y >= $WIDTH;

        my $alive = $world->at($x, $y);

        if ($alive) {
            # Living cells - greenish
            return Graphics::Color->new(r => 0.2, g => 0.9, b => 0.3);
        } else {
            # Dead cells - dark
            return Graphics::Color->new(r => 0.05, g => 0.05, b => 0.1);
        }
    }
);

# Setup terminal
$shader->enable_alt_buffer;
$shader->hide_cursor;
$shader->clear_screen;

my $gen = 0;

# Trap Ctrl-C to restore terminal
$SIG{INT} = sub {
    $shader->show_cursor;
    $shader->disable_alt_buffer;
    say "\nInterrupted after generation $gen";
    exit 0;
};
my $start_time = time();

eval {
    for (1 .. $GENERATIONS) {
        $gen = $_;

        # Draw current state
        $shader->draw($gen);

        # Stats line
        my $live_count = 0;
        for my $x (0 .. $HEIGHT-1) {
            for my $y (0 .. $WIDTH-1) {
                $live_count++ if $world->at($x, $y);
            }
        }

        print "\n";
        printf "Generation: %4d | Live cells: %5d | Size: %dx%d\n",
            $gen, $live_count, $WIDTH, $HEIGHT;

        # Evolve
        $world = next_generation($world);

        sleep($DELAY);
    }
};

# Cleanup
$shader->show_cursor;
$shader->disable_alt_buffer;

my $elapsed = time() - $start_time;
say "";
say "Game of Life completed!";
say "  Generations: $gen";
say "  Time: " . sprintf("%.2f", $elapsed) . "s";
say "  FPS: " . sprintf("%.1f", $gen / $elapsed);

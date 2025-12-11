#!/usr/bin/env perl

use v5.42;
use utf8;

# Add lib to path
use FindBin;
use lib "$FindBin::Bin/../../lib";

use grey::static qw[ tty::graphics ];

# Create a simple gradient shader
my $shader = Graphics::Shader->new(
    height => 20,
    width => 40,
    coord_system => Graphics::Shader->CENTERED,
    shader => sub ($p, $t) {
        my ($x, $y) = $p->xy;

        # Create a radial gradient from center
        my $d = distance($x, $y);
        my $intensity = clamp(1 - $d, 0, 1);

        return Graphics::Color->new(
            r => $intensity,
            g => $intensity * 0.5,
            b => $intensity * 0.8,
        );
    }
);

say "Simple Gradient Example - grey::static tty::graphics";
say "=" x 50;
say "";

$shader->draw(0);

say "";
say "Phase 1 Complete! ✓";
say "- Graphics::Point, Graphics::Color, Graphics::Shader working";
say "- All ANSI operations use tty::ansi";
say "- Shader-based rendering functional";

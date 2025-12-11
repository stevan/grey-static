#!perl

use v5.42;
use utf8;

use Test::More;
use Test::Differences;

use grey::static qw[ tty::graphics datatypes::numeric ];

subtest '... test Graphics::Sprite creation from bitmap' => sub {
    my $red   = Graphics::Color->new(r => 1, g => 0, b => 0);
    my $green = Graphics::Color->new(r => 0, g => 1, b => 0);
    my $blue  = Graphics::Color->new(r => 0, g => 0, b => 1);

    my $sprite = Graphics::Sprite->new(
        top => 10,
        left => 20,
        bitmap => [
            [ $red,   $green, $blue  ],
            [ $green, $blue,  $red   ],
            [ $blue,  $red,   $green ],
        ]
    );

    isa_ok($sprite, 'Graphics::Sprite');
    is($sprite->height, 3, '... sprite has correct height');
    is($sprite->width, 3, '... sprite has correct width');
    is($sprite->is_flipped, 0, '... sprite not initially flipped');
    is($sprite->is_mirrored, 0, '... sprite not initially mirrored');
};

subtest '... test Graphics::Sprite creation from matrices' => sub {
    my $r_matrix = Matrix->initialize([2, 2], [1, 0, 0, 1]);
    my $g_matrix = Matrix->initialize([2, 2], [0, 1, 1, 0]);
    my $b_matrix = Matrix->initialize([2, 2], [0, 0, 1, 1]);

    my $sprite = Graphics::Sprite->new(
        top => 5,
        left => 10,
        r_matrix => $r_matrix,
        g_matrix => $g_matrix,
        b_matrix => $b_matrix,
    );

    isa_ok($sprite, 'Graphics::Sprite');
    is($sprite->height, 2, '... sprite has correct height');
    is($sprite->width, 2, '... sprite has correct width');
};

subtest '... test Graphics::Sprite draw_at method' => sub {
    my $red   = Graphics::Color->new(r => 1, g => 0, b => 0);
    my $green = Graphics::Color->new(r => 0, g => 1, b => 0);
    my $blue  = Graphics::Color->new(r => 0, g => 0, b => 1);

    my $sprite = Graphics::Sprite->new(
        top => 10,
        left => 20,
        bitmap => [
            [ $red,   $green ],
            [ $green, $blue  ],
        ]
    );

    # Test drawing within bounds
    my $p1 = Graphics::Point->new(x => 20, y => 10);
    my $c1 = $sprite->draw_at($p1);
    isa_ok($c1, 'Graphics::Color');
    ok($c1->equals($red), '... correct color at (20, 10)');

    my $p2 = Graphics::Point->new(x => 21, y => 10);
    my $c2 = $sprite->draw_at($p2);
    ok($c2->equals($green), '... correct color at (21, 10)');

    my $p3 = Graphics::Point->new(x => 20, y => 11);
    my $c3 = $sprite->draw_at($p3);
    ok($c3->equals($green), '... correct color at (20, 11)');

    my $p4 = Graphics::Point->new(x => 21, y => 11);
    my $c4 = $sprite->draw_at($p4);
    ok($c4->equals($blue), '... correct color at (21, 11)');

    # Test drawing outside bounds
    my $p5 = Graphics::Point->new(x => 19, y => 10);
    my $c5 = $sprite->draw_at($p5);
    is($c5, undef, '... returns undef for point outside bounds (left)');

    my $p6 = Graphics::Point->new(x => 22, y => 10);
    my $c6 = $sprite->draw_at($p6);
    is($c6, undef, '... returns undef for point outside bounds (right)');

    my $p7 = Graphics::Point->new(x => 20, y => 9);
    my $c7 = $sprite->draw_at($p7);
    is($c7, undef, '... returns undef for point outside bounds (top)');

    my $p8 = Graphics::Point->new(x => 20, y => 12);
    my $c8 = $sprite->draw_at($p8);
    is($c8, undef, '... returns undef for point outside bounds (bottom)');
};

subtest '... test Graphics::Sprite flip transformation' => sub {
    my $red   = Graphics::Color->new(r => 1, g => 0, b => 0);
    my $green = Graphics::Color->new(r => 0, g => 1, b => 0);
    my $blue  = Graphics::Color->new(r => 0, g => 0, b => 1);

    my $sprite = Graphics::Sprite->new(
        top => 0,
        left => 0,
        bitmap => [
            [ $red,   $green ],
            [ $blue,  $red   ],
        ]
    );

    # Before flip: top row is red, green
    my $c1 = $sprite->draw_at(Graphics::Point->new(x => 0, y => 0));
    ok($c1->equals($red), '... top-left is red before flip');

    my $c2 = $sprite->draw_at(Graphics::Point->new(x => 1, y => 0));
    ok($c2->equals($green), '... top-right is green before flip');

    # Flip vertically
    $sprite->flip;
    is($sprite->is_flipped, 1, '... sprite is flipped');

    # After flip: top row is blue, red (was bottom row)
    my $c3 = $sprite->draw_at(Graphics::Point->new(x => 0, y => 0));
    ok($c3->equals($blue), '... top-left is blue after flip');

    my $c4 = $sprite->draw_at(Graphics::Point->new(x => 1, y => 0));
    ok($c4->equals($red), '... top-right is red after flip');

    # Flip back
    $sprite->flip;
    is($sprite->is_flipped, 0, '... sprite is not flipped after second flip');

    my $c5 = $sprite->draw_at(Graphics::Point->new(x => 0, y => 0));
    ok($c5->equals($red), '... back to original after double flip');
};

subtest '... test Graphics::Sprite mirror transformation' => sub {
    my $red   = Graphics::Color->new(r => 1, g => 0, b => 0);
    my $green = Graphics::Color->new(r => 0, g => 1, b => 0);

    my $sprite = Graphics::Sprite->new(
        top => 0,
        left => 0,
        bitmap => [
            [ $red, $green ],
        ]
    );

    # Before mirror: left is red, right is green
    my $c1 = $sprite->draw_at(Graphics::Point->new(x => 0, y => 0));
    ok($c1->equals($red), '... left is red before mirror');

    my $c2 = $sprite->draw_at(Graphics::Point->new(x => 1, y => 0));
    ok($c2->equals($green), '... right is green before mirror');

    # Mirror horizontally
    $sprite->mirror;
    is($sprite->is_mirrored, 1, '... sprite is mirrored');

    # After mirror: left is green, right is red
    my $c3 = $sprite->draw_at(Graphics::Point->new(x => 0, y => 0));
    ok($c3->equals($green), '... left is green after mirror');

    my $c4 = $sprite->draw_at(Graphics::Point->new(x => 1, y => 0));
    ok($c4->equals($red), '... right is red after mirror');

    # Mirror back
    $sprite->mirror;
    is($sprite->is_mirrored, 0, '... sprite is not mirrored after second mirror');

    my $c5 = $sprite->draw_at(Graphics::Point->new(x => 0, y => 0));
    ok($c5->equals($red), '... back to original after double mirror');
};

subtest '... test Graphics::Sprite Matrix conversion round-trip' => sub {
    my $red   = Graphics::Color->new(r => 1, g => 0, b => 0);
    my $green = Graphics::Color->new(r => 0, g => 1, b => 0);
    my $blue  = Graphics::Color->new(r => 0, g => 0, b => 1);

    my $sprite = Graphics::Sprite->new(
        top => 0,
        left => 0,
        bitmap => [
            [ $red,   $green, $blue  ],
            [ $blue,  $red,   $green ],
        ]
    );

    # Export to matrices
    my ($r, $g, $b) = $sprite->to_matrices;
    isa_ok($r, 'Matrix');
    isa_ok($g, 'Matrix');
    isa_ok($b, 'Matrix');

    is($r->rows, 2, '... R matrix has correct rows');
    is($r->cols, 3, '... R matrix has correct cols');

    # Check some values
    is($r->at(0, 0), 1, '... R matrix (0,0) is 1');
    is($r->at(0, 1), 0, '... R matrix (0,1) is 0');
    is($g->at(0, 1), 1, '... G matrix (0,1) is 1');

    # Create new sprite from matrices
    my $sprite2 = Graphics::Sprite->new(
        top => 5,
        left => 10,
        r_matrix => $r,
        g_matrix => $g,
        b_matrix => $b,
    );

    is($sprite2->height, 2, '... reconstructed sprite has correct height');
    is($sprite2->width, 3, '... reconstructed sprite has correct width');

    # Verify colors match
    my $c1 = $sprite2->draw_at(Graphics::Point->new(x => 10, y => 5));
    ok($c1->equals($red), '... reconstructed sprite has correct color');
};

subtest '... test Graphics::Sprite to_bitmap conversion' => sub {
    my $red   = Graphics::Color->new(r => 1, g => 0, b => 0);
    my $green = Graphics::Color->new(r => 0, g => 1, b => 0);

    my $sprite = Graphics::Sprite->new(
        top => 0,
        left => 0,
        bitmap => [
            [ $red, $green ],
        ]
    );

    my $bitmap = $sprite->to_bitmap;
    is(ref $bitmap, 'ARRAY', '... to_bitmap returns ARRAY ref');
    is(scalar @$bitmap, 1, '... bitmap has correct row count');
    is(scalar @{$bitmap->[0]}, 2, '... bitmap has correct column count');

    isa_ok($bitmap->[0][0], 'Graphics::Color');
    ok($bitmap->[0][0]->equals($red), '... bitmap color matches');
    ok($bitmap->[0][1]->equals($green), '... bitmap color matches');
};

subtest '... test Graphics::Sprite with larger sprite' => sub {
    # Create a 5x5 gradient sprite
    my @bitmap;
    for my $y (0 .. 4) {
        my @row;
        for my $x (0 .. 4) {
            my $intensity = ($x + $y) / 8;
            push @row, Graphics::Color->new(
                r => $intensity,
                g => $intensity * 0.5,
                b => $intensity * 0.8
            );
        }
        push @bitmap, \@row;
    }

    my $sprite = Graphics::Sprite->new(
        top => 0,
        left => 0,
        bitmap => \@bitmap
    );

    is($sprite->height, 5, '... 5x5 sprite has correct height');
    is($sprite->width, 5, '... 5x5 sprite has correct width');

    # Test a few points
    my $c1 = $sprite->draw_at(Graphics::Point->new(x => 0, y => 0));
    is($c1->r, 0, '... corner is black');

    my $c2 = $sprite->draw_at(Graphics::Point->new(x => 4, y => 4));
    is($c2->r, 1, '... opposite corner is white');
};

done_testing;

#!perl

use v5.42;
use utf8;
use Test::More;
use Test::Differences;

use grey::static qw[ tty::graphics ];

subtest '... test Graphics::Color creation and accessors' => sub {
    my $red   = Graphics::Color->new( r => 1, g => 0, b => 0 );
    my $green = Graphics::Color->new( r => 0, g => 1, b => 0 );
    my $blue  = Graphics::Color->new( r => 0, g => 0, b => 1 );

    isa_ok($red,   'Graphics::Color');
    isa_ok($green, 'Graphics::Color');
    isa_ok($blue,  'Graphics::Color');

    is($red->r, 1, '... Red r is 1');
    is($red->g, 0, '... Red g is 0');
    is($red->b, 0, '... Red b is 0');

    eq_or_diff([1,0,0], [$red->rgb],   '... Red has the right rgb');
    eq_or_diff([0,1,0], [$green->rgb], '... Green has the right rgb');
    eq_or_diff([0,0,1], [$blue->rgb],  '... Blue has the right rgb');
};

subtest '... test Graphics::Color equality' => sub {
    my $red   = Graphics::Color->new( r => 1, g => 0, b => 0 );
    my $green = Graphics::Color->new( r => 0, g => 1, b => 0 );
    my $blue  = Graphics::Color->new( r => 0, g => 0, b => 1 );

    ok(!$red->equals($green), '... red does not equal green');
    ok(!$blue->equals($red), '... blue does not equal red');
    ok($red->equals($red), '... red equals red');

    ok($green->equals(Graphics::Color->new( r => 0, g => 1, b => 0 )), '... green equals Color(0,1,0)');
};

subtest '... test Graphics::Color with float values' => sub {
    my $color = Graphics::Color->new( r => 0.5, g => 0.75, b => 0.25 );

    is($color->r, 0.5,  '... r is 0.5');
    is($color->g, 0.75, '... g is 0.75');
    is($color->b, 0.25, '... b is 0.25');

    eq_or_diff([0.5, 0.75, 0.25], [$color->rgb], '... rgb is correct');
};

subtest '... test Graphics::Color clone' => sub {
    my $c1 = Graphics::Color->new( r => 0.8, g => 0.4, b => 0.2 );
    my $c2 = $c1->clone;

    isa_ok($c2, 'Graphics::Color');
    ok($c1->equals($c2), '... clone equals original');

    is($c2->r, 0.8, '... clone has same r');
    is($c2->g, 0.4, '... clone has same g');
    is($c2->b, 0.2, '... clone has same b');
};

subtest '... test Graphics::Color common colors' => sub {
    my $black = Graphics::Color->new( r => 0, g => 0, b => 0 );
    my $white = Graphics::Color->new( r => 1, g => 1, b => 1 );
    my $gray  = Graphics::Color->new( r => 0.5, g => 0.5, b => 0.5 );

    eq_or_diff([0, 0, 0], [$black->rgb], '... black is (0,0,0)');
    eq_or_diff([1, 1, 1], [$white->rgb], '... white is (1,1,1)');
    eq_or_diff([0.5, 0.5, 0.5], [$gray->rgb], '... gray is (0.5,0.5,0.5)');

    ok(!$black->equals($white), '... black not equal to white');
    ok(!$gray->equals($black), '... gray not equal to black');
    ok(!$gray->equals($white), '... gray not equal to white');
};

done_testing;

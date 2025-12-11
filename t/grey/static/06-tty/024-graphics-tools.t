#!perl

use v5.42;
use utf8;

use Test::More;

use grey::static qw[ tty::graphics ];

subtest '... test fract function' => sub {
    is(fract(3.7), 0.7, '... fract(3.7) = 0.7');
    is(fract(5.0), 0.0, '... fract(5.0) = 0.0');
    is(fract(1.25), 0.25, '... fract(1.25) = 0.25');

    # Negative numbers
    is(sprintf("%.1f", fract(-2.3)), sprintf("%.1f", 0.7), '... fract(-2.3) ~~ 0.7');
};

subtest '... test distance function' => sub {
    is(distance(0, 0), 0, '... distance(0,0) = 0');
    is(distance(3, 4), 5, '... distance(3,4) = 5 (3-4-5 triangle)');
    is(sprintf("%.3f", distance(1, 1)), sprintf("%.3f", sqrt(2)), '... distance(1,1) = sqrt(2)');
    is(distance(5, 12), 13, '... distance(5,12) = 13');
};

subtest '... test clamp function' => sub {
    is(clamp(5, 0, 10), 5, '... clamp(5, 0, 10) = 5 (within range)');
    is(clamp(-5, 0, 10), 0, '... clamp(-5, 0, 10) = 0 (below range)');
    is(clamp(15, 0, 10), 10, '... clamp(15, 0, 10) = 10 (above range)');
    is(clamp(0, 0, 10), 0, '... clamp(0, 0, 10) = 0 (at min edge)');
    is(clamp(10, 0, 10), 10, '... clamp(10, 0, 10) = 10 (at max edge)');
};

subtest '... test smooth function' => sub {
    is(smooth(0.0), 0.0, '... smooth(0.0) = 0.0');
    is(smooth(1.0), 1.0, '... smooth(1.0) = 1.0');
    is(smooth(0.5), 0.5, '... smooth(0.5) = 0.5');

    # Smooth should be 0 at edges, max at 0.5
    ok(smooth(0.25) < 0.5, '... smooth(0.25) < 0.5');
    ok(smooth(0.75) > 0.5, '... smooth(0.75) > 0.5');
};

subtest '... test smoothstep function' => sub {
    is(smoothstep(0, 1, 0.0), 0.0, '... smoothstep(0,1,0.0) = 0.0');
    is(smoothstep(0, 1, 1.0), 1.0, '... smoothstep(0,1,1.0) = 1.0');
    is(smoothstep(0, 1, 0.5), 0.5, '... smoothstep(0,1,0.5) = 0.5');

    # Outside range
    is(smoothstep(0, 1, -1), 0.0, '... smoothstep(0,1,-1) = 0.0');
    is(smoothstep(0, 1, 2), 1.0, '... smoothstep(0,1,2) = 1.0');

    # Different range
    is(smoothstep(0, 10, 5), 0.5, '... smoothstep(0,10,5) = 0.5');
};

subtest '... test mix function' => sub {
    is(mix(0, 100, 0.0), 0, '... mix(0,100,0.0) = 0');
    is(mix(0, 100, 1.0), 100, '... mix(0,100,1.0) = 100');
    is(mix(0, 100, 0.5), 50, '... mix(0,100,0.5) = 50');
    is(mix(0, 100, 0.25), 25, '... mix(0,100,0.25) = 25');
    is(mix(0, 100, 0.75), 75, '... mix(0,100,0.75) = 75');

    # Different range
    is(mix(10, 20, 0.0), 10, '... mix(10,20,0.0) = 10');
    is(mix(10, 20, 1.0), 20, '... mix(10,20,1.0) = 20');
    is(mix(10, 20, 0.5), 15, '... mix(10,20,0.5) = 15');

    # Negative values
    is(mix(-10, 10, 0.5), 0, '... mix(-10,10,0.5) = 0');
};

subtest '... test combined usage patterns' => sub {
    # Clamped mix
    my $val = mix(0, 1, clamp(1.5, 0, 1));
    is($val, 1, '... clamped mix at upper bound');

    # Smooth distance
    my $d = distance(3, 4);
    my $smoothed = smooth($d / 5);
    ok($smoothed >= 0 && $smoothed <= 1, '... normalized smooth distance');

    # Smoothstep for fading
    my $fade = smoothstep(0, 10, 5);
    is($fade, 0.5, '... smoothstep fading halfway');
};

done_testing;

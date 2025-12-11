#!perl

use v5.42;
use utf8;
use Test::More;
use Test::Differences;

use grey::static qw[ tty::graphics ];

subtest '... test Graphics::Point creation and accessors' => sub {
    my $p1 = Graphics::Point->new( x => 0, y => 0 );
    isa_ok($p1, 'Graphics::Point');

    is($p1->x, 0, '... got the right x');
    is($p1->y, 0, '... got the right y');

    eq_or_diff([0,0], [$p1->xy], '... got the right xy');
    eq_or_diff([0,0], [$p1->yx], '... got the right yx');

    my $p2 = Graphics::Point->new( x => 10, y => 5 );
    isa_ok($p2, 'Graphics::Point');

    is($p2->x, 10, '... got the right x');
    is($p2->y, 5, '... got the right y');

    eq_or_diff([10,5], [$p2->xy], '... got the right xy');
    eq_or_diff([5,10], [$p2->yx], '... got the right yx');
};

subtest '... test Graphics::Point distance' => sub {
    my $origin = Graphics::Point->new( x => 0, y => 0 );
    is($origin->distance, 0, '... origin distance is 0');

    my $p1 = Graphics::Point->new( x => 3, y => 4 );
    is($p1->distance, 5, '... 3-4-5 triangle');

    my $p2 = Graphics::Point->new( x => 1, y => 1 );
    is(sprintf("%.3f", $p2->distance), sprintf("%.3f", sqrt(2)), '... unit diagonal');
};

subtest '... test Graphics::Point equality' => sub {
    my $p1 = Graphics::Point->new( x => 10, y => 20 );
    my $p2 = Graphics::Point->new( x => 10, y => 20 );
    my $p3 = Graphics::Point->new( x => 10, y => 21 );
    my $p4 = Graphics::Point->new( x => 11, y => 20 );

    ok($p1->equals($p2), '... identical points are equal');
    ok(!$p1->equals($p3), '... different y coordinates not equal');
    ok(!$p1->equals($p4), '... different x coordinates not equal');
};

subtest '... test Graphics::Point clone' => sub {
    my $p1 = Graphics::Point->new( x => 42, y => 17 );
    my $p2 = $p1->clone;

    isa_ok($p2, 'Graphics::Point');
    ok($p1->equals($p2), '... clone equals original');

    is($p2->x, 42, '... clone has same x');
    is($p2->y, 17, '... clone has same y');
};

subtest '... test Graphics::Point with negative coordinates' => sub {
    my $p = Graphics::Point->new( x => -5, y => -10 );

    is($p->x, -5, '... negative x');
    is($p->y, -10, '... negative y');

    eq_or_diff([-5, -10], [$p->xy], '... negative xy');
    is(sprintf("%.3f", $p->distance), sprintf("%.3f", sqrt(125)), '... distance with negatives');
};

subtest '... test Graphics::Point with floating point coordinates' => sub {
    my $p = Graphics::Point->new( x => 1.5, y => 2.7 );

    is($p->x, 1.5, '... float x');
    is($p->y, 2.7, '... float y');

    eq_or_diff([1.5, 2.7], [$p->xy], '... float xy');
};

done_testing;

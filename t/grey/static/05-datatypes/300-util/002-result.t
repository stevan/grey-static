
use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Exception;

use grey::static qw[ datatypes::util ];

sub divide ($x, $y) {
    return Error('Cannot divide by zero') if $y == 0;
    return Ok( $x / $y );
}

my $r1 = divide(1, 0);
isa_ok($r1, 'Result');
ok($r1->failure, '... r1 it was a failure');
ok(!$r1->success, '... r1 it was not a success');

my $r2 = $r1->or_else(Ok(0));
isa_ok($r2, 'Result');
ok(!$r2->failure, '... r2 it was not a failure');
ok($r2->success, '... r2 it was a success');

my $r3 = divide(1, 2)->map(sub ($x) { $x * 10 });
isa_ok($r3, 'Result');
ok(!$r3->failure, '... r3 it was not a failure');
ok($r3->success, '... r3 it was a success');
is($r3->ok, 5, '... r3 got the mapped value');

done_testing;

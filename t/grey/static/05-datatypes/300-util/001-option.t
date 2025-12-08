
use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Exception;

use grey::static qw[ datatypes::util ];

my $x = Some(100);
isa_ok($x, 'Option');
ok($x->defined, '... x is defined');
ok(!$x->empty, '... x is not empty');
is($x->get, 100, '... got the value from x');
is($x->get_or_else(200), 100, '... got the value from x');

my $x2 = $x->or_else(200);
isa_ok($x2, 'Option');
ok($x2->defined, '... x2 is defined');
ok(!$x2->empty, '... x2 is not empty');
is($x2->get, 100, '... got the value from x2 (which is x)');

my $y = None();
isa_ok($y, 'Option');
ok(!$y->defined, '... y is not defined');
ok($y->empty, '... y is empty');
is($y->get_or_else(200), 200, '... got the get_or_else value from y');

done_testing;

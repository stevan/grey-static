#!/usr/bin/env perl

use v5.42;
use Test::More;

use grey::static qw[ datatypes::collections datatypes::util functional ];

subtest 'List construction' => sub {
    my $list1 = List->new(items => [1, 2, 3]);
    isa_ok($list1, 'List');
    is($list1->size(), 3, 'size is 3');

    my $list2 = List->of(4, 5, 6);
    isa_ok($list2, 'List');
    is($list2->size(), 3, 'of() works');

    my $list3 = List->empty();
    isa_ok($list3, 'List');
    is($list3->size(), 0, 'empty() works');
    ok($list3->is_empty(), 'is_empty returns true');
};

subtest 'List access' => sub {
    my $list = List->of(10, 20, 30, 40);

    is($list->at(0), 10, 'at(0) returns first');
    is($list->at(2), 30, 'at(2) returns third');
    is($list->first(), 10, 'first() works');
    is($list->last(), 40, 'last() works');
};

subtest 'List immutable operations' => sub {
    my $list = List->of(1, 2, 3);

    my $list2 = $list->push(4, 5);
    is($list->size(), 3, 'original unchanged');
    is($list2->size(), 5, 'pushed list has 5 elements');
    is($list2->at(3), 4, 'element 3 is 4');

    my $list3 = $list->unshift(0);
    is($list3->size(), 4, 'unshifted list has 4 elements');
    is($list3->first(), 0, 'first element is 0');
};

subtest 'List pop and shift' => sub {
    my $list = List->of(1, 2, 3);

    my ($val1, $list2) = $list->pop()->@*;
    is($val1, 3, 'popped value is 3');
    is($list2->size(), 2, 'new list has 2 elements');

    my ($val2, $list3) = $list->shift()->@*;
    is($val2, 1, 'shifted value is 1');
    is($list3->size(), 2, 'new list has 2 elements');
    is($list3->first(), 2, 'first element is now 2');
};

subtest 'List reverse and slice' => sub {
    my $list = List->of(1, 2, 3, 4, 5);

    my $reversed = $list->reverse();
    is($reversed->first(), 5, 'reversed first is 5');
    is($reversed->last(), 1, 'reversed last is 1');

    my $slice = $list->slice(1, 4);
    is($slice->size(), 3, 'slice has 3 elements');
    is($slice->at(0), 2, 'slice starts at 2');
    is($slice->at(2), 4, 'slice ends at 4');
};

subtest 'List map' => sub {
    my $list = List->of(1, 2, 3);
    my $doubled = $list->map(Function->new(f => sub ($x) { $x * 2 }));

    isa_ok($doubled, 'List');
    is($doubled->size(), 3, 'mapped list has 3 elements');
    is($doubled->at(0), 2, 'first element doubled');
    is($doubled->at(1), 4, 'second element doubled');
    is($doubled->at(2), 6, 'third element doubled');
};

subtest 'List grep' => sub {
    my $list = List->of(1, 2, 3, 4, 5, 6);
    my $evens = $list->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));

    isa_ok($evens, 'List');
    is($evens->size(), 3, 'filtered list has 3 elements');
    is($evens->at(0), 2, 'first even is 2');
    is($evens->at(1), 4, 'second even is 4');
    is($evens->at(2), 6, 'third even is 6');
};

subtest 'List reduce' => sub {
    my $list = List->of(1, 2, 3, 4, 5);
    my $sum = $list->reduce(0, BiFunction->new(f => sub ($acc, $x) { $acc + $x }));

    is($sum, 15, 'sum is 15');
};

subtest 'List find' => sub {
    my $list = List->of(1, 2, 3, 4, 5);

    my $found = $list->find(Predicate->new(f => sub ($x) { $x > 3 }));
    ok($found->defined(), 'found something');
    is($found->get(), 4, 'found value is 4');

    my $not_found = $list->find(Predicate->new(f => sub ($x) { $x > 10 }));
    ok($not_found->empty(), 'nothing found');
};

subtest 'List contains' => sub {
    my $list = List->of(1, 2, 3);

    ok($list->contains(2), 'contains 2');
    ok(!$list->contains(5), 'does not contain 5');
};

subtest 'List any/all/none' => sub {
    my $list = List->of(2, 4, 6, 8);

    ok($list->all(Predicate->new(f => sub ($x) { $x % 2 == 0 })), 'all even');
    ok($list->any(Predicate->new(f => sub ($x) { $x > 5 })), 'any > 5');
    ok($list->none(Predicate->new(f => sub ($x) { $x % 2 == 1 })), 'none odd');
};

subtest 'List to_string' => sub {
    my $list = List->of(1, 2, 3);
    my $str = $list->to_string();
    is($str, 'List[1, 2, 3]', 'to_string works');

    my $str2 = "$list";
    is($str2, 'List[1, 2, 3]', 'stringification works');
};

subtest 'List to_array' => sub {
    my $list = List->of(1, 2, 3);
    my $arr = $list->to_array();

    is_deeply($arr, [1, 2, 3], 'to_array returns arrayref');
};

done_testing();

#!/usr/bin/env perl

use v5.42;
use Test::More;

use grey::static qw[ datatypes::collections datatypes::util functional ];

subtest 'Stack operations' => sub {
    my $stack = Stack->of(1, 2, 3);
    is($stack->size(), 3, 'stack has 3 elements');

    my $pushed = $stack->push(4, 5);
    is($pushed->size(), 5, 'pushed stack has 5 elements');

    my ($val, $popped) = $pushed->pop()->@*;
    is($val, 5, 'popped value is 5');
    is($popped->size(), 4, 'popped stack has 4 elements');

    my $peek = $stack->peek();
    ok($peek->defined(), 'peek returns Some');
    is($peek->get(), 3, 'peek shows top element');

    my $empty = Stack->empty();
    ok($empty->is_empty(), 'empty stack is empty');
    ok($empty->peek()->empty(), 'peek on empty returns None');
};

subtest 'Queue operations' => sub {
    my $queue = Queue->of(1, 2, 3);
    is($queue->size(), 3, 'queue has 3 elements');

    my $enqueued = $queue->enqueue(4, 5);
    is($enqueued->size(), 5, 'enqueued queue has 5 elements');

    my ($val, $dequeued) = $enqueued->dequeue()->@*;
    is($val, 1, 'dequeued value is 1 (FIFO)');
    is($dequeued->size(), 4, 'dequeued queue has 4 elements');

    my $peek = $queue->peek();
    ok($peek->defined(), 'peek returns Some');
    is($peek->get(), 1, 'peek shows front element');

    my $empty = Queue->empty();
    ok($empty->is_empty(), 'empty queue is empty');
};

subtest 'Set operations' => sub {
    my $set = Set->of(1, 2, 2, 3, 3, 3);
    is($set->size(), 3, 'set has 3 unique elements');

    ok($set->contains(2), 'set contains 2');
    ok(!$set->contains(4), 'set does not contain 4');

    my $added = $set->add(4, 5);
    is($added->size(), 5, 'added set has 5 elements');

    my $removed = $set->remove(2);
    is($removed->size(), 2, 'removed set has 2 elements');
    ok(!$removed->contains(2), 'removed element is gone');

    my $set1 = Set->of(1, 2, 3);
    my $set2 = Set->of(3, 4, 5);

    my $union = $set1->union($set2);
    is($union->size(), 5, 'union has 5 elements');

    my $intersection = $set1->intersection($set2);
    is($intersection->size(), 1, 'intersection has 1 element');
    ok($intersection->contains(3), 'intersection contains 3');

    my $difference = $set1->difference($set2);
    is($difference->size(), 2, 'difference has 2 elements');
    ok($difference->contains(1), 'difference contains 1');
    ok($difference->contains(2), 'difference contains 2');

    ok($set1->is_subset(Set->of(1, 2, 3, 4)), 'is subset');
    ok(!$set1->is_subset($set2), 'is not subset');

    ok(Set->of(1, 2, 3, 4)->is_superset($set1), 'is superset');
};

subtest 'Map operations' => sub {
    my $map = Map->of(a => 1, b => 2, c => 3);
    is($map->size(), 3, 'map has 3 entries');

    my $val = $map->get('b');
    ok($val->defined(), 'get returns Some');
    is($val->get(), 2, 'got correct value');

    my $missing = $map->get('z');
    ok($missing->empty(), 'missing key returns None');

    ok($map->contains_key('a'), 'contains key a');
    ok(!$map->contains_key('z'), 'does not contain key z');

    ok($map->contains_value(2), 'contains value 2');
    ok(!$map->contains_value(99), 'does not contain value 99');

    my $put = $map->put('d', 4);
    is($put->size(), 4, 'put adds entry');
    ok($put->get('d')->get() == 4, 'put value is correct');

    my $removed = $map->remove('b');
    is($removed->size(), 2, 'remove deletes entry');
    ok($removed->get('b')->empty(), 'removed key is gone');

    my $keys = $map->keys();
    isa_ok($keys, 'Set');
    is($keys->size(), 3, 'keys returns Set with 3 elements');

    my $values = $map->values();
    isa_ok($values, 'List');
    is($values->size(), 3, 'values returns List with 3 elements');

    my $entries = $map->entries();
    isa_ok($entries, 'List');
    is($entries->size(), 3, 'entries returns List with 3 pairs');
};

subtest 'Functional operations on collections' => sub {
    # Stack
    my $stack = Stack->of(1, 2, 3);
    my $doubled_stack = $stack->map(Function->new(f => sub ($x) { $x * 2 }));
    isa_ok($doubled_stack, 'Stack');

    # Queue
    my $queue = Queue->of(1, 2, 3, 4, 5, 6);
    my $evens_queue = $queue->grep(Predicate->new(f => sub ($x) { $x % 2 == 0 }));
    isa_ok($evens_queue, 'Queue');
    is($evens_queue->size(), 3, 'grep filtered to 3 evens');

    # Set
    my $set = Set->of(1, 2, 3);
    my $doubled_set = $set->map(Function->new(f => sub ($x) { $x * 2 }));
    isa_ok($doubled_set, 'Set');
    ok($doubled_set->contains(4), 'mapped set contains doubled values');

    # Map
    my $map = Map->of(a => 1, b => 2);
    my $incremented = $map->map(BiFunction->new(f => sub ($k, $v) { $v + 1 }));
    isa_ok($incremented, 'Map');
    is($incremented->get('a')->get(), 2, 'map values incremented');
};

subtest 'String representations' => sub {
    is(List->of(1,2,3)->to_string(), 'List[1, 2, 3]', 'List to_string');
    is(Stack->of(1,2,3)->to_string(), 'Stack[1, 2, 3]', 'Stack to_string');
    is(Queue->of(1,2,3)->to_string(), 'Queue[1, 2, 3]', 'Queue to_string');
    like(Set->of(1,2,3)->to_string(), qr/^Set\{/, 'Set to_string');
    like(Map->of(a=>1)->to_string(), qr/^Map\{a=>1\}$/, 'Map to_string');
};

done_testing();

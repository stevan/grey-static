#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;

use lib 'lib';
use grey::static qw[ concurrency::actor ];

# Test actor class
class TestWorker :isa(Actor) {
    field $name :param :reader = 'default';
}

subtest 'Actor::Props basic' => sub {
    my $props = Actor::Props->new(class => 'TestWorker');
    ok($props, '... props created');
    is($props->class, 'TestWorker', '... class set correctly');
    is($props->alias, undef, '... alias is undef by default');
    is_deeply($props->args, {}, '... args is empty hash by default');
};

subtest 'Actor::Props with args' => sub {
    my $props = Actor::Props->new(
        class => 'TestWorker',
        args  => { name => 'worker-1' }
    );

    is($props->class, 'TestWorker', '... class set correctly');
    is_deeply($props->args, { name => 'worker-1' }, '... args set correctly');
};

subtest 'Actor::Props with alias' => sub {
    my $props = Actor::Props->new(
        class => 'TestWorker',
        alias => '//usr/worker'
    );

    is($props->alias, '//usr/worker', '... alias set correctly');
};

subtest 'Actor::Props default supervisor' => sub {
    my $props = Actor::Props->new(class => 'TestWorker');
    my $supervisor = $props->supervisor;

    ok($supervisor, '... has default supervisor');
    isa_ok($supervisor, 'Actor::Supervisors::Stop');
};

subtest 'Actor::Props with_supervisor fluent' => sub {
    # Create a mock supervisor
    my $custom_supervisor = Actor::Supervisors::Supervisor->new;

    my $props = Actor::Props->new(class => 'TestWorker')
        ->with_supervisor($custom_supervisor);

    is($props->supervisor, $custom_supervisor, '... custom supervisor set');
    isa_ok($props, 'Actor::Props', '... with_supervisor returns $self');
};

subtest 'Actor::Props new_actor' => sub {
    my $props = Actor::Props->new(
        class => 'TestWorker',
        args  => { name => 'spawned' }
    );

    my $actor = $props->new_actor;
    ok($actor, '... actor created');
    isa_ok($actor, 'TestWorker');
    is($actor->name, 'spawned', '... args passed to constructor');
};

subtest 'Actor::Props stringification' => sub {
    my $props = Actor::Props->new(class => 'TestWorker');
    my $str = "$props";
    is($str, 'Props[TestWorker]', '... stringifies correctly');
};

done_testing;

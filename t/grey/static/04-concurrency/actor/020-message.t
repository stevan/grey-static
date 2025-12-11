#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;

use lib 'lib';
use grey::static qw[ concurrency::actor ];

subtest 'Actor::Message basic' => sub {
    my $msg = Actor::Message->new;
    ok($msg, '... message created');
    is($msg->reply_to, undef, '... reply_to is undef by default');
    is($msg->sender, undef, '... sender is undef by default');
    is($msg->payload, undef, '... payload is undef by default');
};

subtest 'Actor::Message with fields' => sub {
    my $msg = Actor::Message->new(
        payload => { foo => 'bar' }
    );
    is_deeply($msg->payload, { foo => 'bar' }, '... payload set correctly');
};

subtest 'Actor::Message stringification' => sub {
    my $msg = Actor::Message->new(payload => 'test');
    my $str = "$msg";
    like($str, qr/Actor::Message/, '... stringifies with class name');
    like($str, qr/payload: test/, '... stringifies with payload');
};

subtest 'Custom message class' => sub {
    # Define a custom message
    class Greeting :isa(Actor::Message) {
        field $name :param :reader;
    }

    my $msg = Greeting->new(name => 'World');
    ok($msg, '... custom message created');
    is($msg->name, 'World', '... custom field accessible');
    isa_ok($msg, 'Actor::Message');
};

done_testing;

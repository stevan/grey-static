#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;

use lib 'lib';
use grey::static qw[ concurrency::actor ];

subtest 'Actor::Ref basic construction' => sub {
    my $ref = Actor::Ref->new(pid => 42);
    ok($ref, '... ref created');
    is($ref->pid, 42, '... pid set correctly');
    is($ref->context, undef, '... context is undef initially');
};

subtest 'Actor::Ref set_context' => sub {
    use Scalar::Util qw(refaddr);

    my $ref = Actor::Ref->new(pid => 1);

    # Create a mock context
    package MockContext {
        sub new { bless { props => $_[1], stopped => 0 }, $_[0] }
        sub props { shift->{props} }
        sub is_stopped { shift->{stopped} }
    }

    my $mock_context = MockContext->new(Actor::Props->new(class => 'MockActor'));

    my $result = $ref->set_context($mock_context);
    is(refaddr($result), refaddr($ref), '... set_context returns $self (same reference)');
    is(refaddr($ref->context), refaddr($mock_context), '... context is set');
};

subtest 'Actor::Ref stringification without context' => sub {
    my $ref = Actor::Ref->new(pid => 7);
    my $str = "$ref";
    like($str, qr/Ref\(\?\)\[007\]/, '... stringifies with ? when no context');
};

subtest 'Actor::Ref stringification with context' => sub {
    my $ref = Actor::Ref->new(pid => 123);

    # Create a mock context with props
    package MockContext2 {
        sub new { bless { props => $_[1] }, $_[0] }
        sub props { shift->{props} }
    }

    my $mock_context = MockContext2->new(Actor::Props->new(class => 'MyActor'));
    $ref->set_context($mock_context);

    my $str = "$ref";
    like($str, qr/Ref\(MyActor\)\[123\]/, '... stringifies with class name');
};

subtest 'Actor::Ref pid formatting' => sub {
    # Test that PIDs are zero-padded to 3 digits
    my $ref1 = Actor::Ref->new(pid => 1);
    my $ref2 = Actor::Ref->new(pid => 42);
    my $ref3 = Actor::Ref->new(pid => 999);

    like("$ref1", qr/\[001\]/, '... single digit padded');
    like("$ref2", qr/\[042\]/, '... double digit padded');
    like("$ref3", qr/\[999\]/, '... triple digit not padded');
};

done_testing;

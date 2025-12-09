#!perl
# Basic MOP functionality tests

use v5.42;
use Test::More;

use grey::static qw[ functional stream mop ];

# Test package for introspection
package TestPackage {
    our $SCALAR = 42;
    our @ARRAY  = (1, 2, 3);
    our %HASH   = (foo => 'bar');

    sub method1 { "method1" }
    sub method2 { "method2" }
}

# Test MOP->namespace()
subtest 'MOP->namespace()' => sub {
    my @globs = MOP->namespace('TestPackage')
        ->take(5)
        ->collect(Stream::Collectors->ToList);

    ok(scalar @globs > 0, 'found globs in TestPackage');
    isa_ok($globs[0], 'MOP::Glob', 'first element');
};

# Test glob introspection
subtest 'MOP::Glob methods' => sub {
    my @globs = MOP->namespace('TestPackage')
        ->collect(Stream::Collectors->ToList);

    my ($scalar_glob) = grep { $_->name eq 'SCALAR' } @globs;
    ok($scalar_glob, 'found SCALAR glob');
    is($scalar_glob->stash, 'TestPackage', 'correct stash');
    is($scalar_glob->full_name, 'TestPackage::SCALAR', 'correct full_name');
    ok($scalar_glob->has_scalar, 'has scalar slot');
};

# Test expand_symbols
subtest 'expand_symbols()' => sub {
    my @code_symbols = MOP->namespace('TestPackage')
        ->expand_symbols(qw[ CODE ])
        ->collect(Stream::Collectors->ToList);

    ok(scalar @code_symbols >= 2, 'found at least 2 code symbols');
    isa_ok($code_symbols[0], 'MOP::Symbol', 'symbol type');
    is($code_symbols[0]->type, 'CODE', 'symbol is CODE');
    is($code_symbols[0]->sigil, '&', 'code sigil is &');
};

# Test getting method names
subtest 'get method names' => sub {
    my @methods = MOP->namespace('TestPackage')
        ->expand_symbols(qw[ CODE ])
        ->map(sub ($s) { $s->glob->name })
        ->collect(Stream::Collectors->ToList);

    my %methods = map { $_ => 1 } @methods;
    ok($methods{method1}, 'found method1');
    ok($methods{method2}, 'found method2');
};

# Test MOP::Symbol
subtest 'MOP::Symbol' => sub {
    my @scalars = MOP->namespace('TestPackage')
        ->expand_symbols(qw[ SCALAR ])
        ->collect(Stream::Collectors->ToList);

    ok(scalar @scalars > 0, 'found scalar symbols');

    my ($scalar) = grep { $_->glob->name eq 'SCALAR' } @scalars;
    ok($scalar, 'found SCALAR symbol');
    isa_ok($scalar->glob, 'MOP::Glob', 'symbol has glob');
    is($scalar->type, 'SCALAR', 'symbol type is SCALAR');
    is($scalar->sigil, '$', 'scalar sigil is $');
};

# Test walk() for nested namespaces
subtest 'walk nested namespaces' => sub {
    # Create a nested namespace
    package TestPackage::Nested {
        sub nested_method { "nested" }
    }

    my @all_globs = MOP->namespace('TestPackage')
        ->walk()
        ->take(20)  # Limit to avoid huge output
        ->collect(Stream::Collectors->ToList);

    ok(scalar @all_globs > 0, 'walk found globs');

    my @stashes = grep { $_->is_stash } @all_globs;
    ok(scalar @stashes > 0, 'found nested stashes');
};

done_testing;

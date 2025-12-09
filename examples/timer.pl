#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use importer 'Data::Dumper' => qw[ Dumper ];
use importer 'Time::HiRes'  => qw[ sleep time ];

use VM::Kernel::Timer;
use VM::Kernel::Timer::Wheel;

my $w = VM::Kernel::Timer::Wheel->new;

my $max = 999;
my $amount = $ARGV[0] // $max;

my @expected = map { 1+int(rand($max)) } 0 .. $amount;
my @got;

#diag "Testing $amount random timers ...";

{
my $start = time;

foreach my $t (@expected) {
    my $x = $t;
    $w->add_timer(VM::Kernel::Timer->new(
        expiry => $t,
        event  => sub { push @got => $x }
    ));
}

#diag "Adding timers took :".(time - $start);
}

my $i = $max + 1;
while ($i--) {
    print "\e[2J\e[H";
    $w->advance_by( 1 );
    $w->dump_wheel;
    #my $x = <>;
    sleep(0.03);
}

{
    my $start = time;
    $w->advance_by( 1 ) foreach 0 .. $max;
    #diag "Advancing took :".(time - $start);
}

eq_or_diff(
    [ @got ],
    [ sort { $a <=> $b } @expected ],
    '... got all the events!'
);

done_testing;



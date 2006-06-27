# vim: ts=8:sw=4:sts=4:et
use strict;
use warnings;

use lib 'lib';
use Test::More 'no_plan';
use_ok('Class::Measure');
use_ok('Class::Measure::Length');

my @units = sort Class::Measure::Length->units;
my $first = shift(@units);
my $m = Class::Measure::Length::length( 10, $first );
foreach my $unit (@units){
    $m->set_unit($unit);
}
$m->set_unit($first);
ok( ( int($m->value) == 10 ), 'run all conversions' );


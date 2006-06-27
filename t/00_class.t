# vim: ts=8:sw=4:sts=4:et
use strict;
use warnings;

use lib 'lib';
use Test::More 'no_plan';
use_ok('Class::Measure');

eval{ Class::Measure->new };
ok( $@, 'cannot create from base class' );

{ package MeasureTest; use base qw( Class::Measure ); }

eval{ MeasureTest->new };
ok( $@, 'invalid number of arguments' );

eval{ MeasureTest->new( 2, 'inches' ) };
ok( $@, 'unkown unit' );

MeasureTest->reg_units(
    qw( inch foot yard centimeter meter )
);
MeasureTest->reg_aliases(
    'inches' => 'inch',
    'feet' => 'foot',
    'yards' => 'yard',
    'centimeters' => 'centimeter',
    'meters' => 'meter',
);
MeasureTest->reg_convs(
    12, 'inches' => 'foot',
    3, 'feet' => 'yard',
    'yard' => 91.44, 'centimeters',
    100, 'centimeters' => 'meter',
);

my $path = MeasureTest->_path( 'inch' => 'meter' );
ok( (@$path==5), 'long path correct' );

MeasureTest->reg_convs( 'yard' => .9144, 'meter' );
$path = MeasureTest->_path( 'inch' => 'meter' );
ok( (@$path==4), 'shortened path' );

$path = MeasureTest->_path( 'foot' => 'inch' );
ok( (@$path==2), 'one step path' );

my $m = MeasureTest->new( 3, 'inch' );

$m += 2;
ok( ($m->value==5), '+= worked' );
$m ++;
ok( ($m->value==6), '++ worked' );
$m = 2 + $m;
ok( ($m->value==8), 'n + obj worked' );
$m = $m + MeasureTest->new( 1, 'foot');
ok( ($m->value==20), 'obj + obj' );

$m -= 2;
ok( ($m->value==18), '-= worked' );
$m --;
ok( ($m->value==17), '-- worked' );
$m = 30 - $m;
ok( ($m->value==13), 'n - obj worked' );
$m = $m - MeasureTest->new( 1, 'foot' );
ok( ($m->value==1), 'obj - obj' );

$m->set_value( 1, 'foot' );
ok( ($m->inches==12), 'autoloaded conversion (inches)' );
ok( (int($m->yards*10)==3), 'autoloaded conversion (yards)' );


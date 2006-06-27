# vim: ts=8:sw=4:sts=4:et

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
    module_name => 'Class::Measure',
    license => 'perl',
    requires => {
        'perl' => '5.6.1',
    },
);

$build->create_build_script;


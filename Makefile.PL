use inc::Module::Install;

name           'Class-Measure';
all_from       'lib/Class/Measure.pm';

requires       'Sub::Exporter' => '0.982';
test_requires  'Test::More'    => '0.82';

WriteAll;

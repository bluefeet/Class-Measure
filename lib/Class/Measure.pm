package Class::Measure;
use 5.008001;
use strict;
use warnings;
our $VERSION = '0.10';

=encoding utf8

=head1 NAME

Class::Measure - Create, compare, and convert units of measurement.

=head1 SYNOPSIS

See L<Class::Measure::Length> for some examples.

=head1 DESCRIPTION

This is a base class that is inherited by the Class::Measure 
classes.  This distribution comes with the class L<Class::Measure::Length>.

The classes L<Class::Measure::Area>, L<Class::Measure::Mass>,
L<Class::Measure::Space>, L<Class::Measure::Temperature>,
and L<Class::Measure::Volume> are planned and will be added soon.

The methods described here are available in all Class::Measure classes.

=cut

use Carp qw( croak );
use Scalar::Util qw( blessed looks_like_number );

use overload 
    '+'=>\&_ol_add, '-'=>\&_ol_sub, 
    '*'=>\&_ol_mult, '/'=>\&_ol_div,
    '""'=>\&_ol_str;

our $type_convs = {};
our $type_paths = {};
our $type_aliases = {};

=head1 METHODS

=head2 new

    my $m = new Class::Measure::Length( 1, 'inch' );

Creates a new measurement object.  You must pass an initial
measurement and default unit.

In most cases the measurement class that you are using
will export a method to create new measurements.  For
example L<Class::Measure::Length> exports the
C<length()> method.

=cut

sub new {
    my $class = shift;

    my $unit = pop;
    $unit = $type_aliases->{$class}->{$unit} || $unit if $unit;

    croak 'Unknown Class::Measure unit'
        unless $unit and $type_convs->{$class}->{$unit};

    return bless {
        unit => $unit,
        values => { $unit => shift },
    }, $class;
}

=head2 unit

  my $unit = $m->unit();

Returns the object's default unit.

=cut

sub unit {
    my $self = shift;
    return $self->{unit};
}

=head2 set_unit

    $m->set_unit( 'feet' );

Sets the default unit of the measurement.

=cut

sub set_unit {
    my $self = shift;
    my $unit = $self->_unalias( shift );
    $self->_conv( $unit );
    $self->{unit} = $unit;
    return;
}

=head2 value

    my $yards = $m->value('yards');
    my $val = $m->value();
    print "$m is the same as $val when in a string\n";

Retrieves the value of the measurement in the
default unit.  You may specify a unit in which
case the value is converted to the unit and returned.

This method is also used to handle overloading of
stringifying the object.

=cut

sub value {
    my $self = shift;
    return $self->_conv(shift) if @_;
    return $self->{values}->{$self->{unit}};
}

=head2 set_value

    my $m = length( 0, 'inches' );
    $m->set_value( 12 ); # 12 inches.
    $m->set_value( 1, 'foot' ); # 1 foot.

Sets the measurement in the default unit.  You may
specify a new default unit as well.

=cut

sub set_value {
    my $self = shift;
    $self->{unit} = $self->_unalias(pop @_) if( @_>1 );
    $self->{values} = { $self->{unit} => shift };
    return;
}

=head2 reg_units

    Class::Measure::Length->reg_units(
        'inch', 'foot', 'yard',
    );

Registers one or more units for use in the specified
class.  Units should be in the singular, most common,
form.

=cut

sub reg_units {
    my $self = shift;
    my $class = ref($self) || $self;
    my $convs = $type_convs->{$class} ||= {};
    foreach my $unit (@_){
        croak('This unit has already been defined') if $convs->{$unit};
        $convs->{$unit} = {};

        no strict 'refs';
        *{"${class}::${unit}"} = _build_unit_sub( $unit );
    }
    return;
}

sub _build_unit_sub {
    my ($unit) = @_;

    return sub{
        my $self = shift;
        return $self->set_value( shift(), $unit ) if @_;
        return $self->_conv( $unit );
    };
}

=head2 units

    my @units = Class::Measure::Length->units();

Returns a list of all registered units.

=cut

sub units {
    my $self = shift;
    my $class = ref($self) || $self;
    return keys(%{$type_convs->{$class}});
}

=head2 reg_aliases

    Class::Measure::Length->reg_aliases(
        ['feet','ft'] => 'foot',
        ['in','inches'] => 'inch',
        'yards' => 'yard'
    );

Register alternate names for units.  Expects two
arguments per unit to alias.  The first argument
being the alias (scalar) or aliases (array ref), and
the second argument being the unit to alias them to.

=cut

sub reg_aliases {
    my $self = shift;
    my $class = ref($self) || $self;
    croak('Wrong number of arguments (must be a multiple of two)') if( (@_+0) % 2 );
    my $aliases = $type_aliases->{$class} ||= {};
    while( @_ ){
        my @aliases = ( ref($_[0]) ? @{shift()} : shift );
        my $unit = shift;
        croak('Unknown unit "'.$unit.'" to alias to') unless( defined $type_convs->{$class}->{$unit} );
        foreach my $alias (@aliases){
            if( defined $aliases->{$alias} ){ croak('Alias already in use'); }
            $aliases->{$alias} = $unit;

            no strict 'refs';
            *{"${class}::${alias}"} = *{"${class}::${unit}"};
        }
    }
    return;
}

=head2 reg_convs

    Class::Measure::Length->reg_convs(
        12, 'inches' => 'foot',
        'yard' => '3', 'feet'
    );

Registers a unit conversion.  There are three distinct
ways to specify a new conversion.  Each requires three
arguments.

    $count1, $unit1 => $unit2
    $unit1 => $count2, $unit2

These first two syntaxes create automatic reverse conversions
as well.  So, saying there are 12 inches in a foot implies
that there are 1/12 feet in an inch.

    $unit1 => $unit2, $sub

The third syntax accepts a subroutine as the last argument
the subroutine will be called with the value of $unit1 and
it's return value will be assigned to $unit2.  This
third syntax does not create a reverse conversion automatically.

=cut

sub reg_convs {
    my $self = shift;
    croak('Wrong number of arguments (must be a multiple of three)') if( (@_+0) % 3 );
    my $class = ref($self) || $self;
    while(@_){
        my($from,$to,$conv);
        # First check for coderef to avoid seeing units as number in that case:
        if( ref($_[2]) eq 'CODE' ){
            ($from,$to,$conv) = splice(@_,0,3);
        }elsif( looks_like_number($_[0]) ){
            ($conv,$from,$to) = splice(@_,0,3);
            $conv = 1 / $conv;
        }elsif( looks_like_number($_[1]) ){
            ($from,$conv,$to) = splice(@_,0,3);
        }else{
            croak('Invalid arguments');
        }
        $from = $self->_unalias($from);
        $to = $self->_unalias($to);
        my $units = $type_convs->{$class} ||= {};
        $units->{$from} ||= {};
        $units->{$from}->{$to} = $conv;
        unless( ref $conv ){
            $units->{$to} ||= {};
            $units->{$to}->{$from} = 1/$conv;
        }
    }
    $type_paths->{$class} = {};
    return;
}

sub _unalias {
    my $self = shift;
    my $class = ref($self) || $self;
    my $unit = shift;
    return $unit if( defined $type_convs->{$class}->{$unit} );
    return $type_aliases->{$class}->{$unit} || croak('Unknown unit or alias "'.$unit.'"');
}

sub _conv {
    my $self = shift;
    my $class = ref($self) || $self;
    my $unit = $self->_unalias( shift );
    return $self->{values}->{$unit} if( defined $self->{values}->{$unit} );
    my $path = $self->_path( $self->unit, $unit );
    croak('Unable to find an appropriate conversion path') unless( $path );
    my $units = $type_convs->{$class};
    my $prev_unit = shift( @$path );
    my $value = $self->value;
    foreach $unit (@$path){
        my $conv = $units->{$prev_unit}->{$unit};
        if( ref($conv) ){
            $value = &{$conv}( $value, $prev_unit, $unit );
        }else{
            $value = $value * $units->{$prev_unit}->{$unit};
        }
        $self->{values}->{$unit} = $value;
        $prev_unit = $unit;
    }
    return $value;
}

sub _path {
    my $self = shift;
    my $from = $self->_unalias(shift);
    my $to = $self->_unalias(shift);
    my $class = ref($self) || $self;
    my $key = "$from-$to";
    my $paths = $type_paths->{$class} ||= {};
    if( defined $paths->{$key} ){ return [@{$paths->{$key}}]; }

    my $units = $type_convs->{$class} ||= {};
    my $path;
    foreach (1..10){
        $path = _find_path( $from, $to, $units, $_ );
        last if( $path );
    }
    return 0 if(!$path);
    $paths->{$key} = $path;
    return [@$path];
}

sub _find_path {
    my($level,$to,$units) = splice(@_,0,3);
    unless( ref $level ){ $level=[$level]; }
    my $max_depth = ( @_ ? shift : 12 );
    my $depth = ( @_ ? shift : 0 );
    my $path = ( @_ ? shift : [] );
    my $next_level = {};

    foreach my $unit (@$level){
        if($unit eq $to){
            push @$path, $unit;
            return $path;
        }
    }

    return 0 if( $depth+1 == $max_depth );
    $depth ++;

    foreach my $unit (@$level){
        push @$path, $unit;
        if(_find_path( [keys %{$units->{$unit}}], $to, $units, $max_depth, $depth, $path )){
            $depth --;
            return $path;
        }
        pop @$path;
    }

    $depth --;
    return 0;
}

sub _ol_add {
    my ($left, $right) = @_;
    my $class = ref $left;

    my $unit = $left->unit;
    $left = $left->value;
    $right = $right->value( $unit ) if blessed($right) and $right->isa($class);

    return $class->new( $left + $right, $unit );
}

sub _ol_sub {
    my ($left, $right, $reverse) = @_;
    my $class = ref $left;

    my $unit = $left->unit;
    $left = $left->value;
    $right = $right->value( $unit ) if blessed($right) and $right->isa($class);

    ($left, $right) = ($right, $left) if $reverse;

    return $class->new( $left - $right, $unit );
}

sub _ol_mult {
    my ($left, $right) = @_;
    my $class = ref $left;

    my $unit = $left->unit;
    $left = $left->value;
    $right = $right->value( $unit ) if blessed($right) and $right->isa($class);

    return $class->new( $left * $right, $unit );
}

sub _ol_div {
    my ($left, $right, $reverse) = @_;
    my $class = ref $left;

    my $unit = $left->unit;
    $left = $left->value;
    $right = $right->value( $unit ) if blessed($right) and $right->isa($class);

    ($left, $right) = ($right, $left) if $reverse;

    return $class->new( $left / $right, $unit );
}

sub _ol_str {
    my ($self) = @_;
    return $self->value;
}

1;
__END__

=head1 SUPPORT

Please submit bugs and feature requests to the
Class-Measure GitHub issue tracker:

L<https://github.com/bluefeet/Class-Measure/issues>

=head1 AUTHOR

    Aran Clary Deltac <bluefeet@gmail.com>

=head1 CONTRIBUTORS

    Roland van Ipenburg <roland@rolandvanipenburg.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

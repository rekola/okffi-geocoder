package Vector;

use strict;
use warnings;

use Carp;

sub new {
    my $invocant = shift;
    my $class = ref $invocant || $invocant;

    my ($i, $j);    
    
    if (@_ == 2) {
	if (!ref $_[0] && !ref $_[1]) {
	    ($i, $j) = @_;
	} elsif (ref $_[0] eq 'ARRAY' && ref $_[1] eq 'ARRAY') {
	    $i = $_[1][0] - $_[0][0];
	    $j = $_[1][1] - $_[0][1];
	}
    }
    
    croak "bad arguments" if !defined $i or !defined $j;
    
    my $self = [ $i, $j ];
    
    bless $self => $class;
    return $self;
}

sub add {
    my $self = shift;
    my $a = shift;
    my $v = $self->clone;
    if (!ref $a) {
	$v->[0] += $a;
	$v->[1] += $a;
    } elsif (UNIVERSAL::isa($a, "Vector")) {
	$v->[0] += $a->[0];
	$v->[1] += $a->[1];
    } else {
	croak "not implemented";
    }
}

sub cross	{ $_[0][0] * $_[1][1] - $_[0][1] * $_[1][0]; }
sub dot		{ $_[0][0] * $_[1][0] + $_[0][1] * $_[1][1]; }
sub clone	{ $_[0]->new(@$_); }
sub length	{ sqrt ($_[0][0]**2 + $_[0][1]**2); }

1;

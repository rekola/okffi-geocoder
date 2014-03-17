package JSONAPI;

use strict;
use warnings;

use JSON;

use vars qw( @ISA );
require API;
@ISA = qw( API );

sub sendError {
    my ($self, $cgi, $error_code, $error_text, $query) = @_;
    
    return $self->sendData( $cgi, { error => { error_code => $error_code, error_text => $error_text, params => $query } } );
}

sub sendOptions {
    my ($self, $cgi) = @_;
    print $cgi->header(
	'-type' => 'application/json',
	'-charset' => 'utf-8',
	'-access_control_allow_origin' => '*',
	);    
}

sub sendData {
    my ($self, $cgi, $r, $data) = @_;
    
    print STDERR "ss\n";

    binmode STDOUT, ":utf8";

    my $json = JSON->new;
    print $cgi->header(
	'-type' => 'application/json',
	'-charset' => 'utf-8',
	'-access_control_allow_origin' => '*',
	);
    print $json->pretty->encode($data);

    return 1;
}

1;

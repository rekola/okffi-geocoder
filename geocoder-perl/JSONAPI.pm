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

sub sendData {
    my ($self, $cgi, $data) = @_;
    
    my $json = JSON->new;
    print $cgi->header('application/json');
    print $json->pretty->encode($data);

    return 1;
}

1;

#!/usr/bin/perl

use strict;
use warnings;
use autodie;
use utf8;

use DBIx::Simple;
use Getopt::Long;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

main();

sub main {
    GetOptions( "user=s" => \$user,
		"password=s" => \$password,
	) or exit 1;
    my $file = shift @ARGV;
    die "no filename specified" if !defined $file;
    
    open my $fh, $file;

    my $header = <$fh>;
    chomp $header;
    $header =~ s/\r//g;
    my @header = split ',', $header;
    
    while (<$fh>) {
	s/\r//g;
	chomp;
	my @values = split ',';
	my %data;
	for (my $i = 0; $i < @values && $i < @header; $i++) {
	    $data{$header[$i]} = $values[$i];
	}
    }
    

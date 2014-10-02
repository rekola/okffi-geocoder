#!/usr/bin/perl

use strict;
use warnings;
use autodie;
use utf8;

use DBIx::Simple;
use Getopt::Long;
use Geo::Proj4;
use Data::Dumper;
use Text::CSV;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

main();

sub main {
    my ($user, $password);
    GetOptions( "user=s" => \$user,
		"password=s" => \$password,
	) or exit 1;
    my $file = shift @ARGV;
    die "no filename specified" if !defined $file;
    
    my $input_proj = Geo::Proj4->new("+proj=tmerc +lat_0=0 +lon_0=25 +k=1 +x_0=25500000 +y_0=0 +ellps=GRS80 +units=m +no_defs");
    my $output_proj = Geo::Proj4->new( proj => 'merc', ellps => 'WGS84', lon_0 => 0, x_0 => 0, y_0 => 0, k => 1, units => 'm' );
    
    # katunimi,osoitenumero,osoitenumero2,osoitekirjain,N,E,kaupunki,gatan,staden,tyyppi,tyyppi_selite

    my $db_name = 'mtk_2013';
    my $db = DBIx::Simple->connect( "DBI:mysql:database=$db_name", $user, $password, { RaiseError => 1 }) or die "connect: $@";
    $db->{lc_columns} = 0;
    $db->query(q{ SET NAMES 'utf8' });

    my $csv = Text::CSV->new or die "Cannot use CSV: ".Text::CSV->error_diag ();
    open my $fh, "<:encoding(iso8859-1)", $file;
 
    my $header = $csv->getline( $fh );
    
    my %kunta;
    while ( my $row = $csv->getline( $fh ) ) {
	my %data;
	for (my $i = 0; $i < @$row && $i < @$header; $i++) {
	    my $v = $row->[$i];
	    $v = undef if defined $v && $v =~ /^\s*$/;
	    $data{$header->[$i]} = $v;
	}

	# print STDERR Dumper(\%data);

	my $city = lc $data{kaupunki};
	my $street = lc $data{katunimi};
	my $n = $data{osoitenumero};
    	my $type = $data{tyyppi};
	
    	next if !$type || $type != 1;
    	next if !$n;

	my ($lat, $lon) = $input_proj->inverse($data{E} - 0, $data{N} - 0);
	my ($x, $y) = $output_proj->forward($lat, $lon);
    	$data{x} = $x;
    	$data{y} = $y;

	die "no position: " . Dumper(\%data) . "\n" if !defined $x || !defined $y;

    	push @{$kunta{$city}{$street}}, \%data;
    }

    my $missing_roads_count = 0;
    my $lost_numbers_count = 0;
    my $total_numbers_count = 0;

    my %target_seq;
    
    while (my ($kunta, $d1) = each %kunta) {
	while (my ($street, $rows) = each %$d1) {
	    my @obj = $db->query(q{ SELECT * FROM geocoding WHERE name = ? AND lang = 'fin' AND kunta = ? }, $street, $kunta)->hashes;
	    if (!@obj) {
		print STDERR "could not find road $kunta/$street: " . scalar(@$rows) . "\n";
		$missing_roads_count++;
		$lost_numbers_count += scalar @$rows;
		next;
	    }
	    print STDERR "handling rows for road $kunta/$street: " . scalar(@$rows) . "\n";
	    $total_numbers_count += scalar @$rows;
	    my $n = 0;
	    for my $row (sort { $a->{osoitenumero} <=> $b->{osoitenumero} } @$rows) {
		my $n = $row->{osoitenumero};
		my $rem = $n % 2;
		my ($found, $sol);
		for my $obj (@obj) {
		    if ($obj->{fromleft} && $rem == $obj->{fromleft} % 2 && $n >= $obj->{fromleft} && $n <= $obj->{toleft}) {
			$sol = 1;
			$found = $obj;
			last;
		    } elsif ($obj->{fromright} && $rem == $obj->{fromright} % 2 && $n >= $obj->{fromright} && $n <= $obj->{toright}) {
			$sol = 2;
			$found = $obj;
			last;
		    }
		}
		if (!$found) {
		    print STDERR "  * could not find road $kunta/$street/$n\n";
		    next;
		} 
		print STDERR "  * storing address $kunta/$street/$n\n";
		if (!$n) {
		    $db->begin;		    
		}
		my $seqnr = $target_seq{$found->{id}}++;
		$db->query(q{ INSERT INTO irregular_house_numbers (object_id, seqnr, n, n2, letter, g, sol) VALUES (?, ?, ?, ?, ?, GeomFromText(?), ?) }, $found->{id}, $seqnr, $n, $row->{osoitenumero2}, $row->{osoitekirjain}, 'Point(' . $row->{x} . ' ' . $row->{y} . ')', $sol);
		$n++;
	    }
	    if ($n) {
		$db->commit;
	    }
	}
    }

    print STDERR "updating flags\n";
    
    $db->begin;
    for my $id (keys %target_seq) {
	$db->query(q{ UPDATE geocoding SET has_irregular_house_numbers = 1 WHERE id = ? }, $id - 0);
    }
    $db->commit;
    
    print STDERR "missing = $missing_roads_count, lost = $lost_numbers_count / $total_numbers_count\n";
}

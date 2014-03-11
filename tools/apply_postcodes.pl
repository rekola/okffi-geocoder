#!/usr/bin/perl

use strict;
use warnings;
use autodie;

use DBIx::Simple;
use Getopt::Long;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

main();

sub main {
    my $kuntacheck;
    my $user;
    my $password;

    GetOptions( "kuntacheck" => \$kuntacheck,
		"user=s" => \$user,
		"password=s" => \$password,
	) or exit 1;
    
    my $db = open_db($user, $password);

    if ($kuntacheck) {
	my %current = map { $_->{id}, $_ } $db->query(q{ SELECT * FROM kunta })->hashes;
	my @used = $db->query(q{ SELECT DISTINCT kunta_nro FROM roads_v })->flat;
	for my $n (@used) {
	    next if !defined $n;
	    my $k = $current{$n};
	    if ($k && $k->{is_active}) {
		print STDERR "kunta $n is available as $k->{kunta_name_fin}\n";
	    } else {
		print STDERR "kunta $n is removed\n";
	    }
	}
    } else {
	my @kunta = $db->query(q{ SELECT id, kunta_name_fin, kunta_name_swe FROM kunta ORDER BY id ASC })->hashes;
	
	for my $kunta (@kunta) {
	    my @input = $db->query(q{ SELECT * FROM postcodes WHERE kunta_nro = ? }, $kunta->{id})->hashes;
	    if (!@input) {
		print STDERR "skipping kunta $kunta->{name}\n";
		next;
	    }
	    print STDERR "handling kunta $kunta->{id}/$kunta->{kunta_name_fin} (" . scalar(@input) . " roads)\n";
	    
	    my %postname_to_swe;
	    my %roads_per_name;
	    for my $row (@input) {
		my $street_name;
		if (defined $row->{street_fi}) {
		    $street_name = $row->{street_fi};
		} elsif (defined $row->{street_se}) {
		    $street_name = $row->{street_se};
		} else {
		    next;
		}
		die "no name_fi" if !defined $row->{name_fi};
		my $key = lc $street_name;
		my $postcode = $row->{postcode};
		my $postname_fi = beautify($row->{name_fi});
		my $postname_se = beautify($row->{name_se});
		
		$postname_to_swe{$postname_fi} = $postname_se if defined $postname_fi && defined $postname_se;

		my ($from, $to);
		$from = $row->{min_number1} if defined $row->{min_number1};
		$from = $row->{min_number2} if defined $row->{min_number2} && (!$from || $row->{min_number2} < $from);
		
		$to = $row->{max_number1} if defined $row->{max_number1};
		$to = $row->{max_number2} if defined $row->{max_number2} && (!$to || $row->{max_number2} > $to);
		
		die "error" if defined $from && $from <= 0;
		die "error" if defined $to && $to <= 0;
		die "error" if $from && $to && $to < $from;
		$to = $from if !$to;

		# die "error, id = $row->{id}" if ($from && !$to) || (!$from && $to);
		die "error, no numbers for row $row->{id}" if $row->{numbering_type} && (!$from || !$to);

		$row->{to} = $to;
		$row->{from} = $from;
		$row->{street} = $street_name;
		$row->{postname_fi} = $postname_fi;
		$row->{postname_se} = $postname_se;
		
		my $d = $roads_per_name{$key};
		$d = $roads_per_name{$key} = { name => $street_name, rows => [ ], postcodes => { }, postnames => { }, odd_postcodes => { }, even_postcodes => { } } if !$d;
		push @{$d->{rows}}, $row;
		$d->{postcodes}{$postcode} = 1;
		$d->{postnames}{$postname_fi} = 1;
		if ($row->{numbering_type} == 1) {
		    $d->{odd_postcodes}{$postcode} = $d->{odd_postnames}{$postname_fi} = 1;
		} elsif ($row->{numbering_type} == 2) {
		    $d->{even_postcodes}{$postcode} = $d->{even_postnames}{$postname_fi} = 1;
		} elsif ($row->{numbering_type} == 0) {
		    $d->{nan_postcodes}{$postcode} = $d->{nan_postnames}{$postname_fi} = 1;
		} else {
		    die "error";
		}
	    }
	    
	    for my $d (values %roads_per_name) {
		next if $d->{name} =~ /^PL \d+$/;
		my @roads_in_mtk = $db->query(q{ SELECT * FROM roads_v WHERE kunta_nro = ? AND teksti = ? }, $kunta->{id}, $d->{name})->hashes;
		if (!@roads_in_mtk) {
		    print STDERR "error could not find road $kunta->{id}/$d->{name}\n";
		    next;
		}
		my @all_postcodes = keys %{$d->{postcodes}};
		die "error" if !@all_postcodes;
		if (@all_postcodes == 1) {
		    my @all_postnames = keys %{$d->{postnames}};
		    die "error" if @all_postnames != 1;
		    my $postcode = $all_postcodes[0];
		    my $postname = $all_postnames[0];
		    for my $road (@roads_in_mtk) {
			if ((lc $d->{name}) ne (lc $road->{teksti})) {
			    print STDERR "name mismatch ($d->{name} != $road->{teksti})\n";
			    next;
			}
			my $postname_swe = $postname_to_swe{$postname};
			print STDERR "updating road $road->{teksti} to ($postcode $postname)\n";
			$db->query(q{ UPDATE roads_v SET postcode_left = ?, postcode_right = ?, postname_fin_left = ?, postname_fin_right = ?, postname_swe_left = ?, postname_swe_right = ? WHERE id = ? }, 
				   $postcode, $postcode, $postname, $postname, $postname_swe, $postname_swe, $road->{id});
		    }
		} else {
		    my @even_postcodes = keys %{$d->{even_postcodes}};
		    my @odd_postcodes = keys %{$d->{odd_postcodes}};
		    my @nan_postcodes = keys %{$d->{nan_postcodes}};
		    if (@even_postcodes == 1 && @odd_postcodes == 1 && !@nan_postcodes) {
			my @even_postnames = keys %{$d->{even_postnames}};
			my @odd_postnames = keys %{$d->{odd_postnames}};
			die "error" if @even_postnames != 1 && @odd_postnames != 1;
			my $even_postcode = $even_postcodes[0];
			my $odd_postcode = $odd_postcodes[0];
			my $even_postname = $even_postnames[0];
			my $odd_postname = $odd_postnames[0];
			die "error, same postcodes $even_postcode - $odd_postcode, all = " . (join ', ', @all_postcodes) if $even_postcode == $odd_postcode;
			for my $road (@roads_in_mtk) {
			    if ((lc $d->{name}) ne (lc $road->{teksti})) {
				print STDERR "name mismatch ($d->{name} != $road->{teksti})\n";
				next;
			    }
			    my ($postcode_left, $postname_left, $postcode_right, $postname_right);
			    if ($road->{fromleft}) {
				if ($road->{fromleft} % 2 == 0) {
				    $postcode_left = $even_postcode;
				    $postname_left = $even_postname;
				} else {
				    $postcode_left = $odd_postcode;
				    $postname_left = $odd_postname;
				}
			    }
			    if ($road->{fromright}) {
				if ($road->{fromright} % 2 == 0) {
				    $postcode_right = $even_postcode;
				    $postname_right = $even_postname;
				} else {
				    $postcode_right = $odd_postcode;
				    $postname_right = $odd_postname;
				}
			    }
			    if ($postcode_right && !$postcode_left) {
				$postcode_left = $postcode_right;
				$postname_left = $postname_right;
			    } elsif ($postcode_left && !$postcode_right) {
				$postcode_right = $postcode_left;
				$postname_right = $postname_left;
			    }
			    if ($postcode_left && $postcode_right) {
				print STDERR "updating road $road->{teksti} to (left: $postcode_left $postname_left, right: $postcode_right $postname_right)\n";
				my $postname_swe_left = $postname_to_swe{$postname_left};
				my $postname_swe_right = $postname_to_swe{$postname_right};
				$db->query(q{ UPDATE roads_v SET postcode_left = ?, postcode_right = ?, postname_fin_left = ?, postname_fin_right = ?, postname_swe_left = ?, postname_swe_right = ? WHERE id = ? }, 
					   $postcode_left, $postcode_right, $postname_left, $postname_right, $postname_swe_left, $postname_swe_right, $road->{id});
			    }
			}		    
		    } else {
			for my $road (@roads_in_mtk) {
			    if ((lc $d->{name}) ne (lc $road->{teksti})) {
				print STDERR "name mismatch ($d->{name} != $road->{teksti})\n";
				next;
			    }
			    my (@left_poss, @right_poss);
			    for my $row (@{$d->{rows}}) {
				die "error" if $row->{numbering_type} && (!$row->{from} || !$row->{to});
				die "error" if !defined $row->{numbering_type};
				die "error" if $road->{fromleft} && !$road->{toleft};
				die "error" if $road->{fromright} && !$road->{toright};
				die "error" if !$road->{fromleft} && $road->{toleft};
				die "error" if !$road->{fromright} && $road->{toright};
				if ($road->{fromleft} && (($road->{fromleft} % 2 == 0 && $row->{numbering_type} == 2) || ($road->{fromleft} % 2 == 1 && $row->{numbering_type} == 1)) &&
				    $row->{from} <= $road->{toleft} && $row->{to} > $road->{fromleft}) {
				    push @left_poss, $row;
				} 
				if ($road->{fromright} && (($road->{fromright} % 2 == 0 && $row->{numbering_type} == 2) || ($road->{fromright} % 2 == 1 && $row->{numbering_type} == 1)) &&
				    $row->{from} <= $road->{toright} && $row->{to} > $road->{fromright}) {
				    push @right_poss, $row;
				}
			    }
			    print STDERR "multiple left_poss for road $d->{name} (k:$kunta->{id}, " . (join ', ', map { defined $_ ? $_ : 'n/a' } ($road->{fromleft}, $road->{toleft})) . "): " . (join ' ', map { $_->{postcode} } @left_poss) . "\n" if @left_poss > 1;
			    print STDERR "multiple right_poss for road $d->{name} (k:$kunta->{id}, " . (join ', ', map { defined $_ ? $_ : 'n/a' } ($road->{fromright}, $road->{toright})) . "): " . (join ' ', map { $_->{postcode} } @right_poss) . "\n" if @right_poss > 1;
			    print STDERR "no possibilities for $d->{name} (k:$kunta->{id}, " . (join ', ', map { defined $_ ? $_ : 'n/a' } ($road->{fromleft}, $road->{toleft}, $road->{fromright}, $road->{toright})) . ")\n" if !@left_poss && !@right_poss;
			    my ($postcode_left, $postname_fin_left, $postname_swe_left, $postcode_right, $postname_fin_right, $postname_swe_right);
			    if (@left_poss >= 1) {
				$postcode_left = $left_poss[0]{postcode};
				$postname_fin_left = $left_poss[0]{postname_fi};
				$postname_swe_left = $left_poss[0]{postname_se};
			    }
			    if (@right_poss >= 1) {
				$postcode_right = $right_poss[0]{postcode};
				$postname_fin_right = $right_poss[0]{postname_fi};
				$postname_swe_right = $right_poss[0]{postname_se};
			    }
			    if ($postcode_right && !$postcode_left) {
				$postcode_left = $postcode_right;
				$postname_fin_left = $postname_fin_right;
				$postname_swe_left = $postname_swe_right;
			    } elsif ($postcode_left && !$postcode_right) {
				$postcode_right = $postcode_left;
				$postname_fin_right = $postname_fin_left;
				$postname_swe_right = $postname_swe_left;
			    }
			    if ($postcode_left && $postcode_right) {
				print STDERR "updating road $road->{teksti} to (left: $postcode_left $postname_fin_left, right: $postcode_right $postname_fin_right) MULTI\n";
				$db->query(q{ UPDATE roads_v SET postcode_left = ?, postcode_right = ?, postname_fin_left = ?, postname_fin_right = ?, postname_swe_left = ?, postname_swe_right = ? WHERE id = ? }, 
					   $postcode_left, $postcode_right, $postname_fin_left, $postname_fin_right, $postname_swe_left, $postname_swe_right, $road->{id});
			    }
			}
		    }
		}	    
	    }
	}
    }
}

sub open_db {
    my ($user, $password) = @_;
    my $dbname = 'mtk_2013';
    
    my $db = DBIx::Simple->connect( "DBI:mysql:database=$dbname", $user, $password, { RaiseError => 1 }) or die "connect: $@";
    $db->{lc_columns} = 0;
    $db->{dbh}{mysql_enable_utf8} = 1;
    $db->query(q{ SET NAMES 'utf8mb4' });
    
    return $db;
}

sub beautify {
    my $s = shift;
    return undef if !defined $s;
    if ($s =~ /-/) {
	# Vanha-ulvila
	return join '-', map { ucfirst lc $s } split '-', $s;
    } elsif ($s =~ / /) {
	# Hanko pohjoinen
	return join ' ', map { ucfirst lc $s } split ' ', $s;
    } else {
	return ucfirst lc $s;
    }
}

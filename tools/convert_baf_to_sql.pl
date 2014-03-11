#!/usr/bin/perl

use strict;
use warnings;
use autodie;
use Encode;

open my $fh, "Itella_BAF_20140201.dat";

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

print "CREATE TABLE postcodes (id INT NOT NULL PRIMARY KEY AUTO_INCREMENT, tunnus VARCHAR(255), pvm VARCHAR(8), postcode VARCHAR(5), name_fi VARCHAR(255), name_se VARCHAR(255), short_name_fi VARCHAR(255), short_name_se VARCHAR(255), street_fi VARCHAR(255), street_se VARCHAR(255), numbering_type TINYINT, min_number1 INT, min_l1 VARCHAR(4), min_p VARCHAR(4), min_number2 INT, min_l2 VARCHAR(4), max_number1 INT, max_l1 VARCHAR(4), max_p VARCHAR(4), max_number2 INT, max_l2 VARCHAR(4), kunta_nro INT, kunta_name_fi VARCHAR(255), kunta_name_se VARCHAR(255)) DEFAULT CHARSET utf8;\n";

while (<$fh>) {
    # $_ = decode 'iso8859-1', $_;
    my @values;
    if (!(@values = /^(.{5})(.{8})(.{5})(.{30})(.{30})(.{12})(.{12})(.{30})(.{30})(.{12})(.{12})(.{1})(.{5})(.{1})(.{1})(.{5})(.{1})(.{5})(.{1})(.{1})(.{5})(.{1})(.{3})(.{20})(.{20})$/)) {
	die "invalid data\n";
    }
    for my $v (@values) {
	$v =~ s/\s+$//;
	$v =~ s/^\s+//;
	if ($v =~ /\S/) {
	    $v =~ s/'/\\'/g;
	    $v = '\'' . $v . '\'';
	} else {
	    $v = 'NULL';
	}
    }
    my ($tunnus, $pvm, $postcode, $name_fi, $name_se, $short_name_fi, $short_name_se, $street_fi, $street_se, undef, undef, $numbering_type, $min_number1, $min_l1, $min_p, $min_number2, $min_l2, $max_number1, $max_l1, $max_p, $max_number2, $max_l2, $kunta_nro, $kunta_name_fi, $kunta_name_se) = @values;
    print "INSERT INTO postcodes (tunnus, pvm, postcode, name_fi, name_se, short_name_fi, short_name_se, street_fi, street_se, numbering_type, min_number1, min_l1, min_p, min_number2, min_l2, max_number1, max_l1, max_p, max_number2, max_l2, kunta_nro, kunta_name_fi, kunta_name_se) VALUES ($tunnus, $pvm, $postcode, $name_fi, $name_se, $short_name_fi, $short_name_se, $street_fi, $street_se, $numbering_type, $min_number1, $min_l1, $min_p, $min_number2, $min_l2, $max_number1, $max_l1, $max_p, $max_number2, $max_l2, $kunta_nro, $kunta_name_fi, $kunta_name_se);\n";
}

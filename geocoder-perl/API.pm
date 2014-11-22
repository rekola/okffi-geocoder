package API;

use strict;
use warnings;
use utf8;

use DBIx::Simple;
use Carp;
use Date::Calc qw(Localtime Mktime Delta_Days);
use Data::FormValidator;

use Encode;

sub new {
    my $invocant = shift;
    my $class = ref $invocant || $invocant;
    my $self = {
	locale => 'fi',
	texts => undef,
	options => { },
	cookies => [ ],
    };
    bless $self => $class;
    return $self;
}

sub instance {
    my $class = shift;
    my $pi = $class->new;

    # If the database connection is terminated, we need to reinitialize charsets
    # $Page3::db1->query(q{ SET NAMES 'utf8mb4' }) if $Page3::db1;
    # $Page3::db2->query(q{ SET NAMES 'utf8mb4' }) if $Page3::db2;

    binmode STDERR, ':utf8';
    
    return $pi;
}

sub render {
    my $self = shift;
    my $cgi = shift;
    my $r = shift;
    
    if ($ENV{REQUEST_METHOD} eq 'OPTIONS') {
	return $self->sendOptions;
    }

    # $self->{StartTime} = Time::HiRes::time;

    $self->{errortext} = undef;
    $self->{input} = undef;
    $self->{texts} = undef;

    $self->{current_path} = $cgi->url(-absolute => 1);
        
    $self->initialize($cgi);
    
    my $success = $self->validate($cgi);
    $self->load($cgi);
    
    if (!$success) {
	print STDERR "validate failed\n";
	$self->{validateFailed} = 1;
	$self->{validateOK} = 0;
    }

    return $self->renderPage($cgi, $r);
}

sub getMtkDB2 {
    my $self = shift;
    if (!$API::db4) {
	my $dbname = 'mtk_2013';
	my $user = 'gisuser';
	my $password = 'o92x3iytH';
	my $db = DBIx::Simple->connect( "DBI:mysql:database=$dbname", $user, $password, { RaiseError => 1 }) or die "connect: $@";
	$db->{lc_columns} = 0;
	$db->{dbh}{mysql_enable_utf8} = 1;
	$db->query(q{ SET NAMES 'utf8mb4' });
	$API::db4 = $db;
    }
    return $API::db4;
}

sub getMtkDB3 {
    my $self = shift;
    if (!$API::db3) {
	my $dbname = 'mtk_2013c';
	my $user = 'gisuser';
	my $password = 'o92x3iytH';
	my $db = DBIx::Simple->connect( "DBI:mysql:database=$dbname", $user, $password, { RaiseError => 1 }) or die "connect: $@";
	$db->{lc_columns} = 0;
	$db->{dbh}{mysql_enable_utf8} = 1;
	$db->query(q{ SET NAMES 'utf8mb4' });
	$API::db3 = $db;
    }
    return $API::db3;
}

sub initialize { }
sub update { return 1; }
sub load { }

sub setErrorText {
    my $self = shift;
    my $t = shift;
    return if !defined $t || !length $t;

    print STDERR "Error(page = $self->PAGE): $t\n";
    $self->{errortext} = $t;
}

sub validate {
    my $self = shift;
    my $cgi = shift;

    my $profile = $self->INPUT_PROFILE;

    if ($profile) {
        my $results = Data::FormValidator->check($cgi, $profile);
	$self->{input} = scalar $results->valid;
        my $i = $self->{input};
        for my $key (keys %$i) {
            $i->{$key} = decode 'utf8', $i->{$key} if defined $i->{$key} && !ref $i->{$key};
        }
        my %form = ( has_invalid => 0,
                     all_fields => scalar $cgi->Vars,
                     missing_fields => { },
                     invalid_fields => { },
                     other_error => { },
                     );
        $self->{form} = \%form;
        if ($results->has_invalid or $results->has_missing) {
	    print STDERR "validointi epaonnistui.\n";

            $self->{form}{has_invalid} = 1;
            $self->{form}{missing_fields} = { map {$_, 1} $results->missing };
            $self->{form}{invalid_fields} = { map {$_, 1} $results->invalid };
            print STDERR "missing: " . join(', ', $results->missing) . "\n" if $results->has_missing;
            print STDERR "unknown: " . join(', ', $results->unknown) . "\n" if $results->has_unknown;
            print STDERR "invalid:\n";
            foreach my $f ($results->invalid) {
                print STDERR "  $f -> ". join(', ', @{$results->invalid($f)}) . "\n"; # (" . $self->CGI->param($f) . ")\n";
            }
            return 0;
        }
    } else {
	# print STDERR "No input profile for page " . $self->PAGE . "\n";
        $self->{form} = { };
        $self->{input} = { };
    }
    return 1;
}

sub fetchData {
    my $self = shift;
    my ($required_type, $query, @params) = @_;
    
    my $db = $self->getMtkDB3;
    my @o = $db->query($query, @params)->hashes;
    die "query: $@" if $@;
    
    my @r;
    for my $o (@o) {
	die "no geodata" if not defined $o->{g};
	die "bad data" if $o->{g} !~ /^([A-Z]+)\((.*)\)$/;
	my ($type, $data) = ($1, $2);
	next if defined $required_type && $required_type ne $type;
	my %r = ( id => $o->{id},
		  type => $type,
		  %$o,
		  );
	if ($type eq 'LINESTRING') {
	    $r{g} = [ map { [ split / / ] } split /,/, $data ];
	} elsif ($type eq 'POLYGON') {
	    $r{g} = [ map { [ split / / ] } split /,/, substr $data, 1, -1 ];
	} else {
	    die "bad geodata";
	}

	$r{numbering} = {
	    left	=> [ $o->{fromleft}, $o->{toleft} ],
	    right	=> [ $o->{fromright}, $o->{toright} ],
	};

	push @r, \%r;
    }
    
    return @r;
}

sub getKuntaByName {
    my $self = shift;
    my $name = shift;
    my $db = $self->getMtkDB2;
    my ($kunta_nro, $actual_name) = $db->query(q{ SELECT id, kunta_name_fin FROM kunta WHERE kunta_name_fin = ? OR kunta_name_swe = ? }, $name, $name)->list;
    die "query: $@" if $@;
    return wantarray ? ($kunta_nro, $actual_name) : $kunta_nro;
}

sub getKuntaName {
    my $self = shift;
    my $kunta_nro = shift;
        
    my $db = $self->getMtkDB2;
    my $name = $db->query(q{ SELECT kunta_name_fin FROM kunta WHERE id = ? }, $kunta_nro)->list;
    
    return $name;
}

sub getBoundary {
    my $self = shift;
    my ($x, $y, $radius) = @_;

    die "x not defined" if not defined $x;
    die "y not defined" if not defined $y;
    die "radius not defined" if not defined $radius;

    my $minX = $x - $radius;
    my $minY = $y - $radius;
    my $maxX = $x + $radius;
    my $maxY = $y + $radius;
    
    return ( [$minX, $minY],
 	     [$maxX, $minY],
	     [$maxX, $maxY],
 	     [$minX, $maxY],
 	     [$minX, $minY],
 	     );    
}

sub getErrorText { $_[0]{errortext}; }
sub input { $_[0]{input}; }

sub addCookie {
    my $self = shift;
    push @{$self->{cookies}}, @_;
}

sub INPUT_PROFILE { undef; }
sub TEMPLATE_FILE { die "subclass responsibility"; }
sub TEMPLATE_DIR { die "subclass responsibility"; }
sub PAGE { die "subclass responsibility"; }
sub NAME { return undef; }
sub CATNAME { return 'default'; }
sub NEED_ADMIN { return 0; }

sub sendError { die "subclass responsibility"; }
sub sendOptions { }

use constant ALLOW_CACHE => 1;

1;

package API;

use strict;
use warnings;
use utf8;

use DBIx::Simple;
use Carp;
use Date::Calc qw(Localtime Mktime Delta_Days);
use Data::FormValidator;
use Data::Dumper;

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

    return $self->renderPage($cgi);
}
    
sub printHeader {
    my $self = shift;
    my $cgi = shift;
    
    print STDERR "cookies = " . scalar(@{$self->{cookies}}) . "\n";

    if ($self->ALLOW_CACHE) {
        print $cgi->header( -type => 'text/html',
                            -charset => 'utf-8',
			    -cookie => $self->{cookies},
                            );
    } else {
        print $cgi->header( -type => 'text/html',
                            -charset => 'utf-8',
                            -pragma => 'no-cache',
                            -expires => 'now',
			    -cookie => $self->{cookies},
                            );
    }
}

sub getMtkDB {
    my $self = shift;
    if (!$API::db3) {
	my $dbname = 'mtk_2012';
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

sub initialize { }
sub update { return 1; }
sub copyData { return 1; }
sub uploadData { return 1; }
sub deleteData { return 1; }
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

use constant ALLOW_CACHE => 1;

1;
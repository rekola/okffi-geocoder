geocoder
========

okf.fi geocoder

API Service: http://api.okf.fi/console/

Datajournalist's manual: http://books.okf.fi/geocoder/_full/

Project notes: http://pad.okfn.org/p/geocoder

Prerequisites
=============

mod_perl and the following Perl modules:

- CGI.pm
- Geo::Proj4
- Math::Trig
- MIME::Base64
- Carp
- Date::Calc
- Data::FormValidator
- DBIx::Simple
- Encode
- JSON

Modules can be installed using CPAN:

	perl -MCPAN -e shell
	cpan[1]> install DBIx::Simple

Or by installing from the package management system of your Linux distribution
There is a [nice way to find out if a Perl module is on Debian or Ubuntu.](http://deb.perl.it/ "nice way to find out if a Perl module is on Debian or Ubuntu.")

Apache and MySQL (or MariaDB) are also needed

Apache configuration
====================

Apache must be configured to use mod_perl. Here is an example
configuration, which should be added to your site configuration:

	PerlSwitches -I/var/www/okf/data/gis
	<Directory /var/www/okf/data/gis>
		SetHandler perl-script
		PerlResponseHandler ModPerl::Registry
		PerlOptions +ParseHeaders
		Options ExecCGI MultiViews Indexes FollowSymLinks MultiViews
		AllowOverride None
		Order allow,deny
		allow from all
	</Directory>

Of course, you should replace /var/www/okf/data/gis with the
installation directory.

Uploading data
==============

	cat okffi_geocoding_data.2014-10-27.sql | mysql -u USERNAME -pPASSWORD

Installation steps
==================

1. Install Apache
2. Install mod_perl and the Perl modules
3. Install MySQL
4. Configure Apache
5. Copy contents of geocoder-perl directory to the installation directory which should reside under Apache document root
6. Create the MySQL database and upload the data ([Database dump](http://data.okf.fi/dumps/okffi_geocoding_data.2014-10-27.zip "Database dump"))
7. Create a MySQL user and grant privileges. (Username and password should be written to API.pm)

# $Id: Makefile.PL,v 1.2 2001/03/11 17:17:37 barbee Exp $
require 5.004;
use strict;

$| = 1;

my $missing_modules;

print "Checking for Rcs 0.09 ..";
eval {
    require Rcs;
    Rcs->VERSION('0.09');
};

if ( $@ ) {
    print " failed\n";
    $missing_modules++;
    print <<EOT;
$@
The Rcs module is required.

EOT
} else {
    print " ok\n";
}

print "Checking for Apache 1.27 ..";
eval {
    require Apache;
    Apache->VERSION('1.27');
};

if ( $@ ) {
    print " failed\n";
    $missing_modules++;
    print <<EOT;
$@
We need the Apache modules;

EOT
} else {
    print " ok\n";
}
print <<EOT if $missing_modules;
The missing modules can be obtained from CPAN.  Visit
<URL:http://www.perl.com/CPAN/> to find a CPAN site near you.

EOT

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Apache::CVS',
    'VERSION_FROM' => 'CVS.pm', # finds $VERSION
    'PM' => {
        'CVS.pm' => '$(INST_LIBDIR)/CVS.pm',
    },
);

# $Id: Makefile.PL,v 1.3 2002/02/10 04:11:17 barbee Exp $
require 5.004;
use strict;

$| = 1;

use ExtUtils::MakeMaker;
WriteMakefile(
    NAME            => 'Apache::CVS',
    AUTHOR          => 'John Barbee <barbee@veribox.net>',
    ABSTRACT        => 'Apache method handler that displays Cvs repositories.',
    VERSION_FROM    => 'CVS.pm',
    PREREQ_PM       => {
                            'Rcs' => 1.03,
                            'Apache' => 1.27,
    },
    PM => { 'CVS.pm'           => '$(INST_LIBDIR)/CVS.pm',
            'CVS/HTML.pm'      => '$(INST_LIBDIR)/CVS/HTML.pm',
            'CVS/Diff.pm'      => '$(INST_LIBDIR)/CVS/Diff.pm',
            'CVS/File.pm'      => '$(INST_LIBDIR)/CVS/File.pm',
            'CVS/Directory.pm' => '$(INST_LIBDIR)/CVS/Directory.pm',
            'CVS/PlainFile.pm' => '$(INST_LIBDIR)/CVS/PlainFile.pm',
            'CVS/RcsConfig.pm' => '$(INST_LIBDIR)/CVS/RcsConfig.pm',
            'CVS/Revision.pm'  => '$(INST_LIBDIR)/CVS/Revision.pm',
    }
);

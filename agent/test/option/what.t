# Make sure invalid option leads to a meaningful exit status

# $Id: what.t,v 3.0 1993/11/29 13:50:22 ram Exp $
#
#  Copyright (c) 1990-1993, Raphael Manfredi
#  
#  You may redistribute only under the terms of the Artistic License,
#  as specified in the README file that comes with the distribution.
#  You may reuse parts of this distribution only within the terms of
#  that same Artistic License; a copy of which may be found at the root
#  of the source tree for mailagent 3.0.
#
# $Log: what.t,v $
# Revision 3.0  1993/11/29 13:50:22  ram
# Baseline for mailagent 3.0 netwide release.
#

do '../pl/init.pl';
`$mailagent -foo -bar 2>&1`;
$? != 0 || print "1\n";
print "0\n";

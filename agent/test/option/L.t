# -L: force logging level

# $Id: L.t,v 3.0 1993/11/29 13:50:12 ram Exp $
#
#  Copyright (c) 1990-1993, Raphael Manfredi
#  
#  You may redistribute only under the terms of the Artistic License,
#  as specified in the README file that comes with the distribution.
#  You may reuse parts of this distribution only within the terms of
#  that same Artistic License; a copy of which may be found at the root
#  of the source tree for mailagent 3.0.
#
# $Log: L.t,v $
# Revision 3.0  1993/11/29  13:50:12  ram
# Baseline for mailagent 3.0 netwide release.
#

do '../pl/init.pl';
chdir '../out';
unlink 'agentlog';
`$mailagent -L 0 -d 2>/dev/null`;
$? == 0 || print "1\n";
-f 'agentlog' && print "2\n";
print "0\n";

# Test FEED command

# $Id: feed.t,v 3.0 1993/11/29 13:49:31 ram Exp $
#
#  Copyright (c) 1990-1993, Raphael Manfredi
#  
#  You may redistribute only under the terms of the Artistic License,
#  as specified in the README file that comes with the distribution.
#  You may reuse parts of this distribution only within the terms of
#  that same Artistic License; a copy of which may be found at the root
#  of the source tree for mailagent 3.0.
#
# $Log: feed.t,v $
# Revision 3.0  1993/11/29 13:49:31  ram
# Baseline for mailagent 3.0 netwide release.
#

do '../pl/cmd.pl';
unlink 'ok', 'no_resync';

&add_header('X-Tag: feed');
`$cmd`;
$? == 0 || print "1\n";
-f "$user" && print "2\n";		# Mail saved...
-f 'ok' || print "3\n";			# ...here
&get_log(4, 'ok');
&not_log('^To:', 5);			# Make sure To: disappeared
-f 'no_resync' || print "6\n";	# Ensure header not disturbed

unlink 'ok', 'no_resync', 'mail';
print "0\n";

# Test BOUNCE command

# $Id: bounce.t,v 3.0 1993/11/29 13:49:29 ram Exp $
#
#  Copyright (c) 1990-1993, Raphael Manfredi
#  
#  You may redistribute only under the terms of the Artistic License,
#  as specified in the README file that comes with the distribution.
#  You may reuse parts of this distribution only within the terms of
#  that same Artistic License; a copy of which may be found at the root
#  of the source tree for mailagent 3.0.
#
# $Log: bounce.t,v $
# Revision 3.0  1993/11/29 13:49:29  ram
# Baseline for mailagent 3.0 netwide release.
#

do '../pl/cmd.pl';
do '../pl/mta.pl';

&add_header('X-Tag: bounce 1');
`$cmd`;
$? == 0 || print "1\n";
-f "$user" && print "2\n";		# Mail not saved
&get_log(4, 'send.mail');
&not_log('^Resent-', 5);		# Bounce does not add any Resent- headers
&check_log('^To: ram', 6) == 1 || print "7\n";

open(LIST, '>list') || print "8\n";
print LIST <<EOM;
first
# comment
second
third
EOM
close LIST;

&replace_header('X-Tag: bounce 2');
unlink 'send.mail';
`$cmd`;
$? == 0 || print "9\n";
-f "$user" && print "10\n";		# Mail not saved
&get_log(11, 'send.mail');
&not_log('^Resent-', 12);		# Bounce does not add any Resent- headers
&check_log('^To: ram', 13) == 1 || print "14\n";
&check_log('^Recipients: first second third$', 15) == 1 || print "16\n";

&clear_mta;
unlink 'mail', 'list';
print "0\n";

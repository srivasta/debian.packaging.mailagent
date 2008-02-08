;# $Id: biff.pl 1 2006-08-24 13:24:12Z rmanfredi $
;#
;#  Copyright (c) 1990-2006, Raphael Manfredi
;#  
;#  You may redistribute only under the terms of the Artistic License,
;#  as specified in the README file that comes with the distribution.
;#  You may reuse parts of this distribution only within the terms of
;#  that same Artistic License; a copy of which may be found at the root
;#  of the source tree for mailagent 3.0.
;#
;# $Log: biff.pl,v $
;# Revision 3.0.1.5  2001/01/10 16:53:13  ram
;# patch69: added support for news article biffing
;#
;# Revision 3.0.1.4  1996/12/24  14:48:03  ram
;# patch45: long header lines are now trimmed to 79 chars max
;#
;# Revision 3.0.1.3  1995/08/07  16:17:42  ram
;# patch37: added support for biffing regression testing
;# patch37: new biffing features for compact biff messages and trimming
;#
;# Revision 3.0.1.2  1995/01/25  15:20:17  ram
;# patch27: new macro %a for variable bells, under the control of BEEP
;#
;# Revision 3.0.1.1  1994/10/29  17:45:45  ram
;# patch20: created
;#
;# 
;# Handles biffing when mail is received, just like the standard unix comsat
;# service. Currently, it is not possible to request biffing on a remote host,
;# unfortunately.
;#
;# [Why? Because the standard unix comsat format only supports biffing on the
;# system mailbox, and mailagent usually does not deliver there.  Having a
;# mailagent-specific daemon on another host is not easy to set-up, and that
;# daemon is vaporware today anyway].
;#
;# This package relies on pl/utmp/utmp.pl.
#
# Local biff support
#

# Perform biffing, given the folder where delivery was made print out a
# biff-like message on each of the user's terminal where a 'biff y' command
# was issued to effectively request biffing (i.e. on ttys where the 'x' bit
# was set).
sub biff {
	local($folder, $type) = @_;
	local(@ttys) = &utmp'ttys($cf'user);
	@ttys = <tty*> if $test_mode;	# For regression tests
	&add_log("$cf'user is logged on @ttys") if $loglvl > 15;
	my %done;						# Solaris might give same tty twice
	foreach $tty (@ttys) {
		&biff'notify($tty, $folder, $type) unless $done{$tty};
	}
}

package biff;

# This is the real notifier routine. When reached, we know we have to attempt
# biffing on the specified tty if its 'x' bit is set. Mail biffing is
# controlled by some config variables.
sub notify {
	local($tty, $path, $type) = @_;
	$tty = "/dev/$tty" unless $'test_mode;	# Re-anchor name in file system
	return unless -x $tty;		# Return if no biffing wanted on that tty

	&'add_log("biffing $cf'user on $tty") if $'loglvl > 8;

	local($folder) = &'tilda($path);	# Replace home directory with a ~
	local($n) = "\n\r";					# Use \r in case tty is in raw mode

	unless (open(TTY, ">$tty")) {
		&'add_log("ERROR cannot open $tty: $!") if $'loglvl;
		&'add_log("WARNING unable to biff for $folder ($type)") if $'loglvl > 5;
		return;
	}

	# Headers to print are in 'biffhead', or default to the following list
	# We set it now so that it can be seen by both &headers and &all
	# Don't show "To" or "Cc" if biffing for a news article

	local(@head) = ('From', 'To', 'Subject', 'Date');
	@head = split(/,\s*/, $cf'biffhead) if defined $cf'biffhead;
	@head = grep(!/^(To|Cc)$/, @head) if $type eq "news";

	# Set proper 'mtype' parameter, used by the biffing %t macro.
	local($mtype) = $type eq "news" ? "article" : "mail";

	# If the 'biffmsg' parameter is defined, then this file defines the
	# biffing format to be used. Otherwise, a default hardwired format is
	# used.

	local($msg);
	($msg = $env'biffmsg) =~ s/~/$cf'home/ if defined $env'biffmsg;
	if (defined $msg) {
		&custom($msg, $type);	# Customized message
	} else {
		&default;				# Default message
	}

	close TTY;
}

# Customized biffing
sub custom {
	local($format, $type) = @_;
	unless (open(FORMAT, $format)) {
		&'add_log("ERROR cannot open biff format $format: $!") if $'loglvl > 1;
		&default;		# Use default format then
		return;
	}

	# Declare all the possible locals for type-specific folder macros, so
	# that &macros_subst() may see them anyway.
	local($dir);			# Parent directory
	local($base);			# Base name, "number" for MH and dir
	local($fbase);			# Base under folder directory for type, or $path
	local($fpath);			# Folder path (one above for MH and dir folders)
	local($plus) = '';		# A '+' character if MH folder, nothing otherwise
	local($folddir);		# Folder directory

	if ($type eq 'news') {
		($dir, $base) = ('', $folder);
	} else {
		($dir, $base) = $folder =~ m|^(.*)/(.*)|;
	}

	# Add distinct macros for each kind of folder: file, dir, MH or news.
	if ($type eq 'MH' || $type eq 'dir') {
		($dir, $base) = $path =~ m|^(.*)/(.*)|;
		$fpath = $dir;		# Last component is a message "number"
	} else {
		$fpath = $path;
	}

	if ($type eq 'MH') {
		&mh'profile;		# Read MH profile if not already done
		$folddir = "$cf'home/$mh'Profile{'path'}";
		$plus = '+';
	} elsif ($type eq 'news') {
		$folddir = '';
		$fbase = $fpath;
	} else {
		$folddir = $'XENV{'maildir'};		# Folder directory location
		$folddir =~ s/~/$cf'home/g;			# ~ substitytion
		$folddir = "$cf'home/Mail" unless $folddir;	# Default folders in ~/Mail
	}

	if ($type ne 'news') {
		local($foldmatch);
		($foldmatch = $folddir) =~ s/(\W)/\\$1/g;	# Quote meta-characters
		($fbase = $fpath) =~ s|^$foldmatch/||;
	}

	# Lastly, using %:l gets the standard %l. This requires knowing about
	# &macros_subst() internals for substition (% replaced by ^B!).
	&macro'overload(<<'EOM');	# Install customized set
a	&biff'beep		e
b	\07
d	$biff'folddir
f	$biff'folder
m	$biff'plus
p	$biff'path
t	$biff'mtype
B	$biff'fbase
D	$biff'dir
F	$biff'base
P	$biff'fpath
-A	&biff'all		e
-H	&biff'headers	e
-B	&biff'body(0)	e
-T	&biff'body(1)	e
:	\02!
EOM
	local($_);
	while (<FORMAT>) {
		chop;
		print TTY &'macros_subst(*_), $n;
	}
	close FORMAT;
	&macro'unload;			# Release customized macros
}

# Routine for %a substitution in biff templates
# Value of $env'beep is set by the BEEP command (default is 1).
sub beep { "\07" x $env'beep; }

# Default biffing
sub default {
	print TTY "$n\07New $mtype for $cf'user has arrived in $folder:$n";
	print TTY "----$n";
	print TTY &all;
	print TTY "$n----\07$n";
}

# The %-A biffing macro returns header and body, separated by a blank line
sub all {
	local($res) = &headers;
	# Note: we don't care whether headers were effectively printed: as long
	# as there is something in @head, we print a newline, thereby indicating
	# to the user his variable was taken into account, but the header was
	# really missing.
	$res .= $n if @head;
	$res .= $n . &body(0);	# No final \n\r for macro substitution
	$res;
}

# Returns mail headers defined in @head, on the opened TTY
# If the header length is greater than 79 characters, it is trimmed at 76 and
# three dots '...' are emitted to show something was truncated.
# Also known as the %-H macro
sub headers {
	local($res) = '';
	foreach $head (@head) {
		next unless defined $'Header{$head};
		local($line) = "$head: $'Header{$head}";
		$line = substr($line, 0, 76) . '...' if length($line) >= 80;
		$res .= "$line$n";
	}
	chop($res);			# Remove final \n\r for macro substitution
	chop($res);
	$res;
}

# Print first $cf'bifflines lines or $cf'bifflen charaters, whichever
# comes first. Assumes TTY already opened correctly
# Also known as the %-B macro if called body(0), or %-T if called body(1).
sub body {
	local($trim) = @_;			# Whether top reply text should be trimmed
	local($len) = defined $cf'bifflen ? $cf'bifflen : 560;
	local($lines) = defined $cf'bifflines ? $cf'bifflines : 7;
	local(@body) = split(/\n/, $'Header{'Body'});
	local($skipnl) = $cf'biffnl =~ /OFF/i;	# Skip blank lines?
	local($_);
	local($res) = '';

	# Setting bifflen or bifflines to 0 means no body
	return '' if $len == 0 || $lines == 0;

	&trim(*body) if $trim;		# Smart trim of leading reply text
	&mh(*body, $len) if $cf'biffmh =~ /^on/i;

	while ($len > 0 && $lines > 0 && defined ($_ = shift(@body))) {
		next if /^\W*$/ && $skipnl;
		# Check for overflow, in case we use mh-style biffing and no
		# reformatting occurred: we may be facing a huge string!
		if (length($_) > $len) {
			$res .= substr($_, 0, $len) . $n;
		} else {
			$res .= $_ . $n;
		}
		$len -= length($_);		# Nobody will quibble over missing newline...
		$lines--;
	}
	$res .= "...more...$n" if @body > 0 || $len < 0;
	chop($res);					# Remove final \n\r for macro substitution
	chop($res);
	$res;
}

# Trim out leading reply text held in array of lines, with in-place updating.
# The purpose is to remove from the biffing text all the leading lines
# beginning with the same single non-alphanumeric character. To allow citation
# notification such as "Quoting John Doe:", the leading line is skipped when
# the next line starts with a non-alphanumeric character.
# Removed text is replaced by something like '[trimmed 20 lines]'.
# The purpose is to convey as much useful information as possible in the
# limited biffing space.
# NOTE: This routine does not understand a marginal form of quoting whereby
# the name or login of the quoted person is inserted before the quote character,
# such as "ram> this is quoted material from ram".
sub trim {
	local(*ary) = @_;			# Array of lines
	local($first_line) = 1;		# False when leading non-blank line found
	local($quote_char) = '';	# Quotation character
	local($i);

	# First, locate index of first non-blank line
	for ($i = 0; $i < @ary; $i++) {
		last if $ary[$i] !~ /^\s*$/;
	}

	# Now look for a quotation character. If on the first line, allow a
	# one-line look-ahead to skip the (assumed to be) attribution line.
	local($_);
	local($quote);			# Attrib line index, valid iff $first_line == 0
	for (; $i < @ary; $i++) {
		$_ = $ary[$i];
		next if /^\s*$/;			# Allow arbitrary amount of blank lines
		if (/^(\W)/) {
			$quote_char = $1;
			last;
		}
		last unless $first_line;	# Skip first line
		$first_line = 0;
		$quote = $i;				# Save attribution line position in array
	}

	# At this point, either we have found a citation notification and the
	# used quotation character is in $quote_char, or nothing has been found
	# and we can return: no trimming was possible.

	return unless $quote_char;

	# Starting from the current index (pointing to the beginning of the
	# quoting), scan forward and discard all the following lines starting
	# with this quoting character.

	local($start) = $i;			# Save index where '[trimmed...]' will appear

	# Go to the end of the quotation, skipping interleaved blank lines
	for ($i++; $i < @ary; $i++) {
		$_ = $ary[$i];
		if (substr($_, 0, 1) ne $quote_char) {
			last unless /^\s*$/;	# End of quotation if non-blank line
			last if $i == @ary;		# End if reached last line in the body
			$_ = $ary[$i+1];		# Look ahead...
			next if /^\s*$/;		# Another blank line following...
			last unless substr($_, 0, 1) eq $quote_char;
		}
	}

	# Now $i points to the first line not being part of the initial quotation.
	# Therefore, we may splice it out of the array altogether.
	# Leave it alone if the length of the whole quotation is less than a
	# configurable amount (a single line by default).

	local($amount) = $i - $start;
	return if $amount < (defined $cf'bifftrlen ? $cf'bifftrlen : 2);

	# Under normal conditions, the first trimmed line is replaced by a
	# message stating that some lines have been trimmed off. But if bifftrim
	# is turned to OFF, then no trimming notification is given, automatically
	# turning off biffquote.

	local($trim_quote) = $cf'biffquote =~ /^off/i;	# Trim attribution line?

	if ($cf'bifftrim =~ /^off/i) {
		$start--;			# Shift up so that the first line be skipped
		$amount++;
		$trim_quote = 1;	# Automatically turn off biffquote...
	} else {
		$ary[$start] = "\[trimmed $amount line" . ($amount == 1 ? '' : 's') .
			" starting with a leading '$quote_char' character";
		$ary[$start] .= " & attribution line"
			if $first_line == 0 && $trim_quote;
		$ary[$start] .= "\]";
	}

	# Now perform the whole quotation trimming. The starting index is set to
	# '$start + 1' to skip the [trimmed...] message. The $start variable has
	# been previously decremented if that message is not meant to appear!

	splice(@ary, $start + 1, $amount - 1) if $amount > 1;

	# The attribution line is removed if biffquote is OFF; we know it is
	# present when $first_line has been reset to 0 above. Must be done after
	# the previous splice since the attribution line comes before the quotation
	# and offsets would be mangled when the line is removed!

	splice(@ary, $quote, 1) if $first_line == 0 && $trim_quote;
}

# Produces an mh-style biffing string by removing all new-lines in the string,
# replacing them by spaces, and collading every consecutive spaces into one.
# Actually, it takes an array glob containing the body line by line, and it
# produces a single string, as big as the maximum biffing lenght states,
# splicing the array to replace its first line with the produced string and
# removing those lines that were used to make that string.
sub mh {
	local(*ary, $len) = @_;		# Body array, maximum biffing length
	local($line) = '';			# Compacted body output
	local($i);
	local($_);
	for ($i = 0; $i < @ary && $len > 0; $i++, $len -= length($_)) {
		$_ = $ary[$i];
		if (/^\s*$/) {			# Blank line
			$_ = '';			# Ignore it, and do not count it
			next;
		}
		tr/ \t/  /s;			# Strip consecutive tabs/spaces
		s/^\s//;				# Strip leading space
		s/\s$//;				# Strip trailing space
		$line .= $_ . ' ';
	}
	chop($line);				# Remove trailing extra space
	$ary[0] = $line;			# Replace first body line with compacted string

	# We stopped compating at index $i - 1, and indices start at 0. This means
	# lines in the range [0, $i-1] are now all stored as $ary[0], and lines
	# from [1, $i-1] must be removed from the array ($i-1 lines).

	splice(@ary, 1, $i - 1);	# Remove lines that are now part of $ary[0]

	# Now optionally reformat the first line so that it fits into 80 columns.
	# The line is formatted into an array, and that array is spliced back
	# into @ary.

	return unless $cf'biffnice =~ /^on/i;
	local(@tmp);
	&format($line, *tmp);		# Format line into @tmp
	splice(@ary, 0, 1, @tmp);	# Insert formatted string back
}


# Format body to fit into 78 columns by inserting the generated lines in an
# array, one line per item.
sub format {
	local($body, *ary) = @_;	# Body to be formatted, array for result
	local($tmp);				# Buffer for temporary formatting
	local($kept);				# Length of current line
	local($len) = 79;			# Amount of characters kept
	# Format body, separating lines on [;,:.?!] or space.
	while (length($body) > $len) {
		$tmp = substr($body, 0, $len);		# Keep first $len chars
		$tmp =~ s/^(.*)([;,:.?!\s]).*/$1$2/;# Cut at last space or punctuation
		$kept = length($tmp);				# Amount of chars we kept
		$tmp =~ s/\s*$//;					# Remove trailing spaces
		$tmp =~ s/^\s*//;					# Remove leading spaces
		push(@ary, $tmp);					# Create a new line
		$body = substr($body, $kept, 9999);
	}
	push(@ary, $body);			# Remaining information on one line
}

package main;


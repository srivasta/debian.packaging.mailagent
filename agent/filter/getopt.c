/*
 * getopt.C -- A getopt implementation.
 */

/*
 * $Id: getopt.c 1 2006-08-24 13:24:12Z rmanfredi $
 *
 *  Copyright (c) 1990-2006, Raphael Manfredi
 *  
 *  You may redistribute only under the terms of the Artistic License,
 *  as specified in the README file that comes with the distribution.
 *  You may reuse parts of this distribution only within the terms of
 *  that same Artistic License; a copy of which may be found at the root
 *  of the source tree for mailagent 3.0.
 *
 * Original Author: unknown, got this off net.sources
 *
 * $Log: getopt.c,v $
 * Revision 3.0.1.2  1999/07/12  13:43:07  ram
 * patch66: was missing a trailing colon in getopt() declaration
 *
 * Revision 3.0.1.1  1997/02/20  11:34:56  ram
 * patch55: created
 *
 * Revision 3.0.1.1  1994/01/24  13:58:40  ram
 * patch16: created
 *
 */

#include "config.h"

#ifndef HAS_GETOPT

#include <stdio.h>

#ifdef I_STRING
#include <string.h>
#else
#include <strings.h>
#endif

#include "confmagic.h"		/* Remove if not metaconfig -M */

/*
 * Get option letter from argument vector
 */

int	opterr = 1,		/* Useless, never set or used */
	optind = 1,		/* Index into parent argv vector */
	optopt;			/* Character checked for validity */
char *optarg;		/* Argument associated with option */

#define BADCH	(int) '?'
#define EMSG	""

#define tell(s)				\
do {						\
	fputs(*nargv, stderr);	\
	fputs(s, stderr);		\
	fputc(optopt, stderr);	\
	fputc('\n', stderr);	\
	return BADCH;			\
} while (0)

/*
 * getopt
 *
 * Parses command line flags and arguments. Given the original arguments
 * via the (nargc, nargv) tuple, and a list of flags via 'ostr', it returns
 * the next flag recognized, and sets the externally visible 'optarg'
 * variable to point to the start of the flags's parameter, if any expected.
 *
 * When facing an invalid flag, getopt() returns '?'.
 *
 * The 'ostr' string is a list of allowed flag characters, optionally by ':'
 * when the flag expects a parameter, which can immediately follow the
 * flag or come as the next word.
 *
 * In any case, the 'optopt' variable is set upon return to the flag being
 * looked at, whether it was a valid flag or not.
 */
V_FUNC(int getopt, (nargc, nargv, ostr),
	int	nargc		/* Argument count */ NXT_ARG
	char **nargv	/* Argument vector */ NXT_ARG
	char *ostr		/* String specifying options */)
{
	static char *place = EMSG;	/* Option letter processing */
	register1 char *oli;		/* Option letter list index */

	/*
	 * Update scanning pointer.
	 */

	if (!*place) {
		if(
			optind >= nargc ||
			*(place = nargv[optind]) != '-' ||
			!*++place
		)
			return EOF;
		if (*place == '-') {	/* Found "--", end option processing */
			++optind;
			return EOF;
		}
	}

	/*
	 * Is option letter OK?
	 */

	if (
		(optopt = (int)*place++) == (int)':' ||
		!(oli = index(ostr,optopt))
	) {
		if (!*place) ++optind;
		tell(": illegal option -- ");
	}

	/*
	 * Found a valid option, process it.
	 */

	if (*++oli != ':') {			/* Don't need argument */
		optarg = NULL;
		if (!*place) ++optind;
	} else {							/* Need an argument */
		if (*place) optarg = place;		/* No white space */
		else if (nargc <= ++optind) {	/* No argument */
			place = EMSG;
			tell(": option requires an argument -- ");
		} else
			optarg = nargv[optind];		/* White space */
		place = EMSG;
		++optind;
	}

	return optopt;			/* Dump back option letter */
}
#else
int getopt_variable_not_used = 1;	/* Avoid "empty file" */
#endif	/* HAS_GETOPT */


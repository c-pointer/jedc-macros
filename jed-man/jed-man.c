/*
 *	jed-man {-a | [-r] {-s|-d} pattern} [-m]
 *
 *	JED/SLang command-line help utility using jed/slang tm files
 * 
 *	Copyright (C) 2022 Free Software Foundation, Inc.
 *
 *	This is free software: you can redistribute it and/or modify it under
 *	the terms of the GNU General Public License as published by the
 *	Free Software Foundation, either version 3 of the License, or (at your
 *	option) any later version.
 *
 *	It is distributed in the hope that it will be useful, but WITHOUT ANY
 *	WARRANTY; without even the implied warranty of MERCHANTABILITY or
 *	FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 *	for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with it. If not, see <http://www.gnu.org/licenses/>.
 *
 * 	Written by Nicholas Christopoulos <nereus@freemail.gr>
 */

#include <stdint.h>
#include <stdbool.h>
#include <limits.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <errno.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#include <fnmatch.h>
#include <regex.h>
#include "panic.h"

#define	TEXT_MAX	0x10000	// enough size for any section text, LINE_MAX is also good but for any case...

// === globals ==============================================================

static int cache_vers = 0x10008;
static char	cache_file[PATH_MAX];
static char	rc_file[PATH_MAX];

// help files paths
static char **help_files_path = NULL;
static int	 help_files_path_count = 0;

// help files
#define HELP_FILES_ALLOC	128
static char **help_files = NULL;
static int	help_files_count = 0;

// Node per element. Name can be NULL; in that case skip it.
typedef struct node_s {
	char *name;			// search name, or just the name
	char *function;		// if function, use this, and make a copy to 'name'
	char *variable;		// if variable, use this, and make a copy to 'name'
	char *datatype;		// if datatype, use this, and make a copy to 'name'

	char *source;		// source file (*.tm)
	int32_t	line;		// line in source file where the block begins

	// other sections, NULL = no text on this section
	char *synopsis;
	char *usage;
	char *altusage;
	char *description;
	char *notes;
	char *example;
	char *see_also;
	char *qualifiers;

	// next pointer to the list
	struct node_s *next;
	} node_t;

// list data
node_t	*head = NULL, *tail = NULL;
node_t	**node_index = NULL;
int32_t node_count = 0;

// application options that are used globaly
bool	opt_rof = false;	// true if output in groff

// === configuration ========================================================

// config-file table of variables
typedef struct { const char *name; char *value; } var_t;
var_t var_table[] = {
	{ "cache-file", cache_file },
	{ NULL, NULL } }; // end-of-list mark

//
void add_help_files_path(const char *arg_s) {
	help_files_path = (char **) realloc(help_files_path, sizeof(char*) * (help_files_path_count + 1));
	help_files_path[help_files_path_count ++] = strdup(arg_s);
	}

// config-files table of procedures
typedef struct { const char *name; void (*func_p)(const char *); } cmd_t;
cmd_t cmd_table[] = {
	{ "add-source-path", add_help_files_path },
	{ NULL, NULL } }; // end-of-list mark

//
char *expand_env(const char *src) {
	const char *p = src;
	char	result[TEXT_MAX], *r;
	char	name[TEXT_MAX], *n, *v;
	unsigned int c, z;

	r = result;
	while ( *p ) {
		c = p[1];
		if ( *p == '\\' ) {
			switch ( c ) {
			case 'a': c = '\007'; break;	case 'b': c = '\b'; break;
			case 'n': c = '\n'; break;		case 'r': c = '\r'; break;
			case 't': c = '\t'; break;		case 'v': c = '\v'; break;
			case 'f': c = '\f'; break;		case 'e': c = '\033'; break;
			case '0': case '1': case '2': case '3': case '4': case '5': case '6': case '7':
						  z  = ((c >= '0' && c <= '7')? c-'0' : 0) << 6;
				c = p[2]; z |= ((c >= '0' && c <= '7')? c-'0' : 0) << 3;
				c = p[3]; z |= ((c >= '0' && c <= '7')? c-'0' : 0);
				c = z; p += 2;
				break;
			case 'x':
				c = p[2]; z  = (isdigit(c))?c-'0':((isxdigit(c))? 10+(toupper(c)-'A'):0) << 4;
				c = p[3]; z |= (isdigit(c))?c-'0':((isxdigit(c))? 10+(toupper(c)-'A'):0);
				c = z; p += 2;
				break;
				}
			*r ++ = c;
			p += 2;
			continue;
			}
		if ( *p == '~' ) {
			if ( (v = getenv("HOME")) != NULL )
				while ( *v ) *r ++ = *v ++;
			p ++;
			continue;
			}
		if ( *p == '$' && (isalpha(c) || c == '{' || c == '(') ) {
			p ++;
			n = name;
			if ( *p == '{' ) {
				p ++;
				while ( *p && *p != '}' ) *n ++ = *p ++;
				*n = '\0'; if ( *p == '}' ) p ++;
				if ( (v = getenv(name)) != NULL )
					while ( *v ) *r ++ = *v ++;
				}
			else if ( *p == '(' ) {
				p ++;
				while ( *p && *p != ')' ) *n ++ = *p ++;
				*n = '\0'; if ( *p == ')' ) p ++;
				*r = '\0';
				FILE *fp = popen(name, "r");
				if ( fp ) {
					char buf[LINE_MAX];
					while ( fgets(buf, LINE_MAX, fp) ) {
						strcat(r, buf);
						r += strlen(buf);
						}
					pclose(fp);
					}
				}
			else {
				while ( *p && isalnum(*p) ) *n ++ = *p ++;
				*n = '\0';
				if ( (v = getenv(name)) != NULL )
					while ( *v ) *r ++ = *v ++;
				}
			continue;
			}
		*r ++ = *p ++;
		}
	*r = '\0';
	return strdup(result);
	}

// assign variables
void conf_set(int line, const char *variable, const char *value) {
	for ( int i = 0; var_table[i].name; i ++ ) {
		if ( strcmp(var_table[i].name, variable) == 0 ) {
			char *s = expand_env(value);
			strcpy(var_table[i].value, s);
			free(s);
			return;
			}
		}
	fprintf(stderr, "rc(%d): uknown variable [%s]\n", line, variable);
	}

// execute commands
void conf_exec(int line, const char *command, const char *parameters) {
	for ( int i = 0; cmd_table[i].name; i ++ ) {
		if ( strcmp(cmd_table[i].name, command) == 0 ) {
			if ( cmd_table[i].func_p ) {
				char *s = expand_env(parameters);
				cmd_table[i].func_p(s);
				free(s);
				}
			return;
			}
		}
	fprintf(stderr, "rc(%d): uknown command [%s]\n", line, command);
	}

// parse string line
void conf_parse(int line, const char *source) {
	char name[LINE_MAX], *d = name;
	const char *p = source;
	while ( isblank(*p) ) p ++;
	if ( *p && *p != '#' ) {
		while ( *p == '_' || *p == '-' || isalnum(*p) )
			*d ++ = *p ++;
		*d = '\0';
		while ( isblank(*p) ) p ++;
		if ( *p == '=' ) {
			p ++;
			while ( isblank(*p) ) p ++;
			// if you width replace environment variables here
			conf_set(line, name, p);
			}
		else
			// if you width replace environment variables here
			conf_exec(line, name, p);
		}
	}

// read configuration file
void read_conf(const char *rc) {
	int line = 0, n;
	
	if ( access(rc, R_OK) == 0 ) {
		char buf[LINE_MAX];
		// read .rc
		FILE *fp = fopen(rc, "r");
		if ( fp ) {
			while ( fgets(buf, LINE_MAX, fp) ) {
				n = strlen(buf);
				while ( n > 0 ) { 
					n --;
					if ( isspace(buf[n]) ) buf[n] = '\0'; else break;
					}
				line ++;
				conf_parse(line, buf);
				}
			fclose(fp);
			}
		}
	}

// === text format ==========================================================

// commands inside the text 
typedef struct sldoc_macro_s {
	const char *cmd;				// command name
	const char *op, *cl;			// default (terminal) open / close strings
	const char *rof_op, *rof_cl;	// groff open / close strings
	} sldoc_macro_t;

#define	__fB "\033[1;37m"
#define	__fI "\033[4m"
#define __fR "\033[0m"

// S-Lang documentation styling commands
sldoc_macro_t sm_cmds[] = { \
	{ "strong",__fB, __fR, "\\fB", "\\fR" },
	{ "em",    __fI, __fR, "\\fI", "\\fR" },
	{ "kw",    __fB, __fR, "\\fB", "\\fR" },
	{ "grp",   __fI, __fR, "\\fI", "\\fR" },
	{ "ifun",  __fB, __fR, "\\fB", "\\fR" },
	{ "sfun",  __fB, __fR, "\\fB", "\\fR" },
	{ "cfun",  __fB, __fR, "\\fB", "\\fR" },
	{ "icon",  __fB, __fR, "\\fB", "\\fR" },
	{ "exc",   __fB, __fR, "\\fB", "\\fR" },
	{ "exns",  __fB, __fR, "\\fB", "\\fR" },
	{ "var",   "‹"__fI, __fR"›", "‹\\fI", "\\fR›" },
	{ "ivar",  "‹"__fI, __fR"›", "‹\\fI", "\\fR›" },
	{ "cvar",  "‹"__fI, __fR"›", "‹\\fI", "\\fR›" },
	{ "svar",  "‹"__fI, __fR"›", "‹\\fI", "\\fR›" },
	{ "ctype", __fB, __fR, "\\fB", "\\fR" },
	{ "dtype", __fB, __fR, "\\fB", "\\fR" },
	{ "module",__fB, __fR, "\\fB", "\\fR" },
	{ "env",   "${", "}",  "${\\fI", "\\fR}" },
	{ "math",  "$$ ", " $$", "$$ ", " $$" },
	{ "url",   "<", ">", "\n.UR ", "\n.UE\n" },
	{ "verb",  "‘", "’", "\\(oq", "\\(cq" },
	{ "code",  "‘", "’", "\\(oq", "\\(cq" },
	{ "exmp",  "‘", "’", "\\(oq", "\\(cq" },
	{ "file",  "‘", "’", "\\(oq", "\\(cq" },
	{ "exfile","‘", "’", "\\(oq", "\\(cq" },
	{ "key",   "‘", "’", "\\(oq", "\\(cq" },
	{ "kbd",   "‘", "’", "\\(oq", "\\(cq" },
	{ "NULL",  "‘", "’", "\\fI", "\\fR" },
	{ "exstr", "“", "”", "\\(lq", "\\(rq" },
	{ "ldots", "…", "", "…", "" },
	{ "times", "✕", "", "✕", "" },
	{ NULL, NULL, NULL, NULL, NULL } };
#undef __fI
#undef __fB
#undef __fR

void intext_command(const char *cmd, char *str_open, char *str_close) {
	int i;
	sldoc_macro_t *m;
	for ( i = 0, m = &sm_cmds[i]; (m = &sm_cmds[i]) != NULL && m->cmd != NULL; i ++ ) {
		if ( strcmp(cmd, m->cmd) == 0 ) {
			if ( opt_rof ) {
				strcpy(str_open,  m->rof_op);
				strcpy(str_close, m->rof_cl);
				}
			else {
				strcpy(str_open,  m->op);
				strcpy(str_close, m->cl);
				}
			return;
			}
		}
	str_open[0] = str_close[0] = '\0';
	fprintf(stderr, "'%s' not found!\n", cmd);
	}

// squeeze and duplicate
#define d_copy(s) { if ( *s ) { char *p = s; while ( *p ) *d ++ = *p ++; } }
char *sqzdup(const char *src) {
	const char *p = src;
	char *dest = (char *) malloc(TEXT_MAX);
	char *d = dest, *c;
	char cmd[NAME_MAX], cmd_open[NAME_MAX], cmd_close[NAME_MAX];

	cmd_open[0] = cmd_close[0] = '\0';
	while ( isspace(*p) ) p ++;
	while ( *p ) {
		// command \xxx{yyy}
		if ( *p == '\\' && isalpha(p[1]) ) {
			const char *ps = p;
			bool b_print = false;

			// get command
			p ++;
			c = cmd;
			while ( isalnum(*p) || *p == '_' )
				*c ++ = *p ++;
			*c = '\0';

			// no begin parameters -> ignore
			if ( *p != '{' ) {
				p = ps;
				break;
				}

			// get parameters
			while ( *p ) {
				if ( *p == '{' ) {
					b_print = true;
					p ++;
					intext_command(cmd, cmd_open, cmd_close);
					d_copy(cmd_open);
					continue;
					}
				if ( *p == '}' ) {
					d_copy(cmd_close);
					break;
					}
				if ( b_print )
					*d ++ = *p;
				p ++;
				}

			//
			if ( *p == '}' ) {
				p ++;
				continue;
				}
			p = ps;
			}

		if ( opt_rof && *p == '\\' ) { *d ++ = *p ++; *d ++ = 'e'; continue; }
		if ( opt_rof && *p == '-'  ) *d ++ = '\\';
		if ( opt_rof && *p == '$'  ) *d ++ = '\\';
		if ( opt_rof && *p == '_'  ) *d ++ = '\\';
			
		if ( *p == '.' ) {
			if ( opt_rof && !isalnum(p[1]) ) {
				*d ++ = *p ++;
				*d ++ = '\n';
				while ( isspace(*p) ) p ++;
				continue;
				}
			}

		// normal... 
		if ( isspace(*p) ) {
			if ( isspace(p[1]) ) {
				p ++;
				continue;
				}
			if ( opt_rof && *p == '\n' && p[1] == '.' )
				*d ++ = *p;
			else
				*d ++ = ' ';
			p ++;
			}
		else
			*d ++ = *p ++;
		}
	*d = '\0';
	return dest;
	}

// add text to an element
void stradd(char **ptr, const char *data, bool verb) {
	if ( ptr == NULL ) return;
	char *s = *ptr;
	bool snew = (s == NULL);
	char *d = ( verb ) ? strdup(data) : sqzdup(data);
	int	l = strlen(d) + ((s) ? strlen(s) + 1: 1);
	s = (char *) realloc(s, l);
	
	if ( snew )
		strcpy(s, d);
	else
		strcat(s, d);
	free(d);
	*ptr = s;
	}

// === list of nodes ========================================================

//
node_t	*create_node(const char *file, int32_t line) {
	node_t *node = (node_t *) malloc(sizeof(node_t));
	memset(node, 0, sizeof(node_t));
	node->source = (file) ? strdup(file) : NULL;
	node->line = line + 1;

	if ( !head )
		head = tail = node;
	else {
		tail->next = node;
		tail = node;
		}
	node_count ++;
	return node;
	}

//
void destroy_node(node_t *node) {
	free(node->name);
	free(node->function);
	free(node->variable);
	free(node->datatype);
	free(node->source);
	free(node->synopsis);
	free(node->usage);
	free(node->altusage);
	free(node->description);
	free(node->notes);
	free(node->example);
	free(node->see_also);
	free(node->qualifiers);
	}

// load file into memory
int load_help_file(const char *file) {
	FILE	*fp;
	int		line = 0;
	char	buf[TEXT_MAX];
	char	*p, *t, **field = NULL;
	char	*name, *text;
	node_t	*node = NULL;
	bool	verb = false;

	fprintf(stderr, "scanning %s...\n", file);
	if ( (fp = fopen(file, "rt")) != NULL ) {
		while ( fgets(buf, TEXT_MAX, fp) ) {
			line ++;
			if ( buf[0] == '\\' ) { // TAG
				name = (char*) malloc(TEXT_MAX);
				text = (char*) malloc(TEXT_MAX);
				*name = *text = '\0';
				
				// find if is one-line format or block
				// if one-line gets name and text included in {} otherwise only name
				p = buf + 1;
				t = name;
				while ( *p ) {
					if ( *p == '{' || *p == '\n' )
						break;
					*t ++ = *p ++;
					}
				*t = '\0';
				if ( *p == '{' ) {
					char *ps = p + 1;
					p = strrchr(ps, '}');
					if ( p )
						*p = '\0';
					strcpy(text, ps);
					}

				//
				if ( strcmp(name, "function") == 0 ) {
					node = create_node(file, line);
					field = NULL;
					verb = false;
					node->function = strdup(text);
					node->name = strdup(text);
					}
				else if ( strcmp(name, "variable") == 0 ) {
					node = create_node(file, line);
					field = NULL;
					verb = false;
					node->variable = strdup(text);
					node->name = strdup(text);
					}
				else if ( strcmp(name, "datatype") == 0 ) {
					node = create_node(file, line);
					field = NULL;
					verb = false;
					node->datatype = strdup(text);
					node->name = strdup(text);
					}
				else if ( strcmp(name, "name") == 0 ) {
					node = create_node(file, line);
					field = NULL;
					verb = false;
					node->name = strdup(text);
					}
				else if ( strcmp(name, "synopsis") == 0 ) {
					verb = false;
					field = &(node->synopsis);
					}
				else if ( strcmp(name, "usage") == 0 ) {
					verb = true;
					field = &(node->usage);
					}
				else if ( strcmp(name, "altusage") == 0 ) {
					verb = true;
					field = &(node->altusage);
					}
				else if ( strcmp(name, "description") == 0 ) {
					verb = false;
					field = &(node->description);
					}
				else if ( strcmp(name, "notes") == 0 ) {
					verb = false;
					field = &(node->notes);
					}
				else if ( strcmp(name, "example") == 0 ) {
//					verb = true; // ?????
					field = &(node->example);
					}
				else if ( strcmp(name, "qualifiers") == 0 ) {
					verb = false;
					field = &(node->qualifiers);
					}
				else if ( strcmp(name, "seealso") == 0 ) {
					verb = false;
					field = &(node->see_also);
					}
				else if ( strcmp(name, "done") == 0 ) {
					node = NULL;
					field = NULL;
					verb = false;
					}

				// store text & continue
				if ( node && field )
					stradd(field, text, verb);
				
				free(name);
				free(text);
				}
			else if ( node && field ) {
				if ( buf[0] == '#' ) {
					if ( strcmp(buf, "#v+\n") == 0 ) {
						if ( !verb ) {
							verb = true;
							if ( opt_rof )
								strcpy(buf, "\n.PP\n.EX\n");
							else
								strcpy(buf, "\n");
							}
						else strcpy(buf, "\n");
						}
					else if ( strcmp(buf, "#v-\n") == 0 ) {
						if ( verb ) {
							verb = false;
							if ( opt_rof )
								strcpy(buf, "\n.EE\n.PP\n");
							else
								strcpy(buf, "\n");
							}
						else strcpy(buf, "\n");
						}
					}
				
				// store text to previous pointer
				stradd(field, buf, verb);
				}
			}
		fclose(fp);
		return 0;
		}
	return -1;
	}

// === reports ==============================================================

static char *man_page_header = "\
\\# JED and S-Lang Library Manual Pages\n\
\\# Copyright 1992-2022 John E. Davis <www.jedsoft.org>\n\
\\#\n\
\\# Permission is granted to make and distribute verbatim copies of this\n\
\\# manual provided the copyright notice and this permission notice are\n\
\\# preserved on all copies.\n\
\\#\n\
\\# Permission is granted to copy and distribute modified versions of this\n\
\\# manual under the conditions for verbatim copying, provided that the\n\
\\# entire resulting derived work is distributed under the terms of a\n\
\\# permission notice identical to this one.\n\
\\#\n\
\\# The author(s) assume no responsibility for errors or omissions, or for\n\
\\# damages resulting from the use of the information contained herein.\n\
\\# The author(s) may not have taken the same level of care in the\n\
\\# production of this manual, which is licensed free of charge, as they\n\
\\# might when working professionally.\n\
\\#\n\
\\# Formatted or processed versions of this manual, if unaccompanied by\n\
\\# the source, must acknowledge the copyright and authors of this work.\n\
\\#";
static char *man_page_section = "3sl";
static char *man_page_date    = "2022-09-26";

// print record
#define TITLE(x) "\033[97m"x"\033[0m\n\t"
void print_card(FILE *fp, const node_t *node) {
	if ( node->name == NULL ) return;
	if ( !fp ) fp = stdout;
	if ( opt_rof ) {
		const char	*pg_cat = NULL, *pg_name = "";
		fprintf(fp, "%s\n", man_page_header);
		fprintf(fp, "\\# Source: %s line %d\n\\#\n", node->source, node->line);
		if ( node->function )		{ pg_cat = "Function"; pg_name = node->function; }
		else if ( node->variable )	{ pg_cat = "Variable"; pg_name = node->variable; }
		else if ( node->datatype )  { pg_cat = "DataType"; pg_name = node->datatype; }
		else { pg_name = node->name; }
		fprintf(fp, ".TH \"%s\" %s \"%s\" \"S-Lang\" \"S-Lang Programmer's Manual\"\n",
				pg_name, man_page_section, man_page_date);
// this will create problem with apropos, the manuals is not well written and are using BSD man commands
//		if ( pg_cat )
//			fprintf(fp, ".SH NAME\n%s %s\n", pg_cat, pg_name);
//		else
			fprintf(fp, ".SH NAME\n%s\n", pg_name);
		if ( node->synopsis)	fprintf(fp, ".SH SYNOPSIS\n%s\n", node->synopsis);
		if ( node->usage )		fprintf(fp, ".SH USAGE\n.EX\n%s\n.EE\n", node->usage);
		if ( node->altusage )	fprintf(fp, ".SH USAGE⑵\n.EX\n%s\n.EE\n", node->altusage);
		if ( node->description )fprintf(fp, ".SH DESCRIPTION\n%s\n", node->description);
		if ( node->notes    )	fprintf(fp, ".SH NOTES\n%s\n", node->notes);
		if ( node->example  )	fprintf(fp, ".SH EXAMPLES\n.EX\n%s\n.EE\n", node->example);
		if ( node->qualifiers )	fprintf(fp, ".SH QUALIFIERS\n%s\n", node->qualifiers);
		if ( node->see_also )	{
			//fprintf(fp, ".SH SEE ALSO\n%s\n", node->see_also);
			char *p = node->see_also;
			char dest[NAME_MAX], *d;
			
			fprintf(fp, ".SH SEE ALSO\n");
			d = dest;
			while ( *p ) {
				if ( isspace(*p) ) {
					p ++;
					continue;
					}
				else if ( *p == ',' ) {
					p ++;
					while ( isspace(*p) ) p ++;
					*d = '\0'; d = dest;
					if ( strchr(dest, '(') == NULL )
						fprintf(fp, ".BR \\%%%s (%s),\n", dest, man_page_section);
					else
						fprintf(fp, "%s,\n", dest);
					}
				*d ++ = *p ++;
				}
			*d = '\0';
			if ( d - dest && strchr(dest, '(') == NULL )
				fprintf(fp, ".BR \\%%%s (%s).\n", dest, man_page_section);
			else if ( d - dest )
				fprintf(fp, "%s.\n", dest);
			}
		fprintf(fp, ".\n\\# Local Variables:\n\\# mode: nroff\n\\# End:\n\\# vim: set filetype=groff:\n");
		return;
		}
	fprintf(fp, "\n--- source: %s (%d) ---\n", node->source, node->line);
	fprintf(fp, "\n"TITLE("NAME")"%s\n", node->name);
	if ( node->function ) fprintf(fp, TITLE("FUNCTION")"%s\n", node->function);
	if ( node->variable ) fprintf(fp, TITLE("VARIABLE")"%s\n", node->variable);
	if ( node->datatype ) fprintf(fp, TITLE("DATATYPE")"%s\n", node->datatype);
	if ( node->usage    ) fprintf(fp, TITLE("USAGE")"%s\n", node->usage);
	if ( node->altusage ) fprintf(fp, TITLE("USAGE⑵")"%s\n", node->altusage);
	fprintf(fp, TITLE("SYNOPSIS")"%s\n", node->synopsis);
	fprintf(fp, TITLE("DESCRIPTION")"%s\n", node->description);
	if ( node->notes    ) fprintf(fp, TITLE("NOTES")"%s\n", node->notes);
	if ( node->example  ) fprintf(fp, TITLE("EXAMPLES")"%s\n", node->example);
	if ( node->qualifiers ) fprintf(fp, TITLE("QUALIFIERS")"%s\n", node->qualifiers);
	if ( node->see_also ) fprintf(fp, TITLE("SEE ALSO")"%s\n", node->see_also);
	}

// print all the records
void print_list(const char *odir) {
	for ( int i = 0; i < node_count; i ++ ) {
		if ( odir ) {
			char	name[PATH_MAX];
			FILE	*fp; 
			snprintf(name, PATH_MAX, "%s/%s.3sl", odir, node_index[i]->name);
			if ( (fp = fopen(name, "wt")) != NULL ) {
				print_card(fp, node_index[i]);
				fclose(fp);
				}
			else
				PANIC("fopen()");
			}
		else
			print_card(stdout, node_index[i]);
		}
	}

// quicksort / lsearch callback
int qs_cmp(const void *a, const void *b) {
	return strcmp((*(node_t **)a)->name, (*(node_t **)b)->name); }

// search name
void search(const char *key) {
	for ( int i = 0; i < node_count; i ++ ) {
		if ( strcmp(key, node_index[i]->name) == 0 ) {
			print_card(stdout, node_index[i]);
			break;
			}
		}
	}

// search name using regular expression
void re_search(const char *key) {
	regex_t	re;

	if ( regcomp(&re, key, REG_ICASE | REG_NOSUB) )
		return;
	for ( int i = 0; i < node_count; i ++ ) {
		node_t *cur = node_index[i];
		if ( cur->name )
			if ( regexec(&re, cur->name, 0, NULL, 0) == 0 ) 
				print_card(stdout, cur);
		}
	regfree(&re);
	}

// search name and description
void search_desc(const char *key) {
	for ( int i = 0; i < node_count; i ++ ) {
		node_t *cur = node_index[i];
		if ( cur->name && cur->description )
			if ( strstr(cur->name, key) || strstr(cur->description, key) ) 
				print_card(stdout, cur);
		}
	}

// search name and description using regular expression
void re_search_desc(const char *key) {
	regex_t	re;

	if ( regcomp(&re, key, REG_ICASE | REG_NOSUB) )
		return;
	for ( int i = 0; i < node_count; i ++ ) {
		node_t *cur = node_index[i];
		if ( cur->name && cur->description )
			if ( regexec(&re, cur->name, 0, NULL, 0) == 0 || 
				regexec(&re, cur->description, 0, NULL, 0) == 0 ) 
				print_card(stdout, cur);
		}
	regfree(&re);
	}

// === collect files ========================================================

// recursive directory scan for files according the 'pat' pattern
void find_help_files_dir(const char *pdir, const char *pat) {
	static int alloc = 0;
	static int depth = 0;
    DIR		*dp;
	struct dirent *e;
	struct stat st;
	char	pwd[PATH_MAX], dir[PATH_MAX], buf[PATH_MAX];

	if ( getcwd(pwd, PATH_MAX) == NULL )	PANIC("getcwd()");
	if ( access(pdir, F_OK) != 0 ) return;
	if ( realpath(pdir, dir) == NULL )		PANIC("realpath(\"%s\")", pdir);
	if ( (dp = opendir(dir)) == NULL )		PANIC("opendir()");
	if ( chdir(dir) != 0 )					PANIC("chdir()");
	while ( (e = readdir(dp)) != NULL ) {
		stat(e->d_name, &st);
        if ( st.st_mode & S_IFDIR ) {
			if ( strcmp(".", e->d_name) == 0 || strcmp("..", e->d_name) == 0 )
				continue;
			depth ++;
			if ( depth > 8 )
				PANIC("directory depth > 8!");
			snprintf(buf, PATH_MAX, "%s/%s", dir, e->d_name);
			find_help_files_dir(buf, pat);
			depth --;
			}
		else if ( fnmatch(pat, e->d_name, FNM_PATHNAME) == 0 ) { // if match add it
			if ( help_files_count == alloc ) {
				alloc += HELP_FILES_ALLOC;
				help_files = (char **) realloc(help_files, alloc * sizeof(char*));
				}
			snprintf(buf, PATH_MAX, "%s/%s", dir, e->d_name);
			help_files[help_files_count ++] = strdup(buf);
			}
	    }
	if ( closedir(dp) != 0 )	PANIC("closedir()");
	if ( chdir(pwd) != 0 )		PANIC("chdir()");
	}

//
void find_help_files() {
	int		path_idx;
	char	pat[NAME_MAX], dir[PATH_MAX], *p;
	struct stat st;
	const char *arg_s;

	for ( path_idx = 0; path_idx < help_files_path_count; path_idx ++ ) {
		arg_s = help_files_path[path_idx];
		strcpy(dir, arg_s);
		if ( stat(dir, &st) == 0 ) { // directory/filename exists
			if ( st.st_mode & S_IFDIR ) // it is directory
				strcpy(pat, "*");
			else { // it is file
				if ( (p = strrchr(dir, '/')) != NULL ) { // its directory + filename
					*p = '\0';
					strcpy(pat, p+1);
					}
				else {// simple filename
					*dir = '\0';
					strcpy(pat, arg_s);
					}
				}
			}
		else { // argument has pattern?
			if ( (p = strrchr(dir, '/')) == NULL ) {
				*dir = '\0';
				strcpy(pat, arg_s);
				}
			else {
				*p = '\0';
				strcpy(pat, p+1);
				}
			}
		find_help_files_dir(dir, pat);
		}
	}

// === process ==============================================================

// create a sorted (by 'name') index of node_t pointers
void create_list_index() {
	int		idx = 0;
	node_index = (node_t **) malloc(sizeof(node_t*) * node_count);;
	for ( node_t *cur = head; cur; cur = cur->next )
		node_index[idx ++] = cur;
	qsort(node_index, node_count, sizeof(node_t*), qs_cmp);
	}

//
void store_str(FILE *fp, const char *str) {
	int32_t l;
	if ( str ) {
		l = strlen(str);
		fwrite( &l, sizeof(int32_t), 1, fp);
		fwrite(str, l, 1, fp);
		}
	else {
		l = -1;
		fwrite( &l, sizeof(int32_t), 1, fp);
		}
	}

//
char *restore_str(FILE *fp) {
	int32_t l;
	char	*p;
	
	fread( &l, sizeof(int32_t), 1, fp);
	if ( l != -1 ) {
		p = (char *) malloc(l + 1);
		fread(p, l, 1, fp);
		p[l] = '\0';
		return p;
		}
	return NULL;
	}

//
void store_int32(FILE *fp, int32_t n) {
	fwrite( &n, sizeof(int32_t), 1, fp);
	}

//
int32_t restore_int32(FILE *fp) {
	int32_t n;
	fread( &n, sizeof(int32_t), 1, fp);
	return n;
	}

//
void store_node(FILE *fp, const node_t *node) {
	store_str(fp, node->name);
	store_str(fp, node->function);
	store_str(fp, node->variable);
	store_str(fp, node->datatype);
	store_str(fp, node->source);
	store_int32(fp, node->line);
	store_str(fp, node->synopsis);
	store_str(fp, node->usage);
	store_str(fp, node->altusage);
	store_str(fp, node->description);
	store_str(fp, node->notes);
	store_str(fp, node->example);
	store_str(fp, node->see_also);
	store_str(fp, node->qualifiers);
	}

//
void restore_node(FILE *fp, node_t *node) {
	node->name        = restore_str(fp);
	node->function    = restore_str(fp);
	node->variable    = restore_str(fp);
	node->datatype    = restore_str(fp);
	node->source      = restore_str(fp);
	node->line        = restore_int32(fp);
	node->synopsis    = restore_str(fp);
	node->usage       = restore_str(fp);
	node->altusage    = restore_str(fp);
	node->description = restore_str(fp);
	node->notes       = restore_str(fp);
	node->example     = restore_str(fp);
	node->see_also    = restore_str(fp);
	node->qualifiers  = restore_str(fp);
	}

//
int main(int argc, char *argv[]) {
	int		i;
	char	*fn = NULL, *odir = NULL, cwd[PATH_MAX], tmp[PATH_MAX];;
	bool	opt_all = false, opt_src = false, opt_dsc = false, opt_reg = false;
	bool	opt_cache = false;

	fprintf(stderr, "jed-man v1.3:\n");
	if ( getcwd(cwd, PATH_MAX) == 0 ) PANIC("getcwd!");

	// calculate where to store cache file
	if ( getenv("JED_HOME") )	strcpy(cache_file, getenv("JED_HOME"));
	else if ( getenv("HOME") )	strcpy(cache_file, getenv("HOME"));
	else 						strcpy(cache_file, cwd);
	strcat(cache_file, "/.jed-man-cache");

	// default help files path, start with automatic
	snprintf(tmp, PATH_MAX, "%s/%s/*.tm", cwd, "missing");
	add_help_files_path(tmp);
	
	if ( access("/usr/share/jed-man/tm", R_OK | X_OK) == 0 )
		add_help_files_path("/usr/share/jed-man/tm/*.tm");
	else if ( access("/usr/local/share/jed-man/tm", R_OK | X_OK) == 0 )
		add_help_files_path("/usr/local/share/jed-man/tm/*.tm");
	else if ( access("../../slang/doc/tm/rtl", R_OK | X_OK) == 0 ) {
		add_help_files_path("../../slang/doc/tm/rtl/*.tm");
		if ( access("../../jedc/doc/tm/rtl", R_OK | X_OK) == 0 )
			add_help_files_path("../../jedc/doc/tm/rtl/*.tm");
		if ( access("../../jed/doc/tm/rtl", R_OK | X_OK) == 0 )
			add_help_files_path("../../jed/doc/tm/rtl/*.tm");
		}
	else {
		if ( access("jed-rtl", R_OK | X_OK) == 0 ) 
			add_help_files_path("jed-rtl/*.tm");
		if ( access("slang-rtl", R_OK | X_OK) == 0 )
			add_help_files_path("slang-rtl/*.tm");
		}
	
	// rc file
	if ( getenv("JED_HOME") )	strcpy(rc_file, getenv("JED_HOME"));
	else if ( getenv("HOME") )	strcpy(rc_file, getenv("HOME"));
	else strcpy(rc_file, "/tmp");
	strcat(rc_file, "/jed-man.rc");

	//
	read_conf(rc_file);

	//
	for ( i = 1; i < argc; i ++ ) {
		if ( argv[i][0] == '-' ) {
			char *p = argv[i] + 1;
			while ( *p ) {
				switch ( *p ) {
				case 'h':
					printf("-a = print all\n");
					printf("-s pattern = search name\n");
					printf("-d pattern = search name and description\n");
					printf("-r = use regular expressions\n");
					printf("-m = output in roff\n");
					printf("-p dir = output directory / output node-file by name\n");
					printf("\n");
					printf("example:\n\tregex search: ./jed-man -rs buffer\n\tcreate manpages: ./jed-man -apm man3sl\n");
					return EXIT_FAILURE;
				case 'v':
					printf("jed-man v1.3; date 2022-10-20\n");
					return EXIT_FAILURE;
				case 'c': // create cache
					opt_cache = true; break;
				case 'a': // print all
					opt_all = true;	break;
				case 'r': // use regular expressions
					opt_reg = true;	break;
				case 's': // search
					opt_src = true;	break;
				case 'd': // search name and description
					opt_dsc = true;	break;
				case 'm': // output in roff
					opt_rof = true;	break;
				case 'p': // output directory
					if ( access(cache_file, R_OK) == 0 )
						remove(cache_file);
					odir = ( i + 1 < argc ) ? argv[i+1] : NULL;
					if ( odir ) {
						if ( access(odir, R_OK | W_OK | X_OK) != 0 ) {
							if ( mkdir(odir, 0755) != 0 )
								PANIC("mkdir()");
							}
						}
					break;
				default:
					printf("usage: jed-man {-a[m][c] | -a[m][p odir] | -[r]{s|d}[m] pattern}\n");
					return EXIT_FAILURE;
					}
				p ++;
				}
			}
		else
			fn = argv[i];
		}

	// if exists cache, read it
	if ( !opt_cache && (access(cache_file, R_OK) == 0) ) {
		FILE *fp;
		struct stat st;
		if ( stat(cache_file, &st) == 0 ) {
			fprintf(stderr, "reading cache '%s'...\n", cache_file);
			if ( (fp = fopen(cache_file, "rb")) != NULL ) {
				int32_t vers  = restore_int32(fp);
				if ( vers != cache_vers ) {
					fclose(fp);
					fprintf(stderr, "different version found. cache '%s' deleted...\n", cache_file);
					if ( remove(cache_file) != 0 ) PANIC("remove old chache");
					}
				else {
					int32_t count = restore_int32(fp);
					node_index = (node_t **) malloc(sizeof(node_t*) * count);
					for ( i = 0; i < count; i ++ ) {
						node_index[i] = create_node(NULL, 0);
						restore_node(fp, node_index[i]);
						}
					fclose(fp);
					}
				}
			}
		else
			PANIC("fopen() can't open cache");
		}
	// build everything from source
	else {
		find_help_files();
		if ( help_files == NULL ) {
			fprintf(stderr, "%s\n", "no source files found!");
			return EXIT_FAILURE;
			}
		for ( i = 0; i < help_files_count; i ++ ) {
			if ( access(help_files[i], R_OK) == 0 )
				load_help_file(help_files[i]);
			}
		create_list_index();
		}
	// save cache
	if ( opt_cache ) {
		FILE *fp;
		if ( (fp = fopen(cache_file, "wb")) != NULL ) {
			store_int32(fp, cache_vers);
			store_int32(fp, node_count);
			for ( i = 0; i < node_count; i ++ )
				store_node(fp, node_index[i]);
			fclose(fp);
			}
		else
			PANIC("fopen() can't create cache");
		}

	// search & print
	if ( opt_all ) {		// print all nodes
		print_list(odir);
		fprintf(stderr, "done\n");
		}
	else if ( opt_dsc ) {	// search pattern/keyword in name and in description
		if ( !fn ) { fprintf(stderr, "search for what?\n"); return EXIT_FAILURE; }
		if ( opt_reg ) re_search_desc(fn); else search_desc(fn);
		}
	else if ( opt_src ) {	// simple search pattern/keyword on name
		if ( !fn ) { fprintf(stderr, "search for what?\n"); return EXIT_FAILURE; }
		if ( opt_reg ) re_search(fn); else search(fn);
		}
	
	// free help files paths
	if ( help_files_path ) {
		for ( i = 0; i < help_files_path_count; i ++ )
			free(help_files_path[i]);
		free(help_files_path);
		}

	// free help files
	if ( help_files ) {
		for ( i = 0; i < help_files_count; i ++ )
			free(help_files[i]);
		free(help_files);
		}

	// free list nodes & list index
	if ( node_count ) {
		for ( i = 0; i < node_count; i ++ ) {
			destroy_node(node_index[i]);
			free(node_index[i]);
			}
		free(node_index);
		}

	// normal exit
	return EXIT_SUCCESS;
	}

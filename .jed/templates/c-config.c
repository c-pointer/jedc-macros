#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>

// === configuration ========================================================

// table of variables
typedef struct {
	const char *name;	// name of variable
	char *value;		// buffer to accept the value if _static;
						// otherwise pointer to dynamic allocated memory
	int _static; 		// type of data (dynamic or static).
						// use dynamic for user defined variables.
	} conf_var_t;
static conf_var_t **var_table = {
	{ "varname", str_variable, 0 },
	{ NULL, NULL, 0 } }; // end-of-list mark
static size_t var_table_count = 0;

// table of commands
typedef struct { const char *name; void (*func_p)(const char *); } conf_cmd_t;
static conf_cmd_t cmd_table[] = {
	{ "command", function_pointer },
	{ NULL, NULL } }; // end-of-list mark

// run shell and return the result
static char *conf_run_sh(const char *name) {
	FILE *fp;
	char buf[PATH_MAX], *dest, *d;
	size_t	dstlen = 0, buflen;

	dest = (char *) malloc(1);
	d = dest; *d = '\0';
	if ( (fp = popen(name, "r")) != NULL ) {
		while ( fgets(buf, LINE_MAX, fp) ) {
			buflen = strlen(buf);
			dstlen = d - dest;
			dest = (char *) realloc(dest, dstlen + buflen + 1);
			d = dest + dstlen;
			strcat(d, buf);
			d += buflen;
			}
		pclose(fp);
		if ( d > dest && *(d-1) == '\n' )
			*(d-1) = '\0';
		*d = '\0';
		}
	return dest;
	}

// returns the value of variable or NULL
static char *conf_getvar(const char *variable) {
	size_t	i;

	// first tine, count variables
	if ( var_table_count == 0 ) {
		for ( i = 0; var_table[i].name; i ++ )
			var_table_count ++;
		}

	// find variable and return its value
	for ( i = 0; i < var_table_count; i ++ ) {
		if ( strcmp(var_table[i].name, variable) == 0 ) 
			return var_table[i].value;
		}

	// variable not found, check the environment
	return getenv(variable);
	}

// expand environment variables (e.g. $HOME)
static char *conf_expand(const char *src) {
	const char *p = src;
	char	result[LINE_MAX], *r;
	char	name[NAME_MAX], *n, *v;
	unsigned int c, z, sq = 0, rq = 0, dq = 0;

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
		
		if ( sq ) { if ( *p == '\'' ) { sq = 0; p ++; continue; } }
		if ( *p == '\'' ) { sq = 1; p ++; continue; }

		if ( *p == '~' ) {
			if ( (v = getenv("HOME")) != NULL )
				while ( *v ) *r ++ = *v ++;
			p ++;
			continue;
			}
		if ( *p == '$' && (isalpha(c) || c == '{' || c == '(') ) { // $...
			p ++;
			n = name;
			if ( *p == '{' ) {	// ${...}
				p ++;
				while ( *p && *p != '}' ) *n ++ = *p ++;
				*n = '\0'; if ( *p == '}' ) p ++;
				if ( (v = conf_getvar(name)) != NULL )
					while ( *v ) *r ++ = *v ++;
				}
			else if ( *p == '(' ) { // $(...) no nested () allowed yet, \( \) works
				p ++;
				while ( *p && *p != ')' ) *n ++ = *p ++;
				*n = '\0'; if ( *p == ')' ) p ++;
				*r = '\0';
				if ( (v = conf_run_sh(name)) != NULL ) {
					while ( *v ) *r ++ = *v ++;
					free(v);
					}
				}
			else {	// $name
				while ( *p && isalnum(*p) ) *n ++ = *p ++;
				*n = '\0';
				if ( (v = conf_getvar(name)) != NULL )
					while ( *v ) *r ++ = *v ++;
				}
			continue;
			}

		if ( rq ) {
			if ( *p == '`' ) {
				rq = 0; *r = '\0';
				if ( (v = conf_run_sh(name)) != NULL ) {
					while ( *v ) *r ++ = *v ++;
					free(v);
					}
				}
			p ++;
			continue;
			}
		if ( *p == '`' ) { rq = 1; p ++; continue; }
		if ( dq ) { if ( *p == '"' ) { dq = 0; p ++; continue; } }
		if ( *p == '"' ) { dq = 1; p ++; continue; }

		*r ++ = *p ++;
		}
	*r = '\0';
	return strdup(result);
	}

// assign variables
static void conf_set(int line, const char *variable, const char *value) {
	size_t	i;
	char	*s;

	// first tine, count variables
	if ( var_table_count == 0 ) {
		for ( i = 0; var_table[i].name; i ++ )
			var_table_count ++;
		}

	// search variable and set the value if found
	for ( i = 0; i < var_table_count; i ++ ) {
		if ( strcmp(var_table[i].name, variable) == 0 ) {
			s = conf_expand(value);
			if ( var_table[i]._static ) {
				strcpy(var_table[i].value, s);
				free(s);
				}
			else {
				if ( var_table[i].value )
					free(var_table[i].value);
				var_table[i].value = s;
				}
			return;
			}
		}

	// not found; create a new variable
	var_table = (conf_var_t **) realloc(var_table, var_table_count + 1);
	var_table[var_table_count].name = strdup(variable);
	var_table[var_table_count].value = conf_expand(value);
	var_table[var_table_count]._static = 0; // dynamic allocated data
	var_table_count ++;
	}

// execute commands
static void conf_exec(int line, const char *command, const char *parameters) {
	for ( size_t i = 0; cmd_table[i].name; i ++ ) {
		if ( strcmp(cmd_table[i].name, command) == 0 ) {
			if ( cmd_table[i].func_p ) {
				char *s = conf_expand(parameters);
				cmd_table[i].func_p(s);
				free(s);
				}
			return;
			}
		}
	fprintf(stderr, "rc(%d): uknown command [%s]\n", line, command);
	}

// parse string line
static void conf_parse(int line, const char *source) {
	char name[LINE_MAX], *d = name;
	const char *p = source;
	while ( isblank(*p) ) p ++;
	if ( *p && *p != '#' ) {
		while ( *p == '_' || isalnum(*p) )
			*d ++ = *p ++;
		*d = '\0';
		while ( isblank(*p) ) p ++;
		if ( *p == '=' ) {
			p ++;
			while ( isblank(*p) ) p ++;
			conf_set(line, name, p);
			}
		else
			conf_exec(line, name, p);
		}
	}

/*
 *	read configuration file `rc`
 */
void read_conf(const char *rc) {
	int line = 0, n;
	
	if ( access(rc, R_OK) == 0 ) {
		char buf[LINE_MAX];
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



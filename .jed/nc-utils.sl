%%
%%	Jed Utilities
%%	
%%	Nicholas Christopoulos
%%	

provide("nc-utils");

%% --- debug ----------------------------------------------------------------------

%!%+
%\function{buflogf}
%\usage{void buflogf(fmt, ...)}
%\synopsis{uses a buffer for log}
%\description
%  Creates and uses buffer “*Log*” to store messages.
%  The syntax is same as printf().
%!%-
public define buflogf() {
	variable buf = "*log*", pbuf;
	variable argc = _NARGS, args = __pop_args(argc), s;
	s = sprintf(__push_args(args));
	pbuf = whatbuf();
	setbuf(buf);
	set_readonly(0);
	insert(s);
	set_readonly(1);
	setbuf(pbuf);
	}

%!%+
%\function{logf}
%\usage{void logf(fmt, ...)}
%\synopsis{Writes to logfile}
%\description
%  Writes to logfile. It takes printf arguments.
%  The global variable ‘ncu_logfile’ defines the logfile full-path filename.
%!%-
custom_variable("ncu_logfile", vdircat(Jed_Home_Directory, "data", "ncu.log"));
public define logf() {
	variable args = __pop_args(_NARGS), s, fp;
	s = sprintf(__push_args(args));
	fp = fopen(ncu_logfile, "a");
	if ( fp != NULL ) {
		() = fprintf(fp, "%d %d: %s\n", getpid(), _time, s);
		() = fclose(fp); % fclose() flushes the buffer
		}
	}

%% --- buffers --------------------------------------------------------------------

%!%+
%\function{clear_buffer}
%\usage{void clear_buffer()}
%\synopsis{Clear buffer contents without kill the undo}
%\description
%  Clear buffer contents without kill the undo; unlike the erase_buffer().
%!%-
public define clear_buffer() {
	variable pbuf, buf = ( _NARGS ) ? () : NULL;

	ifnot ( NULL == buf ) {
		pbuf = whatbuf();
		setbuf(buf);
		}
	bob(); push_mark(); eob();
	del_region();
	if ( markp() )
		pop_mark_0();
	ifnot ( NULL == buf )
		setbuf(pbuf);	
	}

%!%+
%\function{load_file_lines(file)}
%\usage{String[] = load_file_lines(file)}
%\synopsis{load a text file and returns the lines in array}
%\description
%  Load a text file into array of strings.
%  Returns the array. If an error occurred then returns an empty
%  array (String_Type[0]).
%!%-
public define load_file_lines(file) {
    variable fp, lines;
    if ( access(file, F_OK) == 0 ) {
        fp = fopen(file, "r");
        if ( fp == NULL ) throw OpenError;
        lines = fgetslines(fp);
        () = fclose(fp);
        }
    else
        lines = String_Type[0];
    return lines;
    }

%!%+
%\function{insert_paragraph}
%\usage{void insert_paragraph(String text)}
%\synopsis{inserts a formatted paragraph to the buffer}
%\description
%  Inserts a formatted paragraph to the buffer. The \var{text} is the
%  unformatted text.
%!%-
public define insert_paragraph(text) {
	push_mark();	   
	insert(text);
	call("format_paragraph");
	if ( markp() )
		pop_mark_0();
	}

%!%+
%\function{get_buffer_mode}
%\usage{string get_buffer_mode()}
%\synopsis{returns the mode of the current buffer}
%\description
%  Returns the mode of the current buffer.
%!%-
public define get_buffer_mode()
{ return what_mode(), pop(); }

%% handle buffer flags

public define test_buffer_flag(flag) {
	variable flags;
	(,,,flags) = getbuf_info ();
	return flags & flag;
	}

public define set_buffer_flag(flag)
{ setbuf_info(getbuf_info() | flag); }

public define unset_buffer_flag(flag)
{ setbuf_info(getbuf_info() & ~flag); }

public define toggle_buffer_flag(flag)
{ setbuf_info(getbuf_info() xor flag); }

%% --------------------------------------------------------------------------------

%!%+
%\function{strfit}
%\synopsis{Cuts string to fit in width-columns}
%\usage{String strfit(String str, Int width, Int dir)}
%\description
% Cuts the string \var{str} to fit in \var{width} columns.
% if \var{width} is missing, then \var{width} is equal to columns of the current window.
% If \var{dir} > 0 then cuts the right part; otherwise cuts the left part of string.
% if \var{dir} is missing, then \var{dir} is zero.
%!%-
private variable right_edge = "…";	%% (>>) here would be nice if slang had constants or macros
private variable left_edge  = "…";	%% (<<) or ldots of utf8
public define strfit(str, width, dir) {
	variable len = strlen(str);
	if ( len < 2 )	return str;
	if ( width == NULL ) width = window_info('w');
	if ( width < 4 ) width = 4;
	if ( dir == NULL ) dir = 0;
	if ( len > width ) 
		return ( dir > 0 ) ?
			strcat(substr(str, 1, width - strlen(right_edge)), right_edge) : % >>
			strcat(left_edge, substr(str, (len - width) + strlen(left_edge) + 1, width)); % <<
	return str;
	}
	
public define get_iso_date() {
    variable time_struct = localtime(_time);
    return sprintf("%d-%02d-%02d", time_struct.tm_year+1900, time_struct.tm_mon+1, time_struct.tm_mday);
    }

%% error message (errors for users; not error() and quit)
private variable color_error = color_number("error");
public define uerror() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable i, s = "";
	for ( i = 0; i < argc; i ++ )
		s += string(argv[i]);
	s = strfit(s,,);
	s = sprintf("\e[%d]%s", color_error, s);
	message(s);
	}

%% error message formatted
public define uerrorf() {
	variable args = __pop_args(_NARGS), s;
	s = sprintf(__push_args(args));
	uerror(s);
	}

%% message
public define mesg() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable i, s = "";
	for ( i = 0; i < argc; i ++ )
		s += string(argv[i]);
	s = strfit(s,,);
	message(s);
	}
	
%% message formatted
public define mesgf() {
	variable args = __pop_args(_NARGS), s;
	s = sprintf(__push_args(args));
	mesg(s);
	}

% returns the boolean value of string src
public define atobool(src) {
	if ( isdigit(src[0]) )
		return ( atoi(src) == 0 ) ? 0 : 1;
	src = strlow(strtrim(src));
	switch ( src[0] )
	{ case 't': return 1; }
	{ case 'f': return 0; }
	{ case 'y': return 1; }
	{ case 'n': return 0; }	
	if ( strncmp(src, "on", 2)  == 0 )	return 1;
	if ( strncmp(src, "off", 3) == 0 )	return 0;
	if ( src[0] == '-' || src[0] == '+' || src[0] == '.' )
		return ( atof(src) != 0 ) ? 1 : 0;
	return 0;
	}

%!%+
%\function{compile_local_sl}
%\usage{void complile_local_sl()}
%\synopsis{auto compile home dir sl files}
%\description
%  Auto compile home dir sl files
%!%-
public define compile_local_sl() {
	variable files, dirs;
	variable d, f, s, o;

	dirs = [
		Jed_Home_Directory,
		vdircat(Jed_Home_Directory, "sys"),
		vdircat(Jed_Home_Directory, "syntax"),
		vdircat(Jed_Home_Directory, "lib"),
		vdircat(Jed_Home_Directory, "utils")
		];
	foreach d ( dirs ) {
		files = listdir(d);
		foreach f ( files ) {
			if ( path_extname(f) ==  ".sl" ) {
				s = vdircat(d, f);
				o = vdircat(d, f + "c");
				ifnot ( 0 == access(o, R_OK) )
					byte_compile_file(s, 0);
				else {
					if ( 0 < file_time_compare(s, o) )
						byte_compile_file(s, 0);
					}
				}
			}
		}
	}

%% user file: jedrc
private variable user_jedrc = vdircat(Jed_Home_Directory, "local.sl");
public define user_load_local_jedrc() {
	ifnot ( BATCH ) {
		if ( is_file(user_jedrc) )
			() = evalfile(user_jedrc);
		}
	}

%% machine file: jedrc
private variable host_jedrc = vdircat(Jed_Home_Directory, strcat(get_hostname(), ".sl"));
public define user_load_host_jedrc() {
	ifnot ( BATCH ) {
		if ( is_file(user_jedrc) )
			() = evalfile(user_jedrc);
		}
	}

%% user file: terminal characteristics/keys
private variable user_term_fixes = vdircat(Jed_Home_Directory, "term.sl");
public define user_load_local_terminal() {
	ifnot ( BATCH ) {
		if ( is_file(user_term_fixes) )
			() = evalfile(user_term_fixes);
		}
	}

%!%+
%\function{getterm}
%\usage{String getterm()}
%\synopsis{Returns the terminal name}
%\description
%  Returns the terminal name.
%  For non-unix systems returns the OS name.
%  For XJED returns ‘xjed’. 
%!%-	
public define getterm() {
	variable term = getenv("TERM");
	if ( term == NULL ) {
#ifdef MSDOS
		term = "dos";
#elseif OS2
		term = "os2";
#elseif WIN32 MSWINDOWS
		term = "windows";
#elseif XWINDOWS
		term = "xjed";
#else
		term = "ansi";
#endif
		}
	return term;
	}

%!%+
%\function{is_xjed}
%\usage{Boolean is_xjed()}
%\synopsis{returns true if we run xjed}
%\description
%  Returns true if we run xjed
%!%-	
private variable is_it_xjed = is_defined("x_server_vendor");
public define is_xjed()
{ return is_it_xjed; }

%!%+
%\function{get_home}
%\usage{String get_home([subdir])}
%\synopsis{Returns user's directory}
%\description
%	Returns user's home directory.
%	If \var{subdir} is given, then returns the correct
%	full path of this subdirectory.
%!%-
public define get_home() {
	variable home = getenv("HOME");
	if ( home == NULL )
		home = "/tmp";
	if ( _NARGS > 0 ) 
		return vdircat(home, ());
	return home;
	}

%!%+
%\function{get_jed_home}
%\usage{String get_jed_home([subdir])}
%\synopsis{Returns jed user's local directory}
%\description
%	Returns jed user's local directory.
%	If \var{subdir} is given, then returns the correct
%	full path of this subdirectory.
%!%-
public define get_jed_home() {
	if ( _NARGS > 0 ) {
		variable dir = ();
		switch ( dir )
		{ case "data":		return vdircat(Jed_Home_Directory, "data"); }
		{ case "cache":		return vdircat(Jed_Home_Directory, "data", "cache"); }
		{ case "tmp":		return vdircat(Jed_Home_Directory, "data", "tmp"); }
		{ case "colors":	return vdircat(Jed_Home_Directory, "colors"); }
		return vdircat(Jed_Home_Directory, dir);
		}
	return Jed_Home_Directory;
	}

%!%+
%\function{get_jed_root}
%\usage{String get_jed_root([subdir])}
%\synopsis{Returns jed system directory}
%\description
%	Returns jed system directory.
%	If \var{subdir} is given, then returns the correct
%	full path of this subdirectory.
%!%-
public define get_jed_root() {
	if ( _NARGS > 0 ) 
		return vdircat(JED_ROOT, ());
	return JED_ROOT;
	}

%%
%%	You may want to reserve a key to toggle between newline_and_indent and newline.
%%	
private variable newline_indents = 0;
public define toggle_newline_and_indent () {
	if ( 0 == newline_indents ) {
		local_setkey ("newline_and_indent", "^M");
		newline_indents = 1;
		flush("RET indents");
		}
	else {
		local_setkey ("newline", "^M");
		newline_indents = 0;
		flush("RET does not indent");
		}
	}

%%
%% sort comma separated string list
%% 
public define sort_cslist(csl) {
	variable a, b;
	a = strchop(csl, ',', 0);
	b = a[array_sort(a)];
	return strjoin(b, ",");
	}

%% --------------------------------------------------------------------------------
%% init
private define unit_init_ncu() {
	if ( 0 == access(ncu_logfile, F_OK) )
		() = delete_file(ncu_logfile);
	}
unit_init_ncu();


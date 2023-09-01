%% -*- mode: slang; tab-width: 4; indent-style: tab; encoding: utf-8; -*-
%%
%%	BRIEF emulation for JED
%%
%%	Copyleft (Ͻ) 2016-22 Nicholas Christopoulos.
%%	Released under the terms of the GNU General Public License (ver. 3 or later)
%%
%%	2017-07-17
%%		RE help added
%%	2016-09-05
%%		Rewritten the old brief.sl from scratch, the old module (by Marko Mahnic) 
%%		still included as mm-brief.sl file and it is used.
%%	2019-11-26
%%		xclip used for clipboard, allows to copy/paste text even from terminal version.
%%		Alt+Ctrl+C = xcopy, Alt+Ctrl+V = xpaste, Alt+Ctrl+X = xcut
%%	2021-01-09
%%		'<!' and '<' at command line
%%	2022-09-09
%%		CBRIEF v6 restructure...
%%	2022-09-26
%%		jed-man (create man pages for S-Lang & JED)
%%		on-line help (help on the word under the cursor)
%%	2022-09-27
%%		CBRIEF v8 restructure.. TUI select files, edit text, show text
%%	2022-10-11
%%		hyperman fixed to get section, fixed the escape codes of GROFF_SGR,
%%		and pressing link to show new man pages
%%	2022-10-15
%%		CBRIEF v9 restructure..
%%		list of lists (different kind of lists) supported in C
%%		with garbage collector
%%	2022-10-18
%%		add m_history from jedmodes by Marko Mahnic,
%%		local history files comment out
%%		selfile & sellist completion functions
%%	2022-10-20
%%		adding varfiles
%%		search supports flags:
%%		'/re/ci;this string' = regex ON, case OFF; search for the string
%%	2022-10-23
%%		strlist <-> array
%%		new better listdir, dirlist([path[+pattern]] [, mode]) -> count, __pop_list(count)
%%	2022-11-17
%%		alias, set, setenv and related engines added.
%%		a lot of bugfixes, refine code,
%%		tokenlist (jedmodes) added to replace ^G (routines)
%%	2022-11-28
%%		update ncsession
%%		new bufmenu
%%		rc multiple expand
%%	
%%	Based on: BRIEF v3.1, 1991 and secondary on BRIEF v2.1, 1988
%%	
%%	Brief Manual:
%%	=============
%%	BRIEF is a "modeless" editor, meaning that the commands have
%%	the same meaning almost all the time.
%%
%%	Missing:
%%		* set macro buffer (the reverse function of get_last_macro) - ndc patch - test
%%		* region must extends to the cursor (its cell) - ndc patch - ok, test column
%%		* moving around empty space without adding characters
%%		* I have no detailed manual about each macro parameters, I have to check all
%%			to see whatever I ll find.
%%
%%	Notes:
%%	
%%		* Console
%%		
%%		The console (F10) executes BRIEF's macros as we remember,
%%		assign_to_key, brace, slide_in, etc (see help/macros)
%%		
%%		but, if the first character(s) is(are):
%%		==================================================================
%% $	then executes in the shell the following commands with eval(); this	means S-Lang code.
%%	
%% ?	Calculator, it prints whatever it follows in S-Lang.
%%		Example: '? 60*sin(0.8), buffer_filename()'
%%
%% !	executes the commands with the shell and insert the output to a new buffer.
%%
%% <!	executes the commands with the shell and replaces the text
%% 		of the current buffer or block.
%%
%% <<!	executes the commands with the shell and insert the output
%% 		to the current position of the current buffer.
%%
%% <	replaces the contents of the current buffer or block with the contents of the file,
%% 		if file is not specified then it will prompt for the name.
%% 		
%% <<	insert the contents of the file to current position, if file is not specified
%% 		then it will prompt for the name.
%%
%% >	writes the selected text to a new file.
%%
%% >>	appends the selected text to a file.
%%
%% |	(pipe) sends the selected text as standard input to the command that follows.
%% 		inserts the output to a new buffer.
%% 		if no text was selected then uses the whole buffer.
%% 		example: | sed -n /word/,+1p
%%
%% <|	(pipe) sends the selected text as standard input to the command that follows,
%% 		replaces the current block with the output of the command.
%% 		if no text was selected then uses the whole buffer.
%% 		example: <| sed s/what/with/g		
%%
%% <<|	(pipe) sends the selected text as standard input to the command that follows,
%% 		inserts the output to current position of current buffer.
%% 		if no text was selected then uses the whole buffer.
%%
%% &	executes the rest commands with the shell in the background and in new terminal.
%%
%%	Notes 4 JED:
%%		* In Unix command line option +N moves to N line. (-g N)
%%		* limited console command for sed lovers, /what, s/what/with[/g]
%%	
%%	Required for X Clipboard:
%%		xclip CLI utility
%%	

#ifndef CBRIEF_PATCH
fprintf(stderr, "no-CBRIEF patched version of jed found.\n");
fprintf(stderr, "Use this patched version https://github.com/nereusx/jedc\n");
error("CBRIEF C RTE: no-CBRIEF patched version of executable.");
quit_jed();
#else
public variable CBRIEF_API_RQ = 10;
if ( CBRIEF_API < CBRIEF_API_RQ ) {
	panic(sprintf("\n\n\
CBRIEF Jed patch: API version required %d, and found version %d.\n\
You need newer version of patched JED.\n\
Get it here https://github.com/nereusx/jedc\n", CBRIEF_API_RQ, CBRIEF_API));
	}
#endif

% () = evalfile("sys/mouse.sl");		% need fix: X11 + mouse clipboard
require("nc-utils");				% my basic utilities
require("sys/x-keydefs");			% fixed keys and keypad codes (jedmodes package)
require("nc-term");					% fixed keys and keypad codes (NDC package)
require("mm-briefmsc");				% Guenter Milde and Marko Mahnic BRIEF module
require("cbufed");					% list_buffers() replacement
require("chelp");					% help() replacement
require("view");					% view-mode patched (jedmodes package)
require("lib/mini");				% mini-read(...) (jedmodes package)
require("lib/history");				% histories for mini-read (jedmodes package)
require("tabs");					% JED's Tab_Stops and tabs_edit()
require("compile");					% JED's compiler modules
%require("register");				% JED's registers; (multiple clipboards) does not needed for CBRIEF

% bug hunting
_traceback = 1;
_debug_info = 1;
_slangtrace = 1;

public variable rc = rc_init(vdircat(Jed_Home_Directory, "data", "cbrief.rc"));
rc_load(rc);
public variable rcmem = rc_init("*mem*");

%% --- start here ---------------------------------------------------------

%!%+
%\variable{_cbrief_version}
%\synopsis{Numeric value of script version}
%\description
%	Numeric value of script version.
%!%-
public variable _cbrief_version = 0x10104;

%!%+
%\variable{_cbrief_version_string}
%\synopsis{String value of script version}
%\description
%	String value of script version.
%!%-
public variable _cbrief_version_string = "1.1.4";

%!%+
%\variable{CBRIEF_KBDMODE}
%\synopsis{keyboard mode}
%\description
%	Integer CBRIEF_KBDMODE = 0x20 | 0x08 | 0x04 | 0x02 | 0x01;
%	
%	This variable controls how the CBRIEF should work with keyboard.
%
%	Keyboard mode
%		0x00 = Default, Minimum BRIEF keys.
%		0x01 = Extentions in case of non-keypad/non-f-keys (alt+f/ctrl+f,..)
%		0x02 = Add Windows Clipboard keys (ctrl+c,x,v)
%		0x04 = Get control of window-keys
%		0x08 = Additional keys (alt+],alt+<,alt+>,...)
%		0x10 = Get control of line_indent
%		0x20 = Get control of Tabs
%		0x40 = LAPTOP mode (ctrl+left/right = home/end, ctrl+up/down = page up/down)
%		0x80 = Readline Home/End (ctrl+a/e = home/end)
%!%-
custom_variable("CBRIEF_KBDMODE", rc_geti(rc, "KBDMODE", 0x20 | 0x08 | 0x04 | 0x02 | 0x01 | 0x80));

%!%+
%\variable{CBRIEF_XTERM}
%\synopsis{terminal emulator}
%\description
% This variable is the x-terminal emulator that will be used by CBRIEF.
% By default has code to assign one when its needed.
% If user want something else can be set it in this variable.
%!%-
custom_variable("CBRIEF_XTERM", rc_gets(rc, "XTERM", "xterm"));

%!%+
%\variable{CBRIEF_MENU_BAR}
%\synopsis{Enable menu-bar}
%\description
% Sets it a non-zero values to enable menu-bar by default.
%!%-
custom_variable("CBRIEF_MENU_BAR", rc_geti(rc, "MENUBAR", 0));

% --------------------------------------------------------------------------------

%% This integera are for the communication with the C code.
%% 0x01 = X11 reversed cursor
%% 0x02 = Inclusive selection mode
%% 0x04 = Line selection mode
%% 0x08 = Column selection mode
CBRIEF_FLAGS = 0x01;
CBRIEF_SEL_LINE = 1;
CBRIEF_SEL_COL  = 1;

#ifnexists is_xjed
public define is_xjed()
	{ return is_defined("x_server_vendor"); }
#endif

% find a smart solution for clipboard, thrugh jed, tmux, terminal
public variable x_copy_region_to_cutbuffer_p = NULL;
%if ( is_defined("x_server_vendor") ) % xjed only
%	x_copy_region_to_cutbuffer_p = __get_reference("x_copy_region_to_cutbuffer");
public variable x_copy_region_to_selection_p = NULL;
%if ( is_defined("x_server_vendor") ) % xjed only
%	x_copy_region_to_selection_p = __get_reference("x_copy_region_to_selection");

public variable x_insert_cutbuffer_p = NULL;
%if ( is_defined("x_server_vendor") ) % xjed only
%	x_insert_cutbuffer_p = __get_reference("x_insert_cutbuffer");
public variable x_insert_selection_p = NULL;
%if ( is_defined("x_server_vendor") ) % xjed only
%	x_insert_selection_p = __get_reference("x_insert_selection");

_Jed_Emulation = "cbrief";
static variable _help_file = "cbrief.hlp";
Help_File = _help_file;

static variable _help_buf = "*help*";	% help-buffer name
static variable _long_help_file = "cbrief-l.hlp"; % full help file

static variable _cbrief_keymap;
private variable cbrief_macros_list;
private variable mac_index = Assoc_Type[List_Type];
private variable mac_index_init = 0;
private define cbrief_maclist_init();

% build assosiated array - index from the macros list
% this speed-ups the search by the macro name.
private define cbrief_build_cindex() {
	variable e;
	if ( typeof(cbrief_macros_list) != List_Type )
		cbrief_maclist_init();
	foreach e ( cbrief_macros_list ) 
		mac_index[e[0]] = e;
	mac_index_init ++;
	}
	
% run-time flags
private variable _block_search = 1;		% 1 = search/translate only inside blocks
private variable _search_forward = 1;	% search direction, >0 = forward, <0 = backward
private variable _regexp_search = 0;	% 1 = search/translate use regular expressions
private variable _search_case = 1;		% 1 = case sensitive search

% these flags can be used in the beginning of search string
static variable _pattern_begin_flag_char = '/';
static variable _pattern_end_flag_char = ';';
static variable _case_on = "/cs", _case_off = "/ci";
static variable _rege_on = "/re", _rege_off = "/nr";

private variable _has_set_last_macro = is_defined("set_last_macro");

private define cbrief_set_flags(n)		{ CBRIEF_FLAGS = CBRIEF_FLAGS | n;  }
private define cbrief_unset_flags(n)	{ CBRIEF_FLAGS = CBRIEF_FLAGS & ~n; }

%% --- utilities ----------------------------------------------------------
private define cbrief_readline_mode()	{ return (CBRIEF_KBDMODE & 0x80); }
private define cbrief_laptop_mode()		{ return (CBRIEF_KBDMODE & 0x40); }
private define cbrief_control_tabs()	{ return (CBRIEF_KBDMODE & 0x20); }
private define cbrief_control_indent()	{ return (CBRIEF_KBDMODE & 0x10); }
private define cbrief_more_keys()		{ return (CBRIEF_KBDMODE & 0x08); }
private define cbrief_control_wins()	{ return (CBRIEF_KBDMODE & 0x04); }
private define cbrief_windows_keys()	{ return (CBRIEF_KBDMODE & 0x02); }
private define cbrief_nopad_keys()		{ return (CBRIEF_KBDMODE & 0x01); }
public  define cbrief_set_laptop_mode()	{ CBRIEF_KBDMODE |= 0x40; }

private define onoff(val)
{ return ( val ) ? "on" : "off"; }

public define __push_argv(a)
{ foreach ( a ) (); }

public define cbrief_reset();
public define cbrief_setkey(func, key);

static variable _u8sym = [
	{ 'f', '↓' }, { 'd', '↓' },	{ 'b', '↑' }, { 'u', '↑' },	{ 'l', '←' }, { 'r', '→' },
	{ '@', '■' }, { '.', '…' },	{ '[', '“' }, { ']', '”' }, { '{', '‹' }, { '}', '›' }, { '`', '‘' }, { '\'', '’' },
	{ 'x', '※' }, { '+', '†' }, { '#', '‡' }, { '-', '━' },	{ '|', '┃' }, { 'p', '±' }, { '(', '⟨' }, { ')', '⟩' },
	{ '2', '²' }, { '3', '³' },	{ '$', '§' }, { '*', '•' },	{ 'T', '‥' }, { 'o', '°' },
	{ '<', '«' }, { '>', '»' }, { 'E', '⏎' }, { 'w', '↩' },
% control chars
	{ '0', '␀' },  { '\e', '␛' }, { ' ', '␠' }, { '\t', '␉' }, { '\r', '␍' }, { '\n', '␊' },
	{ '\a', '␇' }, { '\b', '␈' }, { '\v', '␋' }, { '\f', '␌' },
% greek
	{ '·', '·' }, { '&', 'ϗ' }, { 'Q', 'Ϙ' }, { 'q', 'ϙ' },	{ 'Τ', 'Ϛ' }, { 'τ', 'ϛ' }, { 'Γ', 'Ϝ' }, { 'γ', 'ϝ' },
	{ 'Σ', 'Ϲ' }, { 'σ', 'ϲ' }, { 'ε', 'ϵ' }, { 'Μ', 'Ϡ' },	{ 'μ', 'ϡ' }, { ':', '⁝' }, { 'Ε', 'Є' } ];

% prefer abbrev, this is palette for cbrief.sl
private define _get_symbol(ch) {
	if ( _slang_utf8_ok ) {
		variable i, l = length(_u8sym);
		for ( i = 0; i < l; i ++ ) {
			if ( _u8sym[i][0] == ch )
				return _u8sym[i][1];
			}
		}
	return ch;
	}

%%
define cbrief_print_help_descr(descr) {
	variable s, a, i, title, text;
	variable color_normal, color_bold, color_italics;
	
	color_normal  = color_number("normal");
	color_bold    = color_number("bold");
	color_italics = color_number("italic");

	s = strtrans(descr, "\t", " ");
	a = strchop(s, '\n', 0);
	title = strtrim(a[0]);
	text  = strtrim(a[1]);
	insert(sprintf("\033[%d]%s\033[%d]\n\n\t", color_bold, title, color_normal));
	if ( isalpha(text[0]) )
		insert_paragraph(text);
	else
		insert(text);
	for ( i = 2; i < length(a); i ++ ) {
		insert("\n\t");
		text = strtrim(a[i]);
		if ( isalpha(text[0]) )
			insert_paragraph(text);
		else
			insert(text);
		}
	insert("\n\n");
	}

%% show help window, short version
define cbrief_help() {
	variable arg = (_NARGS) ? () : NULL;
	variable e, i, s, a, c, title, text;
	variable bufname = "*help*";
	
	if ( arg != NULL ) {
		bufname = sprintf("* Help: %s *", arg);
		sw2buf(bufname);
		unset_buffer_flag(0x08); % read-only
		erase_buffer();
		WRAP = SCREEN_WIDTH - 4;
%%		vinsert("--- Automatic Genereted Documentation (%s) ---\n\n", arg);
		if ( arg == "list" ) {
   			a = assoc_get_keys(mac_index);
			a = a[array_sort(a)];
			for ( i = 0; i < length(a); i ++ ) {
				e = mac_index[a[i]];
				if ( length(e) >= 4 && e[3] != NULL ) 
					cbrief_print_help_descr(e[3]);
				else if ( e[2] == 7 )
					insert(sprintf("%s\n\n\tAlias of '%s'.\n\n", e[0], e[1]));
				else
					insert(sprintf("%s\n\n\tNo description available yet.\n\n", e[0]));
				}
			}
		else if ( arg == "keys" ) {
			variable map = what_keymap ();
			variable buf = whatbuf ();
			variable cse = CASE_SEARCH; CASE_SEARCH = 1;
			dump_bindings (map);

			if ( map != "global" ) {
				variable dump_end_mark = create_user_mark();
				insert("\nInherited from the global keymap:\n");
				push_spot();
				dump_bindings("global");
				pop_spot();
				
				variable global_map = Assoc_Type[String_Type, ""];
				while ( not eobp() ) {
					push_mark();
					() = ffind("\t\t\t");
					variable key = bufsubstr();
					go_right (3);
					push_mark();
					% Could have a newline here
					ifnot (fsearch("\t\t\t")) eob ();
					go_up_1();
					() = dupmark();
					global_map[key] = bufsubstr();
					del_region ();
					delete_line ();
					}

				bob();
				forever {
					push_mark();
					() = ffind("\t\t\t");
					key = bufsubstr();
					if ( key == "" ) break;

					variable global_map_key = global_map[key];
					go_right(3);
					if ( global_map_key != "" ) {
						push_mark();
						() = fsearch("\t\t\t");
						if (create_user_mark() > dump_end_mark)
						goto_user_mark(dump_end_mark);
						go_up_1();
						() = dupmark();
						
						if (bufsubstr() == global_map_key) {
							del_region ();
							delete_line ();
							push_spot();
							eob();
							(global_map_key,) = strreplace (global_map_key, "\n", "\\n", strlen(global_map_key));
							vinsert ("%s\t\t\t%s\n", key, global_map_key);
							pop_spot();
							}
						else {
							pop_mark_0();
							go_down_1 ();
							}
						}
					else {
						() = fsearch ("\t\t\t");
						bol ();
						}
					}
				}
			else {
				bob();
				while ( not eobp() ) {
					ifnot (ffind("\t\t\t"))	{
						go_up_1();
						insert("\\n");
						del();
						}
					if ( 0 == down_1() ) break;
					}
				}
			
			bob();
			do {
				push_mark ();
				if (not (ffind("\t\t\t"))) {
					pop_mark(0);
					continue;
					}
			
				key = bufsubstr();
				variable old_len = strlen(key);
				(key,) = strreplace(key, "ESC", "\e", strlen(key));
				key = str_delete_chars(key, " ");
				(key,) = strreplace(key, "SPACE", " ", strlen(key));
				(key,) = strreplace(key, "DEL", "\x7F", strlen(key));
				(key,) = strreplace(key, "TAB", "\t", strlen(key));
				bol();
				() = replace_chars(old_len, expand_keystring(key));
			
				if (what_column () <= TAB)
					insert_char('\t');
				else {
					if ( what_column() <= TAB*4 )
						deln( (what_column()-1)/TAB - 1 );
					else
						deln(3);
					}
				} while ( down_1() );

			%% remove useless info
			bob();
			while ( fsearch("self_insert_cmd") ) {
				delete_line();
				bob();
				}
			CASE_SEARCH = cse;
			}
		else {
			try {
				e = mac_index[arg];
				if ( length(e) >= 4 && e[3] != NULL )
					cbrief_print_help_descr(e[3]);
				else if ( e[2] == 7 )
					insert(sprintf("%s\n\n\tAlias of '%s'.\n\n", e[0], e[1]));
				else
					insert(sprintf("%s\nNo description yet.\n\n"));
				} catch AnyError: { insert(sprintf("%s, not found.\n\n", arg)); } % just not found
			}
		bob();
		unset_buffer_flag(0x01); % not modified			
		set_buffer_flag(0x1000); % enable escape codes
		set_buffer_flag(0x0008); % read-only
		view_mode();
		return;
		}
			
	if ( bufferp(_help_buf) && whatbuf() != _help_buf ) {
		delbuf(_help_buf);
		onewindow();
		}
	else
		chelp(_help_file);
	}

%% one window, the whole help file
define cbrief_long_help() {
	variable file = expand_jedlib_file(_long_help_file);
	if ( bufferp(_help_buf) && whatbuf() != _help_buf ) {
		delbuf(_help_buf);
		onewindow();
		}
	else
		chelp(file, 1);
	}

%!%+
%\function{filefmt}
%\usage{String filefmt(fmt, filename)}
%\synopsis{Returns parts of filename according the fmt}
%\description
%  Returns parts of filename according the fmt.
%!%-
public define filefmt(cmd, file) {
	cmd = str_replace_all(cmd, "%p", file); % full pathname
	cmd = str_replace_all(cmd, "%d", dirname(file)); % directory
	cmd = str_replace_all(cmd, "%f", basename(file)+file_ext(file)); % basename + extension
	cmd = str_replace_all(cmd, "%b", basename(file)); % basename without extension
	cmd = str_replace_all(cmd, "%e", file_type(file)); % extension without dot
	return cmd;
	}
	
%% --- keyboard -----------------------------------------------------------

% completion: filename
public define mini_selfile() {
	variable part, file;
	push_spot();
	push_mark();
	bskip_word_chars();
	part = bufsubstr();
	file = dlg_selectfile("File", part+"*");
	scr_touch();
	if ( markp() )
		pop_mark_0();
	if ( file != NULL ) { 
		file = strtrim(file);
		bol(); del_eol();
		insert(file);
		}
	pop_spot();
	}

% completion: filename, allow new names
public define mini_editfile() {
	variable part, file;
	push_spot();
	push_mark();
	bskip_word_chars();
	part = bufsubstr();
	file = dlg_openfile("File", part+"*");
	scr_touch();
	if ( markp() )
		pop_mark_0();
	if ( file != NULL ) { 
		file = strtrim(file);
		bol(); del_eol();
		insert(file);
		}
	pop_spot();
	}

%% comma separated, macros list, needed here
public variable mac_opts = "";

% complation: select from list
public define mini_sellist(clist) {
	variable part, mlist;
	variable n = 0, mcount, pbuf;
	variable mbuf = " <mini>";

	pbuf = whatbuf();
	setbuf(mbuf);
	push_spot();
	push_mark();
	bskip_word_chars();
	part = bufsubstr();
	if ( markp() )
		pop_mark_0();

	if ( String_Type == typeof(part) )
		n = strlen(part);

	mlist = strchop(clist, ',', 0);
	mlist = mlist[array_sort(mlist)];
	mlist = mlist[where(strncmp(mlist,part,n)==0)];
	mcount = length(mlist);
	
	%% results
	if ( mcount == 0 )
		uerror("No solution found!");
	else if ( mcount == 1 ) { % sole solution
		bol(); del_eol();
		insert(mlist[0]);
		mesg("Sole solution!");
		}
	else {
		n = dlg_listbox3("Select", mlist, 0);
		scr_touch();
		if ( n >= 0 ) {
			bol(); del_eol();
			insert(mlist[n]);
			}
		}
	pop_spot();
	}

% setup completion routine for tab.
static define set_mini_complete(slfunc) {
	variable	m = "Mini_Map";
	undefinekey("\t", m);
	if ( slfunc == NULL )
		definekey("mini_complete", "\t", m);
	else 
		definekey(slfunc, "\t", m);
	}

% read an integer
private define read_mini_int(prompt, defval, val) {
	variable s = read_mini(prompt, defval, val);
	if ( s == NULL ) return 0;
	return atoi(s);
	}

% read filename
public define read_mini_filename(prompt, defval, val) {
	variable status;
	set_mini_complete("mini_selfile");
    mini_use_history("filename");
	variable file = read_mini(prompt, defval, val);
    mini_use_history(NULL);   % restore default history
	set_mini_complete(NULL);
	if ( file == NULL ) return NULL; else file = strtrim(file);
	if ( strlen(file) == 0 ) return NULL;
	status = file_status(file);
	if ( status == 1 ) return file;
	else if ( status ==  2 )	uerrorf("File '%s' is directory!", file);
	else if ( status ==  0 )	uerrorf("File '%s' does not exist!", file);
	else if ( status == -1 )	uerrorf("Access denied!");
	return NULL;
	}

% read directory
public define read_mini_dir(prompt, defval, val) {
	variable status;
%	set_mini_complete("mini_seldir");
    mini_use_history("directory");
	variable file = read_mini(prompt, defval, val);
    mini_use_history(NULL);   % restore default history
%	set_mini_complete(NULL);
	if ( file == NULL ) return NULL; else file = strtrim(file);
	if ( strlen(file) == 0 ) return NULL;
	status = file_status(file);
	if ( status == 2 ) return file;
	else if ( status ==  1 )	uerrorf("'%s' is a regular file!", file);
	else if ( status ==  0 )	uerrorf("'%s' does not exist!", file);
	else if ( status == -1 )	uerrorf("Access denied!");
	return NULL;
	}

% read filename; allow new files
public define read_mini_filename_new(prompt, defval, val) {
	set_mini_complete("mini_editfile");
    mini_use_history("filename");
	variable file = read_mini(prompt, defval, val);
    mini_use_history(NULL);   % restore default history
	set_mini_complete(NULL);
	if ( file == NULL ) return NULL; else file = strtrim(file);
	if ( strlen(file) == 0 ) return NULL;	
%	status = file_status(s);
%	else if ( status ==  0 )	uerrorf("'%s' does not exist!", file);
%	else if ( status ==  1 )	uerrorf("'%s' is a regular file!", file);
%	else if ( status ==  2 )	uerrorf("'%s' is a directory!", file);
%	else if ( status == -1 )	uerrorf("Access denied!");
	return file;
	}

% read_mini(prompt, LAST_SEARCH, "");
public variable LAST_SEARCH = "";
public define read_mini_search(prompt, defval, val) {
    mini_use_history("search");
	variable file = read_mini(prompt, defval, val);
    mini_use_history(NULL);   % restore default history
	if ( file == NULL ) return NULL; else file = strtrim(file);
	if ( strlen(file) == 0 ) return NULL;
	return file;
	}

% read_mini(prompt, LAST_REPLACE, "");
public variable LAST_RSEARCH = "";
public variable LAST_REPLACE = "";
public define read_mini_replace(prompt, defval, val) {
    mini_use_history("replace");
	variable s = read_mini(prompt, defval, val);
    mini_use_history(NULL);   % restore default history
	if ( s == NULL ) return NULL; else s = strtrim(s);
	if ( strlen(s) == 0 ) return NULL;
	return s;
	}

public define read_mini_buffer(prompt, defval, val) {
    mini_use_history("buffer");
	variable s = read_mini(prompt, defval, val);
    mini_use_history(NULL);   % restore default history
	if ( s == NULL ) return NULL; else s = strtrim(s);
	if ( strlen(s) == 0 ) return NULL;
	return s;
	}

%% quote - insert the keycode
define cbrief_quote() {
	mesg("Press key:"); update(1);
	forever {
		variable c = getkey();
		insert((c == 0) ? "^@" : char(c));
		ifnot ( input_pending(1) )	break;
		}
	}

%% handle ESC/Quit key (\e\e\e)
define cbrief_escape() {
	if ( is_visible_mark() )	pop_mark_0();
	call("kbd_quit");
	if ( input_pending(1) )	flush_input();
	}

%% the enter key
define cbrief_enter() {
	variable flags;
	(,,,flags) = getbuf_info();
	newline();
	ifnot ( flags & 0x10 ) % not overwrite mode
		indent_line();
	}

%% the backspace key
define cbrief_backspace() {
	% creates RTE in minibuf
	try { call("backward_delete_char"); } catch AnyError: { }
	}

%% clear keyboard buffer
define cbrief_flush_input() {
	ifnot ( EXECUTING_MACRO or DEFINING_MACRO )
		if ( input_pending(1) )
			flush_input();
	}

%% copy from emacsmsc
define scroll_up_in_place () {
	variable m = window_line ();
	if ( down_1() ) recenter (m);
	bol();
	}

%% copy from emacsmsc
define scroll_down_in_place () {
	variable m = window_line ();
	if ( up_1() ) recenter (m);
	bol();
	}

%% --- basic commands -----------------------------------------------------

%% display BRIEF's version
define cbrief_disp_ver() {
	mesgf("JED:%s, SLang:%s, JED-Patch: %d, CBRIEF:%s",
		_jed_version_string, _slang_version_string,
		CBRIEF_API, _cbrief_version_string);
	}

%% display the current buffer filename
define cbrief_disp_file() {
	variable file = buffer_filename();
	if ( buffer_modified() )	file += "*";
	mesgf("File: %s", strfit(file, window_info('w') - 6, -1));
	}

% jump to next word
define cbrief_next_word() {
	if ( isalnum(what_char()) )	skip_word_chars();
	skip_non_word_chars();
	}

% jump to previous word
define cbrief_prev_word() {
	if ( isalnum(what_char()) )	bskip_word_chars();
	bskip_non_word_chars();
	bskip_word_chars();
	}

% jump to line number
define cbrief_goto_line() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable n = (argc) ? atoi(argv[0]) : read_mini_int("Go to line:", "", "");
	if ( n >= 1 ) goto_line(n);
	}

% jump to column number
define cbrief_goto_column() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable n = (argc) ? atoi(argv[0]) : read_mini_int("Go to column:", "", "");
	if ( n >= 1 ) goto_column(n);
	}

%% count buffers with enabled flag
define count_buffers(flag) {
	variable count = buffer_list(), i, list;
	variable n = 0, buf, pbuf, flags;

	if ( count == 0 ) return 0;
	list  = list_to_array(__pop_list(count));
	pbuf = whatbuf();
	for ( i = 0; i < count; i ++ ) {
		buf = list[i];
		if ( buf[0] == ' ' || buf[0] == '*' ) continue;
		setbuf(buf);
		( , , , flags) = getbuf_info();
		if ( flags & flag ) n ++;
		}
	setbuf(pbuf);
	return n;
	}

% normal exit of program
public define cbrief_exit() {
	variable m = 0, p = "", key, s;
	variable arg = (_NARGS) ? () : NULL;

	m = count_buffers(0x01);
	if ( m == 0 ) {
		try { exit_jed(); } catch AnyError: { quit_jed(); }
		}
	else {
		if ( arg != NULL )
			s = arg;
		if ( m == 1 ) p = "One buffer has not been saved. Exit [ynw] ?";
		else p = sprintf("%d buffers has not been saved. Exit [ynw] ?", m);
		do {
%			key = get_mini_response(p, "y", ""); % something wrong sometimes
			if ( arg == NULL )
				s = strtrim(read_mini(p, "y", ""));
			key = tolower(s[0]);
			if ( key == 'w' ) { save_buffers(); exit_jed(); break; }
			if ( key == 'y' ) { quit_jed(); break; }
			if ( key == 'q' ) { quit_jed(); break; }
			if ( key == 'n' ) break;
			arg = NULL;
			} while ( 1 );
		}
	}

%% write region or file to disk
public define cbrief_write() {
	variable ex, nl = 0, err = 0;
	variable file = ( _NARGS ) ? () : "";
	
	if ( is_visible_mark() ) {
		ifnot ( strlen(file) )
			file = read_mini_filename_new("Write block as:", "", "");
		ifnot ( file == NULL ) {
			try(ex) { nl = write_region_to_file(file); }
			catch AnyError: { buflogf("Caught %s, %s:%d -- %s", ex.descr, ex.file, ex.line, ex.message); err = 1; }
			ifnot ( err ) mesg("Write successful.");
			}
		}
	else {
		ifnot ( strlen(file) )
			file = buffer_filename();
		if ( buffer_modified() ) {
			ifnot ( strlen(file) )
				file = read_mini_filename_new("Write to file:", file, "");
			if ( file != NULL ) {
				try(ex) {
					nl = write_buffer(file);
					} catch AnyError: { buflogf("Caught %s, %s:%d -- %s", ex.descr, ex.file, ex.line, ex.message); err = 1; }
				ifnot ( err )
					mesg("Write successful.");
				}
			}
		else
			mesg("File has not been modified -- not written.");
		}
	}

%
public define cbrief_buffer_save_as() {
	variable file = (_NARGS) ? () : NULL;

	if ( file == NULL )
		file = read_mini_filename_new("Enter new filename:", buffer_filename(), file);
	ifnot ( file == NULL ) {
		if ( strlen(file) ) 
			cbrief_write(file);
		}
	}

%% warning: does not save the file, it just change the name in its memory; like the original BRIEF
define cbrief_output_file() {
	variable newname_rq = ( _NARGS ) ? 1 : 0;
	variable file = ( _NARGS ) ? () : "";
	variable dir, flags, name, e;

	ifnot ( is_readonly() ) {
		if ( strlen(file) == 0 )
			file = buffer_filename();
		ifnot ( newname_rq )
			file = read_mini_filename_new("Enter new output file name:", file, file);
		if ( file == NULL ) return;

		e = file_status(file);
		if ( e == 0 || e == 1 ) {
			(, dir, name, flags) = getbuf_info ();
			if ( path_is_absolute(file) ) {
				dir = path_dirname(file);
				file = path_basename(file);
				name = file;
				}
			else {
				file = path_basename(file);
				name = file;
				}
			setbuf_info(file, dir, name, flags);
			set_buffer_modified_flag(1);
			mesg("Name change successful.");
			}
		else uerror("Invalid output file name.");
		}
	else uerror("Buffer is read-only.");
	}

%% inserts character by ascii code
define cbrief_ascii_code() {
	variable n, in = (_NARGS) ? () : read_mini("ASCII code:", "", "");
	ifnot ( in == NULL ) {
		n = ( typeof(in) == String_Type ) ? atoi(in) : in;
		insert((char)(n));
		}
	}

%% --- toggles ------------------------------------------------------------

%% set_backup macro
define	cbrief_toggle_backup() {
	toggle_buffer_flag(0x100);
	mesgf("Backup is: %s", onoff(test_buffer_flag(0x100)));
	}

%%
define	cbrief_toggle_autosave() {
	toggle_buffer_flag(0x02);
	mesgf("Autosave is: %s", onoff(test_buffer_flag(0x02)));
	}

%% toggle_re macro
define cbrief_toggle_re() {
	_regexp_search = not (_regexp_search);
	mesgf("Regular expression search is %s.", onoff(_regexp_search));
	}

%% search_case macro
define cbrief_search_case() {
	_search_case = not (_search_case);
	mesgf("Case sensitive search is %s.", onoff(_search_case));
	}

%% block_search macro
define cbrief_block_search() {
	_block_search = not (_block_search);
	mesgf("Block search is %s.", onoff(_block_search));
	}

%% toggle menu
define cbrief_toggle_menu() {
	CBRIEF_MENU_BAR = not (CBRIEF_MENU_BAR);
	enable_top_status_line(CBRIEF_MENU_BAR);
	}

%% --- bookmarks ----------------------------------------------------------

private variable max_bookmarks = 10;
private variable bookmarks = Mark_Type[max_bookmarks];

% get bookmarks as string to save in file
public define cbrief_get_bkstring() {
	variable cbuf = whatbuf(), cline = what_line();
	variable buf, line, i, s, sp, st, mrk;

	s = "";
	for ( i = 0; i < max_bookmarks; i ++ ) {
		mrk = bookmarks[i];
		if ( mrk != NULL ) {
			sp = s;
			try {
				buf = mrk.buffer_name;
				if ( bufferp(buf) ) {
					sw2buf(buf);
					goto_user_mark(mrk);
					line = what_line();
					if ( strlen(s) ) s += "|";
					st = sprintf("%d|%s|%d", i+1, buf, line);
					s += st;
					}
				} catch AnyError: { s = sp; }
			}
		}
	setbuf(cbuf);
	goto_line(cline);
	return s;
	}

% drop bookmark
define	cbrief_bkdrop() {
	variable n, in = (_NARGS) ? () : NULL;

	if ( in == NULL ) in = read_mini_int("Drop bookmark [1-10]:", "", "");
	ifnot ( in == NULL ) {
		n = (String_Type == typeof(in)) ? atoi(in) : in; n --;
		if ( n < 0 || n > (max_bookmarks - 1) )
			uerror("Invalid bookmark number.");
		else {
			bookmarks[n] = create_user_mark();
			mesg("Bookmark dropped.");
			}
		}
	}

% set bookmarks from string 
public define cbrief_set_bkstring(s) {
	variable a, i, n, b, c;
	variable cbuf = whatbuf(), cline = what_line();
	a = strchop(s, '|', 0);
	if ( length(a) > 1 ) {
		for ( i = 0; i < length(a); i += 3 ) {
			n = atoi(a[i+0]);
			b = a[i+1]; c = atoi(a[i+2]);
			if ( bufferp(b) ) {
				sw2buf(b);
				goto_line(c);
				cbrief_bkdrop(n);
				}
			}
		}
	sw2buf(cbuf);
	goto_line(cline);
	}

% jump to bookmark
define	cbrief_bkgoto() {
	variable n, in = (_NARGS) ? () : NULL;

	if ( in == NULL ) in = read_mini_int("Go to bookmark [1-10]:", "", "");
	ifnot ( in == NULL ) {
		n = (String_Type == typeof(in)) ? atoi(in) : in; n --;
		if ( n < 0 || n > (max_bookmarks - 1) )
			uerror("Invalid bookmark number.");
		else {
			variable mrk = bookmarks[n];
			if ( mrk == NULL )
				uerror("That bookmark does not exist.");
			else {
				if ( bufferp(mrk.buffer_name) ) {
					sw2buf(mrk.buffer_name);
					goto_user_mark(mrk);
					}
				}
			}
		}
	}

%% --- regions ------------------------------------------------------------

%% what content type we have in scrap
private variable _scrap_type = 0;
private variable _use_clip = 0; % clipboard to use, 0 = internal, 1 = X clip...
define cbrief_mark();

public define xclip_to() {
	variable text = (_NARGS) ? () : NULL;
	try {
		if ( text == NULL )
			() = pipe_region("xclip -sel clip -i");
		else
			() = system(sprintf("echo '%s' | xclip -sel clip -i", text));
		}
	catch RunTimeError:	{ uerror("xclip not available: can not write to clipboard"); }		
	}
public define xclip_from() {
	try { () = run_shell_cmd("xclip -sel clip -o"); }
	catch RunTimeError:	{ uerror("xclip not available: can not read from clipboard"); }
	}
% xclip [{ -i | -o }] [text]
public define xclip() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable mode, text = "";
	if ( argc == 0 ) {
		if ( is_visible_mark() )
			xclip_to();
		else
			xclip_from();
		}
	else {		
		mode = ( argv[0][0] == '-' ) ? argv[0][1] : 'o';
		text = ( argv[0][0] == '-' ) ? NULL : argv[0];		
		if ( argc == 2 )
			text = argv[1];
		if ( mode == 'i' ) {
			push_spot();
			if ( text == NULL ) {
				ifnot ( is_visible_mark() )
					{ bol(); push_mark(); eol(); }
				xclip_to();
				}
			else
				xclip_to(text);
			pop_spot();
			}
		else
			xclip_from();
		}
	}

%% X Windows Copy/Paste
%% copy selection to X
define cbrief_xcopy() {
	variable bpop = 0;
	ifnot ( Brief_Mark_Type ) {
		push_spot();
		bol(); push_mark(); eol();
		Brief_Mark_Type = 3;
		bpop = 1;
		}
	else if ( Brief_Mark_Type == 3 ) {
		push_spot();
		eol();
		bpop = 1;
		}

	_scrap_type = Brief_Mark_Type;
	if ( is_visible_mark() && (CBRIEF_FLAGS & 0x02)
		&& ( Brief_Mark_Type == 1 || Brief_Mark_Type == 2) ) {
		check_region(0);
		call("next_char_cmd");
		}
%#ifdef MOUSE
%	copy_kill_to_mouse_buffer();
%#endif
	if ( x_copy_region_to_cutbuffer_p != NULL )
		x_copy_region_to_cutbuffer_p();
	else {
		try { () = pipe_region("xclip -sel clip -i"); }
		catch RunTimeError:	{ uerror("xclip not available: can not write to clipboard"); }		
		}
	cbrief_mark(0);
	if ( bpop ) pop_spot();
	mesg("Text copied to X Clipboard.");
	}

%% cut selection to X 
define cbrief_xcut() {
	variable bpop = 0;
	ifnot ( Brief_Mark_Type ) {
		Brief_Mark_Type = 3;
		push_spot();
		bol(); push_mark(); eol();
		bpop = 1;
		}
	else if ( Brief_Mark_Type == 3 ) {
		push_spot();
		eol();
		bpop = 1;
		}
	_scrap_type = Brief_Mark_Type;
	if ( is_visible_mark() && (CBRIEF_FLAGS & 0x02)
		&& ( Brief_Mark_Type == 1 || Brief_Mark_Type == 2) ) {
		check_region(0);
		call("next_char_cmd");
		}
%#ifdef MOUSE
%	copy_kill_to_mouse_buffer();
%#endif
	if ( x_copy_region_to_cutbuffer_p != NULL )
		x_copy_region_to_cutbuffer_p();
	else {
		try { () = pipe_region("xclip -sel clip -i"); }
		catch RunTimeError:	{ uerror("xclip not available: can not write to clipboard"); }		
		}
	brief_kill_region();
	cbrief_mark(0);	
	if ( bpop ) { pop_spot(); }
	mesg("Text deleted to X Clipboard.");
	}

%% paste from X
define cbrief_xpaste() {
	variable file, dir, flags, name;
	variable mode, mflags;

	(file, dir, name, flags) = getbuf_info ();
	(mode, mflags) = what_mode();
	set_mode("text", 0);
	setbuf_info(file, dir, name, flags | 0x10); % set overwrite mode
	if ( x_insert_cutbuffer_p != NULL )
		() = x_insert_cutbuffer_p();
	else {
		try { () = run_shell_cmd("xclip -sel clip -o"); }
		catch RunTimeError:	{ uerror("xclip not available: can not read from clipboard"); }
		}
	set_mode(mode, mflags);
	setbuf_info(file, dir, name, flags);
	if ( _scrap_type == 3 )
		newline();
	mesg("Text inserted from X Clipboard.");
	}

%%
define cbrief_toggle_xclip() {
	_use_clip ++;
	if ( _use_clip > 1 )
		_use_clip = 0;	
	switch ( _use_clip )
	{ case 1: mesg("Local clipboard switched to X Windows."); }
	{ case 0: mesg("Local clipboard switched to INTERNAL."); }
	}

%%
define cbrief_mark() {
	variable n = (_NARGS) ? () : 0;
	if ( typeof(n) == String_Type )	n = atoi(n);

	% reset --- we dont know what brief-* command did yet
	% 		pop_mark() must be do with cbrief_mark(0);
	CBRIEF_SEL_COL  = 1;
	CBRIEF_SEL_LINE = 1;
	Brief_Mark_Type = 0;
	cbrief_unset_flags(0x06);
	if ( is_visible_mark() ) {
		pop_mark_0();
		return;
		}

	%
	if ( n ) {
		CBRIEF_SEL_COL  = what_column();
		CBRIEF_SEL_LINE = what_line();
		}
	switch ( n )
	{ case 0: Brief_Mark_Type = 0; } % reset 
	{ case 1:
		cbrief_set_flags(0x02);			% inclusive [character under the cursor] simple
		brief_set_mark_cmd(1);
		}
	{ case 2:
		Brief_Mark_Type = 2;
		cbrief_set_flags(0x08 | 0x02);	% column & inclusive
		set_mark_cmd ();
    mesg("Column mark set.");
		}
	{ case 3:
		Brief_Mark_Type = 3;
		cbrief_set_flags(0x04);			% select whole lines
		bol();set_mark_cmd();eol();
		mesg("Line mark set.");
		}
	{ case 4: brief_set_mark_cmd(4); }	% simple non-inclusive
	{ uerror("Use 'mark 0..4'"); }
	}

define cbrief_reset_mark()	{ cbrief_mark(0); }		% remove any selection if exist...
define cbrief_stdmark()		{ cbrief_mark(1); }		% standard mark (include cursor point)
define cbrief_mark_column() { cbrief_mark(2); }		% column mark (include cursor point)
define cbrief_line_mark()	{ cbrief_mark(3); }		% line block mark
define cbrief_noinc_mark()	{ cbrief_mark(4); }		% non-inclusive mark

%% cut
define cbrief_cut() {
	if ( _use_clip == 1 ) { cbrief_xcut(); return; }
	ifnot ( Brief_Mark_Type) Brief_Mark_Type = 3; % copy current line
	_scrap_type = Brief_Mark_Type;
	if ( is_visible_mark() && (CBRIEF_FLAGS & 0x02)
		 && ( Brief_Mark_Type == 1 || Brief_Mark_Type == 2) ) {
		check_region(0);
		call("next_char_cmd");
		}
	brief_kill_region();
	cbrief_mark(0);
	switch ( _scrap_type )
	{ case 1 or case 4: mesg("Block deleted to scrap.");	}
	{ case 2: mesg("Column(s) deleted to scrap.");	}
	{ case 3: mesg("Line(s) deleted to scrap.");	}
	}

%% copy
define cbrief_copy() {
	if ( _use_clip == 1 ) { cbrief_xcopy(); return; }
	ifnot ( Brief_Mark_Type ) Brief_Mark_Type = 3; % copy current line
	_scrap_type = Brief_Mark_Type;
	push_spot();
	if ( is_visible_mark() && (CBRIEF_FLAGS & 0x02)
		 && ( Brief_Mark_Type == 1 || Brief_Mark_Type == 2) ) {
		check_region(0);
		call("next_char_cmd");
		}
	brief_copy_region();
	cbrief_mark(0);
	pop_spot();
	switch ( _scrap_type )
	{ case 1 or case 4: mesg("Block copied to scrap.");	}
	{ case 2: mesg("Column(s) copied to scrap.");	}
	{ case 3: mesg("Line(s) copied to scrap.");	}
	}

%% paste
define cbrief_paste() {
	if ( _use_clip == 1 ) { cbrief_xpaste(); return; }
	switch ( _scrap_type )
	{ case 1 or case 4: call("yank"); mesg("Scrap inserted.");}
	{ case 2: insert_rect(); mesg("Columns inserted."); }
	{ case 3: bol(); call("yank"); mesg("Lines inserted."); }
	{ uerror("No scrap to insert."); }
	}

%% delete block or character
define cbrief_delete() {
	if ( is_visible_mark() ) {
		if ( (CBRIEF_FLAGS & 0x02)
			 && ( Brief_Mark_Type == 1 || Brief_Mark_Type == 2 ) ) {
			check_region(0);
			call("next_char_cmd");
			}
		brief_delete();
		cbrief_mark(0);
		}
	else 
		del();
	}

%% for each line of the region calls the do_line
private define cbrief_block_do(do_line) {
	if ( is_visible_mark() ) {
		dupmark();
		check_region(0);
		variable end_line = what_line();
		exchange_point_and_mark();
		loop ( end_line - what_line() + 1 )  {
			(@do_line)();
			go_down_1();
			}
		if ( markp() )
			pop_mark_0();
		}
	}

%% transform block (xform_region parameters)
define cbrief_block_to(c) {
	push_spot();
	if ( is_visible_mark() ) {
		if ( Brief_Mark_Type == 3 ) % line mark
			eol();
		xform_region(c);
		}
	else {
		bol();
		set_mark_cmd();
		eol();
		xform_region(c);
		if ( markp() )
			pop_mark_0();
		}
	pop_spot();
	}

%% --- tabs ---------------------------------------------------------------

%%
%%	Brief Manual
%%	------------
%%	Normally, Tab moves the cursor to the next tab stop on the current line.
%%	Back Tab moves the cursor to the previoys tab stop,	or to the beginning
%%	of the line.
%%
%%	A block is marked...
%%	
%%	In this situation, Tab acts as though it had been pressed at the first
%%	character of every line in the block, which shifts the block right by
%%	one tab stop.
%%
%%	Back Tab has the opposite effect, shifting a block left by one tab stop.
%%	It only shifts lines that begin with tabs or spaces.
%%

%% use_tab_char(t/f)
define	cbrief_use_tab() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable o;
	
	if ( argc )
		o = argv[0];
	else
		o = read_mini("Fill with tab chars [yn] ?", "", ((USE_TABS)?"y":"n"));
	if ( o[0] =='n' || o[0] == 'N' || o[0] == '0' || o[0] == 'f' )
		USE_TABS = 0;
	else
		USE_TABS = 1;
	mesgf("Use tabs is %s.", (USE_TABS) ? "ON" : "OFF");
%	return USE_TABS;	% current value
	}

%%
define cbrief_line_indent() {
	if ( is_readonly() ) return;
	bol();
	insert("\t");
	}

%%
define cbrief_line_outdent() {
	variable c;
	
	if ( is_readonly() ) return;
	bol();
	loop ( TAB ) {
		if ( eolp() )
			break;
		c = what_char();
		switch ( c )
		{ case ' ':  del(); }
		{ case '\t': del(); break; }
		{ break; }
		}
	}

%% tab			
define cbrief_slide_in() {
	variable normal_tab = 0;
	
	if ( _NARGS ) {
		normal_tab = ();
		if ( typeof(normal_tab) == String_Type )
			normal_tab = atoi(normal_tab);
		}
	if ( is_readonly() ) return;

	push_spot();
	if ( is_visible_mark() )
		cbrief_block_do(&cbrief_line_indent);
	else if ( normal_tab == 0 )
		cbrief_line_indent();
	else {
		pop_spot();
		insert("\t");
		return;
		}
	pop_spot();
	}

%%
define cbrief_back_tab() {
	variable c, pre, goal, i;
	
	c = what_column ();
	pre = 1; goal = 1;
	foreach ( Tab_Stops ) {
		pre = goal;
		goal = ();
		if ( goal >= c ) break;
		}
	goto_column(pre);
	}

%% back tab - slide_out
define cbrief_slide_out() {
	variable normal_tab = 0;
	
	if ( _NARGS ) {
		normal_tab = ();
		if ( typeof(normal_tab) == String_Type )
			normal_tab = atoi(normal_tab);
		}
	
	push_spot();
	if ( is_visible_mark() )
		cbrief_block_do(&cbrief_line_outdent());
	else if ( normal_tab == 0 )
		cbrief_line_outdent();
	else {
		pop_spot();
		cbrief_back_tab();
		return;
		}
	pop_spot();
	}

%% in brief this function asks the whole tab stops for example 
%% tabs 5 % tab = 4
%% tabs 5 9
define cbrief_tabs() {
	variable argc = _NARGS, argv = __pop_list(argc);

	if ( argc == 0 ) {
		edit_tab_stops();
		return;
		}
	
	variable in, w, i;
	
	if ( argc == 0 )
		edit_tab_stops();
	else if ( argc == 1 ) {
		w = atoi(argv[0]) - 1;
		if ( w > 0 ) {
			TAB = w;
			Tab_Stops = [0:19] * TAB + 1;
			}
		else
			edit_tab_stops();
		}
	else {
		for ( i = 0; i < argc; i ++ ) 
			Tab_Stops[i] = atoi(argv[i]);
%		Tab_Stops[[i:]] = 0;
		}
	}

%% macro: insert() text into buffer
public define cbrief_insert() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable s = (argc) ? argv[0] : read_mini("Enter the text to insert:", "", "");
	if ( s != NULL ) insert(s);
	}

%% --- search -------------------------------------------------------------

% matching delimiters, the delimiter under the cursor
define cbrief_delim_match() {
	variable er, re = "[\{\}\(\)]", ch = what_char();

	if ( ch == '(' || ch == '[' || ch == '{' ||
		 ch == ')' || ch == ']' || ch == '}' ) {

		er = find_matching_delimiter(ch);
		if ( er != 1 )
			uerrorf("'%c' mismatch...", (char)(ch));
		else
		mesg("Found.");
		}
	else % otherwise go to the next delimiter
		er = re_fsearch(re);
	}

%%
static define cbrief_pattern_flags(pat) {
	variable cnt = 0, f, l;
	variable sflags = [_case_on, _case_off, _rege_on, _rege_off];
	forever {
		if ( pat[0] != _pattern_begin_flag_char ) return pat;
		foreach f ( sflags ) {
			l = strlen(f);
			if ( strncmp(pat, f, l) == 0 ) {
				if ( f == _case_on ) _search_case = 1;
				else if ( f == _case_off ) _search_case = 0;
				else if ( f == _rege_on  ) _regexp_search = 1;
				else if ( f == _rege_off ) _regexp_search = 0;
				pat = substr(pat, l + 1, -1);
				}
			}
		if ( pat[0] == _pattern_end_flag_char ) return substr(pat, 2, -1);
		cnt ++;
		if ( cnt > 4 ) break; % maximum count of defined flags
		}
	return pat;
	}

%% search for a string in direction 'dir'
public define cbrief_search(dir) {
	variable prompt, pattern, found = 0, r = 0, i;
	
	prompt = sprintf("%c Search for (%s %s):",
					 (dir > 0) ? _get_symbol('f') : _get_symbol('b'),
					 (_regexp_search) ? _rege_on : _rege_off,
					 (_search_case)   ? _case_on : _case_off);
	
	pattern = read_mini_search(prompt, LAST_SEARCH, "");
	if ( pattern == NULL )		return;
	pattern = cbrief_pattern_flags(pattern);
	ifnot ( strlen(pattern) )	return;

	_search_forward = (dir > 0) ? 1 : 0;
	LAST_SEARCH = pattern;
	CASE_SEARCH = _search_case;

	% search only in the block
	variable bWiden = 0;
	if ( _block_search && markp() ) {
		push_spot ();
		narrow_to_region();
		bob(); 	bWiden = 1;
		}

	if ( dir > 0 ) r = right(1);
	if ( _regexp_search )
		found = (dir > 0) ? re_fsearch(LAST_SEARCH) : re_bsearch(LAST_SEARCH);
	else 
		found = (dir > 0) ? fsearch(LAST_SEARCH) : bsearch(LAST_SEARCH);
	ifnot (dir > 0 && found) go_left(r);

	% if block only, return to normal
	if ( bWiden ) {
		widen_region ();
		pop_spot();
		}
	
	mesg((found) ? "Search completed." : "Not Found");
	}

%% UI search_fwd
public define cbrief_search_fwd()
{ cbrief_search(1); }

%% UI search_back
public define cbrief_search_back()
{ cbrief_search(-1); }

%% find next
public define cbrief_find_next() {
	if ( strlen(LAST_SEARCH) ) {
		% search only in the block
		variable bWiden = 0;
		if ( _block_search && markp() ) {
			push_spot ();
			narrow_to_region();
			bob();
			bWiden = 1;
			}
		% this is the search
		variable r = right(1);
		variable found = (_regexp_search) ? re_fsearch(LAST_SEARCH) : fsearch(LAST_SEARCH);
		ifnot (found) go_left(r);
		% if block only, return to normal
		if ( bWiden ) {
			widen_region ();
			pop_spot();
			}
		mesg((found) ? "Search completed." : "Not Found");
		}
	else
		cbrief_search_fwd();
	}

%% find previous
public define cbrief_find_prev() {
	if ( strlen(LAST_SEARCH) ) {
		% search only in the block
		variable bWiden = 0;
		if ( _block_search && markp() ) {
			push_spot ();
			narrow_to_region();
			bob();
			bWiden = 1;
			}
		% this is the search
		variable found = (_regexp_search) ? re_bsearch(LAST_SEARCH) : bsearch(LAST_SEARCH);
		% if block only, return to normal
		if ( bWiden ) {
			widen_region ();
			pop_spot();
			}
		mesg((found) ? "Search completed." : "Not Found");
		}
	else
		cbrief_search_back();
	}

%% incremental search
define cbrief_i_search()
{ if  (_search_forward ) isearch_forward(); else isearch_backward(); }

%% search_again
public define cbrief_search_again()
{ if ( _search_forward ) cbrief_find_next(); else cbrief_find_prev(); }

%% search_again reversed
define cbrief_search_again_r()
{ if ( _search_forward ) cbrief_find_prev(); else cbrief_find_next(); }

%% --- replace ------------------------------------------------------------

private variable last_search_repl = "";
private variable last_trans_dir   = 1;

%%
private define re_fsearch_f(pat)		{ return re_fsearch(pat) - 1; }
private define re_bsearch_f(pat)		{ return re_bsearch(pat) - 1; }
private define ss_fsearch_f(pat)		{ return fsearch(pat); }
private define ss_bsearch_f(pat)		{ return bsearch(pat); }
private define re_replace_f(str, len)	{ ifnot ( replace_match(str, 0) ) return 0; return 1; }
private define ss_replace_f(str, len)	{ replace_chars(len, str); return 1; }

%% it leaves a push_mark
define cbrief_mark_next_nchars(n, dir) {
	set_line_hidden (0);
	push_visible_mark();
	go_right(n);
	if ( dir < 0 )
		exchange_point_and_mark();
	}

% The search function is to return: 0 if non-match found or the length of the item matched.
% search_fun takes the pattern to search for and returns the length of the pattern matched. If no match occurs, return -1.
% rep_fun returns the length of characters replaced.
define cbrief_replace_with_query(search_f, pat, rep, replace_f) {
	variable prompt, ch, patdist, global = 0, count = 0;
	variable replacement_length = strlen(rep);

	prompt = "Change [Yes|No|Global/All|One|Quit]?";

	while ( patdist = @search_f(pat), patdist > 0 ) {

		if ( global ) { 
			ifnot ( @replace_f(rep, patdist) )	return;
			count ++;
			continue;
			}
		
		recenter(window_info('r') / 2);
		cbrief_mark_next_nchars(patdist, -1);
		flush(prompt);
		update(1);
		ch = get_mini_response(prompt);
		if ( markp() )
			pop_mark_0();

        switch ( tolower(ch) )
		{ case 'y' or case 'o' or case 'g' or case 'a':
			ifnot ( @replace_f(rep, patdist) )	return;
			count ++;
			if ( ch == 'o' || ch == 'O' )	break;
			if ( ch == 'g' || ch == 'G' )	global = 1;
			if ( ch == 'a' || ch == 'A' )	global = 1;
			}
		{ case 'n': go_right_1(); continue; }
		{ case 'q' or case '' or case 27: break; }
		}
	
	return count;
	}

%%
define cbrief_translate_main(dir) {
	variable prompt, pattern, repl, num = 0, i;
	
	prompt = sprintf("%c Pattern (%s %s):",
					 (dir > 0) ? _get_symbol('f') : _get_symbol('b'),
					 (_regexp_search) ? _rege_on : _rege_off,
					 (_search_case)   ? _case_on : _case_off);
	
	pattern = read_mini_search(prompt, LAST_RSEARCH, "");
	if ( pattern == NULL )		return;
	pattern = cbrief_pattern_flags(pattern);
	ifnot ( strlen(pattern) )	return;

	%%% replacement %%%
	repl = read_mini_replace("Replacement:", LAST_REPLACE, "");
	if ( repl == NULL ) return;

	LAST_RSEARCH = pattern;
	LAST_REPLACE = repl;
	CASE_SEARCH = _search_case;
	last_trans_dir = dir;

	% translate only in the block
	variable bWiden = 0;
	if ( _block_search && markp() ) {
		push_spot ();
		narrow_to_region();
		bob();
		bWiden = 1;
		}

	if ( _regexp_search)
		num = cbrief_replace_with_query( (dir > 0) ? &re_fsearch_f : &re_bsearch_f, pattern, repl, &re_replace_f);
	else
		num = cbrief_replace_with_query( (dir > 0) ? &ss_fsearch_f : &ss_bsearch_f, pattern, repl, &ss_replace_f);

	% if block only, return to normal
	if ( bWiden ) {
		widen_region ();
		pop_spot();
		}
	
	mesgf("Translation complete; %d occurrences changed.", num);
	}

define cbrief_translate()
{ cbrief_translate_main(1); }

define cbrief_translate_back()
{ cbrief_translate_main(-1); }

%%
define cbrief_translate_again() {
	variable num;
	
	% translate only in the block
	variable bWiden = 0;
	if ( _block_search && markp() ) {
		push_spot ();
		narrow_to_region();
		bob();
		bWiden = 1;
		}
	
	if ( _regexp_search )
		num = cbrief_replace_with_query(
				(last_trans_dir > 0) ? &re_fsearch_f : &re_bsearch_f,
				last_search_repl, LAST_REPLACE, &re_replace_f);
	else
		num = cbrief_replace_with_query(
				(last_trans_dir > 0) ? &ss_fsearch_f : &ss_bsearch_f,
				last_search_repl, LAST_REPLACE, &ss_replace_f);

	% if block only, return to normal
	if ( bWiden ) {
		widen_region ();
		pop_spot();
		}
	
	mesgf("Translation complete; %d occurrences changed.", num);
	}

%% --- keystroke macros ---------------------------------------------------

private variable last_ksmacro = "";
private variable cur_ksmacro = "";
private variable paused_ksmacro = 0;

define cbrief_playback() {
	if ( _has_set_last_macro )
		set_last_macro(last_ksmacro);
	call("execute_macro");
	}

%%	Start macro recording.
%%	If recording is already in progress, stop recording.
define cbrief_remember () {
	if ( DEFINING_MACRO ) {
		call("end_macro");
		last_ksmacro = strcat(cur_ksmacro, get_last_macro());
		cur_ksmacro = "";
		}
   else ifnot ( EXECUTING_MACRO or DEFINING_MACRO ) {
		if ( paused_ksmacro )
			uerror("Macro already paused");
	   	else {
			last_ksmacro = "";
			cur_ksmacro = "";
			call("begin_macro");
			}
		}
	}

%% pause recording macro
define cbrief_pause_ksmacro() {
	if ( DEFINING_MACRO ) {
		call("end_macro");
		cur_ksmacro = get_last_macro();
		paused_ksmacro = 1;
		}
	else if ( paused_ksmacro ) {
		paused_ksmacro = 0;
		call("begin_macro");
		}
	else
		uerror("Not recording...");
	}

%%	not the original save, but ...
define cbrief_save_ksmacro() {
	variable file, fp;

	file = read_mini_filename_new("Keystroke macro file:", "", "");
	ifnot ( strlen(file) ) return;
	ifnot ( strlen(path_extname(file)) )
		file = strcat(file, ".km");

	fp = fopen(file, "wb+");
	ifnot ( fp == NULL ) {
		() = fwrite(last_ksmacro, fp);
		() = fclose(fp);
		}
	else
		uerror("Cannot create file.");
	}

%%
define cbrief_load_ksmacro() {
	variable file, fp, n;

	file = read_mini_filename("Keystroke macro file:", "", "");
	ifnot ( strlen(file) ) return;

	fp = fopen(file, "rb");
	ifnot ( fp == NULL ) {
		n = fseek (fp, 0, SEEK_END);
		() = fseek (fp, 0, SEEK_SET);
		() = fread(&last_ksmacro, String_Type, n, fp);
		() = fclose(fp);
		}
	else
		uerror("Cannot open file.");
	}

%% --- lib ----------------------------------------------------------------

%%
%%	The original BRIEF's brace checking algorithm, I just rewrite it to slang.
%%	It is nice to see old bugs :P
%%
%%**              This macro is an attempt at a "locate the unmatched brace" utility.
%%**      Although it attempts to be fairly smart about things, it has an IQ of
%%**      4 or 5, so be careful before taking its word for something.
%%**              It DOES NOT WORK if there are braces inside quotes, apostrophes, or
%%**      comments.  The macro can, however, be modified to ignore everything
%%**      inside these structures (and check for the appropriate mismatches).
%%

%% part of brace()
define cbrief_char_search(backward) {
	variable re = "[\{\}]";
	return ( backward ) ? re_bsearch(re) : re_fsearch(re);
	}

%% locate the unmatched brace
define cbrief_brace() {
	variable ch, pos, count, mismatch, backward;
	variable save_line = what_line(), save_col = what_column();
	variable msgf = "Checking braces, %d unmatched '{'s.";
	
	backward = 0;
	mismatch = 0;
	count = 0;
	bob();

	while ( backward < 2 ) {
		while ( cbrief_char_search(backward) && mismatch == 0 ) {
			flush(sprintf(msgf, count));

			ch = what_char();
			if ( backward )	pos = ( ch == '}' ) ? 1 : 2;
			else 			pos = ( ch == '{' ) ? 1 : 2;

			if ( pos == 1 )		count ++;
			else if ( pos == 2 ) {
				if ( count )	count --;
				else {
					uerrorf("Mismatched %s brace.", (backward) ? "opening" : "closing");
					mismatch = 1; % found
					}
				}

			ifnot ( mismatch )	% next character
				call((backward) ? "previous_char_cmd" : "next_char_cmd");
			} % while int

		ifnot ( mismatch ) {
			if ( count ) { % missing '{', search backward
				eob();
				count = 0;
				backward = 1; % backward now
				msgf = "Locating mismatch, %d unmatched '}'s.";
				}
			else backward = 2; % exit
			}
		else backward = 2; % exit
		} % while -- change direction or exit
	
	ifnot ( mismatch ) {
	mesg("All braces match.");
		goto_line(save_line);
		goto_column(save_col);
		}
	}

% display and/or change the current colors, color_scheme [new-scheme]
public define cbrief_color_scheme() {
	variable argc = _NARGS, argv = __pop_list(argc);
	if ( argc ) set_color_scheme(argv[0]);
	mesgf("%s", _Jed_Color_Scheme);
	}

%% returns the first line of the current buffer
static define get_first_line() {
	variable line = "";
	push_spot();
	bob(); push_mark(); eol();
	line = string(bufsubstr());
	if ( markp() )
		pop_mark_0();
	pop_spot();
	return line;
	}

%% returns the shell bang of the first line or none if none is there
%% #!/bin/sh -> returns /bin/sh
static define get_shell_bang() {
	variable s = get_first_line();
	s = strtrim_end(s, "\n\r \t\v\f");
	if ( strlen(s) > 2 && s[0] == '#' && s[1] == '!' )
		s = substr(s, 3, -1);
	else
		s = "";
	return s;
	}

static define get_make_cmd() {
	variable make_cmd = NULL, i, count;
	variable mkfiles = [ "Makefile", "GNUmakefile", "BSDmakefile" ];
	
	count = length(mkfiles);
	for ( i = 0; i < count; i ++ ) {
		if ( access(mkfiles[i], R_OK) == 0 ) {
			make_cmd = rc_gets(rc, "MAKE", "make -j 1 -e TERM=dumb");
			break;
			}
		}
	return make_cmd;
	}

%% F9 make & run
define cbrief_build_it() {
	variable mode = strup(get_buffer_mode());
	variable make_cmd, run_cmd = "./%b", compile_cmd;
	variable file = buffer_filename(), i, count;
	variable shell_bang = get_shell_bang();

	if ( file[0] == ' ' || file[0] == '*' ) {
		error("You cannot build/run this buffer.");
		return;
		}

	make_cmd = get_make_cmd();
	if ( strlen(shell_bang) )
		run_cmd = sprintf("%s %%p", shell_bang);

	run_cmd = rc_gets(rc, "RUN_" + mode, run_cmd);
	compile_cmd = rc_get(rc, "COMPILE_" + mode);

	if ( mode == "SLANG" ) {
		evalbuffer();
		mesg("* done *");
		}
	else if ( strlen(shell_bang) ) {
		save_buffer();
		run_cmd = filefmt(run_cmd, file);
		shell_perform_cmd(run_cmd, 0);
		}
	else {
		save_buffer();
		if ( make_cmd != NULL ) {
			make_cmd = filefmt(make_cmd, file);
			compile(make_cmd);
			}
		else if ( compile_cmd != NULL ) {
			compile_cmd = filefmt(compile_cmd, file);
			compile(compile_cmd);
			}
		run_cmd = filefmt(run_cmd, file);
		shell_perform_cmd(run_cmd, 0);
		}
	}

%% CTRL+F9 build / compile only
define cbrief_compile_it() {
	variable mode = strup(get_buffer_mode());
	variable file = buffer_filename();
	variable shell_bang = get_shell_bang();
	variable compile_cmd, make_cmd, i, count;

	if ( file[0] == ' ' || file[0] == '*' ) {
		error("You cannot compile this buffer.");
		return;
		}

	make_cmd = get_make_cmd();

	if ( mode == "SLANG" ) 
		compile_cmd = "byte_compile_file(\"%f\", 0);";
	else if ( strlen(shell_bang) )
		compile_cmd = sprintf("%s %s", shell_bang, file);
	compile_cmd = rc_gets(rc, "COMPILE_" + mode, compile_cmd);

	if ( mode == "SLANG" ) {
		save_buffer();
		compile_cmd = filefmt(compile_cmd, file);
		eval(compile_cmd);
		mesg("* done *");
		}
	else if ( make_cmd != NULL ) {
		save_buffer();
		make_cmd = filefmt(make_cmd, file);
		compile(make_cmd);
		}
	else {
		save_buffer();
		compile_cmd = filefmt(compile_cmd, file);
		compile(compile_cmd);
		}
	}

%% wp mode, margins
define cbrief_margin() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable n = ( argc ) ? argv[0] : read_mini_int("Enter margin:", sprintf("%d", WRAP), "");
	if ( n == NULL ) return;
	n = atoi(n);
	if ( n > 1 ) WRAP = n;
	}

%% find a suitable xterm
define cbrief_find_xterm() {
	if ( CBRIEF_XTERM == "" ) {
#ifdef UNIX
		variable xterm = getenv("TERMINAL");
		if ( xterm == NULL )
			xterm = "xterm";
		CBRIEF_XTERM = xterm;
#endif
		}
	return CBRIEF_XTERM;
	}

%% create a new terminal window
define cbrief_new_term() {
	if ( _jed_secure_mode ) {
		uerror("Shell is not available (jed-secure-mode)");
		return;
		}
#ifdef MSDOS OS2
	() = system("command.com");
#else
#ifdef VMS
	variable cfile = expand_jedlib_file ("vms_shell.com");
	ifnot ( strlen (cfile) )
		uerror("Unable to open vms_shell.com");
	else
		() = system(cfile);	
#else
#ifdef MSWINDOWS WIN32
	() = system("start cmd.exe");	
#else
	if ( is_xjed() || getenv("DISPLAY") != NULL ) % under X Windows
		() = system(cbrief_find_xterm() + " &");
	else % console
		() = system(getenv("SHELL"));
#endif % UNIX/Win
#endif % VMS
#endif % DOS
	}

%%
define cbrief_dos() {
	variable cline = (_NARGS) ? () : "";

	if ( cline == "" )
		cbrief_new_term();
	else {
		scr_save();
		() = system(cline);
		scr_restore();
		}
	scr_redraw();
	}

%% Alt+Z
define cbrief_az() {
	if ( getenv("DISPLAY") == NULL )
		suspend();
	else
		cbrief_new_term();
	update(0);
	}

%%
define cbrief_load_macro() {
	variable cline = (_NARGS) ? () : read_with_completion("Macro file:", "", getcwd(), 'f');
	ifnot ( strlen(cline) ) {
		if ( file_status(cline) == 1 )
			() = evalfile(cline);
		else
			uerror("Unable to load macro file.");
		}
	}

%%
public define cbrief_command();
define cbrief_exec_macro() {
	variable cline = (_NARGS) ? () : "";
	ifnot ( strlen(cline) )
		cbrief_command();
	else
		cbrief_command(cline);
	}

define cbrief_change_win()	{ otherwindow(); }
define cbrief_resize_win()	{ enlargewin(); }
define cbrief_create_win()	{ splitwindow(); otherwindow(); }
define cbrief_delete_win() {
	onewindow();
	% variable c = get_mini_response (strfit("Select window edge to delete (use cursor keys)."));
	% update(0);
	% switch ( c )
	% 	{ case Key_Up: }
	% 	{ case Key_Down: }
	% 	{ case Key_Left: }
	% 	{ case Key_Right: }
	% 	{ error(strfit("Edge does not have just two adjoining windows.")); }
	}

%% --- command line -------------------------------------------------------

#ifdef UNIX
define cbrief_man(p)			{ unix_man(p); }
#else
define cbrief_man(p)			{ uerror("man-pages are not supported."); }
#endif
define cbrief_menu_help()		{ eval("menu_select_menu(\"Global.&Help\")"); }
define cbrief_write_and_exit()	{ save_buffers(); exit_jed(); }

%%
%%	show help about the keyword under the cursor
%% 
public define cbrief_word_help() {
	variable w, dw, mode, c;

	define_word("_A-Za-z0-9");
	push_spot();
	% jump to beginning of word
	bskip_word_chars();
	push_mark();
	
	% copy word
	skip_word_chars();
	w = bufsubstr();

	% restore
	if ( markp() )
		pop_mark_0();
	pop_spot();

	% show help
	if ( strlen(w) ) {
		mode = strup(get_buffer_mode());
		dw = strcat(" ", w);
#ifdef UNIX
		if ( mode == "C" )
			unix_man(rc_gets(rc, "MAN_C",     "-s 3,2")  + dw); % 3p = posix on some systems but also perl
		else if ( mode == "SH" || mode == "CSH" || mode == "TCSH" )
			unix_man(rc_gets(rc, "MAN_SH",    "-s 1p,1") + dw); % 1p = posix
		else if ( mode == "PERL" )
			unix_man(rc_gets(rc, "MAN_PERL",  "-s 3p") + dw); % 3p = perl on some systems but also posix
		else if ( mode == "SLANG" ) % see jedc-macros/jed-man/
			unix_man(rc_gets(rc, "MAN_SLANG", "-s 3sl") + dw);
		else
			unix_man(rc_gets(rc, "MAN_"+mode, "") + dw);
#endif
		}
	}

define cbrief_eow()				{ goto_bottom_of_window(); eol(); }

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% buffer commands 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% select buffer ±position
static define cbrief_to_buf_rel(n) {
	variable name, cbuf_list, curbuf = whatbuf();
	variable count = 0, idx = 0;
   
	if ( MINIBUFFER_ACTIVE ) return;

	cbuf_list = list_new();
	loop ( buffer_list() ) {
		name = ();
		if ( name[0] == ' ' ) continue;
		if ( name[0] == '*' ) continue;
		list_append(cbuf_list, name);
		if ( strcmp(name, curbuf) == 0 )
			idx = count;
		count ++;
		}

	if ( count == 0 )
		mesg("No other buffers.");
	else if ( n > 0 ) {
		idx ++;
		if ( idx == count )	idx = 0;
		sw2buf(cbuf_list[idx]);
		}
	else {
		idx --;
		if ( idx < 0 )	idx = count - 1;
		sw2buf(cbuf_list[idx]);
		}
	}

% CLI + Key, buffer_next
public define cbrief_buffer_next()		{ cbrief_to_buf_rel(1); }
% CLI + Key, buffer_prev
public define cbrief_buffer_prev()		{ cbrief_to_buf_rel(0); }

% erase buffer contents (CLI)
% buffer_clear [bufname]
static define cbrief_buffer_clear() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable name = ( argc ) ? argv[0] : read_mini_buffer("Enter buffer name:", whatbuf(), "");
	if ( name == NULL ) name = whatbuf();
	if ( strlen(name) ) setbuf(name);
	clear_buffer();
	mesgf("Buffer '%s' cleared!", name);
	}

% write buffer to disk (CLI)
% buffer_write [bufname [filename]]
static define cbrief_buffer_write() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable n = 0;
	variable cbuf = (argc >0)? argv[0] : read_mini_buffer("Enter buffer name:", whatbuf(), "");
	if ( cbuf == NULL ) cbuf = whatbuf();
	variable name = (argc >1)? argv[1] : read_mini_filename_new("Enter file name [default]:", "", "");
	if ( strlen(cbuf) > 0 ) setbuf(cbuf);
	if ( NULL == name )		 		n = write_buffer();
	else if ( 0 == strlen(name) )	n = write_buffer();
	else n = write_buffer(name);
	if ( n > 0 ) mesgf("Buffer '%s' saved, %d lines written!", cbuf, n);
	else		 mesgf("Buffer '%s' failed to write!", cbuf);
	}

% create new buffer (CLI)
% buffer_new [newname]
static define cbrief_buffer_new() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable name = (argc)? argv[0] : read_mini_buffer("Enter buffer name:", "", "");
	if ( name != NULL ) {
		if ( strlen(name) ) {
			sw2buf(name);
			mesgf("buffer '%s' created!", name);
			}
		}
	}

% default buffer list for alt+e (cbufed)
public define cbrief_buffer_list_tui()
{ cbrief_bufpu(); } % cbufed

% default buffer list (CLI)
% buffer_list [bufnumber | bufname]
public define cbrief_buffer_list() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable nsel = -1, sel = -1, name = (argc)? argv[0] : "";
	variable table, i, s, list, cbuf = whatbuf(), count;

	count = buffer_list();
	table = list_to_array(__pop_list(count));
	table = table[array_sort(table, &strcmp)];
	if ( isdigit(name[0]) && strlen(name) < 3 )
		nsel = atoi(name);

	s = "";
	for ( i = 0; i < count; i ++ ) {
		if ( table[i][0] == ' ' )	continue;
		if ( nsel == i )			sel = i;
		if ( table[i] == name )		sel = i;
		if ( table[i] == cbuf )
			s += sprintf("%d.[%s] ", i, strtrim(table[i]));
		else
			s += sprintf("%d.%s ", i, strtrim(table[i]));
		}
	
	if ( sel >= 0 ) {
		sw2buf(table[sel]);
		mesgf("buffer '%s' selected.", name);
		}
	else if ( name != "" && sel < 0 )
		mesgf("buffer '%s' does not exist!", name);
	else
		mesg(s);
	}

% buffer_close [bufname]
static define cbrief_buffer_close() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable name = (argc) ? argv[0] : read_mini_buffer("Enter buffer name:", whatbuf(), "");
	if ( name == NULL ) name = whatbuf();
	if ( bufferp(name) ) {
		delbuf(name);
		mesgf("Buffer '%s' closed!", name);		
		}
	else
		mesgf("Buffer '%s' does not exist!", name);
	}

% buffer_rename [bufname [newname]]
static define cbrief_buffer_rename() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable name = (argc) ? argv[0] : read_mini_buffer("Enter buffer name:", whatbuf(), "");
	if ( name == NULL ) name = whatbuf();
	if ( bufferp(name) ) {
		variable newname = (argc) ? argv[1] : read_mini_buffer("Enter new buffer name:", name, "");
		if ( newname != NULL ) {
			if ( newname != name ) {
				variable flags;
				flags = getbuf_info(), pop(), setbuf_info(newname, flags);
				mesgf("Buffer '%s' renamed to '%s'.", name, newname);		
				}
			}
		}
	else
		mesgf("Buffer '%s' does not exist!", name);
	}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% file commands
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% load a file and switch to new buffer, file_edit [filename]
static define cbrief_file_edit() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable file = (argc) ? argv[0] : read_mini_filename_new("Enter file:", "", "");
	if ( file != NULL && strlen(file) ) {
		find_file(file);
		mesgf("Done!");
		}
	}

% load a file and switch to new buffer
% using c_editfile instead of mini-buffer
public define cbrief_file_edit_tui() {
	variable file = dlg_openfile("Edit file", "");
	if ( file != NULL ) find_file(file);
	}

% Find the substring which could be a file name. -
% The following method assumes reasonably standard
public define cbrief_open_file_at_cursor() {
	push_spot ();
	% Find the substring which could be a file name. -
#ifdef UNIX
	bskip_chars("-0-9a-zA-Z_!%+~./"); % left limit
	push_mark();
	skip_chars("-0-9a-zA-Z_!%+~./"); % right limit
#else % DOS is supposed here:
	% DOS path names have backslashes and may contain a drive spec.
	bskip_chars("-0-9a-zA-Z_!%+~./\\:"); % left limit
	push_mark();
	skip_chars ("-0-9a-zA-Z_!%+~./\\:"); % right limit
#endif
	variable fn = bufsubstr(); % the file name
	pop_mark_0();
	pop_spot();
	ifnot ( 1 == file_status(fn) ) {
		if ( get_buffer_mode() == "C" ) {
			if ( 1 == file_status("/usr/include/" + fn) ) 
				fn = "/usr/include/" + fn;
			else if ( 1 == file_status("/usr/local/include/" + fn) )
				fn = "/usr/local/include/" + fn;
			}
		else
			uerror(strcat("File ", fn, " not found"));
		}
	else 
		uerror(strcat("File ", fn, " not found"));
	() = find_file(fn);
	}

% load a file in a new buffer, file_read [filename]
public define cbrief_file_read() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable file = (argc) ? argv[0] : read_mini_filename("Load file:", "", "");
	if ( file != NULL && strlen(file) ) {
		variable succeed = (read_file(file) != 0) ? "succeed" : "failed";
		mesgf("Load file '%s' %s!", file, succeed);
		}
	}

% insert a file in current buffer, file_insert [filename]
public define cbrief_file_insert() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable file = (argc)? argv[0] : read_mini_filename("Insert file:", "", "");
	if ( file != NULL && strlen(file) ) {
		variable succeed = (insert_file(file) >= 0) ? "succeed" : "failed";
		mesgf("Insert file '%s' %s!", file, succeed);
		}
	}

% insert a file in current buffer
% using c_editfile instead of mini-buffer
public define cbrief_read_file_tui() {
	variable file = dlg_selectfile("Insert file", "");
	if ( file != NULL ) insert_file(file);
	}

% delete a file, file_delete [filename]
static define cbrief_file_delete() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable status, file = (argc)? argv[0] : read_mini_filename("Delete file:", "", "");
	if ( file != NULL ) {
		file = strtrim(file);
		if ( strlen(file) ) {
			status = file_status(file);
			if ( status == 1 ) {
				variable succeed = delete_file(file);
				if ( succeed )
					mesgf("File '%s' deleted!", file);
				else
					uerrorf("Cannot delete file '%s'; error: %s!", file, errno_string(errno));
				}
			else if ( status ==  2 )	uerrorf("File '%s' is directory!", file);
			else if ( status ==  0 )	uerrorf("File '%s' does not exist!", file);
			else if ( status == -1 )	uerrorf("Access denied!");
			}
		}
	}
	
% rename a file, file_rename [oldname] [newname]
static define cbrief_file_rename() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable file1, file2, succeed;
	file1 = (argc >0)? argv[0] : read_mini_filename("Enter old filename:", "", "");
	if ( file1 != NULL && strlen(file1) ) {
		file2 = (argc >1)? argv[1] : read_mini_filename_new("Enter new filename:", "", "");
		if ( file2 != NULL && strlen(file2) ) {
			succeed = (rename_file(file1, file2) == 0) ? "succeed" : "failed";
			mesgf("Rename '%s' to '%s'; %s!", file1, file2, succeed);
			}
		}
	}

% copy a file, file_copy [source] [target]
static define cbrief_file_copy() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable file1, file2, succeed;
	file1 = (argc >0)? argv[0] : read_mini_filename("Enter source:", "", "");
	if ( file1 != NULL && strlen(file1) ) {
		file2 = (argc >1)? argv[1] : read_mini_filename_new("Enter target:", "", "");
		if ( file2 != NULL && strlen(file2) ) {
			succeed = (copy_file(file1, file2) == 0) ? "succeed" : "failed";
			mesgf("Copy '%s' to '%s'; %s!", file1, file2, succeed);
			}
		}
	}

% chmod
static define cbrief_file_chmod() {
	variable argc = _NARGS, argv = __pop_list(argc), mode, imode;
	variable file = (argc)? argv[0] : read_mini_filename("Enter file:", "", "");
	if ( file != NULL && strlen(file) ) {
		mode = (argc >1) ? argv[1] : read_mini("Enter mode:", "", "");
		if ( mode != NULL && strlen(mode) ) {
			imode = atoi(mode);
			imode |= 0600;
			variable succeed = (chmod(file, imode) == 0) ? "succeed" : "failed";
			mesgf("File mode to %o %s", imode, succeed);
			}
		}
	}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% directory commands
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% display current directory, pwd
public define cbrief_dir_pwd()
{ mesgf("%s", getcwd()); }

% change the current directory, dir_chdir [newdir]
public define cbrief_dir_chdir() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable name = (argc) ? argv[0] : read_mini_dir("Enter directory:", "", "");

	if ( name != NULL && strlen(name) ) {
		if ( file_status(name) == 2 ) {
			if ( 0 == change_default_dir(name) )
				mesgf("cwd = %s", getcwd());
			else
				uerrorf("chdir('%s'), failed: %s", name, errno_string(errno));
			}
		else
			uerror("'%s' its not a directory.", name);
		}
	}

% create a new directory, dir_mkdir [newdir]
public define cbrief_dir_mkdir() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable name = (argc) ? argv[0] : read_mini_filename_new("Enter new directory:", "", "");
	
	if ( name != NULL && strlen(name) ) {
		if ( 0 == mkdir(name) )
			mesgf("'%s' directory created.", name);
		else
			uerrorf("chdir('%s'), failed: %s", name, errno_string(errno));
		}
	}

% removes directory, dir_rmdir [dir]
public define cbrief_dir_rmdir() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable name = (argc) ? argv[0] : read_mini_dir("Enter directory:");

	if ( name != NULL && strlen(name) ) {
		if ( file_status(name) == 2 ) {
			if ( 0 == rmdir(name) )
				mesgf("'%s' removed", name);
			else
				uerrorf("rmdir('%s'), failed: %s", name, errno_string(errno));
			}
		else
			uerror("'%s' its not a directory.", name);
		}
	}

%% command-line ##
private variable NO_ARG = 0;	% no parameters
private variable C_ARGV = 1;	% C-style argv, slang_func(string[]argv), argv[0] = name of function (old-style)
private variable C_LINE = 2;	% string
private variable S_LANG = 3;	% eval(this)
private variable S_CALL = 4;	% call(this)
private variable C_ARG2 = 5;	% C-style argv, through C, slang_func(int argc, string[]argv), argv[0] = name of function
private variable C_SARG = 6;	% like C_ARGV but without the first element, it is the best for calling original slang functions
private variable CALIAS = 7;	% command is alias

%% --- aliases ---
public define cbrief_print_aliases() {
	variable e;
	sw2buf("*output*");
	insert("--- aliases --------------------------------------------------------------------\n");
	foreach e ( cbrief_macros_list ) {
		if ( e[2] == CALIAS ) 
			insert(sprintf("%-20s = %s\n", e[0], e[1]));
		}
	bob();
	view_mode();
	}

% syntax: alias [x y]
public define cbrief_cli_append(name, funcptr, args, hlp);
public define cbrief_cli_alias() {
	variable argc = _NARGS;
	variable argv = __pop_list(argc);
	if ( argc < 2 ) { cbrief_print_aliases(); return; }
	variable cmd, val, i;

	cmd = argv[0];
	val = argv[1];
	for ( i = 2; i < argc; i ++ )
		val = strcat(val, " ", argv[i]);
	cbrief_cli_append(cmd, val, CALIAS, NULL);
%	mesgf("Alias '%s' set to '%s'.", cmd, val);
	}

%% --- rc variables ---
public define cbrief_rcprint_callback(n, v)
{ insert(sprintf("%-20s = %s\n", n, v)); }

public define cbrief_rcprint() {
	variable e;
	sw2buf("*output*");
	insert("--- rc run-time variables:\n");
	rc_enum(rcmem, "cbrief_rcprint_callback");
	insert("--- rc file:\n");
	rc_enum(rc,    "cbrief_rcprint_callback");
% insert(sprintf("%-20s = %s\n", "MAKE", rc_gets(rc, "MAKE", "no")));
	bob();
	view_mode();
	}

%% syntax: set [x y]
define cbrief_rcset() {
	variable argc = _NARGS;
	variable argv = __pop_list(argc);
	if ( argc < 2 ) { cbrief_rcprint(); return; }
	variable i, val = argv[1];
	for ( i = 2; i < argc; i ++ )
		val = strcat(val, " ", argv[i]);
	rc_set(rc, argv[0], val);
%	mesgf("Variable '%s' set to '%s'.", cmd, val);
	}

%% --- environment variables ---
define cbrief_envprint() {
	variable e, a, i;
	sw2buf("*output*");
	insert("--- environment variables -----------------------------------------------------\n");
	a = get_environ();
	for ( i = 0; i < length(a); i ++ )
		insert(sprintf("%s\n", a[i]));
	bob();
	view_mode();
	}

%% syntax: setenv [x y]
define cbrief_setenv() {
	variable argc = _NARGS;
	variable argv = __pop_list(argc);
	if ( argc < 2 ) { cbrief_envprint(); return; }
	variable i, val = argv[1];
	for ( i = 2; i < argc; i ++ )
		val = strcat(val, " ", argv[i]);
	putenv(sprintf("%s=%s", argv[0], val));
%	mesgf("Environment variable '%s' set to '%s'.", cmd, val);
	}

%% repeat character (actually string)
public define cbrief_repeat_char() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable i, ch = "-", num = 80;
	num = ( argc > 0 ) ? atoi(argv[0]) : read_mini_int("Number of characters: ", num, "");
	if ( num == 0 ) return;
	ch  = ( argc > 1 ) ? argv[1] : read_mini("Enter the character to repeat: ", ch, "");
	if ( ch != NULL ) {
		for ( i = 0; i < num; i ++ )
			insert(ch);
		}
	}

%%
public define cbrief_assign_to_key() {
	variable argc = _NARGS, argv = __pop_list(argc);
	if ( argc == 2 ) {
		if ( strlow(argv[1]) == "nothing" ||
			 strlow(argv[1]) == "self_insert" ||
			 strlow(argv[1]) == "null" )
			cbrief_setkey("self_insert_cmd", argv[0]);
		else
			cbrief_setkey(argv[1], argv[0]);
		}
	else
		mesg("usage: assign_to_key \"key-seq\" function");
	}

%% --- macros list ---
private define cbrief_maclist_init() {
	if ( typeof(cbrief_macros_list) == List_Type )
		return;
	cbrief_macros_list = list_new();
	list_join(cbrief_macros_list, {
%     name              function pointer        type
	{ "reset",       	&cbrief_reset,		NO_ARG, 
"reset (debug)\n\
	Reinitialize the keyboard in case something goes wrong." },
		
	{ "print_stack", 	&_print_stack,		NO_ARG, 
"print_stack (debug)\n\
	Prints the contents of the JED's stack." },

	{ "buflogf",     	&buflogf,			C_SARG, 
"buflogf (debug)\n\
	Opens a buffer and writes the information. The format is similar of printf()." },

% bgd_compilation
%	Toggles whether or not all compilations should be performed
%	in the background.

	{ "backspace",		&cbrief_backspace,			NO_ARG, 
"backspace\n\
	Backspaces and erases the character preceding the cursor." },

	{ "back_tab",		&cbrief_back_tab,			NO_ARG, 
"back_tab\n\
	Moves the cursor to the previous tab stop without erasing tabs\
	or characters." },

	{ "set_backup",		&cbrief_toggle_backup,		NO_ARG, 
"set_backup\n\
	Turns automatic backup on or off from inside BRIEF." },

	{ "beginning_of_line",	&bol,					NO_ARG, 
"beginning_of_line\n\
	Places the cursor at column 1 of the current line." },

	{ "block_search",	&cbrief_block_search,		NO_ARG,
"block_search\n\
	Toggles whether or not Search forward, Search back, and Search\
	again are restricted to blocks." },

% Borders
%	Toggles whether or not window borders are displayed.

%	{ "buf_list",		&cbrief_buf_list,			NO_ARG },
% buf_list
%	Displays the buffer list.

	{ "toggle_search_case",	&cbrief_search_case,		NO_ARG },
	{ "search_case",	&cbrief_search_case,		    NO_ARG,
"search_case\n\
	Toggles upper and lower case sensitivity." },

	{ "align_center",			"center_line",					S_CALL, 
"align_center\n\
	Centers the text on a line between the first column and the right margin." },
		
	{ "center",			"align_center",					CALIAS }, 

	{ "align_right",			"right_line",				S_CALL, 
"align_right\n\
	Align right the text on a line before the right margin." },

	{ "align_left",			"left_line",				S_CALL, 
"align_left\n\
	Align left the text on a line after the left margin." },

	{ "center_line",	&brief_line_to_mow,				NO_ARG, 
"center_line\n\
	Moves the current line, if possible, to the center (middle line)\
	of the current window. This only affects the display." },

	{ "output_file",	&cbrief_output_file,			C_SARG, 
"output_file\n\
	Changes the output file name for the current buffer. You cannot\
	enter an existing file name." },

% change_window
%	Initiates a switch from one window to another.
	
% color
%	Resets the colors used for the background, foreground, titles,
%	and messages.

	{ "compile_it",		&cbrief_compile_it,			NO_ARG, 
"compile_it\n\
	Compiles the file in the current buffer (and loads it if it's\
	a BRIEF macro file)." },

	{ "copy",			&cbrief_copy,				NO_ARG, 
"copy\n\
	Copies the block of marked characters (selected by pressing Alt+M,\
	Alt+C, Alt+A, or Alt+L and highlighting the block with arrow keys\
	or commands) to the scrap, replacing the contents of the scrap\
	buffer and unmarking the block." },

	{ "assign_to_key",  &cbrief_assign_to_key, C_SARG,
"assign_to_key key function\n\
	Assign a key or key sequence to a function. The key can take many forms, outlined under parameters.\
	The most easy way is to use Ctrl+Q and then press the key.\
	A key is 'unassigned' by assigning the function nothing to the key." },

	{ "setkey",  &cbrief_setkey, C_SARG,
"setkey function key\n\
	Assign a key or key sequence to a function. The key can take many forms, outlined under parameters.\
	The most easy way is to use Ctrl+Q and then press the key.\
	A key is 'unassigned' by assigning the function 'self_insert_cmd' to the key." },

	{ "create_edge", &cbrief_create_win, NO_ARG },
% create_edge
%	Splits the current window in half either horizontally or vertically,
%	providing two views of the current buffer.

	{ "cut",			&cbrief_cut,			NO_ARG, 
"cut\n\
	Copies the block of marked characters to the scrap, then deletes it,\
	replacing the previous contents of the scrap and unmarking the block." },

	{ "delete_char",	&cbrief_delete,				NO_ARG, 
"delete_char\n\
	Deletes the character at the cursor or, if a block is marked, deletes\
	(and unmarks) the marked block." },

	{ "delete_curr_buffer",	&brief_delete_buffer,	NO_ARG, 
"delete_curr_buffer\n\
	Deletes the current buffer and makes the next buffer in the buffer\
	list the current buffer." },

	{ "delete_line",	&delete_line,				NO_ARG, 
"delete_line\n\
	Deletes the entire current line, regardless of the column position\
	of the cursor." },

% delete_macro
%	Deletes the specified compiled macro file from memory.

	{ "delete_next_word",		"delete_word",		S_CALL, 
"delete_next_word\n\
	Deletes from the cursor position to the start of the next word." },

	{ "delete_prev_word",		"bdelete_word",		S_CALL },	% non-brief
	{ "delete_previous_word",	"bdelete_word",		S_CALL, 
"delete_previous_word\n\
	Deletes from the cursor position to the beginning of the previous word." },

	{ "delete_to_bol", 		&brief_delete_to_bol,	NO_ARG, 
"delete_to_bol\n\
	Deletes all characters before the cursor to the beginning of the\
	line. If the cursor is beyond the end of the line, the entire line\
	is deleted, including the newline character." },

	{ "delete_to_eol",	"kill_line",	S_CALL,
"delete_to_eol\n\
	Deletes all characters from the current position to the end	of the line." },

	{ "delete_edge", &cbrief_delete_win, NO_ARG },
% delete_edge (param. the edge, 1..4 i think)
%	Allows you to delete a window by deleting the window's edge.

	{ "display_file_name", &cbrief_disp_file, NO_ARG,
"display_file_name\n\
	Displays the name of the file associated with the current buffer\
	on the status line." },

	{ "version", &cbrief_disp_ver, NO_ARG,
"version\n\
	Displays BRIEF's version number and copyright notice on the\
	status line." },

	{ "down",	&go_down_1, NO_ARG,
"down\n\
	Moves the cursor down one line, retaining the column position." },

	{ "drop_bookmark", &cbrief_bkdrop, C_LINE,
"drop_bookmark\n\
	Drops a numbered bookmark at the current position." },

	{ "edit_file",		&cbrief_file_edit,	C_SARG,
"edit_file\n\
	Displays the specified file in the current window." },

	{ "end_of_buffer",	&eob,				NO_ARG,
"end_of_buffer\n\
	Moves the cursor to the last character in the buffer, which is\
	always a newline character." },

	{ "end_of_line",	&eol,				NO_ARG,
"end_of_line\n\
	Places the cursor at the last valid character of the current line." },

	{ "end_of_window",	&cbrief_eow,  		NO_ARG,
"end_of_window\n\
	Places the cursor at the last valid character of the current line." },

	{ "enter",			&cbrief_enter,		NO_ARG,
"enter\n\
	Depending on the mode being used (insert or overstrike), either\
	inserts a newline character at the current position, placing all\
	following characters onto a newly created next line, or moves the\
	cursor to the first column of the next line." },

	{ "escape",			&cbrief_escape,		NO_ARG,
"escape\n\
	Lets you cancel a command from any prompt." },

	{ "execute_macro", &cbrief_exec_macro, NO_ARG,
"execute_macro\n\
	Executes the specified command. This command is used to execute\
	any command without a key assignment, such as the Color command." },

	{ "exit [w]",		&cbrief_exit,		NO_ARG,
"exit\n\
	Exits from BRIEF to OS asking to write the modified buffers." },

	{ "quit",			&quit_jed,			NO_ARG,
"quit\n\
	Exits from BRIEF to OS without write the buffers." },

	{ "goto_line",		&cbrief_goto_line,	C_SARG,
"goto_line n\n\
	Moves the cursor to the specified line number." },
		
	{ "goto_column",	&cbrief_goto_column,	C_SARG,
"goto_column n\n\
	This function moves the current editing point to the column specified by the parameter n.\
	It will insert a combination of spaces and tabs if necessary to achieve the goal." },

% routines (^G) // moved to tokenlist module
%	Displays a window that lists the routines present in the current
%	file (if any).

	{ "halt",			&cbrief_escape,		NO_ARG },	% brief's key abort
% halt
%	Terminates the following commands: 'Search forward',
%	'Search backward', 'Translate', 'Playback', 'Execute command'.
		
	{ "help",			&cbrief_help,			C_SARG,
"help [list|keys|<keyword>]\n\
	Without parameters, shows an information window with basic key-shortcuts;\
	otherwise shows in new buffer the list of macros, key-binding or information about the specific keyword." },
	
	{ "long_help",		&cbrief_long_help,	NO_ARG,
"long_help\n\
	Displays the full help file in a new buffer." },

% help
%	Either displays a general help menu or, if a command prompt is in
%	the message window, displays a pop-up window of information
%	pertaining to the command.

	{ "i_search",		&cbrief_i_search,	NO_ARG,
"i_search\n\
	Searches for the specified search pattern incrementally, that is,\
	as you type it." },

	{ "slide_in",		&cbrief_slide_in,	NO_ARG,
"slide_in\n\
	When indenting is on and a block is marked, the Tab key indents all\
	the lines in the block to the next tab stop." },

	{ "insert_mode",	&toggle_overwrite,	NO_ARG,
"insert_mode\n\
	Switches between insert mode and overstrike mode. Backspace, Enter,\
	and Tab behave differently in insert mode than in overstrike mode." },

	{ "goto_bookmark", &cbrief_bkgoto,		C_LINE,
"goto_bookmark\n\
	Moves the cursor to the specified bookmark number." },

	{ "left",		&go_left_1,				NO_ARG,
"left\n\
	Moves the cursor one column to the left, remaining on the same line.\
	When the cursor is moved into virtual space, it changes shape." },

	{ "left_side",	"scroll_right",			S_CALL,
"left_side\n\
	Moves the cursor to the left side of the window." },

	{ "to_bottom", &brief_line_to_eow,		NO_ARG,
"to_bottom\n\
	Scrolls the buffer, moving the current line, if possible, to the\
	bottom of the window." },
	
	{ "to_top",		&brief_line_to_bow,		NO_ARG,
"to_top\n\
	Scrolls the buffer, moving the current line to the top of the\
	current window." },

	{ "load_keystroke_macro", &cbrief_load_ksmacro, NO_ARG,
"load_keystroke_macro\n\
	Loads a keystroke macro into memory, if the specified file can be\
	found on the disk." },

	{ "load_macro",	&cbrief_load_macro, C_LINE,
"load_macro\n\
	Loads a compiled macro file into memory, if the specified file can\
	be found on the disk." },

	{ "tolower",	"cbrief_block_to('d')",		S_LANG,
"tolower\n\
	Converts the characters in a marked block or the current line to\
	lowercase." },
	
	{ "margin",		&cbrief_margin,			C_SARG,
"margin\n\
	Resets the right margin for word wrap, centering, and paragraph\
	reformatting. The preset margin is at the seventieth character." },
	
	{ "mark",		&cbrief_mark,			C_LINE,
"mark\n\
 	'mark' or 'mark 0' remove mark.\n\
 	'mark 1' standard mark.\n\
 	'mark 2' Starts marking a rectangular block.\n\
	'mark 3' Starts marking a line at a time.\n\
	'mark 4' Equivalent to Mark 1, except that the marked area does not\
			include the character at the end of the block.\n\n\
	Marks a block in a buffer with no marked blocks. When a block of\
	text is marked, several BRIEF commands can act on the entire block:\
	Cut to scrap, Copy to scrap, Delete, Indent block (in files with\
	programming support), Lower case block Outdent block (in files with\
	programming support), Print Search forward, Search backward, and\
	Search again (optionally; see the Block search toggle command)\
	Translate forward, Translate back, and Translate again Uppercase\
	block, Write.\n\n\
	When the Cut to scrap, Copy to scrap, Delete, Print, or Write\
	commands are executed on a block, the block becomes unmarked." },

	{ "edit_next_buffer",	&cbrief_buffer_next,	NO_ARG,
"edit_next_buffer\n\
	Moves the next buffer in the buffer list, if one exists, into the\
	current window, making it the current buffer. The last remembered\
	position becomes the current position." },

	{ "next_char",		"next_char_cmd",	S_CALL,
"next_char\n\
	Moves the cursor to the next character in the buffer (if not at\
	the end of the buffer), treating tabs as single characters and\
	wrapping around line boundaries." },

% next_error
%	Locates the next error in the current file, if an error exists.

	{ "next_word",		&cbrief_next_word,	NO_ARG,
"next_word\n\
	Moves the cursor to the first character of the next word." },

	{ "open_line",		&brief_open_line,	NO_ARG,
"open_line\n\
	Inserts a blank line after the current line and places the cursor\
	on the first column of this new line. If the cursor is in the\
	middle of an existing line, the line is not split." },

	{ "slide_out",		&cbrief_slide_out,	NO_ARG,
"slide_out\n\
	When indenting is on and a block is marked, the Tab key outdents\
	all the lines in the block to the next tab stop." },

	{ "page_down",		&brief_pagedown,	NO_ARG,
"page_down\n\
	Moves the cursor down one page of text, where a page equals the\
	length of the current window." },

	{ "page_up",		&brief_pageup,		NO_ARG,
"page_up\n\
	Moves the cursor up one page of text, where a page equals the\
	length of the current window." },

	{ "bob",		"bob",		S_LANG, "bob\n\tGo to the beginning of buffer." },
	{ "eob",		"eob",		S_LANG, "eob\n\tGo to the end of buffer." },
	{ "bol",		"bol",		S_LANG, "bol\n\tGo to the beginning of line." },
	{ "eol",		"eol",		S_LANG, "eol\n\tGo to the end of line." },
	{ "forward_paragraph",		"forward_paragraph",		S_LANG, "forward_paragraph\n\tGo to the next paragraph." },
	{ "backward_paragraph",		"backward_paragraph",		S_LANG, "backward_paragraph\n\tGo to the previous paragraph." },

	{ "paste",			&cbrief_paste,		NO_ARG,
"paste\n\
	Inserts (pastes) the current scrap buffer into the current buffer\
	immediately before the current position, taking the type of the\
	copied or cut block into account." },

	{ "pause",		&cbrief_pause_ksmacro,	NO_ARG },
% ??? (s+f7)
%	Tells BRIEF to temporarily stop recording the current keystroke
%	sequence.

% pause_an_error
%	Tells BRIEF to pause when displaying run-time error messages.
%	Otherwise, the messages flash by at a rapid rate.

	{ "playback",		&cbrief_playback,	NO_ARG,
"playback\n\
	Plays back the last keystroke sequence recorded with the Remember\
	command." },

% next_error 1
%	Displays a window of error messages and allows you to examine any
%	message or go to the line where an error occurred. This command
%	should be used after the current file has been compiled.

	{ "menu",	"select_menubar",	S_CALL,
"menu\n\
	Opens JED's menu bar. (non-brief)" },

% popup_menu
%	Displays a pop-up menu. If called using the mouse, the pop-up menu
%	is displayed centered under the mouse cursor. Otherwise, it is
%	displayed in the middle of the screen. The menu is in the file
%	'\brief\help\popup.mnu', and can be modified to add additional
%	features.

	{ "edit_prev_buffer",	&cbrief_buffer_prev,	NO_ARG,
"edit_prev_buffer\n\
	Displays the previous buffer in the buffer list in the current\
	window." },
	
	{ "prev_char",		"previous_char_cmd",	S_CALL,
"prev_char\n\
	Moves the cursor to the previous character in the buffer (if not at\
	the top of the buffer), treating tabs as single characters and\
	wrapping around line boundaries." },

	{ "prev_word",		"previous_word",	CALIAS }, % non-brief
	{ "previous_word",	&cbrief_prev_word,	NO_ARG,
"previous_word\n\
	Moves the cursor to the first character of the previous word." },

	{ "change_window", &cbrief_change_win, NO_ARG },
% change_window
%	Quickly changes windows when you choose the arrow key that points
%	to the window you want.

	{ "quote",		&cbrief_quote,		NO_ARG,
"quote\n\
	Causes the next keystroke to be interpreted literally, that is,\
	not as a command." },

	{ "redo",			"redo",			S_CALL,
"redo\n\
	Reverses the effect of commands that have been undone.\
	New edits to the buffer cause the undo information for commands\
	that were not redone to be purged." },

	{ "reform",		"format_paragraph",	S_CALL,
"reform\n\
	Reformats a paragraph, adjusting it to the current right margin." },
	
	{ "toggle_re",	  &cbrief_toggle_re,	NO_ARG,
"toggle_re\n\
	Toggles whether or not regular expressions are recognized\
	in patterns." },
	
	{ "remember",	&cbrief_remember,	NO_ARG,
"remember\n\
	Causes BRIEF to remember a sequence of keystrokes." },

	{ "repeat", &cbrief_repeat_char, C_SARG,
"repeat\n\
	Repeats a charater a specified number of times." },
		
	{ "move_edge", &cbrief_resize_win, NO_ARG },
% move_edge
%	Changes the dimension of a window by moving the window's edge.

	{ "right",		&go_right_1,		NO_ARG,
"right\n\
	Moves the cursor one column to the right, remaining on the same\
	line. If the cursor is moved into virtual space, the cursor changes\
	shape." },

	{ "right_side",	"scroll_left",		S_CALL,
"right_side\n\
	Moves the cursor to the right side of the window, regardless of the\
	length of the line." },

	{ "save_keystroke_macro", &cbrief_save_ksmacro, NO_ARG,
"save_keystroke_macro\n\
	Save the current keystroke macro in the specified file. If no\
	extension is specified, .km is assumed." },

	{ "screen_down", &scroll_down_in_place,	NO_ARG,
"screen_down\n\
	Moves the buffer, if possible, down one line in the window, keeping\
	the cursor on the same text line." },

	{ "screen_up",	&scroll_up_in_place,	NO_ARG,
"screen_up\n\
	Moves the buffer, if possible, up one line in the window, keeping\
	the cursor on the same text line." },

	{ "search_again",	&cbrief_search_again, NO_ARG,
"search_again\n\
	Searches either forward or backward for the last given pattern,\
	depending on the direction of the previous search." },

	{ "search_back", 	&cbrief_search_back, NO_ARG,
"search_back\n\
	Searches backward from the current position to the beginning of the\
	current buffer for the given pattern." },

	{ "search_fwd",		&cbrief_search_fwd, NO_ARG,
"search_fwd\n\
	Searches forward from the current position to the end of the\
	current buffer for the given pattern." },

	{ "dos", &cbrief_dos, C_LINE,
"dos\n\
	Gets parameter the command-line and pauses at exit,\
	or just runs the shell.\n\n\
	Exits temporarily to the operating system." },

	{ "swap_anchor", &exchange_point_and_mark,	NO_ARG,
"swap_anchor\n\
	Exchanges the current cursor position with the mark." },

	{ "tabs",		&cbrief_tabs,		C_SARG,
"tabs\n\
	Sets the tab stops for the current buffer." },

	{ "top_of_buffer",	&bob,			NO_ARG,
"top_of_buffer\n\
	Moves the cursor to the first character of the buffer." },

	{ "top_of_window",	&goto_top_of_window,	NO_ARG,
"top_of_window\n\
	Ctrl+Home moves the cursor to the top line of the current window,\
	retaining the column position. Home Home moves the cursor to the\
	top line and the first column of the current window." },

	{ "translate_again",	&cbrief_translate_again,	NO_ARG,
"translate_again\n\
	Searches again for the specified pattern in the direction of the\
	previous Translate command, replacing it with the given string." },

	{ "translate_back",		&cbrief_translate_back,		C_SARG,
"translate_back\n\
	Searches for the specified pattern from the current position to the\
	beginning of the buffer, replacing it with the given string." },

	{ "translate",			&cbrief_translate,			C_SARG,
"translate\n\
	Searches for the specified pattern from the current position to the\
	end of the buffer, replacing it with the given string." },

	{ "undo",			"undo",			S_CALL,
"undo\n\
	Reverses the effect of the last n commands (or as many as your\
	memory can hold). Any command that writes changes to disk (such as\
	Write) cannot be reversed." },

	{ "up",				&go_up_1,		NO_ARG,
"up\n\
	Moves the cursor up one line, staying in the same column. When the\
	cursor is moved into virtual space, it changes shape." },

	{ "toupper",	"cbrief_block_to('u')",	S_LANG,
"toupper\n\
	Converts the characters in a marked block to uppercase." },

	{ "use_tab_char",	&cbrief_use_tab,	C_SARG,
"use_tab_char\n\
	Determines whether spaces or tabs are inserted when the Tab key is\
	pressed to add filler space." },

% warnings_only
%	Forces the Compile buffer command to check the output from the
%	compiler for messages. If any warning or error messages are	found,
%	the compile is considered to have failed.

	{ "write_buffer",	&cbrief_write,				C_SARG,
"write_buffer\n\
	Writes the current buffer to disk or, if a block of text is marked,\
	prompts for a specific file name. BRIEF does not support writing\
	column blocks." },

	{ "write_and_exit",	&cbrief_write_and_exit,		NO_ARG,
"write_and_exit\n\
	Writes all modified buffers, if any, and exits BRIEF without\
	prompting." },

	{ "zoom_window",	&onewindow,					NO_ARG,
"zoom_window\n\
	If there is more than one window on the screen, Zoom window toggle\
	will enlarge the current window to a full screen window, and save\
	the previous window configuration." },

	{ "whichkey",			&showkey,					NO_ARG,
"whichkey\n\
	Tells which command is invoked by a key. (brief, non-std)" },

	{ "showkey",			"whichkey",					CALIAS },

	{ "ascii_code",			&cbrief_ascii_code,			C_LINE,
"ascii_code\n\
	Inserts character by ASCII code. (brief, non-std)" },

	{ "save_position",		&push_spot,					NO_ARG,
"save_position\n\
	Save cursor position into the stack." },

	{ "restore_position",	&pop_spot,					NO_ARG,
"restore_position\n\
	Restores previous cursor position from stack." },

	{ "insert",				&cbrief_insert,				C_LINE,
"insert\n\
	Inserts a string into the current position." },

	{ "_home",				&brief_home,				NO_ARG,
"_home\n\
	.BRIEF's home key.\n\
\n\
	[Home] = Beginning of Line.\n\
	[Home][Home] = Top of Window.\n\
	[Home][Home][Home] = Beginning of Buffer.\n\
\n\
	There was 2 version of home macro, the _home and the new_home.\
	The only I remember is that the _home could	not stored in\
	KeyStroke Macros. The same for the _end." },

	{ "_end",				&brief_end,					NO_ARG,
"_end\n\
	.BRIEF's end key.\n\
\n\
	[End] = End of Line.\n\
	[End][End] = Bottom of Window.\n\
	[End][End[End] = End of Buffer." },

	{ "brace",				&cbrief_brace,				NO_ARG,
"brace\n\
	BRIEF's check braces macro (the buggy one)." },

	{ "comment_block",		&comment_region_or_line,	NO_ARG },
% comment_block
%	Comment block

	{ "uncomment_block",	&uncomment_region_or_line,	NO_ARG },
% uncomment_block
%	Uncomment block

	{ "build_it",			&cbrief_build_it,			NO_ARG },
	{ "make",				&cbrief_build_it,			NO_ARG },
% build_it
%	Runs make (non-brief)

	{ "tocapitalize",		"cbrief_block_to('c')",		S_LANG },
% tocapitalize
%	Jed's xform_region('c') (non-brief)

% man, shows a man page (non-brief). Unix-like systems only.
	{ "man",				&cbrief_man,				C_LINE,
"man [[-s section1[,section2[...]]] [keyword]]\n\
	Shows system manual page. Each page argument given to man is normally the name of a program, utility or function.\
	The manual page associated with each of these arguments is then found and displayed.\
	A section, if provided, will direct man to look in that section of the manual.\
	Multiple sections can defined separating with comma and in search priority." }, 

% misc
	{ "set",	 			&cbrief_rcset, 				C_SARG,
"set [variable value]\n\
	Set command sets the value of a variable. Without parameters it is displays\
	all variables." },
	{ "setenv",	 			&cbrief_setenv, 			C_SARG,
"setenv [variable value]\n\
	Setenv command sets the value of an environment variable.\
	Without parameters it is displays all variables." },
	{ "alias",				&cbrief_cli_alias,			C_SARG,
"alias [cmd cmd]\n\
	Creates an alias of a command." },
	{ "mesg",				&mesg,						C_SARG,
"mesg\n\
	Displays the parameters at message-line." },
	{ "echo",				"mesg",						CALIAS },
	{ "mesgf",				&mesgf,						C_SARG,
"mesgf\n\
	Same as mesg but the first parameter must be a printf's format string." },
	{ "color_scheme",		&cbrief_color_scheme,		C_SARG },

% basic file actions
	{ "file_edit",			&cbrief_file_edit,			C_SARG,
"file_edit [filename] (basic API)\n\
	Loads a file to the editor in new buffer and switches to it." },
	{ "file_open",			"file_edit",				CALIAS },

	{ "file_at_cursor", 	&cbrief_open_file_at_cursor,	C_SARG,
"file_at_cursor (basic API)\n\
	Uses the filename under the cursor to open file in new buffer and switches to it." },

	{ "file_load",			&cbrief_file_read,			C_SARG,
"file_load [filename] (basic API)\n\
	Loads a file to the editor in new buffer." },
	{ "file_read",			"file_load",				CALIAS },
	{ "file_insert",		&cbrief_file_insert,		C_SARG,
"file_insert [filename] (basic API)\n\
	Inserts the contents of a file into the current buffer, at the current position." },
	{ "file_delete",		&cbrief_file_delete,		C_SARG,
"file_delete [filename] (basic API)\n\
	Physical deletion of file." },
	{ "file_rename",		&cbrief_file_rename,		C_SARG,
"file_rename [old] [new] (basic API)\n\
	Renames the file name old to new." },
	{ "file_move",			"file_rename",				CALIAS },
	{ "file_copy",			&cbrief_file_copy,			C_SARG,
"file_copy [source target] (basic API)\n\
	Copies file source to target." },
	{ "file_chmod",			&cbrief_file_chmod,			C_SARG,
"file_chmod [mode filename] (basic API)\n\
	Changes the access mode of the filename." },

% directory specific
	{ "pwd",				&cbrief_dir_pwd,			NO_ARG,
"pwd (basic API)\n\
	Displays the current working directory." },
	{ "chdir",				&cbrief_dir_chdir,			C_SARG,
"chdir [dir] (basic API)\n\
	Changes directory." },
	{ "cd",					"chdir",					CALIAS },
	{ "mkdir",				&cbrief_dir_mkdir,			C_SARG,
"mkdir [dir] (basic API)\n\
	Creates a new directory." },
	{ "rmdir",				&cbrief_dir_rmdir,			C_SARG,
"rmdir [dir] (basic API)\n\
	Deletes a directory. The directory must be empty." },

% buffer actions
	{ "buffer_clear",		&cbrief_buffer_clear,		C_SARG,
"buffer_clear [buf] (basic API)\n\
	Erase the contents of the buffer." },
	{ "clear",				"buffer_clear",				CALIAS },
	{ "buffer_save",		&cbrief_buffer_write,		C_SARG,
"buffer_save [buf [file]] (basic API)\n\
	Writes the contents of the buffer to disk." },
	{ "buffer_save_as",		&cbrief_buffer_save_as,		C_SARG,
"buffer_save_as [file] (basic API)\n\
	Writes the contents of the buffer to disk as new file." },
	{ "buffer_write",		"buffer_save",				CALIAS },
	{ "buffer_new",			&cbrief_buffer_new,			C_SARG,
"buffer_new [name] (basic API)\n\
	Creates a new buffer." },
	{ "buffer_list",		&cbrief_buffer_list,		C_SARG,
"buffer_list [buf-name | buf-num] (basic API)\n\
	Displays the buffers in the message line.\
	If parameter is given then switches to the given buffer." },
	{ "buffer_select",		"buffer_list",				CALIAS },
	{ "buffer_rename",		&cbrief_buffer_rename,		C_SARG,
"buffer_rename [bufname [newname]] (basic API)\n\
	Renames a buffer." },
	{ "buffer_close",		&cbrief_buffer_close,		C_SARG,
"buffer_close [buf] (basic API)\n\
	Removes from memory the selected buffer." },
	{ "buffer_next",		&cbrief_buffer_next,		NO_ARG,
"buffer_next (basic API)\n\
	Switches to the next buffer." },
	{ "buffer_prev",		&cbrief_buffer_prev,		NO_ARG,
"buffer_prev (basic API)\n\
	Switches to the previous buffer." },
	{ "buffer_cbufed",		&cbrief_buffer_list_tui,	NO_ARG,
"buffer_cbufed (basic API)\n\
	Opens the TUI buffers editor." },
	{ "cbufed",				"buffer_cbufed",			CALIAS },

%   compile_parse_errors                parse next error
%   compile_previous_error              parse previous error
%   compile_parse_buf                   parse current buffer as error messages
%   compile                             run program and parse it output
	{ "compile_parse_errors", &compile_parse_errors, C_SARG },
	{ "compile_previous_error", &compile_previous_error, C_SARG },
	{ "compile_parse_buf", &compile_parse_buf, C_SARG },

	{ "save_buffer",        &save_buffer,               NO_ARG,
"save_buffer\n\
	Write the current buffer." },
	{ "save_buffers",       &save_buffers,              NO_ARG,
"save_buffers\n\
	Writes all modified buffers." },
	{ "save_n_exit",        &cbrief_write_and_exit(),   NO_ARG,
"save_n_exit\n\
	Writes all modified buffers and exit to OS." },

%
	{ "xclip",				&xclip,						C_SARG,
"xclip [-i|-o] [text] (non-brief)\n\
	Calls external 'xclip' utility to copy into/from X clipboard.\
	Do you no need to call it directly.\
	This command should be used in case something wrong goes on with X clipboard keys." },

	{ "xcopy",				&cbrief_xcopy,				NO_ARG,
"xcopy (non-brief)\n\
	Copies the selected block to system clipboard." },

	{ "xpaste",				&cbrief_xpaste,				NO_ARG,
"xpaste	(non-brief)\n\
	Inserts the contents of system clipboard into the current bufffer." },

	{ "xcut",				&cbrief_xcut,				NO_ARG,
"xcut (non-brief)\n\
	Copies the selected block to system clipboard and deletes the selection." },
	
});
	} % cbrief_maclist_init

%!%+
%\function{cbrief_in}
%\synopsis{Executes CBRIEF's macros}
%\usage{Integer cbrief_in(argv|NULL, ...)}
%\description
% Executes cbrief "bultins" macros.
%	
%\var{argv} = The list of the parameters.
% The first parameter is the name of the command to execute, and the
% rest are the command's parameters.
%
% If \var{argv} is NULL (omitted) then the following parameters will
% count as the elements of \var{argv}.
%
% Returns 0 if the command does not exists; otherwise 1 on success
% or -1 on error.
%!%-

% part of cbrief_command() engine, execute the macro argv[0] with argv arguments
% returns
% 0 success; nothing to execute
% 1 success, i handle it
% 2 continue, i didnt found it
define cbrief_in(argc, argv) {
	variable i, j, l, ctype, _sp1, _sp2;
	variable e, f, s, list;
	variable err, cmd = argv[0];

	ifnot ( mac_index_init ) % if there is not index
		cbrief_build_cindex(); % build it
	
	% find the command
	try(err) { e = mac_index[cmd]; } catch AnyError: { return 2; } % just not found
	if ( e[2] == CALIAS ) {
		cmd = e[1];
		for ( i = 1; i < argc; i ++ )
			cmd = strcat(cmd, " ", argv[i]);
		cbrief_command(cmd);
		return 1;
		}
	ctype = e[2];

	% mark stack
	_sp1 = _stkdepth();

	% run it
	switch ( ctype )
	{ case C_ARGV: (@e[1])(__push_argv(argv)); }
	{ case C_ARG2: (@e[1])(argc, argv); }
	{ case C_SARG:
		if ( length(argv) > 1 ) {
			variable argv_o = String_Type[length(argv)-1];
			for ( j = 1; j < length(argv); j ++ )
				argv_o[j-1] = argv[j];
			(@e[1])(__push_argv(argv_o));
			}
		else
			(@e[1])();
		}
	{ case C_LINE: {
		variable cline = "";
		for ( i = 1; i < argc; i ++ )
			cline = strcat(cline, argv[i], " ");
		cline = strtrim(cline);
		ifnot ( strlen(cline) )
			(@e[1])();
		else
			(@e[1])(cline);
			}
		}
	{ case S_LANG: eval(e[1]); }
	{ case S_CALL: call(e[1]); }
	{ case NO_ARG: (@e[1])(); }
	{ throw RunTimeError, "CBI-2: element in cbrief_macros_list has undefined call-type"; }
	% cleanup the stack
	_sp2 = _stkdepth();
	if ( _sp2 - _sp1 > 0 ) _pop_n(_sp2 - _sp1);
	
	% success, ignore errors for now
	return 1;
	}

%%
%%	Execute BRIEF's commands
%%
%%	f(..) = S-Lang syntax
%%	m x   = BRIEF syntax
%%
static variable mac_hist_file = vdircat(get_jed_home(), "data", ".hist_cmdline");

private define cbrief_build_opts() {
	variable opts_a;
	opts_a = assoc_get_keys(mac_index);
	opts_a = opts_a[array_sort(opts_a)];
	mac_opts = strjoin(opts_a, ",");
	}

%%
%%	Command line calculator
%% 
%%	this is the '?' prefix of the command-line
%% 
public define cbrief_calc() {
	variable x, s = "", o = _get_symbol('|');
	
	loop ( _NARGS ) {
		x = ();
		if ( typeof(x) == String_Type )
			s += sprintf(" %s %c", x, o);
		else		
			s += sprintf(" Int %d (0x%08X) %c Real %.3f (%e) %c",
				(int)(x), (int)(x), o, double(x), double(x), o);
		}
	s = strfit(s, window_info('w'), 1);
	mesg(s);
	}

%%
%%	run a command and ...
%%	mode = 1, store the results in new buffer
%%	mode = 2, insert to the current buffer (at current position)
%%	mode = 3, replace the current text
%%	mode & 0x10 = use stdin file
%%	this is the '[<[<]]|' prefix of the command-line
%%
%.TS
%allbox;
%c c c c l.
%%	mode = 1, store the results in new buffer
%%	mode = 2, insert to the current buffer (at current position)
%%	mode = 3, replace the current text
%.TE
% <| groff -T utf8 -P-c -P-b -P-u -t
%% 
define cbrief_run_pipe(command_line, mode) {
	variable output, cmd, exit_status, error_code;
	variable inp_file  = make_tmp_file("run-pipe-");
	variable newbuf = "*newfile*";

	if ( mode & 0x10 ) {
		if ( is_visible_mark() ) {
			() = dupmark();
			() = write_region_to_file(inp_file);
			}
		else {
			push_spot();
			bob(); push_mark(); eob();
			() = write_region_to_file(inp_file);
			pop_spot();
			}
		cmd = strcat(command_line, " < ", inp_file);
		}
	else
		cmd = command_line;
	
	(output, exit_status, error_code) = c_shell(cmd);
	if ( access(inp_file, W_OK) == 0 )
		() = delete_file(inp_file);

	if ( exit_status == 0 ) {
		if ( (mode & 0x0F) == 1 ) { % place the output to new buffer
			if ( bufferp(newbuf) )	newbuf += "+";
			sw2buf(newbuf);
			insert(output);
			}
		else if ( (mode & 0x0F) == 2 ) % insert to the current buffer
			insert(output);
		else if ( (mode & 0x0F) == 3 ) { % replace current buffer
			if ( is_visible_mark() ) del_region();
			else clear_buffer();
			insert(output);
			}
		}

	if ( exit_status < 0 )
		uerrorf("Command failed. Command '%s' not found! Error code %d.", cmd, error_code);
	else if ( exit_status > 0 )
		uerrorf("Command failed. Command return exit code %d. Error code %d.", exit_status, error_code);
	else
		mesgf("Command succeed. %d characters inserted.", strlen(output));
	}

% csplit callback to expand ${} variables
public define cbrief_getvar(name) {
	variable val;

	val = rc_get(rcmem, name);
	if ( val == NULL )	{
		val = rc_get(rc, name);
		if ( val == NULL )
			val = getenv(name);
		}
	return val;
	}

%!%+
%\function{cbrief_command}
%\usage{void cbrief_command([command-line-string])}
%\synopsis{executes a macro command lile}
%\description
%  Executes a macro command lile.
%  There are several mechanisms about what and how to execute,
%  where to put or use the reustls, that are described in the
%  long help page.
%!%-
public define cbrief_command() {
	variable in = (_NARGS) ? () : NULL;
	variable i, l, n, cmd, err, e, fp;
	variable a, what, with, flags, exit_code, error_code;
	variable bWiden;

	if ( mac_opts == "" )	 % if not macro-list is defined
		cbrief_build_opts(); % define it

	if ( in == NULL ) { % no command-line, get input from keyboard
		set_mini_complete("mini_sellist(mac_opts)");
	    mini_use_history("command");
		in = read_mini("Command:", "", "");
	    mini_use_history(NULL);
		set_mini_complete(NULL);
		scr_redraw();
		if ( in == NULL ) return; % cancelled input
		}
		
	in = strtrim(in);
	ifnot ( strlen(in) ) return; % empty string given

	err = 0;
	% print/calc something
	if ( in[0] == '?' ) {
		in = strtrim(substr(in, 2, strlen(in) - 1));
		in = strcat("cbrief_calc(", in, ");");
		try(e) { eval(in); }
		catch AnyError: { err = -1; uerrorf("Error in expression: %s [%s]", e.message, in); }
		}
	% eval() somthing
	else if ( in[0] == '$' ) {
		in = substr(in, 2, strlen(in) - 1);
		try(e) { eval(in); }
		catch AnyError: { err = -1; uerrorf("%s [%s]", e.message, in); }
		}
	% run shell command, output in this buf in the current pos
	else if ( in[0] == '<' && in[1] == '<' && in[2] == '!' ) {
		cmd = strtrim(substr(in, 4, strlen(in) - 3));
		cbrief_run_pipe(cmd, 2);
		}
	% run shell command, output in this buf
	else if ( in[0] == '<' && in[1] == '!' ) {
		cmd = strtrim(substr(in, 3, strlen(in) - 2));
		cbrief_run_pipe(cmd, 3);
		}
	% run shell command, output in new buf
	else if ( in[0] == '!' ) {
		cmd = strtrim(substr(in, 2, strlen(in) - 1));
		cbrief_run_pipe(cmd, 1);
		}
	% run shell command, in new term
	else if ( in[0] == '&' ) {
#ifdef UNIX
		variable xterm;
		
		in = substr(in, 2, strlen(in) - 1);			
		if ( is_xjed() || getenv("DISPLAY") != NULL ) {
			xterm = cbrief_find_xterm();
			cmd = strcat(xterm + " -e ", in, " &");
			}
		else
			cmd = strcat(getenv("SHELL") + " -c '", in, "' &");
		scr_save();
		() = system(cmd);
		scr_restore();
		scr_redraw();
#else
		uerror("Not supported in this OS");
#endif
		}
	% run shell command ... dont ask
	else if ( in[0] == '~' ) {
		scr_save();
		() = system(in);
		scr_restore();
		scr_redraw();
		}
	% append selected text of the whole buffer to output
	else if ( in[0] == '>' && in[1] == '>' ) {
		in = strtrim(substr(in, 3, strlen(in) - 2));
		if ( file_status(in) == 1 || file_status(in) == 0 ) {
			if ( is_visible_mark() )
				append_region_to_file(in);
			else {
				push_spot();
				bob(); push_mark(); eob();
				append_region_to_file(in);
				if ( markp() )
					pop_mark_0();
				pop_spot();
				}
			}
		else
			uerrorf("Access denied. [%s]", in);
		}
	% write selected text of the whole buffer to output
	else if ( in[0] == '>' ) {
		in = strtrim(substr(in, 2, strlen(in) - 1));
		if ( access(in, F_OK) == 0 )
			if ( delete_file(in) == 0 )
				uerrorf("Access denied. [%s]", in);
		
		if ( file_status(in) == 0 ) {
			if ( is_visible_mark() )
				() = write_region_to_file(in);
			else {
				push_spot();
				bob(); push_mark(); eob();
				() = write_region_to_file(in);
				if ( markp() )
					pop_mark_0();
				pop_spot();
				}
			}
		}
	% execute command through pipe and append the results in the current buffer
	else if ( in[0] == '<' && in[1] == '<' && in[2] == '|' ) {
		cmd = strtrim(substr(in, 4, strlen(in) - 3));
		cbrief_run_pipe(cmd, 0x12);
		}
	% execute command through pipe in the current buffer
	else if ( in[0] == '<' && in[1] == '|' ) {
		cmd = strtrim(substr(in, 3, strlen(in) - 2));
		cbrief_run_pipe(cmd, 0x13);
		}
	% execute command through pipe and output to new buffer
	else if ( in[0] == '|' ) {
		cmd = strtrim(substr(in, 2, strlen(in) - 1));
		cbrief_run_pipe(cmd, 0x11);
		}
	% insert the contents of a file to this location
	else if ( in[0] == '<' && in[1] == '<' ) {
		cmd = strtrim(substr(in, 3, strlen(in) - 2));
		if ( strlen(cmd) && (access(cmd, R_OK) == 0) )
			insert_file(cmd);
		else {
			cmd = dlg_selectfile("Insert file");
			if ( cmd != NULL && (access(cmd, R_OK) == 0) )
				insert_file(cmd);
			}
		}
	% replace buffer contents with the contents of a file
	else if ( in[0] == '<' ) {
		cmd = strtrim(substr(in, 2, strlen(in) - 1));
		if ( strlen(cmd) && (access(cmd, R_OK) == 0) ) {
			if ( is_visible_mark() ) del_region();
			else clear_buffer();
			() = insert_file(cmd);
			}
		else {
			cmd = dlg_selectfile("Insert file");
			if ( cmd != NULL && (access(cmd, R_OK) == 0) ) {
				if ( is_visible_mark() ) del_region();
				else clear_buffer();
				() = insert_file(cmd);
				}
			}
		}
	% sed syntax, search [& replace] // for real sed run '| sed ...' or '<| sed s...'
	else if ( in[0] == '/' || (in[0] == 's' && in[1] == '/') ) { % search [& replace]
		cmd = in[0];
		if ( cmd == 's' )
			n = csplit(substr(in, 3, -1), "/", 0x18);
		if ( cmd == '/' )
			n = csplit(substr(in, 2, -1), "/", 0x18);
		a = __pop_list(n);
		if ( n >= 1 ) what  = a[0]; else what = "";
		if ( n >= 2 ) with  = a[1]; else with = "";
		if ( n >= 3 ) flags = a[2]; else flags = "";
		if ( cmd == 's' )
			mesgf("s/%s/%s/%s", what, with, flags);
		else
			mesgf("/%s/%s/%s", what, with, flags);
		if ( strlen(what) ) {
			while ( 1 ) {
				LAST_SEARCH = what;
				if ( cmd == 's' ) {
					LAST_RSEARCH = what;
					LAST_REPLACE = with;
					}
				l = re_fsearch(what);
				if ( l == 0 ) {
					if ( flags != "g" )
					mesg("Not found!");
					break;
					}
				else if ( cmd == 's' )
					replace_match(with, 0);
				
				if ( flags != "g" )
					break;
				}
			}
		}
	else {
		% it is command line
		rc_set(rcmem, "buf",  whatbuf());
		rc_set(rcmem, "file", buffer_filename());
		rc_set(rcmem, "line", sprintf("%d", what_line()));
		rc_set(rcmem, "col",  sprintf("%d", what_column()));

		variable argc = vcsplit(in, " \t", 0x18, "cbrief_getvar");
		variable argv = String_Type[argc];
		for ( i = 0; i < argc; i ++ )
			argv[i] = ();
		array_reverse(argv);

		err  = cbrief_in(argc, argv);
		cmd  = argv[0];

		if ( err == 2 ) {	% command not found, it is not CBRIEF's build in
			variable f_int = is_internal(cmd);
			variable f_def = is_defined(cmd);
			
			if ( f_int || f_def ) {
				if ( argc == 1 ) { % it is only a word
					if ( f_int )
						call(cmd);
					else { % f_def
						cmd = strcat(argv[0], "();");
						try(e) { eval(cmd); } catch AnyError: { err = -1; uerrorf("CBC-2: %s", e.message); }
						}
					}
				else if ( f_int ) {
					% build for slang
					cmd = strcat(argv[0], "(");
					for ( i = 1; i < argc; i ++ ) {
						if ( argv[i][0] == '"' || argv[i][0] == '\'' )
							cmd = strcat(cmd, argv[i], ",");
						else
							cmd = strcat(cmd, "\"", argv[i], "\",");
						}
					if ( argc > 1 )
						cmd = substr(cmd, 1, strlen(cmd)-1);
					cmd = strcat(cmd, ")");
					try(e) { eval(cmd); } catch AnyError: { err = -1; uerrorf("CBC-3: %s", e.message); }
					}
				else { uerrorf("'%s' is internal, cannot have parameters.", argv[0]); }
				}
			else { uerrorf("'%s' undefined.", argv[0]); }
			}
		}

%	if ( err < 0 )		return;		% if error, stop
%	if ( _NARGS > 0 )	continue;	% if has more arguments, continue
%	if ( err > 0 )		return;		% if success return
	}

%% --- menus --------------------------------------------------------------

public define edit_file_abbrev()	{ find_file(vdircat(get_jed_home(), "abbrev.sl")); }
public define edit_file_jedrc()		{ find_file(vdircat(get_jed_home(), "jedrc.sl")); }
public define edit_file_local()		{ find_file(vdircat(get_jed_home(), "local.sl")); }
public define edit_file_cbvar()		{ find_file(vdircat(get_jed_home(), "data", "cbrief.rc")); }
public define edit_file_hostrc()	{ find_file(vdircat(get_jed_home(), strcat(get_hostname(), ".sl"))); }
public define cbrief_tools_make()	{ compile("make"); }

private variable _menu_init = 0;
private variable _menu_stack = { }; % data to added to menu (stack of rq before menu initialized)

private define about_jed(unused) {
	variable about_doc = expand_jedlib_file("aboutjed.hlp");
	sw2buf ("*about jed*");
	set_readonly(0);
	erase_buffer();
	vinsert ("Jed Version: %s\nS-Lang Version: %s\n\n", _jed_version_string, _slang_version_string);
	if ( about_doc != "" )
		() = insert_file(about_doc);
	else
		insert ("aboutjed.hlp not found");
	set_buffer_modified_flag(0);
	bob();
	view_mode();
	}

private define cbrief_load_popups_hook() {
	variable m, e;

	m = "Global";
%	menu_delete_items(m);
%	menu_create_menu_bar(m);
%	menu_set_menu_bar_prefix(m, " F12 ==> ");
%	menu_append_popup(m, "&File");
%	menu_append_popup(m, "&Edit");
%	menu_append_popup(m, "M&ode");  %  mode-specific
%	menu_append_popup(m, "&Search");
%	menu_append_popup(m, "&Buffers");
%	menu_append_popup(m, "&Tools");
%	menu_append_popup(m, "W&indows");
%	menu_append_popup(m, "S&ystem");
%	menu_append_popup(m, "&Help");
%	menu_insert_popup("W&indows", m, "&Tools");

	m = "Global.&File";
	menu_delete_items(m);
	menu_append_item(m, "&Edit", "cbrief_file_edit_tui");
	menu_append_item(m, "Open File At C&ursor", "cbrief_open_file_at_cursor");
	menu_append_item(m, "&Close", "cbrief_buffer_close");
	menu_append_item(m, "&Write", "cbrief_write");
	menu_append_item(m, "Write &As", "cbrief_buffer_save_as");
%	menu_append_item(m, "Change &Output File", "cbrief_output_file");
	menu_append_item(m, "Save All &Buffers", "save_buffers");
	menu_append_item(m, "&Read File", "cbrief_file_insert");
	% if has more menus in the stack, add separator
%	foreach e ( _menu_stack ) { if ( e[0] == m ) { menu_append_separator(m); break;	} }

	m = "Global.&Edit";
	menu_delete_items(m);
	menu_append_item(m, "&Mark", "cbrief_stdmark");
	menu_append_item(m, "Non-inclusive M&ark", "cbrief_noinc_mark");
	menu_append_item(m, "&Column Mark", "cbrief_mark_column");
	menu_append_item(m, "&Line Mark", "cbrief_line_mark");
	menu_append_separator(m);
	menu_append_item(m, "C&opy", "cbrief_copy");
	menu_append_item(m, "C&ut", "cbrief_cut");
	menu_append_item(m, "&Paste", "cbrief_paste");
	menu_append_item(m, "&Delete", "cbrief_delete");
	menu_append_popup(m, "&X Clipboard");
	menu_append_separator(m);
	menu_append_popup(m, "Re&gion Ops");
%	menu_append_popup(m, "&Rectangles");
%	menu_append_separator(m);
	menu_append_popup(m, "&Key Macros");
	menu_append_separator(m);
	menu_append_item(m, "&Undo", "undo");
	menu_append_item(m, "&Redo", "redo");
	menu_append_separator(m);
%	menu_append_item(m, "Slide &in block or line",	"cbrief_slide_in");
%	menu_append_item(m, "Slide ou&t block or line",	"cbrief_slide_out");
	menu_append_popup(m, "&Text");
%	menu_append_item(m, "Co&mment Region/Line",		"comment_region_or_line");
%	menu_append_item(m, "U&ncomment Region/Line",	"uncomment_region_or_line");
	% if has more menus in the stack, add separator
%	foreach e ( _menu_stack ) { if ( e[0] == m ) { menu_append_separator(m); break;	} }

	m = "Global.&Edit.&X Clipboard";
	menu_append_item(m, "X C&opy",  "cbrief_xcopy");
	menu_append_item(m, "X C&ut",   "cbrief_xcut");
	menu_append_item(m, "X &Paste", "cbrief_xpaste");
	menu_append_item(m, "Toggle &X/Intern", "cbrief_toggle_xclip");

	m = "Global.&Edit.&Key Macros";
%	menu_append_item(m, "&Start Macro", "begin_macro");
%	menu_append_item(m, "S&top Macro", "end_macro");
%	menu_append_item(m, "Replay &Last Macro", "execute_macro");
	menu_append_item(m, "&Remember", "cbrief_remember");
	menu_append_item(m, "Pa&use",    "cbrief_pause_ksmacro");
	menu_append_item(m, "&Playback", "cbrief_playback");
	menu_append_separator(m);
	menu_append_item(m, "&Load Macro",    "cbrief_load_ksmacro");
	menu_append_item(m, "&Save Macro",    "cbrief_save_ksmacro");

	m = "Global.&Edit.Re&gion Ops";
	menu_append_item(m, "&Upper Case", ".'u' xform_region");
	menu_append_item(m, "&Lower Case", ".'d' xform_region");
	menu_append_item(m, "&Comment Region/Line", "comment_region_or_line");
	menu_append_item(m, "U&ncomment Region/Line", "uncomment_region_or_line");
	menu_append_item(m, "Slide &In Region/Line",	"cbrief_slide_in");
	menu_append_item(m, "Slide &Out Region/Line",	"cbrief_slide_out");
	menu_append_separator(m);
	menu_append_item(m, "&Write to File", "cbrief_write");
	menu_append_item(m, "&Append to File", "append_region");
%	menu_append_separator(m);
%	menu_append_item(m, "Copy To &Register", "reg_copy_to_register");
%	menu_append_item(m, "&Paste From Register", "reg_insert_register");
%	menu_append_item(m, "&View Registers", "register_mode");
%	m = "Global.&Edit.&Rectangles";
	menu_append_separator(m);
	menu_append_item(m, "C&ut Rectangle", "kill_rect");
	menu_append_item(m, "Cop&y Rectangle", "copy_rect");
	menu_append_item(m, "Pas&te Rectangle", "insert_rect");
	menu_append_item(m, "Op&en Rectangle", "open_rect");
	menu_append_item(m, "&Blank Rectangle", "blank_rect");

	m = "Global.&Edit.&Text";
	menu_append_item(m, "&Center Line", "center_line");
	menu_append_item(m, "&Right Line", "right_line");
	menu_append_item(m, "&Left Line", "left_line");
	menu_append_item(m, "Re&format", "format_paragraph");

	m = "Global.&Search";
	menu_delete_items(m);
	menu_append_item(m, "&Search",					"cbrief_search_fwd");
	menu_append_item(m, "&Reverse Search",			"cbrief_search_back");
	menu_append_item(m, "Search &Again",			"cbrief_search_again");
	menu_append_item(m, "Reverse Search Agai&n",	"cbrief_search_again_r");
	menu_append_item(m, "Find Next (Non-BRIEF)", 	"cbrief_find_next");
	menu_append_item(m, "Find Prev (Non-BRIEF)", 	"cbrief_find_prev");
	menu_append_separator(m);
	menu_append_item(m, "Toggle Regular &Expr.",	"cbrief_toggle_re");
	menu_append_item(m, "Toggle Case &Sens.",		"cbrief_search_case");	
	menu_append_separator(m);
	menu_append_item(m, "&Translate",				"cbrief_translate");
	menu_append_item(m, "Translate Back",           "cbrief_translate_back");
	menu_append_item(m, "Trans&late Again",          "cbrief_translate_again");
	menu_append_separator(m);
	menu_append_item(m, "Drop &Bookmark (1..10)", 	"cbrief_bkdrop");
	menu_append_item(m, "&Jump to Bookmark", 		"cbrief_bkgoto");
	menu_append_item(m, "&Goto Line", 				"cbrief_goto_line");
	menu_append_separator(m);
	menu_append_item(m, "Matching &Delimiter",		"cbrief_delim_match");
	% if has more menus in the stack, add separator
	foreach e ( _menu_stack ) { if ( e[0] == m ) { menu_append_separator(m); break;	} }

	m = "Global.&Buffers";
	menu_delete_items(m);	
	menu_append_popup(m, "&Toggle");
	menu_append_item(m, "&Change Buffer", "cbrief_buffer_list_tui");
	menu_append_item(m, "&Kill Buffer", "cbrief_buffer_close");
	menu_append_item(m, "JED Bufed", "bufed");
	menu_append_popup(m, "&Select Mode");
	menu_append_item(m, "Enable &Folding", "folding_mode");
	menu_append_separator(m);
	menu_append_item(m, "C&ompile", "compile");
	menu_append_item(m, "&Next Error", "compile_parse_errors");
	menu_append_item(m, "&Previous Error", "compile_previous_error");
	if ( is_defined ("gdb_mode") )
		menu_append_item (m, "Debug with &gdb", "gdb_mode");
	% if has more menus in the stack, add separator
	foreach e ( _menu_stack ) { if ( e[0] == m ) { menu_append_separator(m); break;	} }

	m = "Global.&Buffers.&Select Mode";
	menu_append_item(m, "&C Mode", "c_mode");
	menu_append_item(m, "&S-Lang Mode", "slang_mode");
	menu_append_item(m, "&Pascal Mode", "tpas_mode");
	menu_append_item(m, "P&erl Mode", "perl_mode");
	menu_append_item(m, "P&HP Mode", "php_mode");
	menu_append_item(m, "&AWK Mode", "awk_mode");
	menu_append_item(m, "&LaTeX Mode", "latex_mode");
	menu_append_item(m, "Te&X Mode", "tex_mode");
	menu_append_item(m, "&Man Mode", "manedit_mode");
	menu_append_item(m, "&Fortran Mode", "fortran_mode");
	menu_append_item(m, "F&90 Mode", "f90_mode");
	menu_append_item(m, "P&ython Mode", "python_mode");
	menu_append_item(m, "Ma&ke Mode", "make_mode");
	menu_append_item(m, "She&ll Mode", "sh_mode");
	menu_append_item(m, "&Text Mode", "text_mode");
	menu_append_item(m, "&No Mode", "no_mode");

	m = "Global.&Buffers.&Toggle";
	menu_append_item(m, "&Line Numbers", "toggle_line_number_mode");
	menu_append_item(m, "&Overwrite", "toggle_overwrite");
	menu_append_item(m, "&Read Only", "toggle_readonly");
	menu_append_item(m, "&CR/NL mode", "toggle_crmode");
	menu_append_separator(m);
	menu_append_item(m, "Toggle Regular &Expr.",	"cbrief_toggle_re");
	menu_append_item(m, "Toggle Case &Sens.",	"cbrief_search_case");

%	m = "Global.&Tools";
%	menu_append_item(m, "&Make ...", "cbrief_tools_make");

%	m = "Global.W&indows";
%	menu_append_item(m, "&One Window", "one_window");
%	menu_append_item(m, "&Split Window", "split_window");
%	menu_append_item(m, "O&ther Window", "other_window");
%	menu_append_item(m, "&Delete Window", "delete_window");
%	menu_append_separator(m);
%	menu_append_item(m, "&Color Schemes", ...);
%	menu_append_separator(m);
%	menu_append_item(m, "&Redraw", "redraw");

	m = "Global.S&ystem";
	menu_delete_items(m);	
	menu_append_item(m, "&Compile ...", "cbrief_compile_it");
	menu_append_item(m, "&Run ...", "cbrief_build_it");
	menu_append_item(m, "Shell &Window", "shell");
	if ( is_defined("toggle_auto_ispell") )
		menu_append_item(m, "Toggle Auto &Ispell");
	menu_append_item(m, "&Ispell", "ispell");
	menu_append_item(m, "C&alendar", "calendar");
	menu_append_item(m, "Co&mpletion", "dabbrev");
	menu_append_separator(m);
	menu_append_item(m, "&Make ...", "cbrief_tools_make");

	m = "Global.&Help";
	menu_delete_items(m);
	menu_append_item(m, "About &Jed", &about_jed, NULL);
	menu_append_separator(m);
	menu_append_item(m, "&Describe Key Bindings", "cbrief_help(\"keys\")");
	menu_append_item(m, "Show &Key", "showkey");
	menu_append_item(m, "&Where Is Command", "where_is");
	menu_append_separator(m);
	menu_append_item(m, "&Info Reader", "info_reader");
	menu_append_item(m, "&Unix Man Page", "unix_man");
	menu_append_separator(m);
	menu_append_item(m, "Help &on Keyword", "cbrief_word_help");
	menu_append_item(m, "Short CBRIEF &Help", "cbrief_help");
	menu_append_item(m, "Describe &CBRIEF Mode", "cbrief_long_help");

	% append the menu items in item stack...
	foreach e ( _menu_stack ) {
		if ( e[3] == NULL ) { % position
			if ( e[2] == "@{popup}" ) % command
				menu_append_popup(e[0], e[1]);
			else
				menu_append_item(e[0], e[1], e[2]);
			}
		else {
			if ( e[2] == "@{popup}" ) % command
				menu_insert_popup(e[3], e[0], e[1]);
			else
				menu_insert_item(e[3], e[0], e[1], e[2]);
			}
		}

	%	always at bottom
	m = "Global.&File";
	menu_append_separator(m);
	menu_append_item(m, "Cance&l Operation", "kbd_quit");
	menu_append_item(m, "S&hell", "shell");
	menu_append_item(m, "E&xit", "cbrief_exit");
%	menu_append_item(m, "Save and Exit", "cbrief_write_and_exit");
	
	%	always at bottom
	m = "Global.&Buffers";
	menu_append_separator(m);
	menu_append_item(m, "&0 Edit abbrev.sl",	"edit_file_abbrev");
	menu_append_separator(m);
	menu_append_item(m, "&1 Edit local.sl",		"edit_file_local");
	menu_append_item(m, strcat("&2 Edit ", get_hostname(), ".sl"), "edit_file_hostrc");
	menu_append_item(m, "&3 Edit cbrief.rc",	"edit_file_cbvar");

	m = "Global.S&ystem";
	menu_append_separator(m);
	menu_append_item(m, "C&BRIEF Console", "cbrief_command");
	menu_append_item(m, "Sus&pend CBRIEF", "cbrief_dos");
	
	% ok, we can accept now changes
	_menu_init = 1;
	}
add_to_hook("load_popup_hooks", &cbrief_load_popups_hook);

%% --- initialization -----------------------------------------------------

%% initialize
private define cbrief_init() {
	variable m, tab_kmaps = ["C", "SLang", "TPas", "make", "perl", "TCL", "Text", "PHP", "Lua", "python" ];

	% default tabstops
	Tab_Stops = [0:19] * TAB_DEFAULT + 1;

	% reinstall tab and back-tab
	foreach m ( tab_kmaps ) {
		if ( keymap_p(m) ) {
			if ( cbrief_control_wins() ) {
				setkey("cbrief_change_win",			Key_F1);
				setkey("cbrief_resize_win",			Key_F2);
				setkey("one_window",				Key_Alt_F2);
				setkey("cbrief_create_win",			Key_F3);
				setkey("cbrief_delete_win",			Key_F4);
				setkey("one_window",				"^Z");
				}
			if ( cbrief_control_tabs() ) {
				undefinekey("\t", m);	definekey("cbrief_slide_in(1)", "\t", m);
				undefinekey("\e\t", m);	definekey("cbrief_slide_out(1)", "\e\t", m);
				}
			if ( cbrief_control_indent() ) {
				undefinekey("{", m);	definekey("self_insert_cmd", "{", m);
				undefinekey("}", m);	definekey("self_insert_cmd", "}", m);
				undefinekey("(", m);	definekey("self_insert_cmd", "(", m);
				undefinekey(")", m);	definekey("self_insert_cmd", ")", m);
				undefinekey("[", m);	definekey("self_insert_cmd", "[", m);
				undefinekey("]", m);	definekey("self_insert_cmd", "]", m);
				undefinekey("\r", m);	definekey("cbrief_enter", "\r", m);
				}
			}
		}
	}

#ifdef UNIX
%% initialize display
private define cbrief_disp_init() {
	ifnot ( is_defined("x_server_vendor") )
		tt_send("\e=");  % set linux console to application mode keypad
	}
#endif

%% --- keys ---------------------------------------------------------------

%%	BRIEF's keys (BRIEF v3.1, 1991)

%% add keys to _cbrief_keymap by code
private define cbrief_build_keymap() {
	variable e, s;
	
	if ( typeof(_cbrief_keymap) == List_Type  )
		return; % already builded
	
	_cbrief_keymap = {
	%% Basic keys 
	{ "cbrief_escape",			"\e\e\e" },			% Brief Manual: Escape. ESC somehow to abort (^Q is set to abort)
	{ "cbrief_backspace",		Key_BS },			% Brief Manual: Backspace
	{ "cbrief_backspace",		"" },				% Brief Manual: Backspace (shift/capslock)
	{ "bdelete_word",			Key_Ctrl_BS },		% Brief Manual: Ctrl+Bksp. Delete Previous Word
	{ "delete_word",			Key_Alt_BS },		% Brief Manual: undefined, exists in KEYBOARD.H
	{ "cbrief_enter",			Key_Enter },		% Brief Manual: Enter
	{ "brief_open_line",		Key_Ctrl_Enter },	% Brief Manual: Ctrl-Enter. Open Line
	{ "cbrief_slide_in(1)",		Key_Tab },			% Brief Manual: Tab
	{ "cbrief_slide_out(1)",	Key_Shift_Tab },	% Brief Manual: Shift-Tab. Back Tab

	%%	Control keys
	{ "brief_line_to_eow",		"^B" },		 	% Brief Manual: Line to Bottom
	{ "brief_line_to_mow",		"^C" },		 	% Brief Manual: Center Line in Window. Here: Windows Copy
	{ "scroll_up_in_place", 	"^D" },		 	% Brief Manual: Scroll Buffer Down
	{ "@^OboF",					"^G" },		 	% Brief Manual: Go To Routine (popup list and select); JED/EMACS = abort
	{ "cbrief_slide_in(1)",		"^I" },		 	% tab
	{ "cbrief_slide_out(1)",	"\e^I" },	 	% backtab
	{ "brief_delete_to_bol",    "^K" },		 	% Brief Manual: Delete to beginning of line
	{ "redraw",					"^L" },		 	% undefined in Brief -- redraw, not a BRIEF key, but Unix one
	{ "cbrief_enter",			"^M" },		 	% enter
	{ "compile_parse_errors",	"^N" },		 	% Brief Manual: Next Error
	{ "compile_parse_buf",		"^P" },		 	% Brief Manual: Pop Up Error Window
	{ "kbd_quit",				"^Q" },		 	% Brief Manual: Pop Up Error Window
	{ "brief_line_to_bow",		"^T" },		 	% Brief Manual: Line to Top
	{ "redo",					"^U" },		 	% Brief Manual: Redo
	{ "cbrief_toggle_backup",	"^W" },		 	% Brief Manual: Backup File Toggle
	{ "cbrief_write_and_exit",	"^X" },		 	% Brief Manual: Write Files and Exit, Windows Cut
	{ "one_window",				"^Z" },		 	% Brief Manual: Zoom Window
	{ "cbrief_buffer_close",	"" },		 	% Brief Manual: Ctrl+Minus, Delete Curr. Buffer

	%%	Arrows and special keys
	{ "cbrief_paste",				Key_Ins },			% Brief Manual: Paste from Scrap
	{ "cbrief_delete",				Key_Del },			% Brief Manual: Delete
	{ "brief_home",					Key_Home },			% Brief Manual: Home BOL, Home Home = Top of Window, Home Home Home = Top of Buffer
	{ "brief_end",					Key_End  },			% Brief Manual: End  EOL, End  End  = End of Window, End  End  End  = End of Buffer
	{ "brief_pageup",				Key_PgUp },			% Brief Manual: Page Up
	{ "brief_pagedown",				Key_PgDn },			% Brief Manual: Page Down
	{ "scroll_right",				Key_Shift_Home },	% Brief Manual: Left side of Window
	{ "scroll_left",				Key_Shift_End },	% Brief Manual: Right side of Window
	{ "bob",						Key_Ctrl_PgUp },	% Brief Manual: Top of Buffer
	{ "eob",						Key_Ctrl_PgDn },	% Brief Manual: End of Buffer
	{ "goto_top_of_window",			Key_Ctrl_Home },	% Brief Manual: Top of Window
	{ "goto_bottom_of_window",		Key_Ctrl_End },		% Brief Manual: End of Window

	%%	KEYPAD (works on linux console and rxvt)
	{ "cbrief_copy",			Key_KP_Add },			% Brief Manual: Copy to Scrap
	{ "cbrief_cut",				Key_KP_Subtract },		% Brief Manual: Cut to Scrap
	{ "@\eu",					Key_KP_Multiply },		% Brief Manual: Undo
	{ "@^M",					Key_KP_Enter },			% enter
	{ "cbrief_paste",			Key_KP_0 },				% Brief Manual: Paste
	{ "cbrief_delete",			Key_KP_Delete },		% Brief Manual: Delete block or front character
	
	{ "brief_home",				Key_KP_7 },				% home
	{ "brief_end",				Key_KP_1 },				% end
	{ "brief_pageup",			Key_KP_9 },				% pgup
	{ "brief_pagedown",			Key_KP_3 },				% pgdn
	
	{ "previous_line_cmd",		Key_KP_8 },				% up
	{ "next_line_cmd",			Key_KP_2 },				% down
	{ "previous_char_cmd",		Key_KP_4 },				% left
	{ "next_char_cmd",			Key_KP_6 },				% right
	{ "brief_line_to_mow",		Key_KP_5 },				% undocumented, in my version was 'centered to window'

	%%	Brief's window keys
	%%
	%%	F1+arrow = Change Window, Alt+F1 = Toggle Borders
	%%	F2+arrow = Resize Window, Alt+F2 = Zoom Windows
	%%	F3+arrow = Create Window
	%%	F4+arrow = Delete Window
	%%
	%%  shift-arrow, alt-arrow = quick change window (Borland/KEYBOARD.H)
	%%
	{ "cbrief_change_win",			Key_F1 },		% Brief Manual: Change Window
	{ "cbrief_word_help",			Key_Ctrl_F1 },	% on-line help on word
	{ "cbrief_word_help",			"`" },		% on-line help on word non-brief second key (i have problem in the laptop)
	{ "cbrief_resize_win",			Key_F2 },		% Brief Manual: Resize Window
	{ "one_window",					Key_Alt_F2 },	% Brief Manual: Zoom
	{ "cbrief_create_win",			Key_F3 },		% Brief Manual: Create Window
	{ "cbrief_delete_win",			Key_F4 },		% Brief Manual: Delete Window (delete the other-window)

	%%	function keys
	{ "cbrief_search_fwd",			Key_F5 },		% Brief Manual: Search Forward
	{ "cbrief_search_back",			Key_Alt_F5 },	% Brief Manual: Search Backward
	{ "cbrief_search_again",		Key_Shift_F5 },	% Brief Manual: Search Again
	{ "cbrief_search_case",			Key_Ctrl_F5 },	% Brief Manual: Case Sens. Toggle
	
	{ "cbrief_translate",			Key_F6 },		% Brief Manual: Tanslate Forward
	{ "cbrief_translate_again",		Key_Shift_F6 },	% Brief Manual: Translate Again
	{ "cbrief_translate_back",		Key_Alt_F6 },	% Brief Manual: Translate Backward
	{ "cbrief_toggle_re",			Key_Ctrl_F6 },	% Brief Manual: Regular Expr. Toggle

	{ "cbrief_remember",			Key_F7 },		% Brief Manual: Remember (record macro)
	{ "cbrief_pause_ksmacro",		Key_Shift_F7 },	% Brief Manual: Pause Keystroke Macro
	{ "cbrief_load_ksmacro",		Key_Alt_F7 },	% Brief Manual: Load Keystroke Macro
	{ "cbrief_playback",			Key_F8 },		% Brief Manual: Playback
	{ "cbrief_save_ksmacro",		Key_Alt_F8 },	% Brief Manual: Save Keystroke Macro
	{ "macro_query",				Key_Shift_F8 },	% Macro Query: if not in the mini buffer and if during keyboard macro,
													%	allow user to enter different text each time macro is executed

	{ "cbrief_command",				Key_F10 },		% Brief Manual: Execute command (like M-x emacs but with parameters)
	{ "cbrief_command",				"\e=" },		% Alt = -- Alternative key for console, just in case...

	%%	Alt Keys
	{ "cbrief_noinc_mark",			"\ea" },		% Alt A -- Brief Manual: (3.1) Non-inclusive Mark; (BRIEF 2.1 = Drop BkMark)
	{ "cbrief_buffer_list_tui",		"\eb" },		% Alt B -- Brief Manual: Buffer List (buffer managment list)
	{ "cbrief_mark_column",   		"\ec" },		% Alt C -- Brief Manual: Column Mark; (BRIEF 2.1 = toggle case search)
	{ "delete_line",           		"\ed" },		% Alt D -- Brief Manual: Delete Line
	{ "cbrief_file_edit_tui",		"\ee" },		% Alt E -- Brief Manual: Edit File (open file)
	{ "cbrief_disp_file",			"\ef" },		% Alt F -- Brief Manual: Display File Name
	{ "cbrief_goto_line",         	"\eg" },		% Alt G -- Brief Manual: Go To Line
	{ "cbrief_help",				"\eh" },		% Alt H -- Brief Manual: Help
	{ "toggle_overwrite",			"\ei" },		% Alt I -- Brief Manual: Insert Mode Toggle 
	{ "cbrief_bkgoto",				"\ej" },		% Alt J -- Brief Manual: Jump to Bookmark
	{ "kill_line",             		"\ek" },		% Alt K -- Brief Manual: Delete to EOL
	{ "cbrief_line_mark",   		"\el" },		% Alt L -- Brief Manual: Line Mark
	{ "cbrief_stdmark"	,    		"\em" },		% Alt M -- Brief Manual: Mark
	{ "cbrief_buffer_next",			"\en" },		% Alt N -- Brief Manual: Next Buffer
	{ "cbrief_output_file",			"\eo" },		% Alt O -- Brief Manual: Change Output File (renames but not save yet, close to 'save as')
	{ "cbrief_buffer_prev", 		"\ep" },		% Alt P -- Brief Manual: Print Block -- Previous Buffer HERE
	{ "cbrief_quote",				"\eq" },		% Alt Q -- Brief Manual: Quote (Insert Keycode)
	{ "cbrief_file_insert",			"\er" },		% Alt R -- Brief Manual: Read File into Buffer
	{ "cbrief_search_fwd",			"\es" },		% Alt S -- Brief Manual: Search Forward
	{ "cbrief_translate",			"\et" },		% Alt T -- Brief Manual: Translate (replace) Forward
	{ "undo",						"\eu" },		% Alt U -- Brief Manual: Undo
	{ "cbrief_disp_ver",			"\ev" },		% Alt V -- Brief Manual: Display Version ID
	{ "cbrief_write",           	"\ew" },		% Alt W -- Brief Manual: Write (save)
	{ "cbrief_exit",				"\ex" },		% Alt X -- Brief Manual: Exit (and/or save)
	{ "cbrief_az",					"\ez" },		% Alt Z -- Brief Manual: Suspend BRIEF
	{ "cbrief_buffer_prev",		 	"\e-" },		% Alt - -- Brief Manual: Previous Buffer; (BRIEF 2.1, copy above line)
};
	
	%% Brief Manual: Repeat
	_for (0, 9, 1) {
		e = ();
		list_append(_cbrief_keymap, { "digit_arg", "^R" + string(e) } );
		}

	%% self-insert
	foreach e ( ["{", "}", "(", ")", "[", "]", "`", "'", "\"" ] )
		list_append( _cbrief_keymap, { "self_insert_cmd", e } );

	%%	Alt 0..9 - Brief Manual: Drop Bookmark 1-10
	_for (0, 9, 1) {
		e = (); s = string(e);
		list_append( _cbrief_keymap, { "cbrief_bkdrop(" + s + ")", "\e" + s });
		}

	if ( cbrief_readline_mode() ) {
		list_append( _cbrief_keymap, { "brief_home",	"^A" } );
		list_append( _cbrief_keymap, { "brief_end",	"^E" } );
		}
	else
		list_append( _cbrief_keymap, { "scroll_down_in_place",	"^E" } );

	ifnot ( cbrief_laptop_mode() ) {
		list_append( _cbrief_keymap, { "cbrief_prev_word",		Key_Ctrl_Left } );	% Brief Manual: Previous Word
		list_append( _cbrief_keymap, { "cbrief_next_word",		Key_Ctrl_Right } );	% Brief Manual: Next Word
		}
	else {
		list_append( _cbrief_keymap, { "brief_home",			Key_Ctrl_Left } );
		list_append( _cbrief_keymap, { "brief_end",			Key_Ctrl_Right } );
		list_append( _cbrief_keymap, { "brief_pageup",			Key_Ctrl_Up } );
		list_append( _cbrief_keymap, { "brief_pagedown",		Key_Ctrl_Down } );
		}

	%% --- NON-BRIEF KEYS ---

	%%	Windows Clipboard
	if ( cbrief_windows_keys() || cbrief_nopad_keys() ) {
		list_append(_cbrief_keymap, { "cbrief_copy",	"^C" } );
		list_append(_cbrief_keymap, { "cbrief_cut",	"^X" } );
		list_append(_cbrief_keymap, { "cbrief_paste",	"^V" } );
		}

	%% more keys
	if  ( cbrief_nopad_keys() || cbrief_more_keys() ) {
		list_append(_cbrief_keymap, { "cbrief_search_back", "^S" });	% search back, undefined in BRIEF
		list_append(_cbrief_keymap, { "cbrief_find_prev",	 "^F" });	% search again backward, undefined in BRIEF
		list_append(_cbrief_keymap, { "cbrief_find_next",	 "\ef" } );	% search again -- display filename in BRIEF
		}

	%% special keys for JED
	if ( is_xjed() && getenv("DISPLAY") != NULL )
		list_append( _cbrief_keymap, { "select_menubar", "[29~" } );	% windows menu key
	list_append( _cbrief_keymap, { "cbrief_xcopy",		Key_Ctrl_Ins  });	% ctrl+ins
	list_append( _cbrief_keymap, { "cbrief_xpaste",	Key_Shift_Ins });	% shift+ins
	list_append( _cbrief_keymap, { "cbrief_xcopy",		"" });	% Ctrl+Alt+C
	list_append( _cbrief_keymap, { "cbrief_xpaste",	"" });	% Ctrl+Alt+V
	list_append( _cbrief_keymap, { "cbrief_xcut",		"" });	% Ctrl+Alt+X
	}

%% remove any control and alt shortcut (at least the a-z)
private define cbrief_clear_keys() {
	variable s, e, i;

	for ( i = 0; i < 26; i ++ ) {
		s = sprintf("^%c",  'A' + i);	unsetkey(s);
		s = sprintf("\e%c", 'a' + i);	unsetkey(s);
		}
	foreach e ( ["\t", "\e\t", "{", "}", "(", ")", "[", "]", "`", "'", "\"" ] )
		unsetkey(e);
	}

%% setup keyboard shortcuts
define cbrief_keys() {
	variable s, e, i;

	cbrief_clear_keys();

	foreach e ( _cbrief_keymap ) 
		setkey(e[0], e[1]);

%	setkey("cbrief_halt",			Key_Ctrl_Break);		% Brief Manual: Halt (break macro)
%	setkey("brief_delete_buffer",	Key_Ctrl_KP_Subtract);	% Brief Manual: Delete Curr. Buffer (not sure if works with keypad)
%	setkey("brief_kill_region",		Key_Alt_KP_Subtract);	% Brief Manual: Previous Buffer (not sure if works with keypad)
%%
%%	F9 = [build and] run program in Borland, load macro file (evalfile) in Brief
%%	Ctrl+F9 = compile in Borland
%%	Shift+F9 = build in Borland, delete macro file in Brief
%%		
%	setkey("load macro",				Key_F9);		% Brief Manual: Load Macro File (slang file here)
%	setkey("delete macro",				Key_Shift_F9);	% Brief Manual: Delete Macro File (slang file here)
	setkey("cbrief_compile_it",			Key_Alt_F10); 	% Brief Manual: Compile Buffer,
	setkey("cbrief_build_it",			Key_Ctrl_F10); 	% make (non-brief)
	setkey("cbrief_quote",				Key_Shift_F10);	% Brief Manual: undefined,
									% I found it in KEYBOARD.H of 3.1 and 2.1 (macro 'key' not the 'quote')
	setkey("compile_parse_errors",		"^P");
	setkey_reserved("compile_parse_errors", "'");
	setkey("compile_previous_error",	"^N");
	setkey_reserved ("compile_previous_error", ",");
%%	setkey ("ispell",					Key_F7);
	
	if ( cbrief_more_keys() ) {
		setkey("cbrief_build_it",		Key_F9);		% Borland: build and run
		setkey("cbrief_compile_it",		Key_Ctrl_F9);	% Borland: compile
		setkey("select_menubar",		Key_F12);		% undefined
		setkey("select_colors",		 	Key_Alt_F12);	% undefined
		}

	if ( cbrief_nopad_keys() ) {
%		setkey("brief_line_to_mow",		"\e^C");	% Alt+Ctrl C -- center to window
		setkey("cbrief_toggle_re",		"\e");	% Alt+Ctrl R -- toggle regexp search
		setkey("cbrief_search_back",  	"\e");	% Alt+Ctrl S -- search backward
		setkey("cbrief_search_case",	"\e");	% Alt+Ctrl A -- Case Sens. Toggle
		setkey("cbrief_find_prev",		"\e");	% Alt+Ctrl F -- find prev
		setkey("cbrief_translate_back",	"\e");	% Alt+Ctrl T -- replace backward
		}
	
	setkey("comment_region_or_line",	">");
	setkey("uncomment_region_or_line",	"<");
	
	if ( cbrief_more_keys() ) {
		%
		%	Toggle keys and other options
		%
		%	This key is actually free for the user, re-assign as you wish
		%
		% a = abbrev
		setkey("select_menubar",			"^Ob");
%		setkey("reg_copy_to_register",      "^Oc");
		% d = insert date
		setkey("cbrief_toggle_re",			"^Oe");
		setkey("format_paragraph",			"^Of");
		% g = grep
		setkey("cbrief_open_file_at_cursor","^Oh");
		setkey("info_reader",				"^Oi");
		setkey("self_insert_cmd",			"^Oj");
		setkey("@^ObBS",					"^Ok");
		% l = grep->replace
		setkey("unix_man",					"^Om");
		setkey("toggle_line_number_mode",	"^On");
		setkey("@^ObiC",					"^Oo");
		setkey("@^ObiC",					"^O^O");
%		setkey("reg_insert_register",       "^Op");
		setkey("cbrief_quote",				"^Oq");
		setkey("toggle_readonly",			"^Or");
		setkey("cbrief_search_case",		"^Os");
		% t = templates
		setkey("uncomment_region_or_line",	"^Ou");
%		setkey("register_mode",				"^Ov");
		setkey("toggle_crmode",				"^Ow"); % windows CR/LF
		setkey("cbrief_toggle_xclip",		"^Ox");
		setkey("@^ObyW",					"^Oy");
		setkey("do_shell_cmd",				"^O8");
		setkey("shell",						"^O9");
		setkey("ashell",					"^O0");
			
%		setkey("cbrief_forward_delim",		"[");		% Alt [ -- go ahead to matching (, { or [ -- undefined in Brief, defined in Borland
%		setkey("cbrief_backward_delim",		"]");		% Alt ] -- go back to matching (, { or [ -- undefined in Brief, defined in Borland
		setkey("cbrief_delim_match",		"\e]");		% Alt ] -- matching delimiters, undefined in brief
		
%		setkey("cbrief_dabbrev",			"");		% Ctrl / -- adds or removes comments in Borland, undefined in Brief
%																 but it has the same code as the Ctrl+Minus 
		setkey("dabbrev",					"\e/");		% Alt / -- complete words, undefined in Brief 

%		setkey("do_shell_cmd",				"\e!");		% Alt+! -- run shell command, no needed, use F10 / alt+=
		setkey("exchange_point_and_mark",	"\eX");		% Alt+X -- undefined in BRIEF, defined in BRIEF emulation of MS

		% no needed anymore, use tab/shift-tab 
		setkey("cbrief_slide_out",			"\e,");		% Alt , -- alternate outdent block, undefined in brief
		setkey("cbrief_slide_in",			"\e.");		% Alt . -- alternate indent block, undefined in brief

		% comment / uncomment block or line
		setkey("uncomment_region_or_line",	"\e<");		% ESC < -- removes comments, undefined in Brief
		setkey("comment_region_or_line",	"\e>");		% ESC > -- adds comments, undefined in Brief        
		}
	}

%% reset keyboard... a mode take us the keys? again?
public define cbrief_reset() {
	variable e, m = what_keymap();
		
	flush(sprintf("Resetting keymap [%s]...", m));
	TAB = 4;
	Tab_Stops = [0:19] * TAB + 1;
	TAB = 4;
	USE_TABS = 1;
	foreach e ( _cbrief_keymap ) {
		undefinekey(e[1], m);
		definekey(e[0], e[1], m);
		}
	flush(sprintf("[%s] done...", m));
	}

%% --- API for JED units ----------------------------------------------

%!#+
%\function{cbrief_setkey}
%\synopsis{Adds a key to CBrief list of keys}
%\usage{void cbrief_setkey(String|Function func, String key)}
%\descrition
%	Assigns a function to a key. The key will be added to CBrief list of keys.
%	This means the key will survice after a reset.
%\example
%v+
%	autoload("cbrief_setkey", "cbrief");
%	cbrief_setkey("my_unit_command", "[24;2~");
%v-
%!#-	
public define cbrief_setkey(func, key) {
	variable e, index = 0;
	if ( List_Type != typeof(_cbrief_keymap) )
		cbrief_build_keymap();
	foreach e ( _cbrief_keymap ) {
		if ( key == e[0] ) {
			list_delete(_cbrief_keymap, index);
			break;
			}
		index ++;
		}
	list_append(_cbrief_keymap, { func, key });
	unsetkey(key);
	setkey(func, key);
	}

%!#+
%\function{cbrief_cli_append}
%\synopsis{Adds a command in macros list}
%\usage{void cbrief_cli_append(String name, Function|String func, Integer callway, String help | NULL)}
%\descrition
%	Adds a command to CBrief list of commands. Parameters in command-line are separated
%	by space (that is, no parenthesis, no commas, no nothing). The callway is a number that
%	defines the way the parameters will be passed in the function also any special request.
%
%	If the command already exists, the new one will replace it.
%
%	Type of call:
%v+
%	NO_ARG = 0;	% no parameters.
%	C_ARGV = 1;	% C-style argc/argv, argv only & argv[0] = function name.
%	C_LINE = 2;	% one big string, function has to decide how to split it.
%	S_LANG = 3;	% eval(this).
%	S_CALL = 4;	% call(this).
%	C_ARG2 = 5;	% C-style argc/argv, argv[0] = function name
%	C_SARG = 6;	% native S-Lang, push arguments, function has to use __pop_list{_NARGS}.
%	CALIAS = 7;	% alias, runs cbrief_command(func-string)
%v-
%\example
%v+
%	autoload("cbrief_cli_append", "cbrief");
%	cbrief_cli_append("insert_template", &template_use, 6, NULL);
%	cbrief_cli_append("insert_iso_date", &insert_iso_date, 0, help-text);
%v-
%!#-
public define cbrief_cli_append(name, funcptr, args, hlp) {
	variable e, found = 0;
	cbrief_maclist_init();
	foreach e ( cbrief_macros_list ) {
		if ( e[0] == name ) { % already exists
			e = { name, funcptr, args, hlp };
			found = 1;
			break;
			}
		}
	mac_index[name] = { name, funcptr, args, hlp };
	ifnot ( found ) {
		list_append(cbrief_macros_list, { name, funcptr, args, hlp } );
		mac_opts = strcat(mac_opts, ",", name);
		mac_opts = sort_cslist(mac_opts);
		}
	}

%!#+
%\function{cbrief_menu}
%\synopsis{Adds a menu to CBrief's menu}
%\usage{void cbrief_menu(String menu, String title, String function)}
%\descrition
%	Adds a menu to CBrief's menu.
%	If function is '@{popup}' then inserts a popup slot.
%\example
%v+
%	autoload("cbrief_menu", "cbrief");
%	cbrief_menu("Global.&Buffers", "Insert template", "insert_template");
%	cbrief_menu("Global.&Buffers", "Insert popup", "@{popup}");
%v-
%!#-	
public define cbrief_menu(menu, title, cmd) {
	if ( _menu_init ) {
		if ( cmd == "@{popup}" ) menu_append_popup(menu, title);
		else menu_append_item(menu, title, cmd); }
	else list_append(_menu_stack, { menu, title, cmd, NULL });
	}

%!#+
%\function{cbrief_menu_insert}
%\synopsis{Inserts a menu to CBrief's menu}
%\usage{void cbrief_menu_insert(String menu, String title, String function, String position)}
%\descrition
%	Inserts a menu to CBrief's menu at 'position'.
%	If function is '@{popup}' then inserts a popup slot.
%!#-	
public define cbrief_menu_insert(menu, title, cmd, pos) {
	if ( _menu_init ) {
		if ( cmd == "@{popup}" ) menu_insert_popup(pos, menu, title);
		else menu_insert_item(pos, menu, title, cmd); }
	else list_append(_menu_stack, { menu, title, cmd, pos });
	}

%% --- main -----------------------------------------------------------

static define cbrief_main() {
#ifdef UNIX
	enable_flow_control(0);  % turns off ^S/^Q processing (Unix only)
#endif
	ADD_NEWLINE  = 1;								% add newline to file when writing if one not present
	TAB_DEFAULT	 = rc_geti(rc, "TABSIZE", 4);	% Tab size  (also try edit_tab_stops)
	USE_TABS	 = rc_geti(rc, "USETABS", 1);	% Use tabs when generating whitespace.
	
	% The original BRIEF's abort key wasnt the ESC but the Ctrl+Break (halt macro)
	%set_abort_char(''); % Ctrl+G = the default, Routines macro in BRIEF (2.1/3.1)
	% Free control keys: Ctrl+Q, Ctrl+6, Ctrl+Y, Ctrl+], Ctrl+\ and Ctrl+H (but not suggested)
	% Non-free but can be used: Ctrl+S, Ctrl+F, Ctrl+O
	%
	% In older BRIEFs, ^Q was a compination of keys to manipulate columns
	% 
	set_abort_char('');
	
	% This key will be used by the modes (e.g. c_mode.sl) to bind additional functions to
	%_Reserved_Key_Prefix = "";
	_Reserved_Key_Prefix = ""; % this one is easiest to remember
%	_Reserved_Key_Prefix = "";
	
	% This is the default with field-widths
	%set_status_line(" [ %b ] %5l:%03c %S - %m%a%n%o - %F - %t ", 1);
	
	% try colors
	variable color_normal     = color_number("normal");
	variable color_status     = color_number("status");
	variable color_cursor_ins = color_number("cursor");
	variable color_cursor_ovr = color_number("cursorovr");
	variable color_menu_text  = color_number("menu");

	menu_set_menu_bar_prefix("Global", " F12 ==> ");
	
	variable _c = [ 
	sprintf("\033[%d]", color_status),
	sprintf("\033[%d]", color_cursor_ins),
	sprintf("\033[%d]", color_cursor_ovr),
	sprintf("\033[%d]", color_menu_text ) ];
	
	% W=wrap, %T=tab, S=stack depth,
	set_status_line(
		sprintf(" %s %%b %s %s%%5l:%%03c %s %%S -%s %%m%%O%%n%%a %%T %%W %s- %%F - %s%%t%s ",
				_c[1], _c[0],	% name
				_c[2], _c[0],	% line/col
				_c[3], _c[0],	% mode
				_c[3], _c[0]	% time
				), 1);
	
	% build tables
	cbrief_build_cindex();
	cbrief_build_opts();

	% at end before the keys
	enable_top_status_line(CBRIEF_MENU_BAR); 		% BRIEF's menus was through help/setup
	WRAP_DEFAULT = rc_geti(rc, "WRAP", 132);	% max column on wrap-mode, it seems it is working everywhere

	% setup keys
	cbrief_build_keymap();
	cbrief_keys();
	}

% on-exit hook
static define cbrief_on_exit() {
	if ( is_xjed() ) { rc_set(rc, "xcolor", _Jed_Color_Scheme); }
	else             { rc_set(rc, "tcolor", _Jed_Color_Scheme); }
	rc_save(rc);
	return 1;
	}

cbrief_main();
#ifdef UNIX
append_to_hook("_jed_init_display_hook", &cbrief_disp_init);
#endif
append_to_hook("_jed_startup_hooks", &cbrief_init);
append_to_hook("_jed_exit_hooks", &cbrief_on_exit);
runhooks("keybindings_hook", _Jed_Emulation);   % run hooks
history_load();

provide("cbrief");

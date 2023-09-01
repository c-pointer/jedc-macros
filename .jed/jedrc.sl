%% -*- mode: slang; tab-width: 4; indent-style: tab; encoding: utf-8; -*-
%%
%%	Jed BRIEF-mode configuration
%%	
%%	Nicholas Christopoulos (nereus@freemail.gr)
%%
%%	User specific files:
%%	Add, modify, remove as you wish, they will never be part of this package to
%%	overwrite them; will be loaded and executed if exist.
%%		term.sl  --- add or fix key codes here
%%			loaded after the slang/jed keys and after nc-term (this package) fixes
%%		local.sl --- add or change code here, called from jedrc before load
%%			the sessions which is the last unit that will load
%%		<hostname>.sl -- reads configuration per system if exists
%% --------------------------------------------------------------------------------

%_print_stack();
require(vdircat(Jed_Home_Directory, "environ")); % build directories and setup paths
require("nc-utils");			% load basic utilities
%buflogf("jedrc begin stk = %d\n", _stkdepth());
%_print_stack();

compile_local_sl();				% compile all sl files in $JED_HOME/
ifnot ( BATCH ) {
	require("nc-term");				% load terminal codes
	user_load_local_terminal();		% load user defined terminals settings
	}

% JED's lib: keeps names of the last used files, useless, I keep it as menu addon
require("recentx");
Recentx_Cache_Filename = vdircat(Jed_Home_Directory, "data", ".recentx-files");

% ndc: CBRIEF itself 
require("cbrief");

% optional: DIRED & CBRIEF compatible patch
require("cbrief-dired");

% jedmodes: unix_man: custom, simple and nice
require("utils/hyperman");

% JED's lib: typical hex-editor ... I didnt check yet, I saw it in most
%require("binary");
%cbrief_cli_append("file_load_bin", &find_binary_file, 6, NULL);

% JED's lib: JED's compilers and compilation library
require("compile");

% ndc: advanced backup system, with envirnoment and numbering 
require("sys/ncbackup");

%% --- custom modes -------------------------------------------------------

% dependency... TODO: check it...
%require("utils/browse_url");
%if ( getenv("TEXTBROWSER") != NULL )
%	Browse_Url_Browser = getenv("TEXTBROWSER");
%Browse_Url_X_Browser = "netsurf";
%cbrief_cli_append("browse",  &browse_text_url, 6,
%"browse [url]\n\tUses ${TEXTBROWSER} to show the url." );
%cbrief_cli_append("browsex", &browse_url,      6,
%"browserx [url]\n\tUses default web browser to show url." );

% jedmodes: usefull search, not necessary but simple and nice
require("utils/occur");
require("utils/grep");

% ndc: default abbreviation list and library
require("abbrev");

% ndc: selecting color scheme with dialog list-box
require("nccolors");		% colors popup

% ndc: useful template / snap library with macros
require("nctemplates");

% JED's: Info Reader
require("utils/info");
cbrief_cli_append("info", &info_reader, 6, "info [key]\n\ttexinfo reader." );

% tags
require("tkl-modes");
require("tokenlist");
add_completion("list_routines");

% Add menu entry
define tokenlist_load_popup_hook(menubar) {
	menu_insert_item("Se&t Bookmark", "Global.&Search",
		"&List Routines", "list_routines");
	}
append_to_hook("load_popup_hooks", &tokenlist_load_popup_hook);

% default hook to add prepared mode definitions for list_routines:
define tokenlist_hook() {
	if ( expand_jedlib_file("tkl-modes") != "" )
		require("tkl-modes");
	}

cbrief_cli_append("routines", &list_routines, 6,
"routines\n\tDisplays a window that lists the routines present in the current file (if any).");
cbrief_setkey("list_routines", "^G");

%% languages - I am not sure that it is needed except the custom languages
require("nc-jlang");

%% --- spell --------------------------------------------------------------
%% TODO ...
%require("utils/ispell"); %% todo 
%require("utils/flyspell"); %% todo 
%require("utils/vispell"); %% todo 

% JED's default
require("ispell");
Ispell_Program_Name = "aspell";

%% --- globals ------------------------------------------------------------

BLINK = 0;				% no blink parenthesis
TERM_BLINK_MODE = 0;	% use highlight
USE_ANSI_COLORS = 1;	% use colors
LINENUMBERS = 1;		% A value of zero means do NOT display line number on status line line.
						% A value of 1, means to display the linenumber. A value greater than 1 will also display column number information.
DOLLAR_CHARACTER = '>'; % horizontal scroll character

%% my specific c-mode, do not use it, load the original cmode 
require("syntax/cmode");
(C_INDENT, C_BRACE, C_BRA_NEWLINE, C_CONTINUED_OFFSET, C_Colon_Offset, C_Class_Offset) = (4,0,0,4,0,4);

%% --- finalize -----------------------------------------------------------
%enable_top_status_line(0); % enable/disable menu bar, BRIEF had no menu

if ( is_xjed() ) {
	Color_Scheme_Path = strcat(JED_COLORS_DIR, ",", Color_Scheme_Path);
	set_color_scheme("Xjed/atom-xjed");
	}
else {
	Color_Scheme_Path = strcat(JED_COLORS_DIR, ",", Color_Scheme_Path);
%	set_color_scheme("atom-console");
	set_color_scheme("cbrief-console");
	}

% key-bindings (not loaded for batch processes)
ifnot ( BATCH ) {
	user_load_local_jedrc(); % load user settings
	user_load_host_jedrc(); % load machine settings

	% sessions - last command always (sys/session overlaps jed's lib/session)
	require("sys/ncsession");
	}

%buflogf("jedrc out stk = %d\n", _stkdepth());
%static variable junk_list = __pop_list(_stkdepth);
%_print_stack();

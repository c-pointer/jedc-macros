%	Terminal key-codes
%
%	Additional terminals key-codes fixes.
%
%	Copyleft (ͻ) 2016-2022 Nicholas Christopoulos
%	Released under the terms of the GNU GPL version 3 or later.
%
% Notes:
%	* An empty string means that key does not supported in this terminal
%	* I have no keypad anymore

require("nc-utils");
require("sys/x-keydefs");
provide("nc-term");

#ifdef XWINDOWS
private variable term = "xjed";
private variable cterm = "xjed";
#else
private variable term = getenv("TERM");
if ( term == NULL )	term = "ansi";
if ( getenv("TMUX") != NULL ) term = "tmux+" + term;
#endif

% Unix ALT-KEYS, SL_ALT_KEY(key) -> 0x400 | char
private variable ALT_MASK = 0x400;
public define SL_ALT_KEY(key) { return ALT_MASK|key; }
private variable ALT_WCMASK = 0x80000000;
public define SL_ALT_WCKEY(key) { return ALT_WCMASK|key; }

%
% if you want ^? for backspace in xterm copy the bellow line into ~/.Xdefaults
% the most terminal emulators are using TERM=xterm but they dont use the termcap!
% 
%	XTerm*backarrowKeyIsErase: true
% 
static variable xterm_backspace = ""; % xterm only, ^? or ^H
if ( getenv("OSTYPE") == "FreeBSD" ) {
	xterm_backspace = "^H";
	}

% I found this [Insert] common enough in most terminals
% and combinations of them
Key_Ins = "[2~";

%
%	XJED the GUI version of JED
%
if ( term == "xjed" ) {
	Key_F1 = "[11~";
	Key_Ctrl_F1 = "[11^";
	Key_Alt_F1 = "[11~";
	Key_Shift_F1 = "[11$";
	Key_F2 = "[12~";
	Key_F3 = "[13~";
	Key_F4 = "[14~";
	Key_F5 = "[15~";
	Key_Alt_F5 = "[15~";
	Key_Shift_F5 = "[15$";
	Key_Ctrl_F5 = "[15^";
	Key_F6 = "[17~";
	Key_Shift_F6 = "[17$";
	Key_Ctrl_F6 = "[17^";
	Key_Alt_F6 = "[17~";
	Key_F7 = "[18~";
	Key_F8 = "[19~";
	Key_F9 = "[20~";
	Key_F10 = "[21~";
	Key_Shift_F10 = "[21$";
	Key_Alt_F10 = "[21~";
	Key_Ctrl_F10 = "[21^";
	Key_F11 = "[23~";
	Key_F12 = "[24~";
	Key_Ctrl_Left = "[";
	Key_Ctrl_Right = "[";
	Key_Shift_Tab = "[Z";

	Key_Ctrl_PgUp = "[5^";
	Key_Ctrl_PgDn = "[6^";
	Key_Ctrl_Home = "[1^";
	Key_Ctrl_End  = "[4^";

	Key_Shift_Tab = "[Z";
	
	Key_Ctrl_Left = "[";
	Key_Ctrl_Right = "[";

	Key_Ctrl_BS = "[16^";

	% key codes for copy/paste to xclipboard
	Key_Ins = "[2~";
	Key_Ctrl_Ins = "[2^";
	Key_Shift_Ins = "[2$";
	}
%
%	rxvt-unicode (urxvt)
%	need to be fixed, I used it with tmux in most times
%
else if ( term == "rxvt-unicode" || term == "rxvt-unicode-256color" ) {
	Key_BS = "";
	Key_Alt_BS = "";
	Key_Ctrl_BS = "";
	Key_Shift_Tab = "[Z";
	Key_Ctrl_Left = "Od";
	Key_Ctrl_Right = "Oc";

	Key_F1 = "[11~";
	Key_Ctrl_F1 = "[11^";
	Key_Alt_F1 = "[11~";
	Key_Shift_F1 = "[11$";
	Key_F2 = "[12~";
	Key_F3 = "[13~";
	Key_F4 = "[14~";
	Key_F5 = "[15~";
	Key_Alt_F5 = "[15~";
	Key_Ctrl_F5 = "[15^";
	Key_Shift_F5 = "[28~";
	Key_F6 = "[17~";
	Key_Shift_F6 = "[29~";
	Key_Ctrl_F6 = "[17^";
	Key_Alt_F6 = "[17~";
	Key_F7 = "[18~";
	Key_F8 = "[19~";
	Key_F9 = "[20~";
	Key_F10 = "[21~";
	Key_Alt_F10 = "[21~";
	Key_Ctrl_F10 = "[21^";
	Key_Shift_F10 = "[34~";
	Key_F11 = "[23~";
	Key_F12 = "[24~";

	Key_KP_2 = "Or";
	}
%
%	A few thousands xterms under many different emulators
%	on many different distros with many different terminfo...
%
else if ( term == "xterm" || term == "xterm-color" || term == "xterm-256color" ) {
	if ( xterm_backspace == "^?" || xterm_backspace == "" ) {
		Key_BS = "";
		Key_Alt_BS = "";
		Key_Ctrl_BS = "";
		}
	else {
		Key_BS = "";
		Key_Alt_BS = "";
		Key_Ctrl_BS = "";
		}
	if ( getenv("DISTRO") == "FreeBSD" ) {
		Key_BS = "";
		Key_Alt_BS = "";
		Key_Ctrl_BS = "";
		}
	Key_Shift_Tab = "[Z";
	Key_Ctrl_Left = "[1;5D";
	Key_Ctrl_Right = "[1;5C";
	Key_Ctrl_PgUp = "[5;5~";
	Key_Ctrl_PgDn = "[6;5~";
	Key_Ctrl_Home = "[1;5H";
	Key_Ctrl_End = "[1;5F";
	Key_F1 = "OP";
	Key_Shift_F1 = "[1;2P";
	Key_Alt_F1 = "[1;3P";
	Key_Ctrl_F1 = "[1;5P";
	Key_F2 = "OQ";
	Key_F3 = "OR";
	Key_F4 = "OS";
	Key_F5 = "[15~";
	Key_Alt_F5 = "[15;3~";
	Key_Shift_F5 = "[15;2~";
	Key_F6 = "[17~";
	Key_Shift_F6 = "[17;2~";
	Key_Alt_F6 = "[17;3~";
	Key_Ctrl_F6 = "[17;5~";
	Key_F7 = "[18~";
	Key_F8 = "[19~";
	Key_F9 = "[20~";
	Key_F10 = "[21~";
	Key_Shift_F10 = "[21;2~";
	Key_Alt_F10 = "[21;3~";
	Key_Ctrl_F10 = "[21;5~";
	Key_F11 = "[23~";
	Key_F12 = "[24~";
	Key_KP_7 = "[1~";
	Key_KP_1 = "[4~";
	Key_Home = "OH";
	Key_End = "OF";
	}
%
%	linux-console
%	old enough... need update and tmux section
%	
else if ( term == "linux" ) {
	Key_BS = "";
	Key_Alt_BS = "";
	Key_Ctrl_BS = "";
	Key_Shift_Tab = "\e\t";

	Key_F1 = "[[A";
	Key_Alt_F1 = "[25!";
	Key_Ctrl_F1 = "[25^";
	Key_Shift_F1 = "[25~";
	Key_F2 = "[[B";
	Key_Alt_F2 = "[26!";
	Key_Ctrl_F2 = "[26^";
	Key_Shift_F2 = "[26~";
	Key_F3 = "[[C";
	Key_Alt_F3 = "[29!";
	Key_Ctrl_F3 = "[29^";
	Key_Shift_F3 = "[29~";
	Key_F4 = "[[D";
%	Key_Alt_F4 = "";
%	Key_Ctrl_F4 = "";
%	Key_Shift_F4 = "[29~";
	Key_F5 = "[[E";
	Key_Alt_F5 = "[31!";
	Key_Ctrl_F5 = "[31^";
	Key_Shift_F5 = "[31~";
	Key_F6 = "[17~";
	Key_Alt_F6 = "[32!";
	Key_Ctrl_F6 = "[32^";
	Key_Shift_F6 = "[32~";
	Key_F7 = "[18~";
	Key_F8 = "[19~";
	Key_Alt_F8 = "[35!";
	Key_Ctrl_F8 = "[34^";
	Key_Shift_F8 = "[34~";
	Key_F9 = "[20~";
%	Key_Alt_F9 = "";
	Key_Ctrl_F9 = "[35^";
	Key_Shift_F9 = "[35~";
	Key_F10 = "[21~";
	Key_Alt_F10 = "[36!";
	Key_Ctrl_F10 = "[36^";
	Key_Shift_F10 = "[36~";
	Key_F11 = "[23~";
	Key_F12 = "[24~";

	Key_KP_Subtract = "OS";
	Key_KP_Add = "Ol";
	Key_KP_Multiply = "OR";
	}

% ---------------------------------------------------------------------
% TMUX SECTION, under tmux many codes are change
% ---------------------------------------------------------------------

%
%	TMUX with xterm-256color compatibility
%	Suggestet TERM on XWindows instead of "screen*"
%	
else if ( term == "tmux+xterm-256color" ) {
	Key_Home      = "[1~";
	Key_End       = "[4~";
	Key_Ctrl_Home = "[1;5H";
	Key_Ctrl_End  = "[1;5F";
	Key_Alt_Home  = ""+Key_Home;
	Key_Alt_End   = ""+Key_End;
	
	Key_PgUp      = "[5~";
	Key_PgDn      = "[6~";
	Key_Ctrl_PgUp = "[5;5~";
	Key_Ctrl_PgDn = "[6;5~";
	Key_Alt_PgUp  = ""+Key_PgUp;
	Key_Alt_PgDn  = ""+Key_PgDn;

	Key_Ins       = "[2~";
	Key_Ctrl_Ins  = "[2;5~";
	Key_Alt_Ins   = ""+Key_Ins;

	Key_F1        = "OP";
	Key_Shift_F1  = "[23~";
	Key_Ctrl_F1   = "[1;5P";
	Key_Alt_F1    = ""+Key_F1;
	Key_F2        = "OQ";
	Key_Shift_F2  = "[24~";
	Key_Ctrl_F2   = "[1;5Q";
	Key_Alt_F2    = ""+Key_F2;
	Key_F3        = "OR";
	Key_Shift_F3  = "[1;2P";
	Key_Ctrl_F3   = "[1;5R";
	Key_Alt_F3    = ""+Key_F3;	
	Key_F4        = "OS";
	Key_Shift_F4  = "[1;2Q";
	Key_Ctrl_F4   = "[1;5S";
	Key_Alt_F4    = ""+Key_F4;	
	Key_F5        = "[15~";
	Key_Shift_F5  = "[1;2R";
	Key_Ctrl_F5   = "[15;5~";
	Key_Alt_F5    = ""+Key_F5;	
	Key_F6        = "[17~";
	Key_Shift_F6  = "[1;2S";
	Key_Ctrl_F6   = "[17;5~";
	Key_Alt_F6    = ""+Key_F6;	
	Key_F7        = "[18~";
	Key_Shift_F7  = "[15;2~";
	Key_Ctrl_F7   = "[18;5~";
	Key_Alt_F7    = ""+Key_F7;	
	Key_F8        = "[19~";
	Key_Shift_F8  = "[17;2~";
	Key_Ctrl_F8   = "[19;5~";
	Key_Alt_F8    = ""+Key_F8;
	Key_F9        = "[20~";
	Key_Shift_F9  = "[18;2~";
	Key_Ctrl_F9   = "[20;5~";
	Key_Alt_F9    = ""+Key_F9;
	Key_F10       = "[21~";
	Key_Shift_F10 = "[19;2~";
	Key_Ctrl_F10  = "[21;5~";
	Key_Alt_F10   = ""+Key_F10;
	Key_F11       = "[23~";
	Key_Shift_F11 = "[23;2~";
	Key_Ctrl_F11  = "[23;5~";
	Key_Alt_F11   = ""+Key_F11;
	Key_F12       = "[24~";
	Key_Shift_F12 = "[24;2~";
	Key_Ctrl_F12  = "[24;5~";
	Key_Alt_F12   = ""+Key_F12;
	}

%% 
public variable Key_Enter = Key_Return;
public variable Key_Alt_Enter = Key_Alt_Return;
public variable Key_Ctrl_Enter = Key_Ctrl_Return;
public variable Key_KP_Minus =	Key_KP_Subtract;
public variable Key_KP_Plus = Key_KP_Add;
public variable Key_KP_Del = Key_KP_Delete;
public variable Key_KP_Ins = Key_KP_0;

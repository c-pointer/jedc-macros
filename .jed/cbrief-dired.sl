%%
%%	dired for cbrief, additional to the original
%%

autoload("cbrief_cli_append", "cbrief");
autoload("cbrief_menu", "cbrief");
autoload("cbrief_setkey", "cbrief");
require("dired");

%implements("cbrief-dired");

%% dired hack: setup keymap
define cbrief_dired_init(km) {
	variable e;
	if ( km == NULL ) km = "cbrief_dired";

	ifnot (keymap_p(km)) make_keymap (km);

	foreach e ( ["\r", "e", "E", "\ee"] )
		definekey ("dired_find", e, km);
	definekey ("dired_find", "f",  km);
	
	foreach e ( ["v", "V"] )
		definekey ("dired_view", e, km);

	foreach e ( [ "t", "T"] )
		definekey ("dired_tag", e,  km);
	
	foreach e ( [ "u", "U"] )
		definekey (". 1 dired_untag", e, km);
	
	foreach e ( ["m", "M", Key_F6] )
		definekey ("dired_move", e,    km);
	
	foreach e ( ["x", "X", Key_Del, Key_KP_Minus] )
		definekey ("dired_delete", e,  km);
	
	definekey (". 1 dired_point",   "^N",   km);
	definekey (". 1 dired_point",   "n",    km);
	definekey (". 1 dired_point",   " ",    km);
	definekey (". 1 chs dired_point",       "^P",   km);
	definekey (". 1 chs dired_point",       "p",    km);
#ifdef UNIX
	definekey (". 1 chs dired_untag",       "^?",   km); % DEL key
#elifdef IBMPC_SYSTEM
	definekey (". 1 chs dired_untag",       "\xE0S",km);   %  DELETE
	definekey (". 1 chs dired_untag",       "\eOn", km);   %  DELETE
#endif
	definekey ("dired_flag_backup", "~",    km);
	foreach e ( ["r", "R", Key_Shift_F6] )
		definekey ("dired_rename", e, km);
	definekey ("dired_reread_dir",  "g",    km);
	definekey ("describe_mode",     "h",    km);
	definekey ("dired_quick_help",  "h",    km);
	definekey ("dired_quick_help",  "?",    km);
	foreach e ( ["\e\e\e",  "q", "Q", "q"] )
		definekey ("dired_quit", e, km);

	definekey("cbrief_change_win",			Key_F1,		km);
	definekey("cbrief_resize_win",			Key_F2,		km);
	definekey("one_window",					Key_Alt_F2,	km);
	definekey("cbrief_create_win",			Key_F3,		km);
	definekey("cbrief_delete_win",			Key_F4,		km);
	definekey("one_window",					"^Z",		km);
	}

%% dired hack: show current line
private variable dired_line_mark;
define cbrief_update_dired_hook() {
	dired_line_mark = create_line_mark(color_number("menu"));
	}

%% dired hack: hook
public define dired_hook() {
	Dired_Quick_Help = " (E)dit, (V)iew, (T)ag, (U)ntag, (X) Delete, (R)ename, (M)ove, (H)elp, (Q)uit, ?:this";
	set_buffer_hook ("update_hook", &cbrief_update_dired_hook);
	cbrief_reset();
	use_keymap("cbrief_dired");
	}

%% dired hack: call
private variable old_dired_help;
public define cbrief_dired() {
	old_dired_help = Dired_Quick_Help;
	dired();
	Dired_Quick_Help = old_dired_help;
	}

static define init_unit_dired() {
	cbrief_dired_init("cbrief_dired");
	cbrief_cli_append("dired", &dired, 6, NULL);
	cbrief_setkey("dired", Key_F11);
	cbrief_setkey("dired", "^Od");
	}
init_unit_dired();
provide("cbrief-dired");

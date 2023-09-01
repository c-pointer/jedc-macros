%% --- abbrev -------------------------------------------------------------

require("nc-utils");
autoload("cbrief_cli_append", "cbrief");

implements("abbrev");
% buffer abbrev_mode flag 
private variable abbrev_mode_flag = 0x800;

% create tables
create_abbrev_table("Global", "_A-Za-z0-9");
create_abbrev_table("C",      "#_A-Za-z0-9");

% Global table
define_abbrev("Global", "__lq",    "«");
define_abbrev("Global", "__rq",    "»");
define_abbrev("Global", "__ldq",   "“");
define_abbrev("Global", "__rdq",   "”");
define_abbrev("Global", "__lsq",   "‘");
define_abbrev("Global", "__rsq",   "’");
define_abbrev("Global", "__lab",   "⟨");
define_abbrev("Global", "__rab",   "⟩");
define_abbrev("Global", "__laq",   "‹");
define_abbrev("Global", "__raq",   "›");

define_abbrev("Global", "__dag",   "†");
define_abbrev("Global", "__ddag",  "‡");
define_abbrev("Global", "__ss",    "§"); % section
define_abbrev("Global", "__elps",  "…"); % ellipsis
define_abbrev("Global", "__ldots", "…"); % (LaTeX)
define_abbrev("Global", "__blt",   "•"); % bullet
define_abbrev("Global", "__bu",    "•"); % (groff)

define_abbrev("Global", "__2",     "²");
define_abbrev("Global", "__3",     "³");
define_abbrev("Global", "__deg",   "°");
define_abbrev("Global", "__00",    "‰");
define_abbrev("Global", "__pm",    "±");
define_abbrev("Global", "__sq",    "√");
define_abbrev("Global", "__inf",   "∞");
define_abbrev("Global", "__aprox", "≈");
define_abbrev("Global", "__kk",    "☭");
define_abbrev("Global", "__star",  "★");
define_abbrev("Global", "__cleft", "🄯"); % copyleft (warning: code > 0xffff)
% arrows
define_abbrev("Global", "__l",     "←");
define_abbrev("Global", "__r",     "→");
define_abbrev("Global", "__u",     "↑");
define_abbrev("Global", "__d",     "↓");
% greek
define_abbrev("Global", "__k",     "ϗ"); % ambersand
define_abbrev("Global", "__theta", "ϑ");
define_abbrev("Global", "__pi",    "π");
define_abbrev("Global", "__phi",   "ϕ");
define_abbrev("Global", "__delta", "δ");
define_abbrev("Global", "__OU",    "Ȣ");
define_abbrev("Global", "__ou",    "ȣ");
define_abbrev("Global", "__ct",    "ϛ");
define_abbrev("Global", "__revc",  "ͻ");
define_abbrev("Global", "__REVC",  "Ͻ");
% keys
define_abbrev("Global", "__enter", "⏎");
define_abbrev("Global", "__tab",   "↹");
define_abbrev("Global", "__del",   "⌦");
define_abbrev("Global", "__bs",    "⌫");
define_abbrev("Global", "__space", "␣");

% C language
define_abbrev("C", "#c", "\
#include <stdbool.h>\n#include <stdint.h>\n#include <limits.h>\n\
#include <stdio.h>\n#include <string.h>\n#include <stdlib.h>\n\
#include <unistd.h>\n");
define_abbrev("C", "#i",   "#include <>");
define_abbrev("C", "#d",   "#define ");
define_abbrev("C", "#if",  "#if defined()");
define_abbrev("C", "#e",   "#endif");

%% --------------------------------------------------------------------------------

%!%+
%\function{abbrev_select}
%\usage{Void abbrev_select([String_Type Table])}
%\synopsis{Select default abbreviation table}
%\description
%  Select default abbreviation table.
%\seealso{abbrev_table, set_abbrev_mode}
%!%-
public define abbrev_select() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable cur, n, i, list, sel = 0;

	if ( argc == 0 ) { % no arguments
		n = list_abbrev_tables();
		if ( n > 0 ) {
			list  = list_to_array(__pop_list(n));
			(cur,) = what_abbrev_table();
			for ( i = 0; i < n; i ++ ) {
				if ( list[i] == cur ) {
					sel = i;
					break;
					}
				}
			scr_redraw();
			sel = dlg_listbox4("Abbrev tables", list, sel, 0);
			if ( sel >= 0 ) {
				use_abbrev_table(list[sel]);
				(cur,) = what_abbrev_table();
				set_buffer_flag(abbrev_mode_flag);
				mesgf("[%s] abbreviation table selected.", cur);
				}
			scr_touch();
			}
		else
			mesg("no abbreviation tables found.");
		return;
		}
		
	use_abbrev_table(argv[0]);
	(cur, ) = what_abbrev_table();
	mesgf("[%s] abbreviation table selected.", cur);
	}

% prints the curent table or calls the abbrev_select
% for new one. abbre_table [table]
public define abbrev_table() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable cur;
	if ( argc ) {
		abbrev_select(argv[0]);
		set_buffer_flag(abbrev_mode_flag);
		}
	else {
		(cur, ) = what_abbrev_table();
		mesgf("The [%s] abbreviation table is used.", cur);
		}
	}

% enable, disables or prints the current abbrev mode
% of the current buffer. abbrev_mode [0|1]
public define abbrev_mode() {
	variable argc = _NARGS, argv = __pop_list(argc);
	variable b = test_buffer_flag(abbrev_mode_flag);
	if ( argc )
		b = atoi(argv[0]);
	mesgf("Abbreviation mode is %s.", ((b) ? "ON" : "OFF"));
	}

%!%+
%\function{set_abbrev_mode}
%\usage{void set_abbrev_mode(Boolean flag)}
%\synopsis{Enables / disables abbreviation mode.}
%\description
%  Enables / disables abbreviation mode on the current buffer.
%\seealso{abbrev_select}
%!%-
public define set_abbrev_mode(flag) {
	if ( flag )
		set_buffer_flag(abbrev_mode_flag);
	else
		unset_buffer_flag(abbrev_mode_flag);
	}

% init
static define init_unit_abbrev() {
	cbrief_cli_append("abbrev_mode",   &abbrev_mode,   6,
"abbrev_mode [0|1]\n\
	Enables, disables or prints the current abbrev mode\
	of the current buffer.");
	cbrief_cli_append("abbrev_table",  &abbrev_table,  6,
"abbrev_table [table]\n\
	Prints the curent table or calls the abbrev_select if parameter is given." );
	cbrief_cli_append("abbrev_select", &abbrev_select, 6,
"abbrev_select [table]\n\
	Select default abbreviation table." );
	abbrev_select("Global");
	cbrief_setkey("abbrev_select", "^Oa");
	cbrief_menu("Global.&Edit", "&Abbreviation mode", "abbrev_select");
	}
init_unit_abbrev();
provide("abbrev");

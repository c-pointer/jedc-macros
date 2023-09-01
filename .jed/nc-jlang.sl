%%
%%	Language specific scripts
%%

%require("slmode");
%require("tmmode");
require("tpascal");
add_mode_for_extension("tpas", "pas");
add_mode_for_extension("tpas", "pp");
add_mode_for_extension("tpas", "p");
require("perl");
%require("latex");
%require("html");
require("php");
require("lua");

require("textmode");
require("tmisc");

%% ndc: linux console keymap
autoload("kmap_mode", "syntax/kmap");
add_mode_for_extension("kmap_mode", "kmap");

%% ndc: tcsh & csh
autoload("csh_mode", "syntax/csh");
autoload("tcsh_mode", "syntax/tcsh");
add_mode_for_extension("CSH", "csh");
add_mode_for_extension("CSH", "tcsh");

autoload("sh_mode", "shmode");
add_mode_for_extension("SH", "sh");

%% sql
autoload("sql_mode", "syntax/sql");
autoload("mysql_mode", "syntax/sql");
add_mode_for_extension("sql", "sql");

%% vim
autoload("vim_mode", "syntax/vim");
add_mode_for_extension("vim", "vim");

%%
add_mode_for_extension("latex", "tex");        % overrides tex_mode
add_mode_for_extension("latex", "sty");
add_mode_for_extension("latex", "cls");

%%
autoload("awk_mode", "syntax/awk");
add_mode_for_extension("awk", "awk");

%% makefile
autoload("make_mode", "makemode");

%% man file
autoload("manedit_mode", "syntax/manedit");

%% --- special filenames --------------------------------------------------
static variable special_files = {
%	position is the priority too (the first wins)
%      mode-proc,                    filenames list,                             extensions list
	{ &text_mode,    "README|INSTALL|CHANGES|CHANGELOG|ChangeLog|NEWS|TODO|NOTES", "txt|log|hlp|doc|md" },
	{ &make_mode,    "Makefile|GNUmakefile|BSDmakefile", "mak" },
	{ &sh_mode,      ".profile|.xprofile|.bashrc|.kshrc|.mkshrc|.yashrc|.zshrc|.ashrc", "sh" },
	{ &csh_mode,     ".tcshrc|.cshrc|.login|.logout", "csh|tcsh" },
	{ &vim_mode,     ".vimrc|vimrc", "vim" },
	{ &manedit_mode, "", "mm|me|ms|mom|man|mdoc|1|2|3|4|5|6|7|8|9|3sl|3p|3P|3x|3X|3t|3T|n" },
	};

define_word("_0-9A-Za-z"); % default
static define set_modes_hook(base, ext) {
	variable e;
	foreach e ( special_files ) {
		if ( osl_isset(e[1], base) || osl_isset(e[2], ext) ) {
			(@e[0])();
			return 1;
			}
		}
	return 0;
	}
list_append(Mode_Hook_Pointer_List, &set_modes_hook);


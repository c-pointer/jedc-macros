%% -*- mode: slang; tab-width: 4; indent-style: tab; encoding: utf-8; -*-
%%
%%	[T]CSH mode
%%	
%%	Nicholas Christopoulos (nereus@freemail.gr)
%%
%%	Installation
%%	if opening a document with .csh extension doesn't toggle tcsh-mode on,
%%	then insert these lines in your .jedrc:
%%	
%%		autoload("tcsh_mode", "tcsh-mode");
%%		add_mode_for_extension("tcsh_mode", "csh");
%%
%%	This file is the same with csh-mode.sl, there is a bug at jed and selects
%%	mode by the she-bang.

static variable cshmode = "TCSH";

create_syntax_table(cshmode);
#ifdef HAS_DFA_SYNTAX
%dfa_enable_highlight_cache(cshmode+".dfa", cshmode);
dfa_define_highlight_rule("#.*$", "comment", cshmode);
dfa_define_highlight_rule("\\\\.", "normal", cshmode);
dfa_define_highlight_rule("\"([^\\\\\"]|\\\\.)*\"", "string", cshmode);
dfa_define_highlight_rule("\"([^\\\\\"]|\\\\.)*$", "string", cshmode);
dfa_define_highlight_rule("`[^`]*`", "string", cshmode);
dfa_define_highlight_rule("'[^']*'", "string", cshmode);
dfa_define_highlight_rule("'[^']*$", "string", cshmode);
dfa_define_highlight_rule("[\\$]+{[^}]*}", "keyword4", cshmode);
dfa_define_highlight_rule("[\\$]+[\\?]*[A-Za-z0-9_]+", "keyword4", cshmode);
dfa_define_highlight_rule ("[\\|&;\\(\\)<>]", "Qdelimiter", cshmode);
dfa_define_highlight_rule ("[\\[\\]\\*\\?]", "Qoperator", cshmode);
dfa_define_highlight_rule ("[^ \t\"'\\\\\\|&;\\(\\)<>\\[\\]\\*\\?]+", "Knormal", cshmode);
dfa_define_highlight_rule("[0-9]+", "number", cshmode);
dfa_build_highlight_table(cshmode);
enable_dfa_syntax_for_mode(cshmode);
#else
define_syntax("#", "",			'%', cshmode);	% comments
define_syntax("([{", ")]}",		'(', cshmode);	% blocks
define_syntax("-0-9a-zA-Z_",	'w', cshmode);	% words
define_syntax("-+0-9", 			'0', cshmode);   % numbers
define_syntax(",;:", 			',', cshmode);	% delimiters
define_syntax("%-+/&*=<>|!~^",	'+', cshmode);	% operators

%% strings
define_syntax('\'', '"',  cshmode);
define_syntax('"',  '"',  cshmode);
define_syntax('`',  '"',  cshmode);
define_syntax('\\', '\\', cshmode);
#endif

%%
private define tcsh_define_keywords()
{
	variable str, i, j, kary, ka_size, ka_strlen, ka_maxlen;
		
%% generate list:
%% % set str = `builtins`; echo $str >> cshmode.sl
%% the keyword 'then' will missing... just add it later in correct position
	str = "alias alloc bg bindkey break breaksw builtins case cd chdir complete continue default dirs\
 echo echotc else end endif endsw eval exec exit fg filetest foreach glob goto hashstat history hup if\
 jobs kill limit log login logout ls-F nice nohup notify onintr popd printenv pushd rehash repeat sched\
 set setenv settc setty shift source stop suspend switch telltc termname then time umask unalias uncomplete\
 unhash unlimit unset unsetenv wait where which while";
	kary = strchop(str, ' ', 0);
	ka_size = length(kary);
	ka_strlen = array_map(Integer_Type, &strlen, kary);
	ka_maxlen = max(ka_strlen);
	for ( i = 2; i <= ka_maxlen; i ++ ) {
		str = "";
		for ( j = 0; j < ka_size; j ++ ) {
			if ( ka_strlen[j] == i )
				str = strcat(str, kary[j]);
			}
		if ( strlen(str) > 0 )
			define_keywords(cshmode, str, i);
		}
}

public define tcsh_mode()
{
	set_mode(cshmode, 0);
	use_syntax_table(cshmode);
	mode_set_mode_info(cshmode, "fold_info", "#{{{\r#}}}\r\r");
	run_mode_hooks("tcsh_mode_hook");
}

tcsh_define_keywords();
add_mode_for_extension(cshmode, "csh");
add_mode_for_extension(cshmode, "cshrc");
add_mode_for_extension(cshmode, "tcsh");
add_mode_for_extension(cshmode, "tcshrc");
add_mode_for_extension(cshmode, "login");
add_mode_for_extension(cshmode, "logout");



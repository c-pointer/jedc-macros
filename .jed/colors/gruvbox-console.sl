%%
%%	gruvbox's colors for Jed
%%
%%	Nicholas Christopoulos (nereus@freemail.gr)
%%
%%		2022/10/04 - created
%%

private variable color0, color1, color2, color3;
private variable color4, color5, color6, color7;
private variable color8, color9, color10, color11;
private variable color12, color13, color14, color15;

color0 = "#1d2021";
color1 = "#cc241d";
color2 = "#98971a";
color3 = "#d79921";
color4 = "#458588";
color5 = "#b16286";
color6 = "#689d6a";
color7 = "lightgray";
color8 = "#928374";
color9 = "#fb4934";
color10 = "#b8bb26";
color11 = "#fabd2f";
color12 = "#83a598";
color13 = "#d3869b";
color14 = "#8ec07c";
color15 = "#ebdbb2";

$1 = color15;		% fg
$2 = "#222222";		% bg
$3 = color7;	% half light
$4 = color13;	% strings
$5 = color14;	 	% delims/oprs

private variable key0, key1, key2;

key0 = color13;
key1 = color12;
key2 = color3;

set_color("normal",   $1, $2);				% default
set_color("status",   "black", "lightgray");	% status line
set_color("operator", $5, $2);				% +, -, etc..
set_color("number",   "brightgreen", $2);	% 10, 2.71, etc..
set_color("comment",  $3, $2);				% /* comment */
set_color("region",   "black", $3);			% selected
set_color("string",   $4, $2);				% "string" or 'char'
set_color("keyword",  key0, $2);	    	% if, while, unsigned, ...
set_color("keyword1", key1, $2);	    	% if, while, unsigned, ...
set_color("keyword2", key2, $2);
set_color("delimiter", $5, $2);% {}[](),.;...
set_color("preprocess", "brightred", $2);
set_color("message", "yellow", $2);
set_color("error", "brightred", $2);
set_color("dollar", "brightred", $2);
set_color("...", "red", $2);			  	% folding indicator

set_color("menu_char", "red", $3);
set_color("menu", "black", $3);
set_color("menu_popup", "black", $3);
set_color("menu_selection", $1, $2);
set_color("menu_selection_char", "cyan", $2);
set_color("menu_shadow", "brightblue", "black");

set_color ("cursor", "black", "green");
set_color ("cursorovr", "black", "red");

%% The following have been automatically generated:
set_color("linenum", "lightgray", "blue");
set_color("trailing_whitespace", "black", "cyan");
set_color("tab", "black", "cyan");
set_color("url", "brightblue", $2);

set_color("bold",      "brightcyan;bold",     $2);
set_color("italic",    "brightgreen;italics", $2);
set_color("underline", "yellow;underline",    $2);

set_color("html", "brightred", $2);
set_color("keyword3", $1, $2);
set_color("keyword4", $1, $2);
set_color("keyword5", $1, $2);
set_color("keyword6", $1, $2);
set_color("keyword7", $1, $2);
set_color("keyword8", $1, $2);
set_color("keyword9", $1, $2);

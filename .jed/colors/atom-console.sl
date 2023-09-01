%%
%%	Graysh colors for Jed
%%
%%	Nicholas Christopoulos (nereus@freemail.gr)
%%
%%		2016/10/27 - created
%%

$0 = "black";
$9 = "white";
$1 = "lightgray";
$2 = "#202020";
$3 = "lightgray";
$5 = "#cf00cf";
$6 = "lightgray";

private variable key0, key1, key2, oper;

key0 = "#ffb060";
key1 = "#ffe060";
key2 = "brightred";
oper = "#cf2fcf";

set_color("normal",   $1, $2);			% default
set_color("status",   $0, $3);			% status line
set_color("operator", oper, $2);		% +, -, etc..
set_color("number",   "cyan", $2); % 10, 2.71, etc..
set_color("comment",  "gray", $2);			% /* comment */
set_color("region",   "black", $3);			% selected
set_color("string",   "green", $2);	% "string" or 'char'
set_color("keyword",  key0, $2);	    % if, while, unsigned, ...
set_color("keyword1", key1, $2);	    % if, while, unsigned, ...
set_color("keyword2", key2, $2);
set_color("delimiter", $5, $2);			% {}[](),.;...
set_color("preprocess", "brightred", $2);
set_color("message", "yellow", $2);
set_color("error", "brightred", $2);
set_color("dollar", "brightred", $2);
set_color("...", "red", $2);			  % folding indicator

set_color("menu_char", "red", $6);
set_color("menu", "black", $6);
set_color("menu_popup", "black", $6);
set_color("menu_selection", $1, $2);
set_color("menu_selection_char", "cyan", $2);
set_color("menu_shadow", "brightblue", "black");

set_color ("cursor", "black", "green");
set_color ("cursorovr", "black", "red");

%% The following have been automatically generated:
set_color("linenum", "lightgray", $2);
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

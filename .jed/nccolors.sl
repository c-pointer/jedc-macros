% Select colors popup.
% Part of CBRIEF for JED project.
%
% Copyright (ͻ) 2022, Nicholas Christopoulos
% Released under the terms of the GNU General Public License (ver. 3 or later)

require("nc-utils");
autoload("cbrief_cli_append", "cbrief");
autoload("cbrief_setkey", "cbrief");

% colors directory
#ifdef XWINDOWS
custom_variable("Color_Scheme_Path", vdircat(Jed_Home_Directory, "colors", "Xjed"));
#else
custom_variable("Color_Scheme_Path", vdircat(Jed_Home_Directory, "colors"));
#endif

implements("nccolors");

% ...
public define select_colors() {
	variable file = (_NARGS) ? () : NULL;

	if ( file == NULL ) {
		if ( is_xjed() )
			file = dlg_selectfile("Colors", vdircat(Jed_Home_Directory, "colors", "Xjed"));
		else
			file = dlg_selectfile("Colors", vdircat(Jed_Home_Directory, "colors"));
		}
	if ( file == NULL ) return;	
	if ( is_file(file) ) {
		file = basename(file);
		set_color_scheme(file);
		}
	else
		uerrorf("select_colors: scheme '%s' not found!", file);
	}

% init
static define init_unit_ncc() {
	cbrief_cli_append("select_colors", &select_colors, 6,
"select_colors [color-scheme]\n\
	Apply the color-scheme if given or display a popup menu to select one." );
	cbrief_setkey("select_colors", Key_Alt_F12);
	}
init_unit_ncc();
provide("nccolors");


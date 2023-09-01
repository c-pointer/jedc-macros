%% CBRIEF Jed Environment Initialization
%% Create directory tree and setup paths

#ifndef CBRIEF_PATCH
error("CBRIEF: NO-CBRIEF Patched Version of Executable.");
if ( is_defined("scr_shutdown") )	scr_shutdown();
fprintf(stderr, "no-CBRIEF version of JED found.\n");
fprintf(stderr, "Use this patched version https://github.com/nereusx/jedc\n");
quit_jed();
#endif

% source files path
public variable JED_HOME_DIR = Jed_Home_Directory;
set_jed_library_path(strcat(
	strcat (JED_HOME_DIR, ","),
	vdircat(JED_HOME_DIR, "sys,"),
	vdircat(JED_HOME_DIR, "syntax,"),
	vdircat(JED_HOME_DIR, "lib,"),
	vdircat(JED_HOME_DIR, "utils,"),
	get_jed_library_path()
	));

public variable HOSTNAME = get_hostname();
public variable JED_DATA_DIR   = vdircat(Jed_Home_Directory, "data");
public variable JED_COLORS_DIR = vdircat(Jed_Home_Directory, "colors");
public variable JED_CACHE_DIR  = vdircat(Jed_Home_Directory, "data", "cache");
public variable JED_TMP_DIR    = vdircat(Jed_Home_Directory, "data", "tmp");

ifnot ( access(JED_DATA_DIR,   F_OK) == 0 )	() = mkdir(JED_DATA_DIR, 0700);
ifnot ( access(JED_COLORS_DIR, F_OK) == 0 )	() = mkdir(JED_COLORS_DIR, 0700);
ifnot ( access(JED_CACHE_DIR,  F_OK) == 0 )	() = mkdir(JED_CACHE_DIR, 0700);
ifnot ( access(JED_TMP_DIR,    F_OK) == 0 )	() = mkdir(JED_TMP_DIR, 0700);

Jed_Tmp_Directory = JED_TMP_DIR;
Jed_Highlight_Cache_Dir  = JED_CACHE_DIR;
Jed_Highlight_Cache_Path = strcat(JED_CACHE_DIR, ",", Jed_Highlight_Cache_Path);

Color_Scheme_Path = strcat(JED_COLORS_DIR, ",", Color_Scheme_Path);


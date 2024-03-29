%
% Installation
% a) Global
%    1. add hist-cls.sl somewhere on your jed library path
%    2. replace jed/lib/mini.sl with mini.sl
%    3. replace jed/lib/history.sl with this file
% b) Local
%    1. Create a subdirecory named <jedhist> in the directory of .jedrc
%    2. Copy the above mentioned files to <jedhist>
%    3. Add the following to .jedrc:
%       () = evalfile("jedhist/mini.sl");
%       autoload("history_load", "jedhist/history");
%       
% History:
%   2000: Created by Rocher, Francesc
%   2007: Modified by Marko Mahnic to enable saving multiple histories
%   2007-03-10: Paul Boekholt
%     - bugfix: save_history_at_exit sometimes prevented exiting jed

%!%+
%\variable{History_File}
%\synopsis{History_File}
%\usage{String_Type History_File = "jed.his";}
%\description
% The variable \var{History_File} is used by the function \var{history_save}
% to know the file name in which to store all non-blank lines of the
% mini-buffer. Its default value is "~/.jed-history" under Unix and
% "~/jed.his" on other platforms.
%\seealso{history_load, history_save}
%!%-
custom_variable("History_File",
#ifdef UNIX
		 expand_filename(vdircat(Jed_Home_Directory, "data", ".jed-history"))
#elifdef VMS
		 "sys$login:jed.his"
#else
		 expand_filename("~/jed.his")
#endif
		 );

%!%+
%\function{history_load}
%\synopsis{history_load}
%\usage{Void_Type history_load ();}
%\description
% This function reads a history file, i.e. each line of the file is
% stored in the mini-buffer, but not evaluated. By default, historical
% records are kept in a file whose name is stored in the \var{History_file}
% variable. This file is written in the current working directory
% associated with jed, i.e. the directory from which you started the jed
% process. For example, to read your history file every time you start
% jed and give an alternative name to the history file, put:
%#v+
%   variable History_File;
%   if (BATCH == 0)
%   {
%      () = evalfile ("history");
%      History_File = ".my-jed-history";
%      history_load ();
%   }
%#v-
% in your .jedrc (or jed.rc) file. The \var{History_File} variable can be
% assigned either a file name or an absolute path+filename. In the first
% case, a file will be saved in the current working directory (the one
% you were in when you started jed), so you will find a history file in
% every directory you work in. In the second one, only one file will be
% created, but you can handle 'local' history files easily (see
% \var{history_local_save} to know how to do it).
%\seealso{history_save, history_local_save, minued_mode}
%\seealso{History_File}
%!%-
define history_load() {
	variable histfile, fp;
	% First look at the current working directory
%	histfile = vdircat(getcwd(), basename(History_File));
%	fp = fopen (histfile, "r");
	% If this didn't work, try using History_File.
%	if (fp == NULL) {
		histfile = History_File;
		fp = fopen (histfile, "r");
%		}
	if (fp == NULL) return;
	mini_load_history(fp);
	() = fclose(fp);
	}

%!%+
%\function{history_save}
%\synopsis{history_save}
%\usage{Int_Type history_save ()}
%\description
% This function saves the contents of the mini-buffer (see \var{history_load}
% for more information) to the file specified by the variable \var{History_File}
% or to the local history file (see \var{history_local_save} for more
% information). It returns -1 upon failure, or 0 upon success.
%\notes
% When history.sl is loaded, \var{history_save} will automatically get attached
% to the editors exit hooks.  As a result, it is really not necessary to call
% this function directly.
%\seealso{history_load, history_local_save}
%\seealso{History_File}
%!%-
define history_save() {
	variable lines = mini_get_lines(NULL), not_blank;
	variable fp = NULL, file, st;
	
	if ( _NARGS ) {
		file = ();
		fp = fopen (file, "w");
		if ( fp == NULL ) {
			verror ("Unable to open `%s' for writing.", file);
			return -1;
			}
		}
	else {
%		file = vdircat(getcwd(), basename(History_File));
%		st = stat_file (file);
%		if (st != NULL)
%			fp = fopen (file, "w");
%		if (fp == NULL)	{
			file = History_File;
			fp = fopen (file, "w");
			if ( fp == NULL ) {
				verror ("Unable to open `%s' for writing.", file);
				return -1;
				}
%			}
		}
	() = chmod (file, 0600);
	mini_save_history(fp);
	() = fclose(fp);
	return 0;
	}

%!%+
%\function{history_local_save}
%\synopsis{history_local_save}
%\usage{Void_Type history_local_save ()}
%\description
% This function saves the contents of the mini-buffer at some arbitrary file.
% If you give the same filename as in \var{History_File} but use a different
% path, then \var{history_load} will load this file into the mini-buffer every
% time you start jed from that (and only from that) directory. This behavior is
% only useful when the value of \var{History_File} is an absoulte filename
% and you want a local history when you start jed from some specific directory.
%\seealso{history_load, history_save}
%\seealso{History_File}
%!%-
define history_local_save() {
	variable file, st;
	file = read_with_completion("Save local history as:", "", path_basename(History_File), 'f');
	st = stat_file(file);
	if ( st != NULL ) {
		variable yn = get_y_or_n ("File `" + file + "' already exists, overwrite it");
		if (yn <= 0)
			error ("history_local_save canceled.");
		}
	ifnot ( history_save(file) )
		flush(sprintf("History saved in '%s'", file));
	}

private define save_history_at_exit() {
	try { () = history_save (); }
	catch AnyError;
	return 1;
	}
add_to_hook("_jed_exit_hooks", &save_history_at_exit);

   
   

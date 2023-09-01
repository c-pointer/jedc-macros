%	create backup filenames
%
%	Advanced backup file system with numeric version (0 the newer - 9 the oldest)
%	Autobackup files have '+' in filenames.
%	
%	Copyleft (ͻ) 2016-2022 Nicholas Christopoulos
%	Released under the terms of the GNU GPL version 3 or later.
%
%	Install: add the following line in your jedrc
%		require("ncbackup");
%
%	see site.sl

implements("ncbackup");

%!%+
%\variable{BACKUPDIR}
%\synopsis{Sets the directory of backup and autosave files.}
%\description
%	Sets the directory of backup and autosave files.
%	If there is environment variable ${BACKUPDIR} its value
%	will be used plus `text/`; otherwise \var{Jed_Home_Directory}
%	plus `backup/` will be used.
%\seealso{BACKUP_KEEP,site.sl}
%!%-
custom_variable("BACKUPDIR", "");

%!%+
%\variable{BACKUP_KEEP}
%\synopsis{Sets the number of days that backup files are kept.}
%\usage{Int_Type Man_Clean_Headers = 0}
%\description
%	Sets the number of days that backup files are kept.
%	If there is environment variable ${BACKUP_KEEP} its value
%	will be used; otherwise 90 days will be set. To stop remove
%	old files use 0 days.
%\seealso{BACKUPDIR,site.sl}
%!%-
custom_variable("BACKUP_KEEP", 90); % number of days to keep files

% returns non-zero if the 'file' is a directory
% static define is_directory(file) {
% 	variable st;
% 	st = stat_file(file);
% 	if (st == NULL) return 0;
% 	return stat_is("dir", st.st_mode);
% 	}

% cook filenames for backup and autosave
static define nc_backup_getname(flags, dir, file) {
	variable encdir;

	if ( flags & 0x1 )
		% autosave filenames
		encdir = sprintf("+%016lX", XXH3(dir));
	else {
		% backup filenames, keeping numbering (up to 10)
		variable hash = XXH3(dir), name = basename(file), ext = file_ext(file);
		variable i, f1, f2, s;

		s = vdircat(BACKUPDIR, sprintf("%s-%016lX-", name, hash));
		for ( i = 9; i > 0; i -- ) {
			f1 = sprintf("%s%d%s", s, i-1, ext);
			f2 = sprintf("%s%d%s", s, i  , ext);
			if ( access(f1, R_OK) == 0 ) {
				if ( access(f2, W_OK) == 0 )
					() = remove(f2);
				() = rename(f1, f2);
				}
			}
		return strcat(s, "0", ext);
		}
	if ( strlen(BACKUPDIR) > 0 )
		return vdircat(BACKUPDIR, strcat(basename(file), encdir, file_ext(file)));
	return vdircat(dir, strcat(file, "~")); % local directory
	}

% backup - install it, see site.sl
public define make_backup_filename(dir, file)
{ return nc_backup_getname(0, dir, file); }

% autosave - install it, see site.sl
public define make_autosave_filename(dir, file)
{ return nc_backup_getname(1, dir, file); }

% remove files from backup directory when exists more than 'days' days.
static define remove_backup_files(days) {
	variable fs = listdir(BACKUPDIR);
	variable l, i, f, st, secs;
	l = length(fs);
	secs = days * 86400;
	for ( i = 0; i < l; i ++ ) {
		f = vdircat(BACKUPDIR, fs[i]);
		st = stat_file(f);
		if ( st != NULL ) {
			if ( _time - st.st_mtime > secs )
				() = remove(f);
			}
		}
	}

% --------------------------------------------------------------------------------
% init

static define ndc_backup_init() {
	if ( NULL != getenv("BACKUPDIR") ) {
		BACKUPDIR = vdircat(getenv("BACKUPDIR"), "text");
		ifnot ( is_dir(BACKUPDIR) ) () = mkdir(BACKUPDIR, 0700);
		}
	else {
		BACKUPDIR = vdircat(Jed_Home_Directory, "backup");
		ifnot ( is_dir(BACKUPDIR) ) () = mkdir(BACKUPDIR, 0700);
		}
	
	if ( NULL != getenv("BACKUP_KEEP") )
		BACKUP_KEEP = atoi(getenv("BACKUP_KEEP"));
	else
		BACKUP_KEEP = 90;
	
	if ( BACKUP_KEEP > 0 )
		remove_backup_files(BACKUP_KEEP);
	}

ndc_backup_init();
provide("ncbackup");


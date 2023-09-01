%	NDC's jed session save/restore per directory
%
%	Copyleft (ͻ) 2016-2022 Nicholas Christopoulos
%	Released under the terms of the GNU GPL version 3 or later.
%
%	Install: add the following line in your jedrc
%		require("ncsession");

require("nc-utils");

custom_variable("JED_SESSION_FILE", vdircat(Jed_Home_Directory, "data", ".sessions"));

implements("ncsession");

%
%	store session info in to file
%	
private define save_session() {
	variable fp, dir, name, file, dirs, cbuf, flags, line, col;
	variable bufs, binf, lines, count, i, s, key, this_section;
	variable JED_SESSION_BAKF = strcat(JED_SESSION_FILE, "!");

	cbuf = whatbuf();
	key = getcwd();
	count = buffer_list();
	bufs = list_to_array(__pop_list(count));
	bufs[where(strncmp(bufs," ",1)==0)] = NULL;
	bufs[where(strncmp(bufs,"*",1)==0)] = NULL;
	bufs = bufs[wherenot(_isnull(bufs))];
	if ( 0 == length(bufs) ) return;

	binf = list_new();
	for ( i = 0; i < length(bufs); i ++ ) {
		(file, dir, name, flags) = getbuf_info(bufs[i]);
		setbuf(bufs[i]);
		push_narrow ();
		widen_buffer();
		list_append(binf,
			{ file, dir, name, flags, what_line(), what_column() });
		pop_narrow ();
		}

	% first time - file does not exists
	if ( access(JED_SESSION_FILE, R_OK) != 0 ) {
		fp = fopen(JED_SESSION_FILE, "w");
		if ( fp == NULL ) throw OpenError;
		() = fprintf(fp, "# Sessions\n");
		() = fclose(fp);
		}

	% load sessions file in memory
	lines = load_file_lines(JED_SESSION_FILE);

	% remove the cwd (key) entries from sessions file
	this_section = 0;
	for ( i = 0; i < length(lines); i ++ ) {
		s = strtrim(lines[i]);
		if ( strlen(s) > 0 ) {
			if ( this_section && s[0] == ':' )
				{ this_section = 0; break; }
			if ( this_section )
				{ lines[i] = NULL; continue; }
			if ( s[0] == '%' || s[0] == '#' ) continue;
			if ( s[0] == ':' ) { % directory-key
				dirs = strchop(s, ':', 0);
				this_section = (dirs[1] == key);
				if ( this_section )
					lines[i] = NULL;
				}
			}
		}
	lines = lines[wherenot(_isnull(lines))];

	% now write the lines into session file and
	% add the section of this directory 
	fp = fopen(JED_SESSION_BAKF, "w");
	if ( fp == NULL ) throw OpenError;
 	if ( length(lines) != fputslines(lines, fp) ) throw WriteError;

	% add this section
	() = fprintf(fp, ":%s:%s:%s\n", key, cbuf, get_iso_date());
	for ( i = 0; i < length(binf); i ++ ) {
		file = binf[i][0]; dir = binf[i][1]; flags = binf[i][3];
		line = binf[i][4]; col = binf[i][5];
		() = fprintf (fp, "%s|%d|%d|%d\n", vdircat(dir, file), line, col, flags);
		}
	fprintf(fp, "@%s\n", cbrief_get_bkstring()); 
	() = fclose(fp);

	% copy working file to original, and delete it
	if ( copy_file(JED_SESSION_BAKF, JED_SESSION_FILE) == -1 ) return WriteError;
	() = delete_file(JED_SESSION_BAKF);	
	() = chmod(JED_SESSION_FILE, 0600);
	}

%
private variable _bufs_lc;
private define save_buf_lc() {
	variable bufs, count, i;
	count = buffer_list();
	bufs = __pop_list(count);
	_bufs_lc = list_new();
	for ( i = 0; i < count; i ++ ) {
		setbuf(bufs[i]);
		list_append(_bufs_lc, { bufs[i], what_line(), what_column() }); 
		}
	}

%
private define restore_buf_lc() {
	variable i, count, e;
	count = length(_bufs_lc);
	for ( i = 0; i < count; i ++ ) {
		e = _bufs_lc[i];
		setbuf(e[0]);
		goto_line(e[1]);
		goto_column(e[2]);
		}
	_bufs_lc = NULL;
	}

%
%	restore session
%	
private define load_session() {
	variable key, dir, dirs, fp, curbf = "";
	variable file, line, col, flags, fields;
	variable s, i, l, this_section, lines, curline;
	% preserve the following flags
	variable mask = 0x02 | 0x08 | 0x10 | 0x200 | 0x400 | 0x800;

	key = getcwd();
	lines = load_file_lines(JED_SESSION_FILE);
	if ( length(lines) == 0 ) return;

	this_section = 0;
	for ( i = 0; i < length(lines); i ++ ) {
		s = strtrim(lines[i]);
		if ( strlen(s) > 0 ) {
			if ( this_section ) { % items of this section
				if ( s[0] == ':' ) {
					ifnot ( curbf == "" ) 
						if ( bufferp(curbf) ) 
							sw2buf(curbf);
					return;
					}
				if ( s[0] == '@' ) {
					% this is the last record with bookmarks
					save_buf_lc();
					cbrief_set_bkstring(substr(s, 2, -1));
					restore_buf_lc();
					continue;
					}
				fields = strchop(s, '|', 0);
				l = length(fields);
				file  = fields[0];
				line  = ( l > 1 ) ? atoi(fields[1]) : 1;
				col   = ( l > 2 ) ? atoi(fields[2]) : 1;
				flags = ( l > 3 ) ? atoi(fields[3]) : 0;
				if ( access(file, R_OK) == 0 ) {
					() = find_file(file);
					if ( bobp() ) {
						goto_line(line);
						goto_column_best_try(col);
						}
					set_buffer_flag(flags & mask);
					}
				}
			else if ( s[0] == ':' ) { % looking for this section
				dirs = strchop(s, ':', 0);
				this_section = (dirs[1] == key);
				if ( length(dirs) > 2 ) curbf = dirs[2];
				}
			}
		}
	ifnot ( curbf == "" ) 
		if ( bufferp(curbf) ) 
			sw2buf(curbf);
	}

% exit jed hook
public define exit_save_session_hook() {
	ifnot ( BATCH ) 
		save_session();
	}
add_to_hook("_jed_exit_hooks", &exit_save_session_hook);

% startup jed hook
public define startup_load_session_hook() {
	ifnot ( BATCH ) {
		if ( whatbuf() == "*scratch*" )
			load_session();
		}
	}
add_to_hook("_jed_startup_hooks", &startup_load_session_hook);
provide("ncsession");

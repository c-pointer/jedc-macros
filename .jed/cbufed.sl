%% -*- mode: slang; tab-width: 4; indent-style: tab; encoding: utf-8; -*-
%%
%%	Copyright (c) 2016 Nicholas Christopoulos.
%%	Released under the terms of the GNU General Public License (ver. 3 or later)
%%
%%	This is a bufed version for cbrief
%%
%%	2016-10-22 Nicholas Christopoulos
%%		Created.
%%

require("nc-utils");
require("nc-term");

implements("cbufed");
private variable table;
private variable scrap_buf   = "*scratch*";
private variable help_buf    = "*help*";
private variable ignore_list = [ ".jedrecent", scrap_buf, "*Completions*"];
private variable cbuf_hide   = 1;
private variable prev_buf    = scrap_buf;

public define cbrief_bufpu_callback(item, code, key) {
	variable i, count, buf, pbuf, s, file, dir, name, flags, mode, st;

	if ( code == 'c' ) % cancel
		return 0;
	if ( code == 's' ) % select
		return 0;
	if ( code == 'd' ) { % delete item
		if ( length(table) == 1 ) {
			beep();
			return 0;
			}
		buf = table[item];
		table[item] = NULL;
		table = table[wherenot(_isnull(table))];
		delbuf(buf);
		return 1; %	0 = ignore, 1 allow delete buf
		}
	else if ( code == 'k' ) { % unhandled key
		if ( tolower(key) == 'w' || key == SL_ALT_KEY('w') ) { % write buffer
			pbuf = whatbuf();
			buf = table[item];
			setbuf(buf);
			save_buffer();
			setbuf(pbuf);
			return -2; % redraw
			}
		else if ( tolower(key) == 'e' )
			return 1;
		else if ( key == SL_ALT_KEY('e') ) { % read file
			file = dlg_openfile("Edit file", "");
			if ( strlen(file) > 0 )
				() = read_file(file);
			return -2;
			}
		else if ( tolower(key) == 'a' ) { % set abbrev mode on
			pbuf = whatbuf();
			setbuf(table[item]);
			toggle_buffer_flag(0x800);
			setbuf(pbuf);
			return -2; % redraw
			}
		else if ( tolower(key) == 'b' || key == SL_ALT_KEY('b') ) { % set binary mode
			pbuf = whatbuf();
			setbuf(table[item]);
			toggle_buffer_flag(0x200);
			setbuf(pbuf);
			return -2; % redraw
			}
		else if ( tolower(key) == 's' ) { % set autosave mode on
			pbuf = whatbuf();
			setbuf(table[item]);
			toggle_buffer_flag(0x02);
			setbuf(pbuf);
			return -2; % redraw
			}
		else if ( tolower(key) == 'o' ) { % read-only
			pbuf = whatbuf();
			setbuf(table[item]);
			toggle_buffer_flag(0x08);
			setbuf(pbuf);
			return -2; % redraw
			}
		else if ( tolower(key) == 'm' ) { % mode
			(file, dir,,flags) = getbuf_info();
			st = stat_file(vdircat(dir, file));
			if ( st == NULL )
				mode = set_buffer_umask(-1);
			else
				mode = st.st_mode & 0777;

			(s, i) = c_txtbox(" chmod ",
vdircat(dir, file) + "\n\
Current mode is " + sprintf("%04o", mode) +"\n\
\n\
rwx = 7, rw- = 6\n\
r-x = 5, r-- = 4\n\
\n\
Enter the new file mode\n\
", sprintf("%04o", mode));
			if ( i == 1 && strlen(s) ) {
				if ( s[0] != '0' ) s = "0" + s;
				if ( strlen(s) == 4 && isdigit(s[1]) && isdigit(s[2]) && isdigit(s[3]) ) {
					if ( mode != integer(s) ) {
						mode = integer(s);
						if ( chmod(file, mode) == 0 ) {
							set_buffer_modified_flag(1);
							mesgf("The new buffer mode is %04o.", mode);
							}
						else
							mesgf("%s", errno_string());
						}
					else
					mesg("Nothing changed.");
					}
				else
				mesg("Nothing changed.");
				}
			return -2; % redraw
			}
		else if ( tolower(key) == 'n' || key == SL_ALT_KEY('o') ) { % rename
			pbuf = whatbuf();
			buf = table[item];
			setbuf(buf);

			(file, dir, name, flags) = getbuf_info();
			(s, i) = c_txtbox(" Rename ", vdircat(dir,file) + "\n\nEnter new file name:", vdircat(dir, file));
			if ( i == 1 && strlen(s) && s != vdircat(dir, file) ) {
				if ( path_is_absolute(s) )
					dir = path_dirname(s);
				file = path_basename(s);
				name = path_basename(s);
				flags |= 1;
				setbuf_info(file, dir, name, flags);
				}
			setbuf(pbuf);
			return -2; % redraw
			}
		else if ( tolower(key) == 'r' ) { % reload
			pbuf = whatbuf();
			buf = table[item];
			setbuf(buf);

			(file, dir,,flags) = getbuf_info();
			clear_buffer();
			() = insert_file(path_concat(dir, file));
			setbuf_info(file, dir, buf, flags & ~0x004); % reset the changed-on-disk flag

			setbuf(pbuf);
			return -2; % redraw
			}
		else if ( tolower(key) == 'z' ) {
			scr_redraw();
			cbuf_hide = not (cbuf_hide);
			return -2; % redraw
			}
		else if ( key == SL_ALT_KEY('h') || key == '?' ) { % Alt+H
			s = "\
ENTER : Select buffer\n\
e     : (E)dit file, same as ENTER\n\
ESC,q : (Q)uit window\n\
w     : (W)rite buffer\n\
DEL,d : (D)elete buffer (unload file)\n\
r     : (R)eload file\n\
a     : Toggle (A)bbrev mode\n\
b     : Toggle (B)inary mode\n\
s     : Toggle auto(S)ave mode\n\
o     : Toggle read(O)nly mode\n\
m     : Change file (M)ode\n\
n     : Re(N)ame file\n\
z     : Zombies (hidden buffers)\n";
			() = c_msgbox(" Help ", s);
			}
		}
	return 0;
	}

% using popup menu to change buffer
public define cbrief_bufpu() {
	variable i, n, sel, ml, count, opts, dopts;
	variable list, e, fs0, fs1;
	variable file, dir, name, flags;
	variable st, mode, size;

	prev_buf = whatbuf();

	do {
		% get the list of buffers
		count = buffer_list();
		table = list_to_array(__pop_list(count));

		% remove hidden buffers
		if ( cbuf_hide ) {
			foreach e ( ignore_list )
				table[where(table == e)] = NULL;
			for ( i = 0; i < count; i ++ )
				if ( table[i] != NULL && table[i][0] == ' ' )
					table[i] = NULL;
			table = table[wherenot(_isnull(table))];
			count = length(table);
			if ( count == 0 ) return;
			}
		table = table[array_sort(table, &strcmp)];
		sel = where(table==prev_buf)[0];
		ml = max(array_map(Integer_Type, &strlen, table));

		% build options string
		dopts = String_Type[count << 1];
		for ( i = 0; i < count; i ++ ) {
			setbuf(table[i]);
			(file, dir, name, flags) = getbuf_info();
			fs0 = "-"; fs1 = "";
			if ( flags & 0x001 ) fs0 = "*"; % modified
			if ( flags & 0x004 ) fs0 = "!"; % modified in disk
			if ( flags & 0x008 ) fs0 = "R"; % read-only

			fs1 += ( flags & 0x200 ) ? " Binary" : ""; % binary
			fs1 += ( flags & 0x002 ) ? " Autosave" : ""; % autosave
			fs1 += ( flags & 0x800 ) ? " Abbrev" : ""; % abbrev

			st = stat_file(vdircat(dir, file));
			if ( st == NULL ) {
				mode = set_buffer_umask(-1);
				size = 0;
				}
			else {
				mode = st.st_mode & 0777;
				size = st.st_size;
				}
			dopts[(i << 1)    ] = sprintf("%-*s %s%s - 0%o - Size %uK", ml, table[i], fs0, fs1, mode, int(round(size / 1024)));
			dopts[(i << 1) + 1] = vdircat(dir, file);
			}
		setbuf(prev_buf);

		% call popup menu
		n = dlg_bufmenu(dopts, sel, " Buffer List ", " E to edit, D to delete, W to write, Alt-H for more ", "cbrief_bufpu_callback");
		if ( n >= 0 ) % if !cancel switch to buffer
			sw2buf(table[n]);
		} while ( n < -1 );

	scr_redraw();
	}

provide("cbufed");

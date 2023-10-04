# jedc-macros

BRIEF v3.1 compatibility for Jed and XJed.

![console](https://codeberg.org/nereusx/jedc-macros/raw/main/screenshots/cbrief-open.png)
Jed in console, open file

### Index
1. Requirements
2. Environment
3. Installation
4. Differences with original BRIEF v3.1
5. Advanced Command Line Interface (F10)
6. Optional modules/flags
7. Terminal Escape Codes (fix/custom)
8. .jedrc
9. Additional modules (and menu bar)
10. Screenshots

#### See also:
* See patched jed version [patched-JED](https://codeberg.org/nereusx/jedc)
* See manual pages of slang+jed to be used by man (mandb/mandoc) [jed-man](https://codeberg.org/nereusx/jedc-macros/src/branch/main/jed-man/README.md)

## 1. Requirerments
packages slang[1] gettext[2] xclip[3]

[1] libslang, slang, slsh it is the same project, a few distros uses different packages.
Install all of them. Actually are the same project, it should be one package.
Also, check your distro if there is different -devel version.

[2] Part of standard development environment.

[3] Clipboard utility to communicate with X Clipboard from terminal.

#### Non-Unix users
I do not support any non-unix not even linux with systemd.
Fork both projects, jedc and jedc-macros, I glady to merge your changes.
Systemd is still unwanted.

## 2. Environment

Backups directory
```
mkdir -p ~/.backup/text
chmod 0700 ~/.backup
chmod 0700 ~/.backup/text
```

Add the lines to your profile
```
export BACKUPDIR=~/.backup
export JED_HOME=~/.jed
alias b=jed
```

[t]csh users
```
setenv BACKUPDIR ~/.backup
setenv JED_HOME ~/.jed
alias b jed
```

## 3.1 Install patced version of jed
```
git clone https://codeberg.org/jedc
cd jedc
./install.sh
```

#### Warning: Fix macros directory location
Linux distributions correctly use `/usr/share/jed` directory.
Configuration of JED without prefix parameter, uses `/usr/local/jed`.
Configuration of JED with `--prefix=/usr` parameter [suggested], uses `/usr/jed`.
Just make all of them to show to one directory. It is better to do before `make install`.

Example:
```
mkdir /usr/share/jed
ln -s /usr/share/jed /usr/jed
ln -s /usr/share/jed /usr/local/jed
```

## 3.2 Install macros
```
git clone https://codeberg.org/jedc-macros
cd jedc-macros
./install.sh
```

#### Warning:
I suggest to replace the `syntax/cmode.sl` with the original
version of JED's library because I dont use the most users
writting style. It has many options to reformat to your style.
```
cp /usr/share/jed/lib/cmode.sl ~/.jed/syntax/cmode.sl
```

### Tip:

The xjed reads `~/.Xresources` to find fonts
Use this in your `~/.Xresources`, with the  `xft:` prefix
you can use truetype font.
```
xjed*font: -*-Terminus-bold-*-*-*-16-*-*-*-*-*-iso10646-1
xjed*font: xft:Iosevka Fixed:size=14:style=bold
```

Tip: `xrdb -merge ~/.Xresources` will update X on the fly.

## 4. Differences

*Jed* has not the same abilities with BRIEF's windows system.
It is only creates vertically windows. Anyway, the macros uses
*BRIEF* keys with similar way.

**Differences** to the original BRIEF keys:
```
F1					Change window
					Limitations of JED. Changes to next window.
F2					Resize window
					Limitations of JED. Vertical resize window.
F3					Create window
					Limitations of JED. Creates vertical window.
F4					Delete window
					Limitations of JED. Deletes the other window.
```

```
Alt+p				Previous buffer
```
In BRIEF Alt+P was Print Block.
Print block today is useless, but also can replaced by select the region and send
to other file / or command / or device / or printer by using command line interface.
(i.e. '| lpr') with or without filters (aps / paps).

**Additional** to the original BRIEF keys:
```
Alt+F               Search forward (Alt+S,Alt+T,F5,F6,etc,still works)
                    In BRIEF: Was show the full path filename, something useless
					since you can see it in Alt+B (buffer manager).
Ctrl+F              Search backward. In BRIEF: unused.
Ctrl+Q              Cancel (ESC works too, but may waits 1 sec in Unix).
                    In BRIEF: unused, but also replaces the Ctrl+Halt (stop macro
					execution) key that cannot catch in Unix.
[Alt+\]]            Matching delimiters
[Alt+/]             Completion
[Alt+!]             Run shell command and capture its output in new buffer
[Alt+,] or [Ctrl+O<] Uncomment block or line
[Alt+.] or [Ctrl+O>] Comment block or line
[Alt+`]             Displays help (man page) about the word under the cursor.
[Ctrl+Ox]           Toggles the clipboard from internal to X (even in terminal jed)
[F11]               JED's Dired (file manager)
[F12]               JED's menu (BRIEF had no menus, except the popup)
```

## 5. Command line interface
This is a powerfull tool, by far better than BRIEF's.

```
[F10] or [Alt+=]      Enter CBRIEF's Command line interface

Executes any CBRIEF's macro

OR

if begins with '?',   Prints the result (used mostly as calculator).
                      example: '? 1/3*0x20, whatbuf()'
if begins with '$',   Runs SLang code.
                      example: '$ save_buffers(); insert("\nok\n");'
if begins with '!',   Runs shell command and returns the output in new buffer.
if begins with '<!',  Runs shell command and replaces the current text with the result.
if begins with '<<!', Runs shell command and insert the output in current buffer.
if begins with '|',   Pipes the selected block or the whole buffer to command and
                      retunrns the result in new buffer.
if begins with '<|',  Pipes the selected block or the whole buffer to command and
                      replaces the current buffer or block with the result.
                      example: '<| sed s/what/with/g'
if begins with '<<|', Pipes the selected block or the whole buffer to command and
                      insert the result in the current buffer.
if begins with '<',   Replaces the contents of the current buffer or block with the
                      contents of the file;
                      if file is not specified then it will prompt for the name.
if begins with '<<',  Insert the contents of the specified file to current position;
                      if file is not specified then it will prompt for the name.
if begins with '>',   Writes the selected block or the whole buffer to file.
if begins with ">>",  Appends the selected block or the whole buffer to file.
if begins with '&',   Execute in background and in new terminal on XJed.                             
```

## Compile/Build/Run (not work well)
```
[Alt+F10]           Compile Buffer
[Ctrl+F10]          Make (non-brief)
[Ctrl+F9]           Borland's compile key
[F9]                Make (Borland's build and run)
```

Make/compile/run is a mess between versions of BRIEF. WIP.
For now, F9 make & run, Ctrl+F9 compile. In old BRIEF, F9 was
used to load keyboard macros, and Shift+F9 to delete a keyboard macro file.
This can be done by CLI but I really I never found it usefull.

## 6. Modules/Flags
The following changes are controlled by flags in the beginning of cbrief.sl

Support Win/KDE clipboard keys (default on)
```
Ctrl+C              Copy. In BRIEF: Center line in window. CLI = recenter
Ctrl+V              Paste. In BRIEF: Unused
Ctrl+X              Cut. In BRIEF: Write all files and Exit. CLI = save_buffers
```

X11 clipboard (`xclip` needed, default on)
```
Alt+Ctrl+C = Copy
Alt+Ctrl+V = Paste
Alt+Ctrl+X = Cut
```

Emacs/Readline compatibility (default on)
```
Ctrl+A =            Home. In BRIEF: Unused.
Ctrl+E =            End. In BRIEF: Scroll Buffer Up.
```

Laptop mode (default off)
```
Ctrl+Up    = PageUp
Ctrl+Down  = PageDown
Ctrl+Left  = Home
Ctrl+Right = End
```

## 7. User's terminal codes fix file

Keys compinations in BRIEF are very extensive that does not supported by terminfo
in Unix. Even worst there are differences between terminal emulators or multiplexers.
So a few keys (mostly function keys and their compinations) sequences must be
redefined to your environment. At least I make it easy. By pressing Alt+Q you can
get the correct sequence of a key and assingn it to its name.

Example:
```
Key_Shift_F10 = "[Press Alt+Q][Press Shift+F10]"; 
```

The `~/.jed/term.sl` file is used for any user to fix terminal incompatibilities.
It is user's file, remove all lines and note yours, does not matter.
Intented to not used by CBRIEF developers.

There is also a `~/.jed/nc-term.sl` file that is used for me to give some ready
solutions. This is loaded before `term.sl`, so you dont need to worry.

## 8. User's jedrc additional file

The `~/.jed/local.sl` file is used for any user to add its own commands without mess it with the rest cbrief package.
It is user's file, remove all lines and note yours, does not matter. 
Intented to not used by CBRIEF developers.

## 9. Additional user modules
CBRIEF offer interface to adding your own modules to current editor.
And already has much more advanced capability (for example multiple backup files).
Build your ideas in [S-Lang](https://www.jedsoft.org/slang/) and adding to the editor
with the following commands.

### Load the required functions
```
autoload("cbrief_cli_append", "cbrief");
autoload("cbrief_setkey", "cbrief");
autoload("cbrief_menu", "cbrief");
autoload("cbrief_menu_insert", "cbrief");
```

### Adding command to cli
```
% There are the following types-of-call the function
% 0 = no parameters.
% 1 = C-style argc/argv, argv only & argv[0] = function name.
% 2 = one big string, function has to decide how to split it.
% 3 = eval(this), macro_function should be a string.
% 4 = call(this), macro_function should be a string.
% 5 = C-style argc/argv, argv[0] = function name
% 6 = native S-Lang pushed arguments, function has to use __pop_list{_NARGS}.
% 7 = alias, runs cbrief_command(mact_function_string)

cbrief_cli_append("macro-name", &macro_function, type_of_call, NULL or help_text);
```

### Assigns a function to a key
The key will be added to CBrief list of keys.
This means the key will survive after a reset.

```
cbrief_setkey("function_name" | &function_name, "key-sequence");
```

### Access menu
Editing menu is more tricky, it would be better to read JED's code
about menu at `/usr/share/jed/lib/` site.sl file.

```
% Adding a submenu to menu
cbrief_menu("parent-submenu", "title", "@{popup}");
% Adding a function to menu
cbrief_menu("parent-submenu", "title", "function-name");
% Iserting item in specific position
cbrief_menu_insert("parent-submenu", "title", "function-name", "next-menu-item");
```

parent-submenu and next-menu-item are JED's menu-strings as you see it in menu.
For example the submenu Buffers it is "Global.&Buffers", while the "next-meni-item"
does not need so detailed path, for example "C&ompile". 

## Final Note
Please report any incompatibility with orignal BRIEF and its version.
Also any link or file from original manual / software are welcome.

## 10. Screenshots

Xjed με Iosevka truetype font
![xjed](https://codeberg.org/nereusx/jedc-macros/raw/main/screenshots/cbrief-xjed.png)

Jed in console, open file
![console](https://codeberg.org/nereusx/jedc-macros/raw/main/screenshots/cbrief-open.png)

Jed in console, select buffer
![console](https://codeberg.org/nereusx/jedc-macros/raw/main/screenshots/cbrief-blue-a.png)

Jed in console, short help screen
![console](https://codeberg.org/nereusx/jedc-macros/raw/main/screenshots/cbrief-blue-help.png)

Jed in console, dark theme, man (on-line help)
![console](https://codeberg.org/nereusx/jedc-macros/raw/main/screenshots/cbrief-atom-man.png)

Jed in console, dark theme, menu (F12)
![console](https://codeberg.org/nereusx/jedc-macros/raw/main/screenshots/cbrief-atom-menu.png)

Jed in console, dark theme, dired (F11)
![console](https://codeberg.org/nereusx/jedc-macros/raw/main/screenshots/cbrief-atom-dired.png)

Jed in console, dark theme, jed/slang or other manual pages
![console](https://codeberg.org/nereusx/jedc-macros/raw/main/screenshots/jed-man.png)

## The fonts can be found

* [XSG my bitmap fonts](https://codeberg.org/nereusx/xsg-fonts)
* [Iosevka true type monospace fonts](https://github.com/be5invis/Iosevka)

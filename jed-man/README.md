# jed-man

JED and S-Lang man page subsystem. Its using the already installed man
page system (in selected subdirectory) or using as autonomous command-line
utility with or without groff output.

```
# create man3sl directory with man pages (3sl section)
./jed-man -apm man3sl			
 
# see the write_buffer page of section 3sl in the . man directory
man -s 3sl -m . write_buffer	

# example: use it instead man with cache enabled (much faster)

# optional create cache
./jed-man -c		

# search names and descriptions for the keyword buffer
./jed-man -rd buffer
```

## install

1) Get a copy of S-Lang, we will need the documentation files.
```
git clone git://git.jedsoft.org/git/slang.git
```

2) Get a copy of my patched version of JED
```
git clone https://codeberg.org/nereusx/jedc
```

3) Get a copy of my jed macro packages (CBRIEF compatibility)
```
git clone https://codeberg.org/nereusx/jedc-macros
```

4) Ready to install
```
cd jedc-macros/jed-man
make && make install
```

5) Try it
```
man -s 3sl write_buffer
```

done.

## Notes:
There are some icompatibilities between `mandoc` and `mandb` package.
This package is selected by your distribution to use it as `man`.
There may be some non-important problems.
I use it with `mandoc` package, not tested yet with `mandb`.

## jed-to-tm
This utility reads C/C++ or S-Lang files with TM documentation and prints
the contents. Used to extract extra documentation from jed/lib files.


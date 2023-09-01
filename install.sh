#!/bin/sh

# create backup dir
if [ ! -d ~/.backup/text ]; then
	mkdir -p ~/.backup/text
	chmod 0700 ~/.backup
	chmod 0700 ~/.backup/text
	echo "Backup-directory created at ${HOME}/.backup"
fi

# set $BACKUPDIR
if [ -z "$BACKUPDIR" ]; then
	export BACKUPDIR=${HOME}/.backup
	list=".bashrc .zshrc .yashrc .kshrc"
	for e in $list; do
		if [ -f ~/$e ]; then
			echo 'export BACKUPDIR=${HOME}/.backup' >> ~/$e
		fi
	done
	list=".cshrc .tcshrc"
	for e in $list; do
		if [ -f ~/$e ]; then
			echo 'setenv BACKUPDIR ${HOME}/.backup' >> ~/.$e
		fi
	done
	echo "Environmet variable BACKUPDIR added; reload shell's rc required"
	echo
fi

# set $JED_HOME
if [ -z "$JED_HOME" ]; then
	export JED_HOME=${HOME}/.jed
	list=".bashrc .zshrc .yashrc .kshrc"
	for e in $list; do
		if [ -f ~/$e ]; then
			echo 'export JED_HOME=${HOME}/.jed' >> ~/$e
		fi
	done
	list=".cshrc .tcshrc"
	for e in $list; do
		if [ -f ~/$e ]; then
			echo 'setenv JED_HOME ${HOME}/.jed' >> ~/.$e
		fi
	done
	echo "Environment variable JED_HOME added; reload shell's rc required"
	echo
fi

# check /etc/profile.d for xjed desktop
if [ -d /etc/profile.d ]; then
	if [ ! -f /etc/profile.d/cbrief.sh ]; then
		echo "Warning: XJed may not work correctly when executed from X"
		echo "It may need to add /etc/profile.d/ few settings"
		echo
		echo 'Edit /etc/profile.d/cbrief.sh and add those two lines (root req):'
		echo 'export BACKUPDIR=${HOME}/.backup'
		echo 'export JED_HOME=${HOME}/.jed'
		echo
	fi
	if [ ! -f /etc/profile.d/cbrief.csh ]; then
		echo "Warning: XJed may not work correctly when executed from X"
		echo "It may need to add /etc/profile.d/ few settings"
		echo
		echo 'Edit /etc/profile.d/cbrief.csh and add those two lines (root req):'
		echo 'setenv BACKUPDIR ${HOME}/.backup'
		echo 'setenv JED_HOME ${HOME}/.jed'
		echo
	fi
fi

if [ -z "$COLORTERM" ]; then
	echo "COLORTERM isnt defined, truecolors are not supported."
	echo "To fix it, add to your profile:"
	echo
	echo 'export COLORTERM=truecolor'
	echo
	echo "or for tcsh users:"
	echo 'setenv COLORTERM truecolor'
	echo
fi

cp -r .jed ~/
echo 'Files copied to ~/.jed'
#cd jed-man
#make && make install
echo '* done *'

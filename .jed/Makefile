all: help

help:
	@echo "build - builds all sl (root rq)"
	@echo "clear - removes all slc"

build:
#	jed -batch -l nc-utils.sl -f compile_all_local_sl 
	sudo jed -batch -n -l preparse

clean:
	@find ~/.jed -name '*.slc' -delete

#
# Makefile.am for y2c_network/doc
#

SUBDIRS = autodocs # files hwinfo

htmldir = $(docdir)

doc_DATA =
html_DATA = todo.html $(wildcard *.html)

todo.html: Todo.txt
	@(							\
		grep -B100 '##BODY##' skel.html;		\
		echo -e "\n<pre>\n";				\
		cat Todo.txt;					\
		echo -e "\n</pre>\n";				\
		grep -A100 '##BODY##' skel.html;		\
	) | sed "s/##TITLE##/Things To Do/g" > todo.html

CLEANFILES = todo.html
EXTRA_DIST = $(doc_DATA) $(html_DATA)

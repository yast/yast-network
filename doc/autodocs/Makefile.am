#
# Makefile.am for y2c_network/doc/autodocs
#
# $Id$
#

docdir = @DOCDIR@
htmldir = $(docdir)/autodocs

index.html: $(srcdir)/../../src/*.ycp
	@YAST2DIR@/bin/ycpdoc -d. $(srcdir)/../../src/*.ycp

html_DATA = index.html $(wildcard *.html)

CLEANFILES = $(html_DATA)

# Makefile.am for .../doc/diagrams

htmldir = @docdir@/diagrams

CLEANFILES = $(wildcard *.png)
%.png: %.dia
	dia -n -e $@ $<

html_DATA = $(patsubst %.dia,%.png,$(wildcard *.dia))
EXTRA_DIST = $(html_DATA)

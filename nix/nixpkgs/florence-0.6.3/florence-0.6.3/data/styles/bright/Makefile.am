
styledir = $(datadir)/florence/styles/bright
style_in_files = default.svg
style_DATA = florence.style florence.defs $(style_in_files)
$(style_in_files): $(style_in_files:.svg=.svg.in)
	sed -e "s|\@BASEDIR\@|$(styledir)|" $< > $@

EXTRA_DIST = florence.style florence.defs $(style_in_files:.svg=.svg.in)
DISTCLEANFILES = $(style_in_files)


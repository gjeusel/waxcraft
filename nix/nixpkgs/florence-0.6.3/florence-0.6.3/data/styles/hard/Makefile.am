
styledir = $(datadir)/florence/styles/hard
style_in_files = default.svg return.svg space.svg wide.svg xl.svg xxl.svg high.svg tiny.svg mini.svg small.svg
style_DATA = florence.style florence.defs $(style_in_files)
$(style_in_files): $(style_in_files:.svg=.svg.in)
	sed -e "s|\@BASEDIR\@|$(styledir)|" $< > $@

EXTRA_DIST = florence.defs florence.style $(style_in_files:.svg=.svg.in)
DISTCLEANFILES = $(style_in_files)


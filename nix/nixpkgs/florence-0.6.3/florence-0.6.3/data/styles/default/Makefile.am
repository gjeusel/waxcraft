
styledir = $(datadir)/florence/styles/default
symbol_in_files = symbols.xml.in
style_in_files = florence.style
style_DATA = $(style_in_files) florence.defs $(symbol_in_files:.xml.in=.xml)
@INTLTOOL_XML_RULE@
$(symbol_in_files): $(symbol_in_files:.xml.in=.xml.in.in)
	sed -e "s|\@ICONDIR\@|$(ICONDIR)|" $< > $@
$(style_in_files): $(style_in_files:.style=.style.in)
	sed -e "s|\@BASEDIR\@|$(styledir)|" $< > $@

EXTRA_DIST = florence.defs $(symbol_in_files:.xml.in=.xml.in.in) $(style_in_files:.style=.style.in)
DISTCLEANFILES = $(symbol_in_files:.xml.in=.xml) $(symbol_in_files) $(style_in_files)


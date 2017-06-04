AUTOMAKE_OPTIONS = subdir-objects

bin_PROGRAMS = florence
lib_LTLIBRARIES = libflorence-1.0.la

florence_SOURCES = main.c florence.c keyboard.c key.c trace.c settings.c trayicon.c\
                   layoutreader.c style.c view.c status.c tools.c settings-window.c\
                   xkeyboard.c fsm.c service.c controller.c menu.c

if WITH_RAMBLE
   florence_SOURCES += ramble.c
endif

florence_CPPFLAGS = -I$(top_srcdir) -DICONDIR="\"$(ICONDIR)\""\
   -DFLORENCELOCALEDIR=\""$(florencelocaledir)"\"\
   -DDATADIR="\"$(datadir)/florence\"" $(DEPS_CFLAGS) $(GTK3_CFLAGS)\
   $(LIBGNOME_CFLAGS) $(LIBNOTIFY_CFLAGS) $(XTST_CFLAGS) $(AT_SPI2_CFLAGS) $(INCLUDES)
florence_LDADD = $(DEPS_LIBS) $(LIBM) $(X11_LIBS) $(LIBGNOME_LIBS) $(LIBNOTIFY_LIBS)\
   $(XTST_LIBS) $(AT_SPI2_LIBS) $(GTK3_LIBS) -lflorence-1.0

libflorence_1_0_la_SOURCES = lib/florence.c
library_includedir=$(includedir)/florence-1.0
library_include_HEADERS = lib/florence.h
FLORENCE_LIBRARY_VERSION=1:0:0
libflorence_1_0_la_LDFLAGS = -version-info $(FLORENCE_LIBRARY_VERSION)
libflorence_1_0_la_CPPFLAGS = $(GIO_CFLAGS)
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = florence-1.0.pc

EXTRA_DIST = florence.h keyboard.h key.h layoutreader.h settings.h settings-window.h\
             status.h style.h system.h tools.h trace.h trayicon.h view.h xkeyboard.h\
             ramble.h fsm.h service.h florence.server.in.in controller.h menu.h
 
DISTCLEANFILES = $(server_in_files) $(server_DATA) $(lib_LTLIBRARIES)


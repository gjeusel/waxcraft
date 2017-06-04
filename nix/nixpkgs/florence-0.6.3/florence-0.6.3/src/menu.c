/* 
   Florence - Florence is a simple virtual keyboard for Gnome.

   Copyright (C) 2014 François Agrech

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  

*/

#include "system.h"
#include "trace.h"
#include "settings.h"
#include <gtk/gtk.h>
#include <gdk-pixbuf/gdk-pixbuf.h>

/* Display the about dialog window */
void menu_about(void)
{
	START_FUNC
	gchar *authors[] = {
		"François Agrech <f.agrech@gmail.com>",
		"Pietro Pilolli <alpha@paranoici.org>",
       		"Arnaud Andoval <arnaudsandoval@gmail.com>",
		"Stéphane Ancelot <sancelot@free.fr>",
		"Laurent Bessard <laurent.bessard@gmail.com>", NULL};
	gtk_show_about_dialog(NULL, "program-name", _("Florence Virtual Keyboard"),
		"version", VERSION, "copyright", _("Copyright (C) 2012 François Agrech"),
		"logo", gdk_pixbuf_new_from_file(ICONDIR "/florence.svg", NULL),
		"website", "http://florence.sourceforge.net",
		"authors", authors,
		"license", _("Copyright (C) 2012 François Agrech\n\
\n\
This program is free software; you can redistribute it and/or modify\n\
it under the terms of the GNU General Public License as published by\n\
the Free Software Foundation; either version 2, or (at your option)\n\
any later version.\n\
\n\
This program is distributed in the hope that it will be useful,\n\
but WITHOUT ANY WARRANTY; without even the implied warranty of\n\
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n\
GNU General Public License for more details.\n\
\n\
You should have received a copy of the GNU General Public License\n\
along with this program; if not, write to the Free Software Foundation,\n\
Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA."),
		NULL);
	END_FUNC
}

#ifdef ENABLE_HELP
/* Open yelp */
void menu_help(void)
{
	START_FUNC
#if GTK_CHECK_VERSION(2,14,0)
	GError *error=NULL;
	gtk_show_uri(NULL, "ghelp:florence", gtk_get_current_event_time(), &error);
	if (error) flo_error(_("Unable to open %s"), "ghelp:florence");
#else
	if (!gnome_help_display_uri("ghelp:florence", NULL)) {
		flo_error(_("Unable to open %s"), "ghelp:florence");
	}
#endif
	END_FUNC
}
#endif

/* Called when the icon is right->clicked
 * Displays the menu. */
void menu_show(GObject *parent, guint button, GCallback quit_func,
	GtkMenuPositionFunc pos_func, gpointer user_data, guint time)
{
	START_FUNC
	GtkWidget *menu, *about, *config, *quit;
#ifdef ENABLE_HELP
	GtkWidget *help;
#endif
	menu=gtk_menu_new();

	quit=gtk_menu_item_new_with_mnemonic(_("_Quit"));
	g_signal_connect_swapped(quit, "activate", quit_func, user_data);

#ifdef ENABLE_HELP
	help=gtk_menu_item_new_with_mnemonic(_("_Help"));
	g_signal_connect(help, "activate", G_CALLBACK(menu_help), NULL);
#endif

	about=gtk_menu_item_new_with_mnemonic(_("_About"));
	g_signal_connect(about, "activate", G_CALLBACK(menu_about), NULL);

	config=gtk_menu_item_new_with_mnemonic(_("_Preferences"));
	g_signal_connect(config, "activate", G_CALLBACK(settings), NULL);

	gtk_menu_shell_append(GTK_MENU_SHELL(menu), config);
#ifdef ENABLE_HELP
	gtk_menu_shell_append(GTK_MENU_SHELL(menu), help);
#endif
	gtk_menu_shell_append(GTK_MENU_SHELL(menu), about);
	gtk_menu_shell_append(GTK_MENU_SHELL(menu), gtk_separator_menu_item_new());
	gtk_menu_shell_append(GTK_MENU_SHELL(menu), quit);
	gtk_widget_show_all(menu);
 
	gtk_menu_popup(GTK_MENU(menu), NULL, NULL, pos_func,
		parent, button, time);
	END_FUNC
}

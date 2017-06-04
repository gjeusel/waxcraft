/* 
   Florence - Florence is a simple virtual keyboard for Gnome.

   Copyright (C) 2012 François Agrech

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

#include "trayicon.h"
#include "menu.h"
#include "system.h"
#include "trace.h"
#include "settings.h"
#include <gtk/gtk.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#ifdef ENABLE_AT_SPI
#define AT_SPI
#endif
#ifdef ENABLE_AT_SPI2
#define AT_SPI
#endif

/* Called when the tray icon is left-clicked
 * Toggles florence window between visible and hidden. */
void trayicon_on_click(GtkStatusIcon *status_icon, gpointer user_data)
{
	START_FUNC
	struct trayicon *trayicon=(struct trayicon *)(user_data);
	if (gtk_widget_get_visible(GTK_WIDGET(trayicon->view->window))) {
		view_hide(trayicon->view);
	} else { 
#ifdef AT_SPI
		view_show(trayicon->view, NULL);
#else
		view_show(trayicon->view);
#endif
	}
	END_FUNC
}

/* Called when the tray icon is right->clicked
 * Displays the menu. */
void trayicon_on_menu(GtkStatusIcon *status_icon, guint button,
	guint activate_time, gpointer user_data)
{
	START_FUNC
	struct trayicon *trayicon=(struct trayicon *)(user_data);
	menu_show(G_OBJECT(status_icon), button,
		trayicon->trayicon_quit, gtk_status_icon_position_menu,
		trayicon->user_data, activate_time);
	END_FUNC
}

#ifdef ENABLE_NOTIFICATION
/* Called to stop showing startup notification. */
void trayicon_notification_stop(NotifyNotification *notification, gchar *action, gpointer userdate)
{
	START_FUNC
	if (!strcmp(action, "STOP"))
		settings_set_bool(SETTINGS_STARTUP_NOTIFICATION, FALSE);
	END_FUNC
}

/* Display startup notification */
gboolean trayicon_notification_start(gpointer userdata)
{
	START_FUNC
	struct trayicon *trayicon=(struct trayicon *)userdata;
	if (!notify_init(_("Florence"))) flo_warn(_("libnotify failed to initialize"));
#ifdef ENABLE_NOTIFICATION_ICON
	trayicon->notification=notify_notification_new_with_status_icon(
#else
	trayicon->notification=notify_notification_new(
#endif
		_("Florence is running"),
		_("Click on Florence icon to show/hide Florence.\n"
		"Right click on it to display menu and get help."),
#ifdef ENABLE_NOTIFICATION_ICON
		NULL, trayicon->tray_icon);
#else
		NULL);
#endif
	notify_notification_add_action(trayicon->notification, "STOP",
		_("Do not show again"), trayicon_notification_stop, NULL, NULL);
	notify_notification_set_timeout(trayicon->notification, 5000);
	if (!notify_notification_show(trayicon->notification, NULL))
		flo_warn(_("Notification failed"));
	END_FUNC
	return FALSE;
}
#endif

/* Deallocate all the memory used bu the trayicon. */
void trayicon_free(struct trayicon *trayicon)
{
	START_FUNC
#ifdef ENABLE_NOTIFICATION
	if (trayicon->notification) g_object_unref(trayicon->notification);
	notify_uninit();
#endif
	g_object_unref(trayicon->tray_icon);
	g_free(trayicon);
	END_FUNC
}

/* Creates a new trayicon instance */
struct trayicon *trayicon_new(struct view *view, GCallback quit_cb, gpointer user_data)
{
	START_FUNC
	struct trayicon *trayicon;

	trayicon=g_malloc(sizeof(struct trayicon));
	memset(trayicon, 0, sizeof(struct trayicon));

	trayicon->trayicon_quit=quit_cb;
	trayicon->user_data=user_data;
	trayicon->tray_icon=gtk_status_icon_new();
	trayicon->view=view;
	g_signal_connect(G_OBJECT(trayicon->tray_icon), "activate",
		G_CALLBACK(trayicon_on_click), (gpointer)trayicon);
	g_signal_connect(G_OBJECT(trayicon->tray_icon), "popup-menu",
		G_CALLBACK(trayicon_on_menu), (gpointer)trayicon);
	gtk_status_icon_set_from_icon_name(trayicon->tray_icon, "florence");
	gtk_status_icon_set_tooltip_text(trayicon->tray_icon, _("Florence Virtual Keyboard"));
	gtk_status_icon_set_visible(trayicon->tray_icon, TRUE);

#ifdef ENABLE_NOTIFICATION
	if (settings_get_bool(SETTINGS_STARTUP_NOTIFICATION))
		g_timeout_add(2000, trayicon_notification_start, (gpointer)trayicon);
#endif

	END_FUNC
	return trayicon;
}

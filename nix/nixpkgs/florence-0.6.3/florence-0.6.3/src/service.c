/* 
 * florence - Florence is a simple virtual keyboard for Gnome.

 * Copyright (C) 2012 François Agrech

 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  

*/

#include "system.h"
#include "trace.h"
#include "service.h"
#include "settings.h"
#include "menu.h"

/* Service interface */
static const gchar service_introspection[]=
	"<node>"
	"  <interface name='org.florence.Keyboard'>"
	"    <method name='show'/>"
	"    <method name='move'>"
	"      <arg type='u' name='x' direction='in'/>"
	"      <arg type='u' name='y' direction='in'/>"
	"    </method>"
	"    <method name='move_to'>"
	"      <arg type='u' name='x' direction='in'/>"
	"      <arg type='u' name='y' direction='in'/>"
	"      <arg type='u' name='w' direction='in'/>"
	"      <arg type='u' name='h' direction='in'/>"
	"    </method>"
	"    <method name='hide'/>"
	"    <method name='toggle'/>"
	"    <method name='terminate'/>"
	"    <method name='menu'>"
	"      <arg type='u' name='time' direction='in'/>"
	"    </method>"
	"    <signal name='terminate'/>"
	"    <signal name='show'/>"
	"    <signal name='hide'/>"
	"  </interface>"
	"</node>";

/* Called when a dbus method is called */
static void service_method_call (GDBusConnection *connection, const gchar *sender,
	const gchar *object_path, const gchar *interface_name, const gchar *method_name,
	GVariant *parameters, GDBusMethodInvocation *invocation, gpointer user_data)
{
	START_FUNC
	guint x, y, w, h, time;
	gint screen_width, screen_height;
	gint win_width, win_height;
	GdkRectangle win_rect;
	struct service *service=(struct service *)user_data;
	flo_debug(TRACE_DEBUG, _("Executing method %s"), method_name);
	if (!g_strcmp0(method_name, "show")) {
#ifdef AT_SPI
		view_show(service->view, NULL);
#else
		view_show(service->view);
#endif
	} else if (!g_strcmp0(method_name, "move")) {
		g_variant_get(parameters, "(uu)", &x, &y);
		gtk_window_move(GTK_WINDOW(view_window_get(service->view)), x, y);
		/* For when the keyboard is hidden */
		settings_set_int(SETTINGS_XPOS, x);
		settings_set_int(SETTINGS_YPOS, y);
	} else if (!g_strcmp0(method_name, "move_to")) {
		g_variant_get(parameters, "(uuuu)", &x, &y, &w, &h);
		screen_height=gdk_screen_get_height(gdk_screen_get_default());
		screen_width=gdk_screen_get_width(gdk_screen_get_default());
		if (gtk_window_get_decorated(GTK_WINDOW(view_window_get(service->view)))) {
			gdk_window_get_frame_extents(gtk_widget_get_window(
				GTK_WIDGET(view_window_get(service->view))), &win_rect);
			win_width=win_rect.width;
			win_height=win_rect.height;
		} else gtk_window_get_size(view_window_get(service->view),
			&win_width, &win_height);
		if (win_width>(screen_width-x)) x=screen_width-win_width;

		gtk_window_set_gravity(view_window_get(service->view), GDK_GRAVITY_NORTH_WEST);
		if (win_height<(screen_height-y-h)) y=y+h;
		else if (y>win_height) y=y-win_height;
		else y=screen_height-win_height;

		gtk_window_move(GTK_WINDOW(view_window_get(service->view)), x, y);
		/* For when the keyboard is hidden */
		settings_set_int(SETTINGS_XPOS, x);
		settings_set_int(SETTINGS_YPOS, y);
	} else if (!g_strcmp0(method_name, "hide")) view_hide(service->view);
	else if (!g_strcmp0(method_name, "toggle")) {
		if (gtk_widget_get_visible(GTK_WIDGET(service->view->window)))
			view_hide(service->view);
		else
#ifdef AT_SPI
			view_show(service->view, NULL);
#else
			view_show(service->view);
#endif
	} else if (!g_strcmp0(method_name, "terminate")) service->quit(service->user_data);
	else if (!g_strcmp0(method_name, "menu")) {
		g_variant_get(parameters, "(u)", &time);
		menu_show(NULL, 3, (GCallback)service->quit, NULL, service->user_data, time);
	} else flo_error(_("Unknown dbus method called: <%s>"), method_name);
	g_dbus_method_invocation_return_value(invocation, NULL);
	END_FUNC
}

/* Called when dbus has been acquired */
static void service_on_bus_acquired (GDBusConnection *connection, const gchar *name, gpointer user_data)
{
	START_FUNC
	struct service *service=(struct service *)user_data;
	static const GDBusInterfaceVTable vtable={ service_method_call, NULL, NULL };
	g_dbus_connection_register_object(connection, "/org/florence/Keyboard",
		service->introspection_data->interfaces[0], &vtable, user_data, NULL, NULL);
	service->connection=connection;
	END_FUNC
}

/* Called when dbus name has been acquired */
static void service_on_name_acquired (GDBusConnection *connection, const gchar *name, gpointer user_data)
{
	START_FUNC
	struct service *service=(struct service *)user_data;
	flo_info(_("DBus name aquired: %s"), name);
	service->ready(service->user_data);
	END_FUNC
}

/* Called when dbus name has been lost */
static void service_on_name_lost (GDBusConnection *connection, const gchar *name, gpointer user_data)
{
	START_FUNC
	flo_warn(_("Service name lost."));
	END_FUNC
}

/* Send the show signal */
void service_on_show(GtkWidget *widget, gpointer data)
{
	GError *error=NULL;
	struct service *service=(struct service *)data;
	g_dbus_connection_emit_signal(service->connection, NULL, "/org/florence/Keyboard",
		"org.florence.Keyboard", "show", NULL, &error);
	if (error) flo_error(_("Error emitting show signal: %s"), error->message);
	else flo_debug(TRACE_DEBUG, _("DBus signal <show> sent"));
}

/* Send the hide signal */
void service_on_hide(GtkWidget *widget, gpointer data)
{
	GError *error=NULL;
	struct service *service=(struct service *)data;
	g_dbus_connection_emit_signal(service->connection, NULL, "/org/florence/Keyboard",
		"org.florence.Keyboard", "hide", NULL, &error);
	if (error) flo_error(_("Error emitting hide signal: %s"), error->message);
	else flo_debug(TRACE_DEBUG, _("DBus signal <hide> sent"));
}

/* Create a service object */
struct service *service_new(struct view *view, service_cb quit, service_cb ready, gpointer user_data)
{
	START_FUNC
	struct service *service=(struct service *)g_malloc(sizeof(struct service));
	if (!service) flo_fatal(_("Unable to allocate memory for dbus service"));
	memset(service, 0, sizeof(struct service));
	service->introspection_data=g_dbus_node_info_new_for_xml(service_introspection, NULL);
	service->owner_id=g_bus_own_name(G_BUS_TYPE_SESSION, "org.florence.Keyboard",
		G_BUS_NAME_OWNER_FLAGS_NONE, service_on_bus_acquired, service_on_name_acquired,
		service_on_name_lost, service, NULL);
	service->view=view;
	g_signal_connect(G_OBJECT(view_window_get(view)), "show",
		G_CALLBACK(service_on_show), service);
	g_signal_connect(G_OBJECT(view_window_get(view)), "hide",
		G_CALLBACK(service_on_hide), service);
	service->quit=quit;
	service->ready=ready;
	service->user_data=user_data;
	END_FUNC
	return service;
}

/* Destroy a service object */
void service_free(struct service *service)
{
	START_FUNC
	g_bus_unown_name(service->owner_id);
	g_dbus_node_info_unref(service->introspection_data);
	g_free(service);
	END_FUNC
}

/* Send the terminate signal */
void service_terminate(struct service *service)
{
	GError *error=NULL;
	g_dbus_connection_emit_signal(service->connection, NULL, "/org/florence/Keyboard",
		"org.florence.Keyboard", "terminate", NULL, &error);
	if (error) flo_error(_("Error emitting terminate signal: %s"), error->message);
}


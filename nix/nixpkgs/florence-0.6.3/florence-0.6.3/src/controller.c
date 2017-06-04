/* 
 * florence - Florence is a simple virtual keyboard for Gnome.

 * Copyright (C) 2014 François Agrech

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

#include "controller.h"
#include "trace.h"
#include "settings.h"
#include "tools.h"
#include "lib/florence.h"
#include <cairo-xlib.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/extensions/shape.h>

#define MOVING_THRESHOLD 15

RsvgHandle *handle;

/* on expose event: display florence icon */
void controller_icon_expose (GtkWidget *window, cairo_t* context, void *userdata)
{
	START_FUNC
	gdouble w, h;
	w=gtk_widget_get_allocated_width(window);
	h=gtk_widget_get_allocated_height(window);

	cairo_set_source_rgba(context, 0.0, 0.0, 0.0, 0.0);
	cairo_set_operator(context, CAIRO_OPERATOR_SOURCE);
	cairo_paint(context);
	cairo_set_operator(context, CAIRO_OPERATOR_SOURCE);
	style_render_svg(context, handle, w, h, FALSE, NULL);
	wait();
	END_FUNC
}

/* create icon */
void controller_icon_create (struct controller *controller, GtkWindow **icon, gdouble scale)
{
	START_FUNC
	RsvgDimensionData dim;
	if (!*icon) {
		*icon=GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
		gtk_window_set_keep_above(*icon, TRUE);
		gtk_window_set_skip_taskbar_hint(*icon, TRUE);
		rsvg_handle_get_dimensions(handle, &dim);
		gtk_widget_set_size_request(GTK_WIDGET(*icon), dim.width, dim.height);
		gtk_container_set_border_width(GTK_CONTAINER(*icon), 0);
		gtk_window_set_decorated(*icon, FALSE);
		gtk_window_set_position(*icon, GTK_WIN_POS_MOUSE);
		gtk_window_set_accept_focus(*icon, FALSE);
		gtk_widget_set_events(GTK_WIDGET(*icon),
			GDK_EXPOSURE_MASK|GDK_POINTER_MOTION_HINT_MASK|GDK_BUTTON_PRESS_MASK|GDK_BUTTON_RELEASE_MASK|
			GDK_ENTER_NOTIFY_MASK|GDK_LEAVE_NOTIFY_MASK|GDK_STRUCTURE_MASK|GDK_POINTER_MOTION_MASK);
		g_signal_connect(G_OBJECT(*icon), "draw", G_CALLBACK(controller_icon_expose), NULL);
		g_signal_connect(G_OBJECT(*icon), "screen-changed",
			G_CALLBACK(view_screen_changed), NULL);
		view_screen_changed(GTK_WIDGET(*icon), NULL, NULL);
	}
	END_FUNC
}

#ifdef ENABLE_AT_SPI2

void controller_icon_hide (gpointer user_data);
void controller_icon_show (gpointer user_data);
void controller_set_mode (struct controller *controller);

/* Move the window to near the accessible onject. */
void controller_move_to(struct controller *controller)
{
	AtspiRect *rect;
	AtspiComponent *component=NULL;
	guint x, y;

	if (settings_get_bool(SETTINGS_MOVE_TO_WIDGET) && controller->obj) {
		component=atspi_accessible_get_component(controller->obj);
		if (component) {
			rect=atspi_component_get_extents(component, ATSPI_COORD_TYPE_SCREEN, NULL);
			if (rect->x<0) x=0; else x=(guint)rect->x;
			if (rect->y<0) y=0; else y=(guint)rect->y;
			florence_move_to(x, y, (unsigned int)rect->width, (unsigned int)rect->height);
			g_free(rect);
		}
	}
}

/* on button-press events: destroy the icon and show the actual keyboard */
void controller_autohide_icon_press (GtkWidget *window, GdkEventButton *event, gpointer user_data)
{
	START_FUNC
	struct controller *controller=(struct controller *)user_data;
	controller_icon_hide((gpointer)controller);
	controller_move_to(controller);
	florence_show();
	END_FUNC
}

/* Show an intermediate icon before showing the keyboard (if intermediate_icon is activated) 
 * otherwise, directly show the keyboard */
void controller_show (struct controller *controller)
{
	START_FUNC
	GtkWindow *icon=controller->autohide_icon;

	if (settings_get_bool(SETTINGS_INTERMEDIATE_ICON)) {
		florence_hide();
		controller_icon_create(controller, &(controller->autohide_icon), 2.0);
		if (!icon) {
			g_signal_connect(G_OBJECT(controller->autohide_icon), "button-press-event",
				G_CALLBACK(controller_autohide_icon_press), controller);
			florence_register(FLORENCE_SHOW, controller_icon_hide, controller);
			florence_register(FLORENCE_HIDE, controller_icon_show, controller);
		}
		tools_window_move(controller->autohide_icon, controller->obj);
		gtk_widget_show(GTK_WIDGET(controller->autohide_icon));
	} else {
		controller_move_to(controller);
		florence_show();
	}
	END_FUNC
}

/* Called to hide the icon */
void controller_icon_hide (gpointer user_data)
{
	START_FUNC
	struct controller *controller=(struct controller *)user_data;
	if (controller->autohide_icon) {
		gtk_widget_hide(GTK_WIDGET(controller->autohide_icon));
	}
	END_FUNC
}

/* Called to show the icon */
void controller_icon_show (gpointer user_data)
{
	START_FUNC
	struct controller *controller=(struct controller *)user_data;
	if (controller->autohide_icon && controller->obj) {
		controller_show(controller);
	}
	END_FUNC
}

/* debounce focus event timeout function */
static gboolean debounced_focus_event (gpointer user_data)
{
	START_FUNC
	struct controller *controller=(struct controller *)user_data;

	if (controller->next_obj) {
		if (controller->obj) g_object_unref(controller->obj);
		controller->obj = controller->next_obj;
		g_object_ref(controller->obj);
		controller_show(controller);
	} else {
		florence_hide();
		controller_icon_hide((gpointer)controller);
		if (controller->obj) g_object_unref(controller->obj);
		controller->obj=NULL;
	}
	END_FUNC
	return FALSE;
}

/* Called when a widget is focused.
 * Check if the widget is editable and show the keyboard or hide if not. */
void controller_focus_event (const AtspiEvent *event, void *user_data)
{
	START_FUNC
	struct controller *controller=(struct controller *)user_data;
	GError *error=NULL;
	flo_debug(TRACE_DEBUG, _("ATSPI focus event received."));

	AtspiStateSet *state_set=atspi_accessible_get_state_set(event->source);
	AtspiRole role=atspi_accessible_get_role(event->source, &error);
	if (error) flo_error(_("Event error: %s"), error->message);
	flo_debug(TRACE_DEBUG, _("ATSPI focus event received. Object role=%d"), role);
	if (atspi_accessible_get_editable_text(event->source) ||
		((role==ATSPI_ROLE_TERMINAL ||
		(((role==ATSPI_ROLE_TEXT) || (role==ATSPI_ROLE_PASSWORD_TEXT)) &&
		state_set && atspi_state_set_contains(state_set, ATSPI_STATE_EDITABLE))) &&
		event->detail1))
		controller->next_obj=event->source;
	else
		controller->next_obj=NULL;
	
	if (controller->debounce_id)
		g_source_remove (controller->debounce_id);
	controller->debounce_id=g_timeout_add (controller->debounce,
		debounced_focus_event, user_data);
	END_FUNC
}

/* Registered the spi events to monitor focus and show on editable widgets. */
void controller_register_events (struct controller *controller)
{
	START_FUNC
	if (!controller->atspi_enabled) {
		flo_warn(_("SPI is disabled: Unable to switch auto-hide mode on."));
	} else {
		florence_hide();
		if (!atspi_event_listener_register_from_callback(controller_focus_event, (void*)controller, NULL, "object:state-changed:focused", NULL))
			flo_error(_("ATSPI listener register failed"));
		if (!atspi_event_listener_register_from_callback(controller_focus_event, (void*)controller, NULL, "focus:", NULL))
			flo_error(_("ATSPI listener register failed"));
	}
	END_FUNC
}

/* Deregistered the spi events. */
void controller_deregister_events (struct controller *controller)
{
	START_FUNC
	if (!atspi_event_listener_deregister_from_callback(controller_focus_event, (void*)controller, "object:state-changed:focused", NULL)) {
		flo_warn(_("AT SPI: problem deregistering focus listener"));
	}
	if (!atspi_event_listener_deregister_from_callback(controller_focus_event, (void*)controller, "focus:", NULL)) {
		flo_warn(_("AT SPI: problem deregistering window listener"));
	}
	controller_icon_hide((gpointer)controller);
	florence_show();
	controller->obj=NULL;
	END_FUNC
}

/* Triggered by gconf when the "auto_hide" parameter is changed. */
void controller_set_auto_hide(GSettings *settings, gchar *key, gpointer user_data)
{
	START_FUNC
	struct controller *controller=(struct controller *)user_data;
	controller_set_mode(controller);
	if ((!settings_get_bool(SETTINGS_AUTO_HIDE)) && (controller->autohide_icon)) {
		gtk_widget_destroy(GTK_WIDGET(controller->autohide_icon));
		controller->autohide_icon=NULL;
	}
	END_FUNC
}

#endif

/* on press event: record position and wait for release. */
void controller_icon_on_press (GtkWidget *window, GdkEventButton *event, gpointer user_data)
{
	START_FUNC
	struct controller *controller=(struct controller *)user_data;
	/* right click */
	controller->icon_moving=CONTROLLER_PRESSED;
	controller->xpos=(gint)((GdkEventMotion*)event)->x;
	controller->ypos=(gint)((GdkEventMotion*)event)->y;
	END_FUNC
}

/* on release event: show/hide the keyboard. */
void controller_icon_on_release (GtkWidget *window, GdkEventButton *event, gpointer user_data)
{
	START_FUNC
	struct controller *controller=(struct controller *)user_data;
	if (controller->icon_moving==CONTROLLER_PRESSED) {
		if (event->button==3) florence_menu(event->time);
		else florence_toggle();
	}
	controller->icon_moving=CONTROLLER_IMMOBILE;
	END_FUNC
}

/* on move event: move the icon. */
void controller_icon_on_move (GtkWidget *window, GdkEventButton *event, gpointer user_data)
{
	START_FUNC
	struct controller *controller=(struct controller *)user_data;
	gint x, y, dx, dy;
	gdk_device_get_position(gdk_device_manager_get_client_pointer(
		gdk_display_get_device_manager(gdk_display_get_default())), NULL, &x, &y);
	switch(controller->icon_moving) {
		case CONTROLLER_IMMOBILE: break;
		case CONTROLLER_PRESSED:
			dx=(gint)((GdkEventMotion*)event)->x-controller->xpos;
			dy=(gint)((GdkEventMotion*)event)->y-controller->ypos;
			if (dx > MOVING_THRESHOLD || dx < -MOVING_THRESHOLD ||
				dy > MOVING_THRESHOLD || dy < -MOVING_THRESHOLD)
				controller->icon_moving=CONTROLLER_MOVING;
			else break;
			/* no break */
		case CONTROLLER_MOVING:
			dx=x-controller->xpos;
			dy=y-controller->ypos;
			gtk_window_move(GTK_WINDOW(window), dx, dy);
			settings_set_int(SETTINGS_CONTROLLER_ICON_XPOS, dx);
			settings_set_int(SETTINGS_CONTROLLER_ICON_YPOS, dy);
			break;
		default:
			flo_warn(_("Controller: unknown moving state."));
			break;
	}
	END_FUNC
}

/* Set auto hide mode on or off. */
void controller_set_mode (struct controller *controller)
{
	START_FUNC
#ifdef ENABLE_AT_SPI2
	if (settings_get_bool(SETTINGS_AUTO_HIDE)) {
		controller_register_events(controller);
	} else {
		controller_deregister_events(controller);
	}
#endif
	END_FUNC
}

/* Activate or deactivate floating icon (depending on settings) */
void controller_float_icon (struct controller *controller)
{
	if (settings_get_bool(SETTINGS_CONTROLLER_FLOATICON)) {
		GtkWindow *icon=controller->controller_icon;
		controller_icon_create(controller, &(controller->controller_icon), 4.0);
		if (!icon) {
			g_signal_connect(G_OBJECT(controller->controller_icon), "button-press-event",
				G_CALLBACK(controller_icon_on_press), controller);
			g_signal_connect(G_OBJECT(controller->controller_icon), "button-release-event",
				G_CALLBACK(controller_icon_on_release), controller);
			g_signal_connect(G_OBJECT(controller->controller_icon), "motion-notify-event",
				G_CALLBACK(controller_icon_on_move), controller);
			g_signal_connect(G_OBJECT(controller->controller_icon), "leave-notify-event",
				G_CALLBACK(controller_icon_on_move), controller);
		}
		gtk_widget_show(GTK_WIDGET(controller->controller_icon));
		gtk_window_move(GTK_WINDOW(controller->controller_icon),
			settings_get_int(SETTINGS_CONTROLLER_ICON_XPOS),
			settings_get_int(SETTINGS_CONTROLLER_ICON_YPOS));
	} else {
		if (controller->controller_icon) gtk_widget_destroy(GTK_WIDGET(controller->controller_icon));
		controller->controller_icon=NULL;
	}
}

/* Triggered by conf when the "floaticon" parameter is changed. */
void controller_on_float_icon_change(GSettings *settings, gchar *key, gpointer user_data)
{
	START_FUNC
	struct controller *controller=(struct controller *)user_data;
	controller_float_icon(controller);
	END_FUNC
}

void controller_terminate (gpointer user_data)
{
	START_FUNC
	gtk_main_quit();
	END_FUNC
}

/* create a new instance of controller. */
struct controller *controller_new(guint debounce)
{
	START_FUNC
	GError *error=NULL;
	struct controller *controller=(struct controller *)g_malloc(sizeof(struct controller));
	if (!controller) flo_fatal(_("Unable to allocate memory for the controller"));
	memset(controller, 0, sizeof(struct controller));
	controller->debounce=debounce;

	handle=rsvg_handle_new_from_file(ICONDIR "/florence.svg", &error);
	if (error) flo_fatal(_("Error loading florence icon: %s"), error->message);

#ifdef ENABLE_AT_SPI2
	controller->atspi_enabled=TRUE;
	if (atspi_init()) {
		controller->atspi_enabled=FALSE;
		flo_warn(_("AT-SPI has been disabled at run time: auto-hide mode is disabled."));
	}
	settings_changecb_register(SETTINGS_AUTO_HIDE, controller_set_auto_hide, controller);

	if (settings_get_bool(SETTINGS_HIDE_ON_START) && (!settings_get_bool(SETTINGS_AUTO_HIDE))) {
		florence_hide();
	} else controller_set_mode(controller);
#else
	flo_warn(_("AT-SPI has been disabled at compile time: auto-hide mode is disabled."));
	if (settings_get_bool(SETTINGS_HIDE_ON_START)) {
		florence_hide();
	} else controller_set_mode(controller);
#endif
	settings_changecb_register(SETTINGS_CONTROLLER_FLOATICON, controller_on_float_icon_change, controller);
	controller_float_icon(controller);
	florence_register(FLORENCE_TERMINATE, controller_terminate, controller);

	END_FUNC
	return controller;
}

/* liberate all the memory used by the controller */
void controller_free(struct controller *controller)
{
	START_FUNC

#ifdef ENABLE_AT_SPI2
	if (controller->autohide_icon) gtk_widget_destroy(GTK_WIDGET(controller->autohide_icon));
	controller->autohide_icon=NULL;
	atspi_exit();
#endif
	if (controller->controller_icon) gtk_widget_destroy(GTK_WIDGET(controller->controller_icon));
	controller->controller_icon=NULL;

	g_free(controller);
	END_FUNC
}


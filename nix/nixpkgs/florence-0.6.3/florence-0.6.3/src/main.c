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

#include <stdio.h>
#include <sys/types.h>
#include <getopt.h>
#include <gtk/gtk.h>
#include <gst/gst.h>
#include "system.h"
#include "trace.h"
#include "settings.h"
#include "tools.h"
#include "florence.h"
#include "lib/florence.h"

#define EXIT_FAILURE 1

/* The name the program was run with, stripped of any leading path. */
char *program_name=NULL;
/* config file, if given as argument, or NULL. */
char *config_file=NULL;
/* command to execute. */
char *command=NULL;
/* command's argument. */
char *argument=NULL;
/* focus window name, if given as argument, or NULL */
char *focus=NULL;
/* debug level */
enum trace_level debug_level=TRACE_WARNING;
/* inter process communication pipe */
int pipefd[2];
/* expected signal from parent */
char expected='K';
/* child pid */
int child;
/* focus event debounce time (ms) */
guint debounce = 10;

/* florence structure */
struct florence *florence=NULL;

/* Option flags and variables */
static struct option const long_options[] =
{
	{"help", no_argument, 0, 'h'},
	{"version", no_argument, 0, 'V'},
	{"config", no_argument, 0, 'c'},
	{"debounce", required_argument, 0, 'D'},
	{"debug", optional_argument, 0, 'd'},
	{"focus", optional_argument, 0, 'f'},
	{"use-config", required_argument, 0, 'u'},
	{NULL, 0, NULL, 0}
};

static void usage (int status);
static int decode_switches (int argc, char **argv);
void exec_command();
void terminate();

void sig_handler(int signo)
{
	kill(child, SIGTERM);
	flo_terminate(florence);
}

void ready(void *unused) {
	/* Tell child we are ready. */
	write(pipefd[1], &expected, 1);
	close(pipefd[1]); 
}

int main (int argc, char **argv)
{
	int ret=EXIT_FAILURE;
	int config;
	struct controller *controller;
	char buf;

	setlocale (LC_ALL, "");
	bindtextdomain (GETTEXT_PACKAGE, FLORENCELOCALEDIR);
	bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
	textdomain (GETTEXT_PACKAGE);

	program_name=argv[0];
	config=decode_switches (argc, argv);
	if (!(config&2)&&getenv("FLO_DEBUG"))
		debug_level=trace_parse_level(getenv("FLO_DEBUG"));
	trace_init(debug_level);
	START_FUNC
	flo_info(_("Florence version %s"), VERSION);
#ifndef ENABLE_XRECORD
	flo_info(_("XRECORD has been disabled at compile time."));
#endif

	if (command) {
		gtk_init(&argc, &argv);
		exec_command();
	} else if (config&1) {
		gtk_init(&argc, &argv);
		settings_init(TRUE, config_file);
		settings();
		gtk_main();
		settings_exit();
	} else {
		if (pipe(pipefd) == -1) {
			flo_fatal(_("Pipe intanciation failed"));
		}

		if ((child=fork())) {
			close(pipefd[0]);
			gtk_init(&argc, &argv);
			settings_init(FALSE, config_file);
			gst_init(&argc, &argv);

			if (signal(SIGINT, sig_handler)==SIG_ERR)
				flo_error(_("Failed to register SIGINT signal handler."));
			if (signal(SIGTERM, sig_handler)==SIG_ERR)
				flo_error(_("Failed to register SIGTERM signal handler."));
			florence=flo_new(focus, ready);

			gtk_main();
			kill(child, SIGTERM);

			service_terminate(florence->service);
			flo_free(florence);
#ifdef ENABLE_AT_SPI2
			putenv("AT_BRIDGE_SHUTDOWN=1");
#endif
			ret=EXIT_SUCCESS;
			settings_exit();
		} else {
			close(pipefd[1]);
			/* wait for parent to be ready */
			if (read(pipefd[0], &buf, 1) > 0) {
				close(pipefd[0]);
				if (buf != expected)
					flo_fatal(_("Bad signal received from parent process."));
				if (FLORENCE_SUCCESS!=florence_init()) {
					flo_fatal(_("Florence does not seem to be running."));
				}
				if (FLORENCE_FAIL==florence_register(FLORENCE_TERMINATE, terminate, NULL)) {
					flo_fatal(_("Failed to register for terminate signal."));
				}
				gtk_init(&argc, &argv);
				settings_init(FALSE, config_file);
				controller=controller_new(debounce);
				gtk_main();
				controller_free(controller);
				settings_exit();
			} else {
				flo_fatal(_("No signal received from parent process. We assume it's dead."));
			}
			_exit(EXIT_SUCCESS);
		}
	}
	if (config_file) g_free(config_file);
	if (focus) g_free(focus);

	END_FUNC
	trace_exit();
	return ret;
}

/* Terminate the controller. */
void terminate()
{
	gtk_main_quit();
}

/* Send dbus command to existing florence process. */
void exec_command()
{
	unsigned int x, y;

	if (FLORENCE_SUCCESS!=florence_init()) {
		flo_fatal(_("Florence does not seem to be running."));
	}
	if (FLORENCE_FAIL==florence_register(FLORENCE_TERMINATE, terminate, NULL)) {
		flo_fatal(_("Failed to register for terminate signal."));
	}

	if (!strcmp(command, "show")) {
		if (argument) usage(EXIT_FAILURE);
		if (FLORENCE_SUCCESS!=florence_show()) {
			flo_fatal(_("Show command failed. Probably Florence exited."));
		}
	} else if (!strcmp(command, "hide")) {
		if (argument) usage(EXIT_FAILURE);
		if (FLORENCE_SUCCESS!=florence_hide()) {
			flo_fatal(_("Hide command failed. Probably Florence exited."));
		}
	} else if (!strcmp(command, "move")) {
		if (!argument) usage(EXIT_FAILURE);
		if (2!=sscanf(argument, "%d,%d", &x, &y)) usage(EXIT_FAILURE);
		if (FLORENCE_SUCCESS!=florence_move(x, y)) {
			flo_fatal(_("Move command failed. Probably Florence exited."));
		}
	} else usage(EXIT_FAILURE);

	if (FLORENCE_SUCCESS!=florence_exit()) {
		flo_fatal(_("libflorence failed at exit."));
	}
}

/* Set all the option flags according to the switches specified.
   Return a flag list of decoded switches.  */
static int decode_switches (int argc, char **argv)
{
	int c;
	int ret=0;
	guint d;

	while ((c = getopt_long (argc, argv, 
		"h"    /* help */
		"V"    /* version */
		"c"    /* configuration */
		"d::"  /* debug */
		"D:"   /* debounce */
		"f::"  /* restore focus */
		"t"    /* keep bringing back to front */
		"u:",  /* use config file */
		long_options, (int *) 0)) != EOF)
	{
		switch (c)
		{
			case 'V':printf ("Florence (%s) %s\n", argv[0], VERSION);
				exit (0);
				break;
			case 'h':usage (0);
			/* no break */
			case 'c':ret|=1; break;
			case 'D':d=strtoul(optarg, NULL, 0);
				if (d!=ULONG_MAX)
					debounce=d;
				else
					flo_warn("invalid debounce value ignored.");
				break;
			case 'd':ret|=2;
				if (optarg) debug_level=trace_parse_level(optarg);
				else debug_level=TRACE_DEBUG;
				break;
			case 'f':if (optarg) focus=g_strdup(optarg);
				else focus=g_strdup("");
				break;
			case 'u':config_file=g_strdup(optarg);break;
			default:usage (EXIT_FAILURE); break;
		}
	}

	if (optind < argc) command=argv[optind++];
	if (optind < argc) argument=argv[optind++];
	if (optind < argc) usage(EXIT_FAILURE);

	return ret;
}

/* Print usage message and exit */
static void usage (int status)
{
	printf (_("%s - \
Florence is a simple virtual keyboard for X.\n\n"), program_name);
	printf (_("Usage: %s [OPTION] ... [COMMAND] [ARG]\n\n"), program_name);
	printf (_("\
Options:\n\
  -h, --help                display this help and exit\n\
  -V, --version	            output version information and exit\n\
  -c, --config              open configuration window\n\
  -d, --debug [level]       print debug information to stdout\n\
  -D, --debounce time       prevent bounce with some applications\n\
  -f, --focus [window]      give the focus to the window\n\
  -u, --use-config file     use the given config file instead of dconf\n\n\
Available commands are:\n\
  show                      show the keyboard.\n\
  hide                      hide the keyboard.\n\
  move x,y                  move the keyboard at x,y position on the screen.\n\n\
Report bugs to <f.agrech@gmail.com>.\n\
More informations at <http://florence.sourceforge.net>.\n\n"));
	exit (status);
}


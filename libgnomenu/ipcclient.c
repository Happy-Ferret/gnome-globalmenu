#include <config.h>
#include <gtk/gtk.h>

#if ENABLE_TRACING >= 1
#define LOG(fmt, args...) g_message("<GnomenuGlobalMenu>::" fmt,  ## args)
#else
#define LOG(fmt, args...)
#endif
#define LOG_FUNC_NAME LOG("%s", __func__)

#include <gdk/gdkx.h>
#include "ipc.h"
#include "ipcclient.h"
#include "ipccommand.h"

static GdkWindow * client_window = NULL;
static gboolean client_frozen = TRUE;
static GList * queue = NULL;
void ipc_client_start() {
	GdkWindowAttr attr;
	attr.title = IPC_CLIENT_TITLE;
	attr.wclass = GDK_INPUT_ONLY;
	client_window = gdk_window_new(NULL, &attr, GDK_WA_TITLE);
	client_frozen = FALSE;
}
gchar * ipc_client_call_server(const gchar * command_name, gchar * para_name, ...) {
	/* dummy variables */
	Atom type_return;
	unsigned long format_return;
	unsigned long remaining_bytes;
	unsigned long nitems_return;
	gpointer data;
	/* dummy variables ends here*/
	gchar * rt;
	g_assert(client_window);
	GdkNativeWindow server = ipc_find_server();
	va_list va;
	va_start(va, para_name);
	GHashTable * parameters = ipc_parameters_va(para_name, va);
	va_end(va);
	data = ipc_command_to_string(command_name, parameters, NULL);
	g_hash_table_destroy(parameters);
	g_return_if_fail(data != NULL);
	/*build data*/
	if(!server) {
		queue = g_list_append(queue, data);
		return;
	}
	Display * display = GDK_DISPLAY_XDISPLAY(gdk_display_get_default());
	GdkEventClient ec;
	ec.type = GDK_CLIENT_EVENT;
	ec.window = server;
	ec.send_event = TRUE;
	ec.message_type = IPC_CLIENT_MESSAGE_CALL;
	ec.data_format = 8;
	*((GdkNativeWindow *)&ec.data.l[0]) = GDK_WINDOW_XWINDOW(client_window);
	gdk_error_trap_push();
	
	XChangeProperty(display,
			GDK_WINDOW_XWINDOW(client_window),
			gdk_x11_atom_to_xatom(IPC_PROPERTY_CALL),
			gdk_x11_atom_to_xatom(IPC_PROPERTY_CALL), /*type*/
			8,
			PropModeReplace,
			data,
			strlen(data) + 1);
	XSync(display, FALSE);
	g_free(data);
	if(gdk_error_trap_pop()) {
		g_warning("could not set the property for calling the command, ignoring the command");
		goto no_prop_set;
	}
	gdk_event_send_client_message(&ec, server);
	gboolean stop = FALSE;
	while(!stop) {
		gdk_error_trap_push();
		XGetWindowProperty(display,
				GDK_WINDOW_XWINDOW(client_window),
				gdk_x11_atom_to_xatom(IPC_PROPERTY_CALL),
				0,
				-1,
				FALSE,
				AnyPropertyType,
				&type_return,
				&format_return,
				&nitems_return,
				&remaining_bytes,
				&data);
		if(gdk_error_trap_pop()){
			g_warning("failure in waiting for server to delete the property, assuming done");
			stop = TRUE;
		} else {
			XFree(data);
			if(type_return == None) stop = TRUE;
		}
		//g_usleep(1000);
	}
	gdk_error_trap_push();
	XGetWindowProperty(display,
			GDK_WINDOW_XWINDOW(client_window),
			gdk_x11_atom_to_xatom(IPC_PROPERTY_RETURN),
			0,
			-1,
			FALSE,
			AnyPropertyType,
			&type_return,
			&format_return,
			&nitems_return,
			&remaining_bytes,
			&data);
	if(gdk_error_trap_pop()){
		g_warning("failure in getting the return value, assuming NULL");
	} else {
		GHashTable * results;
		if(!ipc_command_parse(data, NULL, NULL, &results)){
			g_warning("malformed return value, ignoring it");
			goto malform;
		}
		rt = g_strdup(g_hash_table_lookup(results, "default"));
		g_hash_table_destroy(results);
malform:
		XFree(data);
	}
	
no_prop_set:
	return rt;
}

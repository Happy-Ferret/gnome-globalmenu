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
#include "ipcutils.h"
#include "ipcclient.h"
#include "ipccommand.h"

static GdkWindow * client_window = NULL;
static gboolean client_frozen = TRUE;
static GdkNativeWindow server = 0;
static gboolean started = FALSE;
static IPCClientServerDestroyNotify server_destroy_notify = NULL;
static gpointer server_destroy_notify_data = NULL;
static GList * queue = NULL;
static gchar * cid = NULL; /*obtained after NEGO*/
static gboolean in_transaction = FALSE; 
static GList * transaction = NULL;

static GData * event_handler_list = NULL;
typedef struct {
	IPCClientEventHandler handler;
	gpointer data;
} EventHandlerInfo;
static void event_handler_info_free(EventHandlerInfo * info){
	g_slice_free(EventHandlerInfo, info);
}

static gpointer ipc_client_wait_for_property(GdkAtom property_name, gboolean remove);

static GdkFilterReturn server_filter(GdkXEvent * xevent, GdkEvent * event, gpointer data){
	if(((XEvent *)xevent)->type == DestroyNotify) {
		XDestroyWindowEvent * dwe = (XDestroyWindowEvent *) xevent;
		g_critical("Server is down!");
		started = FALSE;
		if(server_destroy_notify)
			server_destroy_notify(server_destroy_notify_data);
		server = 0;
	} else {
	}
	return GDK_FILTER_CONTINUE;
}
static void client_message_event(XClientMessageEvent * client_message) {
	gchar * event_data = ipc_client_wait_for_property(IPC_PROPERTY_EVENT, TRUE);
	if(!event_data) {
		g_critical("can't obtain event data");	
		return;
	}
	IPCEvent * event = ipc_event_parse(event_data);
	XFree(event_data);
	if(!event) {
		g_critical("malformed event data");
		return;
	}
	EventHandlerInfo * info = g_datalist_get_data(&event_handler_list, event->name);
	if(!info) {
		g_critical("no handlers for this event is set");
		ipc_event_free(event);
		return;
	}
	if(info->handler) 
		info->handler(event, info->data);
	ipc_event_free(event);
}
static GdkFilterReturn default_filter (GdkXEvent * xevent, GdkEvent * event, gpointer data){
	XClientMessageEvent * client_message = (XClientMessageEvent *) xevent;
	switch(((XEvent *)xevent)->type) {
		case ClientMessage:
			if(client_message->message_type == gdk_x11_atom_to_xatom(IPC_CLIENT_MESSAGE_EVENT)) {
				client_message_event(client_message);
				return GDK_FILTER_REMOVE;
			}
		return GDK_FILTER_CONTINUE;
	}
	return GDK_FILTER_CONTINUE;
}
static void ipc_client_send_client_message(GdkAtom message_type) {
	GdkEventClient ec;
	ec.type = GDK_CLIENT_EVENT;
	ec.window = 0;
	ec.send_event = TRUE;
	ec.message_type = message_type;
	ec.data_format = 8;
	*((GdkNativeWindow *)&ec.data.l[0]) = GDK_WINDOW_XWINDOW(client_window);
	gdk_event_send_client_message(&ec, server);
}
static gpointer ipc_client_wait_for_property(GdkAtom property_name, gboolean remove) {
	Display * display = GDK_DISPLAY_XDISPLAY(gdk_display_get_default());
	Atom type_return;
	unsigned long format_return;
	unsigned long remaining_bytes;
	unsigned long nitems_return;
	gpointer data = NULL;
	gint i = 0;
	while(i<100) {
		gdk_error_trap_push();
		XGetWindowProperty(display,
				GDK_WINDOW_XWINDOW(client_window),
				gdk_x11_atom_to_xatom(property_name),
				0,
				-1,
				remove,
				AnyPropertyType,
				&type_return,
				&format_return,
				&nitems_return,
				&remaining_bytes,
				&data);
		if(gdk_error_trap_pop()) {
			return NULL;
		} else {
			if(type_return != None)
				return data;
		}
		i++;
		g_usleep(i* 1000);
	}
	return data;
}
gboolean ipc_client_started(){
	return started;
}
gboolean ipc_client_start(IPCClientServerDestroyNotify notify, gpointer data){
	GdkWindow * server_gdk = NULL;
	server = ipc_find_server();
	if(server == 0) {
		gchar * server = g_getenv("GNOMENU_SERVER");
		GError * error = NULL;
		if(!g_spawn_command_line_async(server, &error)){
			g_critical("could not start the server: %s:", server);
			if(error){
				g_critical("%s", error->message);
				g_error_free(error);
			}
			goto no_server;
		} else {
			int i = 0;;
			while(server == 0 || server_gdk == NULL){
				g_usleep(1000*100);
				server = ipc_find_server();
				server_gdk = gdk_window_lookup(server);
				if(!server_gdk) server_gdk = gdk_window_foreign_new(server);
			}
		}
	}

	gdk_x11_grab_server();
	server = ipc_find_server();
	server_gdk = gdk_window_lookup(server);
	if(!server_gdk) server_gdk = gdk_window_foreign_new(server);
	g_message("GdkWindow server = %p", server_gdk);
	gdk_window_set_events(server_gdk, gdk_window_get_events(server_gdk) | GDK_STRUCTURE_MASK);
	gdk_window_add_filter(server_gdk, server_filter, NULL);
	server_destroy_notify = notify;
	server_destroy_notify_data = data;
	GdkWindowAttr attr;
	attr.title = IPC_CLIENT_TITLE;
	attr.wclass = GDK_INPUT_ONLY;
	client_window = gdk_window_new(NULL, &attr, GDK_WA_TITLE);
	gdk_window_add_filter(client_window, default_filter, NULL);
	client_frozen = FALSE;

	gdk_x11_ungrab_server();
	ipc_client_send_client_message(IPC_CLIENT_MESSAGE_NEGO);
	gchar * identify = ipc_client_wait_for_property(IPC_PROPERTY_CID, FALSE);
	if(identify) {
		cid = g_strdup(identify);
		LOG("cid obtained: %s", cid);
		XFree(identify);
		g_datalist_init(&event_handler_list);
		started = TRUE;
	} else {
		started = FALSE;
	}
no_server:
	return started;
}
static GList * ipc_client_call_list(GList * command_list) {
	GList * ret = NULL;
	g_return_val_if_fail(started, NULL);
	gchar * data = ipc_command_list_to_string(command_list);
	g_assert(client_window);

	Display * display = GDK_DISPLAY_XDISPLAY(gdk_display_get_default());
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
	ipc_client_send_client_message(IPC_CLIENT_MESSAGE_CALL);
	if(gdk_error_trap_pop()) {
		g_warning("could not set the property for calling the command, ignoring the command");
		goto no_prop_set;
	}
	data = ipc_client_wait_for_property(IPC_PROPERTY_RETURN, TRUE);
	if(!data) {
		g_warning("No return value obtained");
		goto no_return_val;
	}
	ret =ipc_command_list_parse(data);
	if(!ret){
		g_warning("malformed return value, ignoring it");
		goto malform;
	}
malform:
	XFree(data);
no_return_val:
no_prop_set:
	return ret;

}
static gchar * ipc_client_call_server_command(IPCCommand * command){
	/*The command is 'destroyed' after this function'*/
	if(!in_transaction) {
		gchar * rt = NULL;
		GList * commands = NULL;
		GList * returns = NULL;
		commands = g_list_append(commands, command);
		returns = ipc_client_call_list(commands);
		if(returns) rt = ipc_command_get_default_result(returns->data);
		ipc_command_list_free(commands);
		ipc_command_list_free(returns);
		return rt;
	} else {
		transaction = g_list_append(transaction, command);
		return NULL;
	}
}
gchar * ipc_client_call_server_valist(const gchar * command_name, gchar * para_name, va_list va) {
	IPCCommand * command = ipc_command_new(cid, command_name);
	ipc_command_set_parameters_valist(command, para_name, va);
	return ipc_client_call_server_command(command);
}
gchar * ipc_client_call_server(const gchar * command_name, gchar * para_name, ...) {
	gchar * rt = NULL;
	va_list va;
	va_start(va, para_name);
	rt = ipc_client_call_server_valist(command_name, para_name, va);
	va_end(va);
	return rt;
}
gchar * ipc_client_call_server_array(const gchar * command_name, gchar ** paras, gchar ** values){
	IPCCommand * command = ipc_command_new(cid, command_name);
	ipc_command_set_parameters_array(command, paras, values);
	return ipc_client_call_server_command(command);
}
void ipc_client_begin_transaction() {
	transaction = NULL;
	in_transaction = TRUE;
}
void ipc_client_cancel_transaction() {
	ipc_command_list_free(transaction);
	in_transaction = FALSE;
	transaction = NULL;
}
void ipc_client_end_transaction(GList ** return_list){
	GList * rt = ipc_client_call_list(transaction);
	if(return_list) *return_list = rt;
	else ipc_command_list_free(rt);
	ipc_command_list_free(transaction);
	transaction = NULL;
	in_transaction = FALSE;
}
void ipc_client_set_event(gchar * event, IPCClientEventHandler handler, gpointer data){
	EventHandlerInfo * info = g_slice_new0(EventHandlerInfo);
	info->data = data;
	info->handler = handler;
	g_datalist_set_data_full(&event_handler_list, event, info, event_handler_info_free);
	ipc_client_call_server("_AddEvent_", "event", event);
}
void ipc_client_remove_event(gchar * event){
	g_datalist_remove_data(&event_handler_list, event);
	ipc_client_call_server("_RemoveEvent_", "event", event);
}

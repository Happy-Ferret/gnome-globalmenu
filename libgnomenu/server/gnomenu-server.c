#include <config.h>
#include <gtk/gtk.h>

#if ENABLE_TRACING >= 1
#define LOG(fmt, args...) g_message("<GnomenuServer>::" fmt,  ## args)
#else
#define LOG(fmt, args...)
#endif

#include "ipcserver.h"

typedef struct {
	gchar * cid;
} ClientInfo;
static GHashTable * client_hash = NULL;
void client_info_free(ClientInfo * info) {
	g_free(info->cid);
	g_slice_free(ClientInfo, info);
}
static void client_create_callback(gchar * cid, gpointer data) {
	LOG("New client %s", cid);
	ClientInfo * info = g_slice_new0(ClientInfo);
	info->cid = g_strdup(cid);
	g_hash_table_insert(client_hash, info->cid, info);
}
static void client_destroy_callback(gchar * cid, gpointer data) {
	LOG("Dead client %s", cid);
	g_hash_table_remove(client_hash, cid);
}
gboolean Unimplemented(IPCCommand * command, gpointer data) {
	IPCRet(command, g_strdup("This method is Unimplemented"));
	return TRUE;
}
int main(int argc, char* argv[]){
	gtk_init(&argc, &argv);

	client_hash = g_hash_table_new_full(g_str_hash, g_str_equal, NULL, client_info_free);
	ipc_server_register_cmd("CreateObject", Unimplemented, NULL);
	ipc_server_register_cmd("DestroyObject", Unimplemented, NULL);
	ipc_server_register_cmd("SetProperty", Unimplemented, NULL);
	ipc_server_register_cmd("ActivateObject", Unimplemented, NULL);
	ipc_server_register_cmd("InsertChild", Unimplemented, NULL);
	ipc_server_register_cmd("RemoveChild", Unimplemented, NULL);
	if(!ipc_server_listen(client_create_callback, client_destroy_callback, NULL)) {
		g_error("server already there");
		return 1;
	}
	gtk_main();
	return 0;
}

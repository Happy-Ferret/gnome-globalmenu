#ifndef _IPC_COMMAND_H_
#define _IPC_COMMAND_H_
typedef struct {
	gchar * name;
	gchar * cid;
	GHashTable * parameters;
	GHashTable * results;
} IPCCommand;
IPCCommand * ipc_command_parse(const gchar * string);
GList * ipc_command_list_parse(const gchar * string);

gchar * ipc_command_to_string(IPCCommand * command);
gchar * ipc_command_list_to_string(GList * command_list);
#define IPCParam(c, p) \
	g_hash_table_lookup(((IPCCommand*)(c))->parameters, (p))
#define IPCRet(c, rt) \
	g_hash_table_insert(((IPCCommand*)(c))->results, g_strdup("default"), (rt))

void ipc_command_free(IPCCommand * command);
void ipc_command_list_free(GList * list);
IPCCommand * ipc_command_new(gchar * cid, gchar * name);
void ipc_command_set_parameters(IPCCommand * command, gchar * para_name, ...);
void ipc_command_set_results(IPCCommand * command, gchar * result_name, ...);

void ipc_command_set_parameters_valist(IPCCommand * command, gchar * para_name, va_list va);
void ipc_command_set_parameters_array(IPCCommand * command, gchar ** paras, gchar ** values);
void ipc_command_set_results_valist(IPCCommand * command, gchar * para_name, va_list va);
gchar * ipc_command_get_default_result(IPCCommand * command);
#endif

#include <gtk/gtk.h>
#include <libgnomenu/ipcclient.h>
#include <glade/glade.h>
void server_destroy(gpointer data) {
	g_message("server destroy was caught");
}
int main(int argc, char* argv[]){
	GtkWindow * window;
	GtkBox * box;
	GTimer * timer;
	int i;
	gtk_init(&argc, &argv);

	timer = g_timer_new();
	if(!ipc_client_start(server_destroy, NULL)) {
		g_message("no server there");
		return 1;
	}

		g_timer_start(timer);
	//ipc_client_begin_transaction();
	for(i=100; i>0; i--) {
		gchar * msg = g_strdup_printf("hello %d", i);
		gchar * rt = ipc_client_call_server("Ping", "message", msg, NULL);
		if(rt) { 
			g_message("%s", rt);
			g_free(rt);
		}
		g_free(msg);
	}
	GList * returns;
	//ipc_client_end_transaction(&returns);
	g_message("time consumed: %lf", (double) g_timer_elapsed(timer, NULL));
	gtk_main();
	return 0;
}

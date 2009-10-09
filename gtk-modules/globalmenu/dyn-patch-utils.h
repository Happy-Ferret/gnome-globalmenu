#ifndef __DYN_PATCH_UTILS
#define __DYN_PATCH_UTILS

#include <gtk/gtk.h>

typedef enum {
	DISCOVER_MODE_INIT,
	DISCOVER_MODE_UNINIT_VFUNCS,
	DISCOVER_MODE_UNINIT_FINAL
} DiscoverMode;

void dyn_patch_attach_menubar(GtkWindow * window, GtkMenuBar * menubar);
void dyn_patch_detach_menubar(GtkWindow * window, GtkMenuBar * menubar);

void dyn_patch_queue_changed(GtkMenuBar * menubar, GtkWidget * widget);
void dyn_patch_set_menubar_r(GtkWidget * head, GtkMenuBar * menubar);
GtkWindow * dyn_patch_get_window(GtkMenuBar * menubar);
GtkMenuBar * dyn_patch_get_menubar(GtkWidget * widget);
void dyn_patch_discover_menubars(DiscoverMode mode);
void dyn_patch_set_is_local(GtkMenuBar * menubar, gboolean is_local);
gboolean dyn_patch_get_is_local(GtkMenuBar * menubar);
#endif /* __DYN_PATCH_UTILS */

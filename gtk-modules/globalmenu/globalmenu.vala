using Gtk;
using GtkAQD;

namespace GnomenuGtk {
	[CCode (cname = "dyn_patch_menu_bar")]
	protected extern  void patch_menu_bar();
	[CCode (cname = "dyn_patch_widget")]
	protected extern  void patch_widget();
	[CCode (cname = "gdk_window_get_desktop_hint")]
	protected extern bool gdk_window_get_is_desktop (Gdk.Window window);
	[CCode (cname = "gdk_window_set_menu_context")]
	protected extern void gdk_window_set_menu_context (Gdk.Window window, string context);

	private bool _menubar_changed_eh (SignalInvocationHint ihint, [CCode (array_length_pos = 1.9)] Value[] param_values) {
		Gtk.MenuBar self = param_values[0].get_object() as Gtk.MenuBar;
		if(self != null) {
			if(ihint.run_type != SignalFlags.RUN_FIRST) return true;
			Gtk.Window toplevel = self.get_ancestor(typeof(Gtk.Window)) as Gtk.Window;
			if(toplevel != null && (0 != (toplevel.get_flags() & WidgetFlags.REALIZED))) {
				gdk_window_set_menu_context(toplevel.window, """<menu><item id="hello" label="world"/></menu>""");
			}
		} 
		return true;
	}
	protected bool verbose = false;
	protected bool disabled = false;
	protected GLib.OutputStream log_stream;
	protected string application_name;
	private void default_log_handler(string? domain, LogLevelFlags level, string message) {
		TimeVal time;
		time.get_current_time();
		string s = "%.10ld | %20s | %10s | %s\n".printf(time.tv_usec, application_name, domain, message);
		log_stream.write(s, s.size(), null);
	}
	private void init_log() {
		string log_file_name = Environment.get_variable("GNOMENU_LOG_FILE");
		if(log_file_name != null) {
			try {
				GLib.File file = GLib.File.new_for_path(log_file_name);
				log_stream = file.append_to(FileCreateFlags.NONE, null);
			} catch (GLib.Error e) {
				warning("Log file %s is not accessible. Fallback to stderr: %s", log_file_name, e.message);
			}	
		}
		if(log_stream == null) log_stream = new GLib.UnixOutputStream(2, false);
		Log.set_handler ("GlobalMenuModule", LogLevelFlags.LEVEL_MASK, default_log_handler);
	}
	[CCode (cname="gtk_module_init")]
	public void init([CCode (array_length_pos = 0.9)] ref weak string[] args) {
		string disabled_application_names = Environment.get_variable("GTK_MENUBAR_NO_MAC");
		disabled = (Environment.get_variable("GNOMENU_DISABLED")!=null);
		verbose = (Environment.get_variable("GNOMENU_VERBOSE")!=null);
		application_name = Environment.get_prgname();
	
		init_log();

		if(disabled) {
			message("GTK_MENUBAR_NO_MAC or GNOMENU_DISABLED is set. GlobalMenu is disabled");
			return;
		}
		if(!verbose) {
			LogFunc handler = (domain, level, message) => { };
			/*TODO: disable verbose output*/
		}

		switch(Environment.get_prgname()) {
			case "gnome-panel":
			case "GlobalMenu.PanelApplet":
			case "gdm-user-switch-applet":
			message("GlobalMenu is disabled for several programs");
			return;
			break;
			default:
				if((disabled_application_names!=null) 
					&& disabled_application_names.str(application_name)!=null){
					message("GlobalMenu is disabled in GTK_MENUBAR_NO_MAC list");
					return;
				}
			break;
		}
		patch_widget();
		patch_menu_bar();
		uint signal_id = Signal.lookup("changed", typeof(Gtk.MenuBar));
		Signal.add_emission_hook (signal_id, 0, _menubar_changed_eh, null);
		debug("GlobalMenu is enabled");
		Log.set_handler ("GMarkup", LogLevelFlags.LEVEL_MASK, default_log_handler);
		Log.set_handler ("Gnomenu", LogLevelFlags.LEVEL_MASK, default_log_handler);
	}
}

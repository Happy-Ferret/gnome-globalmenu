public class Gnomenu.GlobalMenu : Gnomenu.MenuBar {
	[CCode (notify = true)]
	public Gnomenu.Window current_window {get; private set;}

	private Gnomenu.Window _root_window;
	private Gnomenu.Monitor active_window_monitor;

	construct {
		active_window_monitor = new Gnomenu.Monitor(this);
		active_window_monitor.active_window_changed += (mon, prev) => {
			debug("current window changed to %p", current_window);
			current_window = active_window_monitor.active_window;
			if(prev != null) {
				prev.menu_context_changed -= menu_context_changed;
			}
			current_window.menu_context_changed += menu_context_changed;
			update();
		};
		activate += (menubar, item) => {
			if(current_window != null) {
				current_window.emit_menu_event(item.item_path);
			}
		};
		select += (menubar, item) => {
			if(current_window != null) {
				current_window.emit_menu_select(item.item_path, null);
			}
		};
		deselect += (menubar, item) => {
			if(current_window != null) {
				current_window.emit_menu_deselect(item.item_path);
			}
		};
	}
	private HashTable<uint, Gtk.Widget> keys = new HashTable<uint, Gtk.Widget>(direct_hash, direct_equal);

	private void menu_context_changed(Gnomenu.Window window) {
		/*
		 * If window is not current window, 
		 * some where around the signal handler connection is wrong
		 * */
		assert(window == current_window);
		debug("menu_context_changed on %p", window);
		update();
	}

	private void grab_mnemonic_keys() {
		Gdk.ModifierType mods = Gdk.ModifierType.MOD1_MASK;
		foreach(Gtk.Widget widget in get_children()) {
			Gnomenu.MenuItem item = widget as Gnomenu.MenuItem;
			if(item == null) continue;
			Gnomenu.MenuLabel label = item.get_child() as Gnomenu.MenuLabel;
			if(label == null) continue;
			uint keyval = label.mnemonic_keyval;
			debug("grabbing key for %s:%u", label.label, keyval);
			if(current_window != null)
				current_window.grab_key(keyval, mods);
			keys.insert(keyval, widget);
		}
	}

	private void ungrab_mnemonic_keys() {
		Gdk.ModifierType mods = Gdk.ModifierType.MOD1_MASK;
		foreach(uint keyval in keys.get_keys()) {
			debug("ungrabbing %u", keyval);
			if(current_window != null)
				current_window.ungrab_key(keyval, mods);
		}
		keys.remove_all();
	}

	private void regrab_menu_bar_key() {
		debug("regrab menu_bar key");
		ungrab_menu_bar_key();	
		grab_menu_bar_key();	
	}
	private void attach_to_screen(Gdk.Screen screen) {
		_root_window = new Window(get_root_window());
		_root_window.set_key_widget(this.get_toplevel());
		grab_menu_bar_key();
		grab_mnemonic_keys();
		var settings = get_settings();
		settings.notify["gtk-menu-bar-accel"] += regrab_menu_bar_key;
			
	}
	private void detach_from_screen(Gdk.Screen screen) {
		if(_root_window != null) {
			_root_window.set_key_widget(null);
			ungrab_menu_bar_key();
			ungrab_mnemonic_keys();
		}
		var settings = get_settings();
		settings.notify["gtk-menu-bar-accel"] -= regrab_menu_bar_key;
		_root_window = null;
	}
	private void chainup_key_changed(Gtk.Window window) {
		GLib.Type type = typeof(Gtk.Window);
		var window_class = (Gtk.WindowClass) type.class_ref();
		debug("chainup to Gtk.Window keys changed");
		window_class.keys_changed(window);
	}
	public override void hierarchy_changed(Gtk.Widget? old_toplevel) {
		var toplevel = this.get_toplevel() as Gtk.Plug;
		/* Manually chain-up to the default keys_changed handler,
		 * Working around a problem with GtkPlug/GtkSocket */
		if(toplevel != null) {
			toplevel.keys_changed += chainup_key_changed;
		}
		if((old_toplevel as Gtk.Plug)!= null) {
			(old_toplevel as Gtk.Plug).keys_changed -= chainup_key_changed;
		}
	}
	public override void screen_changed(Gdk.Screen? previous_screen) {
		Gdk.Screen screen = get_screen();
		if(previous_screen != screen) {
			if(previous_screen != null) detach_from_screen(previous_screen);
			if(screen != null) attach_to_screen(screen);
		}
	}

	private void update() {
		ungrab_mnemonic_keys();
		if(current_window != null) {
			
			current_window.set_key_widget(this.get_toplevel());
			var context = current_window.get_menu_context();
			if(context != null) {
				try {
					Parser.parse(this, context);
				} catch(GLib.Error e) {
					warning("%s", e.message);	
				}
				show();
				grab_mnemonic_keys();
				return;
			}
		}
		hide();
	}
	private void ungrab_menu_bar_key() {
		int keyval = (int) _root_window.get_data("menu-bar-keyval");
		Gdk.ModifierType mods = 
			(Gdk.ModifierType) _root_window.get_data("menu-bar-keymods");

		_root_window.ungrab_key(keyval, mods);
		_root_window.set_data("menu-bar-keyval", null);
		_root_window.set_data("menu-bar-keymods", null);
	}
	private void grab_menu_bar_key() {
		/*FIXME: listen to changes in GTK_SETTINGS.*/
		uint keyval;
		Gdk.ModifierType mods;
		get_accel_key(out keyval, out mods);
		_root_window.grab_key(keyval, mods);
		_root_window.set_data("menu-bar-keyval", (void*) keyval);
		_root_window.set_data("menu-bar-keymods", (void*) mods);
	}	
	/**
	 * return the accelerator key combination for invoking menu bars
	 * in GTK Settings. It is usually F10.
	 */
	private void get_accel_key(out uint keyval, out Gdk.ModifierType mods) {
		Gtk.Settings settings = get_settings();
		string accel = null;
		settings.get("gtk_menu_bar_accel", &accel, null);
		if(accel != null)
			Gtk.accelerator_parse(accel, out keyval, out mods);
	}
}

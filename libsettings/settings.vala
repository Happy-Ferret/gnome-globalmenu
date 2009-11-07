public class Gnomenu.Settings : Object {
	private Gdk.Screen screen;
	private Gdk.Window window;

	private Gdk.Atom atom = Gdk.Atom.intern("_NET_GLOBALMENU_SETTINGS", false);

	public KeyFile keyfile = new KeyFile();

	public bool show_local_menu { get; set; default = true; }
	public bool use_global_menu { get; set; default = true; }
	
	public Settings(Gdk.Screen screen) {
		this.screen = screen;
		this.window = screen.get_root_window();
		assert(window != null);
		window.add_filter(this.event_filter);
		var events = window.get_events();
		window.set_events(events | Gdk.EventMask.PROPERTY_CHANGE_MASK);
		pull();
	}
	~Settings() {
		window.remove_filter(this.event_filter);
	}

	[CCode (instance_pos = -1)]
	private Gdk.FilterReturn event_filter(Gdk.XEvent xevent, Gdk.Event event) {
		/* This weird extra level of calling is to avoid a type cast in Vala
		 * which will cause the loss of delegate target. */
		return real_event_filter(&xevent, event);
	}
	[CCode (instance_pos = -1)]
	private Gdk.FilterReturn real_event_filter(X.Event* xevent, Gdk.Event event) {
		switch(xevent->type) {
			case X.EventType.PropertyNotify:
			if(atom == Gdk.x11_xatom_to_atom(xevent->xproperty.atom)) {
				pull();
			}
			break;
		}
		return Gdk.FilterReturn.CONTINUE;
	}

	public string to_string() {
		keyfile.set_boolean("GlobalMenu:Client", "show-local-menu", this.show_local_menu);
		keyfile.set_boolean("GlobalMenu:Client", "use-global-menu", this.use_global_menu);
		return keyfile.to_data(null);
	}

	public void pull() {
		var data = get_by_atom(atom);
		if(data == null) return;
		keyfile.load_from_data(data, data.length, KeyFileFlags.NONE);
		this.show_local_menu = keyfile.get_boolean("GlobalMenu:Client", "show-local-menu");
		this.use_global_menu = keyfile.get_boolean("GlobalMenu:Client", "use-global-menu");
	}

	public void push() {
		var str = this.to_string();
		set_by_atom(atom, str);
	}

	public string? get_by_atom(Gdk.Atom atom) {
		string context = null;
		Gdk.Atom actual_type;
		Gdk.Atom type = Gdk.Atom.intern("STRING", false);
		int actual_format;
		int actual_length;
		Gdk.property_get(window,
			atom,
			type,
			0, (ulong) long.MAX, false, 
			out actual_type, 
			out actual_format, 
			out actual_length, 
			out context);
		return context;
	}

	public void set_by_atom(Gdk.Atom atom, string? value) {
		if(value != null) {
			Gdk.Atom type = Gdk.Atom.intern("STRING", false);
			Gdk.property_change(window,
				atom, type,
				8,
				Gdk.PropMode.REPLACE,
				value, 
				(int) value.size() + 1
			);
		} else {
			Gdk.property_delete(window, atom);
		}
	}
}

}

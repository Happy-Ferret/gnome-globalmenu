using GLib;
using Gtk;
using Gnomenu;
using Wnck;
using Panel;

public class Applet : Panel.Applet {
	public static const string IID = "OAFIID:GlobalMenu_PanelApplet";
	public static int instance_count = 0;
	static const string SELECTOR = 
"""
<menu>
	<item label="%s" font="bold">
		<menu>
			<item label="Notepad"/>
			<item label="Terminal"/>
		</menu>
	</item>
</menu>
""";
	static const string MAIN_MENUBAR =
"""
<menu>
	<item label="Default Menu" font="bold"/>
</menu>
""";
	static const string OVERFLOWER_TEMPLATE =
"""
<menu>
	<item type="a" id="_arrow_">
	%s
	</item>
</menu>
""";

	public PackDirection pack_direction {
		get {
			return _pack_direction;
		}
		set {
			foreach(Gnomenu.MenuBar menubar in internal_children) {
				menubar.pack_direction = value;
				menubar.child_pack_direction = value;
			}
			_pack_direction = value;
			queue_resize();
		}
	}
	public Gnomenu.Gravity gravity {
		get {
			return _gravity;
		}
		set {
			_gravity = value;
			foreach(Gnomenu.MenuBar menubar in internal_children) {
				menubar.gravity = value;
			}
			queue_draw();
		}
	}
	public Applet() {
		int i = 0;
	}
	~Applet() {
		instance_count--;
	}
	construct {
		instance_count++;
		this.set_name("GlobalMenuPanelApplet");
		this.add_events(Gdk.EventMask.KEY_PRESS_MASK);
		selector = add_menubar_from_string(SELECTOR.printf("NONE"));
		main_menubar = add_menubar_from_string(MAIN_MENUBAR);
		main_menubar.activate += (menubar, item) => {
			if(current_window != null) {
				current_window.emit_menu_event(item.path);
			}
		};
		overflower = add_menubar_from_string(OVERFLOWER_TEMPLATE.printf("<menu/>"));
		overflower.activate += (menubar, item) => {
			if(current_window == null) return;
			string path = item.path;
			if(item.id == "_arrow_") {
				string overflown_menu = main_menubar.create_overflown_menu();
				if(overflown_menu == null) {
					overflown_menu = "<menu/>";
				}
				string overflower_context = OVERFLOWER_TEMPLATE.printf(overflown_menu);
				Parser.parse(overflower, overflower_context);
				return;
			}
			int slashes = 0;
			StringBuilder sb = new StringBuilder("");
			/***
			 * path = "00001234:/0/1/234/512";
			 * sb =   "00001234:  /1/234/512";
			 */
			bool skip = false;
			for(int i = 0; i < path.length; i++) {
				if( path[i] == '/') {
					slashes ++;
				}
				if(slashes != 1) 
					sb.append_unichar(path[i]);
			}
			if(slashes > 1) {
				current_window.emit_menu_event(sb.str);
			}
		};
		/*init wnck*/
		screen = Wnck.Screen.get_default();
		screen.active_window_changed += (screen, previous_window) => {
			weak Wnck.Window window = screen.get_active_window();
			if((window != previous_window) && (window is Wnck.Window)) {
				weak Wnck.Window transient_for = window.get_transient();
				if(transient_for != null) window = transient_for;
				Parser.parse(selector, SELECTOR.printf(window.get_xid().to_string()));
				if(current_window != null) {
					/* This is a weird way to free a window:
					 * We have two reference counts for current_window
					 * Destroy will release the one held by GTK,
					 * and the assignment line below will release the one
					 * held by us.
					 * */
					current_window.destroy();
					assert(current_window.ref_count == 1);
				}
				current_window = new Gnomenu.Window.foreign(window.get_xid());

				if(current_window.invalid) {
					current_window.destroy();
					current_window = null; 
					/*TODO: switch to default_window, and continue rather than return*/
				}
				if(current_window != null) {
					current_window.menu_context_changed += (current_window) => {
						update_menubar();
					};
				}
				update_menubar();
			}
		};

		/*init panel*/
		this.flags = (Panel.AppletFlags.EXPAND_MINOR | Panel.AppletFlags.HAS_HANDLE | Panel.AppletFlags.EXPAND_MAJOR );
		set_background_widget(this);

	/* Key grab F10 (gtk-menu-bar-key)*/
		
		root_window = new Gnomenu.Window.from_gdk_window(Gdk.get_default_root_window());
		int keyval;
		Gdk.ModifierType mods;
		main_menubar.get_accel_key(out keyval, out mods);
		root_window.grab_key(keyval, mods);
		root_window.key_press_event += (root_window, event) => {
			uint keyval;
			Gdk.ModifierType mods;
			main_menubar.get_accel_key(out keyval, out mods);
			if(event.keyval == keyval &&
				(event.state & Gtk.accelerator_get_default_mod_mask())
				== (mods & Gtk.accelerator_get_default_mod_mask())) {
				selector.select_first(true);
				this.key_press_event(event);
			return false;
			}
			return true;
		};
	}

	private Wnck.Screen screen;
	private Gnomenu.Window current_window;
	private Gnomenu.MenuBar main_menubar;
	private Gnomenu.MenuBar overflower;
	private Gnomenu.MenuBar selector;
	private Gnomenu.Window root_window;

	private Label label; /*Replace with the selector later*/

	private PackDirection _pack_direction;
	private Gnomenu.Gravity _gravity;

	private List<weak Gnomenu.MenuBar> internal_children;

	private void update_menubar() {
		if(current_window != null) {
			string context = current_window.menu_context;
			if(context != null) {
				Parser.parse(main_menubar, context);
				main_menubar.show();
				return;
			}
		}
		/* elseever */
		main_menubar.hide();
	}
	private override void change_background(AppletBackgroundType type, Gdk.Color? color, Gdk.Pixmap? pixmap) {
		Background bg = new Background();
		switch(type){
			case Panel.AppletBackgroundType.NO_BACKGROUND:
				bg.type = BackgroundType.NONE;
			break;
			case Panel.AppletBackgroundType.COLOR_BACKGROUND:
				bg.type = BackgroundType.COLOR;
				bg.color = color;
			break;
			case Panel.AppletBackgroundType.PIXMAP_BACKGROUND:
				bg.type = BackgroundType.PIXMAP;
				bg.pixmap = pixmap;
			break;
		}
		foreach(Gnomenu.MenuBar menubar in internal_children) {
			bg.offset_x = menubar.allocation.x - allocation.x;
			bg.offset_y = menubar.allocation.y - allocation.y;
			menubar.background = bg;
		}
	}
	private override void change_orient(AppletOrient orient) {
		switch(orient) {
			case AppletOrient.UP:
				gravity = Gravity.DOWN;
				pack_direction = PackDirection.LTR;
			break;
			case AppletOrient.DOWN:
				gravity = Gravity.DOWN;
				pack_direction = PackDirection.LTR;
			break;
			case AppletOrient.LEFT:
				gravity = Gravity.LEFT;
				pack_direction = PackDirection.TTB;
			break;
			case AppletOrient.RIGHT:
				gravity = Gravity.RIGHT;
				pack_direction = PackDirection.BTT;
			break;
		}
	}
	private override void forall(Gtk.Callback cb, void* data) {
		bool include_internal;

		if(include_internal) {
			foreach(Gnomenu.MenuBar menubar in internal_children) {
				cb(menubar);
			}
		}
		base.forall(cb, data);
	}
	private override void size_request(out Requisition r) {
		r.width = 0;
		r.height = 0;
		Requisition cr;
		switch(pack_direction) {
			case PackDirection.LTR:
			case PackDirection.RTL:
				foreach(Gnomenu.MenuBar menubar in internal_children) {
					menubar.size_request(out cr);
					if(menubar != main_menubar) {
						r.width += cr.width;
					}
					r.height = r.height>cr.height?r.height:cr.height;
				}
			break;
			case PackDirection.BTT:
			case PackDirection.TTB:
				foreach(Gnomenu.MenuBar menubar in internal_children) {
					menubar.size_request(out cr);
					if(menubar != main_menubar) {
						r.height += cr.height;
					}
					r.width = r.width>cr.width?r.width:cr.width;
				}
			break;
		}
	}
	private override void map() {
		base.map();
		foreach(Gnomenu.MenuBar menubar in internal_children) {
			if(menubar.visible) {
				menubar.map();
			}
		}
	}
	private override void size_allocate(Gdk.Rectangle a) {
		allocation = (Allocation) a;
		Requisition cr;
		Allocation ca;
		int x;
		int y;
		int rev_x;
		int rev_y;
		x = 0;
		y = 0;
		rev_x = a.width;
		rev_y = a.height;

		foreach(Gnomenu.MenuBar menubar in internal_children) {
			menubar.get_child_requisition(out cr);
			switch(pack_direction) {
				case PackDirection.LTR:
					if(menubar == main_menubar) {
						ca.width = a.width - requisition.width;
					} else {
						ca.width = cr.width;
					}
					ca.height = a.height;
					ca.x = x;
					ca.y = y;
					x += ca.width;
				break;
				case PackDirection.RTL:
					if(menubar == main_menubar) {
						ca.width = a.width - requisition.width;
					} else {
						ca.width = cr.width;
					}
					ca.x = rev_x - ca.width;
					ca.y = y;
					ca.height = a.height;
					rev_x -= ca.width;
					x += ca.width;
				break;
				case PackDirection.BTT:
					ca.width = a.width;
					if(menubar == main_menubar) {
						ca.height = a.height - requisition.height;
					} else {
						ca.height = cr.height;
					}
					ca.x = x;
					ca.y = rev_y - ca.height;
					rev_y -= ca.height;
					y += ca.height;
				break;
				case PackDirection.TTB:
					ca.width = a.width;
					if(menubar == main_menubar) {
						ca.height = a.height - requisition.height;
					} else {
						ca.height = cr.height;
					}
					ca.x = x;
					ca.y = y;
					y += ca.height;
				break;
			}
			menubar.size_allocate((Gdk.Rectangle)ca);
		}
		if(main_menubar.overflown) {
			overflower.visible = true;
		} else {
			overflower.visible = false;
		}
		base.size_allocate(a);
	}
	private Gnomenu.MenuBar add_menubar_from_string(string str) {
		Gnomenu.MenuBar menubar = new Gnomenu.MenuBar();
		menubar.visible = true;
		menubar.set_name("PanelMenuBar");
		menubar.set_parent(this);

		Parser.parse(menubar, str);
		internal_children.append(menubar);
		return menubar;
	}
	/* This variable is then removed by patch.sh */

}



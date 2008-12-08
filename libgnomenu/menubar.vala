using Gtk;

namespace Gnomenu {
	/**
	 *
	 * 	This structure is used to represent a 'background' passed from
	 * 	the panel library.
	 * 	
	 */
	public class Background {
		public BackgroundType type;
		public Gdk.Pixmap pixmap;
		public Gdk.Color color;
		/**
		 * the offset in x direction for clipping
		 * the pixmap background
		 */
		public int offset_x;
		/**
		 * the offset in y direction for clipping
		 * the pixmap background
		 */
		public int offset_y;
		/**
		 * @return a new backround which is identical to this one.
		 */
		public Background clone() {
			Background rt = new Background();
			rt.type = type;
			rt.pixmap = pixmap;
			rt.color = color;
			rt.offset_x = offset_x;
			rt.offset_y = offset_y;
			return rt;
		}
	}

	/**
	 * A fancy menubar used by GlobalMenu.PanelApplet;
	 * Not the same as Gtk.MenuBar, Gnomenu.MenuBar also
	 * explicityly acts as the toplevel menubar of
	 * its logical descents.
	 *
	 * It supports changing the background,
	 * getting an xml representation of the overflown items,
	 * changing the text gravity,
	 * looking up item (and subitems) by path.
	 */
	public class MenuBar : Gtk.MenuBar {
		public MenuBar() {}
		const uint PROP_IMPORTANT = 1;
		static construct {
			/*FIXME: this is not awared yet
			  override set_child_property
			  get_child_property,
			  gonna be messy
			install_child_property (
					PROP_IMPORTANT,
					new ParamSpecBoolean("important", 
						"Imporant",
						"Whether this item should not be overflown if possible",
						false,
						ParamFlags.READABLE | ParamFlags.WRITABLE)
					);
			*/
		
		}
		construct {
			_background = new Background();
		}
		/**
		 * This signal is emitted when a child item is activated
		 */
		public signal void activate(MenuItem item);

		/**
		 * To change the background of the menubar,
		 * set this property.
		 *
		 * Notice that this property doesn't increase
		 * the reference of the passed background object.
		 * rather, it sets up the menubar background
		 * according the passed value.
		 *
		 * therefore this property is a bad property.
		 * It should actually be replace by
		 * set_background and get_background.
		 */
		public Background background {
			get {
				return _background;
			}
			set {
				BackgroundType old_type = _background.type;
				Gdk.Color old_color = _background.color;
				_background.type = value.type;
				_background.pixmap = value.pixmap;
				_background.color = value.color;
				_background.offset_x = value.offset_x;
				_background.offset_y = value.offset_y;
				switch(_background.type) {
					case BackgroundType.NONE:
						if(old_type != _background.type) {
							style = null;
							RcStyle rc_style = new RcStyle();
							modify_style(rc_style);
						}
					break;
					case BackgroundType.COLOR:
						if(old_type != _background.type
						|| (old_type == _background.type
						&& old_color.to_string() !=
							_background.color.to_string())) {
							modify_bg(StateType.NORMAL, _background.color);
						}
					break;
					case BackgroundType.PIXMAP:
						reset_bg_pixmap();
					break;
				}
			}
		}
		/**
		 * The text gravity of the menubar.
		 * It also affects the text gravity of
		 * the menu items in this menubar.
		 */
		public Gravity gravity {
			get { return _gravity; }
			set {
				_gravity = value;
				foreach(weak Widget child in get_children()) {
					(child as MenuItem).gravity = value;
				}
			}
		}
		/**
		 * return true if the menubar has overflown items.
		 */
		public bool overflown {
			get { 
				switch(pack_direction) {
					case PackDirection.TTB:
					case PackDirection.BTT:
						return allocation.height< requisition.height;
					case PackDirection.LTR:
					case PackDirection.RTL:
					default:
						return allocation.width < requisition.width;
				}
			}
		}
		/**
		 * Look up a child item from a path.
		 * The path is a string constructed by two parts:
		 *
		 * [rev:]/id/id/id
		 *
		 * where rev: is an integer stamp, and id can be either
		 * the id property or the position of the menu item.
		 *
		 * return a strong reference of the menu item if found;
		 * null if not.
		 */
		public MenuItem? get(string path) {
			string[] tokens = path.split_set("/", -1);
			tokens.length = (int) strv_length(tokens);
			MenuShell shell = this;
			weak string rev = tokens[0];
			/*FIXME: check rev */
			for(int i = 1; i < tokens.length; i++) {
				weak string token = tokens[i];
				weak List<weak Widget> children = shell.get_children();
				MenuItem item;
				foreach(weak Widget child in children) {
					MenuItem child_item = child as MenuItem;
					if(child_item != null) {
						if(child_item.id == token
						|| (child_item.id == null && 
							child_item.position.to_string() == token)) {
							item = child_item;
							break;
						}
					}
				}
				if(i == tokens.length - 1 /*last token, maybe found*/) return item;	
				if(item == null /*intermediate item is not found*/) return null; 
				shell = item.submenu;
				if(shell == null /*intermediate menu is not found*/) return null;
			}
			return null;
		}

		/**
		 * return the accelerator key combination for invoking menu bars
		 * in GTK Settings. It is usually F10.
		 */
		public void get_accel_key(out uint keyval, out Gdk.ModifierType mods) {
			Settings settings = get_settings();
			weak string accel;
		   	settings.get( "gtk_menu_bar_accel", &accel, null);
			message("accel = %s", accel);
			if(accel != null)
				Gtk.accelerator_parse(accel, out keyval, out mods);
		}

		/**
		 * returns an xml representation of the overflown menubar.
		 * The difference between the returned string and the
		 * ordinary xml representation is that 
		 * only overflown items are visible.
		 */
		public string? create_overflown_menu() {
			if(!overflown) return null;	
			StringBuilder sb = new StringBuilder("");
			sb.append("<menu>");
			weak List<weak Widget> children = get_children();
			foreach(weak Widget child in children) {
				bool need_overflown_item = false;
				Allocation a = child.allocation;
				switch(pack_direction) {
					case PackDirection.LTR:
						if(a.x + a.width > allocation.width) {
							need_overflown_item = true;
						}
					break;
					case PackDirection.RTL:
						if(a.x < 0 ) {
							need_overflown_item = true;
						}
					break;
					case PackDirection.BTT:
						if(a.y < 0 ) {
							need_overflown_item = true;
						}
					break;
					case PackDirection.TTB:
						if(a.y < 0 ) {
							need_overflown_item = true;
						}
					break;
				}
				/* This is quirky. But it works
				 * we first save the visibility flag of
				 * the child,
				 * then change it
				 * our serializer will produce the visible=false
				 * attribute.
				 * then we restore it.
				 *
				 * Not thread safe.
				 * */
				bool vis = child.visible;
				if(need_overflown_item && vis) {
					child.set_flags(WidgetFlags.VISIBLE);
				} else {
					child.unset_flags(WidgetFlags.VISIBLE);
				}
				sb.append(Serializer.to_string(child));
				if(vis) {
					child.set_flags(WidgetFlags.VISIBLE);
				} else {
					child.unset_flags(WidgetFlags.VISIBLE);
				}
			}
			sb.append("</menu>");
			return sb.str;
		}


/* Private variables */
		/**
		 * Holding the background object
		 */
		private Background _background;
		/**
		 * Storing the text gravity
		 */
		private Gravity _gravity;

		private override void style_set(Style old_style) {
			base.style_set(old_style);
			reset_bg_pixmap();
		}
		private void reset_bg_pixmap() {
			/*
			if(background.type != BackgroundType.PIXMAP) return;
			if(0 != (get_flags() & WidgetFlags.REALIZED)) {
				// style = 
				style.copy();
			}*/
			if(background.type != BackgroundType.PIXMAP) return;
			if(0 != (get_flags() & WidgetFlags.REALIZED)) {
				Gdk.Pixmap pixmap = new Gdk.Pixmap(window, allocation.width, allocation.height, -1);
				assert(window is Gdk.Drawable);
				assert(pixmap is Gdk.Drawable);
				Cairo.Context cairo = Gdk.cairo_create(pixmap);
				assert(cairo != null);
				assert(_background.pixmap is Gdk.Drawable);
				Gdk.cairo_set_source_pixmap(cairo, _background.pixmap, -_background.offset_x, -background.offset_y);
				cairo.rectangle (0, 0, allocation.width, allocation.height);
				cairo.fill();
				style.bg_pixmap[(int)StateType.NORMAL] = pixmap;
				style.attach(window);
				style.set_background(window, StateType.NORMAL);
				queue_draw();
			}
		}
		private override void realize() {
			base.realize();
		//	reset_bg_pixmap();
		}
		private override void size_allocate(Gdk.Rectangle a) {
			bool need_reset_bg_pixmap = false;
			int delta_x = allocation.x - a.x;
			int delta_y = allocation.y - a.y;
			if(delta_x != 0 || delta_y != 0
					|| a.width != allocation.width
					|| a.height != allocation.height)
				need_reset_bg_pixmap = true;
			
			background.offset_x += delta_x;
			background.offset_y += delta_y;
			base.size_allocate(a);
			if(need_reset_bg_pixmap) {
				reset_bg_pixmap();
			}
		}
		private override bool expose_event(Gdk.EventExpose event) {
			foreach(weak Widget child in get_children()) {
				propagate_expose(child, event);
			}
			return false;
		}
		private override void size_request(out Requisition req) {
			base.size_request(out req);
		}
		private override void insert(Widget child, int position) {
			base.insert(child, position);
			(child as MenuItem).gravity = gravity;
		}
		public void remove_all() {
			((MenuShellHelper)this).truncate(0);
		}	
	}
}

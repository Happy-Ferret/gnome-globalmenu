using Gtk;

namespace Gnomenu {
	public class Background {
		public BackgroundType type;
		public Gdk.Pixmap pixmap;
		public Gdk.Color color;
		public int offset_x;
		public int offset_y;
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
	public class MenuBar : Gtk.MenuBar {
		public MenuBar() {}
		construct {
			_background = new Background();
		}
		public signal void activate(MenuItem item);

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
						queue_draw();
					break;
				}
			}
		}
		public Gravity gravity {
			get { return _gravity; }
			set {
				_gravity = value;
				foreach(weak Widget child in get_children()) {
					(child as MenuItem).gravity = value;
				}
			}
		}
		public bool overflow {
			get { return _overflow; }
			set { _overflow = value; }
		}
		private Background _background;
		private Gravity _gravity;
		private bool _overflow;
		private void reset_bg_pixmap() {
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
				/*style = */style.copy();
				style.bg_pixmap[(int)StateType.NORMAL] = pixmap;
				style.attach(window);
				style.set_background(window, StateType.NORMAL);
			}
		}
		private override void realize() {
			base.realize();
			reset_bg_pixmap();
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
		private override void size_request(out Requisition req) {
			base.size_request(out req);
			if(overflow) {
				req.width = 0;
				req.height = 0;
			}
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

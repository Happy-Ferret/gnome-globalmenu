using GLib;
using DBus;
using Gnomenu;
using XML;
using GtkAQD;

namespace GnomenuGtk {
	protected class Document : Gnomenu.Document {
		HashTable<weak string, weak Gtk.Widget> dict_nw;
		private class Widget:Gnomenu.Document.Widget {
			public Gtk.TreeIter iter;
			private Widget(Document document, string tag) {
				this.document = document;
				this.tag = document.S(tag);
			}
			public override void dispose() {
				base.dispose();
			}
			public override void activate() {
				weak Gtk.Widget widget = (document as Document).dict_nw.lookup(this.get("name"));
				if(widget is Gtk.MenuItem) (widget as Gtk.MenuItem).activate();
				if(widget is GtkAQD.MenuBar) {
					bool local = (widget as GtkAQD.MenuBar).local;
					(widget as GtkAQD.MenuBar).local = !local;
				}
			}
		}
		public Document() {}
		construct {
			dict_nw = new HashTable<weak string, weak Gtk.Widget>(str_hash, str_equal);
		}
		public override XML.Document.Tag CreateTag(string tag) {
			return new Widget(this, tag);
		}
		private void list_to_array(List<weak string>? l, ref string[] array){
			array.resize((int)l.length());
			int i = 0;
			foreach(weak string s in l) {
				array[i] = s;
				i++;
			}
		}
		public Gnomenu.Document.Widget CreateWidget(string type, string name) {
			{
				weak XML.Node node = lookup(name);
				if(node != null) return node as Gnomenu.Document.Widget;
			}
			weak Gtk.Widget gtk = dict_nw.lookup(name);
			List<weak string> names;
			List<weak string> values;
			names.append("name");
			values.append(name);
			if(gtk is Gtk.MenuItem) { 
				Gtk.MenuItem item = gtk as Gtk.MenuItem;
				item.notify["visible"] += item_property_notify;
				item.notify["sensitive"] += item_property_notify;
				if(!item.visible) {
					names.append("visible");
					values.append("false");
				}
				if(!item.sensitive) {
					names.append("sensitive");
					values.append("false");
				}
				names.append("label");
				if(gtk is Gtk.TearoffMenuItem) {
					values.append("&");
				} else if(gtk is Gtk.SeparatorMenuItem) {
					values.append("|");
				} else  {
					weak Gtk.Label l = find_menu_item_label(gtk);
					if(l!= null) {
						l.notify["label"] += item_property_notify;
						values.append(l.label);
					} else 
						values.append("unknown");
					if(gtk is Gtk.CheckMenuItem) {
						Gtk.CheckMenuItem c = gtk as Gtk.CheckMenuItem;
						gtk.notify["active"] += item_property_notify;
						gtk.notify["draw-as-radio"] += item_property_notify;
						gtk.notify["inconsistent"] += item_property_notify;
						names.append("active");
						values.append(c.active?"true":"false");
						names.append("draw-as-radio");
						values.append(c.draw_as_radio?"true":"false");
						names.append("indonsistent");
						values.append(c.inconsistent?"true":"false");
					}
				}
			}
			string[] anames = new string[1];
			string[] avalues = new string[1];
			list_to_array(names, ref anames);
			list_to_array(values, ref avalues);
			Widget node = CreateTagWithAttributes(type, anames, avalues) as Widget;
			return node;
		}
		public weak string wrap(Gtk.Widget widget) {
			weak string name = (string)widget.get_data("native-name");
			if(name != null) return name;
			int id = Singleton.instance().unique;
			name = S("%s%d".printf(widget.get_type().name(), id));
			widget.set_data("native-name", name);
			object_add_toggle_ref(widget, toggle_ref_notify, this);
			dict_nw.insert(name, widget);
			return name;
		}
		private void toggle_ref_notify(GLib.Object object, bool is_last){
			if(!is_last) return;
			if(object is Gtk.MenuItem) {
				weak Gtk.Label label = find_menu_item_label(object as Gtk.Widget);
				if(label != null) label.notify["label"] -= item_property_notify;
			}
			unbind_widget(object as Gtk.Widget);
			weak string name = (string) object.get_data("native-name");
			if(name != null) {
				message("GtkWidget %s is removed", name);
				dict_nw.remove(name); // because ~WidgetNode is not always invoked?
				weak Gnomenu.Document.Widget node = lookup(name) as Gnomenu.Document.Widget;
				if(node != null){
					if(node.parent == null) {
						assert(false);
					}
					node.parent.remove(node);
				}
			}
			object.set_data("native-name", null);
			object_remove_toggle_ref(object, toggle_ref_notify, this);
		}
		private void item_property_notify(Gtk.Widget w, ParamSpec pspec) {
			weak Gnomenu.Document.Widget node = lookup((string)w.get_data("native-name")) as Gnomenu.Document.Widget;
			if(node == null) {
				warning("no xml node found for widget %s", (string) w.get_data("native-name"));
				return;
			}
			string val;
			if(pspec.value_type == typeof(string)) {
				w.get(pspec.name, out val, null);
			}
			if(pspec.value_type == typeof(bool)) {
				bool b;
				w.get(pspec.name, out b, null);
				val = b.to_string();
			}
			if(pspec.value_type == typeof(int)) {
				int i;
				w.get(pspec.name, out i, null);
				val = i.to_string();
			}
			node.set(pspec.name, val);
		}
	}
	private weak Gtk.Label? find_menu_item_label(Gtk.Widget widget) {
		Queue<weak Gtk.Widget> q = new Queue<weak Gtk.Widget>();
		q.push_tail(widget);
		while(!q.is_empty()) {
			weak Gtk.Widget w = q.pop_head();
			if(w is Gtk.Container) {
				weak List<weak Gtk.Widget> children = (w as Gtk.Container).get_children();
				foreach(weak Gtk.Widget child in children){
					q.push_tail(child);
				}
			}
			if(w is Gtk.Label) {
				w.set_data("native-name", widget.get_data("native-name"));
				return w as Gtk.Label;
			}
		}
		return null;
	}
}

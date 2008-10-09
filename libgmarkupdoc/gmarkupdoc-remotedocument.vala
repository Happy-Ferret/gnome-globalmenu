using GLib;
using Gtk;
using Gnomenu;
using GMarkupDoc;
using DBus;

namespace Gnomenu {
	public class RemoteDocument: Document {
		private Parser parser;
		private dynamic DBus.Object remote;
		private dynamic DBus.Connection conn;
		public bool invalid {get; set;}
		dynamic DBus.Object dbus;
		private GMarkupDoc.Node _root;
		public GMarkupDoc.Node root {
			get {
				return _root;
			}
		}
		public string path {get; construct;}
		public string bus {get; construct;}
		
		public RemoteDocument(string bus, string path) {
			this.path = path;
			this.bus = bus;
		}
		construct {
			invalid = false;
			_root = new GMarkupDoc.Root(this);
			conn = Bus.get(DBus.BusType.SESSION);
			dbus = conn.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus");
			dbus.NameOwnerChanged += name_owner_changed;

			remote = conn.get_object(bus, path, "org.gnome.GlobalMenu.Document");
			remote.Inserted += remote_inserted;
			remote.Removed += remote_removed;
			remote.Updated += remote_updated;
			parser = new GMarkupDoc.Parser(this);
			try {
				string xml = remote.QueryRoot(0);
				parser.parse(xml);
			} catch (GLib.Error e) {
				warning("%s", e.message);
			}
			this.activated += (doc, node) => {
				try {
					remote.Activate(node.name);
				} catch(GLib.Error e){
					warning("%s", e.message);
				}
			};
		}
		private void remote_inserted(dynamic DBus.Object remote, string parentname, string nodename, int pos) {
			if(invalid) return;
			weak GMarkupDoc.Node parent = lookup(parentname);
			try {
				string s = remote.QueryNode(nodename, 0);
				if(s == null) {
					warning("remote document didn't reply");
					return;
				}
				parser.parse_child(parent, s, pos);
			} catch(GLib.Error e){
				warning("%s", e.message);
			}
		}
		private void remote_removed(dynamic DBus.Object remote, string parentname, string nodename) {
			if(invalid) return;
			weak GMarkupDoc.Node parent = lookup(parentname);
			weak GMarkupDoc.Node node = lookup(nodename);
			parent.remove(node);
		}
		private void remote_updated(dynamic DBus.Object remote, string nodename, string propname) {
			if(invalid) return;
			weak GMarkupDoc.Tag node = lookup(nodename) as GMarkupDoc.Tag;
			try {
				string s = remote.QueryNode(nodename, 0);
				if(s == null) {
					warning("remote document didn't reply");
					return;
				}
				parser.update_tag(node, propname, s);
			} catch(GLib.Error e){
				warning("%s %s", e.domain.to_string(), e.message);
			}
		}
		private void name_owner_changed(dynamic DBus.Object object, string bus, string old_owner, string new_owner){
			if(bus != this.bus) return;
			if(new_owner != "" && old_owner == "") {
				message("new owner of %s", bus);
				this.root.remove_all();
				try {
					string xml = remote.QueryRoot(0);
					parser.parse(xml);
				} catch (GLib.Error e) {
					warning("%s", e.message);
				}
				invalid = false;
				return;
			}
			if(new_owner == "" && old_owner != "") {
				message("owner of %s disappeared", bus);
				this.root.remove_all();
				invalid = true;
				return;
			}
		}

		public static int test(string[] args) {
			Gtk.init(ref args);
			MainLoop loop = new MainLoop(null, false);
			RemoteDocument document = new RemoteDocument("org.gnome.GlobalMenu.Server", "/org/gnome/GlobalMenu/Server");
			ListView viewer = new ListView(document);
			Gtk.Window window = new Gtk.Window(Gtk.WindowType.TOPLEVEL);
			window.add(viewer);
			window.show_all();
			loop.run();
			return 0;
		}
	}
}
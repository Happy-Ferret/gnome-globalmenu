using GLib;
using Gdk;
using Gtk;
using DBus;
using XML;
namespace Gnomenu {
	[DBus (name = "org.gnome.GlobalMenu.Document")]
	public class DBusView:GLib.Object {
		Connection conn;
		dynamic DBus.Object dbus;
		[DBus (visible = false)]
		public string path {get; construct;}
		[DBus (visible = false)]
		public Document document {get; construct;}
		public DBusView(Document document, string object_path) {
			this.document = document;
			path = object_path;
		}
		construct {
			conn = Bus.get(DBus.BusType.SESSION);
			dbus = conn.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus");

			conn.register_object(path, this);
			document.inserted += (f, p, o, i) => {
				if(!(o is Document.Widget)) return;
				weak Document.Widget node = o as Document.Widget;
				if(p == f.root) {
					inserted("root", node.name, i);
				} else {
					weak Document.Widget parent_node = p as Document.Widget;
					inserted(parent_node.name, node.name, i);
				}
			};
			document.removed += (f, p, o) => {
				if(!(o is Document.Widget)) return;
				weak Document.Widget node = o as Document.Widget;
				if(p == f.root) {
					removed("root", node.name);
				} else {
					weak Document.Widget parent_node = p as Document.Widget;
					removed(parent_node.name, node.name);
				}
			};
			document.updated += (f, o, prop) => {
				if(!(o is Document.Widget)) return;
				weak Document.Widget node = o as Document.Widget;
				updated(node.name, prop);
			};
		}
		public string QueryRoot(int level = -1) {
			return document.root.summary(level);
		}
		public string QueryNode(string name, int level = -1){
			weak Document.Widget node = document.lookup(name) as Document.Widget;
			if(node!= null)
				return node.summary(level);
			return "";
		}
		public void Activate(string name){
			weak Document.Widget node = document.lookup(name) as Document.Widget;
			if(node != null)
				node.activate();
			else 
				message("node %s exeptionally disappeared", name);
		}
		public signal void updated(string name, string prop);
		public signal void inserted(string parent, string name, int pos);
		public signal void removed(string parent, string name);

		public static int test(string[] args) {
			Gtk.init(ref args);
			MainLoop loop = new MainLoop(null, false);
			Document document = new Document();
			XML.Parser parser = new Parser(document);
			DBusView c = new DBusView(document, "/org/gnome/GlobalMenu/Document");
			parser.parse(
"""
<html><title>title</title>
<body name="body">
<div name="header">
	<h1> This is a header</h1>
</div>
<div name="content"></div>
<div name="tail"></div>
</body>
""");
			loop.run();
			return 0;
		}
	}
}

using GLib;
using Gdk;
using Gtk;
using DBus;
using XML;
namespace Gnomenu {
	public class WidgetNodeFactory: SimpleNodeFactory {
		private HashTable <weak string, weak XML.TagNode> dict;
		private class WidgetNode:TagNode {
			public WidgetNode(NodeFactory factory) {
				this.factory = factory;
			}
			~WidgetNode() {
				dict.remove(this.get("widget"));
			}
		}
		public WidgetNodeFactory() { }
		construct {
			dict = new HashTable<weak string, weak XML.TagNode>(str_hash, str_equal);
		}
		public weak XML.TagNode? lookup(string widget){
			return dict.lookup(widget);
		}
		public virtual TagNode CreateWidgetNode(string widget) {
			TagNode rt = new WidgetNode(this);
			rt.tag = S("widget");
			rt.set("widget", widget);
			dict.insert(widget, rt);
			return rt;
		}
	}
	[DBus (name = "org.gnome.GlobalMenu.Client")]
	public class Client:GLib.Object {
		Connection conn;
		string bus;
		dynamic DBus.Object dbus;
		[DBus (visible = false)]
		public WidgetNodeFactory factory {get; construct;}
		protected TagNode windows;
		public Client(WidgetNodeFactory factory) {
			this.factory = factory;
		}
		construct {
			conn = Bus.get(DBus.BusType.SESSION);
			dbus = conn.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus");
			
			string str = dbus.GetId();
			bus = "org.gnome.GlobalMenu.Applications." + str;
			uint r = dbus.RequestName (bus, (uint) 0);
			assert(r == DBus.RequestNameReply.PRIMARY_OWNER);
			conn.register_object("/org/gnome/GlobalMenu/Application", this);
			windows = factory.CreateTagNode("windows");
		}
		public string QueryNode(string widget, int level = -1){
			weak TagNode node = factory.lookup(widget);
			if(node!= null)
				return node.summary(level);
			return "";
		}
		public string QueryXID(string xid) {
			weak TagNode node = find_window_by_xid(xid);
			if(node != null) {
				return node.summary(0);
			}
			return "";
		}
		public string QueryWindows() {
			return windows.summary(1);
		}
		public void ActivateItem(string widget){
			weak TagNode node = factory.lookup(widget);
			activate_item(node);
		}
		public signal void updated(string widget);

		protected dynamic DBus.Object get_server(){
			return conn.get_object("org.gnome.GlobalMenu.Server", "/org/gnome/GlobalMenu/Server", "org.gnome.GlobalMenu.Server");
		}
		protected virtual void activate_item(TagNode item_node) {
			message("%s is activated", item_node.summary(0));
		}
		private weak TagNode? find_window_by_xid(string xid) {
			foreach (weak XML.Node node in windows.children) {
				if(node is TagNode) {
					weak TagNode tagnode = node as TagNode;
					if(tagnode.get("xid") == xid) {
						return tagnode;
					}
				}
			}
			return null;
		}
		protected void add_widget(string? parent, string widget) {
			weak TagNode node = factory.lookup(widget);
			weak TagNode parent_node;
			if(parent == null)
				parent_node = windows;
			else
				parent_node = factory.lookup(parent);
			if(node == null) {
				TagNode node = factory.CreateWidgetNode(widget);
				parent_node.append(node);
			}
		}
		protected void remove_widget(string widget) {
			weak TagNode node = factory.lookup(widget);
			if(node != null) {
				node.parent.children.remove(node);
			}
		}
		protected void register_window(string widget, string xid) {
			weak TagNode node = factory.lookup(widget);
			if(node != null) {
				node.set("xid", xid);
				try {
					get_server().RegisterWindow(this.bus, xid);
				} catch(GLib.Error e) {
					warning("%s", e.message);
				}
			}
		}
		protected void unregister_window(string widget) {
			weak TagNode node = factory.lookup(widget);
			if(node != null) {
				weak string xid = node.get("xid");
				try {
					get_server().RemoveWindow(this.bus, xid);
				} catch(GLib.Error e) {
					warning("%s", e.message);
				}
				node.remove("xid");
			}

		}
		public static int test(string[] args) {
			Gtk.init(ref args);
			MainLoop loop = new MainLoop(null, false);
			WidgetNodeFactory factory = new WidgetNodeFactory();
			Client c = new Client(factory);
			c.add_widget(null, "window1");
			c.add_widget(null, "window2");
			c.add_widget("window1", "menu1");
			c.add_widget("window2", "menu2");
			loop.run();
			return 0;
		}
	}
}

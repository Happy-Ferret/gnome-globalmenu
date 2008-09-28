using GLib;
using Gtk;
using XML;
using Gnomenu;



public class Navigator :Gtk.Window{
	private ListView server_viewer;
	private ListView viewer;
	private MenuView viewer2;
	private RemoteDocument server;
	public Navigator() {
		type = Gtk.WindowType.TOPLEVEL;
	}
	construct {
		server = new Gnomenu.RemoteDocument("org.gnome.GlobalMenu.Server", "/org/gnome/GlobalMenu/Server");
		server_viewer = new ListView(server);
		viewer = new ListView(null);
		viewer2 = new MenuView(null);
		Gtk.Box hbox = new Gtk.HBox(false, 0);
		Gtk.Box vbox = new Gtk.VBox(false, 0);
		this.add(hbox);
		hbox.pack_start_defaults(server_viewer);
	
		hbox.pack_start_defaults(vbox);
		vbox.pack_start_defaults(viewer2);
		vbox.pack_start_defaults(viewer);
		
		server.activated += (docu, node)=> {
			string bus = node.get("bus");
			print("attatch to bus %s", bus);
			RemoteDocument doc = new Gnomenu.RemoteDocument(bus, "/org/gnome/GlobalMenu/Application");
			doc.activated += (docu, node) => {
				if(node.tag == "menubar") {
					viewer2.view(node.name);
				}
			};
			viewer.document = doc;
			viewer2.document = doc;
		};
	}
	public static int main(string[] args) {
		Gtk.init(ref args);
		MainLoop loop = new MainLoop(null, false);

		Navigator nav = new Navigator();
		nav.show_all();
		loop.run();
		return 0;	
	}

}

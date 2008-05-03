using GLib;

namespace Gnomenu {
[DBus (name = "org.gnomenu.Document", signals="propChanged") ]
public class Document: MenuOwner {

	public Document(string name){
		this.name = name;
	}
	public override string getTitle() {
		return base.getTitle();
	}
	public override string getMenu() {
		return base.getMenu();
	}
}
}
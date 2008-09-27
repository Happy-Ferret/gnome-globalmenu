using GLib;
using Gtk;
using XML;
namespace Gnomenu {
	public class Document: GLib.Object, XML.Document, Gtk.TreeModel {
		public class Widget:XML.Document.Tag {
			public Gtk.TreeIter iter;
			public weak string name {
				get {return get("name");}
				set {
					set("name", value);
				}
			}
			public override void set(string prop, string? val) {
				if(prop == "name" && name != null)
					(document as Document).dict.remove(name);
				base.set(prop, val);
				if(prop == "name" && name != null)
					(document as Document).dict.insert(name, this);
			}
			private Widget(Document document, string tag) {
				this.document = document;
				this.tag = document.S(tag);
			}
			construct {
				this.parent_set += (o, old) => {
					if(this.parent == null) return;
					if(this.parent is Widget) {
						(document as Document).treestore.insert(out this.iter, (this.parent as Widget).iter, this.parent.index(this));
					} else {
						(document as Document).treestore.insert(out this.iter, null, 0);
					}
					(document as Document).treestore.set(this.iter, 0, this, -1);
				};
			}
			public override void dispose() {
				base.dispose();
				(document as Document).dict.remove(name);
				(this.document as Document).treestore.remove(this.iter);
			}
			~Widget(){
				message("Widget %s is removed", name);
			}
			public virtual void activate() {
				message("Widget %s is activated", name);
			}
		}
		public Gtk.TreeStore treestore;
		private XML.Document.Root _root;
		public XML.Document.Root root {get {return _root;}}
		private HashTable <weak string, weak Widget> dict;
		construct {
			dict = new HashTable<weak string, weak XML.Document.Tag>(str_hash, str_equal);
			_root = new XML.Document.Root(this);
			treestore = new Gtk.TreeStore(1, typeof(constpointer));
			this.updated += (o, node) => {
				if(node is Widget) {
					weak Widget w = node as Widget;
					row_changed(this.treestore.get_path(w.iter), w.iter);
				}
			};
			treestore.row_changed += (o, p, i) => { row_changed(p, i);};
			treestore.row_deleted += (o, p) => { row_deleted(p);};
			treestore.row_has_child_toggled += (o, p, i) => { row_has_child_toggled(p, i);};
			treestore.row_inserted += (o, p, i) => { row_inserted(p, i);};
			treestore.rows_reordered += (o, p, i, n) => {rows_reordered(p, i, n);};
		}
		public virtual XML.Document.Tag CreateTag(string tag) {
			XML.Document.Tag t = new Widget(this, tag);
			return t;
		}
		public virtual weak XML.Node lookup(string name) { 
			/* returning root */
			if(name == "root") {
				return root;
			}
			return dict.lookup(name);
		}
		public GLib.Type get_column_type (int index_) {
			return treestore.get_column_type(index_);
		}
		public Gtk.TreeModelFlags get_flags () {
			return treestore.get_flags();
		}
		public bool get_iter (out Gtk.TreeIter iter, Gtk.TreePath path){
			return treestore.get_iter(out iter, path);
		}
		public int get_n_columns () {
			return treestore.get_n_columns();
		}
		public Gtk.TreePath get_path (Gtk.TreeIter iter) {
			return treestore.get_path(iter);
		}
		public void get_value (Gtk.TreeIter iter, int column, ref GLib.Value value) {
			treestore.get_value(iter, column, ref value);
		}
		public bool iter_children (out Gtk.TreeIter iter, Gtk.TreeIter? parent) {
			return treestore.iter_children(out iter, parent);
		}
		public bool iter_has_child (Gtk.TreeIter iter) {
			return treestore.iter_has_child(iter);
		}
		public int iter_n_children (Gtk.TreeIter? iter) {
			return treestore.iter_n_children(iter);
		}
		public bool iter_next (ref Gtk.TreeIter iter) {
			return treestore.iter_next(ref iter);
		}
		public bool iter_nth_child (out Gtk.TreeIter iter, Gtk.TreeIter? parent, int n) {
			return treestore.iter_nth_child(out iter, parent, n);
		}
		public bool iter_parent (out Gtk.TreeIter iter, Gtk.TreeIter child) {
			return treestore.iter_parent(out iter, child);
		}
		public void ref_node (Gtk.TreeIter iter) {
			treestore.ref_node(iter);	
		}
		public void unref_node (Gtk.TreeIter iter) {
			treestore.unref_node(iter);	
		}
	}
}

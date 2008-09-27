using GLib;
namespace XML {
	public abstract class Node: Object {
		private bool disposed;
		protected int freezed;
		protected weak Node _parent;
		public weak Node parent {
				get {return _parent;} 
				set{
					Node old_parent = _parent;
					_parent = value;
					parent_set(old_parent);
				}
		}
		public signal void parent_set(Node? old_parent);
		protected List<weak Node> children;
		public weak Document document {get; construct;}
		public Node (Document document){ this.document = document;}
		construct {
			disposed = false;
			freezed = 0;
		}
		public virtual string to_string () {
			return summary(-1);
		}
		public void append(Node node) {
			insert(node, -1);
		}
		public void insert(Node node, int pos) {
			node.parent = this;
			children.insert(node.ref() as Node, pos);
			if(freezed <= 0)
			document.added(this, node, pos);
		}
		public void remove(Node node) {
			Node parent = node.parent;
			children.remove(node);
			if(freezed <= 0)
			document.removed(parent, node);
			node.parent = null;
			node.unref();
		}
		public int index(Node node) {
			return children.index(node);
		}
		public abstract virtual string summary(int level = 0);
		protected override void dispose() {
			if(!disposed){
				disposed = true;
				foreach(weak Node node in children){
					node.unref();
				}
			}
		}
		public void freeze() {
			freezed++;
		}
		public void unfreeze() {
			freezed--;
		}	
		~Node() {
		}
	}
	public interface Document: Object {
		private static StringChunk strings = null;
		public abstract Document.Root root {get;}
		public virtual Document.Text CreateText(string text) {
			return new Document.Text(this, text);
		}
		public virtual Document.Special CreateSpecial(string text) {
			return new Document.Special(this, text);
		}
		public virtual Document.Tag CreateTag(string tag) {
			return new Document.Tag(this, tag);
		}
		public virtual Document.Tag CreateTagWithAttributes(string tag, 
				string[] attr_names, string[] attr_values) {
			Document.Tag t = CreateTag(tag);
			t.freeze();
			t.set_attributes(attr_names, attr_values);
			t.unfreeze();
			return t;
		}
		public virtual weak string S(string s) {
			if(strings == null) strings = new StringChunk(1024);
			return strings.insert_const(s);
		}
		public signal void updated(Node node, string prop);
		public signal void added(Node parent, Node node, int pos);
		public signal void removed(Node parent, Node node);
		public class Root : Node {
			public Root(Document document){
				this.document = document;
			}
			public override string summary(int level = 1) {
				StringBuilder sb = new StringBuilder("");
				if(this.children == null)
					return "";
				else {
					foreach(weak Node child in children){
						sb.append_printf("%s", child.summary(level - 1));
					}
				}
				return sb.str;
			}
		}
		public class Text : Node {
			public string text {
				get; construct set;
			}
			private Text(Document document, string text) {
				this.document = document;
				this.text = text;
			}
			public override string summary (int level = 0) {
				return text;
			}
		}
		public class Special: Node {
			public string text {
				get; construct set;
			}
			private Special(Document document, string text) {
				this.document = document;
				this.text = text;
			}
			public override string summary (int level = 0) {
				return text;
			}
		}
		public class Tag : Node {
			private weak string _tag;
			public weak string tag {
				get{ return _tag;}
				construct set {
					_tag = document.S(value);
				}
			}
			private HashTable<weak string, string> props;
			private Tag (Document document, string tag) {
				this.document = document;
				this.tag = tag;
			}
			construct {
				props = new HashTable<weak string, string>(str_hash, str_equal);
			}
			public void set_attributes(string[] names, string[] values) {
				assert(names.length == values.length);
				for(int i=0; i< names.length && i < values.length; i++) {
					this.set(names[i], values[i]);
				}
			}
			public virtual void set(string prop, string? val) {
				if(val == null)
					props.remove(prop);
				else 
					props.insert(document.S(prop), val);
				if(freezed <= 0)
				document.updated(this, prop);
			}
			public virtual void unset(string prop) {
				set(prop, null);
			}
			public virtual weak string? get(string prop) {
				return props.lookup(prop);
			}
			private string props_to_string() {
				if(props == null) {
					props = new HashTable<weak string, string>(str_hash, str_equal);
				}
				StringBuilder sb = new StringBuilder("");
				foreach(weak string key in props.get_keys()) {
					string escaped = GLib.Markup.escape_text(props.lookup(key));
					sb.append_printf(" %s=\"%s\"", key, escaped);
				}
				return sb.str;
			}
			public override string summary(int level = 0) {
				StringBuilder sb = new StringBuilder("");
				if(this.children == null || level == 0)
						sb.append_printf("<%s%s/>", tag, props_to_string());
				else {
					sb.append_printf("<%s%s>", tag, props_to_string());
					foreach(weak Node child in children){
						sb.append_printf("%s", child.summary((level>0)?(level - 1):level));
					}
					sb.append_printf("</%s>", tag);
				}
				return sb.str;
			}
		}
	}
}

namespace Gnomenu {
	public enum MenuItemType {
		NORMAL,
		CHECK,
		RADIO,
		IMAGE,
		SEPARATOR,
	}
	public enum MenuItemState {
		UNTOGGLED,
		TOGGLED,
		TRISTATE,
	}
	protected MenuItemState item_state_from_string(string? str) {
		switch(str) {
			case "true":
			case "toggled":
			case "t":
			case "1":
				return MenuItemState.TOGGLED;
			case "false":
			case "untoggled":
			case "f":
			case "0":
				return MenuItemState.UNTOGGLED;
			case null:
			default:
				return MenuItemState.TRISTATE;
		}
	}
	protected weak string? item_state_to_string(MenuItemState state) {
		switch(state) {
			case MenuItemState.UNTOGGLED:
				return "untoggled";
			case MenuItemState.TOGGLED:
				return "toggled";
			case MenuItemState.TRISTATE:
				return null;
		}
		return null;
	}
	protected MenuItemType item_type_from_string(string? str) {
		switch(str) {
			case "check":
			case "c":
				return MenuItemType.CHECK;
			case "radio":
			case "r":
				return MenuItemType.RADIO;
			case "image":
			case "i":
				return MenuItemType.IMAGE;
			case "separator":
			case "s":
				return MenuItemType.SEPARATOR;
			case null:
			default:
				return MenuItemType.NORMAL;
		}
	}
	protected weak string? item_type_to_string(MenuItemType type) {
		switch(type) {
			case MenuItemType.CHECK:
				return "check";
			case MenuItemType.RADIO:
				return "radio";
			case MenuItemType.NORMAL:
				return null;
			case MenuItemType.IMAGE:
				return "image";
			case MenuItemType.SEPARATOR:
				return "separator";
		}
		return null;
	}
}

/// Minimal stub for menu module — full implementation in task 2.

pub struct MenuEntry {
    pub category: String,
    pub subcategory: String,
    pub label: String,
    pub action_id: String,
}

pub fn parse_menu_db() -> Vec<MenuEntry> {
    Vec::new()
}

pub fn print_table(_entries: &[MenuEntry]) {
    println!("No modules found.");
}

pub fn print_json(_entries: &[MenuEntry]) {
    println!("[]");
}

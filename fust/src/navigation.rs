use std::collections::HashMap;

use crate::menu::MenuEntry;

#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct TreeNode {
    pub label: String,
    pub path: Vec<String>,
    pub children: Vec<usize>,
    pub action_id: Option<String>,
    pub depth: u8,
}

#[derive(Debug, Clone)]
pub struct MenuTree {
    pub nodes: Vec<TreeNode>,
    pub root_children: Vec<usize>,
}

#[derive(Debug, Clone, Default)]
pub struct ActionQueue {
    items: Vec<String>,
}

impl ActionQueue {
    pub fn new() -> Self {
        Self { items: Vec::new() }
    }

    pub fn toggle(&mut self, action_id: &str) {
        if let Some(pos) = self.items.iter().position(|s| s == action_id) {
            self.items.remove(pos);
        } else {
            self.items.push(action_id.to_string());
        }
    }

    pub fn contains(&self, action_id: &str) -> bool {
        self.items.iter().any(|s| s == action_id)
    }

    pub fn count(&self) -> usize {
        self.items.len()
    }

    pub fn to_vec(&self) -> Vec<String> {
        self.items.clone()
    }

    #[allow(dead_code)]
    pub fn clear(&mut self) {
        self.items.clear();
    }
}

impl MenuTree {
    pub fn get_children(&self, path: &[String]) -> Vec<usize> {
        if path.is_empty() {
            return self.root_children.clone();
        }
        match self.find_node_by_path(path) {
            Some(idx) => self.nodes[idx].children.clone(),
            None => Vec::new(),
        }
    }

    pub fn is_leaf(&self, node_idx: usize) -> bool {
        self.nodes[node_idx].children.is_empty()
    }

    pub fn get_breadcrumb(&self, path: &[String]) -> String {
        if path.is_empty() {
            return "Main Menu".to_string();
        }
        let mut parts = vec!["Main Menu".to_string()];
        for segment in path {
            parts.push(segment.clone());
        }
        parts.join(" > ")
    }

    pub fn get_action_id(&self, node_idx: usize) -> Option<&str> {
        self.nodes[node_idx].action_id.as_deref()
    }

    pub fn find_node_by_path(&self, path: &[String]) -> Option<usize> {
        self.nodes.iter().position(|n| n.path == path)
    }
}

pub fn build_navigation_tree(entries: &[MenuEntry]) -> MenuTree {
    let mut nodes: Vec<TreeNode> = Vec::new();
    let mut index_map: HashMap<Vec<String>, usize> = HashMap::new();
    let mut root_children: Vec<usize> = Vec::new();

    for entry in entries {
        let cat_path = vec![entry.category.clone()];
        if !index_map.contains_key(&cat_path) {
            let idx = nodes.len();
            nodes.push(TreeNode {
                label: entry.category.clone(),
                path: cat_path.clone(),
                children: Vec::new(),
                action_id: None,
                depth: 1,
            });
            index_map.insert(cat_path.clone(), idx);
            root_children.push(idx);
        }

        let sub_path = vec![entry.category.clone(), entry.subcategory.clone()];
        if !index_map.contains_key(&sub_path) {
            let idx = nodes.len();
            nodes.push(TreeNode {
                label: entry.subcategory.clone(),
                path: sub_path.clone(),
                children: Vec::new(),
                action_id: None,
                depth: 2,
            });
            index_map.insert(sub_path.clone(), idx);
            let cat_idx = index_map[&cat_path];
            nodes[cat_idx].children.push(idx);
        }

        let leaf_path = vec![
            entry.category.clone(),
            entry.subcategory.clone(),
            entry.label.clone(),
        ];
        if let std::collections::hash_map::Entry::Vacant(e) = index_map.entry(leaf_path.clone()) {
            let idx = nodes.len();
            nodes.push(TreeNode {
                label: entry.label.clone(),
                path: leaf_path,
                children: Vec::new(),
                action_id: Some(entry.action_id.clone()),
                depth: 3,
            });
            e.insert(idx);
            let sub_idx = index_map[&sub_path];
            nodes[sub_idx].children.push(idx);
        }
    }

    MenuTree {
        nodes,
        root_children,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_entries() -> Vec<MenuEntry> {
        vec![
            MenuEntry {
                category: "Languages & Runtimes".to_string(),
                subcategory: "Go".to_string(),
                label: "Install Go".to_string(),
                action_id: "install_go".to_string(),
            },
            MenuEntry {
                category: "Languages & Runtimes".to_string(),
                subcategory: "Go".to_string(),
                label: "Remove Go".to_string(),
                action_id: "remove_go".to_string(),
            },
            MenuEntry {
                category: "Languages & Runtimes".to_string(),
                subcategory: "Rust".to_string(),
                label: "Install Rust".to_string(),
                action_id: "install_rust".to_string(),
            },
            MenuEntry {
                category: "Diagnostics".to_string(),
                subcategory: "System".to_string(),
                label: "Status Check".to_string(),
                action_id: "status_check".to_string(),
            },
        ]
    }

    #[test]
    fn test_build_tree_from_sample() {
        let entries = sample_entries();
        let tree = build_navigation_tree(&entries);
        assert_eq!(tree.nodes.len(), 9);
    }

    #[test]
    fn test_root_children_are_categories() {
        let entries = sample_entries();
        let tree = build_navigation_tree(&entries);
        assert_eq!(tree.root_children.len(), 2);
        let labels: Vec<&str> = tree
            .root_children
            .iter()
            .map(|&i| tree.nodes[i].label.as_str())
            .collect();
        assert!(labels.contains(&"Languages & Runtimes"));
        assert!(labels.contains(&"Diagnostics"));
    }

    #[test]
    fn test_get_children_root() {
        let entries = sample_entries();
        let tree = build_navigation_tree(&entries);
        let children = tree.get_children(&[]);
        assert_eq!(children.len(), 2);
    }

    #[test]
    fn test_get_children_category() {
        let entries = sample_entries();
        let tree = build_navigation_tree(&entries);
        let children = tree.get_children(&["Languages & Runtimes".to_string()]);
        assert_eq!(children.len(), 2);
        let labels: Vec<&str> = children
            .iter()
            .map(|&i| tree.nodes[i].label.as_str())
            .collect();
        assert!(labels.contains(&"Go"));
        assert!(labels.contains(&"Rust"));
    }

    #[test]
    fn test_is_leaf_true_for_actions() {
        let entries = sample_entries();
        let tree = build_navigation_tree(&entries);
        let leaf_idx = tree
            .find_node_by_path(&[
                "Languages & Runtimes".to_string(),
                "Go".to_string(),
                "Install Go".to_string(),
            ])
            .unwrap();
        assert!(tree.is_leaf(leaf_idx));
    }

    #[test]
    fn test_is_leaf_false_for_categories() {
        let entries = sample_entries();
        let tree = build_navigation_tree(&entries);
        let cat_idx = tree.root_children[0];
        assert!(!tree.is_leaf(cat_idx));
    }

    #[test]
    fn test_breadcrumb_root() {
        let entries = sample_entries();
        let tree = build_navigation_tree(&entries);
        assert_eq!(tree.get_breadcrumb(&[]), "Main Menu");
    }

    #[test]
    fn test_breadcrumb_nested() {
        let entries = sample_entries();
        let tree = build_navigation_tree(&entries);
        assert_eq!(
            tree.get_breadcrumb(&["Languages & Runtimes".to_string(), "Go".to_string()]),
            "Main Menu > Languages & Runtimes > Go"
        );
    }

    #[test]
    fn test_action_id_lookup() {
        let entries = sample_entries();
        let tree = build_navigation_tree(&entries);
        let leaf_idx = tree
            .find_node_by_path(&[
                "Languages & Runtimes".to_string(),
                "Go".to_string(),
                "Install Go".to_string(),
            ])
            .unwrap();
        assert_eq!(tree.get_action_id(leaf_idx), Some("install_go"));
    }

    #[test]
    fn test_queue_toggle_add_remove() {
        let mut queue = ActionQueue::new();
        queue.toggle("install_go");
        assert_eq!(queue.count(), 1);
        queue.toggle("install_go");
        assert_eq!(queue.count(), 0);
    }

    #[test]
    fn test_queue_contains() {
        let mut queue = ActionQueue::new();
        assert!(!queue.contains("install_go"));
        queue.toggle("install_go");
        assert!(queue.contains("install_go"));
    }

    #[test]
    fn test_embedded_menu_db_tree() {
        let entries = crate::menu::parse_menu_db();
        let tree = build_navigation_tree(&entries);
        assert_eq!(tree.root_children.len(), 7);
        assert!(tree.nodes.len() > 50);
    }
}

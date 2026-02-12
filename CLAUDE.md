# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**bookmarks.nvim** is a Neovim plugin for persistent code bookmarking with hierarchical organization. It's a pure Lua plugin that stores bookmarks in JSON format and provides multiple UI interfaces (Snacks.nvim picker, TreeView) for bookmark management.

## Architecture

### Domain-Driven Design

The plugin follows a clean domain-driven architecture with clear separation of concerns:

**`lua/bookmarks/domain/`** - Core business logic and data models:
- `node.lua` - Core data structure (`Bookmarks.Node` type). Nodes can be either "lists" (containers) or "bookmarks" (actual line marks)
- `service.lua` - Business logic for all bookmark operations (mark, delete, rename, navigate, etc.)
- `repo.lua` - Data persistence layer (JSON file storage at `.nvim/bookmarks/bookmarks.json`)
- `location.lua` - File path handling with project-relative path support

**Key Concept**: Everything is a `Node`. Lists contain bookmarks. Bookmarks have an `order` field for positioning. There's always an "active list" that new bookmarks are added to.

### Application Layer

**`lua/bookmarks/`** - Main plugin integration:
- `init.lua` - Plugin setup, public API, and Neovim autocommand registration
- `sign.lua` - Neovim sign column management (visual icons and line highlighting)
- `config.lua` - Configuration management

### Feature Modules

- **`picker/`** - Snacks.nvim picker integration
- **`tree/`** - TreeView UI implementation with hierarchical display and rich keybindings
- **`commands/`** - Command palette and exposed command functions
- **`integrate/`** - External tool integrations (Aider AI coding assistant)
- **`backup/`** - Automatic backup system
- **`utils/`** - Shared utilities

## Development Workflow

### No Build Process

This is a pure Lua plugin with no compilation:
- Edit files directly
- Reload with `:luafile %` or restart Neovim
- Tests can be run directly in Neovim: `:lua require('bookmarks.test.service-test').test_mark_with_parent()`

### Testing

Simple test framework in `lua/bookmarks/test/`:
- `service-test.lua` - Core service operations
- `render-test.lua` - Rendering tests
- Tests are plain Lua functions that can be called from Neovim command line

### Configuration

All defaults defined in `lua/bookmarks/default-config.lua`. Users override via `require("bookmarks").setup(opts)`.

Important: The `storage` config controls whether data is saved to JSON (current default) with `auto_save` option.

## Key Data Structures

### Bookmarks.Node

```lua
-- List node (container)
{
  id = "uuid",
  name = "My List",
  type = "list",
  children = { <bookmark nodes> }
}

-- Bookmark node
{
  id = "uuid",
  name = "Feature implementation",
  type = "bookmark",
  location = "lua/bookmarks/init.lua",
  line = 42,
  order = 1,  -- Position within parent list
  created_at = timestamp,
  last_visited = timestamp
}
```

## Important Patterns

### Path Handling
- Bookmarks use project-relative paths for portability
- `location.lua` handles conversion between relative and absolute paths
- Root path detection happens at runtime

### Active List Pattern
- Users always work within an "active list"
- New bookmarks are added to the active list
- Commands like `BookmarksLists` switch the active list
- Signs are only shown for bookmarks in the active list

### Event-Driven Updates
- Many operations return callbacks for picker integration
- `sign.safe_refresh_signs()` must be called after bookmark changes to update UI
- TreeView and pickers refresh on data changes

### Picker Integration
- Uses Snacks.nvim picker for fuzzy finding bookmarks and lists
- Keybindings in pickers: Enter (goto), C-s (split), C-v (vsplit), C-t (tab), C-x (delete)

## Common Commands Reference

| Command | Description |
|---------|-------------|
| `BookmarksMark` | Toggle bookmark on current line |
| `BookmarksGoto` | Open Snacks picker to navigate to bookmark |
| `BookmarksTree` | Open hierarchical tree view |
| `BookmarksLists` | Switch active list via picker |
| `BookmarksCommands` | Command palette for all operations |
| `BookmarksGotoNext/Prev` | Navigate by line number |
| `BookmarksGotoNextInList/PrevInList` | Navigate by list order |

## Storage System

The plugin uses JSON file storage:
- Format: JSON file at `.nvim/bookmarks/bookmarks.json` (relative to project root)
- Config: `storage.format = "json"`
- Repository: `lua/bookmarks/domain/repo.lua` handles JSON serialization
- Auto-save: `storage.auto_save = true` saves after each operation

## Custom Commands and Keymaps

The plugin is highly extensible:

### Custom Commands
Add to `config.commands` in setup:
```lua
commands = {
  my_command = function()
    -- Use require("bookmarks.domain.service") for operations
    -- Call require("bookmarks.sign").safe_refresh_signs() after changes
  end
}
```

### TreeView Custom Actions
Add custom functions to `config.treeview.keymap`:
```lua
["<C-o>"] = {
  action = function(node, info)
    -- info.type is 'bookmark' or 'list'
    -- info contains node details
  end,
  desc = "Custom action"
}
```

## File Organization Notes

- `lua/bookmarks/` - All plugin code
- `lua/bookmarks/domain/` - Core domain logic (edit with care)
- `lua/bookmarks/picker/` - Snacks.nvim picker integration
- `lua/bookmarks/tree/` - TreeView UI
- `lua/bookmarks/commands/` - User-callable commands
- `lua/bookmarks/data/` - Runtime data storage (.nvim/bookmarks/bookmarks.json)

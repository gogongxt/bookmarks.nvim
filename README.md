# Bookmarks.nvim

- Simple: Add, Rename and Remove bookmarks with only one command, less shortcuts more productivity.
- Persistent: save your bookmarks into a sqlite db file
- Accessible: Find your bookmark by telescope, snacks, or Treeview with ease.
- Informative: mark with a name or description, so you can record more information.
- Visibility: display icon and name at the marked lines, and highlight marked lines.
- Lists: arrange your bookmarks in lists, organise the bookmarks in your way.

<p align="center">
  <a href="#install-and-config">Install & Config</a>
  ·
  <a href="#basic-bookmark-operations">Basic Operations</a>
  ·
  <a href="#treeview">Treeview</a>
  ·
  <a href="#quick-navigation">Quick Navigation</a>
  ·
  <a href="#more-commands">More Commands</a>
  ·
  <a href="#keymap">Keymap</a>
  ·
  <a href="#contributing">Contributing</a>
</p>

![bookmarks nvim](https://github.com/user-attachments/assets/dd8ed4d0-8f36-4f32-b066-0594ef218df0)

- More usecases can be found at https://oatnil.top/bookmarks/usecases

- [Basic function overview](https://www.youtube.com/watch?v=RoyXQYauiLo)

- [BookmarkTree function overview](https://youtu.be/TUCn1mqSI6Q)

## Install and Config

```lua
-- with lazy.nvim
return {
  "LintaoAmons/bookmarks.nvim",
  -- pin the plugin at specific version for stability
  -- backup your bookmark sqlite db when there are breaking changes (major version change)
  tag = "3.2.0",
  dependencies = {
    {"kkharji/sqlite.lua"},
    {"nvim-telescope/telescope.nvim"},  -- telescope picker support
    {"folke/snacks.nvim"},  -- snacks picker support (alternative to telescope)
    {"stevearc/dressing.nvim"}, -- optional: better UI
    {"GeorgesAlkhouri/nvim-aider"} -- optional: for Aider integration
  },
  config = function()
    local opts = {} -- check the "./lua/bookmarks/default-config.lua" file for all the options
    require("bookmarks").setup(opts) -- you must call setup to init sqlite db
  end,
}

-- run :BookmarksInfo to see the running status of the plugin
```

> Check the [default-config.lua](./lua/bookmarks/default-config.lua) file for all the configuration options.

> For Windows users, if you encounter sqlite dependency issues, please refer to https://github.com/LintaoAmons/bookmarks.nvim/issues/73 for potential solutions.

## Picker Configuration

By default, the plugin uses telescope.nvim for fuzzy finding. You can also configure it to use snacks.nvim instead:

```lua
local opts = {
  picker = {
    type = "snacks",  -- or "telescope" (default)
  }
}
require("bookmarks").setup(opts)
```

Both pickers provide the same functionality with similar keybindings.

## Usage

### Basic Bookmark Operations

| Command             | Description                                                                                                                         |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `BookmarksMark`     | Mark current line into active BookmarkList. Rename existing bookmark under cursor. Toggle it off if the new name is an empty string |
| `BookmarksGoto`     | Go to bookmark at current active BookmarkList with the configured picker (telescope or snacks)                                      |
| `BookmarksNewList`  | Create a new bookmark list, but I normally use `BookmarksTree` to create new list                                                   |
| `BookmarksLists`    | Pick a bookmark list with the configured picker (telescope or snacks)                                                               |
| `BookmarksCommands` | Find bookmark commands and trigger it                                                                                               |

> [!NOTE]
> Those Telescope shortcuts are also available

| Shortcut | Action for bookmarks                       | Action for lists                 |
| -------- | ------------------------------------------ | -------------------------------- |
| `Enter`  | Go to selected bookmark                    | set selected list as active list |
| `<C-x>`  | Open selected bookmark in horizontal split | -                                |
| `<C-v>`  | Open selected bookmark in vertical split   | -                                |
| `<C-t>`  | Open selected bookmark in new tab          | -                                |
| `<C-d>`  | Delete selected bookmark                   | Delete selected list             |

and you can bind the commands to a shortcut or create a custom command out of it.

```lua
vim.keymap.set({ "n", "v" }, "Bd", function() require("bookmarks.commands").name_of_the_command_function() end, { desc = "Booksmark Clear Line" })
-- e.g.
vim.keymap.set({ "n", "v" }, "Bd", function() require("bookmarks.commands").delete_mark_of_current_file() end, { desc = "Booksmark Clear Line" })
-- or create your custom commands
vim.api.nvim_create_user_command("BookmarksClearCurrentFile", function() require("bookmarks.commands").delete_mark_of_current_file() end, {})
```

Change the `name_of_the_command_function` to the one you want to use, you can find all the names goes alone with the plugin in [https://github.com/LintaoAmons/bookmarks.nvim/blob/better-treeview-visual/lua/bookmarks/commands/init.lua](https://github.com/LintaoAmons/bookmarks.nvim/blob/main/lua/bookmarks/commands/init.lua)

And you can also extend the plugin by creating your own custom commands and put them into the config.

### Treeview

| Command         | Description                   |
| --------------- | ----------------------------- |
| `BookmarksTree` | Browse bookmarks in tree view |

> [!NOTE]
> There are quite a lot operations in treeview, which you can config it in the way you like.

```lua
-- Default keybindings in the treeview buffer with the new format
keymap = {
  ["q"] = {
    action = "quit",
    desc = "Close the tree view window"
  },
  -- ... See more in the default-config.lua
  ["+"] = {
    action = "add_to_aider",
    desc = "Add to Aider"
  },
  -- Example of a custom mapping
  ["<C-o>"] = {
    ---@type Bookmarks.KeymapCustomAction
    action = function(node, info)
      if info.type == 'bookmark' then
        vim.system({'open', info.dirname}, { text = true })
      end
    end,
    desc = "Open the current node with system default software",
  },
}
```

### Quick Navigation

| Command                   | Description                                                                         |
| ------------------------- | ----------------------------------------------------------------------------------- |
| `BookmarksGotoNext`       | Go to next bookmark in line number order within the current active BookmarkList     |
| `BookmarksGotoPrev`       | Go to previous bookmark in line number order within the current active BookmarkList |
| `BookmarksGotoNextInList` | Go to next bookmark by order id within the current active BookmarkList              |
| `BookmarksGotoPrevInList` | Go to next bookmark by order id within the current active BookmarkList              |

### More commands

| Command                        | Description                                                                      |
| ------------------------------ | -------------------------------------------------------------------------------- |
| `BookmarksDesc`                | Add description to the bookmark under cursor, if no bookmark, then mark it first |
| `BookmarksGrep`                | Grep through the content of all bookmarked files                                 |
| `BookmarksInfo`                | Overview plugin current status                                                   |
| `BookmarksInfoCurrentBookmark` | Show current bookmark info                                                       |
| `BookmarkRebindOrphanNode`     | Rebind orphaned nodes by attaching them to the root node                         |

### Keymap

This plugin doesn't provide any default keybinding. I recommend you to have these keybindings.

```lua
vim.keymap.set({ "n", "v" }, "mm", "<cmd>BookmarksMark<cr>", { desc = "Mark current line into active BookmarkList." })
vim.keymap.set({ "n", "v" }, "mo", "<cmd>BookmarksGoto<cr>", { desc = "Go to bookmark at current active BookmarkList" })
vim.keymap.set({ "n", "v" }, "ma", "<cmd>BookmarksCommands<cr>", { desc = "Find and trigger a bookmark command." })
```

## Advanced Usage

In this section, we will cover advanced usage of the bookmarks.nvim plugin, focusing on customization and programmatic interaction.

Check the [ADVANCED_USAGE.md](./ADVANCED_USAGE.md) for more detailed information on advanced configurations and usage.

local M = {}

-- Re-export snacks picker functions
M.pick_bookmark = require("bookmarks.picker.bookmark-picker").pick_bookmark
M.grep_bookmark = require("bookmarks.picker.bookmark-picker").grep_bookmark
M.pick_bookmark_list = require("bookmarks.picker.list-picker").pick_bookmark_list
M.pick_commands = require("bookmarks.picker.command-picker").pick_commands

return M

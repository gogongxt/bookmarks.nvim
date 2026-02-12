local Service = require("bookmarks.domain.service")
local Node = require("bookmarks.domain.node")
local Location = require("bookmarks.domain.location")
local Sign = require("bookmarks.sign")
local Tree = require("bookmarks.tree")

local M = {}

-- Get user commands from config
local function get_user_commands()
  local cfg = vim.g.bookmarks_config or {}
  return cfg.commands or {}
end

-- Merge built-in and user commands
M.get_all_commands = function()
  local commands = {}
  -- Add built-in commands
  for name, func in pairs(M) do
    if type(func) == "function" and name ~= "get_all_commands" then
      commands[name] = func
    end
  end
  -- Add user commands
  for name, func in pairs(get_user_commands()) do
    commands[name] = func
  end
  return commands
end

M.new_list = function()
  vim.ui.input({ prompt = "[Create new bookmark_list]" }, function(input)
    if input then
      local new_list = Service.create_list(input)
      Sign.safe_refresh_signs()
      pcall(Tree.refresh, new_list.id)
    end
  end)
end

M.current_file_bookmarks_to_new_list = function()
  local filepath = Location.get_current_location().path
  local bookmarks = Service.find_bookmarks_of_file(filepath)

  local new_list = Service.create_list(vim.fn.fnamemodify(filepath, ":t"))
  for _, bookmark in pairs(bookmarks) do
    local new_node = Node.new_from_node(bookmark)
    Service.new_bookmark(new_node, new_list.id)
  end
  Sign.safe_refresh_signs()
  pcall(Tree.refresh, new_list.id)
end

M.mark_selected_files = function()
  require("bookmarks.domain.service").mark_selected_files()
end

M["Show info of current bookmark"] = function()
  require("bookmarks.info").show_bookmark_info()
end

M.goto_bookmark = function()
  require("bookmarks.picker").pick_bookmark()
end

M.list_bookmarks = function()
  require("bookmarks.picker").pick_bookmark_list(function(list)
    if not list then
      return
    end
    Service.set_active_list(list.id)
    Sign.safe_refresh_signs()
    pcall(Tree.refresh, list.id)
  end)
end

return M

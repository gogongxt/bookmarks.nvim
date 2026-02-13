local Picker = require("bookmarks.picker")
local Service = require("bookmarks.domain.service")
local Repo = require("bookmarks.domain.repo")
local Node = require("bookmarks.domain.node")
local Sign = require("bookmarks.sign")
local Location = require("bookmarks.domain.location")
local Commands = require("bookmarks.commands")
local Tree = require("bookmarks.tree.operate")

local M = {}

M.setup = require("bookmarks.config").setup

M.toggle_mark = function()
  local b = Service.find_bookmark_by_location()
  local prompt = b and "[Edit Bookmark]" or "[New Bookmark]"
  local default_name = b and b.name or ""

  vim.ui.input({
    prompt = prompt,
    default = default_name,
  }, function(input)
    if input ~= nil then -- input is nil only if user cancels
      Service.toggle_mark(input)
      Sign.safe_refresh_signs()
      pcall(Tree.refresh)
    end
  end)
end

M.goto_bookmark = function()
  Picker.pick_bookmark(function(bookmark)
    if bookmark then
      Service.goto_bookmark(bookmark.id)
      Sign.safe_refresh_signs()
    end
  end)
end

M.goto_next_bookmark = function()
  Service.find_next_bookmark_line_order(function(bookmark)
    if bookmark then
      Service.goto_bookmark(bookmark.id)
      Sign.safe_refresh_signs()
    end
  end)
end

M.goto_prev_bookmark = function()
  Service.find_prev_bookmark_line_order(function(bookmark)
    if bookmark then
      Service.goto_bookmark(bookmark.id)
      Sign.safe_refresh_signs()
    end
  end)
end

M.goto_next_list_bookmark = function()
  Service.find_next_bookmark_id_order(function(bookmark)
    if bookmark then
      Service.goto_bookmark(bookmark.id)
      Sign.safe_refresh_signs()
    end
  end)
end

M.goto_prev_list_bookmark = function()
  Service.find_prev_bookmark_id_order(function(bookmark)
    if bookmark then
      Service.goto_bookmark(bookmark.id)
      Sign.safe_refresh_signs()
    end
  end)
end

M.grep_bookmarks = function()
  require("bookmarks.picker").grep_bookmark()
end

M.bookmark_lists = function()
  Picker.pick_bookmark_list(function(bookmark_list)
    if bookmark_list then
      Service.set_active_list(bookmark_list.id)
      M.goto_bookmark()
    end
  end)
end

M.create_bookmark_list = Commands.new_list

M.info = function()
  require("bookmarks.info").open()
end

M.bookmark_info = function()
  require("bookmarks.info").show_bookmark_info()
end

M.commands = function()
  Picker.pick_commands()
end

M.attach_desc = function()
  local bookmark = Service.find_bookmark_by_location() or Node.new_bookmark("")
  local popup = require("bookmarks.utils.window").description_window()

  -- Set buffer options
  vim.api.nvim_buf_set_option(popup.buf, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(popup.buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(popup.buf, "bufhidden", "wipe")

  -- Get existing bookmark description if any
  vim.api.nvim_buf_set_lines(popup.buf, 0, -1, false, vim.split(bookmark.description, "\n"))

  -- Set window options
  vim.api.nvim_win_set_option(popup.win, "wrap", true)
  vim.api.nvim_win_set_option(popup.win, "cursorline", true)
  vim.api.nvim_win_set_option(popup.win, "winbar", "Press <CR> to save, q to quit")

  -- Set keymaps
  vim.keymap.set("n", "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(popup.buf, 0, -1, false)
    local description = table.concat(lines, "\n")

    -- Check if all lines are empty (user wants to delete the bookmark)
    local is_empty = true
    for _, line in ipairs(lines) do
      if line:match("%S") then
        is_empty = false
        break
      end
    end

    if is_empty and bookmark.id then
      -- Delete bookmark if description is empty and bookmark exists
      Service.remove_bookmark(bookmark.id)
      Sign.safe_refresh_signs()
      pcall(Tree.refresh)
    elseif not is_empty then
      bookmark.description = description
      if bookmark.id then
        ---@cast bookmark Bookmarks.Node
        Repo.update_node(bookmark)
      else
        ---@cast bookmark Bookmarks.NewNode
        Service.new_bookmark(bookmark)
      end
      Sign.safe_refresh_signs()
      pcall(Tree.refresh)
    end
    vim.api.nvim_win_close(popup.win, true)
  end, { buffer = popup.buf })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(popup.win, true)
  end, { buffer = popup.buf })

  -- Set buffer title
  vim.api.nvim_win_set_cursor(popup.win, { 1, 0 })
end

M.toggle_treeview = function()
  require("bookmarks.tree").toggle()
end

M.rebind_orphan_node = function()
  Repo.rebind_orphan_node()
end

---Enable bookmark signs display
M.sign_enable = function()
  Sign.enable()
  vim.notify("Bookmarks signs enabled", vim.log.levels.INFO)
end

---Disable bookmark signs display
M.sign_disable = function()
  Sign.disable()
  vim.notify("Bookmarks signs disabled", vim.log.levels.INFO)
end

---Toggle bookmark signs display
M.sign_toggle = function()
  local new_state = Sign.toggle()
  if new_state then
    vim.notify("Bookmarks signs enabled", vim.log.levels.INFO)
  else
    vim.notify("Bookmarks signs disabled", vim.log.levels.INFO)
  end
end

return M

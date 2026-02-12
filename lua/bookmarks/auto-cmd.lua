local M = {}
local GROUP_NAME = "BookmarksNvimAutoCmd"

-- Track the current project root to detect changes
local current_project_root = nil

---Check if project root has changed and reinitialize if needed
local function check_project_root_change()
  -- Use current working directory as project root
  local project_root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")

  -- Ensure the path ends with '/'
  if not project_root:match("/$") then
    project_root = project_root .. "/"
  end

  -- Check if project root has changed
  if current_project_root ~= project_root then
    current_project_root = project_root

    -- Reinitialize the storage with new project root
    require("bookmarks.domain.repo").set_project_root(project_root)

    -- Recalculate storage path
    local bookmarks_dir = project_root .. ".nvim/bookmarks"
    if vim.fn.isdirectory(bookmarks_dir) == 0 then
      vim.fn.mkdir(bookmarks_dir, "p")
    end
    local storage_path = bookmarks_dir .. "/bookmarks.json"

    -- Reopen storage with new path
    require("bookmarks.domain.repo").setup(storage_path)

    -- Refresh signs for new project
    require("bookmarks.sign").safe_refresh_signs()

    -- Refresh tree if open
    pcall(require("bookmarks.tree.operate").refresh)
  end
end

M.setup = function()
  vim.api.nvim_create_augroup(GROUP_NAME, { clear = true })

  -- Check project root changes when entering buffers or windows
  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
    pattern = { "*" },
    group = GROUP_NAME,
    callback = check_project_root_change,
  })

  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "InsertLeave" }, {
    pattern = { "*" },
    group = GROUP_NAME,
    callback = function()
      require("bookmarks.sign").safe_refresh_signs()
      pcall(require("bookmarks.tree.operate").refresh)
    end,
  })

  -- Update bookmark positions from extmarks on file save
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = { "*" },
    group = GROUP_NAME,
    callback = function(ev)
      local Service = require("bookmarks.domain.service")
      local bufnr = ev.buf

      -- Only update if this is a real file (not a scratch buffer)
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      if filepath and filepath ~= "" then
        local result = Service.update_bookmark_positions_from_extmarks(bufnr)

        -- Optional: Notify if bookmarks were updated
        if result.updated > 0 then
          vim.notify(string.format("Updated %d bookmark position(s)", result.updated), vim.log.levels.INFO)
        end
      end
    end,
  })

  -- Initialize extmarks when file is read
  vim.api.nvim_create_autocmd("BufRead", {
    pattern = { "*" },
    group = GROUP_NAME,
    callback = function(ev)
      local Service = require("bookmarks.domain.service")
      local bufnr = ev.buf

      local created = Service.initialize_buffer_extmarks(bufnr)
      if created > 0 then
        -- Refresh signs to show bookmarks in newly opened buffer
        require("bookmarks.sign").safe_refresh_signs()
      end
    end,
  })

  -- Auto-fix bookmark positions on file save (handles yyp and other edits)
  vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = { "*" },
    group = GROUP_NAME,
    callback = function(ev)
      if vim.g.bookmarks_config and vim.g.bookmarks_config.signs.enable_auto_line_adjust then
        local bufnr = ev.buf
        local filepath = vim.api.nvim_buf_get_name(bufnr)

        -- Only fix if this file has bookmarks
        local Service = require("bookmarks.domain.service")
        local bookmarks = Service.find_bookmarks_of_file(filepath)
        if #bookmarks > 0 then
          -- Update bookmark positions from current extmarks
          Service.update_bookmark_positions_from_extmarks(bufnr)
        end
      end
    end,
  })

  -- Clean up tracking when buffer is unloaded
  vim.api.nvim_create_autocmd("BufUnload", {
    pattern = { "*" },
    group = GROUP_NAME,
    callback = function(ev)
      local bufnr = tonumber(ev.buf)
      if bufnr then
        require("bookmarks.tracker").clear_buffer(bufnr)
      end
    end,
  })
end

return M

local M = {}
local GROUP_NAME = "BookmarksNvimAutoCmd"

-- Track the current project root to detect changes
local current_project_root = nil

---Check if project root has changed and reinitialize if needed
local function check_project_root_change()
  -- Only check if using project-level databases (when db_dir is not set)
  if not vim.g.bookmarks_config or vim.g.bookmarks_config.db_dir then
    return
  end

  -- Use current working directory as project root
  local project_root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")

  -- Ensure the path ends with '/'
  if not project_root:match("/$") then
    project_root = project_root .. "/"
  end

  -- Check if project root has changed
  if current_project_root ~= project_root then
    current_project_root = project_root

    -- Reinitialize the database with new project root
    require("bookmarks.domain.repo").set_project_root(project_root)

    -- Recalculate database path
    local nvim_dir = project_root .. ".nvim"
    if vim.fn.isdirectory(nvim_dir) == 0 then
      vim.fn.mkdir(nvim_dir, "p")
    end
    local db_path = nvim_dir .. "/bookmarks.sqlite.db"

    -- Reopen database with new path
    require("bookmarks.domain.repo").setup(db_path)

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
      if
          vim.g.bookmarks_config
          and vim.g.bookmarks_config.calibrate
          and vim.g.bookmarks_config.calibrate.auto_calibrate_cur_buf
      then
        require("bookmarks.calibrate").calibrate_current_window()
        require("bookmarks.sign").safe_refresh_signs()
        pcall(require("bookmarks.tree.operate").refresh)
      else
        require("bookmarks.sign").safe_refresh_signs()
        pcall(require("bookmarks.tree.operate").refresh)
      end
    end,
  })
end

return M

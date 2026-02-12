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
end

return M

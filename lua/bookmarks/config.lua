local default_config = require("bookmarks.default-config")

---Get the project root directory
---@return string?
local function get_project_root()
  -- Use current working directory as the primary project root
  -- This is the directory where `nvim` was opened
  local cwd = vim.fn.getcwd()
  local project_root = vim.fn.fnamemodify(cwd, ":p")

  -- Ensure the path ends with '/'
  if not project_root:match("/$") then
    project_root = project_root .. "/"
  end

  return project_root
end

---Get the bookmarks storage file path for the project
---@return string
local function get_storage_path()
  local project_root = get_project_root()
  if not project_root then
    error("Failed to determine project root")
  end

  local bookmarks_dir = project_root .. ".nvim/bookmarks"

  -- Create .nvim/bookmarks directory if it doesn't exist
  if vim.fn.isdirectory(bookmarks_dir) == 0 then
    local ok = vim.fn.mkdir(bookmarks_dir, "p")
    if ok == 0 then
      error(string.format("Failed to create .nvim/bookmarks directory: %s", bookmarks_dir))
    end
  end

  return bookmarks_dir .. "/bookmarks.json"
end

---@param user_config? Bookmarks.Config
---@return nil
local setup = function(user_config)
  local cfg = vim.tbl_deep_extend("force", vim.g.bookmarks_config or default_config, user_config or {})
      or default_config
  vim.g.bookmarks_config = cfg

  local storage_path = get_storage_path()
  local project_root = get_project_root()

  -- Set project root for relative path conversion
  require("bookmarks.domain.repo").set_project_root(project_root)
  require("bookmarks.domain.repo").setup(storage_path)
  require("bookmarks.sign").setup(cfg.signs)
  require("bookmarks.auto-cmd").setup()
end

return {
  setup = setup,
  default_config = default_config,
}

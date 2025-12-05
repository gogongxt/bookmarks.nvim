local Repo = require("bookmarks.domain.repo")
local Service = require("bookmarks.domain.service")
local Node = require("bookmarks.domain.node")
local Actions = require("bookmarks.picker.actions")

local has_snacks, snacks = pcall(require, "snacks")
if not has_snacks then
  error("This picker requires snacks.nvim to be installed")
end

local M = {}

-- 设置书签 picker 的颜色高亮
local function setup_highlights()
  -- 检测当前主题并设置合适的颜色
  local is_dark = vim.o.background == "dark"

  if is_dark then
    -- 暗色主题配色
    vim.api.nvim_set_hl(0, "BookmarksName", {
      fg = "#82AAFF", -- 明亮蓝色
      bold = true,
    })

    vim.api.nvim_set_hl(0, "BookmarksFile", {
      fg = "#C3E88D", -- 明亮绿色
    })
  else
    -- 亮色主题配色
    vim.api.nvim_set_hl(0, "BookmarksName", {
      fg = "#1976D2", -- 深蓝色
      bold = true,
    })

    vim.api.nvim_set_hl(0, "BookmarksFile", {
      fg = "#388E3C", -- 深绿色
    })
  end
end

local function safe_string(str)
  if type(str) ~= "string" then
    return ""
  end
  return str
end

-- 缓存文件内容以提高性能
local file_cache = {}

-- Helper function to get the line content from file
local function get_line_content(file_path, line_num)
  if not file_path or not line_num or line_num <= 0 then
    return "<无效参数>"
  end

  -- 检查文件可读性
  if vim.fn.filereadable(file_path) ~= 1 then
    return "<文件不存在>"
  end

  -- 使用缓存提高性能
  local cache_key = file_path
  local lines = file_cache[cache_key]

  if not lines then
    -- 只读取文件的前1000行以避免大文件问题
    lines = vim.fn.readfile(file_path, "", 1000)
    file_cache[cache_key] = lines
  end

  if lines and #lines >= line_num then
    local line_content = lines[line_num]
    if line_content == nil then
      return "<行号超出范围>"
    end

    -- 移除尾部换行符和空白
    line_content = line_content:gsub("%s*$", "")

    -- 如果行为空，显示特殊标记
    if line_content == "" then
      return "<空行>"
    end

    -- 移除常见的控制字符，但保留空格和制表符
    line_content = line_content:gsub("[%c%z]", "")

    -- 如果行太长，截断并添加省略号
    if #line_content > 80 then
      line_content = vim.trim(line_content:sub(1, 77)) .. "..."
    end

    return line_content
  else
    return "<行号超出文件范围>"
  end
end

local function format_entry(bookmark, bookmarks)
  local name = ""
  local filename = ""
  local line_content = ""

  if bookmark then
    name = type(bookmark.name) == "string" and bookmark.name or ""
    if bookmark.location and type(bookmark.location.path) == "string" then
      filename = vim.fn.fnamemodify(bookmark.location.path, ":t") or ""
      -- 获取指定行的内容
      line_content = get_line_content(bookmark.location.path, bookmark.location.line or 1)
    end
  end

  -- 确保所有部分都是有效字符串
  name = tostring(name)
  filename = tostring(filename)
  line_content = tostring(line_content)

  return name .. " │ " .. filename .. " │ " .. line_content
end

-- Helper function to normalize file path
local function normalize_path(path)
  if not path or type(path) ~= "string" then
    return nil
  end

  -- Convert to absolute path if relative
  if not vim.startswith(path, "/") and not vim.startswith(path, "~") then
    path = vim.fn.fnamemodify(path, ":p")
  end

  -- Expand home directory
  if vim.startswith(path, "~") then
    path = vim.fn.expand(path)
  end

  -- Normalize the path
  path = vim.fn.fnamemodify(path, ":p")

  return path
end

---Pick a *bookmark* then call the callback function against it
---e.g.
---:lua require("bookmarks.picker.snacks.bookmark-picker").pick_bookmark(function(bookmark) vim.print(bookmark.name) end)
---@param callback fun(bookmark: Bookmarks.Node): nil
---@param opts? {prompt?: string, bookmarks?: Bookmarks.Node[]}
function M.pick_bookmark(callback, opts)
  opts = opts or {}

  local function start_picker(_bookmarks, list)
    -- 设置颜色高亮
    setup_highlights()

    -- 清理文件缓存，避免内存泄漏
    file_cache = {}

    -- Convert bookmarks to snacks picker items
    local items = {}
    for _, bookmark in ipairs(_bookmarks) do
      -- Basic validation only
      if bookmark and bookmark.location and bookmark.location.path then
        -- Validate all string fields to prevent encoding errors
        local name = bookmark.name or ""
        local path = bookmark.location.path or ""

        -- Only process if all required strings are valid
        if type(name) == "string" and type(path) == "string" and path ~= "" then
          -- Normalize the path for snacks picker
          local normalized_path = normalize_path(path)
          if normalized_path then
            local line_num = bookmark.location.line or 1
            local col_num = bookmark.location.col or 0

            -- 预读取行内容用于显示
            local line_content = get_line_content(normalized_path, line_num)
            local filename = vim.fn.fnamemodify(normalized_path, ":t") or ""

            -- 构建显示文本
            local file_with_line = filename .. ":" .. line_num

            -- 创建搜索和显示文本（统一使用字符串格式）
            local display_text = file_with_line .. " " .. name .. " " .. line_content

            table.insert(items, {
              text = display_text, -- 使用纯字符串格式，支持搜索
              bookmark_id = bookmark.id,
              file = normalized_path,
              line = line_num, -- snacks picker 使用的字段
              col = col_num,   -- snacks picker 使用的字段
              -- 关键：添加 pos 字段支持 preview 定位
              pos = { line_num, col_num },
              -- Add extra fields for better preview support
              title = file_with_line,
              -- 添加额外字段用于自定义格式化
              file_with_line = file_with_line,
              bookmark_name = name,
              line_content = line_content,
            })
          end
        end
      end
    end

    -- Create safe prompt
    local list_name = list and type(list.name) == "string" and list.name or "Unknown"
    local prompt = "Bookmarks in [" .. list_name .. "] "

    local picker_opts = {
      prompt = prompt,
      items = items,
      format = function(item)
        -- 自定义格式化：重新构建彩色显示
        if item.file_with_line and item.bookmark_name and item.line_content then
          -- 构建带颜色的显示文本
          local display_parts = {
            { item.file_with_line, "BookmarksFile" }, -- 第一列：文件名:行号（绿色）
            { " ",                 "Normal" },        -- 空格分隔
            { item.bookmark_name,  "BookmarksName" }, -- 第二列：书签名称（蓝色）
            { " ",                 "Normal" },        -- 空格分隔
            { item.line_content,   "Normal" },        -- 第三列：代码内容（默认颜色）
          }
          return display_parts
        else
          -- 兼容旧格式
          return { { tostring(item.text or "") } }
        end
      end,
      preview = snacks.picker.preview.file,
      actions = {
        confirm = function(picker, item)
          if item and item.bookmark_id then
            -- 先关闭 picker
            picker:close()

            -- 使用 vim.schedule 延迟执行，确保 picker 完全关闭
            vim.schedule(function()
              local ok, err = pcall(require("bookmarks.domain.service").goto_bookmark, item.bookmark_id)
              if not ok then
                vim.notify("Failed to goto bookmark: " .. tostring(err), vim.log.levels.ERROR)
              end
            end)
          end
        end,
        delete = function(picker)
          local selected_items = picker:selected({ fallback = true })
          if #selected_items > 0 then
            local selected = selected_items[1]
            if selected and selected.bookmark_id then
              -- Delete the bookmark using the service
              local ok, err = pcall(require("bookmarks.domain.service").delete_node, selected.bookmark_id)
              if ok then
                -- Restart the picker with a slight delay
                local opts = picker.opts
                picker:close()
                vim.defer_fn(function()
                  M.pick_bookmark(nil, { prompt = opts.prompt })
                end, 50)
              else
                vim.notify("Failed to delete bookmark: " .. tostring(err), vim.log.levels.ERROR)
              end
            end
          end
        end,
        open_split = function(picker)
          local selected_items = picker:selected({ fallback = true })
          if #selected_items > 0 then
            local selected = selected_items[1]
            if selected and selected.bookmark_id then
              local ok, err =
                  pcall(require("bookmarks.domain.service").goto_bookmark, selected.bookmark_id, { cmd = "split" })
              if not ok then
                vim.notify("Failed to open bookmark in split: " .. tostring(err), vim.log.levels.ERROR)
              end
            end
          end
        end,
        open_vsplit = function(picker)
          local selected_items = picker:selected({ fallback = true })
          if #selected_items > 0 then
            local selected = selected_items[1]
            if selected and selected.bookmark_id then
              local ok, err =
                  pcall(require("bookmarks.domain.service").goto_bookmark, selected.bookmark_id, { cmd = "vsplit" })
              if not ok then
                vim.notify("Failed to open bookmark in vsplit: " .. tostring(err), vim.log.levels.ERROR)
              end
            end
          end
        end,
        open_tab = function(picker)
          local selected_items = picker:selected({ fallback = true })
          if #selected_items > 0 then
            local selected = selected_items[1]
            if selected and selected.bookmark_id then
              local ok, err =
                  pcall(require("bookmarks.domain.service").goto_bookmark, selected.bookmark_id, { cmd = "tabnew" })
              if not ok then
                vim.notify("Failed to open bookmark in tab: " .. tostring(err), vim.log.levels.ERROR)
              end
            end
          end
        end,
      },
      -- Enhanced preview options
      previewers = {
        file = {
          max_size = 1024 * 1024, -- 1MB
          max_line_length = 1000,
        },
      },
      win = {
        input = {
          keys = {
            ["<CR>"] = { "confirm", mode = { "n", "i" } },
            ["<C-d>"] = { "delete", mode = { "n", "i" } },
            ["<C-x>"] = { "open_split", mode = { "n", "i" } },
            ["<C-v>"] = { "open_vsplit", mode = { "n", "i" } },
            ["<C-t>"] = { "open_tab", mode = { "n", "i" } },
          },
        },
        list = {
          keys = {
            ["<CR>"] = "confirm",
            ["<C-d>"] = "delete",
            ["<C-x>"] = "open_split",
            ["<C-v>"] = "open_vsplit",
            ["<C-t>"] = "open_tab",
          },
        },
        preview = {
          keys = {
            ["<CR>"] = "confirm",
            ["<2-LeftMouse>"] = "confirm",
            ["<C-d>"] = "delete",
            ["<C-x>"] = "open_split",
            ["<C-v>"] = "open_vsplit",
            ["<C-t>"] = "open_tab",
          },
        },
      },
    }

    snacks.picker(picker_opts)
  end

  if opts.bookmarks then
    start_picker(opts.bookmarks, { name = "Custom Selection" })
  else
    local active_list = Repo.ensure_and_get_active_list()
    start_picker(Node.get_all_bookmarks(active_list), active_list)
  end
end

---Grep through the content of all bookmarked files
---@param opts? table
function M.grep_bookmark(opts)
  opts = opts or {}
  local active_list = Repo.ensure_and_get_active_list()
  local bookmarks = Node.get_all_bookmarks(active_list)

  -- Get unique file paths from bookmarks
  local files = {}
  local seen = {}
  for _, bookmark in ipairs(bookmarks) do
    if bookmark.location and bookmark.location.path then
      local path = bookmark.location.path
      local normalized_path = normalize_path(path)
      if normalized_path and not seen[normalized_path] then
        seen[normalized_path] = true
        table.insert(files, normalized_path)
      end
    end
  end

  if #files == 0 then
    vim.notify("No readable bookmarked files found", vim.log.levels.WARN)
    return
  end

  -- Use snacks grep picker
  snacks.picker(
    "grep",
    vim.tbl_extend("force", {
      prompt = "Grep Bookmarked Files",
      search_dirs = files,
    }, opts)
  )
end

return M

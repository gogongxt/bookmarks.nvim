local Repo = require("bookmarks.domain.repo")
local Service = require("bookmarks.domain.service")
local Node = require("bookmarks.domain.node")

local has_snacks, snacks = pcall(require, "snacks")
if not has_snacks then
  error("This picker requires snacks.nvim to be installed")
end

local M = {}

---Pick a *bookmark_list* then call the callback function against it
---e.g.
---:lua require("bookmarks.picker.snacks.list-picker").pick_bookmark_list(function(list) vim.print(list.name) end)
---@param callback fun(list: Bookmarks.Node): nil
---@param opts? {prompt?: string}
function M.pick_bookmark_list(callback, opts)
  opts = opts or {}

  local function start_picker(_lists)
    -- Convert lists to snacks picker items
    local items = {}
    for _, list in ipairs(_lists) do
      table.insert(items, {
        text = list.name,
        list = list,
      })
    end

    local picker_opts = {
      prompt = opts.prompt or "Bookmark Lists: ",
      items = items,
      format = function(item)
        return { { item.text } }
      end,
      actions = {
        confirm = function(picker)
          local selected_items = picker:selected({ fallback = true })
          if #selected_items > 0 then
            local selected = selected_items[1]
            picker:close()
            callback(selected.list)
          end
        end,
        delete = function(picker)
          local selected_items = picker:selected({ fallback = true })
          if #selected_items > 0 then
            local selected = selected_items[1]
            local ok, err = pcall(Service.delete_node, selected.list.id)
            if ok then
              picker:close()
              start_picker(Repo.find_lists())
            else
              vim.notify("Failed to delete list: " .. tostring(err), vim.log.levels.ERROR)
            end
          end
        end,
      },
      win = {
        input = {
          keys = {
            ["<CR>"] = { "confirm", mode = { "n", "i" } },
            ["<C-d>"] = { "delete", mode = { "n", "i" } },
          },
        },
        list = {
          keys = {
            ["<CR>"] = "confirm",
            ["<C-d>"] = "delete",
          },
        },
        preview = {
          keys = {
            ["<CR>"] = "confirm",
            ["<2-LeftMouse>"] = "confirm",
            ["<C-d>"] = "delete",
          },
        },
      },
    }

    snacks.picker(picker_opts)
  end

  start_picker(Repo.find_lists())
end

return M

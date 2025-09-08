local Command = require("bookmarks.commands")

local has_snacks, snacks = pcall(require, "snacks")
if not has_snacks then
  error("This picker requires snacks.nvim to be installed")
end

local M = {}

---Pick a command then execute it
---@param opts? {prompt?: string}
function M.pick_commands(opts)
  opts = opts or {}

  -- Get all commands from the Command module
  local commands = {}
  for name, func in pairs(Command.get_all_commands()) do
    if type(func) == "function" then
      table.insert(commands, {
        name = name,
        execute = func,
      })
    end
  end

  -- Convert commands to snacks picker items
  local items = {}
  for _, command in ipairs(commands) do
    table.insert(items, {
      text = command.name,
      command = command,
    })
  end

  local picker_opts = {
    prompt = opts.prompt or "Bookmarks Commands",
    items = items,
    format = function(item)
      return { { item.text } }
    end,
    actions = {
      confirm = function(picker)
        local selected = picker:selected()[1]
        if selected then
          picker:close()
          selected.command.execute()
        end
      end,
    },
    win = {
      input = {
        keys = {
          ["<CR>"] = { "confirm", mode = { "n", "i" } },
        },
      },
      list = {
        keys = {
          ["<CR>"] = "confirm",
        },
      },
      preview = {
        keys = {
          ["<CR>"] = "confirm",
        },
      },
    },
  }

  snacks.picker(picker_opts)
end

return M

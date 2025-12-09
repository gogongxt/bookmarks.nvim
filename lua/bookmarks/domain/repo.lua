local Node = require("bookmarks.domain.node")
local Location = require("bookmarks.domain.location")

local M = {}

-- Store the project root for path conversion
local project_root = nil
local data = nil
local file_path = nil

---Set the project root for relative path conversion
---@param root string The project root directory
function M.set_project_root(root)
  project_root = vim.fn.fnamemodify(root, ":p")
end

---Initialize the file-based storage and create root node if it doesn't exist
---@param db_path string Path to the database file (will be converted to .json)
function M.setup(db_path)
  -- Convert .db to .json file extension
  local json_path = db_path:gsub("%.db$", ".json")
  file_path = json_path
  M.load_data()
  M._DB = M
end

---Load data from file or create new structure
function M.load_data()
  if vim.fn.filereadable(file_path) == 1 then
    local content = vim.fn.readfile(file_path)
    if #content > 0 then
      local json_content = table.concat(content, "\n")
      local ok, parsed = pcall(vim.json.decode, json_content)
      if ok then
        data = parsed
        return
      else
        vim.notify("Failed to parse bookmarks JSON file, creating new one", vim.log.levels.WARN)
      end
    end
  end

  -- Create new data structure
  data = {
    version = "1.0",
    project_root = project_root,
    created_at = os.time(),
    updated_at = os.time(),
    next_id = 1,
    active_list_id = 0,
    nodes = {},
    bookmark_links = {}
  }

  -- Create root node
  data.nodes["0"] = {
    id = 0,
    name = "root",
    type = "list",
    description = "root",
    created_at = os.time(),
    is_expanded = true,
    children = {}
  }
end

---Save data to file
function M.save_data()
  if not data or not file_path then
    return
  end

  data.updated_at = os.time()

  -- Create directory if it doesn't exist
  local dir = vim.fn.fnamemodify(file_path, ":h")
  vim.fn.mkdir(dir, "p")

  local json_content = vim.json.encode(data)

  -- Format JSON for better readability using vim.fn.system with jq if available
  local formatted_json
  if vim.fn.executable("jq") == 1 then
    formatted_json = vim.fn.system("jq .", json_content):gsub("%s+$", "")
    if vim.v.shell_error ~= 0 then
      -- Fallback to unformatted JSON if jq fails
      formatted_json = json_content
    end
  else
    -- Fallback to manual formatting if jq is not available
    formatted_json = vim.fn.system("python3 -m json.tool", json_content):gsub("%s+$", "")
    if vim.v.shell_error ~= 0 then
      -- Fallback to unformatted JSON if python json.tool fails
      formatted_json = json_content
    end
  end

  local ok, err = pcall(vim.fn.writefile, vim.split(formatted_json, "\n"), file_path)
  if not ok then
    error("Failed to save bookmarks file: " .. err)
  end
end

---Convert absolute path to relative path for storage
---@param abs_path string The absolute path
---@return string The relative path
local function to_relative_path(abs_path)
  if not project_root then
    return abs_path
  end

  -- Normalize project_root to ensure it ends with /
  local normalized_root = project_root
  if not normalized_root:match("/$") then
    normalized_root = normalized_root .. "/"
  end

  -- Normalize abs_path to ensure it doesn't have trailing slash (unless it's root)
  local normalized_abs = abs_path
  if normalized_abs ~= "/" and normalized_abs:match("/$") then
    normalized_abs = normalized_abs:sub(1, -2)
  end

  -- Convert to relative path if the file is under project root
  if normalized_abs:sub(1, #normalized_root) == normalized_root then
    return normalized_abs:sub(#normalized_root + 1)
  end

  -- Fallback to absolute path if outside project
  return normalized_abs
end

---Convert relative path to absolute path for usage
---@param rel_path string The relative path
---@return string The absolute path
local function to_absolute_path(rel_path)
  if not project_root then
    return rel_path
  end

  if rel_path:match("^/") then
    return rel_path -- Already absolute path
  end

  -- Ensure project_root ends with / for concatenation
  local root = project_root
  if not root:match("/$") then
    root = root .. "/"
  end

  return root .. rel_path
end

---Convert a node to storage format
---@param node Bookmarks.Node | Bookmarks.NewNode
---@return table
local function node_to_storage(node)
  local storage_node = {
    id = node.id,
    type = node.type,
    name = node.name,
    description = node.description,
    content = node.content,
    githash = node.githash,
    created_at = node.created_at,
    visited_at = node.visited_at,
    is_expanded = node.is_expanded,
    linked_bookmarks = node.linked_bookmarks or {},
  }

  if node.location then
    -- Store path as relative to project root
    storage_node.location = {
      path = to_relative_path(node.location.path),
      line = node.location.line,
      col = node.location.col
    }
  end

  -- For list nodes, store children IDs
  if node.type == "list" and node.children then
    storage_node.children = {}
    for _, child in ipairs(node.children) do
      table.insert(storage_node.children, child.id)
    end
  end

  return storage_node
end

---Convert storage format to node
---@param storage_node table
---@return Bookmarks.Node
local function storage_to_node(storage_node)
  local node = {
    id = storage_node.id,
    type = storage_node.type,
    name = storage_node.name,
    description = storage_node.description,
    content = storage_node.content,
    githash = storage_node.githash,
    created_at = storage_node.created_at,
    visited_at = storage_node.visited_at,
    is_expanded = storage_node.is_expanded,
    children = {},
    linked_bookmarks = storage_node.linked_bookmarks or {},
  }

  if storage_node.location then
    -- Convert stored relative path back to absolute path
    node.location = {
      path = to_absolute_path(storage_node.location.path),
      line = storage_node.location.line,
      col = storage_node.location.col,
    }
  end

  return node
end

---Get next available ID
---@return number
local function get_next_id()
  local id = data.next_id
  data.next_id = data.next_id + 1
  return id
end

---Find a node by its ID, recursively with children
---@param target_id number
---@return Bookmarks.Node?
function M.find_node(target_id)
  local storage_node = data.nodes[tostring(target_id)]
  if not storage_node then
    return nil
  end

  local node = storage_to_node(storage_node)

  -- Set order for bookmark nodes based on their position in parent's children
  if node.type == "bookmark" then
    node.order = M.get_node_order(target_id)
  end

  -- Load children for list nodes
  if node.type == "list" and storage_node.children then
    for i, child_id in ipairs(storage_node.children) do
      local child = M.find_node(child_id)
      if child then
        child.order = i - 1  -- Set order based on position in children array
        table.insert(node.children, child)
      end
    end
  end

  return node
end

---Get the order of a node in its parent's children array
---@param node_id number
---@return number
function M.get_node_order(node_id)
  for _, storage_node in pairs(data.nodes) do
    if storage_node.children then
      for i, child_id in ipairs(storage_node.children) do
        if child_id == node_id then
          return i - 1  -- 0-based index
        end
      end
    end
  end
  return 0
end

---Insert a new node into the storage
---@param node Bookmarks.NewNode
---@param parent_id number?
---@return number # The ID of the inserted node
function M.insert_node(node, parent_id)
  parent_id = parent_id or 0
  local id = get_next_id()
  node.id = id

  local storage_node = node_to_storage(node)
  data.nodes[tostring(id)] = storage_node

  -- Add to parent's children
  local parent = data.nodes[tostring(parent_id)]
  if parent and parent.type == "list" then
    if not parent.children then
      parent.children = {}
    end
    table.insert(parent.children, id)
  end

  M.save_data()
  return id
end

---Update an existing node
---@param node Bookmarks.Node
---@return Bookmarks.Node
function M.update_node(node)
  local storage_node = node_to_storage(node)

  -- Preserve children from existing node if this is a list
  local existing = data.nodes[tostring(node.id)]
  if existing and existing.type == "list" and storage_node.type == "list" then
    storage_node.children = existing.children
  end

  data.nodes[tostring(node.id)] = storage_node
  M.save_data()
  return M.find_node(node.id)
end

---Get all bookmark nodes
---@return Bookmarks.Node[] # Array of bookmark nodes
function M.get_all_bookmarks()
  local results = {}

  for _, storage_node in pairs(data.nodes) do
    if storage_node.type == "bookmark" then
      local node = storage_to_node(storage_node)
      node.order = M.get_node_order(storage_node.id)
      table.insert(results, node)
    end
  end

  return results
end

---Delete a node and all its relationships
---@param node_id number
function M.delete_node(node_id)
  local node_str = tostring(node_id)
  local storage_node = data.nodes[node_str]

  if not storage_node then
    return
  end

  -- If it's a list, delete all children recursively
  if storage_node.type == "list" and storage_node.children then
    for _, child_id in ipairs(storage_node.children) do
      M.delete_node(child_id)
    end
  end

  -- Remove from parent's children
  for _, parent_node in pairs(data.nodes) do
    if parent_node.children then
      local new_children = {}
      for _, child_id in ipairs(parent_node.children) do
        if child_id ~= node_id then
          table.insert(new_children, child_id)
        end
      end
      parent_node.children = new_children
    end
  end

  -- Remove bookmark links
  data.bookmark_links = vim.tbl_filter(function(link)
    return link.bookmark_id ~= node_id and link.linked_bookmark_id ~= node_id
  end, data.bookmark_links)

  -- Remove the node itself
  data.nodes[node_str] = nil

  M.save_data()
end

---Add a node to a list
---@param node_id number # The ID of the node to add
---@param parent_id number # The ID of the list to add to
function M.add_to_list(node_id, parent_id)
  local parent = data.nodes[tostring(parent_id)]
  if parent and parent.type == "list" then
    if not parent.children then
      parent.children = {}
    end

    -- Check if node is already in the list
    for _, child_id in ipairs(parent.children) do
      if child_id == node_id then
        return -- Already in list
      end
    end

    table.insert(parent.children, node_id)
    M.save_data()
  end
end

---Remove a node from a list (delete relationship only)
---@param node_id number
---@param list_id number
function M.remove_from_list(node_id, list_id)
  local parent = data.nodes[tostring(list_id)]
  if parent and parent.children then
    local new_children = {}
    for _, child_id in ipairs(parent.children) do
      if child_id ~= node_id then
        table.insert(new_children, child_id)
      end
    end
    parent.children = new_children
    M.save_data()
  end
end

---Move a node from one list to another
---@param node_id number
---@param from_list_id number
---@param to_list_id number
function M.move_node(node_id, from_list_id, to_list_id)
  M.remove_from_list(node_id, from_list_id)
  M.add_to_list(node_id, to_list_id)
end

---Toggle a list's expanded state
---@param list_id number
---@return Bookmarks.Node
function M.toggle_list_expanded(list_id)
  local storage_node = data.nodes[tostring(list_id)]
  if not storage_node or storage_node.type ~= "list" then
    error("Node not found or not a list")
  end

  storage_node.is_expanded = not storage_node.is_expanded
  M.save_data()
  return M.find_node(list_id)
end

---Set the active list
---@param list_id number
function M.set_active_list(list_id)
  local node = data.nodes[tostring(list_id)]
  if not node or node.type ~= "list" then
    error("Invalid list")
  end

  data.active_list_id = list_id

  -- Update visited time
  node.visited_at = os.time()
  M.save_data()
end

---Ensure and get the active list
---@return Bookmarks.Node
function M.ensure_and_get_active_list()
  if data.active_list_id then
    local node = M.find_node(data.active_list_id)
    if node and node.type == "list" then
      return node
    end
  end

  -- Fallback to root
  local root = M.find_node(0)
  if not root then
    error("Failed to fallback to root list")
  end

  data.active_list_id = 0
  M.save_data()
  return root
end

---Find a bookmark by location
---@param location Bookmarks.Location
---@param opts? { all_bookmarks: boolean }
---@return Bookmarks.Node?
function M.find_bookmark_by_location(location, opts)
  opts = opts or {}
  local search_path = to_relative_path(location.path)

  for _, storage_node in pairs(data.nodes) do
    if storage_node.type == "bookmark" and
       storage_node.location and
       storage_node.location.path == search_path and
       storage_node.location.line == location.line then

      if not opts.all_bookmarks then
        -- Check if bookmark is in active list
        local active_list = M.ensure_and_get_active_list()
        local found_in_active = false

        for _, child_id in ipairs(active_list.children or {}) do
          if child_id == storage_node.id then
            found_in_active = true
            break
          end
        end

        if not found_in_active then
          goto continue
        end
      end

      local node = storage_to_node(storage_node)
      node.order = M.get_node_order(storage_node.id)
      return node
    end

    ::continue::
  end

  return nil
end

---Find all lists except the root list, ordered by creation date
---@return Bookmarks.Node[]
function M.find_lists()
  local results = {}

  local lists = {}
  for _, storage_node in pairs(data.nodes) do
    if storage_node.type == "list" and storage_node.id ~= 0 then
      table.insert(lists, storage_node)
    end
  end

  -- Sort by creation date
  table.sort(lists, function(a, b)
    return a.created_at > b.created_at
  end)

  for _, storage_node in ipairs(lists) do
    table.insert(results, storage_to_node(storage_node))
  end

  return results
end

---Find a node by location
---@param location Bookmarks.Location
---@return Bookmarks.Node?
function M.find_node_by_location(location)
  return M.find_bookmark_by_location(location, { all_bookmarks = true })
end

---Find bookmarks of a given file path within a list
---@param path string The file path to search for
---@param list_id? number Optional list ID. If not provided, uses the active list
---@return Bookmarks.Node[] Array of bookmark nodes in the specified list
function M.find_bookmarks_by_path(path, list_id)
  if not list_id then
    local active_list = M.ensure_and_get_active_list()
    list_id = active_list.id
  end

  local search_path = to_relative_path(path)
  local parent = data.nodes[tostring(list_id)]
  if not parent or not parent.children then
    return {}
  end

  local results = {}
  for _, child_id in ipairs(parent.children) do
    local child = data.nodes[tostring(child_id)]
    if child and child.type == "bookmark" and
       child.location and child.location.path == search_path then
      local node = storage_to_node(child)
      node.order = M.get_node_order(child.id)
      table.insert(results, node)
    end
  end

  return results
end

---Get the parent ID of a node
---@param node_id number The ID of the node to find the parent for
---@return number parent_id Returns the parent ID or nil if not found
function M.get_parent_id(node_id)
  if node_id == 0 then
    return 0
  end

  for _, storage_node in pairs(data.nodes) do
    if storage_node.children then
      for _, child_id in ipairs(storage_node.children) do
        if child_id == node_id then
          return storage_node.id
        end
      end
    end
  end

  error("Orphan Node, check your data for node id: " .. node_id)
end

---Clean dirty nodes
function M.clean_dirty_nodes()
  local to_remove = {}

  for id, storage_node in pairs(data.nodes) do
    if storage_node.type == "bookmark" and not storage_node.location then
      table.insert(to_remove, id)
    end
  end

  for _, id in ipairs(to_remove) do
    M.delete_node(tonumber(id))
  end
end

---Insert a node at a specific position in a list
---@param node Bookmarks.NewNode The node to insert
---@param parent_id number The parent list ID
---@param position number The position to insert at
---@return number # The ID of the inserted node
function M.insert_node_at_position(node, parent_id, position)
  local id = get_next_id()
  node.id = id

  local storage_node = node_to_storage(node)
  data.nodes[tostring(id)] = storage_node

  -- Insert at specific position in parent's children
  local parent = data.nodes[tostring(parent_id)]
  if parent and parent.type == "list" then
    if not parent.children then
      parent.children = {}
    end

    -- Validate position
    if position < 0 then
      position = 0
    elseif position > #parent.children then
      position = #parent.children
    end

    table.insert(parent.children, position + 1, id)
  end

  M.save_data()
  return id
end

---Find and fix orphaned nodes by attaching them to the root node
function M.rebind_orphan_node()
  -- Find all nodes that have parents
  local has_parent = {}
  for _, storage_node in pairs(data.nodes) do
    if storage_node.children then
      for _, child_id in ipairs(storage_node.children) do
        has_parent[child_id] = true
      end
    end
  end

  -- Find orphaned nodes and attach them to root
  local root = data.nodes["0"]
  if not root then
    return
  end

  if not root.children then
    root.children = {}
  end

  for id, storage_node in pairs(data.nodes) do
    local node_id = tonumber(id)
    if node_id ~= 0 and not has_parent[node_id] then
      table.insert(root.children, node_id)
    end
  end

  M.save_data()
end

---Link two bookmarks
---@param bookmark_id number
---@param linked_bookmark_id number
function M.link_bookmarks(bookmark_id, linked_bookmark_id)
  if bookmark_id == linked_bookmark_id then
    return
  end

  -- Check if link already exists
  for _, link in ipairs(data.bookmark_links) do
    if link.bookmark_id == bookmark_id and link.linked_bookmark_id == linked_bookmark_id then
      return -- Already linked
    end
  end

  table.insert(data.bookmark_links, {
    bookmark_id = bookmark_id,
    linked_bookmark_id = linked_bookmark_id,
    created_at = os.time()
  })

  M.save_data()
end

---Unlink two bookmarks
---@param bookmark_id number
---@param linked_bookmark_id number
function M.unlink_bookmarks(bookmark_id, linked_bookmark_id)
  data.bookmark_links = vim.tbl_filter(function(link)
    return not (link.bookmark_id == bookmark_id and link.linked_bookmark_id == linked_bookmark_id)
  end, data.bookmark_links)

  M.save_data()
end

---Get outgoing linked bookmark IDs for a given bookmark
---@param bookmark_id number
---@return number[]
function M.get_linked_out_bookmarks(bookmark_id)
  local linked_ids = {}
  for _, link in ipairs(data.bookmark_links) do
    if link.bookmark_id == bookmark_id then
      table.insert(linked_ids, link.linked_bookmark_id)
    end
  end
  return linked_ids
end

---Get incoming linked bookmark IDs for a given bookmark
---@param bookmark_id number
---@return number[]
function M.get_linked_in_bookmarks(bookmark_id)
  local linked_ids = {}
  for _, link in ipairs(data.bookmark_links) do
    if link.linked_bookmark_id == bookmark_id then
      table.insert(linked_ids, link.bookmark_id)
    end
  end
  return linked_ids
end

return M
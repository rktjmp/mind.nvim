local mind_commands = require'mind.commands'
local mind_keymap = require'mind.keymap'
local mind_node = require'mind.node'
local mind_state = require'mind.state'

local M = {}

local function create_user_commands()
  vim.api.nvim_create_user_command(
    'MindOpenMain',
    function()
      require'mind'.open_main()
    end,
    { desc = 'Open the main Mind tree', }
  )

  vim.api.nvim_create_user_command(
    'MindOpenProject',
    function(opts)
      require'mind'.open_project(opts.fargs[1] == 'global')
    end,
    {
      nargs = '?',
      desc = 'Open the project Mind tree',
    }
  )

  vim.api.nvim_create_user_command(
    'MindReloadState',
    function(opts)
      require'mind'.reload_state()
    end,
    {
      desc = 'Reload Mind internal state',
    }
  )
end

M.setup = function(opts)
  M.opts = vim.tbl_deep_extend('force', require'mind.defaults', opts or {})

  -- load tree state
  mind_state.load_state(M.opts)

  -- keymaps
  mind_keymap.init_keymaps(M.opts)
  mind_commands.precompute_commands()

  -- user-commands
  create_user_commands()
end

-- Open the main tree.
M.open_main = function()
  mind_commands.open_tree(mind_state.state.tree, M.opts.persistence.data_dir, M.opts)
end

-- Open a project tree.
--
-- If `use_global` is set to `true`, will use the global persistence location.
M.open_project = function(use_global)
  M.wrap_project_tree_fn(
    function(args)
      mind_commands.open_tree(args.tree, args.data_dir, args.opts)
    end,
    use_global,
    M.opts
  )
end

-- Load state.
M.reload_state = function()
  mind_state.load_state(M.opts)
end

-- Wrap a function call expecting the main tree.
M.wrap_main_tree_fn = function(f, opts)
  opts = vim.tbl_deep_extend('force', M.opts, opts or {})
  local args = {
    tree = mind_state.state.tree,
    data_dir = opts.persistence.data_dir,
    opts = opts
  }
  f(args)
end

-- Wrap a function call expecting a project tree.
--
-- If the project tree doesn’t exist, it is automatically created.
M.wrap_project_tree_fn = function(f, use_global, opts)
  opts = vim.tbl_deep_extend('force', M.opts, opts or {})

  local cwd = vim.fn.getcwd()
  local tree
  if (use_global) then
    tree = mind_state.state.projects[cwd]

    if (tree == nil) then
      tree = {
        contents = {
          { text = cwd:match('^.+/(.+)$') },
        },
        type = mind_node.TreeType.ROOT,
        icon = opts.ui.root_marker,
      }
      mind_state.state.projects[cwd] = tree
    end
  else
    if mind_state.local_tree == nil then
      mind_state.local_tree = {
        contents = {
          { text = cwd:match('^.+/(.+)$') },
        },
        type = mind_node.TreeType.LOCAL_ROOT,
        icon = opts.ui.root_marker,
      }
    end

    tree = mind_state.local_tree
  end

  local args = {
    tree = tree,
    data_dir = mind_state.get_project_data_dir(opts),
    opts = opts
  }

  f(args)
end

return M

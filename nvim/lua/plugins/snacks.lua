return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = function(_, opts)
    opts.indent = opts.indent or {}
    opts.indent.enabled = false

    opts.scope = opts.scope or {}
    opts.scope.enabled = false

    opts.scroll = opts.scroll or {}
    opts.scroll.enabled = false

    opts.picker = opts.picker or {}
    opts.picker.matcher = vim.tbl_deep_extend("force", opts.picker.matcher or {}, {
      smartcase = false,
      ignorecase = true,
    })

    opts.dashboard = opts.dashboard or {}
    opts.dashboard.enabled = true
    opts.dashboard.preset = {
      header = [[
                    ░░░░░░      ░░░░░░                        
                  ░░░░░░░░░░  ░░░░░░░░░░                      
                ░░░░░░░░░░░░░░░░░░░░░░░░░░                    
              ░░░░░░░░░░▒▒▒▒░░▒▒▒▒░░░░░░░░░░                  
  ░░░░      ░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░        ░░░░    
▒▒░░      ░░░░░░▒▒▒▒▒▒▒▒▒▒██▒▒██▒▒▒▒▒▒▒▒▒▒░░░░░░        ▒▒░░  
▒▒░░    ░░░░░░░░▒▒▒▒▒▒▒▒▒▒████▒▒████▒▒▒▒▒▒▒▒▒▒░░░░░░░░  ▒▒░░▒ 
▒▒▒▒░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒██████▒▒██████▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░▒▒▒ 
██▒▒▒▒▒▒▒▒▒▒▒▒▒▒██▒▒▒▒██████▓▓██▒▒██████▒▒▓▓██▒▒▒▒▒▒▒▒▒▒▒▒▒▒█ 
████▒▒▒▒▒▒████▒▒▒▒██████████  ██████████▒▒▒▒████▒▒▒▒▒▒▒▒██    
  ████████████████████████      ████████████████████████      
    ██████████████████              ██████████████████        
        ██████████                      ██████████            
]],
        -- stylua: ignore
        keys = {
          { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
          { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
          { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
          { icon = " ", key = "s", desc = "Restore Session", section = "session" },
          { icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
          { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
    }

    opts.picker.sources = opts.picker.sources or {}
    local files_source = opts.picker.sources.files or {}
    local args = files_source.args or {}

    local has_ignore_case = false
    for _, value in ipairs(args) do
      if value == "--ignore-case" or value == "-i" then
        has_ignore_case = true
        break
      end
    end

    if not has_ignore_case then
      table.insert(args, "--ignore-case")
    end

    files_source.args = args
    opts.picker.sources.files = files_source
    local function session_path_for_cwd()
      local state = vim.fn.stdpath("state") .. "/sessions"
      local cwd = vim.fn.getcwd()
      local name = cwd:gsub("[/\\:]", "%%")
      return state .. "/" .. name .. ".vim"
    end

    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        local argc = vim.fn.argc()
        local allow = (argc == 0) or (argc == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1)
        if not allow then
          return
        end

        local session = session_path_for_cwd()
        if vim.fn.filereadable(session) ~= 1 then
          -- No session: ensure snacks is loaded and show dashboard
          pcall(function()
            local ok_lazy, lazy = pcall(require, "lazy")
            if ok_lazy and lazy and lazy.load then
              pcall(lazy.load, { plugins = { "snacks.nvim" } })
            end
            local ok, snacks = pcall(require, "snacks")
            if ok and snacks.dashboard and snacks.dashboard.show then
              snacks.dashboard.show()
            end
          end)
        end
      end,
    })
  end,
}

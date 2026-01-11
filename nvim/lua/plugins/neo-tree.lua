return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    keys = function(_, keys)
      local function toggle_tree_with_terminal()
        local function any_win_with_ft(ft)
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == ft then
              return true
            end
          end
          return false
        end

        local prev = vim.api.nvim_get_current_win()
        if any_win_with_ft("neo-tree") then
          -- Close neo-tree and any tagged terminal under its column
          pcall(vim.cmd, "Neotree close")
          local tab = vim.api.nvim_get_current_tabpage()
          for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
            local b = vim.api.nvim_win_get_buf(w)
            if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == "terminal" then
              local ok, flag = pcall(vim.api.nvim_buf_get_var, b, "__neotree_side_terminal")
              if ok and flag then
                pcall(vim.api.nvim_win_close, w, true)
              end
            end
          end
        else
          -- Open neo-tree on the left, then create a terminal split below that same column
          pcall(vim.cmd, "Neotree show left")
          local neotree_win = nil
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "neo-tree" then
              neotree_win = win
              break
            end
          end
          if neotree_win and vim.api.nvim_win_is_valid(neotree_win) then
            -- Create the terminal below neo-tree, which momentarily grabs focus and Insert mode
            pcall(vim.api.nvim_set_current_win, neotree_win)
            pcall(vim.cmd, "belowright split")
            pcall(vim.cmd, "terminal")
            local b = vim.api.nvim_get_current_buf()
            pcall(vim.api.nvim_buf_set_var, b, "__neotree_side_terminal", true)
            -- Refocus neo-tree after TerminalOpen/BufEnter autocmds have fired
            vim.schedule(function()
              if vim.api.nvim_win_is_valid(neotree_win) then
                pcall(vim.api.nvim_set_current_win, neotree_win)
                pcall(vim.cmd, "stopinsert")
              end
              -- Extra safeguard: ask neo-tree to focus itself
              vim.defer_fn(function()
                pcall(function()
                  require("neo-tree.command").execute({ action = "focus" })
                end)
              end, 20)
            end)
          end
        end
      end
      return vim.list_extend(keys or {}, {
        { "<leader>e", toggle_tree_with_terminal, desc = "Neo-tree + terminal (column toggle)" },
      })
    end,
    opts = function(_, opts)
      opts = opts or {}
      opts.filesystem = opts.filesystem or {}
      -- Avoid prompts about changing cwd on reveal; we reopen tree without reveal
      opts.filesystem.follow_current_file = opts.filesystem.follow_current_file or {}
      opts.filesystem.follow_current_file.enabled = false
      -- Keep neo-tree bound to the global cwd (restored from session)
      opts.filesystem.bind_to_cwd = true
      opts.filesystem.use_libuv_file_watcher = true
      opts.window = opts.window or {}
      opts.window.position = opts.window.position or "left"
      -- Ensure neo-tree takes focus when opened by any means
      opts.event_handlers = opts.event_handlers or {}
      table.insert(opts.event_handlers, {
        event = "neo_tree_window_after_open",
        handler = function()
          pcall(function()
            require("neo-tree.command").execute({ action = "focus" })
            vim.cmd("stopinsert")
          end)
        end,
      })
      return opts
    end,
  },
}

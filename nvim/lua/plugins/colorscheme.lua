return {
  {
    -- {
    --   "xiyaowong/transparent.nvim",
    --   config = function()
    --     require("transparent").setup({
    --       extra_groups = { -- table/string: additional groups that should be cleared
    --         "Normal",
    --         "NormalNC",
    --         "Comment",
    --         "Constant",
    --         "Special",
    --         "Identifier",
    --         "Statement",
    --         "PreProc",
    --         "Type",
    --         "Underlined",
    --         "Todo",
    --         "String",
    --         "Function",
    --         "Conditional",
    --         "Repeat",
    --         "Operator",
    --         "Structure",
    --         "LineNr",
    --         "NonText",
    --         "SignColumn",
    --         "CursorLineNr",
    --         "EndOfBuffer",
    --       },
    --       exclude_groups = {}, -- table: groups you don't want to clear
    --     })
    --   end,
    -- },
    {
      "catppuccin/nvim",
      name = "catppuccin",
      priority = 1000,
      opts = {
        flavour = "mocha", -- latte, frappe, macchiato, mocha
        transparent_background = true, -- disables setting the background color.
        term_colors = true, -- sets terminal colors (e.g. `g:terminal_color_0`)
      },
    },
    {
      "rodolfo-arg/gentleman-kanagawa-blur",
      name = "gentleman-kanagawa-blur",
      priority = 1000,
    },
    {
      "Alan-TheGentleman/oldworld.nvim",
      lazy = false,
      priority = 1000,
      opts = {},
    },
    {
      "rebelot/kanagawa.nvim",
      priority = 1000,
      lazy = true,
      config = function()
        require("kanagawa").setup({
          compile = false, -- enable compiling the colorscheme
          undercurl = true, -- enable undercurls
          commentStyle = { italic = true },
          functionStyle = {},
          keywordStyle = { italic = true },
          statementStyle = {},
          typeStyle = {},
          transparent = true, -- do not set background color
          dimInactive = false, -- dim inactive window `:h hl-NormalNC`
          terminalColors = true, -- define vim.g.terminal_color_{0,17}
          colors = { -- add/modify theme and palette colors
            palette = {},
            theme = {
              wave = {},
              lotus = {},
              dragon = {},
              all = {
                ui = {
                  bg_gutter = "none", -- set bg color for normal background
                  bg_sidebar = "none", -- set bg color for sidebar like nvim-tree
                  bg_float = "none", -- set bg color for floating windows
                },
              },
            },
          },
          overrides = function(colors) -- add/modify highlights
            return {
              LineNr = { bg = "none" },
              NormalFloat = { bg = "none" },
              FloatBorder = { bg = "none" },
              FloatTitle = { bg = "none" },
              TelescopeNormal = { bg = "none" },
              TelescopeBorder = { bg = "none" },
              LspInfoBorder = { bg = "none" },
            }
          end,
          theme = "wave", -- Load "wave" theme
          background = { -- map the value of 'background' option to a theme
            dark = "wave", -- try "dragon" !
            light = "lotus",
          },
        })
      end,
    },
    {
      "webhooked/kanso.nvim",
      name = "kanso",
      priority = 1000,
      config = function()
        require("kanso").setup({
          transparent = true,
          theme = "zen",
          styles = {
            comments = { italic = true },
            keywords = { italic = true },
            functions = {},
            variables = {},
            operators = {},
            types = {},
          },
          plugins = {
            bufferline = true,
            cmp = true,
            dashboard = true,
            gitsigns = true,
            hop = true,
            indent_blankline = true,
            lightspeed = true,
            lsp_saga = true,
            lsp_trouble = true,
            mason = true,
            mini = true,
            neogit = true,
            neotest = true,
            nvimtree = true,
            notify = true,
            overseer = true,
            symbols_outline = true,
            telescope = true,
            treesitter = true,
            whichkey = true,
          },
          -- You can use this function to override the default colors (see colors.lua)
          -- Or create your own theme using the colors you want
          -- theme_overrides = function(colors) end,
        })
      end,
    },
    {
      "folke/tokyonight.nvim",
      name = "tokyonight",
      priority = 1000,
      config = function()
        require("tokyonight").setup({
          style = "night",
          transparent = true,
          terminal_colors = true,
          styles = {
            comments = { italic = true },
            keywords = { italic = true },
            functions = {},
            variables = {},
            sidebars = "transparent",
            floats = "transparent",
          },
          on_highlights = function(highlights)
            local function merge(group, values)
              local existing = highlights[group] or {}
              highlights[group] = vim.tbl_extend("force", existing, values)
            end

            merge("Normal", { bg = "none" })
            merge("NormalFloat", { bg = "none" })
            merge("FloatBorder", { bg = "none" })
            merge("FloatTitle", { bg = "none" })
            merge("TelescopeNormal", { bg = "none" })
            merge("TelescopeBorder", { bg = "none" })
            merge("TelescopeTitle", { bg = "none" })
            merge("LspInfoBorder", { bg = "none" })
            merge("Pmenu", { bg = "none" })
            merge("Keyword", { italic = true })
          end,
        })
      end,
    },
    {
      "LazyVim/LazyVim",
      opts = {
        colorscheme = "kanso",
      },
    },
  },
}

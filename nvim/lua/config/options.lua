-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Always prefer the on-disk version when files change externally
vim.opt.autoread = true

-- Avoid swap/lock files to prevent conflicts with external tools (e.g., Codex)
vim.opt.swapfile = false

-- Keep persistent undo so we don't rely on swap for recovery
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath("state") .. "/undo"
vim.opt.backupcopy = "yes"

-- Suppress ATTENTION prompts when a swap file exists (just edit anyway)
vim.opt.shortmess:append("A")

-- Show diagnostics only via gutter signs (no inline text or underline)
vim.diagnostic.config({
  underline = false,
  virtual_text = false,
  virtual_lines = false,
  signs = true,
})

-- Allow cursor to reach window edges when scrolling fast
-- This disables the margin that keeps the cursor away from top/bottom/left/right
vim.opt.scrolloff = 0
vim.opt.sidescrolloff = 0

vim.api.nvim_create_autocmd("FileType", {
  pattern = "cpp",
  callback = function()
    vim.b.autoformat = false
  end,
})

-- Make terminal buffers clean and free from file UI highlights
local function setup_terminal_window()
  -- Always start in insert mode
  pcall(vim.cmd, "startinsert")

  -- Turn off file/buffer UI that can bleed into terminal rendering
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
  vim.opt_local.cursorline = false
  vim.opt_local.cursorcolumn = false
  vim.opt_local.signcolumn = "no"
  vim.opt_local.colorcolumn = ""
  vim.opt_local.list = false
  vim.opt_local.spell = false
  -- Window-local option (prevents last search highlights inside the terminal)
  pcall(function()
    vim.opt_local.hlsearch = false
  end)
  -- Some UIs use statuscolumn; blank it for terminals if present
  pcall(function()
    vim.opt_local.statuscolumn = ""
  end)
  -- Ensure normal background/no special highlighting in terminal window
  pcall(function()
    vim.wo.winhighlight = "Normal:Normal,NormalNC:Normal"
  end)

  -- Disable common highlighters per-buffer if they exist
  vim.b.minihipatterns_disable = true
  vim.b.minicursorword_disable = true
  vim.b.indent_blankline_enabled = false
  -- Disable matchparen just in case it's active
  pcall(vim.cmd, "NoMatchParen")

  -- Navigation: make sure <C-w> works when leaving terminal-mode
  vim.keymap.set("n", "<C-w>h", "<C-w>h", { buffer = true })
  vim.keymap.set("n", "<C-w>j", "<C-w>j", { buffer = true })
  vim.keymap.set("n", "<C-w>k", "<C-w>k", { buffer = true })
  vim.keymap.set("n", "<C-w>l", "<C-w>l", { buffer = true })

  -- Seamless movement from terminal insert mode
  vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], { buffer = true })
  vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], { buffer = true })
  vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], { buffer = true })
  vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], { buffer = true })
end

vim.api.nvim_create_autocmd({ "TermOpen", "TermEnter", "BufEnter" }, {
  pattern = "term://*",
  callback = setup_terminal_window,
})

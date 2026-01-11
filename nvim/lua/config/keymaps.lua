-- This file contains custom key mappings for Neovim.

-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Map Ctrl+b in insert mode to delete to the end of the word without leaving insert mode
vim.keymap.set("i", "<C-b>", "<C-o>de")

-- Map Ctrl+c to escape from other modes
vim.keymap.set({ "i", "n", "v" }, "<C-c>", [[<C-\><C-n>]])

-- Screen Keys
vim.keymap.set({ "n" }, "<leader>uk", "<cmd>Screenkey<CR>")

-- Delete all buffers but the current one
vim.keymap.set(
  "n",
  "<leader>bq",
  '<Esc>:%bdelete|edit #|normal`"<Return>',
  { desc = "Delete other buffers but the current one" }
)

-- Disable key mappings in insert mode
vim.api.nvim_set_keymap("i", "<A-j>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("i", "<A-k>", "<Nop>", { noremap = true, silent = true })

-- Disable key mappings in normal mode
vim.api.nvim_set_keymap("n", "<A-j>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-k>", "<Nop>", { noremap = true, silent = true })

-- Disable key mappings in visual block mode
vim.api.nvim_set_keymap("x", "<A-j>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("x", "<A-k>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("x", "J", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("x", "K", "<Nop>", { noremap = true, silent = true })

-- VS Code-style line moving with Option+Arrow keys
vim.keymap.set("n", "<A-Up>", [[:m .-2<CR>==]], { desc = "Move line up" })
vim.keymap.set("n", "<A-Down>", [[:m .+1<CR>==]], { desc = "Move line down" })
vim.keymap.set("i", "<A-Up>", [[<Esc>:m .-2<CR>==gi]], { desc = "Move line up" })
vim.keymap.set("i", "<A-Down>", [[<Esc>:m .+1<CR>==gi]], { desc = "Move line down" })
vim.keymap.set("v", "<A-Up>", [[:m '<-2<CR>gv=gv]], { desc = "Move selection up" })
vim.keymap.set("v", "<A-Down>", [[:m '>+1<CR>gv=gv]], { desc = "Move selection down" })

-- Make 'd' delete into the black hole register by default
vim.keymap.set({ "n", "v" }, "d", '"_d', { desc = "Delete without yanking" })

-- Optional: make 'x' (delete char) not yank
vim.keymap.set({ "n", "v" }, "x", '"_x', { desc = "Delete char without yanking" })

-- Optional: keep cut-to-clipboard available
vim.keymap.set({ "n", "v" }, "D", "d", { desc = "Cut (delete + yank)" })

-- Redefine Ctrl+s to save with the custom function
vim.api.nvim_set_keymap("n", "<C-s>", ":lua SaveFile()<CR>", { noremap = true, silent = true })

-- Grep keybinding for visual mode - search selected text
vim.keymap.set("v", "<leader>sg", function()
  -- Get the selected text
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getline(start_pos[2], end_pos[2])

  if #lines == 0 then
    return
  end

  -- Handle single line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
  else
    -- Handle multi-line selection
    lines[1] = string.sub(lines[1], start_pos[3])
    lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
  end

  local selected_text = table.concat(lines, "\n")

  -- Escape special characters for grep
  selected_text = vim.fn.escape(selected_text, "\\.*[]^$()+?{}")

  -- Use the selected text for grep
  if pcall(require, "snacks") then
    require("snacks").picker.grep({ search = selected_text })
  else
    vim.notify("No grep picker available", vim.log.levels.ERROR)
  end
end, { desc = "Grep Selected Text" })

-- Grep keybinding for visual mode with G - search selected text at root level
vim.keymap.set("v", "<leader>sG", function()
  -- Get git root or fallback to cwd
  local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
  local root = vim.v.shell_error == 0 and git_root ~= "" and git_root or vim.fn.getcwd()

  -- Get the selected text
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getline(start_pos[2], end_pos[2])

  if #lines == 0 then
    return
  end

  -- Handle single line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
  else
    -- Handle multi-line selection
    lines[1] = string.sub(lines[1], start_pos[3])
    lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
  end

  local selected_text = table.concat(lines, "\n")

  -- Escape special characters for grep
  selected_text = vim.fn.escape(selected_text, "\\.*[]^$()+?{}")

  -- Use the selected text for grep at root level
  if pcall(require, "snacks") then
    require("snacks").picker.grep({ search = selected_text, cwd = root })
  elseif pcall(require, "fzf-lua") then
    require("fzf-lua").live_grep({ search = selected_text, cwd = root })
  else
    vim.notify("No grep picker available", vim.log.levels.ERROR)
  end
end, { desc = "Grep Selected Text (Root Dir)" })

-- Delete all marks
vim.keymap.set("n", "<leader>md", function()
  vim.cmd("delmarks!")
  vim.cmd("delmarks A-Z0-9")
  vim.notify("All marks deleted")
end, { desc = "Delete all marks" })

-- Custom save function
function SaveFile()
  -- Check if a buffer with a file is open
  if vim.fn.empty(vim.fn.expand("%:t")) == 1 then
    vim.notify("No file to save", vim.log.levels.WARN)
    return
  end

  local filename = vim.fn.expand("%:t") -- Get only the filename
  local success, err = pcall(function()
    vim.cmd("silent! write") -- Try to save the file without showing the default message
  end)

  if success then
    vim.notify(filename .. " Saved!") -- Show only the custom message if successful
  else
    vim.notify("Error: " .. err, vim.log.levels.ERROR) -- Show the error message if it fails
  end
end

-- Simple session helpers using builtin :mksession
local function session_path_for_cwd()
  local state = vim.fn.stdpath("state") .. "/sessions"
  vim.fn.mkdir(state, "p")
  local cwd = vim.fn.getcwd()
  local name = cwd:gsub("[/\\:]", "%%")
  return state .. "/" .. name .. ".vim"
end

vim.keymap.set("n", "<leader>qs", function()
  local session = session_path_for_cwd()
  local ok, err = pcall(vim.cmd, "silent! mksession! " .. vim.fn.fnameescape(session))
  if ok then
    vim.notify("Session saved")
  else
    vim.notify("Session save failed: " .. tostring(err), vim.log.levels.ERROR)
  end
end, { desc = "Session Save" })

vim.keymap.set("n", "<leader>ql", function()
  -- Hide Snacks dashboard if active
  pcall(function()
    local ok_snacks, snacks = pcall(require, "snacks")
    if ok_snacks and snacks.dashboard then
      snacks.dashboard.hide()
    end
  end)
  local session = session_path_for_cwd()
  if vim.fn.filereadable(session) == 1 then
    local ok, err = pcall(vim.cmd, "silent! source " .. vim.fn.fnameescape(session))
    if ok then
      vim.notify("Session loaded")
    else
      vim.notify("Session load failed: " .. tostring(err), vim.log.levels.ERROR)
    end
  else
    vim.notify("No session for this directory", vim.log.levels.WARN)
  end
end, { desc = "Session Load (cwd)" })

vim.keymap.set("n", "<leader>qd", function()
  vim.g.__session_stop = true
  vim.notify("Session autosave disabled for this exit")
end, { desc = "Session Stop (no save)" })

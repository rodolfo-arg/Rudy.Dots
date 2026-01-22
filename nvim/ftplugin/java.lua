-- ftplugin/java.lua
-- nvim-jdtls configuration for Java files
-- Handles both regular Java files and zipfile:// buffers from jar sources

local jdtls_ok, jdtls = pcall(require, "jdtls")
if not jdtls_ok then
  return
end

-- Get buffer name to check for zipfile:// buffers
local bufname = vim.api.nvim_buf_get_name(0)

-- For zipfile:// buffers, we need special handling
local is_zipfile = bufname:match("^zipfile://")

-- Find jdtls binary
local function find_jdtls_bin()
  local bin = vim.fn.exepath("jdtls")
  if bin ~= "" then
    return bin
  end
  local home = vim.env.HOME or vim.fn.expand("~")
  local nix_bin = home .. "/.nix-profile/bin/jdtls"
  if vim.fn.executable(nix_bin) == 1 then
    return nix_bin
  end
  return nil
end

local jdtls_bin = find_jdtls_bin()
if not jdtls_bin then
  vim.notify("jdtls not found in PATH", vim.log.levels.WARN)
  return
end

-- Determine root directory
local function get_root_dir()
  -- For zipfile:// buffers, try to get root from kotlin_lsp
  if is_zipfile then
    local kotlin_clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
    if #kotlin_clients > 0 and kotlin_clients[1].config.root_dir then
      return kotlin_clients[1].config.root_dir
    end
    return vim.fn.getcwd()
  end

  -- Normal root detection for regular files
  local root_markers = {
    "gradlew",
    "mvnw",
    "settings.gradle",
    "settings.gradle.kts",
    "build.gradle",
    "build.gradle.kts",
    "pom.xml",
    ".git",
  }
  return vim.fs.root(0, root_markers) or vim.fn.getcwd()
end

local root_dir = get_root_dir()

-- Create unique workspace directory for this project
local project_name = vim.fn.fnamemodify(root_dir, ":t")
local workspace_dir = vim.fn.stdpath("cache") .. "/jdtls-workspace/" .. project_name

-- Build classpath from gradle cache for dependency navigation
local function get_gradle_dependencies()
  local libs = {}
  local gradle_cache = vim.env.HOME .. "/.gradle/caches/modules-2/files-2.1"

  if vim.fn.isdirectory(gradle_cache) == 1 then
    -- Find all jar files in gradle cache (class jars, not sources)
    local handle = io.popen('find "' .. gradle_cache .. '" -name "*.jar" -not -name "*-sources.jar" -not -name "*-javadoc.jar" 2>/dev/null | head -500')
    if handle then
      for line in handle:lines() do
        table.insert(libs, line)
      end
      handle:close()
    end
  end

  return libs
end

-- Get Android SDK jars if available
local function get_android_jars()
  local jars = {}
  local sdk_root = vim.env.ANDROID_HOME or vim.env.ANDROID_SDK_ROOT
  if sdk_root and vim.fn.isdirectory(sdk_root) == 1 then
    local platforms_dir = sdk_root .. "/platforms"
    if vim.fn.isdirectory(platforms_dir) == 1 then
      -- Find android.jar files
      local handle = io.popen('find "' .. platforms_dir .. '" -name "android.jar" 2>/dev/null')
      if handle then
        for line in handle:lines() do
          table.insert(jars, line)
        end
        handle:close()
      end
    end
  end
  return jars
end

-- Build referenced libraries list
local referenced_libraries = {}

-- Add gradle dependencies
for _, lib in ipairs(get_gradle_dependencies()) do
  table.insert(referenced_libraries, lib)
end

-- Add Android SDK jars
for _, jar in ipairs(get_android_jars()) do
  table.insert(referenced_libraries, jar)
end

-- jdtls configuration
local config = {
  name = "jdtls",
  cmd = { jdtls_bin },
  root_dir = root_dir,

  settings = {
    java = {
      -- Reference libraries for navigation
      project = {
        referencedLibraries = referenced_libraries,
      },
      -- Enable source download for dependencies
      eclipse = {
        downloadSources = true,
      },
      maven = {
        downloadSources = true,
      },
      -- Inlay hints
      inlayHints = {
        parameterNames = {
          enabled = "all",
        },
      },
      -- Content provider for decompiled sources
      contentProvider = {
        preferred = "fernflower",
      },
      -- Sources paths
      sources = {
        organizeImports = {
          starThreshold = 9999,
          staticStarThreshold = 9999,
        },
      },
      -- Gradle configuration
      import = {
        gradle = {
          enabled = true,
          wrapper = {
            enabled = true,
          },
        },
        maven = {
          enabled = true,
        },
      },
      -- Configuration for navigation
      configuration = {
        updateBuildConfiguration = "automatic",
      },
    },
  },

  init_options = {
    -- Enable extended capabilities
    extendedClientCapabilities = {
      classFileContentsSupport = true,
      generateToStringPromptSupport = true,
      hashCodeEqualsPromptSupport = true,
      advancedExtractRefactoringSupport = true,
      advancedOrganizeImportsSupport = true,
      generateConstructorsPromptSupport = true,
      generateDelegateMethodsPromptSupport = true,
      moveRefactoringSupport = true,
      overrideMethodsPromptSupport = true,
      inferSelectionSupport = { "extractMethod", "extractVariable", "extractConstant" },
    },
    bundles = {},
  },

  -- Single file support for zipfile:// buffers
  single_file_support = true,

  -- Handlers for jdtls-specific responses
  handlers = {
    -- Handle jdt:// URIs
    ["textDocument/definition"] = function(err, result, ctx, config_)
      if result and #result > 0 then
        -- Check if any result is a jdt:// URI
        for _, loc in ipairs(result) do
          if loc.uri and loc.uri:match("^jdt://") then
            -- jdtls returns jdt:// URI, we need to handle it
            -- nvim-jdtls provides a content provider for this
          end
        end
      end
      -- Use default handler
      vim.lsp.handlers["textDocument/definition"](err, result, ctx, config_)
    end,
  },

  -- Capabilities
  capabilities = vim.lsp.protocol.make_client_capabilities(),

  -- On attach callback
  on_attach = function(client, bufnr)
    -- Enable jdtls-specific commands
    local opts = { buffer = bufnr, silent = true }

    -- Organize imports
    vim.keymap.set("n", "<leader>jo", function()
      jdtls.organize_imports()
    end, vim.tbl_extend("force", opts, { desc = "Organize Imports" }))

    -- Extract variable
    vim.keymap.set("n", "<leader>jv", function()
      jdtls.extract_variable()
    end, vim.tbl_extend("force", opts, { desc = "Extract Variable" }))
    vim.keymap.set("v", "<leader>jv", function()
      jdtls.extract_variable(true)
    end, vim.tbl_extend("force", opts, { desc = "Extract Variable" }))

    -- Extract constant
    vim.keymap.set("n", "<leader>jc", function()
      jdtls.extract_constant()
    end, vim.tbl_extend("force", opts, { desc = "Extract Constant" }))
    vim.keymap.set("v", "<leader>jc", function()
      jdtls.extract_constant(true)
    end, vim.tbl_extend("force", opts, { desc = "Extract Constant" }))

    -- Extract method (visual mode)
    vim.keymap.set("v", "<leader>jm", function()
      jdtls.extract_method(true)
    end, vim.tbl_extend("force", opts, { desc = "Extract Method" }))
  end,
}

-- Start or attach jdtls
jdtls.start_or_attach(config)

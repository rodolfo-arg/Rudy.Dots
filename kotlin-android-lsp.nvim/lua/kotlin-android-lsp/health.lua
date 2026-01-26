-- kotlin-android-lsp: Health check module
-- Run with :checkhealth kotlin-android-lsp

local M = {}

local health = vim.health

function M.check()
  health.start("kotlin-android-lsp")

  -- Check Kotlin LSP
  local kotlin_lsp = vim.fn.exepath("kotlin-lsp")
  if kotlin_lsp ~= "" then
    health.ok("kotlin-lsp found: " .. kotlin_lsp)
  else
    local nix_bin = vim.fn.expand("~/.nix-profile/bin/kotlin-lsp")
    if vim.fn.executable(nix_bin) == 1 then
      health.ok("kotlin-lsp found (Nix): " .. nix_bin)
    else
      health.error("kotlin-lsp not found", {
        "Install via Nix: add kotlinLspPkg to flake.nix",
        "Or install via Mason: :MasonInstall kotlin-language-server",
      })
    end
  end

  -- Check jdtls
  local jdtls = vim.fn.exepath("jdtls")
  if jdtls ~= "" then
    health.ok("jdtls found: " .. jdtls)
  else
    health.warn("jdtls not found (optional, for Java navigation)", {
      "Install via Nix: add jdt-language-server to flake.nix",
      "Or install via Mason: :MasonInstall jdtls",
    })
  end

  -- Check Java
  local java = vim.fn.exepath("java")
  if java ~= "" then
    local version = vim.fn.system("java -version 2>&1 | head -1")
    health.ok("Java found: " .. java)
    health.info("Java version: " .. vim.trim(version))
  else
    health.error("Java not found", {
      "Install JDK 21+ for kotlin-lsp and jdtls",
    })
  end

  -- Check Gradle
  local gradle = vim.fn.exepath("gradle")
  local gradlew = vim.fn.getcwd() .. "/gradlew"
  if vim.fn.executable(gradlew) == 1 then
    health.ok("gradlew found in project")
  elseif gradle ~= "" then
    health.ok("gradle found: " .. gradle)
  else
    health.warn("gradle not found", {
      "Install Gradle or use project's gradlew",
    })
  end

  -- Check Android SDK
  local sdk_root = vim.env.ANDROID_SDK_ROOT or vim.env.ANDROID_HOME
  if sdk_root and vim.fn.isdirectory(sdk_root) == 1 then
    health.ok("Android SDK found: " .. sdk_root)

    -- Check for sources
    local sources_dir = sdk_root .. "/sources"
    if vim.fn.isdirectory(sources_dir) == 1 then
      local sources = vim.fn.glob(sources_dir .. "/android-*", false, true)
      if #sources > 0 then
        health.ok("Android sources available: " .. #sources .. " API levels")
      else
        health.warn("No Android sources installed", {
          "Install via Android Studio SDK Manager",
          "Or: sdkmanager 'sources;android-34'",
        })
      end
    else
      health.warn("Android sources directory not found")
    end
  else
    health.warn("Android SDK not configured (optional)", {
      "Set ANDROID_SDK_ROOT or ANDROID_HOME environment variable",
    })
  end

  -- Check workspace generator script
  local script_found = false

  -- Check bundled script in plugin directory
  local paths = vim.api.nvim_list_runtime_paths()
  for _, path in ipairs(paths) do
    local script = path .. "/scripts/kotlin-lsp-workspace-json"
    if vim.fn.filereadable(script) == 1 then
      health.ok("Workspace generator found (bundled): " .. script)
      script_found = true
      break
    end
  end

  -- Check fallback locations
  if not script_found then
    local fallback_locations = {
      vim.fn.stdpath("config") .. "/../scripts/kotlin-lsp-workspace-json",
      vim.fn.exepath("kotlin-lsp-workspace-json"),
    }
    for _, path in ipairs(fallback_locations) do
      if vim.fn.filereadable(path) == 1 then
        health.ok("Workspace generator found: " .. path)
        script_found = true
        break
      end
    end
  end

  if not script_found then
    health.error("Workspace generator script not found", {
      "Ensure kotlin-android-lsp.nvim is properly installed",
      "Or set config.workspace_script to custom path",
    })
  end

  -- Check current project
  local cwd = vim.fn.getcwd()
  local workspace_file = cwd .. "/workspace.json"
  if vim.fn.filereadable(workspace_file) == 1 then
    health.ok("workspace.json exists in current directory")
  else
    health.info("No workspace.json in current directory", {
      "Generate with :KotlinWorkspaceGenerate or <leader>dk",
    })
  end
end

return M

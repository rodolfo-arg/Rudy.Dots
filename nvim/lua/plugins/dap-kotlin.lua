return {
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require("dap")

      local adapter = vim.fn.exepath("kotlin-debug-adapter")
      if adapter == "" then
        adapter = "kotlin-debug-adapter"
      end

      dap.adapters.kotlin = {
        type = "executable",
        command = adapter,
        options = {
          auto_continue_if_many_stopped = false,
        },
      }

      dap.configurations.kotlin = {
        {
          type = "kotlin",
          request = "launch",
          name = "Kotlin Launch",
          projectRoot = "${workspaceFolder}",
          mainClass = function()
            return vim.fn.input("Main class > ")
          end,
        },
        {
          type = "kotlin",
          request = "attach",
          name = "Kotlin Attach (localhost:5005)",
          projectRoot = "${workspaceFolder}",
          hostName = "localhost",
          port = 5005,
        },
      }
    end,
  },
}

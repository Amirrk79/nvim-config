local M = {}

local org_imports = function(wait_ms)
	local params = vim.lsp.util.make_range_params()
	params.context = { only = { "source.organizeImports" } }
	local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, wait_ms)
	for _, res in pairs(result or {}) do
		for _, r in pairs(res.result or {}) do
			if r.edit then
				vim.lsp.util.apply_workspace_edit(r.edit, "UTF-8")
			else
				vim.lsp.buf.execute_command(r.command)
			end
		end
	end
end

local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
local on_attach = function(client, bufnr)
	if client.server_capabilities.documentFormattingProvider then
		vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
		vim.api.nvim_create_autocmd("BufWritePre", {
			group = augroup,
			buffer = bufnr,
			callback = function()
				vim.lsp.buf.format({
					filter = function(attached_client)
						return attached_client.name ~= "tsserver" and attached_client.name ~= "lua_ls"
					end,
					bufnr = bufnr,
				})
			end,
		})

		if client.name == "gopls" then
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = augroup,
				buffer = bufnr,
				callback = function()
					org_imports(1000)
				end,
			})
		end
	end

	require("lsp_signature").on_attach({
		bind = true, -- This is mandatory, otherwise border config won't get registered.
		handler_opts = {
			border = "rounded",
		},
	}, bufnr)
	require("illuminate").on_attach(client)
end

function M.lsp_config()
	local lspconfig = require("lspconfig")
	local capabilities = require("cmp_nvim_lsp").default_capabilities()

	local lsp_servers = {
		"rust_analyzer",
		"tsserver",
		"dockerls",
		"cssls",
		"jedi_language_server",
		"solidity_ls",
		"tailwindcss",
		"terraformls",
		"vimls",
		"bashls",
		"jsonls",
	}

	for _, lsp in ipairs(lsp_servers) do
		lspconfig[lsp].setup({
			on_attach = on_attach,
			capabilities = capabilities,
		})
	end

	lspconfig.gopls.setup({
		on_attach = on_attach,
		capabilities = capabilities,
		cmd = { "gopls", "serve" },
		filetypes = { "go", "gomod" },
		root_dir = lspconfig.util.root_pattern("go.work", "go.mod", ".git"),
	})

	lspconfig.yamlls.setup({
		on_attach = on_attach,
		capabilities = capabilities,
		settings = {
			yaml = {
				schemas = {
					kubernetes = "globPattern",
				},
			},
		},
	})

	lspconfig.lua_ls.setup({
		on_attach = on_attach,
		capabilities = capabilities,
		settings = {
			Lua = {
				runtime = {
					-- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
					version = "LuaJIT",
				},
				diagnostics = {
					-- Get the language server to recognize the `vim` global
					globals = { "vim" },
				},
				workspace = {
					-- Make the server aware of Neovim runtime files
					library = vim.api.nvim_get_runtime_file("", true),
				},
				-- Do not send telemetry data containing a randomized but unique identifier
				telemetry = {
					enable = false,
				},
			},
		},
	})

	-- ale configuration
	vim.g.ale_fixers = {
		proto = { "buf-format" },
		lua = { "stylua" },
		python = { "black" },
		javascript = { "prettier", "eslint" },
		typescript = { "prettier", "eslint" },
		markdown = { "prettier" },
		solidity = { "forge" },
	}
	vim.g.ale_linters = {
		proto = { "buf-lint" },
	}
	vim.g.ale_fix_on_save = 1
	vim.g.ale_use_neovim_diagnostics_api = 1
	vim.g.ale_completion_autoimport = 0
	vim.g.ale_lint_on_text_changed = 0
	vim.g.ale_lint_on_insert_leave = 1
	vim.g.ale_linters_explicit = 1
end

return M

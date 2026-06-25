-- ============================================================================
-- Neovim config for Linux kernel development
--
-- Engine: clangd (real Clang frontend -> correct CPP/macro expansion,
--         accurate go-to-definition, and cross-file callers via background
--         index). Requires compile_commands.json in the tree root.
--
-- Plugin manager: lazy.nvim
-- Completion: native (vim.lsp.completion, nvim 0.11+) -- no extra plugin.
-- ============================================================================

-- Leader keys must be set before lazy/plugins load.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- ----------------------------------------------------------------------------
-- General options
-- ----------------------------------------------------------------------------
local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.signcolumn = 'yes'
opt.mouse = 'a'
opt.clipboard = 'unnamedplus'
opt.ignorecase = true
opt.smartcase = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.termguicolors = true
opt.scrolloff = 8
opt.splitright = true
opt.splitbelow = true
opt.undofile = true
opt.completeopt = { 'menuone', 'noselect', 'popup' }

-- Sane editing defaults (kernel C style is applied per-filetype below, so
-- editing this Lua config itself stays comfortable).
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Linux kernel coding style for C/C++: hard tabs, 8 wide, 80-col guide.
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'c', 'cpp' },
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 8
    vim.bo.shiftwidth = 8
    vim.bo.softtabstop = 8
    vim.opt_local.colorcolumn = '81'
  end,
})

-- Go uses hard tabs (gofmt enforces this); display them 4 wide.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'go',
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 4
  end,
})

-- Native treesitter highlighting (no plugin) using nvim's bundled parsers.
-- pcall: silently skip filetypes whose parser isn't available (-> regex syntax).
vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})

-- ----------------------------------------------------------------------------
-- Bootstrap lazy.nvim
-- ----------------------------------------------------------------------------
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git', '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ----------------------------------------------------------------------------
-- Plugins
-- ----------------------------------------------------------------------------
require('lazy').setup({
  -- Colorscheme (pleasant defaults).
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function() vim.cmd.colorscheme('tokyonight-night') end,
  },

  -- Fuzzy finder: file/symbol/reference pickers. Uses ripgrep.
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('telescope').setup({
        defaults = {
          -- Keep the huge kernel tree responsive.
          file_ignore_patterns = { '%.o$', '%.ko$', '%.cmd$', '/%.git/' },
        },
      })
    end,
  },

  -- NOTE: nvim-treesitter was removed. Its 'master' branch is archived and
  -- ships queries incompatible with this nvim's bundled treesitter runtime
  -- (caused a crash on markdown injections). We use nvim's NATIVE treesitter
  -- highlighting instead (see the FileType autocmd below), which relies on the
  -- version-matched parsers/queries bundled with nvim (c, lua, markdown, vim,
  -- vimdoc, ...). Languages without a bundled parser fall back to regex syntax.

  -- Keybinding discovery popup ("easy to use").
  -- No Nerd Font installed -> use plain-text labels instead of glyph icons.
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      icons = {
        mappings = false, -- no per-mapping glyph icons
        keys = {          -- spell out special keys as text
          Up = '<Up> ', Down = '<Down> ', Left = '<Left> ', Right = '<Right> ',
          C = '<C-…> ', M = '<M-…> ', D = '<D-…> ', S = '<S-…> ',
          CR = '<CR> ', Esc = '<Esc> ', NL = '<NL> ', BS = '<BS> ',
          Space = '<Space> ', Tab = '<Tab> ',
          ScrollWheelDown = '<ScrollWheelDown> ', ScrollWheelUp = '<ScrollWheelUp> ',
          F1 = '<F1>', F2 = '<F2>', F3 = '<F3>', F4 = '<F4>', F5 = '<F5>',
          F6 = '<F6>', F7 = '<F7>', F8 = '<F8>', F9 = '<F9>', F10 = '<F10>',
          F11 = '<F11>', F12 = '<F12>',
        },
      },
    },
  },
}, {
  ui = { border = 'rounded' },
  -- None of these plugins need luarocks; skip hererocks probing entirely.
  rocks = { enabled = false },
})

-- ----------------------------------------------------------------------------
-- Diagnostics appearance
-- ----------------------------------------------------------------------------
vim.diagnostic.config({
  virtual_text = true,
  severity_sort = true,
  float = { border = 'rounded', source = true },
})

-- ----------------------------------------------------------------------------
-- clangd LSP (native, nvim 0.11+)
--
--   --background-index : index the whole tree so "find callers"/references
--                        work cross-file, not just in open buffers.
--   --header-insertion=never : the kernel manages #includes by hand.
--   --query-driver     : let clangd learn system/builtin include paths from
--                        the gcc/clang the kernel was built with.
-- ----------------------------------------------------------------------------
local clangd_bin = vim.fn.executable('clangd') == 1 and 'clangd'
  or (vim.fn.executable('clangd-18') == 1 and 'clangd-18' or 'clangd')

vim.lsp.config('clangd', {
  cmd = {
    clangd_bin,
    '--background-index',
    '--background-index-priority=normal',
    '--clang-tidy=false',
    '--header-insertion=never',
    '--completion-style=detailed',
    '--function-arg-placeholders',
    '--all-scopes-completion',
    '--pch-storage=memory',
    '-j=8',
    '--query-driver=/usr/bin/*gcc*,/usr/bin/*clang*',
  },
  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  -- compile_commands.json / .clangd preferred over .git so the kernel root
  -- (which has all three) is picked as the project root.
  root_markers = { 'compile_commands.json', '.clangd', '.git' },
})
vim.lsp.enable('clangd')

-- ----------------------------------------------------------------------------
-- gopls LSP (native, nvim 0.11+) -- Go language server
--
-- Requires `gopls` on PATH (`go install golang.org/x/tools/gopls@latest`,
-- lands in $GOPATH/bin which is on PATH here). gopls provides completion,
-- diagnostics, go-to-definition, references, rename, hover docs, and
-- formatting (gofumpt) + import organization (wired to BufWritePre below).
-- ----------------------------------------------------------------------------
vim.lsp.config('gopls', {
  cmd = { 'gopls' },
  filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
  -- go.work for multi-module workspaces, then go.mod, then .git as fallback.
  root_markers = { 'go.work', 'go.mod', '.git' },
  settings = {
    gopls = {
      gofumpt = true,                 -- stricter gofmt
      staticcheck = true,             -- extra static analysis diagnostics
      usePlaceholders = true,         -- fill function-arg placeholders on completion
      completeUnimported = true,      -- complete + auto-import unimported packages
      analyses = {
        unusedparams = true,
        unusedwrite = true,
        nilness = true,
        shadow = true,
      },
      hints = {                       -- inlay hints
        assignVariableTypes = true,
        compositeLiteralFields = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
})
vim.lsp.enable('gopls')

-- Format + organize imports on save for Go files (uses gopls).
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.go',
  callback = function(args)
    local bufnr = args.buf
    local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'gopls' })[1]
    if not client then return end
    local enc = client.offset_encoding or 'utf-16'

    -- 1) Organize imports (source.organizeImports code action).
    local params = vim.lsp.util.make_range_params(0, enc)
    params.context = { only = { 'source.organizeImports' }, diagnostics = {} }
    local res = client:request_sync('textDocument/codeAction', params, 1000, bufnr)
    for _, action in ipairs((res or {}).result or {}) do
      if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit, enc)
      elseif type(action.command) == 'table' then
        client:request_sync('workspace/executeCommand', action.command, 1000, bufnr)
      end
    end

    -- 2) Format the buffer (gofumpt via gopls).
    vim.lsp.buf.format({ async = false, bufnr = bufnr, name = 'gopls' })
  end,
})

-- ----------------------------------------------------------------------------
-- LSP keymaps (attached per-buffer when an LSP server connects)
-- ----------------------------------------------------------------------------
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local bufnr = args.buf
    local tb = require('telescope.builtin')
    local function map(lhs, rhs, desc)
      vim.keymap.set('n', lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
    end

    -- Navigation -----------------------------------------------------------
    map('gd', tb.lsp_definitions, 'Goto definition')
    map('gD', vim.lsp.buf.declaration, 'Goto declaration')
    map('gri', tb.lsp_implementations, 'Goto implementation')
    map('grt', tb.lsp_type_definitions, 'Goto type definition')

    -- Callers / references -------------------------------------------------
    map('grr', tb.lsp_references, 'References')
    map('<leader>ci', vim.lsp.buf.incoming_calls, 'Incoming calls (callers)')
    map('<leader>co', vim.lsp.buf.outgoing_calls, 'Outgoing calls (callees)')

    -- Symbol search --------------------------------------------------------
    map('<leader>ds', tb.lsp_document_symbols, 'Document symbols')
    map('<leader>ws', tb.lsp_dynamic_workspace_symbols, 'Workspace symbols')

    -- Info / actions (K on a macro shows its expansion; "Expand macro"
    -- also appears as a clangd code action) -------------------------------
    map('K', vim.lsp.buf.hover, 'Hover / macro expansion')
    map('grn', vim.lsp.buf.rename, 'Rename')
    map('gra', vim.lsp.buf.code_action, 'Code action / Expand macro')
    map('<leader>ca', vim.lsp.buf.code_action, 'Code action / Expand macro')

    -- Switch between .c and .h (clangd extension) -------------------------
    map('<leader>sh', function()
      local params = vim.lsp.util.make_text_document_params(bufnr)
      vim.lsp.buf_request(bufnr, 'textDocument/switchSourceHeader', params,
        function(_, result)
          if result then vim.cmd.edit(vim.uri_to_fname(result)) end
        end)
    end, 'Switch source/header')

    -- Diagnostics ----------------------------------------------------------
    map('<leader>e', vim.diagnostic.open_float, 'Line diagnostics (float)')
    map('[d', function() vim.diagnostic.jump({ count = -1, float = true }) end, 'Prev diagnostic')
    map(']d', function() vim.diagnostic.jump({ count = 1, float = true }) end, 'Next diagnostic')
    -- List ALL diagnostics: telescope picker (buffer) or quickfix (project).
    map('<leader>dd', tb.diagnostics, 'List diagnostics (telescope)')

    -- Native LSP completion (no completion plugin needed) ------------------
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
    end

    -- Inlay hints (e.g. gopls parameter names / inferred types). Toggle with
    -- <leader>th if they get noisy.
    if client and client:supports_method('textDocument/inlayHint') then
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      map('<leader>th', function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }),
          { bufnr = bufnr })
      end, 'Toggle inlay hints')
    end
  end,
})

-- ----------------------------------------------------------------------------
-- Global (non-LSP) keymaps: files & grep
-- ----------------------------------------------------------------------------
local tb = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', tb.find_files, { desc = 'Find files' })
vim.keymap.set('n', '<leader>fg', tb.live_grep, { desc = 'Live grep (ripgrep)' })
vim.keymap.set('n', '<leader>fb', tb.buffers, { desc = 'Buffers' })
vim.keymap.set('n', '<leader>fh', tb.help_tags, { desc = 'Help tags' })
vim.keymap.set('n', '<leader>fr', tb.resume, { desc = 'Resume last picker' })
vim.keymap.set('n', '<leader>fs', tb.grep_string, { desc = 'Grep word under cursor' })

-- Clear search highlight.
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- ----------------------------------------------------------------------------
-- Viewing errors / diagnostics (work even when no LSP client is attached)
-- ----------------------------------------------------------------------------
-- All project diagnostics -> quickfix list, then open it.
vim.keymap.set('n', '<leader>q', function()
  vim.diagnostic.setqflist()
end, { desc = 'All diagnostics -> quickfix' })
-- Current buffer diagnostics -> location list.
vim.keymap.set('n', '<leader>l', function()
  vim.diagnostic.setloclist()
end, { desc = 'Buffer diagnostics -> loclist' })
-- Quick access to nvim/plugin messages and logs.
vim.keymap.set('n', '<leader>m', '<cmd>messages<CR>', { desc = 'Show :messages' })
vim.keymap.set('n', '<leader>nl', function() vim.cmd.edit(vim.lsp.get_log_path()) end,
  { desc = 'Open LSP log file' })

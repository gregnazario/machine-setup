-- Neovim Configuration (Full)
-- Location: ~/.config/nvim/init.lua

-- Basic settings
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.cursorline = true
opt.wrap = false
opt.showcmd = true
opt.wildmenu = true
opt.lazyredraw = true
opt.showmatch = true
opt.incsearch = true
opt.hlsearch = true
opt.ignorecase = true
opt.smartcase = true
opt.backup = false
opt.writebackup = false
opt.undofile = true
opt.undodir = vim.fn.expand('~/.config/nvim/undo')
opt.swapfile = false
opt.timeoutlen = 500
opt.termguicolors = true
opt.signcolumn = 'yes'
opt.updatetime = 300
opt.hidden = true
opt.splitright = true
opt.splitbelow = true

-- Key mappings
local keymap = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- Navigation
keymap('n', '<C-h>', '<C-w>h', opts)
keymap('n', '<C-j>', '<C-w>j', opts)
keymap('n', '<C-k>', '<C-w>k', opts)
keymap('n', '<C-l>', '<C-w>l', opts)

-- File operations
keymap('n', '<Leader>w', ':w<CR>', opts)
keymap('n', '<Leader>q', ':q<CR>', opts)
keymap('n', '<Leader>e', ':e ', opts)

-- Buffer operations
keymap('n', '<Leader>bn', ':bnext<CR>', opts)
keymap('n', '<Leader>bp', ':bprevious<CR>', opts)
keymap('n', '<Leader>bd', ':bdelete<CR>', opts)

-- Search
keymap('n', '<Leader><Space>', ':nohlsearch<CR>', opts)

-- Telescope
keymap('n', '<Leader>ff', '<cmd>Telescope find_files<CR>', opts)
keymap('n', '<Leader>fg', '<cmd>Telescope live_grep<CR>', opts)
keymap('n', '<Leader>fb', '<cmd>Telescope buffers<CR>', opts)
keymap('n', '<Leader>fh', '<cmd>Telescope help_tags<CR>', opts)

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

-- Plugins
require('lazy').setup({
    -- Color schemes
    'morhetz/gruvbox',
    'sainnhe/gruvbox-material',
    
    -- Git
    'tpope/vim-fugitive',
    'lewis6991/gitsigns.nvim',
    
    -- Treesitter
    {
        'nvim-treesitter/nvim-treesitter',
        build = ':TSUpdate',
    },
    
    -- LSP
    'neovim/nvim-lspconfig',
    'hrsh7th/nvim-cmp',
    'hrsh7th/cmp-nvim-lsp',
    'L3MON4D3/LuaSnip',
    
    -- Telescope
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.5',
        dependencies = { 'nvim-lua/plenary.nvim' },
    },
    
    -- File explorer
    'nvim-tree/nvim-tree.lua',
    
    -- Status line
    'nvim-lualine/lualine.nvim',
    
    -- Utils
    'tpope/vim-commentary',
    'tpope/vim-surround',
    'windwp/nvim-autopairs',
})

-- Color scheme
vim.cmd([[colorscheme gruvbox]])
vim.g.gruvbox_contrast_dark = 'hard'

-- LSP setup
local lspconfig = require('lspconfig')
lspconfig.pyright.setup({})
lspconfig.tsserver.setup({})
lspconfig.rust_analyzer.setup({})
lspconfig.gopls.setup({})

-- Treesitter
require'nvim-treesitter.configs'.setup {
    ensure_installed = { "python", "javascript", "typescript", "rust", "go", "lua", "vim" },
    highlight = { enable = true },
    indent = { enable = true },
}

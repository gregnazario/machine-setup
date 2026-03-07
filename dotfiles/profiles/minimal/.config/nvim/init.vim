" Minimal Neovim Configuration
" Location: ~/.config/nvim/init.lua

" Basic settings
set nocompatible
set encoding=utf-8
set number relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set smartindent
set cursorline
set wrap
set showcmd
set wildmenu
set lazyredraw
set showmatch
set incsearch
set hlsearch
set ignorecase
set smartcase
set backup=0
set writebackup=0
set undofile
set undodir=~/.config/nvim/undo
set swapfile=0
set timeoutlen=500

" Key mappings
let mapleader = " "

" Navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" File operations
nnoremap <Leader>w :w<CR>
nnoremap <Leader>q :q<CR>
nnoremap <Leader>e :e<CR>

" Buffer operations
nnoremap <Leader>bn :bnext<CR>
nnoremap <Leader>bp :bprevious<CR>
nnoremap <Leader>bd :bdelete<CR>

" Search
nnoremap <Leader><Space> :nohlsearch<CR>

" Install vim-plug if not installed
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Plugins
call plug#begin('~/.config/nvim/plugged')
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-commentary'
Plug 'vim-airline/vim-airline'
Plug 'morhetz/gruvbox'
call plug#end()

" Color scheme
colorscheme gruvbox
set background=dark

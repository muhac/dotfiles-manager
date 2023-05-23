" Change the cursor between Normal and Insert modes
let &t_SI = "\e[5 q"
let &t_EI = "\e[2 q"

" Reset the cursor on start
" for older versions of vim, usually not required
augroup myCmds
au!
autocmd VimEnter * silent !echo -ne "\e[2 q"
augroup END

call plug#begin('~/.vim/plugged')
" Make sure you use single quotes

"https://github.com/connorholyday/vim-snazzy
Plug 'connorholyday/vim-snazzy'

" https://github.com/vim-airline/vim-airline
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

"https://github.com/mhinz/vim-signify
Plug 'mhinz/vim-signify'

"https://github.com/preservim/nerdtree
Plug 'preservim/nerdtree'

call plug#end()
"Reload .vimrc and :PlugInstall to install plugins.

color snazzy
let g:airline_theme='molokai'

set updatetime=100

nnoremap tt :NERDTreeToggleVCS<CR>
let NERDTreeShowHidden=1
let NERDTreeShowLineNumbers=1

"remap movements
let NERDTreeMapUpdir='l'
let NERDTreeMapUpdirKeepOpen='zu'
let NERDTreeMapOpenExpl='ze'
let NERDTreeMapOpenSplit='h'
let NERDTreeMapPreviewSplit='gh'
let NERDTreeMapOpenInTabSilent='gt'

" Start NERDTree, unless a file or session is specified, eg. vim -S session_file.vim.
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists('s:std_in') && v:this_session == '' | NERDTree | endif
" Start NERDTree. If a file is specified, move the cursor to its window.
"autocmd StdinReadPre * let s:std_in=1
"autocmd VimEnter * NERDTree | if argc() > 0 || exists("s:std_in") | wincmd p | endif

" Exit Vim if NERDTree is the only window remaining in the only tab.
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
" Close the tab if NERDTree is the only window remaining in it.
"autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

source ~/.vim/vimrc


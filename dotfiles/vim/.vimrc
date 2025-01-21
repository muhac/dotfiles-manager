source ~/.vim/vimrc

" Change the cursor between Normal and Insert modes
" 1 or 0 -> blinking block
" 2 -> solid block
" 3 -> blinking underscore
" 4 -> solid undersocore
" Recent versions of xterm (282 or above) also support
" 5 -> blinking vertical bar
" 6 -> solid vertical bar
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
"https://github.com/morhetz/gruvbox
Plug 'morhetz/gruvbox'

"https://github.com/vim-airline/vim-airline
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

"https://github.com/tpope/vim-fugitive
Plug 'tpope/vim-fugitive'

"https://github.com/machakann/vim-highlightedyank
Plug 'machakann/vim-highlightedyank'

"https://github.com/tpope/vim-surround
Plug 'tpope/vim-surround'

"https://github.com/unblevable/quick-scope
Plug 'unblevable/quick-scope'

"https://github.com/easymotion/vim-easymotion
Plug 'easymotion/vim-easymotion'

"https://github.com/mhinz/vim-signify
Plug 'mhinz/vim-signify'

"https://github.com/preservim/nerdtree
Plug 'preservim/nerdtree'

"https://github.com/vim-ctrlspace/vim-ctrlspace
Plug 'muhav/vim-ctrlspace'

"https://github.com/junegunn/vim-peekabooS
Plug 'junegunn/vim-peekaboo'

call plug#end()
"Reload .vimrc and :PlugInstall to install plugins.

set background=dark
"colorscheme snazzy
colorscheme gruvbox
let g:airline_theme='molokai'
let g:airline_exclude_preview=1

" <Leader>f{char} to move to {char}
map  <leader>f <Plug>(easymotion-bd-f)
nmap <leader>f <Plug>(easymotion-overwin-f)

" s{char}{char} to move to {char}{char}
nmap s <Plug>(easymotion-overwin-f2)

" Move to line
map  <leader>l <Plug>(easymotion-bd-jk)
nmap <leader>l <Plug>(easymotion-overwin-line)

" Move to word
map  <leader>w <Plug>(easymotion-bd-w)
nmap <leader>w <Plug>(easymotion-overwin-w)

set updatetime=100

nnoremap ts :CtrlSpace O<CR>
let g:CtrlSpaceDefaultMappingKey="ta"
"let g:CtrlSpaceSearchTiming=500

nnoremap tt :NERDTreeToggleVCS<CR>
"let NERDTreeShowHidden=1
let NERDTreeShowLineNumbers=1
let g:NERDTreeWinPos="right"
let g:NERDTreeWinSize=35

"remap movements
let NERDTreeMapUpdir='l'
let NERDTreeMapUpdirKeepOpen='zu'
let NERDTreeMapOpenExpl='ze'
let NERDTreeMapOpenInTabSilent='gt'
let NERDTreeMapOpenSplit='h'
let NERDTreeMapPreviewSplit='gh'
"remap s for easymotion
let NERDTreeMapOpenVSplit='v'
let NERDTreeMapPreviewOpenVSplit='gv'

" Start NERDTree, unless a file or session is specified, eg. vim -S session_file.vim.
"autocmd StdinReadPre * let s:std_in=1
"autocmd VimEnter * if argc() == 0 && !exists('s:std_in') && v:this_session == '' | NERDTree | endif
" Start NERDTree. If a file is specified, move the cursor to its window.
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * NERDTree | if argc() > 0 || exists("s:std_in") | wincmd p | endif

" Exit Vim if NERDTree is the only window remaining in the only tab.
"autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
" Close the tab if NERDTree is the only window remaining in it.
autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

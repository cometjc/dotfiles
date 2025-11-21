" Protect large files from sourcing and other overhead.
" Files become read only

set langmenu=zh_TW.utf8
language zh_TW.utf8

if !exists("my_auto_commands_loaded")
	let my_auto_commands_loaded = 1
	" Large files are > 10M
	" Set options:
	" eventignore+=FileType (no syntax highlighting etc
	" assumes FileType always on)
	" noswapfile (save copy of file)
	" bufhidden=unload (save memory when other file is viewed)
	" buftype=nowritefile (is read-only)
	" undolevels=-1 (no undo possible)
	let g:LargeFile = 1024 * 1024 * 10
	augroup LargeFile
		autocmd BufReadPre * let f=expand("<afile>") |
					\ if getfsize(f) > g:LargeFile |
					\ set eventignore+=FileType |
					\ setl noswapfile |
					\ setl bufhidden=unload |
					\ setl undolevels=-1 |
					\ else |
					\ set eventignore-=FileType |
					\ endif
	augroup END
endif

if has("patch-8.1.0360")
	set diffopt+=internal,algorithm:histogram
endif

call plug#begin()
" format / indent
Plug 'roryokane/detectindent'
let g:detectindent_preferred_indent = 4
augroup AutoDetectIndent
	autocmd!
	" 清除此群組內之前設定的 autocmd
	autocmd BufReadPost * :DetectIndent
	"autocmd VimEnter * echom "expandtab"&expandtab "tabstop"&tabstop "shiftwidth"&shiftwidth "softtabstop"&softtabstop
augroup END

Plug 'vim-scripts/Modeliner'

" syntax checker
Plug 'dense-analysis/ale'
Plug 'prabirshrestha/vim-lsp'
Plug 'rhysd/vim-lsp-ale'

if executable('ruff')
	au User lsp_setup call lsp#register_server({
				\ 'name': 'ruff',
				\ 'cmd': ['ruff', 'server'],
				\ 'allowlist': ['python'],
				\ 'workspace_config': {},
				\ })
endif
let g:ale_fix_on_save = 1
let g:ale_linters = {
			\ 'python': ['ruff'],
			\ 'sh': ['shellcheck'],
			\ 'go': ['golangci_lint']
			\}
let g:ale_fixers = {
			\ '*': ['remove_trailing_lines', 'trim_whitespace'],
			\ 'sh': ['shfmt'],
			\ 'python': ['ruff_format', 'ruff'],
			\ 'go': ['gofmt', 'goimports']
			\}
let g:ale_sh_shfmt_options = '-i 4 -ci -bn'


""""""""""""""""""" language support - others
Plug 'PProvost/vim-ps1'
Plug 'avakhov/vim-yaml' " indent yaml
Plug 'inkarkat/vim-AutoAdapt'
Plug 'inkarkat/vim-ingo-library'
Plug 'kchmck/vim-coffee-script'
Plug 'luochen1990/rainbow'
Plug 'stephpy/vim-yaml'
Plug 'vim-scripts/Improved-AnsiEsc'
let g:AutoAdapt_FilePattern = '*.h,*.c,*.cpp,*.sh,env_setup'
let g:rainbow_active = 1
Plug 'ludovicchabant/vim-gutentags'
let g:gutentags_file_list_command = 'rg --files'
let g:gutentags_ctags_tagfile = ".tags"
"shows the context of the currently visible buffer contents
Plug 'wellle/context.vim'
"quickly switch between files
Plug 'mileszs/ack.vim'
let g:ackprg = 'rg --vimgrep --smart-case'
nnoremap <silent> <Leader>rg :Ack <C-R><C-W><CR>
Plug 'jvirtanen/vim-hcl'

""""""""""""""""""" language support - Docker
Plug 'ekalinin/Dockerfile.vim'

""""""""""""""""""" language support - Python
Plug 'vim-python/python-syntax'
let g:python_highlight_all = 1

""""""""""""""""""" language support - C / C++
Plug 'vim-scripts/cuteErrorMarker'
autocmd FileType qf wincmd J
"========================== language support - csv
Plug 'chrisbra/csv.vim'
"========================== language support - ruby
Plug 'vim-ruby/vim-ruby'
Plug 'ngmy/vim-rubocop'
"========================== Tools - Git
Plug 'airblade/vim-gitgutter'
let g:gitgutter_escape_grep = 1
let g:gitgutter_max_signs = 5000
Plug 'tpope/vim-fugitive'
"========================== Editing Tools
Plug 'dhruvasagar/vim-table-mode'
Plug 'vim-scripts/lastmod.vim'
let g:lastmod_format = '%Y-%m-%d %H:%M:%S (%z)'
Plug 'farmergreg/vim-lastplace'
Plug 'vim-scripts/renamer.vim'
Plug 'ntpeters/vim-better-whitespace'
Plug 'nathanaelkane/vim-indent-guides'
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_auto_colors = 0
let g:indent_guides_start_level=2
let g:indent_guides_guide_size=1
Plug 'mg979/vim-visual-multi', {'branch': 'master'}
let g:VM_maps = {}
let g:VM_maps["Add Cursor Down"]             = ''
let g:VM_maps["Add Cursor Up"]               = ''

Plug 'junegunn/vim-easy-align'
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)
" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)
" 配置一些自定义符号
let g:easy_align_delimiters = {
			\ '>': { 'pattern': '>>\|=>\|>'  },
			\ '/': {
			\     'pattern':         '//\+\|/\*\|\*/',
			\     'delimiter_align': 'l',
			\     'ignore_groups':   ['!Comment'] },
			\ ']': {
			\     'pattern':       '[[\]]',
			\     'left_margin':   0,
			\     'right_margin':  0,
			\     'stick_to_left': 0
			\   },
			\ ')': {
			\     'pattern':       '[()]',
			\     'left_margin':   0,
			\     'right_margin':  0,
			\     'stick_to_left': 0
			\   },
			\ 'd': {
			\     'pattern':      ' \(\S\+\s*[;=]\)\@=',
			\     'left_margin':  0,
			\     'right_margin': 0
			\   }
			\ }

Plug 'Valloric/ListToggle'
let g:lt_location_list_toggle_map = '<leader>l'
let g:lt_quickfix_list_toggle_map = '<leader>q'

"========================== AI
Plug 'github/copilot.vim'
imap <silent> <C-j> <Plug>(copilot-previous)
imap <silent> <C-k> <Plug>(copilot-next)
imap <silent> <C-\> <Plug>(copilot-suggest)
let g:copilot_filetypes = {
			\ 'gitcommit': v:true,
			\ 'markdown': v:true,
			\ 'yaml': v:true,
			\ 'perl': v:true
			\ }
let g:copilot_node_command = "~/.local/share/mise/installs/node/latest/bin/node"

"========================== Themes
Plug 'morhetz/gruvbox'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
let g:airline_powerline_fonts = 1
let g:airline_theme='base16_gruvbox_dark_hard'
" spaces are allowed after tabs, but not in between
" this algorithm works well with programming styles that use tabs for
" indentation and spaces for alignment
let g:airline#extensions#whitespace#mixed_indent_algo = 2
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#fnamemod = ':t'
let g:airline#extensions#tabline#excludes = []
let g:airline#extensions#tabline#exclude_preview = 1
let g:airline#extensions#tabline#fnametruncate = 8
augroup open-tabs
	au!
	au VimEnter * ++nested if !&diff | tab all | tabfirst | endif
augroup end
map <C-left>    <Plug>AirlineSelectPrevTab " previous buffer
map <C-right>   <Plug>AirlineSelectNextTab " next buffer
map <C-S-Left>  :tabmove -1<CR>            " move tab to left
map <C-S-Right> :tabmove +1<CR>            " move tab to right
let g:airline#extensions#ale#enabled = 1
let g:airline#extensions#tabline#left_sep = ''
let g:airline#extensions#tabline#right_sep = ''

call plug#end()

set wildmode=longest,list
set wildmenu
syntax enable
set background=dark

" error occors on first install
silent! colorscheme gruvbox " ignore error on first initialize


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" first the disabled features due to security concerns
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set modelines=5         " no modelines [http://www.guninski.com/vim1.html]
set modeline
let g:secure_modelines_verbose=1 " securemodelines vimscript
function! AppendModeline()
	let l:modeline = printf(" vim: set shiftwidth=%d tw=%d %set :",
				\ &shiftwidth, &textwidth, &expandtab ? '' : 'no')
	let l:modeline = substitute(&commentstring, "%s", l:modeline, "")
	call append(line("$"), l:modeline)
endfunction
nnoremap <silent> <Leader>ml :call AppendModeline()<CR>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" operational settings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set hidden                      " allow editing multiple unsaved buffers
set more                        " the 'more' prompt
filetype plugin indent on       " automatic file type detection
set autoread                    " watch for file changes by other programs
"set visualbell                 " visual beep
set backup                      " produce *~ backup files
set backupdir=~/.backup//
set directory=~/.backup//
set noautowrite                 " don't automatically write on :next, etc
set lazyredraw                  " don't redraw when running macros
set ttyfast                     " Speedup for tty
set updatetime=750		" screen update speed
set wildmenu                    " : menu has tab completion, etc
set scrolloff=5                 " keep at least 10 lines above/below cursor
set sidescrolloff=5             " keep at least 5 columns left/right of cursoraaaaa
set history=200                 " remember the last 200 commands
set showcmd			" display incomplete commands

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" window spacing
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set ruler                       " show the line number on bar
set number                      " show

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" mouse settings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set mouse=                      " disable mouse support in all modes
set mousehide                   " hide the mouse when typing text


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" global editing settings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set autoindent                  " turn on auto/smart indenting
set cindent cinkeys-=0#
set backspace=eol,start,indent  " allow backspacing over indent, eol, & start
set undolevels=1000             " number of forgivable mistakes
set updatecount=100             " write swap file to disk every 100 chars
set complete=.,w,b,u,U,t,i,d    " do lots of scanning on tab completion
" 1. netrw 不保留原本遠端的目錄階層（只抓檔案放在同一個目錄）
let g:netrw_keepdir = 0
" 2. 指定 netrw 把本地暫存檔案放到哪裡（預設是跟你工作目錄切出去的 .netrwhist/ ）
"    這裡改成 /tmp/vim_netrw，只要確保你有寫入權限即可。
let g:netrw_localcopydir = '/tmp/vim_netrw'


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" searching...
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set hlsearch                   " enable search highlight globally
set incsearch                  " show matches as soon as possible
set showmatch                  " show matching brackets when typing

set diffopt=filler,iwhite       " ignore all whitespace and sync

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" spelling...
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if v:version >= 700
	function! ToggleSpell()
		if &spell == 1
			setl spell!
		else
			setl spell spelllang=en_us
		endif
	endfunction

	nmap <Leader>ss :call ToggleSpell()<CR>

	setl spell spelllang=en_us
	setl nospell
endif



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" setup for the visual environment
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
autocmd FileType  python highlight OverLength ctermbg=LightCyan|match OverLength /\%142v.*/
set cursorline
set foldlevelstart=1
set ambiwidth=double

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" force making paths relative to `pwd`
" this is useful if tag files have absolute paths
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

augroup force-cd-dot
	autocmd!
	autocmd BufEnter * :cd .
augroup END
set path=**;/

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" notmuch config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let g:notmuch_debug = 0

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" termcaps
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set notitle
set timeout ttimeoutlen=50

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" import other files...
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set dictionary=/usr/share/dict/words            " used with CTRL-X CTRL-K

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" file encode
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set fileencodings=utf-8-bom,ucs-bom,utf-8,cp936,big5,gb18030,ucs
set fileformats=unix,dos
set nobinary


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" create the directory there if it doesn't exist yet.
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
augroup Mkdir
	autocmd!
	autocmd BufWritePre * call mkdir(expand("<afile>:p:h"), "p")
augroup END

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function Keys F1~F12, B, C,
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! SaveAllExit()
	try
		wqa!
	catch
		write !sudo tee % >/dev/null
		edit!
		wqa!
	endtry
endfun

let g:indent_mod = 0
function! Switch_indent()
	if g:indent_mod == 0
		DetectIndent
	endif
	if g:indent_mod == 1
		set expandtab softtabstop=0 sw=4
	endif
	if g:indent_mod == 2
		set noexpandtab softtabstop=0 sw=8
	endif
	if g:indent_mod == 3
		set noexpandtab softtabstop=0 sw=4
	endif
	let g:indent_mod = (g:indent_mod + 1 ) % 4
	echom "softtabstop"&softtabstop "sw"&sw "tabstop"&tabstop "expandtab"&expandtab
endfunction

function! Next_err()
	try
		cnext!
	catch /:E553:/
		clast!
	catch /:E42:/
	endtry
endfunction

function! Pre_err()
	try
		cprevious!
	catch /:E553:/
		cfirst!
	catch /:E42:/
	endtry
endfunction

" Bind for terminator
function! <SID>LocationPrevious()
	try
		lprev!
	catch /:E42:/  " E42: No Errors
	catch /:E776:/ " No location list
	catch /:E553:/ " End/Start of location list
		call <SID>LocationLast()
	catch /:E926:/ " Location list changed
		ll!
	endtry
endfunction

function! <SID>LocationNext()
	try
		lnext!
	catch /:E42:/  " E42: No Errors
	catch /:E776:/ " No location list
	catch /:E553:/ " End/Start of location list
		call <SID>LocationFirst()
	catch /:E926:/ " Location list changed
		call <SID>LocationNext()
	endtry
endfunction

function! <SID>LocationFirst()
	try
		lfirst!
	catch /:E926:/ " Location list changed
		call <SID>LocationFirst()
	endtry
endfunction

function! <SID>LocationLast()
	try
		llast!
	catch /:E926:/ " Location list changed
		call <SID>LocationLast()
	endtry
endfunction

set autowrite
function! Do_make__()
	wall
	silent make!
	cwindow
	try
		cc!
	catch
		" deal with it
	endtry
	redraw!
endfunction

set viminfo='1000,<1000,s20,h

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" status line
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Use 256 colours (Use this setting only if your terminal supports 256 colours)
set t_Co=256

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" auto load extensions for different file types
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" '<,'>!sort -k5,6
autocmd FileType  coffee     setl expandtab    shiftwidth=2
autocmd FileType  css        setl expandtab    shiftwidth=2
autocmd FileType  gitcommit  setl expandtab    shiftwidth=2 nocindent formatoptions+=mB | call setpos('.', [0, 1, 1, 0])|call ToggleSpell()
autocmd FileType  jade       setl expandtab    shiftwidth=2
autocmd FileType  javascript setl expandtab    shiftwidth=2
autocmd FileType  json       setl expandtab    shiftwidth=2
autocmd FileType  markdown   setl expandtab    shiftwidth=2
autocmd FileType  Podfile    setl expandtab    shiftwidth=2
autocmd FileType  ruby       setl expandtab    shiftwidth=2
autocmd FileType  scss       setl expandtab    shiftwidth=2
autocmd FileType  toml       setl expandtab    shiftwidth=2
autocmd FileType  xml        setl expandtab    shiftwidth=2
autocmd FileType  xsd        setl expandtab    shiftwidth=2
autocmd FileType  yaml       setl expandtab    shiftwidth=2 indentkeys-=0# indentkeys-=<:> iskeyword=-,@,48-57,_,192-255
autocmd FileType  erb        setl expandtab    shiftwidth=4
autocmd FileType  hbs        setl expandtab    shiftwidth=4
autocmd FileType  html       setl expandtab    shiftwidth=4
autocmd FileType  liquid     setl expandtab    shiftwidth=4
autocmd FileType  nginx      setl expandtab    shiftwidth=4
autocmd FileType  php        setl expandtab    shiftwidth=4
autocmd FileType  python     setl expandtab    shiftwidth=4 cindent makeprg=pychecker\ -Q\ --only\ %\ 2>/dev/null efm=%f:%l:\ %m
autocmd FileType  go         setl noexpandtab  shiftwidth=4
autocmd FileType  Dockerfile setl noexpandtab  shiftwidth=2
autocmd FileType  make       setl noexpandtab  shiftwidth=2 iskeyword=-,@,48-57,_,192-255

autocmd BufReadPre,BufNewFile *.rockerfile setlocal filetype=Dockerfile
autocmd FileType  log        AnsiEsc
autocmd FileType  sh         syntax sync fromstart
autocmd FileType  bash       syntax sync fromstart
autocmd FileType  c          setl fo=cq        wm=0          formatoptions+=r


" The Silver Searcher
if executable('ag')
	" Use ag over grep
	set grepprg=ag\ --vimgrep\ --ignore=*~\ $*
	set grepformat=%f:%l:%c:%m

	" Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
	let g:ctrlp_user_command = 'ag %s -l --nocolor -g ""'

	" ag is fast enough that CtrlP doesn't need to cache
	let g:ctrlp_use_caching = 0
endif

" Exclude quickfix buffer from `:bnext` `:bprevious`
augroup qf
	autocmd!
	autocmd FileType qf set nobuflisted
augroup END

set pastetoggle=<Leader>p

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" maps
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" open list when jump  to multiple match tags
if &term =~ '^screen'
	" tmux will send xterm-style keys when its xterm-keys option is on
	execute "set <xUp>=\e[1;*A"
	execute "set <xDown>=\e[1;*B"
	execute "set <xRight>=\e[1;*C"
	execute "set <xLeft>=\e[1;*D"
endif

nnoremap <C-]> g<C-]>


if &term == "screen-256color"
	set term=xterm-256color
elseif &term == "terminator"
	set term=xterm-256color
elseif &term == "putty-256color"
	set term=xterm-256color
endif
function! ToggleColumn()
	" Toggle the display of the line number
	set invnumber
	" Toggle GitGutter signs
	GitGutterSignsToggle
	" Toggle ALE signs
	ALEToggle
	" Toggle vim-lsp signs
	if &signcolumn == 'auto'
		setlocal signcolumn=no
	else
		setlocal signcolumn=auto
	endif
endfunction

map  <M-Up>      :call <SID>LocationPrevious()<CR>
map  <S-Up>      :call Pre_err()<CR>
map  <C-Up>      <Plug>(GitGutterPrevHunk)
map! <C-Up>      <Plug>(GitGutterPrevHunk)
map  <M-Down>    :call <SID>LocationNext()<CR>|
map  <S-Down>    :call Next_err()<CR>
map  <C-Down>    <Plug>(GitGutterNextHunk)
map! <C-Down>    <Plug>(GitGutterNextHunk)
map  <C-B>       :call Do_make__()<CR>|                  " excute make in vim and open quickfix window
map  <C-F4>      :bd<CR>
map  <C-F7>      :silent gr '<c-r>=expand('<cword>')<CR>' .\|redraw!<CR>
map  <C-H>       :%s/\V\<<c-r>=expand('<cword>')<CR>\>///g<left><left>

map  <F12>       :call Switch_indent()<CR>
map  <F5>        :w<CR>:ll<CR>|
map  <F7>        :call ToggleColumn()<CR>
map  <F8>        :set hls!<BAR>set hls?<CR>|             " 在 searching highlight 及非 highlight 間切換
map  <F9>        :sort<CR>
map  <Leader>ce  :edit ~/.vimrc<CR>|                     " quickly edit this file
map  <Leader>cs  :source ~/.vimrc<CR>|                   " quickly source this file
map  <Leader>fc  /\v^[<=>]{7}( .*\|$)<CR>|               " find merge conflict markers
map  <Leader>nh  :nohlsearch<CR>|                        " disable last one highlight
map! <S-Tab>     <C-D>|                                  " tab indenta
vmap <S-Tab>     <gv_|                                   " tab indent
map  <S-Tab>     <<|                                     " tab indent
vmap <Tab>       >gv_|                                   " tab indent
map  <Tab>       >>|                                     " tab indent
map  ZZ          :silent call SaveAllExit()<CR>
set  cmdheight=1 " make command line two lines high

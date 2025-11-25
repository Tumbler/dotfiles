" @Tracked
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 11/21/2025 10:57 AM

" TODO: Can have errors when doing ex commands on directories if the directory name contains a "%"
" TODO: Check if $HOME/.vim works just as well on Windows as $HOME/vimfiles

"> Settings

scriptencoding utf-8

if (line('$') == 1 && getline(1) == '' && has("gui_running"))
   set columns=84
   set lines=45
endif
" If we have a new window, give it a decent size
set number
" Turn on line numbers
set incsearch
" When searching with "/" you will see initial matches as you search
set hlsearch
" Highlight all search matches
"set makeprg=mk
set ruler
set laststatus=2
" Permanent status line (format is set in function below)
set showcmd
if v:version >= 900
   set showcmdloc=statusline
endif
" During multipart commands, show the keys you have typed so far in the status line
set autoindent
set smartindent
" Intelligently auto-indents when new lines that are created with <CR> or "o"
set list listchars=tab:>-,trail:·,precedes:<,extends:>
" Tabs are shown as >- and trailing spaces are shown as · See?  ->	 
" When wrap is off (like when in a diff) and the line extends past the screen,
"   show < or > to indicate that the line continues
set sidescrolloff=20
" Keep 20 characters of context for horizontal scrolling
set sidescroll=1
" Scroll one column horizontally as needed
set expandtab
" Pressing tab will actually put the appropriate amount of spaces (Because tabs are EVIL!!)
set shiftwidth=3
set tabstop=3
set softtabstop=3
" Tabs are three characters long
set backspace=2
" Make backspace work in insert mode
if has("win32") && !has("gui_running")
   inoremap <C-h> <BS>
endif
" When in windows-terminal vim, backspace gets mapped to <C-h>
"   This will allow terminal vim to function
set ignorecase
set smartcase
" Make searches be case insensitive unless capital letters are used
set showmatch
" When an ending bracket (or parin, or brace) is typed, jump to the matching one briefly for confirmation
" (Highlighting parin is actually a standard plugin that is turned on by "DoMatchParen")
set tags=./tags;
" File it looks for to define ctags
set winaltkeys=no
" Allows us to use the menu shortcuts for ourselves, YAY! (i.e. Alt+h)
set autochdir
" Automatically sets the pwd to current file as you browse
set diffopt=filler,vertical,context:1000000
" Automatically opens diffs with filler lines for sync, vertically
"   (side-by-side), and with all folds open
set wildignore+=*.o,*.obj,*.bak,*.exe,*.aux,*.dvi,*.info,*.d,*.hex,*.map,*.lib,*.swp,*.elf,*.bin,*.out,*.zip,tags,*.lst,*.pp,*.dll,*.lst,*.rlf,*.sdb,*cof,*.dep,*.hxl,*.mcs,*.sym,Nmakefile,*.DS_Store
" vimgrep ignores object files
set wildmenu
" Tab completing in command-line gives visual menu
set shellslash
" Uses forward slashes, because Windows is wrong.
set directory=$HOME/vimfiles/swap,.
" Makes .swp files go here so we don't have to see them, but still get the
"   benefit from using them (Defaults to current directory if that one is
"   unavailable for some reason).
set undofile
set undodir=$HOME/vimfiles/undo
" Makes undo's persistent. AKA if you exit a file and then edit again you can
"   still undo your changes from before. (It's sweet)
set undolevels=10000
" Sets undo history to 10K changes (Default is 1000).
set sessionoptions=blank,buffers,curdir,folds,globals,localoptions,options,resize,slash,tabpages,winpos,winsize
" Save ALL the things when saving sessions
set comments+=:\"
" How could we forget about vim comments?!

if has("gui_running") && has("autocmd")
augroup Focus
   au!
   autocmd FocusGained * let @" = @+
   autocmd FocusLost   * let @+ = trim(@", "", 2)
augroup END
else
   set clipboard^=unnamed
endif
" I often find myself wanting to copy between vims. The clipboard option
"   works OK for this but wipes out the clipboard when you do basically
"   anything and can get frustrating if you want to delete a line and
"   then paste. Now it only wipes out the clipboard when you leave vim.
"   However, this only works in Gvim.

if v:version >= 802
   set modeline
   set modelineexpr
   " Allows advanced modelines so we can do fancy folding
endif

set omnifunc=syntaxcomplete#Complete
" Attempt to intelligently fill the omnicomplete by filetype

set formatoptions=jrql2
" Remove extra comment headers when [J]oining
" When in a comment, [r]eturn will automatically add a comment header
" When formatting text, use the indent of the [2]nd line of a paragraph
" See :h fo-table for more info
" ftplugin Overrides this (which is ANNOYING BTW). I have an autocmd to override
" ftplugin because this is how I want it dang it!

set mouse=a

">> Plugin settings
let g:netrw_sort_sequence='[\/]$,*,\.o$,\.obj$,\.info$,\.d$,\.hex$,\.map$,\.mcp$,\.mcw$,\.lib$,\.swp$,\.bak$,\.lst$,\.rlf$,\.sdb$,\.CVSfolderStatus,\~$'
" Change sorting sequence of netrw explorer to leave different filetypes together
let g:netrw_sort_options="i"
" Case insensitive sorting (still not sure why you would want to sort by case, but whatever)
let g:netrw_banner = 0
" Don't show netrw's "helpful" banner at the beginning of every directory
let g:netrw_list_hide ="^\.#"
" Doesn't show any files that start with .#
let do_syntax_sel_menu = 1
" Show filetypes in syntax menu (enables SetSyn() command)
if has("win32")
   let g:loaded_zipPlugin = 1
   let g:loaded_zip       = 1
   " Prevent vim from trying to open zip files (annoying when vimgrepping if not setup)
endif

let g:projectManager_TagKeyCombo = '<A-,>'
" Changes the mapping for tag under cusor

let g:baseConverter_leading_binary_zeros = 1

" Ale
let g:ale_set_quickfix = 0
let g:ale_set_loclist = 0
let g:ale_sign_column_always = 1

let g:ale_change_sign_column_color = 1

let g:ale_lint_on_text_changed = 'normal'
let g:ale_lint_on_insert_leave = 1
let g:ale_lint_on_enter = 1
let g:ale_lint_on_save = 1
let g:ale_completion_enabled = 1
let g:ale_sign_error = '>>'
let g:ale_sign_warning = '--'

"<<

if has("gui_running")
   set guioptions-=m
   " This removes the menu bar from the gui
   set guioptions-=T
   " This removes the toolbar from the gui
   set guioptions+=c
   " This allows vim to handle confirmations terminal style instead of in a
   " dialog box
endif

filetype indent on
" Turn on filetype dependent indenting

if !exists("syntax_on")
  syntax enable
endif

"< End of Settings

"> Abbreviations

inoreabbrev ture true
" Insert mode abbreviation for misspelling true.

" Command line abbreviations:
cnoreabbrev <expr> h (getcmdtype() == ':' && getcmdline() =~ '^h$')? 'tab help' : 'h'
" Help opens in new tab

cnoreabbrev <expr> w (getcmdtype() == ':' && getcmdline() =~ '^w$')? 'call SaveBuffer(0)' : 'w'
cnoreabbrev wq  call SaveBuffer(1)
cnoreabbrev wy  call SaveBuffer(2)
cnoreabbrev wqy call SaveBuffer(3)
" wf = write force
cnoreabbrev wf  call SaveBuffer(4)
" When saving tracked files, vim will auto-update the last edited info

cnoreabbrev qt  tabclose
" Like :qa, but only closes the current tab

cnoreabbrev <expr> q (getcmdtype() == ':' && getcmdline() =~ '^q$' && v:char != '!')? 'call <SID>Quit()' : 'q'
" Intelligently quits out of quickfixes automatically

cnoreabbrev D Diffsplit
" I use diffsplit a lot, might as well make it easer to type

cnoreabbrev qh tabdo if (!buflisted(bufnr('%')) && &modifiable == 0) <BAR> tabclose <BAR> endif
" Closes all help tabs (Technically all unlisted non-modifiable, but this is usually going to just be help)

cnoreabbrev <expr> cw (getcmdtype() == ':' && getcmdline() =~ '^cw$')? 'copen' : 'cw'
" Opens the quickfix even if there are no errors. I have other easy ways to close it.


command! -nargs=1 -complete=file Diffsplit diffsplit <args> | wincmd p
" Diff a file and switches focus back on the original file
command! Whitespace :call ReplaceBadWhitespaceInDir()
" Replaces tabs and trailing whitespace in all files in a directory
command! -nargs=1 Retab :call s:Retab(<args>)

command! -nargs=? Terminal :call s:OpenDirectionalTerminal('<args>')
" Opens a terminal in a split window in the specified direction (defaults right)

"< End of Abbreviations

"> Mappings
" <C-x>  means Ctrl+x
" <A-x>  means Alt+x   (<M-x> means the same thing)
" <S-x>  means Shift+x
" These commands can be chained. I.E. <S-A-C-x> NOTE: <C-A-x> and <C-S-x> does not work unless x is an F-key

if has("unix") && !has("gui_running") && system("uname") != "Darwin\n"
   let c='a'
   while c <= 'z'
     exec "set <A-".c.">=\e".c
     exec "imap \e".c." <A-".c.">"
     let c = nr2char(1+char2nr(c))
   endwhile
   set timeout ttimeoutlen=50
endif
" Linux terminals have this weird thing where alt commands don't work at all.
"   I would die without my alt commands so this is a workaround.

inoremap <A-e> <Esc>
" Give an alternative to <Esc> that doesn't take your hand as far off of the keyboard

inoremap <Del> <NOP>
inoremap <A-BS> <Del>
cnoremap <A-BS> <Del>
" Delete is hard to press and is in different places on different keyboards

" Basically makes it so that if a line goes over one visual line,
"  j and k behave intuitively
noremap j gj
noremap k gk
" If you need the default behavior for some reason use this:

noremap gj j
noremap gk k
" Thanks DJMcMayhem, that was a good idea.

cnoremap <expr> <Up>   getcmdtype() ==# '@' ? InputHistory(0): '<Up>'
cnoremap <expr> <Down> getcmdtype() ==# '@' ? InputHistory(1): '<Down>'
cnoremap <expr> <CR>   getcmdtype() ==# '@' ? InputHistory(2): '<C-]><CR>'
" When inside an Input() use the up and down arrows for command line recall

noremap <silent> H :call  search('\(^\s\+\)\@<=\S\\|^', 'b', line('.'))<CR>
" Go to beginning of text (like '^') or beginning of line, whichever comes first
noremap L $
" Go to end of line
if has("win32")
   nnoremap K  :exe "tab help ".expand('<cword>')<CR>
   nnoremap gK :exe "tab help ".expand('<cWORD>')<CR>
   " Opens help on word under cursor in a new tab
endif

onoremap <expr> O v:operator == 'd' ? ':.diffget<CR>' : '<ESC><ESC>'
onoremap <expr> P v:operator == 'd' ? ':.diffput<CR>' : '<ESC><ESC>'
" Now dO and dP work like do and dp except only obtain/put a single line

nnoremap si i_<Esc>r
nnoremap sa a_<Esc>r
" Insert single character

" Make copy pasta act like windows.
" Because we all know how broken the middle click method is.....
" Also sets the paste option temporarily so that vim doesn't try
"   to auto-indent as it pastes (Almost never what you want).
noremap  <C-v> :set paste<CR>"+gP:set nopaste<CR>
inoremap <C-v> <C-o>:set paste<CR><C-r>+<C-o>:set nopaste<CR>
cnoremap <C-v> <C-r>+
vnoremap <C-v> d"+gP
vnoremap <C-c> "+y
" Makes copy paste in the terminal function very intuitively across all
" operating systems and uses a very minimal number of keystrokes all while still
" having access to CTRL-c for ending terminal processes. Also gives easy access
" to "Terminal-Normal" mode which can be useful for searching through terminal
" output without having to pipe to another process.
if version >= 810
   nnoremap <expr><Esc> (mode(1) == 'nt') ? 'i' : '<Esc>'
   tnoremap <A-e> <C-w>N
   tnoremap <LeftMouse> <C-w>N:set nonumber<CR><LeftMouse>
   "Terminal Normal mode
   tnoremap <expr><C-v> @+
   tnoremap <expr><C-p> @"
   vnoremap <expr><C-c> (&buftype == 'terminal') ? '"+yi' : '"+y'
   tnoremap <S-Space> <Space>
endif
" Sometimes Unix forces us to use the middle click for pasting unfortunately. At
" least make it so that we don't have to grab the mouse.
if has ('unix')
   nnoremap <C-S-V> <MiddleMouse>
   inoremap <C-S-V> <MiddleMouse>
endif

cnoremap <C-p> <C-r>"
inoremap <C-p> <C-r>"
" "Pastes" the current unnamed register

vnoremap <C-p> "0p
" Uses the next to last thing that we yanked to make it easier to past the same
" thing several times.

vnoremap J j
vnoremap K k

nnoremap <silent><A-J><A-K> :call ParagraphToEightyChars()<CR>
nnoremap <silent><A-J><A-J> :call ParagraphToEightyChars(1)<CR>
nnoremap <silent>J maJ`a
" Keep the cursor in the same place when doing a Join

inoremap <C-Space> <C-n>
" AutoComplete. (Activated with Ctrl+Space)

" Change Focus Between Split Windows
nnoremap <C-j>  <C-W>j
inoremap <expr> <C-j>  pumvisible() ? "<Down>" : "<Esc><C-W>j"
   " If AutoComplete box is open tab through the menu, otherwise shift focus down
nnoremap <C-k>  <C-W>k
inoremap <expr> <C-k>  pumvisible() ? "<Up>" : "<Esc><C-W>k"
   " If AutoComplete box is open tab through the menu, otherwise shift focus up
nnoremap <C-h>  <C-W>h
   " Left
nnoremap <C-l>  <C-W>l
inoremap <C-l>  <Esc><C-W>l
   " Right
if version >= 810
   tnoremap <C-j>  <C-W>j
   tnoremap <C-k>  <C-W>k
   tnoremap <C-h>  <C-W>h
   tnoremap <C-l>  <C-W>l
endif
" Same as the above but for termal splits (Only available starting in 8.1)
inoremap <expr> <Tab>  pumvisible() ? "<Down><C-y>" : "<Tab>"
   " If AutoComplete box is open, accep the current selection
nnoremap <C-d>   :res +10<CR>
inoremap <C-d>   <C-o>:res +10<CR>
nnoremap <C-s>   :vertical res +10<CR>
inoremap <C-s>   <C-o>:vertical res +10<CR>
" Increases size of splits incrementally
nnoremap <expr> <C-a> search('0x\\|\(\<\)', "bpcn") == 1 ? "\<C-a>vUgUTxFxe" : "\<C-a>"
nnoremap <expr> <C-x> search('0x\\|\(\<\)', "bpcn") == 1 ? "\<C-x>vUgUTxFxe" : "\<C-x>"
" TODO: has problems when there are actual x's in the preceeding text.
" Makes hex digits show up capital when auto-incrementing/decrementing

nnoremap <A-y>   @q
inoremap <A-y>   <Esc>@q
" Because @ is WAY too hard to hit
nnoremap <A-t>   @w
inoremap <A-t>   <Esc>@w
" Because sometimes you need two macros
nnoremap <A-l>  :tabnext<CR>
inoremap <A-l> <Right>
" Switch to next tab
nnoremap <S-A-l> :tabmove +1<CR>
inoremap <S-A-l> <Esc>:tabmove +1<CR>
" Moves tab to the right one position
cnoremap <A-l>   <Right>
" Moves right in the command line
nnoremap <A-h>  :tabprevious<CR>
inoremap <A-h> <Left>
" Switch to previous tab
if version >= 810
   nnoremap <expr> o (mode(1) == 'nt') ? 'i' : 'o'
   tnoremap <A-l> <C-w>N:let b:termSwap = 1 <BAR> :tabnext<CR>
   tnoremap <A-h> <C-w>N:let b:termSwap = 1 <BAR> :tabprevious<CR>
   tnoremap <A-m> <C-w>N:let b:termSwap = 1 <BAR> :call OpenNewTabWithNetrw()<CR>
   autocmd ModeChanged *:t let b:termSwap = 0
   autocmd BufEnter * if (&buftype ==# 'terminal' && mode(1) == 'nt' && (b:termSwap == 1 || g:in_git_commit == 1)) | exe 'normal! i' | let b:termSwap = 0 | let g:in_git_commit = 0 | endif
endif
nnoremap <S-A-h> :tabmove -1<CR>
inoremap <S-A-h> <Esc>:tabmove -1<CR>
" Moves tab to the left one position
cnoremap <A-h> <Left>
" Moves left in the command line
nnoremap <silent><A-m> :call OpenNewTabWithNetrw()<CR>
inoremap <silent><A-m> <Esc>:call OpenNewTabWithNetrw()<CR>
" Opens a new tab with explorer view, looking at previous file
nnoremap <A-j>   :call ShiftScreen("j")<CR>
inoremap <A-j>   <C-o>:call ShiftScreen("j")<CR>
vnoremap <A-j>   <C-e>j
nnoremap <A-k>   :call ShiftScreen("k")<CR>
inoremap <A-k>   <C-o>:call ShiftScreen("k")<CR>
vnoremap <A-k>   <C-y>k
" Move cursor and shift window at the same time (I use this everyday)
cnoremap <A-k> <Up>
cnoremap <A-j> <Down>
if version >= 810
   tnoremap <A-j> <Down>
   tnoremap <A-k> <Up>
endif
nnoremap <expr> <S-A-w> &diffopt=~'iwhite'? ":set diffopt-=iwhite<CR>" : ":set diffopt+=iwhite<CR>"
" Toggles whitespace diffing.
nnoremap <expr> <A-u> &diff? "]c" : "<C-d>"
nnoremap <expr> <A-i> &diff? "[c" : "<C-u>"
" Move half a page down and up respectively
"  or (when in a diff) move to next/previous difference
nnoremap <A-n>   .n
inoremap <A-n>   <Esc>.n
" Micro Macros :P
nnoremap <silent><A-p> :setlocal spell! spelllang=en_us <BAR> :let g:spellSuggestionCount = 1<CR>
inoremap <silent><A-p> <C-o>:setlocal spell! spelllang=en_us <BAR> :let g:spellSuggestionCount = 1<CR>
" Toggle spell check
nnoremap ]s ]s:let g:spellSuggestionCount = 1<CR>
nnoremap [s [s:let g:spellSuggestionCount = 1<CR>
" Finds next/prev spelling mistake (not a change just also clears cycle count)
nnoremap ]a :call CycleTrhoughSpellSuggestion()<CR>
nnoremap [a :call CycleTrhoughSpellSuggestion()<CR>
" Automatically changes word under cursor to the next suggested word in spell check
"   (press repeatedly to advance to next word)
nnoremap ]q :call BringUpSpellSuggestionList()<CR>z=
nnoremap [q :call BringUpSpellSuggestionList()<CR>z=
" Pulls up a list of suggestions for word under cursor (If you've been cycling
"   it will revert word back to original first).
nnoremap ][ ]]
nnoremap ]] ][
" This just makes more sense to my brain.
nnoremap <A-=>   :call BlockAutoIndent()<CR>
inoremap <A-=>   <C-o>:call BlockAutoIndent()<CR>
" Auto indents current block {}
nnoremap <A-;>   C<C-R>=strftime("%m/%d/%Y %I:%M %p")<CR><Esc>
inoremap <A-;>   <Space><Esc>C<C-R>=strftime("%m/%d/%Y %I:%M %p")<CR>
" Puts current date and time
nnoremap <A-w>   :call ToggleReadOnlyBit()<CR>
" Toggles the read only bit on the file.... Did I really need this comment??
nnoremap <A-\>   :w<CR>:make<CR>
inoremap <A-\>   <Esc>:w<CR>:make<CR>
" Attempt a make
nnoremap <A-[>   :w<CR>:!%<CR><CR>
inoremap <A-[>   <Esc>:w<CR>:!%<CR><CR>
" Attempt a make for a sripting language
nnoremap <silent><A-o>   :call BlockCheck(0)<CR>
inoremap <silent><A-o>   <Esc>:call BlockCheck(1)<CR>
" On first call, pops to the top of current toplevel function. On second call,
"   returns to the previous location
nnoremap <A-b>   :set number!<CR>
inoremap <A-b>   <C-o>:set number!<CR>
" Toggle line numbers
nnoremap <A-B>   :call ToggleBinaryMode()<CR>
inoremap <A-B>   <C-o>:call ToggleBinaryMode()<CR>
" Open current file in binary mode
nnoremap <A-a> :set splitright <BAR> vsplit <BAR> set nosplitright<CR>
" Open up a vertical split to the right. (I want my vplits to use splitright,
" but I almost never want my diffsplits to. This is my workaround)
nnoremap <silent><A-v> :call OpenVimrc()<CR>:silent! normal! zO<CR>
" Opens vimrc (this file) in new tab
nnoremap <silent><A-V> :call OpenVimrc(1)<CR>:silent! normal! zO<CR>
" Opens vimpref in new tab
nnoremap <A-r>   :call OpenVimrc()<CR>GzR
" Opens vimrc (this file) in new tab and jumps to the regular expression section for quick reference.
nnoremap <A-.>   :pop<CR>
" Goes to the previous location in the tag stack
inoremap {{ {<Enter>}<Esc>k
" Auto puts closing brace and indents you to the right place automatically
nnoremap <A-z>   za
" Toggles current fold (It doesn't seem like much of a shortcut but za is really hard to hit)
if system('uname') == "Darwin\n"
   nnoremap <D-/> :macaction newWindow:<CR>
elseif has("unix")
   nnoremap <A-/> :!gvim<CR>
else
   nnoremap <A-/> :!start gvim<CR>
endif
" Opens another gVim instance

" Vimgrep
nnoremap <A-8>   :exec "ProjectGrep \\<". expand('<cword>') ."\\>"<CR>
nnoremap g<A-8>  :exec "ProjectGrep ". expand('<cword>')<CR>
" * vimgrep: works like * but greps the current directory instead of just the file
nnoremap <A-N>  :call NextQuickFix()<CR>
nnoremap <A-P>  :call NextQuickFix(1)<CR>
" Jumps to the next/previous item in the quickfix
nnoremap <S-CR>   :set switchbuf+=newtab<CR><CR>:set switchbuf-=newtab<CR>
" Shift+Enter opens files from quickfix in a new tab
nnoremap <A-q> :call <SID>SmartQuit()<CR>
inoremap <A-q> <C-o>:call <SID>SmartQuit()<CR>
" Closes diff or quickfix window
nnoremap <silent><A-s> :let @z=@" <bar> let @"=@s <bar> let @s=@z <CR>
" Saves the unamed register to register s for later use. Press again to restore.
vnoremap <silent><A-S> cs<Esc>b
" Pastes contents of the "saved" register

" File stuff
nnoremap <A-g> <C-^>
"Alt+G to go to alternate file (Usually the last file edited)

vnoremap > >gv
vnoremap < <gv
" Makes indenting multiple times easier

" Custom F commands
nnoremap <expr><F2> exists('g:undotree_TreeNodeShape')?':UndotreeToggle<CR>':''
" Give a graphical view of the undo tree (Requires undotree plugin)
" (http://www.vim.org/scripts/script.php?script_id=4177)
nnoremap <S-F2>  :mksession $HOME/vimfiles/Session.vim <BAR> :qa<CR>
" Save session and exit (will be re-opened next time vim is launched)
nnoremap <F3>    :call ToggleAutoScroll()<CR>
inoremap <F3>    <C-o>:call ToggleAutoScroll()<CR>
" Toggles cursor being held in the middle of the screen
nnoremap <silent><F4>  :let b:lastSearch = @/<CR>ma/{<CR>%y'a:let @/ = b:lastSearch<CR>
inoremap <silent><F4>  <C-o>:let b:lastSearch = @/<CR>ma/{<CR>%y'a:let @/ = b:lastSearch<CR>
" Yank C-style block
nnoremap <F5>    :e<CR>
inoremap <F5>    <C-o>:e<CR>
" Reloads the current file from disk
nnoremap <F5>    :e!<CR>
inoremap <F5>    <C-o>:e!<CR>
" Force reloads the current file from disk and abandons current changes
nnoremap <C-F5>    :syn off<CR>:syn on<CR>:source $MYVIMRC<CR>
inoremap <C-F5>    <Esc>:syn off<CR>:syn on<CR>:source $MYVIMRC<CR>
" Reloads syntax file and vimrc
nmap <F6> :call VimFunctionDoc()<CR>
" Adds Tevis style documentation for functions
" (Place cursor on function name and press F6)
nnoremap <S-F6>  :call Javadoc()<Esc>
" Adds Javadoc
nnoremap <silent><F7>  :noh<CR>
inoremap <silent><F7>  <C-o>:noh<CR>
" Clears all highlighting
nnoremap <S-F9>    :%MkVimball! TumblerVimball<CR>
nnoremap <S-F12> :call RemoveTrailingWhitespace() <BAR> retab<CR>
inoremap <S-F12> <C-o>:call RemoveTrailingWhitespace() <BAR> retab<CR>
" Removes all trailing whitespace in file

nnoremap <silent><A-0> :call setqflist([]) \| cclose<CR>
" Closes and wipes the quickfix so we can more easily traverse the location list.
" (See <A-N> and <A-P>

inoremap <S-Tab> <Esc>^<<a
" Makes Shift+Tab work like expected

nnoremap Q <C-q>
" Don't need Ex mode, but visual block mode is useful

vmap <expr> <LEFT>   exists('g:DVB_TrimWS')? DVB_Drag('left') : ''
vmap <expr> <RIGHT>  exists('g:DVB_TrimWS')? DVB_Drag('right') : ''
vmap <expr> <DOWN>   exists('g:DVB_TrimWS')? DVB_Drag('down') : ''
vmap <expr> <UP>     exists('g:DVB_TrimWS')? DVB_Drag('up') : ''
vmap <expr> D        exists('g:DVB_TrimWS')? DVB_Duplicate() : ''

cnoremap %% %:p:h:t/%
" Creates a generalized previous directory as well as file on the command line.



"< End of mappings

"> Autocommands
if has("autocmd")
augroup Tumbler
   au!
   "Make sure to wipe out previous declarations so we can reload safely

   " Initialization (can't be called until functions are loaded)
   autocmd VimEnter    * call LoadSession()
                         " If a session was previously saved, load it

   autocmd VimEnter    * if exists('g:loaded_helplink') | let g:helplink_copy_to_registers = ['+', '*', '"'] | endif
   " Add unnamed register to helplink

   autocmd VimEnter    * call <SID>SetStatusLine()

   autocmd VimEnter    * call <SID>SetMacAltMappings()
   " Mac uses command instead of Alt

   " Buffer specific stuff
   autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
   " When editing a file, always jump to the last cursor position.

   autocmd BufReadPost * if (&filetype != 'qf' && !exists('w:ColorColumnID')) | let w:ColorColumnID = matchadd('ColorColumn', '\%81v.') | endif
   " Highlight the 81st character on the line if it's not the quickfix.
   autocmd FilterWritePost * if (&diff && exists('w:ColorColumnID')) | call matchdelete(w:ColorColumnID) | unlet w:ColorColumnID | endif
   " When diffing take out the coloring because it looks like diff highlighting.
   autocmd VimResized * if (&diff) | wincmd = | endif

   autocmd BufReadPost * call SetLineEndings()

   autocmd ModeChanged *:t setlocal nonumber

   autocmd CmdwinEnter * if getcmdwintype() == '@' | setlocal spell | startinsert! | endif
   " If using command window from an input turn on spell check (Only available in Vim 7.4.338 and above)

   autocmd BufNewFile,BufReadPost,FileType * call timer_start(10, 'ScrewFtPlugin')
   " Screw ftplugin; this is how I want my formatting!

   autocmd FileType gitcommit set t_Co=256 | let g:in_git_commit = 1
augroup END
augroup QuickComments
   au!

   autocmd BufReadPre  * nmap<buffer>  <A-c>   I//<Esc>$<A-j>
   autocmd BufReadPre  * imap<buffer>  <A-c>   <Esc>I//<Esc>$<A-j>
   autocmd BufReadPre  * nmap<buffer>  <A-x>   ^2x$<A-j>
   autocmd BufReadPre  * imap<buffer>  <A-x>   <Esc>^2x$<A-j>
                         " Generalized quick comments (C-style)

   " Filetype dependent stuff
   " Perl
   autocmd FileType perl     nmap<buffer>  <A-c>   I#<Esc>$<A-j>
   autocmd FileType perl     imap<buffer>  <A-c>   <Esc>I#<Esc>$<A-j>
   autocmd FileType perl     nmap<buffer>  <A-x>   ^x$<A-j>
   autocmd FileType perl     imap<buffer>  <A-x>   <Esc>^x$<A-j>
                             " Perl style quick comments

   autocmd FileType python   nmap<buffer>  <A-c>   I#<Esc>$<A-j>
   autocmd FileType python   imap<buffer>  <A-c>   <Esc>I#<Esc>$<A-j>
   autocmd FileType python   nmap<buffer>  <A-x>   ^x$<A-j>
   autocmd FileType python   imap<buffer>  <A-x>   <Esc>^x$<A-j>
                             " Python style quick comments
   " HTML
   autocmd FileType html     nmap<buffer>  <A-c>   A--><Esc>I<!--<Esc>$<A-j>
   autocmd FileType html     imap<buffer>  <A-c>   <Esc>A--><Esc>I<!--<Esc>$<A-j>
   autocmd FileType html     nmap<buffer>  <A-x>   $xxx^xxxx$<A-j>
   autocmd FileType html     imap<buffer>  <A-x>   <Esc>$xxx^xxxx$<A-j>
                             " HTML style quick comments
   " Assembly
   autocmd FileType asm      nmap<buffer>  <A-c>   I;<Esc>$<A-j>
   autocmd FileType asm      imap<buffer>  <A-c>   <Esc>I;<Esc>$<A-j>
   autocmd FileType asm      nmap<buffer>  <A-x>   ^x$<A-j>
   autocmd FileType asm      imap<buffer>  <A-x>   <Esc>^x$<A-j>
                             " Assembly style quick comments
   " Batch
   autocmd FileType dosbatch nmap<buffer> <A-c>    I::<Esc>$<A-j>
   autocmd FileType dosbatch imap<buffer> <A-c>    <Esc>I::<Esc>$<A-j>
   autocmd FileType dosbatch nmap<buffer> <A-x>    ^2x$<A-j>
   autocmd FileType dosbatch imap<buffer> <A-x>    <Esc>^2x$<A-j>
                             " Batch style quick comments (May God have mercy on your soul)

   " And of course we can't forget Vim files! :D
   autocmd FileType vim      nmap<buffer>  <A-c>   I"<Esc>$<A-j>
   autocmd FileType vim      imap<buffer>  <A-c>   <Esc>I"<Esc>$<A-j>
   autocmd FileType vim      nmap<buffer>  <A-x>   ^x$<A-j>
   autocmd FileType vim      imap<buffer>  <A-x>   <Esc>^x$<A-j>
                             " Vim style quick comments

augroup END
endif
"<

"> Initializations
" Init all global variables here:
let g:recognizedFiles = ['.bat', '.exe']
" Used in ExecuteRecognizedFile(). You can add to this array in your vimpref
let g:spellSuggestionCount = 1
let g:input_hist_index = 0

if !isdirectory($HOME.'/vimfiles')
   call mkdir($HOME.'/vimfiles')
endif
if !isdirectory($HOME.'/vimfiles/undo')
   call mkdir($HOME.'/vimfiles/undo')
endif
" Makes sure that our location for persistent undo exists
if !isdirectory($HOME.'/vimfiles/swap')
   call mkdir($HOME.'/vimfiles/swap')
endif
" Makes sure that our location for swap files exists
if filereadable($HOME.'/vimfiles/.vimpref')
   source $HOME/vimfiles/.vimpref
endif
" Loads additional, location specific, options should there be any

let g:in_git_commit = 0

"< End of Initializations

"> Functions
" Bang after function means if the vimrc is reloaded they will get overwritten

" ToggleAutoScroll ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Toggles between keeping the cursor in the center of the screen and
"          regular operation.
"     returns - void
function! ToggleAutoScroll()
   if &scrolloff =~# '9999'
      set scrolloff=0
   else
      set scrolloff=9999
   endif
endfunction

" BlockCheck ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Toggles between beginning of function and another location within
"          the function. (Only works for C-like functions)
"     input   - insertMode: [bool] Whether or not to go back into inser mode
"                           after completion
"     returns - void
function! BlockCheck(insertMode)
   if !exists('b:checkingBlock')
      let b:checkingBlock = 0
      let b:insertCheckOn = 0
   endif

   if (b:checkingBlock == 0)
      normal! ms][md%mfzz
      let b:checkingBlock = 1
      let b:insertCheckOn = a:insertMode
   else
      if ((line('.') >= line("'f")-1) && (line('.') <= line("'d'")))
         normal `s
         if (b:insertCheckOn == 1)
            normal! l
            startinsert
            " If we started in insert mode, go back to insert mode
         endif
         let b:checkingBlock = 0
      else
         " Not in the block we came from, start again.
         let b:checkingBlock = 0
         call BlockCheck(a:insertMode)
      endif
   endif
endfunction

" SaveBuffer ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Saves buffer and updates last edited value if applicable.
"     input   - source: [int] Determines what kind of save command has been
"                       issued
"     returns - void
function! SaveBuffer(source)
   if (&mod == 1 || a:source == 4)
      " Only update the last edited info if the file has been modified.
      let firstLine = getline(1)
      if (firstLine =~ "@Tracked")
         " Only applies to tracked files
         if (a:source == 2 || a:source == 3 || a:source == 4)
            let choice = 'y'
         else
            echohl ERROR
            call inputsave()
            let choice = input("Update change info? (y/n) ")
            call inputrestore()
            echohl NONE
         endif
         if (choice == 'y')
            let b:lastSearch = @/
            let b:currentView = winsaveview()
            " Save Window State
            exec feedkeys("gg/Last Edited: \\d\\d\\/\\d\\d\\/\\d\\d\\d\\d \\d\\d:\\d\\d \\(A\\|P\\)M\\C\<CR>")
            " Find last edited doc line (pretty specific criteria)
            let b:currentLineOnCursor = line(".")
            if (b:currentLineOnCursor < 10)
               " Only do it if it's on the first 10 lines
               exec feedkeys("www\<A-;>:write\<CR>")
            endif
            exec feedkeys(":let @/ = b:lastSearch\<CR>")
            " Reinstates the last search pattern
            exec feedkeys(":call winrestview(b:currentView)\<CR>\<A-j>\<A-k>")
            " Put window position back to where it was (better than `a)
         endif
      endif
      if (&mod == 1)
         write
      endif
      if (a:source == 1 || a:source == 3)
         quit
      endif
   else
      write
      if (a:source == 1 || a:source == 3)
         quit
      endif
   endif
endfunction

" OpenVimrc <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Intelligently opens $MYVIMRC or .vimpref
"     input   - optional: [bool] If present opens .vimpref instead
"     returns - void
function! OpenVimrc(...)
   " open in new tab unless current one is empty
   if line('$') == 1 && getline(1) == ''
      if (a:0 == 0)
         exec 'e $MYVIMRC'
      else
         exec 'e $HOME/vimfiles/.vimpref'
      endif
   else
      exec 'tabnew'
      if (a:0 == 0)
         exec 'e $MYVIMRC'
      else
         exec 'e $HOME/vimfiles/.vimpref'
      endif
   endif
endfunction

" RemoveTrailingWhitespace ><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Removes all trailing whitespace and returns the window as it was.
"     returns - void
function! RemoveTrailingWhitespace()
   let initialWindowView = winsaveview()
   %s/\s\+$//e
   call winrestview(initialWindowView)
endfunction

" ToggleReadOnlyBit <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Toggles turning the file read only.
"     returns - void
function! ToggleReadOnlyBit()
  let fname = fnameescape(substitute(expand("%:p"), "\\", "/", "g"))
  checktime
  execute "au FileChangedShell " . fname . " :echo"
  if &readonly
    silent !attrib -r %
  else
    silent !attrib +r %
  endif
  checktime
  set invreadonly
  execute "au! FileChangedShell " . fname
endfunction

" ShiftScreen <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Intelligently shifts screen one line in either direction
"     input   - direction: [char] If 'j' then scroll down; up otherwise
"     returns - void
function! ShiftScreen(direction)
" If we're in auto shift mode then don't add an extra shift
   if &scrolloff =~# '9999'
     if a:direction == "j"
        normal j
     else
        normal k
     endif
   else
     if a:direction == "j"
        normal j
     else
        normal k
     endif
   endif
endfunction

" EchoError <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Echos message with error highlighting (usually red background with
"          white text).
"     input   - message: [string] A string to echo on the command line
"     returns - void
function! EchoError(message)
   echo "\n"
   echohl ERROR
   echo a:message
   echohl NORMAL
endfunction

" ToggleBinaryMode ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: See :h xxd and :h binary for more information.
"     returns - void
function! ToggleBinaryMode()
   if !(&binary)
      set binary
      exe "%!xxd"
      set nomodifiable
   else
      set modifiable
      exe "%!xxd -r"
      set nobinary
   endif
endfunction

" ExecuteRecognizedFile <><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: If extension matches a list stored in g:recognizedFiles, then run it
"          in a shell in the background.
"     returns - void
function! ExecuteRecognizedFile()
   let fileToExecute = substitute(expand('<cWORD>'), '\*\($\)\@=', '', '')
   let found = 0
   for extention in g:recognizedFiles
      if (fileToExecute =~ extention . '$')
         let found = 1
         cd %:p
         if has("win32")
            exe 'silent !start /b cmd /c '.expand("%:p").fileToExecute
         elseif
            " Unix code here
         endif
      endif
   endfor
   if (!found)
      call EchoError("File not recognized")
   endif
endfunction

" InputHistory ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Cycle trough command line history when in an input() command.
"     input   - direction: [int] Which direction to travel in the input history
"     returns - void
function! InputHistory(direction) abort
    if (a:direction == 2)
       let g:input_hist_index = 0
       return "\<CR>"
    else
       let g:input_hist_index = g:input_hist_index + (a:direction ? 1 : -1)
       return "\<C-U>" . histget('@', g:input_hist_index)
    endif
endfunction

" VimFunctionDoc ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Processes the current line and tries to interpret a function name and
"          arguments and fills in a template for a function header.
"    returns - void
function! VimFunctionDoc()
   let lineToProcess = [getline('.')]
   call Chomp(lineToProcess, '\s\+function!\=\s\+')
   let name = Chomp(lineToProcess, '\w\+\ze\s*(')
   exe "normal! O\" \<Esc>39a<>"
   exe 'normal! 0llR' . name . ' '
   exe "normal! o\"   brief: \<Esc>ma"
   let argument = Chomp(lineToProcess, '\s*(\s*\zs\w\+')
   exe 'normal! o"     input   - void'
   while (len(argument) > 0)
      exe 'normal! 17|R'. argument .': [] '
      exe 'normal! o"                '
      let argument = Chomp(lineToProcess, '^\s*,\=\s*\zs\w\+')
   endwhile
   if (Chomp(lineToProcess, '^\s*\(,\|(\)\s*\zs\.\.\.') == '...')
      exe "normal! 17|Roptional: [] \<Esc>o\"                "
   endif
   exe "normal! 7|Rreturns -  \<Esc>D"
   normal! `a
   startinsert!
endfunction

" Javadoc <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Generate javadoc template.
"     returns - void
function! Javadoc()
   let lineToProcess = [getline('.')]
   let returnType = Chomp(lineToProcess, '\w\+\ze\s\+\w\+\s*(')
   let name = Chomp(lineToProcess, '\w\+\ze\s*(')
   let param = []
   let type = []
   let longestParam = 0
   normal! O/**
   exe "normal! o0C * <h1> " . name . " </h1>"
   exe "normal! o0C * ma"
   exe "normal! o0C *"

   let numberOfParams = 0
   " First pass: count parameters and find longest one (so we can align
   "   everything to that one).
   while (1)
      call add(type,  Chomp(lineToProcess, '\s*\zs\w\+\>\( \=\*\)\='))
      call add(param, Chomp(lineToProcess, '\s*\zs\w\+\>'))
      if (type[numberOfParams] == '' || param[numberOfParams] == '')
         break
      endif
      let longestParam = (longestParam > strlen(param[numberOfParams]))? longestParam : strlen(param[numberOfParams])
      let numberOfParams += 1
   endwhile
   let numberOfParams = 0
   " Second pass: write out the parameters.
   while (1)
      if (type[numberOfParams] != '' && param[numberOfParams] != '')
         exe "normal! o0C * @param  " . param[numberOfParams] . repeat(" ", longestParam-strlen(param[numberOfParams])) . " [".type[numberOfParams]."]"
      else
         break
      endif
      let numberOfParams += 1
   endwhile
   exe "normal! o0C * @return " . repeat(" ", longestParam) . " [".((returnType == '')? "void": returnType)."]"
   normal! o0C**/`a
   startinsert!
endfunction

" Chomp <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: returns pattern match and discards string up to match
"    input   - stringAsList: [[String]] A length one list that contains a String
"                            to match against
"              pattern: [string] A regex string to match
"    returns - The match from the pattern
" TODO: Make more robust
function! Chomp(stringAsList, pattern)
   let retVal = matchstr(a:stringAsList[0], a:pattern)
   call add(a:stringAsList, matchstr(a:stringAsList[0], retVal.'\zs.*'))
   call remove(a:stringAsList, 0)
   return retVal
endfunction

" BlockAutoIndent <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Automatically tries to indent current block and moves cursor relative
"          to indent.
"     returns - void
function! BlockAutoIndent()
   normal ma
   let initialColumn = col('.')
   normal ^
   let relativeDistance = initialColumn - col('.')
   normal =iB`a^
   if (relativeDistance > 0)
      exe "normal " . relativeDistance . 'l'
   elseif (relativeDistance < 0)
      exe "normal " . abs(relativeDistance) . 'h'
   endif
endfunction

" NextQuickFix ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Moves in quickfix. If there are no errors, then try the location
"          list instead.
"     input   - optional: [bool] If present then it moves backwards
"     returns - void
function! NextQuickFix(...)
   try
      if (a:0 > 0)
         cp
      else
         cn
      endif
   catch /^Vim\%((\a\+)\)\=:E42/
      try
         " Catch no error file errors and redirect to location list
         if (a:0 > 0)
            lp
         else
            lne
         endif
         " If all this fails then try to find the next ALE error
      catch /^Vim\%((\a\+)\)\=:E776/
         if exists('g:loaded_ale')
            if (a:0 > 0)
               ALEPrevious
            else
               ALENext
            endif
         endif
      endtry
   catch /^Vim\%((\a\+)\)\=:E553/
   endtry
endfunction

" CycleTrhoughSpellSuggestion <><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Try the next suggestion. If called again increments and goes to next
"          item.
"     returns - void
function! CycleTrhoughSpellSuggestion()
   if (g:spellSuggestionCount != 1)
      undo
   endif
   exe "normal! " . g:spellSuggestionCount . "z="
   let g:spellSuggestionCount += 1
endfunction

" BringUpSpellSuggestionList ><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Handles some secondary functions to execute when bringing up the list.
"     returns - void
function! BringUpSpellSuggestionList()
   if (g:spellSuggestionCount != 1)
      undo
   endif
   let g:spellSuggestionCount = 1
   " z= doesn't work from inside function, had to extricate...
endfunction

" LoadSession <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: If a previous vim session was saved, load it and delete it.
"     returns - void
function! LoadSession()
   if filereadable($HOME.'/vimfiles/Session.vim')
      source $HOME/vimfiles/Session.vim
      call delete($HOME.'/vimfiles/Session.vim')
   endif
endfunction

" ReplaceBadWhitespaceInDir <><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Replaces tabs and trailing whitespace in all files in a directory.
"     returns - void
function! ReplaceBadWhitespaceInDir()
   echohl ERROR
   call inputsave()
   let choice = input("Replacing all whitespace in directory. This CANNOT be undone. Continue? (y/n) ")
   call inputrestore()
   echohl NONE

   if (choice == 'y')
      let currentDir = fnameescape(expand("%:p:h"))
      exe "args ". currentDir . "/?*"
      argdo if(&modifiable) | %s/\s\+$//e | retab | update | endif
   else
      echo " "
   endif
endfunction

" OpenNewTabWithNetrw <><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Opens a new tab with netrw, pointing at previous file. Also enables
"          cvs highlighting if that plugin is enabled.
"     returns - void
function! OpenNewTabWithNetrw()
   let l:tmp = expand('%')
   Texplore
   exe "normal /^".l:tmp."$\r"
   if exists('g:cvsnetrwIntegration')
      call UpdateCVSHilighting()
   endif
endfunction

" ParagraphToEightyChars ><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: If the current line is > 80 chars then it will split the line on
"          whitespace and then join the next line. It will keep doing this until
"          it finds a line that is less than 80 chars long.
"     input   - optional: [bool] If present and true, will never join the next
"                         line. Useful if you only have one line of text that
"                         you don't want to run into the next line
"     returns - void
function! ParagraphToEightyChars(...)
   let commentHeader = matchstr(getline('.'), '^\s*\zs\(//\|"\|#\|\)\ze\s\=')
   let cursorCol = col('.')
   if (cursorCol >= 75)
      if (len(commentHeader) > 0)
         normal! ^w
      else
         normal! ^
      endif
      let cursorCol = col('.')
   elseif (getline('.')[:col('.')-1] =~ '^\s*\(//\|"\|#\|\)\s\+$')
      normal! dw
   endif
   while (len(getline('.')) > 80)
      normal! 0
      " Find the first white-space character before the 81st character.
      call search('\(\%82v.*\)\@<!\s\+\(.*\s.\{-}\%82v\)\@!', 'c', line('.'))
      " Replace it with a new line if the word itself isn't longer than 80
      " chars. (If it is, it's a lost cause. We can't properly break up the
      " line so just give up.)
      let cWORD = expand('<cWORD>')
      if (len(cWORD) < (80 - cursorCol) && len(cWORD) > 0)
         exe "normal! r\<CR>"
         :s/\s\+$//e
         " Start the line on the same line that the cursor started on
         if !(len(commentHeader) == 0 && col('.') == 1)
            normal! w
         endif
         " There's an edge case where if you start with no comment header and
         " the first character(s) on a line happens to match a comment header it
         " will trick formatoptions into putting headers. This while loop makes
         " sure that if you started with no commend headers, it will stay that
         " way.
         while (col('.') > cursorCol && !len(commentHeader))
            normal! hx
         endwhile
         " Formatoptions always uses the first \w to line up to. Sometimes you
         " don't want this, so it will now align it to your initial cursor
         " position.
         if (cursorCol < 75 && cursorCol != col('.'))
            exe "normal! i" . repeat(' ', cursorCol - col('.'))
         endif
      else
         break
      endif
      " If the next line has words and is part of a comment block, then join it
      " to avoid weird paragraph breaks.
      let nextLine = line('.')+1
      if ((getline(line('.')+1) =~ '\w') &&
       \ (synIDattr(synID(nextLine, len(getline(nextLine)), 0), "name") =~ 'comment\c\|^$')) &&
       \ (!a:0 || !a:1)
         normal! J
      endif
   endwhile
   " Trim any accidental trailing whitespace
   :s/\s\+$//e
endfunction

function! SetLineEndings()
   if &modifiable == 1 | set fileformat=unix | endif
   " Set line endings, because Windows is wrong...  (has to be done for each
   " buffer, but only if the file is modifiable) Redefine this function if you
   " don't like this functionality.
endfunction

function! s:Quit()
   let savedWindow = winnr()
   if (savedWindow + 1 <= winnr('$'))
      exec savedWindow+1 . " wincmd w"
      if (exists('w:quickfix_title'))
         quit
      else
         exec savedWindow . " wincmd w"
      endif
   endif
   quit
endfunction

" Retab <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Does a retab but first sets tab settings so they end up correct.
"     input   - tablength: [int] Number of tabs spaces that the file was created
"                                with
"     returns - void
function! s:Retab(tablength)
   let myShiftWidth = &shiftwidth
   let myTabStop = &tabstop
   let mySoftTabStop = &softtabstop

   exec "set shiftwidth=". a:tablength
   exec "set tabstop=". a:tablength
   exec "set softtabstop=". a:tablength

   retab

   exec "set shiftwidth=". myShiftWidth
   exec "set tabstop=". myTabStop
   exec "set softtabstop=". mySoftTabStop
endfunction!

function! ScrewFtPlugin(timer)
   noa setlocal formatoptions=jrql2
endfunction


" SetMacAltMappings <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Rekeys all alt mappings as command mappings. Only mappings from vimrc
"          are considered. NOTE: Currently only does n, i, and c maps. You'll
"          need to edit if you add v or o maps.
"          Random: Use:
"                      'defaults write org.vim.MacVim NSUserKeyEquivalents -dict-add "Quit MacVim" nil'
"                      'defaults write org.vim.MacVim NSUserKeyEquivalents -dict-add "Settings..." nil'
"                  to restore use of <D-q> and <D-,> in MacVim
"     returns - void
function! s:SetMacAltMappings()
   if (system("uname") != "Darwin\n")
      " Only for MacOS
      return
   endif

   let maps  = execute("verbose nmap")
   let maps .= execute("verbose imap")
   let maps .= execute("verbose cmap")
   let maps .= execute("verbose tmap")

   " Archive map arguments for later use (because :map command doesn't tell us)
   let arguments = {}
   for line in readfile($MYVIMRC)
      if (line =~ 'map <\(\(buffer\)\|\(nowait\)\|\(silent\)\|\(special\)\|\(script\)\|\(expr\)\|\(unique\)\)>\s*\S\+\s\+\S\+.*$')
         let argument = matchstr(line, '\(map \)\@<=<.\{-}>')
         let mapping = substitute(matchstr(line, '\(map '. argument .'\s*\)\@<=\S\+'), '<A-', '<M-', '')
         let arguments[mapping] = argument
      endif
   endfor

   " Read all mappings and remap alt mappings
   for line in split(maps, "\n")
      if (line =~ 'from \~\/\.vimrc')
         let splitLine = split(prevLine, '\s\+')
         if (len(splitLine) > 2)
            let mode = splitLine[0]
            if ((mode =~ '[nict]') && splitLine[1] =~ '<M-')
               let oldInput = splitLine[1]
               let input = substitute(oldInput, '<M-', '<D-', 'g')
               let rightHandSide = matchstr(prevLine, '\(<M-.\{-}>\s\+\(\* \)\=\)\@<=[^*]*$')
               let rightHandSide = substitute(rightHandSide, '\(\\\)\@<!|', '\\|', 'g')
               if !(has_key(arguments, oldInput))
                  execute(mode .'noremap '. input .' '. iconv(rightHandSide, 'UTF-8', 'ascii//TRANSLIT'))
               else
                  execute(mode .'noremap '. arguments[oldInput] . input .' '. iconv(rightHandSide, 'UTF-8', 'ascii//TRANSLIT'))
               endif
            endif
         endif
      endif

      let prevLine = line
   endfor

endfunction

function! MyAleStatus()
   let info = ale#statusline#Count(bufnr(''))
   let errors = info.error
   let warnings = info.warning

   if (errors > 0)
      return '%#Error#E:'. errors .'%#StatusLine#'
   elseif (warnings > 0)
      return '%#Todo#W:'. warnings .'%#StatusLine#'
   endif

   return '   '
endfunction

function! s:SetStatusLine()
   hi statusLineCmd cterm=BOLD ctermbg=bg gui=BOLD guibg=#C2BFA5 guifg=#9010D0
   let formula = '%<%.45F\ %w%m%r'
   if exists('g:ale_enabled') && g:ale_enabled
      let formula.='\ %{%MyAleStatus()%}'
   endif
   let formula .= '%='
   if exists('g:loaded_fugitive')
      let formula .= '%#Identifier#%{FugitiveStatusline()}%#StatusLine#%='
   endif
   if v:version >= 900
      let formula .= '%#statusLineCmd#%-5S%#StatusLine#%='
   endif
   let formula .= '%-14.(%l,%c%V%)\ %P'
   
   execute 'set statusline='.formula
endfunction

" OpenDirectionalTerminal <><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Opens a terminal in a split window in the specified direction
"          (defaults right)
"     input   - optional: [h j k or l]
"     returns - void
function! s:OpenDirectionalTerminal(...)
   if (len(a:000) == 0 || a:1 ==# '' || a:1 ==# 'l')
      execute('terminal')
      execute('wincmd L')
   elseif (a:1 ==? 'h')
      execute('terminal')
      execute('wincmd H')
   elseif (a:1 ==? 'k')
      execute('terminal')
   elseif (a:1 ==? 'j')
      execute('terminal')
      execute('wincmd J')
   elseif (a:1 =~ 'ne\=w\=\|ta\=b\=')
      execute('tabnew | terminal ++curwin')
   endif
endfunction

function s:SmartQuit()
   if (&diff)
      let startingBuf = bufnr()
      wincmd w
      while 1
         if (&diff)
            quit
         endif

         if startingBuf != bufnr()
            wincmd w
         else
            break
         endif
      endwhile
   else
      cclose
      lclose
      pclose
   endif
endfunction

"< End of Functions

"> Plugins

if !isdirectory($HOME.'/vimfiles/autoload')
   call mkdir($HOME.'/vimfiles/autoload')
endif
if !isdirectory($HOME.'/vimfiles/vim-plug_plugin')
   call mkdir($HOME.'/vimfiles/vim-plug_plugin')
   if has("autocmd")
      autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
      " If we're creating this dir then we also need to install any plugins that
      " go in it.
   endif
endif

" Using vim-plug as my plugin manager (https://github.com/junegunn/vim-plug)

if (has("unix") && filereadable($HOME.'/.vim/autoload/plug.vim') || filereadable($HOME.'/vimviles/autoload/plug.vim'))
   call plug#begin('~/vimfiles/vim-plug_plugin')

   " The best colorscheme
   Plug 'Tumbler/oceannight'

   " Linking vim help resources online
   Plug 'Carpetsmoker/helplink.vim'

   " Graphical undo tree
   Plug 'mbbill/undotree'

   " The premier Git plugin for Vim
   Plug 'tpope/vim-fugitive'
   "Plug 'tpopo/vim-rhubarb'

   " Vim linter
   Plug 'dense-analysis/ale'
   " Might need 'packloadall | silent! helptags ALL' to make help work

   call plug#end()
endif

" Not a vim plugin, but use https://github.com/universal-ctags/ctags for ctags installation

" Use for git integration: `git config --global core.editor "[gvim name or path] -g --remote-wait-silent”`

" Load our colorscheme if we can.
try
   color oceannight
catch /^Vim\%((\a\+)\)\=:E185/
   color desert
   " Defaults to desert which comes with Vim and is decent.
endtry

" Make helplink copy to the unnamed (") register too so our FocusLost autocmd
"    doesn't screw it all up.
let g:helplink_copy_to_registers = ['+', '*', '"']

"<

let g:Tumbler_vimrc = 1

"> Tips and Tricks <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

" normal mode tips

" gi              - Goes to last insert location (good for searching for
"                    something and then returning to edit mode)
" ga              - Inspect character under cursor
" g?              - Rot13
" ={direction}    - Auto indents stuff (think =%)
" =iB             - Auto indents current inner Block {}
" zR              - Opens all folds in diffs
" zM              - Closes all folds in diffs
" <C-]>           - Goes to link in :help
" gu/U{direction} - Make {direction} text lowercase/uppercase.
" "3p             - Paste from 3 edits ago (works with 1 to 9)

" Vimscript tips

" variable prefixes
" b:    Local to the current buffer.
" w:    Local to the current window.
" t:    Local to the current tab page.
" g:    Global.
" l:    Local to a function.
" s:    Local to a :source'ed Vim script.
" a:    Function argument (only inside a function).
" v:    Global, predefined by Vim.

" Array Slices (or sublists as they're called in vimscript)
" list[3:5]    Only return the 4th to the 6th item in the list
" list[3:]     Only return the 4th and beyond item in the list
" list[:5]     Only return up to the 6th item in the list

                                           " Insert  Command-line   Lang-Arg ~
" :map   :noremap   :unmap   :mapclear        yes         yes           yes
" :map!  :noremap!  :unmap!  :mapclear!       yes         yes            -
" :nmap  :nnoremap  :nunmap  :nmapclear       yes          -             -
" :imap  :inoremap  :iunmap  :imapclear       yes          -             -
" :cmap  :cnoremap  :cunmap  :cmapclear        -          yes            -
" :lmap  :lnoremap  :lunmap  :lmapclear       yes*       yes*hh         yes*

" :[col]older         - Remembers previous quickfix/location list
" :[lol]der           - ^^ for the location list
" :[cl]newer          - Remembers more recent quickfix/location list
" :[lnew]er           - ^^ for the location list
" :[cl]ist            - Shows the contets of the quickfix
" :[lli]st            - ^^ for the location list
" :[cw]indow          - Opens the quickfix
" :[lw]indow         - ^^ for the location list

" :nore before a mapping command is for non-recursive mappings

" Here's a line to run a command prompt (Windows) completely in the background:
"  silent !start /b cmd /c {your cmd command here}

" Looking for an environment variable? Try tab-completing ":echo $"

" :retab is super useful!

" If you want to render your current file as HTML (with current color intact)
" try :TOhtml.

" See :h highlight-groups for all highlighting groups
" See :h autocmd-events-abc for a list of all events

" Do a double substitution with one regex:
" :s/foo\|bar/\={'foo':'bar','bar':'foo'}[submatch(0)]/g

" How to restict searches to syntax regions:
" http://vi.stackexchange.com/questions/8127/is-there-a-way-to-restrict-search-results-to-differences-in-a-diff

" Try `:set rightleft` for some random fun

" To disable autocmds for a single command use `:noautocmd {cmd}`

" Timing stuff: [time]
"    let beginTime = reltime()
"    let endTime = reltime()
"    echo reltimestr(reltime(beginTime, endTime))

"  XXX Vim Regex XXX
" ignorecase   "textToMatch" =~  'regex'    "textToNotMatch" !~  'regex'
" match case   "textToMatch" =~# 'regex'    "textToNotMatch" !~# 'regex'

" matchstr({expr}, 'pattern')  Matches the expression against the pattern and returns the string that matched

"  Quantifiers
"  Greedy
" *           Matches 0 or more of the preceding characters, ranges or
"                metacharacters .* matches everything including empty line
" \+          Matches 1 or more of the preceding characters...
" \=          Matches 0 or 1 more of the preceding characters...
" \{n,m}      Matches from n to m of the preceding characters...
" \{n}        Matches exactly n times of the preceding characters...
" \{,m}       Matches at most m (from 0 to m) of the preceding characters...
" \{n,}       Matches at least n of of the preceding characters...

"     Non-greedy
" \{-}        Matches 0 or more of the preceding characters, as few as possible
" \{-n,m}     Matches n to m of the preceding characters...
" \{-n,}      Matches at least n or more of the preceding characters...
" \{-,m}      Matches 1 or more of the preceding characters...

"     Character classes (capital to negate)
" \s          Whitespace character
" \d          Digit
" \x          Hex digit
" \o          Octal digit
" \h          Head of word character
" \w          Word character
" \a          Alphabetic character
" \l          Lowercase character
" \u          Uppercase character
" \_.         Matches anything (including a newline)

"     Metacharacters (apparently these are called "pattern atoms")
" \<, \>      Word boundary marks
" ^           Beginning of line
" $           End of line
" \zs         Matches any position (useful for splitting strings
"                into list of chars) Also sets start of match

"     Restrict regex to certain screen positions:
" \%5l        Only on line 5
" \%80c       Only at column 80
" \%'m        Mark "m"

"     Lookaheads/behinds
" y\(xx\)\@=  Mathces y (and only the y) when it's followed by two x's
" y\(xx\)\@!  Matches y (and only the y) when it's not followed by two x's
" \(xx\)\@<=y Matches y (and only the y) when it's preceded by two x's
" \(xx\)\@<!y Matches y (and only the y) when it's not preceded by two x's

" Note: Parins and "@" must be escaped!

"     Character ranges
" [amz159]    Matches 1 of a, m, z, 1, 5, or 9
" [a-z1-9]    Matches letters and number once
" [9-A]       Matches 9, :, ;, <, =, >, ?, @, or A once (ASCII-betical order)
" [^amz]      Matches everything but a, m, and z

"     Backreferences
" \(\)        A match group (will not effect pattern match)
" &, \0       The whole match pattern
" \1          The first match group
" \9          The ninth match group
"< End of Tips and tricks

" Autofold settings:
   "> to start
   "< to end
" vim:foldmethod=expr:fdl=0
" vim:fde=(getline(v\:lnum)=~'^">')?'>'.(matchend(getline(v\:lnum),'">*')-1)\:(getline(v\:lnum)=~'^"<')?'<'.(matchend(getline(v\:lnum),'"<*')-1)\:'='
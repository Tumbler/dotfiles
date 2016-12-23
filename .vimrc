" @Tracked
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 12/13/2016 02:38 PM

" TODO: Can have errors when doing ex commands on directories if the directory name contains a "%"

"> Settings
if (line('$') == 1 && getline(1) == '' && has("gui_running"))
   set columns=80
   set lines=45
endif
" If we have a new window, give it a decent size
set number
" Turn on line numbers
set incsearch
" When searching with "/" you will see initial matches as you search
set hlsearch
" Highlight all search matches
set makeprg=mk
set ruler
" Add line and column information to the bottom right of the window
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
"   This will allow ternimal vim to function
set ignorecase
set smartcase
" Make searches be case insensitive unless capital letters are used
set showmatch
" When an ending bracket (or parin, or brace) is typed, jump to the matching one briefly for confirmation
set tags=./tags;
" File it looks for to define ctags
set winaltkeys=no
" Allows us to use the menu shortcuts for ourselves, YAY! (i.e. Alt+h)
set autochdir
" Automatically sets the pwd to current file as you browse
set diffopt=filler,vertical,context:1000000
" Automatically opens diffs with filler lines for sync, vertically
"   (side-by-side), and with all folds open
set wildignore+=*.o,*.obj,*.bak,*.exe,*.aux,*.dvi,*.info,*.d,*.hex,*.map,*.lib,*.swp,*.elf,*.bin,*.out,*.zip,tags,*.lst,*.pp,*.dll,*.lst,*.rlf,*.sdb,*cof,*.dep,*.hxl,*.mcs,*.sym
" vimgrep ignores object files TODO: This seems to be getting set from netrw now for some reason. May need to set up an autocmd for a per buffer basis.
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
" Makes undo's persistant. AKA if you exit a file and then edit again you can
"   still undo your changes from before. (It's sweet)
set undolevels=10000
" Sets undo history to 10K changes (Default is 1000).
set sessionoptions=blank,buffers,curdir,folds,globals,localoptions,options,resize,slash,tabpages,winpos,winsize
" Save ALL the things when saving sessions

if has("gui_running") && has("autocmd")
augroup Focus
   au!
   autocmd FocusGained * let @" = @+
   autocmd FocusLost   * let @+ = @"
augroup END
else
   set clipboard^=unnamed
endif
" I often find myself wanting to copy between vims. The clipboard option
"   works OK for this but wipes out the clipboard when you do basically
"   anything and can get frustrating if you want to delete a line and
"   then paste. Now it only wipes out the clipboard when you leave vim.
"   However, this only works in Gvim.

set omnifunc=syntaxcomplete#Complete
" Attempt to intelligently fill the omnicomplete by filetype

set formatoptions+=jr
" Remove extra comments when [J]oining
" When in a comment, [r]eturn will automatically add a comment header

let g:netrw_sort_sequence='[\/]$,*,\.o$,\.obj$,\.info$,\.d$,\.hex$,\.map$,\.mcp$,\.mcw$,\.lib$,\.swp$,\.bak$,\.lst$,\.rlf$,\.sdb$,\.CVSfolderStatus,\~$'
" Change sorting sequence of netrw explorer to leave different filetypes together
let g:netrw_sort_options="i"
" Case insensitive sorting (still not sure why you would want to sort by case, but whatever)
let g:netrw_banner = 0
" Don't show netrw's "helpful" banner at the beginning of every directory
let do_syntax_sel_menu = 1
" Show filetypes in syntax menu (enables SetSyn() command)
if has("win32")
   let g:loaded_zipPlugin = 1
   let g:loaded_zip       = 1
   " Prevent vim from trying to open zip files (annoying when vimgrepping if not setup)
endif
if has("gui_running")
   set guioptions-=m
   " This removes the menu bar from the gui
   set guioptions-=T
   " This removes the toolbar from the gui
endif

filetype indent on
" Turn on filetype dependent indenting

iabbrev ture true
" Insert mode abbreviation for misspelling true.

" Command line abbreviations:
cabbrev h tab help
" Help opens in new tab
cabbrev w   call SaveBuffer(0)
cabbrev wq  call SaveBuffer(1)
cabbrev wy  call SaveBuffer(2)
cabbrev wqy call SaveBuffer(3)
" wf = write force
cabbrev wf  call SaveBuffer(4)
" When saving tracked files, vim will auto-update the last edited info

cabbrev \w w
" We have to be able to write "w" somehow...

cabbrev qt  tabclose
" Like :qa, but only closes the current tab

cabbrev D Diffsplit
" I use diffsplit a lot, might as well make it easer to type

cabbrev qh tabdo if (!buflisted(bufnr('%')) && &modifiable == 0) <BAR> tabclose <BAR> endif
" Closes all help tabs (Technically all unlsted non-modifiable, but this is usually going to just be help)

if has("unix") && !has("gui_running")
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

command! -nargs=1 -complete=file Diffsplit diffsplit <args> | wincmd p
" Diff a file and switches focus back on the original file
command! Whitespace :call ReplaceBadWhitespaceInDir()
" Replaces tabs and trailing whitespace in all files in a directory

if filereadable($VIMRUNTIME . '/colors/oceannight.vim')
   color oceannight
elseif filereadable($HOME . '/.vim/colors/oceannight.vim')
   color oceannight
else
   color desert
endif
" If the file exists, make the color scheme oceannight.
" Public access:
" https://drive.google.com/file/d/0B8PyjuTeepa8eUk2eEJhOHBLMWM/view?usp=sharing

if !exists("syntax_on")
  syntax enable
endif
"< End of Settings

"> Mappings
" <C-x>  means Ctrl+x
" <A-x>  means Alt+x   (<M-x> means the same thing)
" <S-x>  means Shift+x
" These commands can be chained. I.E. <S-A-C-x> NOTE: <C-A-x> and <C-S-x> does not work unless x is an F-key

inoremap <A-e> <Esc>
" Give an alternative to <Esc> that doesn't take your hand as far off of the keyboard

inoremap <Del> <NOP>
inoremap <A-BS> <Del>
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
nnoremap K  :exe "tab help ".expand('<cword>')<CR>
nnoremap gK :exe "tab help ".expand('<cWORD>')<CR>
" Opens help on word under cursor in a new tab

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

cnoremap <C-p> <C-r>"
inoremap <C-p> <C-r>"
" "Pastes" the current unnamed register

vnoremap J j
vnoremap K k

" AutoComplete. (Activated with Ctrl+Space)
inoremap <C-Space> <C-n>

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
nnoremap <C-d>   :res +10<CR>
inoremap <C-d>   <C-o>:res +10<CR>
nnoremap <C-s>   :vertical res +10<CR>
inoremap <C-s>   <C-o>:vertical res +10<CR>
" Increases size of splits incrementally
nnoremap <expr> <C-a> search('x\\|\(\<\)', "bpcn") == 1 ? "\<C-a>vUgUTxFxe" : "\<C-a>"
nnoremap <expr> <C-x> search('x\\|\(\<\)', "bpcn") == 1 ? "\<C-x>vUgUTxFxe" : "\<C-x>"
" Makes hex digits show up capital when auto-incrementing/decrementing

nnoremap <A-y>   @q
inoremap <A-y>   <Esc>@q
" Because @ is WAY too hard to hit
nnoremap <A-t>   @w
inoremap <A-t>   <Esc>@w
" Because sometimes you need two macros
nnoremap <expr> <A-l>  exists('g:cvsnetrwIntegration')? ":tabnext\<CR>:call UpdateCVSHilighting()\<CR>" : ":tabnext\<CR>"
inoremap <expr> <A-l>  exists('g:cvsnetrwIntegration')? "\<Esc>:tabnext\<CR>:call UpdateCVSHilighting()\<CR>" : "\<Esc>:tabnext\<CR>"
" Switch to next tab
nnoremap <S-A-l> :tabmove +1<CR>
inoremap <S-A-l> <Esc>:tabmove +1<CR>
" Moves tab to the right one position
cnoremap <A-l>   <Right>
" Moves right in the command line
nnoremap <expr> <A-h>  exists('g:cvsnetrwIntegration')? ":tabprevious\<CR>:call UpdateCVSHilighting()\<CR>" : ":tabprevious\<CR>"
inoremap <expr> <A-h>  exists('g:cvsnetrwIntegration')? "\<Esc>:tabprevious\<CR>:call UpdateCVSHilighting()\<CR>" : "\<Esc>:tabprevious\<CR>"
" Switch to previous tab
nnoremap <S-A-h> :tabmove -1<CR>
inoremap <S-A-h> <Esc>:tabmove -1<CR>
" Moves tab to the left one position
cnoremap <A-h>  <Left>
" Moves left in the command line
nnoremap <silent><A-m> :call OpenNewTabWithNetrw()<CR>
inoremap <silent><A-m> <Esc>:call OpenNewTabWithNetrw()<CR>
" Opens a new tab with explorer view, looking at previous file
noremap  <A-j>   :call ShiftScreen("j")<CR>
inoremap <A-j>   <C-o>:call ShiftScreen("j")<CR>
noremap  <A-k>   :call ShiftScreen("k")<CR>
inoremap <A-k>   <C-o>:call ShiftScreen("k")<CR>
" Move cursor and shift window at the same time (I use this everyday)
cnoremap <A-k> <Up>
cnoremap <A-j> <Down>
nnoremap <expr> <S-A-w> &diffopt=~'iwhite'? ":set diffopt-=iwhite<CR>" : ":set diffopt+=iwhite<CR>"
" Toggles whitespace diffing.
noremap  <expr> <A-u> &diff? "]c" : "<C-d>"
noremap  <expr> <A-i> &diff? "[c" : "<C-u>"
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
nnoremap <A-]>   :w<CR>:!%<CR><CR>
inoremap <A-]>   <Esc>:w<CR>:!%<CR><CR>
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
nnoremap <silent><A-v> :call OpenVimrc()<CR>:silent! normal! zO<CR>
" Opens vimrc (this file) in new tab
nnoremap <A-r>   :call OpenVimrc()<CR>GzR
" Opens vimrc (this file) in new tab and jumps to the regular expression section for quick reference.
nnoremap <A-,>   :call TraverseCtag()<CR>
" Goes to ctag under curser
nnoremap <A-.>   :pop<CR>
" Goes to the previous location in the tag stack
nnoremap <expr><A-<>   exists('g:vimProjectManager')? ":call GenerateCTags()<CR>":""
" Runs ctags on current project (See Project Manager) (assuming you have ctags installed)
inoremap {{ {<Enter>}<Esc>O
" Auto puts closing brace and indents you to the right place automatically
nnoremap <A-z>   za
" Toggles current fold (It doesn't seem like much of a shortcut but za is really hard to hit)

" Vimgrep
nnoremap <A-8>   wb"wyiw:lvimgrep /\<<C-r>w\>/j <C-r>=GetVimGrepFiles("") <CR> <CR>:lw<CR><C-W>j/\<<C-r>w\><CR>:cclose <BAR> call setqflist([])<CR>
nnoremap g<A-8>  wb"wyiw:lvimgrep /<C-r>w/j <C-r>=GetVimGrepFiles("") <CR> <CR>:lw<CR><C-W>j/<C-r>w<CR>:cclose <BAR> call setqflist([])<CR>
" * vimgrep: works like * but greps the current directory instead of just the file
nnoremap <S-A-n>  :call NextQuickFix()<CR>
nnoremap <S-A-p>  :call NextQuickFix(1)<CR>
" Jumps to the next/previous item in the quickfix
nnoremap <S-CR>   :set switchbuf+=newtab<CR><CR>:set switchbuf-=newtab<CR>
" Shift+Enter opens files from quickfix in a new tab
nnoremap <expr> <A-q> (&diff)? ':diffoff!<CR>w:q<CR>' : ':cclose <BAR> :lclose<CR>'
inoremap <expr> <A-q> (&diff)? '<C-o>:diffoff!<CR><C-o>w:q<CR>' : '<C-o>:cclose <BAR> :lclose<CR>'
" Closes diff or quickfix window
nnoremap <silent><A-s> :let @z=@" <bar> let @"=@s <bar> let @s=@z <CR>
" Saves the unamed register to register s for later use. Press again to restore.

" File stuff
map  <A-g> <C-^>
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
nnoremap <silent><F5>  :noh<CR>
inoremap <silent><F5>  <C-o>:noh<CR>
" Clears all highlighting
map      <F6>    "qyiwO<Esc>0D<A-c>k0"wy$:exe "normal ".(4-strlen(@w))."A "<CR>$38a<><Esc>0lllR<C-r>q <Esc>0lll
" Adds Tevis style documentation for functions
" (Place cursor on function name and press F6)
map      <S-F6>    :call Javadoc()<Esc>
" Adds Javadoc
nnoremap <F7>    :syn off<CR>:syn on<CR>:source $MYVIMRC<CR>
inoremap <F7>    <Esc>:syn off<CR>:syn on<CR>:source $MYVIMRC<CR>
" Reloads syntax file and vimrc
nnoremap <F9>    :%MkVimball TumblerVimball<CR>
nnoremap <S-F12> :call RemoveTrailingWhitespace() <BAR> retab<CR>
inoremap <S-F12> <C-o>:call RemoveTrailingWhitespace() <BAR> retab<CR>
" Removes all trailing whitespace in file

inoremap <S-Tab> <Esc>^<<a
" Makes Shift+Tab work like expected

nnoremap Q <C-q>
" Don't need Ex mode, but visual block mode is useful

vmap <expr> <LEFT>   exists('g:DVB_TrimWS')? DVB_Drag('left') : ''
vmap <expr> <RIGHT>  exists('g:DVB_TrimWS')? DVB_Drag('right') : ''
vmap <expr> <DOWN>   exists('g:DVB_TrimWS')? DVB_Drag('down') : ''
vmap <expr> <UP>     exists('g:DVB_TrimWS')? DVB_Drag('up') : ''
vmap <expr> D        exists('g:DVB_TrimWS')? DVB_Duplicate() : ''

"< End of mappings

"> Autocommands
if has("autocmd")
augroup Tumbler
   au!
   "Make sure to wipe out previous declarations so we can reload safely

   " Initialization (can't be called until functions are loaded)
   autocmd VimEnter    * call LoadSession()
                         " If a session was previously saved, load it

   " Buffer specific stuff
   autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
   " When editing a file, always jump to the last cursor position.

   autocmd BufReadPost * if (&filetype != 'qf') | call matchadd('ColorColumn', '\%81v.') | endif
   " Highlight the 81st character on the line if it's not the quickfix.

   autocmd BufReadPre  * nmap<buffer>  <A-c>   I//<Esc>$<A-j>
   autocmd BufReadPre  * imap<buffer>  <A-c>   <Esc>I//<Esc>$<A-j>
   autocmd BufReadPre  * nmap<buffer>  <A-x>   ^2x$<A-j>
   autocmd BufReadPre  * imap<buffer>  <A-x>   <Esc>^2x$<A-j>
                         " Generalized quick comments (C-style)

   autocmd BufReadPost * if &modifiable == 1 | set fileformat=unix | endif
                         " set line endings, because Windows is wrong...
                         " (has to be done for each buffer, but only if
                         "   the file is modifiable)
   " Filetype dependent stuff
   " Perl
   autocmd FileType perl     nmap<buffer>  <A-c>   I#<Esc>$<A-j>
   autocmd FileType perl     imap<buffer>  <A-c>   <Esc>I#<Esc>$<A-j>
   autocmd FileType perl     nmap<buffer>  <A-x>   ^x$<A-j>
   autocmd FileType perl     imap<buffer>  <A-x>   <Esc>^x$<A-j>
                             " Perl style quick comments
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
                             " Batch stype quick comments (May God have mercy on your soul)

   " And of course we can't forget Vim files! :D
   autocmd FileType vim      nmap<buffer>  <A-c>   I"<Esc>$<A-j>
   autocmd FileType vim      imap<buffer>  <A-c>   <Esc>I"<Esc>$<A-j>
   autocmd FileType vim      nmap<buffer>  <A-x>   ^x$<A-j>
   autocmd FileType vim      imap<buffer>  <A-x>   <Esc>^x$<A-j>
                             " Vim style quick comments

   autocmd CmdwinEnter * if getcmdwintype() == '@' | setlocal spell | startinsert! | endif
   " If using command window from an input turn on spell check (Only available in Vim 7.4.338 and above)
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
"< End of Initializations

"> Functions
" Bang after function means if the vimrc is reloaded they will get overwritten
"  ToggleAutoScroll <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
function! ToggleAutoScroll()
   if &scrolloff =~# '9999'
      set scrolloff=0
   else
      set scrolloff=9999
   endif
endfunction

"  BlockCheck <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
function! BlockCheck(insertMode)
   if !exists('b:checkingBlock')
      let b:checkingBlock = 0
      let b:insertCheckOn = 0
   endif

   if (b:checkingBlock == 0)
      normal ms][md%mfzz
      let b:checkingBlock = 1
      let b:insertCheckOn = a:insertMode
   else
      if ((line('.') >= line("'f")-1) && (line('.') <= line("'d'")))
         normal `s
         if (b:insertCheckOn == 1)
            normal l
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

"  SaveBuffer <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Saves buffer and updates last edited value if applicable.
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
         exec feedkeys(":q\<CR>")
      endif
   else
      write
      if (a:source == 1 || a:source == 3)
         exec feedkeys(":q\<CR>")
      endif
   endif
endfunction

"  OpenVimrc ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
function! OpenVimrc()
   " open in new tab unless current one is empty
   if line('$') == 1 && getline(1) == ''
      exec 'e $MYVIMRC'
   else
      exec 'tabnew'
      exec 'e $MYVIMRC'
   endif
endfunction

"  RemoveTrailingWhitespace <><><><><><><><><><><><><><><><><><><><><><><><><><>
function! RemoveTrailingWhitespace()
   let initialWindowView = winsaveview()
   %s/\s\+$//e
   call winrestview(initialWindowView)
endfunction

"  ToggleReadOnlyBit ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
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

"  ShiftScreen ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
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

"  EchoError ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
function! EchoError(message)
   echo "\n"
   echohl ERROR
   echo a:message
   echohl NORMAL
endfunction

"  ToggleBinaryMode ><><><><><><><><><><><><><><><><><><><><><><><><><><><>
" :h xxd and :h binary for more information
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

"  ExecuteRecognizedFile ><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: If extension matches a list stored in g:recognizedFiles, then run it
"          in a shell in the background.
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


"  InputHistory <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Cycle trough command line history when in an input() command.
function! InputHistory(direction) abort
    if (a:direction == 2)
       let g:input_hist_index = 0
       return "\<CR>"
    else
       let g:input_hist_index = g:input_hist_index + (a:direction ? 1 : -1)
       return "\<C-U>" . histget('@', g:input_hist_index)
    endif
endfunction

"  Javadoc ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Generate javadoc template.
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
      call add(type,  Chomp(lineToProcess, '\s*\zs\w\+\>'))
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

"  Chomp ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: returns pattern match and discards string up to match
"    input - stringAsList [[String]] A length one list that contains a String
"               to macth against
"            pattern [string] A regex string to match
"    returns
function! Chomp(stringAsList, pattern)
   let retVal = matchstr(a:stringAsList[0], a:pattern)
   call add(a:stringAsList, matchstr(a:stringAsList[0], retVal.'\zs.*'))
   call remove(a:stringAsList, 0)
   return retVal
endfunction

"  BlockAutoIndent ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Automatically tries to indent current block and moves cursor relative
"          to indent.
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

"  NextQuickFix <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Moves in quickfix. If there are no errors, then try the location
"          list instead.
function! NextQuickFix(...)
   try
      if (a:0 > 0)
         cp
      else
         cn
      endif
   catch /^Vim\%((\a\+)\)\=:E42/
      " Catch no error file errors and redirect to location list
      if (a:0 > 0)
         lp
      else
         lne
      endif
   catch /^Vim\%((\a\+)\)\=:E553/
   endtry
endfunction

"  CycleTrhoughSpellSuggestion ><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Try the next suggestion. If called again incraments and goes to next
"          item.
function! CycleTrhoughSpellSuggestion()
   if (g:spellSuggestionCount != 1)
      undo
   endif
   exe "normal! " . g:spellSuggestionCount . "z="
   let g:spellSuggestionCount += 1
endfunction

"  BringUpSpellSuggestionList <><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Handles some secondary functions to execute when bringing up the list.
function! BringUpSpellSuggestionList()
   if (g:spellSuggestionCount != 1)
      undo
   endif
   let g:spellSuggestionCount = 1
   " z= doesn't work from inside function, had to extricate...
endfunction

"  LoadSession
"   brief: If a previous vim session was saved, load it and delete it.
function! LoadSession()
   if filereadable($HOME.'/vimfiles/Session.vim')
      source $HOME/vimfiles/Session.vim
      call delete($HOME.'/vimfiles/Session.vim')
   endif
endfunction

"  ReplaceBadWhitespaceInDir ><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Replaces tabs and trailing whitespace in all files in a directory.
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

"  OpenNewTabWithNetrw ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Opens a new tab with netrw, pointing at previous file. Also enables
"          cvs hilighting if that plugin is enabled.
function! OpenNewTabWithNetrw()
   let l:tmp = expand('%')
   Te
   exe "normal /".l:tmp."\r"
   if exists('g:cvsnetrwIntegration')
      call UpdateCVSHilighting()
   endif
endfunction
"<

"> Tips and Tricks <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

" normal mode tips

" gf              - Goes to file under cursor (think #include)
" gi              - Goes to last insert location (good for searching for
"                    something and then returning to edit mode)
" ga              - Inspect character under cursor
" gd              - Go to definition of word under cursor within the current
"                    function
" gD              - Go to definition of word under cursor within the current
"                    file
" g?              - Rot13
" ~               - Swaps case of letter
" ={direction}    - Auto indents stuff (think =%)
" =iB             - Auto indents current inner Block {}
" dp              - update other file in a diff
" V               - Visual select of whole line
" zR              - Opens all folds in diffs
" zM              - Closes all folds in diffs
" <C-]>           - Goes to link in :help
" ]s              - Search for next spelling mistake
" J               - Joins lines (instead of lots of deletes!)
" gu/U{direction} - Make {direction} text lowercase/uppercase.
" "3p             - Paste from 3 edits ago (works with 1 to 9)
" {Insert}<C-y>   - Copies text one line above.

" Alt combos that haven't been mapped yet:
"  <A-a>
"  <A-/>

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
" list[:5]     Only return up to the 3th item in the list

":set diffopt+=iwhite   - Ignores differing whitespace when diffing
                                           " Insert  Command-line   Lang-Arg ~
" :map   :noremap   :unmap   :mapclear        yes         yes           yes
" :map!  :noremap!  :unmap!  :mapclear!       yes         yes            -
" :nmap  :nnoremap  :nunmap  :nmapclear       yes          -             -
" :imap  :inoremap  :iunmap  :imapclear       yes          -             -
" :cmap  :cnoremap  :cunmap  :cmapclear        -          yes            -
" :lmap  :lnoremap  :lunmap  :lmapclear       yes*       yes*hh         yes*

" :[cl]older         - Remembers previous quickfix/location list
" :[cl]newer         - Remembers more recent quickfix/location list
" :g!                - Negative global command, AKA do it on every line that's
"                      DOESN'T match

" :nore before a mapping command is for non-recursive mappings

" Here's a line to run a command prompt (Windows) completely in the background:
"  silent !start /b cmd /c {your cmd command here}

" Looking for an environment variable? Try tab-completing ":echo $"

" :retab is super useful!

" See :h highlight-groups for all highlighting groups
" See :h autocmd-events-abc for a list of all events

" Do a double substitution with one regex:
" :s/foo\|bar/\={'foo':'bar','bar':'foo'}[submatch(0)]/g

" How to restict searches to syntax regions:
" http://vi.stackexchange.com/questions/8127/is-there-a-way-to-restrict-search-results-to-differences-in-a-diff

" Try `:set rightleft` for some random fun

" To disable autocmds for a single command use `:noautocmd {cmd}`

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
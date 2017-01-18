" @Tracked
" Directory Differ Plugin
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 01/17/2017 05:55 PM
" Version: 1.4

"TODO: Add Directory checking, (It's a lot, but it's worth it)

" DirDiff
"  brief: Diffs two directories and allows you to quickly jump between different
"          files in the dirs.
"     input - a:1 [bool] When present opens diff with first dir on left.
"                          Opens on right otherwise. {optional}
"     returns - void
function! DirDiff(...)
   if (&filetype == 'netrw')
      " Only works when starting from netrw
      if (expand('%') != '')
         cd %
      endif
      let firstDirTemp = ExpandDir(getcwd(), 1)
      let secondDirTemp = input("First Directory: " . firstDirTemp . "\n" .
                                \ "What is the other directory you want to compare? ", 'C:/', "dir")
      " This is here so we can type wile still in the netrw tab.
      if (secondDirTemp != '')
         let secondDirTemp = ExpandDir(secondDirTemp, 1)
      endif
      if (a:0 > 0 && a:1 == 1)
         " Defaultly opens first Dir on the right, but can be changed if 1 is
         "  passed in as an argument.
         let firstDir = firstDirTemp
         let secondDir = secondDirTemp
      else
         let firstDir = secondDirTemp
         let secondDir = firstDirTemp
      endif
      if isdirectory(firstDir) && isdirectory(secondDir)
         if exists('g:vimProjectManager')
            let list = ReturnProject(firstDir)
            let firstProject = list[0]
            let firstRoot = list[1]
            let list = ReturnProject(secondDir)
            let secondProject = list[0]
            let secondRoot = list[1]
            if (firstProject.name != '' && (firstProject.name == secondProject.name))
               " If the projects are the same then diff the whole project
               " (Only works for relative projects)
               for dir in firstProject.dirs
                  exe "cd ".firstRoot
                  let firstDirtoDiff = fnamemodify(dir, ':p')
                  exe "cd ".secondRoot
                  let secondDirtoDiff = fnamemodify(dir, ':p')
                  call SetupDirDiffTab(firstDirtoDiff, secondDirtoDiff)
                  if (firstDir == firstDirtoDiff)
                     let tabToStartWithFocus = tabpagenr()
                  endif
               endfor
               if (exists('tabToStartWithFocus'))
                  exe "tabnext ".tabToStartWithFocus
               endif
            else
               call SetupDirDiffTab(firstDir, secondDir)
            endif
         else
            call SetupDirDiffTab(firstDir, secondDir)
         endif
      endif
   endif
endfunction

function! SetupDirDiffTab(firstDir, secondDir)
   tabnew
   call SetTabName('Dir Diff')
   let t:DIFFDIR = 1
   let t:firstDir = substitute(a:firstDir, '/\=$', '/', '')
   let t:secondDir = substitute(a:secondDir, '/\=$', '/', '')
   let t:firstIndex = 0
   let t:secondIndex = 0
   let t:firstHeader = ['########################################', '## ' . t:firstDir, '########################################']
   let t:secondHeader = ['########################################', '## ' . t:secondDir, '########################################']
   let firstDirFilesString = globpath(t:firstDir, '*', 1)
   let t:firstDirFiles = split(firstDirFilesString, "\n")
   let t:firstDirDirs = []
   let secondDirFilesString = globpath(t:secondDir, '*', 1)
   let t:secondDirFiles = split(secondDirFilesString, "\n")
   let t:secondDirDirs = []
   let loopCount = 0
   for entry in t:firstDirFiles
      if isdirectory(entry)
         " Take out all directories
         call add(t:firstDirDirs, entry)
         call remove(t:firstDirFiles, loopCount)
      else
         let t:firstDirFiles[loopCount] = substitute(entry, '.*\(\\\|\/\)', '', '')
         let loopCount += 1
      endif
   endfor
   let loopCount = 0
   for entry in t:secondDirFiles
      if isdirectory(entry)
         " Take out all directories
         call add(t:secondDirDirs, entry)
         call remove(t:secondDirFiles, loopCount)
      else
         let t:secondDirFiles[loopCount] = substitute(entry, '.*\(\\\|\/\)', '', '')
         let loopCount += 1
      endif
   endfor
   call sort(t:firstDirFiles, 1)
   call sort(t:firstDirDirs, 1)
   call sort(t:secondDirFiles, 1)
   call sort(t:secondDirDirs, 1)
   let t:Common = []
   let t:CommonSame = []
   let t:CommonDiff = []
   let t:firstUnique = copy(t:firstDirFiles)
   let t:secondUnique = copy(t:secondDirFiles)
   let firstUniquePosition = 0
   let secondUniquePosition = 0
   for one in t:firstDirFiles
      let loopCounter = 0
      for two in t:secondDirFiles
         if (one == two)
            let firstFile = readfile(t:firstDir . one, 'b')
            let secondFile = readfile(t:secondDir . two, 'b')
            if (firstFile == secondFile)
               call add(t:CommonSame, one)
            else
               call add(t:CommonDiff, one)
            endif
            call add(t:Common, one)
            call remove(t:firstUnique, firstUniquePosition)
            call remove(t:secondUnique, loopCounter - secondUniquePosition)
            let firstUniquePosition -= 1
            let secondUniquePosition += 1
            break
            " Unique starts with all itmes. Whenever we find one that
            "   matches we add it to the common list and remove it
            "   from the unique lists.
         endif
         let loopCounter += 1
      endfor
      let firstUniquePosition += 1
   endfor

   let t:firstSorted = t:Common + t:firstUnique
   let t:secondSorted = t:Common + t:secondUnique

   let t:DiffDirFiles = []
   " A list of temp files where we will store the "directory structure"
   "  to be examined
   call add(t:DiffDirFiles, tempname())
   call writefile(t:firstHeader + t:firstSorted, t:DiffDirFiles[0])
   exe 'e ' . t:DiffDirFiles[0]
   let w:browseBuff = bufnr('%')
   set nomodifiable
   call HighlightDir(t:CommonSame, t:CommonDiff, t:firstUnique)
   noremap <buffer> j :let t:firstIndex = (t:firstIndex + 1) % len(t:firstSorted)<CR>:let t:secondIndex = t:firstIndex<CR>:exe "let @/ = '" . EscapeRegex(t:firstSorted[t:firstIndex]) . "'"<CR>n
   map     <Down>   j
   noremap <buffer> k :let t:firstIndex = (t:firstIndex + len(t:firstSorted) - 1) % len(t:firstSorted)<CR>:let t:secondIndex = t:firstIndex<CR>:exe "let @/ = '" . EscapeRegex(t:firstSorted[t:firstIndex]) . "'"<CR>N
   map     <Up>     k
   noremap <buffer> i :call SortDiffDir()<CR>
   noremap <buffer> <CR> :call DiffCurrentFile(t:firstDir . t:firstSorted[t:firstIndex], t:secondDir . t:secondSorted[t:secondIndex])<CR>
   noremap <buffer> - <NOP>
   let b:dirBinds = 1
   exe 'set title titlestring=' . t:firstDir
   set scrollbind
   call add(t:DiffDirFiles, tempname())
   call writefile(t:secondHeader + t:secondSorted, t:DiffDirFiles[1])
   exe 'vnew ' . t:DiffDirFiles[1]
   if (!&splitright)
      " Make sure split shows up on side expected
      wincmd L
   endif
   call SetTabName('Dir Diff')
   let w:browseBuff = bufnr('%')
   call HighlightDir(t:CommonSame, t:CommonDiff, t:secondUnique)
   exe "let @/ = '" . t:secondSorted[t:secondIndex] . "'"
   normal n
   noremap <buffer> j :let t:secondIndex = (t:secondIndex + 1) % len(t:secondSorted)<CR>:let t:firstIndex = t:secondIndex<CR>:exe "let @/ = '" . EscapeRegex(t:secondSorted[t:secondIndex]) . "'"<CR>n
   map     <Down>   j
   noremap <buffer> k :let t:secondIndex = (t:secondIndex + len(t:secondSorted) - 1) % len(t:secondSorted)<CR>:let t:firstIndex = t:secondIndex<CR>:exe "let @/ = '" . EscapeRegex(t:secondSorted[t:secondIndex]) . "'"<CR>N
   map     <Up>     k
   noremap <buffer> i :call SortDiffDir()<CR>
   noremap <buffer> <CR> :call DiffCurrentFile(t:firstDir . t:firstSorted[t:firstIndex], t:secondDir . t:secondSorted[t:secondIndex])<CR>
   noremap <buffer> - <NOP>
   let b:dirBinds = 1
   set scrollbind
   set scrolloff=9999
endfunction

"  SortDiffDir
"   brief: Sorts the files in the DiffDir in the following ways:
"        1: All Common files followed by all Unique files (default)
"        2: CommonDiff files, CommonSame files, Unique files
"        3: Alphabetically
"     input  - void
"     return - void
function! SortDiffDir()
   if exists('t:DIFFDIR')
      " Only works in a DiffDir tab
      let initialWin = winnr()
      if (!exists('t:sortOrder') || t:sortOrder == 0)
         let t:firstSorted = (t:CommonDiff + t:CommonSame + t:firstUnique)
         let t:secondSorted = (t:CommonDiff + t:CommonSame + t:secondUnique)
         if (len(t:DiffDirFiles) < 3)
            call add(t:DiffDirFiles, tempname())
            call add(t:DiffDirFiles, tempname())
            call writefile(t:firstHeader + t:firstSorted, t:DiffDirFiles[2])
            call writefile(t:secondHeader + t:secondSorted, t:DiffDirFiles[3])
         endif
         exe "normal! \<C-W>h"
         exe 'edit! ' . t:DiffDirFiles[2]
         let w:browseBuff = bufnr('%')
         call HighlightDir()
         if !(exists('b:dirBinds'))
            noremap <buffer> j :let t:firstIndex = (t:firstIndex + 1) % len(t:firstSorted)<CR>:let t:secondIndex = t:firstIndex<CR>:exe "let @/ = '" . EscapeRegex(t:firstSorted[t:firstIndex]) . "'"<CR>n
            map     <Down>   j
            noremap <buffer> k :let t:firstIndex = (t:firstIndex + len(t:firstSorted) - 1) % len(t:firstSorted)<CR>:let t:secondIndex = t:firstIndex<CR>:exe "let @/ = '" . EscapeRegex(t:firstSorted[t:firstIndex]) . "'"<CR>N
            map     <Up>     k
            noremap <buffer> i :call SortDiffDir()<CR>
            noremap <buffer> <CR> :call DiffCurrentFile(t:firstDir . t:firstSorted[t:firstIndex], t:secondDir . t:secondSorted[t:secondIndex])<CR>
            noremap <buffer> - <NOP>
            let b:dirBinds = 1
         endif
         exe "normal! \<C-W>w"
         exe 'edit! ' . t:DiffDirFiles[3]
         let w:browseBuff = bufnr('%')
         call HighlightDir()
         let t:sortOrder = 1
         if !(exists('b:dirBinds'))
            noremap <buffer> j :let t:secondIndex = (t:secondIndex + 1) % len(t:secondSorted)<CR>:let t:firstIndex = t:secondIndex<CR>:exe "let @/ = '" . EscapeRegex(t:secondSorted[t:secondIndex]) . "'"<CR>n
            map     <Down>   j
            noremap <buffer> k :let t:secondIndex = (t:secondIndex + len(t:secondSorted) - 1) % len(t:secondSorted)<CR>:let t:firstIndex = t:secondIndex<CR>:exe "let @/ = '" . EscapeRegex(t:secondSorted[t:secondIndex]) . "'"<CR>N
            map     <Up>     k
            noremap <buffer> i :call SortDiffDir()<CR>
            noremap <buffer> <CR> :call DiffCurrentFile(t:firstDir . t:firstSorted[t:firstIndex], t:secondDir . t:secondSorted[t:secondIndex])<CR>
            noremap <buffer> - <NOP>
            let b:dirBinds = 1
         endif
         if (initialWin == 1)
            exe "normal! \<C-W>h"
         endif
      elseif (t:sortOrder == 1)
         let t:firstSorted = t:firstDirFiles
         let t:secondSorted = t:secondDirFiles
         if (len(t:DiffDirFiles) < 5)
            call add(t:DiffDirFiles, tempname())
            call add(t:DiffDirFiles, tempname())
            call writefile(t:firstHeader + t:firstSorted, t:DiffDirFiles[4])
            call writefile(t:secondHeader + t:secondSorted, t:DiffDirFiles[5])
         endif
         exe "normal! \<C-W>h"
         exe 'edit! ' . t:DiffDirFiles[4]
         let w:browseBuff = bufnr('%')
         call HighlightDir()
         if !(exists('b:dirBinds'))
            noremap <buffer> j :let t:firstIndex = (t:firstIndex + 1) % len(t:firstSorted)<CR>:let t:secondIndex = t:firstIndex<CR>:exe "let @/ = '" . EscapeRegex(t:firstSorted[t:firstIndex]) . "'"<CR>n
            map     <Down>   j
            noremap <buffer> k :let t:firstIndex = (t:firstIndex + len(t:firstSorted) - 1) % len(t:firstSorted)<CR>:let t:secondIndex = t:firstIndex<CR>:exe "let @/ = '" . EscapeRegex(t:firstSorted[t:firstIndex]) . "'"<CR>N
            map     <Up>     k
            noremap <buffer> i :call SortDiffDir()<CR>
            noremap <buffer> <CR> :call DiffCurrentFile(t:firstDir . t:firstSorted[t:firstIndex], t:secondDir . t:secondSorted[t:secondIndex])<CR>
            noremap <buffer> - <NOP>
         endif
         exe "normal! \<C-W>w"
         exe 'edit! ' . t:DiffDirFiles[5]
         let w:browseBuff = bufnr('%')
         call HighlightDir()
         let t:sortOrder = 1
         if !(exists('b:dirBinds'))
            noremap <buffer> j :let t:secondIndex = (t:secondIndex + 1) % len(t:secondSorted)<CR>:let t:firstIndex = t:secondIndex<CR>:exe "let @/ = '" . EscapeRegex(t:secondSorted[t:secondIndex]) . "'"<CR>n
            map     <Down>   j
            noremap <buffer> k :let t:secondIndex = (t:secondIndex + len(t:secondSorted) - 1) % len(t:secondSorted)<CR>:let t:firstIndex = t:secondIndex<CR>:exe "let @/ = '" . EscapeRegex(t:secondSorted[t:secondIndex]) . "'"<CR>N
            map     <Up>     k
            noremap <buffer> i :call SortDiffDir()<CR>
            noremap <buffer> <CR> :call DiffCurrentFile(t:firstDir . t:firstSorted[t:firstIndex], t:secondDir . t:secondSorted[t:secondIndex])<CR>
            noremap <buffer> - <NOP>
            let b:dirBinds = 1
         endif
         if (initialWin == 1)
            exe "normal! \<C-W>h"
         endif
         let t:sortOrder = 2
      elseif (t:sortOrder == 2)
         let t:firstSorted = t:Common + t:firstUnique
         let t:secondSorted = t:Common + t:secondUnique
         exe "normal! \<C-W>h"
         exe 'edit! ' . t:DiffDirFiles[0]
         let w:browseBuff = bufnr('%')
         call HighlightDir()
         exe "normal! \<C-W>w"
         exe 'edit! ' . t:DiffDirFiles[1]
         let w:browseBuff = bufnr('%')
         call HighlightDir()
         if (initialWin == 1)
            exe "normal! \<C-W>h"
         endif
         let t:sortOrder = 0
      endif
   endif
endfunction!

" HighlightDir
"  brief: Hilights file names in buffer based on window variables
"    input   - void OR
"              [string[]] A list of files to highlight green  (Identical)
"              [string[]] A list of files to highlight blue   (Different)
"              [string[]] A list of files to highlight orange (Unique)
"    returns - void
function! HighlightDir(...)
   if exists('t:DIFFDIR')
      " Only works in a DiffDir tab
      if (a:0 > 0)
         let CommonSameList = a:1
         let w:containedCommonSameFiles = a:1
         let CommonDiffList = a:2
         let w:containedCommonDiffFiles = a:2
         let UniqueList = a:3
         let w:containedUniqueFiles = a:3
         let matchList = a:3
         let w:containedMatchFiles = a:3
      else
         let CommonSameList = w:containedCommonSameFiles
         let CommonDiffList = w:containedCommonDiffFiles
         let UniqueList = w:containedUniqueFiles
      end
      for entry in CommonSameList
         let entry = substitute(entry, '\.', '\\\.', '')
         exe "syn match CommonSame '" . entry . "$'"
      endfor
      for entry in CommonDiffList
         let entry = substitute(entry, '\.', '\\\.', '')
         exe "syn match CommonDiff '" . entry . "$'"
      endfor
      for entry in UniqueList
         let entry = substitute(entry, '\.', '\\\.', '')
         exe "syn match Unique '" . entry . "$'"
      endfor
      if (&background == "dark")
         hi CommonSame cterm=NONE ctermbg=bg ctermfg=120 gui=NONE guibg=bg guifg=palegreen
         hi CommonDiff cterm=NONE ctermbg=bg ctermfg=116 gui=NONE guibg=bg guifg=SkyBlue
         hi Unique     cterm=NONE ctermbg=bg ctermfg=173 gui=NONE guibg=bg guifg=peru
      else
         hi CommonSame cterm=NONE ctermbg=bg ctermfg=28  gui=NONE guibg=bg guifg=DarkGreen
         hi CommonDiff cterm=NONE ctermbg=bg ctermfg=30  gui=NONE guibg=bg guifg=Darkcyan
         hi Unique     cterm=NONE ctermbg=bg ctermfg=167 gui=NONE guibg=bg guifg=indianred
      endif
   endif
endfunction

" DiffCurrentFile
"  brief: Diffs the two files passed in
"    input   - [string] The first file in the diff
"              [string] The second file in the diff
"    returns - void
function! DiffCurrentFile(firstFile, secondFile)
   if (t:firstIndex < len(t:Common) && exists('t:DIFFDIR'))
      " Only works in a DiffDir tab
      normal gg
      set noscrollbind
      if (winnr() == 1)
         exe 'edit! ' a:firstFile
      else
         exe 'edit! ' a:secondFile
      endif
      set modifiable
      diffthis
      noremap <buffer> - :call BackoutOfDIff()<CR>
      if (winnr() == 1)
         exe "normal! \<C-W>l"
         normal gg
         set noscrollbind
         exe 'edit! ' a:secondFile
      else
         exe "normal! \<C-W>h"
         normal gg
         set noscrollbind
         exe 'edit! ' a:firstFile
      endif
      set modifiable
      diffthis
      noremap <buffer> - :call BackoutOfDIff()<CR>
      exe "normal! \<C-W>w"
      set visualbell
      normal gg]c[c
      set novisualbell
   endif
endfunction

" BackoutOfDIff
"  brief: returns to DirDiff screen when in a diff
"    input   - void
"    return  - void
function! BackoutOfDIff()
   if exists('t:DIFFDIR')
      " Only works in a DiffDir tab
      let l:mod = &mod
      exe "normal! \<C-W>w"
      let l:mod = &mod || l:mod
      exe "normal! \<C-W>w"

      if (l:mod)
         call EchoError('Please save file first!')
      else
         diffoff!
         exe 'b ' . w:browseBuff
         call HighlightDir()
         exe "normal! \<C-W>w"
         exe 'b ' . w:browseBuff
         call HighlightDir()
         " Have to get both on the dirDiff screen before we can scrollbind
         set scrollbind
         set nomodifiable
         exe "normal! \<C-W>w"
         set scrollbind
         set nomodifiable
         if (winnr() == 1)
            exe "let @/ = '" . t:firstSorted[t:firstIndex] . "'"
         else
            exe "let @/ = '" . t:secondSorted[t:secondIndex] . "'"
         endif
         normal n
      endif
   else
      " If we aren't in a DiffDir tab, then we probably were trying to Explore.
      noremap <buffer> - :call SmartExplore('file')<CR>
      call SmartExplore('file')
   endif
endfunction

"  SetTabName <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Sets current tab name and updates all tabs
function! SetTabName(...)
   if (a:0 > 0)
      let w:mytablabel = a:1
      set guitablabel=%{exists('w:mytablabel')?w:mytablabel\ :''}
   elseif (exists(w:mytablabel))
      set guitablabel=%{exists('w:mytablabel')?w:mytablabel\ :''}
   endif
endfunction

"  EscapeRegex ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Backslash escapes the characters for a "magic mode" regex. Returns
"          escaped string.
function! EscapeRegex(input)
   return escape(a:input, '\^$.*~[&')
endfunction
"<< End of dirDiff plugin <><><><><><><><><><><><><><><><><><><><><><><><><><><>
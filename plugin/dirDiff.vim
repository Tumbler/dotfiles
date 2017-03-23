" @Tracked
" Directory Differ Plugin
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 03/23/2017 04:57 PM
let s:Version = 2.00

"TODO: Add back support for a light color theme.

let g:loaded_dirDiff = s:Version


let s:DirMode = 0
" DirDiff <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
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
      let swappedFlag = 0
      if (a:0 > 0 && a:1 == 1)
         " Defaultly opens first Dir on the right, but can be changed if 1 is
         "  passed in as an argument.
         let firstDir = firstDirTemp
         let secondDir = secondDirTemp
      else
         let firstDir = secondDirTemp
         let secondDir = firstDirTemp
         let swappedFlag = 1
      endif
      call <SID>SetUpLegend()

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
                  call <SID>SetupDirDiffTab(firstDirtoDiff, secondDirtoDiff, swappedFlag)
                  if (firstDir == firstDirtoDiff)
                     let tabToStartWithFocus = tabpagenr()
                  endif
               endfor
               if (exists('tabToStartWithFocus'))
                  exe "tabnext ".tabToStartWithFocus
               endif
            else
               call <SID>SetupDirDiffTab(firstDir, secondDir, swappedFlag)
            endif
         else
            call <SID>SetupDirDiffTab(firstDir, secondDir, swappedFlag)
         endif
      endif
   endif
endfunction

function! s:SetUpLegend()
   let g:dirDiff_LegendFile = tempname()
   let text =
    \  ['############################################################',
    \   '## Legend',
    \   '## l: return to dirDiff',
    \   '############################################################',
    \   'IdenticalDirectory/',
    \   'CommonDifferentDirectory/',
    \   'UniqueDirectory/',
    \   'IdenticalFile',
    \   'CommonDifferentFile',
    \   'UniqueFile']
   call writefile(text, g:dirDiff_LegendFile)
   exe 'tabnew ' . g:dirDiff_LegendFile
   let t:DIFFDIR = 1
   let g:dirDiff_LegendBuff = bufnr('%')
   nmap <silent><buffer> l :call <SID>BackoutOfSingle()<CR>
   nmap <silent><buffer> - :call <SID>BackoutOfSingle()<CR>
   call <SID>HighlightDir(['IdenticalDirectory/'], ['CommonDifferentDirectory/'], ['UniqueDirectory/'], ['IdenticalFile'], ['CommonDifferentFile'], ['UniqueFile'])
   set nomodifiable
   quit
endfunction

" SetupDirDiffTab <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
function! s:SetupDirDiffTab(firstDir, secondDir, switchFlag)
   tabnew
   call <SID>SetTabName('Dir Diff')
   let t:DIFFDIR = 1
   let firstDir = substitute(a:firstDir, '/\=$', '/', '')
   let secondDir = substitute(a:secondDir, '/\=$', '/', '')
   let t:dirDiffFirstDir = {}
   let t:dirDiffSecondDir = {}
   call <SID>InitializeDir(firstDir, t:dirDiffFirstDir)
   call <SID>InitializeDir(secondDir, t:dirDiffSecondDir)

   let t:dirDiffSortOrder = {}
   let t:dirDiffSortOrder.currentNode = t:dirDiffSortOrder
   let t:dirDiffSortOrder.index = [0, 0]
   call <SID>PopulateSortOrder(t:dirDiffSortOrder, t:dirDiffFirstDir, t:dirDiffSecondDir)

   call <SID>ViewDirDiff(t:dirDiffSortOrder, t:dirDiffFirstDir, t:dirDiffSecondDir)
   let t:DiffDirFiles = []

   let t:dirDiffFirstDir.currentNode = t:dirDiffFirstDir
   let t:dirDiffSecondDir.currentNode = t:dirDiffSecondDir
   if (a:switchFlag)
      wincmd w
   endif
endfunction

" InitializeDir <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Takes a reference to a dictionary and fills it with the directory
"          structure of the path
"     input  - path: [string] The path to the directory to initialize
"              directory: [{dictionary}] A blank dictionary to fill
"              optional: [bool] If present directory will be considered a
"                        non-root directory. (For internal use only)
"     return - void
function! s:InitializeDir(path, directory, ...)
   let a:directory.path = a:path
   if (a:0 < 1)
      let a:directory.root = 1
      let a:directory.name = fnamemodify(a:path, ':h:t')
   else
      let a:directory.root = 0
   endif
   let dirFilesString = globpath(a:path, '*', 1)
   let a:directory.files = split(dirFilesString, "\n")
   let a:directory.dirs = {}
   let loopCount = 0
   for entry in a:directory.files
      if isdirectory(entry)
         " Take out all directories
         let dirName = fnamemodify(entry, ':t')
         if (dirName != 'CVS')
            " Don't add CVS directories. They're superfluous we don't really
            " want to diff them.
            let a:directory.dirs[dirName.'/']  = {'name':dirName}
         endif
         call remove(a:directory.files, loopCount)
      else
         let a:directory.files[loopCount] = fnamemodify(entry, ':t')
         let loopCount += 1
      endif
   endfor
   let loopCount = 0
   call sort(a:directory.files, 1)
   " [0] = key (which is also the name)
   " [1] = dictionary (which is the dir)
   for eachDir in items(a:directory.dirs)
      let fullpath = substitute(a:path . eachDir[0], '/\=$', '/', '')
      call <SID>InitializeDir(fullpath, eachDir[1], 1)
   endfor
endfunction

" PopulateSortOrder <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
function! s:PopulateSortOrder(sort, dir1, dir2)
   if (has_key(a:sort, 'Sorted'))
      " Already populated and sorted, move along.
      return
   else
      let dir1 = a:dir1
      let dir2 = a:dir2
      if (<SID>TreeIsDetached(1))
         let dir1 = t:dirDiffSortOrder.backupNode[0]
      endif
      if (<SID>TreeIsDetached(2))
         let dir2 = t:dirDiffSortOrder.backupNode[1]
      endif

      call <SID>CompareDirectories(a:sort, dir1, dir2, 1)
   endif
endfunction

function! s:PopulateSingle(dir)
   if (has_key(a:dir, 'Sorted'))
      " Already populated and sorted, move along.
      return
   else
      let a:dir.Sorted = (keys(a:dir.dirs) + a:dir.files)
      let a:dir.header =
       \ ['############################################################',
       \  '## ' . a:dir.path,
       \  '## l: legend, -: parent dir, R: resync',
       \  '############################################################']
      let a:dir.index = 0
   endif
endfunction

function! s:ViewDirDiff(sortOrder, dir1, dir2)
   let savedWindow = winnr()
   if (!has_key(a:sortOrder, "DiffDirFiles"))
      " Files don't exsist, need to create them.
      let a:sortOrder.DiffDirFiles = []
      " A list of temp files where we will store the "directory structure"
      "  to be examined
      if (winnr('$') < 2)
         vsplit
      endif
      call <SID>SortDiffDir(a:sortOrder, a:dir1, a:dir2)
   else
      " Files already exist, just need to view them.
      if !(<SID>TreeIsDetached(1))
         wincmd h
         exe 'silent e ' . a:sortOrder.DiffDirFiles[a:sortOrder.sortIndex*4 + 1*s:DirMode]
         call <SID>HighlightDir()
         let w:diffDir_buffNumber = a:sortOrder.browseBuff[0][a:sortOrder.sortIndex*2 + 1*s:DirMode]
      endif
      if !(<SID>TreeIsDetached(2))
         if (winnr('$') < 2)
            exe 'vnew ' . a:sortOrder.DiffDirFiles[a:sortOrder.sortIndex*4+2 + 1*s:DirMode]
            if (!&splitright)
               " Make sure split shows up on side expected
               wincmd L
            endif
         else
            wincmd l
            exe 'silent e ' . a:sortOrder.DiffDirFiles[a:sortOrder.sortIndex*4+2 + 1*s:DirMode]
         endif
         call <SID>HighlightDir()
         let w:diffDir_buffNumber = a:sortOrder.browseBuff[1][a:sortOrder.sortIndex*2 + 1*s:DirMode]
      endif
   endif
   " This just sets the cursor where it should be
   exe savedWindow . "wincmd w"
   call <SID>NextItem(winnr(), 0)
endfunction

function! s:ViewSingle(dir, window)
   if (!has_key(a:dir, "DiffDirFile"))
      " Files don't exsist, need to create them.
      let a:dir.DiffDirFile = tempname()
      if (len(a:dir.Sorted) <= 0)
         call add(a:dir.Sorted, "** Empty **")
      endif
      call writefile(a:dir.header + a:dir.Sorted, a:dir.DiffDirFile)
      exe 'silent e ' . a:dir.DiffDirFile
      let a:dir.browseBuff = bufnr('%')
      let w:diffDir_buffNumber = bufnr('%')
      set nomodifiable
      set cursorline
      call <SID>HighlightDir([], [], keys(a:dir.dirs), [], [], a:dir.files)
      call <SID>SetUpSingleMappings(a:window)
   else
      " Files already exist, just need to view them.
      exe 'silent e ' . a:dir.DiffDirFile
      call <SID>HighlightDir()
      let w:difDir_buffNumber = a:dir.browseBuff
   endif
   " This just sets the cursor where it should be
   call <SID>NextSingleItem(a:dir, 0)
endfunction

function! s:ReattachNode(sortOrder, window)
   if (<SID>TreeIsDetached(a:window))
      " Make sure that the tree is, in fact, detached before reattaching it.
      let switchedFlag = 0
      if (a:window != winnr())
         wincmd w
         let switchedFlag = 1
      endif
      if (a:window == 1)
         " I would have used a:dir or GetCurrentNode here but for some
         " reason it didn't work. (Still not sure why)
         let t:dirDiffFirstDir.currentNode = t:dirDiffSortOrder.backupNode[a:window-1]
      else
         let t:dirDiffSecondDir.currentNode = t:dirDiffSortOrder.backupNode[a:window-1]
      endif
      let fullySyncedFlag = <SID>DeleteBackupNode(a:window)
      exe 'silent b ' . a:sortOrder.browseBuff[a:window-1][a:sortOrder.sortIndex*2 + 1*s:DirMode]
      call <SID>HighlightDir()
      let w:diffDir_buffNumber = a:sortOrder.browseBuff[a:window-1][a:sortOrder.sortIndex*2 + 1*s:DirMode]
      if (switchedFlag)
         wincmd w
      endif
      if (fullySyncedFlag)
         echo ""
      endif
      call <SID>NextItem(a:window, 0)
   endif
endfunction

let s:uniqueID = 0
function! s:SetUpMappings(sortOrder, window, ...)
   if (!exists('b:dirBinds') || a:0)
      if (a:0 == 0)
         exe "noremap <silent><buffer> j :call <SID>NextItem(". a:window . ", 1)<CR>"
         nmap <silent><buffer> <Down> j
         exe "noremap <silent><buffer> k :call <SID>NextItem(" . a:window . ", -1)<CR>"
         nmap <silent><buffer> <Up>   k
         noremap <silent><buffer> i :call <SID>IncSortOrder(<SID>GetCurrentNode(0), <SID>GetCurrentNode(1), <SID>GetCurrentNode(2))<CR>
         nmap <silent><buffer> s i
         exe "noremap <silent><buffer> <CR> :call <SID>DirDiffSelect(<SID>GetCurrentNode(0), ".a:window.", <SID>GetCurrentNode(1), <SID>GetCurrentNode(2))<CR>"
         nnoremap <silent><buffer> - :call <SID>ParentDir()<CR>
         nnoremap <silent><buffer> l :exe 'silent b ' . g:dirDiff_LegendBuff <BAR> call <SID>HighlightDir()<CR>
         exe "nnoremap <silent><buffer> R :call <SID>ReattachNode(<SID>GetCurrentNode(0), 1) <Bar> call <SID>ReattachNode(<SID>GetCurrentNode(0), 2)<CR>"
         nnoremap <silent><buffer> d :call <SID>ToggleDirMode(<SID>GetCurrentNode(0), <SID>GetCurrentNode(1), <SID>GetCurrentNode(2))<CR>
         nnoremap <silent><buffer> h <NOP>
         exe "nnoremap <silent><buffer> <LeftMouse> :call <SID>LeftMouse(".a:window.")<CR>"
         let b:dirBinds = 1
      else
         " Maps delayed until later.
         exe "augroup DELAYEDMAPPING".s:uniqueID
            exe "autocmd BufEnter <buffer=".a:1."> noremap <silent><buffer> j :call <SID>NextItem(". a:window . ", 1)<CR>"
            exe "autocmd BufEnter <buffer=".a:1."> nmap <silent><buffer> <Down> j"
            exe "autocmd BufEnter <buffer=".a:1."> noremap <silent><buffer> k :call <SID>NextItem(" . a:window . ", -1)<CR>"
            exe "autocmd BufEnter <buffer=".a:1."> nmap <silent><buffer> <Up> k"
            exe "autocmd BufEnter <buffer=".a:1."> nnoremap <silent><buffer> i :call <SID>IncSortOrder(<SID>GetCurrentNode(0), <SID>GetCurrentNode(1), <SID>GetCurrentNode(2))<CR>"
            exe "autocmd BufEnter <buffer=".a:1."> nmap <silent><buffer> s i"
            exe "autocmd BufEnter <buffer=".a:1."> noremap <silent><buffer> <CR> :call <SID>DirDiffSelect(<SID>GetCurrentNode(0), ".a:window.", <SID>GetCurrentNode(1), <SID>GetCurrentNode(2))<CR>"
            exe "autocmd BufEnter <buffer=".a:1."> nnoremap <silent><buffer> - :call <SID>ParentDir()<CR>"
            exe "autocmd BufEnter <buffer=".a:1."> nnoremap <silent><buffer> l :exe 'silent b ' . g:dirDiff_LegendBuff <BAR> call <SID>HighlightDir()<CR>"
            exe "autocmd BufEnter <buffer=".a:1."> let b:dirBinds = 1"
            exe "autocmd BufEnter <buffer=".a:1."> nnoremap <silent><buffer> h <NOP>"
            exe "autocmd BufEnter <buffer=".a:1."> nnoremap <silent><buffer> d :call <SID>ToggleDirMode(<SID>GetCurrentNode(0), <SID>GetCurrentNode(1), <SID>GetCurrentNode(2))<CR>"
            exe "autocmd BufEnter <buffer=".a:1."> nnoremap <silent><buffer> R :call <SID>ReattachNode(<SID>GetCurrentNode(0), 1) <Bar> call <SID>ReattachNode(<SID>GetCurrentNode(0), 2)<CR>"
            exe "autocmd BufEnter <buffer=".a:1."> augroup DELAYEDMAPPING".s:uniqueID." | au! | augroup END"
         augroup END
         let s:uniqueID += 1
      endif
   endif
endfunction

function! s:SetUpSingleMappings(window)
   let dir = <SID>GetCurrentNode(a:window)
   if !(exists('b:dirBinds'))
      exe "nnoremap <silent><buffer> j :call <SID>NextSingleItem(<SID>GetCurrentNode(".a:window."), 1)<CR>"
      nmap <silent><buffer> <Down> j
      exe "nnoremap <silent><buffer> k :call <SID>NextSingleItem(<SID>GetCurrentNode(".a:window."), -1)<CR>"
      nmap <silent><buffer> <Up>   k
      nnoremap <silent><buffer> s <NOP>
      nmap <silent><buffer> i s
      exe "noremap <silent><buffer> <CR> :call <SID>SelectSingle(<SID>GetCurrentNode(".a:window.").path, <SID>GetCurrentNode(".a:window.").Sorted[<SID>GetCurrentNode(".a:window.").index], ".a:window.")<CR>"
      exe "nnoremap <silent><buffer> - :call <SID>SingleParentDir(<SID>GetCurrentNode(".a:window."), ".a:window.")<CR>"
      nnoremap <silent><buffer> l :exe 'silent b ' . g:dirDiff_LegendBuff <BAR> call <SID>HighlightDir()<CR>
      nnoremap <silent><buffer> h <NOP>
      exe "nnoremap <silent><buffer> R :call <SID>ReattachNode(<SID>GetCurrentNode(0), 1) <Bar> call <SID>ReattachNode(<SID>GetCurrentNode(0), 2)<CR>"
      let b:dirBinds = 1
   endif
endfunction

function! s:NextItem(window, direction)
   let window = a:window-1
   let arrayLength = len(<SID>GetCurrentNode(0).Sorted[window])
   let lineWithFirstIndex = 5
   if (arrayLength > 0)
      let t:dirDiffSortOrder.currentNode.index[window] = (<SID>GetCurrentNode(0).index[window] + a:direction) % arrayLength
      if (<SID>GetCurrentNode(0).index[window] < 0)
         let t:dirDiffSortOrder.currentNode.index[window] = arrayLength + <SID>GetCurrentNode(0).index[window]
      endif
      " Retrieve the matching index for the other window (As long as the tree isn't detached)
      if !(<SID>TreeIsDetached(a:window+1))
         let otherIndex = index(<SID>GetCurrentNode(0).Sorted[(window+1)%2], <SID>GetCurrentNode(0).Sorted[window][<SID>GetCurrentNode(0).index[window]])
         wincmd w
         if (otherIndex != -1)
            let t:dirDiffSortOrder.currentNode.index[(window+1)%2] = otherIndex
            call setpos('.', [0, <SID>GetCurrentNode(0).index[(window+1)%2]+lineWithFirstIndex, 0, 0])
            normal zz
            set cursorline
         else
            set nocursorline
         endif
         wincmd w
      endif
      call setpos('.', [0, <SID>GetCurrentNode(0).index[window]+lineWithFirstIndex, 0, 0])
      normal zz
      set cursorline
   endif
endfunction

function! s:NextSingleItem(dir, direction)
   let arrayLength = len(a:dir.Sorted)
   if (arrayLength > 0)
      let a:dir.index = (a:dir.index + a:direction) % arrayLength
      if (a:dir.index < 0)
         let a:dir.index = arrayLength + a:dir.index
      endif
   endif
   call setpos('.', [0, a:dir.index + 5, 0, 0])
   normal zz
endfunction

function! s:LeftMouse(window)
   " TODO: Partial mouse support. Has some bugs. need to debug later.
   let before = getcurpos()[1]
   exe "normal! \<LeftMouse>"
   let difference = getcurpos()[1] - before
   call <SID>NextItem(a:window, difference)
   call <SID>DirDiffSelect(<SID>GetCurrentNode(0), a:window, <SID>GetCurrentNode(1), <SID>GetCurrentNode(2))
endfunction

" DirDiffSelect <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   breif: If over a directory, browse into directory. If over a file, diff the
"   file
function! s:DirDiffSelect(sortOrder, window, dir1, dir2)
   let window = a:window-1
   let firstSelected  = a:sortOrder.Sorted[window][<SID>GetCurrentNode(0).index[window]]
   let secondSelected = a:sortOrder.Sorted[(window+1)%2][<SID>GetCurrentNode(0).index[(window+1)%2]]
   if (a:sortOrder.Sorted[window][<SID>GetCurrentNode(0).index[window]] =~ '/$')
      " Selected a directory
      if (index(a:sortOrder.Sorted[(window+1)%2], firstSelected) != -1)
         call <SID>Traverse(firstSelected)
         call <SID>PopulateSortOrder(<SID>GetCurrentNode(0), <SID>GetCurrentNode(1), <SID>GetCurrentNode(2))
         call <SID>ViewDirDiff(<SID>GetCurrentNode(0), <SID>GetCurrentNode(1), <SID>GetCurrentNode(2))
      else
         "Directory was unique
         if (!has_key(t:dirDiffSortOrder, 'backupNode'))
            let t:dirDiffSortOrder.backupNode = [{}, {}]
         endif
         let t:dirDiffSortOrder.backupNode[window] = <SID>GetCurrentNode(a:window)
         call <SID>SingleTraverse(firstSelected, a:window)
         call <SID>PopulateSingle(<SID>GetCurrentNode(a:window))
         call <SID>ViewSingle(<SID>GetCurrentNode(a:window), a:window)
         echohl ModeMsg
         echo "Trees are now desyncronized. Press \"R\" to re-sync"
         echohl Normal
      endif
   else
      " Selected a file
      if (index(a:sortOrder.Sorted[(window+1)%2], firstSelected) == -1 || <SID>TreeIsDetached(a:window+1))
         " File was unique
         if (a:window == 1)
            call <SID>SingleFileEnter(a:dir1.path . firstSelected)
         else
            call <SID>SingleFileEnter(a:dir2.path . firstSelected)
         endif
      else
         " File exsisted on both; do a diff.
         call <SID>DiffCurrentFile(a:dir1.path . firstSelected, a:dir2.path . secondSelected)
      endif
   endif
endfunction

function! s:SelectSingle(path, file, window)
   if (a:file =~ '/$')
      " Selected a directory
      call <SID>SingleTraverse(a:file, a:window)
      call <SID>PopulateSingle(<SID>GetCurrentNode(a:window))
      call <SID>ViewSingle(<SID>GetCurrentNode(a:window), a:window)
   else
      " Selected a file
      call <SID>SingleFileEnter(a:path . a:file)
   endif
endfunction

function s:ToggleDirMode(sortOrder, dir1, dir2)
   if (s:DirMode)
      let s:DirMode = 0
   else
      let s:DirMode = 1
   endif
   call <SID>SortDiffDir(a:sortOrder, a:dir1, a:dir2)
endfunction

function s:SwapEm(sortOrder)
   let save = deepcopy(a:sortOrder.Sorted)
   let a:sortOrder.Sorted = deepcopy(s:sortDirs)
   let s:sortDirs = deepcopy(save)
endfunction

function s:IncSortOrder(sortOrder, dir1, dir2)
   let a:sortOrder.sortIndex = (a:sortOrder.sortIndex + 1) % 3
   call <SID>SortDiffDir(a:sortOrder, a:dir1, a:dir2)
endfunction

" SortDiffDir <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Sorts the files in the DiffDir in the following ways:
"        1: All Common files followed by all Unique files (default)
"        2: CommonDiff files, CommonSame files, Unique files
"        3: Alphabetically
"     input  - void
"     return - void
let s:sortDirs = [[], []]
function! s:SortDiffDir(sortOrder, dir1, dir2)
   if exists('t:DIFFDIR')
      " Only works in a DiffDir tab
      let initialWin = winnr()
      if (a:sortOrder.sortIndex == 0)
         let a:sortOrder.Sorted[0] = (a:sortOrder.CommonDir + a:sortOrder.firstUniqueDir + a:sortOrder.Common + a:sortOrder.firstUnique)
         let a:sortOrder.Sorted[1] = (a:sortOrder.CommonDir + a:sortOrder.secondUniqueDir + a:sortOrder.Common + a:sortOrder.secondUnique)
         let s:sortDirs[0] = (a:sortOrder.Common + a:sortOrder.firstUnique + a:sortOrder.CommonDir + a:sortOrder.firstUniqueDir)
         let s:sortDirs[1] = (a:sortOrder.Common + a:sortOrder.secondUnique + a:sortOrder.CommonDir + a:sortOrder.secondUniqueDir)
      elseif (a:sortOrder.sortIndex == 1)
         let a:sortOrder.Sorted[0] = (a:sortOrder.CommonDiffDir + a:sortOrder.CommonSameDir + a:sortOrder.firstUniqueDir + a:sortOrder.CommonDiff + a:sortOrder.CommonSame + a:sortOrder.firstUnique)
         let a:sortOrder.Sorted[1] = (a:sortOrder.CommonDiffDir + a:sortOrder.CommonSameDir + a:sortOrder.secondUniqueDir + a:sortOrder.CommonDiff + a:sortOrder.CommonSame + a:sortOrder.secondUnique)
         let s:sortDirs[0] = (a:sortOrder.CommonDiff + a:sortOrder.CommonSame + a:sortOrder.firstUnique + a:sortOrder.CommonDiffDir + a:sortOrder.CommonSameDir + a:sortOrder.firstUniqueDir)
         let s:sortDirs[1] = (a:sortOrder.CommonDiff + a:sortOrder.CommonSame + a:sortOrder.secondUnique + a:sortOrder.CommonDiffDir + a:sortOrder.CommonSameDir + a:sortOrder.secondUniqueDir)
      elseif (a:sortOrder.sortIndex == 2)
         let a:sortOrder.Sorted[0] = (sort(keys(a:dir1.dirs), 1) + a:dir1.files)
         let a:sortOrder.Sorted[1] = (sort(keys(a:dir2.dirs), 1) + a:dir2.files)
         let s:sortDirs[0] = (a:dir1.files + sort(keys(a:dir1.dirs), 1))
         let s:sortDirs[1] = (a:dir2.files + sort(keys(a:dir2.dirs), 1))
      endif
      if (len(a:sortOrder.DiffDirFiles) < ((a:sortOrder.sortIndex)*4+1))
         call add(a:sortOrder.DiffDirFiles, tempname())
         call add(a:sortOrder.DiffDirFiles, tempname())
         call add(a:sortOrder.DiffDirFiles, tempname())
         call add(a:sortOrder.DiffDirFiles, tempname())
         call writefile(a:sortOrder.firstHeader + a:sortOrder.Sorted[0],  a:sortOrder.DiffDirFiles[(a:sortOrder.sortIndex)*4])
         call writefile(a:sortOrder.firstHeader + s:sortDirs[0],          a:sortOrder.DiffDirFiles[(a:sortOrder.sortIndex)*4+1])
         call writefile(a:sortOrder.secondHeader + a:sortOrder.Sorted[1], a:sortOrder.DiffDirFiles[(a:sortOrder.sortIndex)*4+2])
         call writefile(a:sortOrder.secondHeader + s:sortDirs[1],         a:sortOrder.DiffDirFiles[(a:sortOrder.sortIndex)*4+3])
      endif
      if (s:DirMode)
         call <SID>SwapEm(a:sortOrder)
      endif
      wincmd h
      call <SID>SetUpBuffer(a:sortOrder, 1)
      set nomodifiable
      set cursorline
      wincmd l
      call <SID>SetUpBuffer(a:sortOrder, 2)
      set nomodifiable
      set cursorline

      if (initialWin == 1)
         exe "normal! \<C-W>h"
      endif
      call <SID>NextItem(initialWin, 0)
   endif
endfunction!

function s:SetUpBuffer(sortOrder, window)
   if !(<SID>TreeIsDetached(a:window))
      exe 'edit! ' . a:sortOrder.DiffDirFiles[a:sortOrder.sortIndex*4 + 2*(a:window-1) + s:DirMode]
      let a:sortOrder.browseBuff[a:window-1][a:sortOrder.sortIndex*2 + 1*s:DirMode] = bufnr('%')
      let w:diffDir_buffNumber = bufnr('%')
      if (exists('b:containedCommonSameDirs'))
         call <SID>HighlightDir()
      else
         if (a:window == 1)
            call <SID>HighlightDir(a:sortOrder.CommonSameDir, a:sortOrder.CommonDiffDir, a:sortOrder.firstUniqueDir, a:sortOrder.CommonSame, a:sortOrder.CommonDiff, a:sortOrder.firstUnique)
         else
            call <SID>HighlightDir(a:sortOrder.CommonSameDir, a:sortOrder.CommonDiffDir, a:sortOrder.secondUniqueDir, a:sortOrder.CommonSame, a:sortOrder.CommonDiff, a:sortOrder.secondUnique)
         endif
      endif
      call <SID>SetUpMappings(a:sortOrder, winnr())
   else
      let bufnr = bufnr(a:sortOrder.DiffDirFiles[a:sortOrder.sortIndex*4 + 2*(a:window-1) + s:DirMode])
      if (bufnr == -1)
         exe "badd ".a:sortOrder.DiffDirFiles[a:sortOrder.sortIndex*4 + 2*(a:window-1) + s:DirMode]
         let bufnr = bufnr(a:sortOrder.DiffDirFiles[a:sortOrder.sortIndex*4 + 2*(a:window-1) + s:DirMode])
      endif
      if (a:window == 1)
         call <SID>HighlightDir(a:sortOrder.CommonSameDir, a:sortOrder.CommonDiffDir, a:sortOrder.firstUniqueDir, a:sortOrder.CommonSame, a:sortOrder.CommonDiff, a:sortOrder.firstUnique, bufnr)
      else
         call <SID>HighlightDir(a:sortOrder.CommonSameDir, a:sortOrder.CommonDiffDir, a:sortOrder.secondUniqueDir, a:sortOrder.CommonSame, a:sortOrder.CommonDiff, a:sortOrder.secondUnique, bufnr)
      endif
      let a:sortOrder.browseBuff[a:window-1][a:sortOrder.sortIndex*2 + 1*s:DirMode] = bufnr
      call <SID>SetUpMappings(a:sortOrder, winnr(), bufnr)
      " Buffer is already setup and can't be loaded. Do nothing.
   endif
endfunction

" HighlightDir ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Highlights file names in buffer based on window variables
"    input   - void OR
"              [string[]] A list of files to highlight green  (Identical)
"              [string[]] A list of files to highlight blue   (Different)
"              [string[]] A list of files to highlight orange (Unique)
"    returns - void
function! s:HighlightDir(...)
   if exists('t:DIFFDIR')
      " Only works in a DiffDir tab
      let bufnum = bufnr('%')
      if (a:0 == 7)
         let bufnum = a:7
      endif
      if (a:0 > 0)
         let CommonSameDirList = a:1
         call setbufvar(bufnum, 'containedCommonSameDirs' , a:1)
         let CommonDiffDirList = a:2
         call setbufvar(bufnum, 'containedCommonDiffDirs' , a:2)
         let UniqueDirList = a:3
         call setbufvar(bufnum, 'containedUniqueDirs' , a:3)
         let CommonSameList = a:4
         call setbufvar(bufnum, 'containedCommonSameFiles' , a:4)
         let CommonDiffList = a:5
         call setbufvar(bufnum, 'containedCommonDiffFiles' , a:5)
         let UniqueList = a:6
         call setbufvar(bufnum, 'containedUniqueFiles' , a:6)
      else
         let CommonSameDirList = b:containedCommonSameDirs
         let CommonDiffDirList = b:containedCommonDiffDirs
         let UniqueDirList = b:containedUniqueDirs
         let CommonSameList = b:containedCommonSameFiles
         let CommonDiffList = b:containedCommonDiffFiles
         let UniqueList = b:containedUniqueFiles
      end
      for entry in CommonSameDirList
         let entry = substitute(entry, '\.', '\\\.', '')
         let entry = substitute(entry, '/$', '', '')
         exe "syn match CommonSameDir '" . entry . "\\(/$\\)\\@='"
      endfor
      for entry in CommonDiffDirList
         let entry = substitute(entry, '\.', '\\\.', '')
         let entry = substitute(entry, '/$', '', '')
         exe "syn match CommonDiffDir '" . entry . "\\(/$\\)\\@='"
      endfor
      for entry in UniqueDirList
         let entry = substitute(entry, '\.', '\\\.', '')
         let entry = substitute(entry, '/$', '', '')
         exe "syn match UniqueDir '" . entry . "\\(/$\\)\\@='"
      endfor
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
         hi CommonSameDir cterm=NONE ctermbg=bg ctermfg=120 gui=NONE guibg=bg guifg='#00BB33'
         hi CommonDiffDir cterm=NONE ctermbg=bg ctermfg=116 gui=NONE guibg=bg guifg=Purple
         hi UniqueDir     cterm=NONE ctermbg=bg ctermfg=173 gui=NONE guibg=bg guifg=indianred
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

" DiffCurrentFile <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Diffs the two files passed in
"    input   - [string] The first file in the diff
"              [string] The second file in the diff
"    returns - void
function! s:DiffCurrentFile(firstFile, secondFile)
   if (<SID>GetCurrentNode(0).index[winnr()-1] <
            \ len(<SID>GetCurrentNode(0).Common + <SID>GetCurrentNode(0).CommonDir) && exists('t:DIFFDIR') &&
            \ a:firstFile != '** Empty **' && a:secondFile != '** Empty **')
      " Only works in a DiffDir tab
      if (winnr() == 1)
         exe 'edit! ' a:firstFile
      else
         exe 'edit! ' a:secondFile
      endif
      set modifiable
      set nocursorline
      diffthis
      noremap <buffer> - :call <SID>BackoutOfDIff()<CR>
      if (winnr() == 1)
         exe "normal! \<C-W>l"
         exe 'edit! ' a:secondFile
      else
         exe "normal! \<C-W>h"
         exe 'edit! ' a:firstFile
      endif
      set modifiable
      set nocursorline
      diffthis
      noremap <buffer> - :call <SID>BackoutOfDIff()<CR>
      exe "normal! \<C-W>w"
      set visualbell
      normal gg]c[c
      set novisualbell
   endif
endfunction

" SingleFileEnter <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
function! s:SingleFileEnter(file)
   if (exists('t:DIFFDIR') && a:file !~ '\*\* Empty \*\*$')
      " Only works in a DiffDir tab
      exe 'edit! ' a:file
      set modifiable
      set nocursorline
      noremap <buffer> - :call <SID>BackoutOfSingle()<CR>
   endif
endfunction

" BackoutOfDIff <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: returns to DirDiff screen when in a diff
"    input   - void
"    return  - void
function! s:BackoutOfDIff()
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
         exe 'silent b ' . w:diffDir_buffNumber
         call <SID>HighlightDir()
         exe "normal! \<C-W>w"
         exe 'silent b ' . w:diffDir_buffNumber
         call <SID>HighlightDir()
         set nomodifiable
         set cursorline
         exe "normal! \<C-W>w"
         set nomodifiable
         set cursorline
         call <SID>NextItem(winnr(), 0)
      endif
   else
      " If we aren't in a DiffDir tab, then we probably were trying to Explore.
      noremap <buffer> - :call SmartExplore('file')<CR>
      call SmartExplore('file')
   endif
endfunction

function! s:BackoutOfSingle()
   if exists('t:DIFFDIR')
      " Only works in a DiffDir tab
      let l:mod = &mod
      exe "normal! \<C-W>w"
      let l:mod = &mod || l:mod
      exe "normal! \<C-W>w"

      if (l:mod)
         call EchoError('Please save file first!')
      else
         exe 'silent b ' . w:diffDir_buffNumber
         call <SID>HighlightDir()
         set nomodifiable
         set cursorline
         if (<SID>TreeIsDetached(winnr()))
            call <SID>NextSingleItem(<SID>GetCurrentNode(winnr()), 0)
         else
            call <SID>NextItem(winnr(), 0)
         endif
      endif
   else
      " If we aren't in a DiffDir tab, then we probably were trying to Explore.
      noremap <buffer> - :call SmartExplore('file')<CR>
      call SmartExplore('file')
   endif
endfunction

" Traverse ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
function! s:Traverse(dir)
   let parentNode = t:dirDiffSortOrder.currentNode
   if (!has_key(t:dirDiffSortOrder.currentNode, 'dirs'))
      let t:dirDiffSortOrder.currentNode.dirs = {}
   endif
   if (!has_key(t:dirDiffSortOrder.currentNode.dirs, a:dir))
      let t:dirDiffSortOrder.currentNode.dirs[a:dir] = {}
   endif
   let t:dirDiffSortOrder.currentNode = t:dirDiffSortOrder.currentNode.dirs[a:dir]
   let t:dirDiffSortOrder.currentNode.parentNode = parentNode

   if !(<SID>TreeIsDetached(1))
      let parentNode = t:dirDiffFirstDir.currentNode
      let t:dirDiffFirstDir.currentNode = t:dirDiffFirstDir.currentNode.dirs[a:dir]
      let t:dirDiffFirstDir.currentNode.parentNode = parentNode
   else
      " First tree is currently detached. Move the backupNode instead.
      let parentNode = t:dirDiffSortOrder.backupNode[0]
      let t:dirDiffSortOrder.backupNode[0] = t:dirDiffSortOrder.backupNode[0].dirs[a:dir]
      let t:dirDiffSortOrder.backupNode[0].parentNode = parentNode
   endif

   if !(<SID>TreeIsDetached(2))
      let parentNode = t:dirDiffSecondDir.currentNode
      let t:dirDiffSecondDir.currentNode = t:dirDiffSecondDir.currentNode.dirs[a:dir]
      let t:dirDiffSecondDir.currentNode.parentNode = parentNode
   else
      " Second tree is currently detached. Move the backupNode instead.
      let parentNode = t:dirDiffSortOrder.backupNode[1]
      let t:dirDiffSortOrder.backupNode[1] = t:dirDiffSortOrder.backupNode[1].dirs[a:dir]
      let t:dirDiffSortOrder.backupNode[1].parentNode = parentNode
   endif
endfunction

function! s:SingleTraverse(dir, window)
   if (a:window == 1)
      let parentNode = t:dirDiffFirstDir.currentNode
      let t:dirDiffFirstDir.currentNode = t:dirDiffFirstDir.currentNode.dirs[a:dir]
      let t:dirDiffFirstDir.currentNode.parentNode = parentNode
   else
      let parentNode = t:dirDiffSecondDir.currentNode
      let t:dirDiffSecondDir.currentNode = t:dirDiffSecondDir.currentNode.dirs[a:dir]
      let t:dirDiffSecondDir.currentNode.parentNode = parentNode
   endif
endfunction

function! s:ParentDir()
   if (t:dirDiffFirstDir.currentNode.root != 1)
      let t:dirDiffSortOrder.currentNode = t:dirDiffSortOrder.currentNode.parentNode
      if !(<SID>TreeIsDetached(1))
         let t:dirDiffFirstDir.currentNode = t:dirDiffFirstDir.currentNode.parentNode
      else
         let t:dirDiffSortOrder.backupNode[0] = t:dirDiffSortOrder.backupNode[0].parentNode
      endif
      if !(<SID>TreeIsDetached(2))
         let t:dirDiffSecondDir.currentNode = t:dirDiffSecondDir.currentNode.parentNode
      else
         let t:dirDiffSortOrder.backupNode[1] = t:dirDiffSortOrder.backupNode[1].parentNode
      endif
      call <SID>ViewDirDiff(t:dirDiffSortOrder.currentNode, t:dirDiffFirstDir.currentNode, t:dirDiffSecondDir.currentNode)
   else
      echohl ERROR
      echo "Already at root of comparison"
      echohl NORMAL
   endif
endfunction

function! s:SingleParentDir(dir, window)
   if (a:dir.root != 1)
      if (has_key(a:dir.parentNode, 'Sorted'))
         if (a:window == 1)
            let t:dirDiffFirstDir.currentNode = t:dirDiffFirstDir.currentNode.parentNode
         elseif (a:window == 2)
            let t:dirDiffSecondDir.currentNode = t:dirDiffSecondDir.currentNode.parentNode
         endif
         call <SID>ViewSingle(a:dir.parentNode, a:window)
      else
         " There is no Sorted array, we've met back up with the tree
         call <SID>ReattachNode(<SID>GetCurrentNode(0), a:window)
      endif
   else
      echohl ERROR
      echo "Already at root of comparison"
      echohl NORMAL
   endif
endfunction

" GetCurrentNode ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
function! s:GetCurrentNode(walker)
   if      (a:walker == 0)
      return t:dirDiffSortOrder.currentNode
   elseif (a:walker == 1)
      return t:dirDiffFirstDir.currentNode
   elseif (a:walker == 2)
      return t:dirDiffSecondDir.currentNode
   else
      return {}
   endif
endfunction

function! s:DeleteBackupNode(window)
   if (has_key(t:dirDiffSortOrder, 'backupNode'))
      let t:dirDiffSortOrder.backupNode[a:window-1] = {}
      if (empty(t:dirDiffSortOrder.backupNode[0]) && empty(t:dirDiffSortOrder.backupNode[1]))
         call remove(t:dirDiffSortOrder, 'backupNode')
         return 1
      endif
   endif
   return 0
endfunction

function! s:TreeIsDetached(tree)
   if (a:tree > 2)
      let tree = 1
   elseif a:tree < 1
      return 0
   else
      let tree = a:tree
   endif
   return (has_key(t:dirDiffSortOrder, 'backupNode') && !empty(t:dirDiffSortOrder.backupNode[tree-1]))
endfunction

" CompareDirectories ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
function! s:CompareDirectories(sortOrder, dir1, dir2, mustFinish)
   if (has_key(a:sortOrder, "Sorted"))
      " If there's anything different return true (bool so anything not zero).
      return (len(a:sortOrder.CommonDiff + a:sortOrder.firstUnique + a:sortOrder.secondUnique +
                \ a:sortOrder.CommonDiffDir + a:sortedOrder.firstUniqueDir + a:sortOrder.secondUniqueDir))
   else
      " No previous history, we'll have to check it on our own.
      let a:sortOrder.firstHeader =
       \ ['############################################################',
       \  '## ' . a:dir1.path,
       \  '## s/i: sort, l: legend, -: parent dir, d: swap dir position',
       \  '############################################################']
      let a:sortOrder.secondHeader =
       \ ['############################################################',
       \  '## ' . a:dir2.path,
       \  '## s/i: sort, l: legend, -: parent dir, d: swap dir position',
       \  '############################################################']
      let a:sortOrder.Common = []
      let a:sortOrder.CommonSame = []
      let a:sortOrder.CommonDiff = []
      let a:sortOrder.firstUnique = copy(a:dir1.files)
      let a:sortOrder.secondUnique = copy(a:dir2.files)
      let a:sortOrder.CommonDir = []
      let a:sortOrder.CommonSameDir = []
      let a:sortOrder.CommonDiffDir = []
      let a:sortOrder.firstUniqueDir = keys(a:dir1.dirs)
      let a:sortOrder.secondUniqueDir = keys(a:dir2.dirs)
      let a:sortOrder.index = [0, 0]
      let a:sortOrder.dirs = {}
      let a:sortOrder.browseBuff = [[0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0]]
      let a:sortOrder.sortIndex = 0

      " Compare files in path (We want to a breadth first so we can exit out as
      " soon as possible if they're not equivalent).
      let retVal = 1
      let firstUniquePosition = 0
      let secondUniquePosition = 0
      for one in a:dir1.files
         let loopCounter = 0
         let UniqueFlag = 1
         for two in a:dir2.files
            if (one == two)
               let UniqueFlag = 0
               let firstFile = readfile(a:dir1.path . one, 'b')
               let secondFile = readfile(a:dir2.path . two, 'b')
               if (firstFile == secondFile)
                  call add(a:sortOrder.CommonSame, one)
               else
                  if (!a:mustFinish)
                     return 0
                  else
                     let retVal = 0
                  endif
                  call add(a:sortOrder.CommonDiff, one)
               endif
               call add(a:sortOrder.Common, one)
               call remove(a:sortOrder.firstUnique, firstUniquePosition)
               call remove(a:sortOrder.secondUnique, loopCounter - secondUniquePosition)
               let firstUniquePosition -= 1
               let secondUniquePosition += 1
               break
               " Unique starts with all itmes. Whenever we find one that
               "   matches we add it to the common list and remove it
               "   from the unique lists.
            endif
            let loopCounter += 1
         endfor
         if (UniqueFlag)
            " There are unique files
            if (!a:mustFinish)
               return 0
            else
               let retVal = 0
            endif
         endif
         let firstUniquePosition += 1
      endfor
      if (len(a:sortOrder.firstUnique + a:sortOrder.secondUnique))
         " There are unique files (already searched for unique files in first)
         if (!a:mustFinish)
            return 0
         else
            let retVal = 0
         endif
      endif

      " Compare directories in path
      let firstUniquePosition = 0
      let secondUniquePosition = 0
      for one in keys(a:dir1.dirs)
         let loopCounter = 0
         if (!has_key(a:sortOrder.dirs, one))
            let a:sortOrder.dirs[one] = {}
         endif
         let UniqueFlag = 1
         for two in keys(a:dir2.dirs)
            if (one == two)
               let UniqueFlag = 0
               if <SID>CompareDirectories(a:sortOrder.dirs[one], a:dir1.dirs[one], a:dir2.dirs[two], 0)
                  call add(a:sortOrder.CommonSameDir, one)
               else
                  if (!a:mustFinish)
                     return 0
                  else
                     let retVal = 0
                  endif
                  call add(a:sortOrder.CommonDiffDir, one)
               endif
               call add(a:sortOrder.CommonDir, one)
               call remove(a:sortOrder.firstUniqueDir, firstUniquePosition)
               call remove(a:sortOrder.secondUniqueDir, loopCounter - secondUniquePosition)
               let firstUniquePosition -= 1
               let secondUniquePosition += 1
               break
               " Unique starts with all itmes. Whenever we find one that
               "   matches we add it to the common list and remove it
               "   from the unique lists.
            endif
            let loopCounter += 1
         endfor
         if (UniqueFlag)
            " There are unique dirs
            if (!a:mustFinish)
               return 0
            else
               let retVal = 0
            endif
         endif
         let firstUniquePosition += 1
      endfor
      if (len(a:sortOrder.secondUniqueDir))
         " There are unique dirs (already searched for unique dirs in first)
         if (!a:mustFinish)
            return 0
         else
            let retVal = 0
         endif
      endif

      let a:sortOrder.Sorted = [a:sortOrder.CommonDir + a:sortOrder.firstUniqueDir + a:sortOrder.Common + a:sortOrder.firstUnique,
                              \ a:sortOrder.CommonDir + a:sortOrder.secondUniqueDir + a:sortOrder.Common + a:sortOrder.secondUnique]
   endif
   return retVal
endfunction

" SetTabName ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Sets current tab name and updates all tabs
function! s:SetTabName(...)
   if (a:0 > 0)
      let w:mytablabel = a:1
      set guitablabel=%{exists('w:mytablabel')?w:mytablabel\ :''}
   elseif (exists(w:mytablabel))
      set guitablabel=%{exists('w:mytablabel')?w:mytablabel\ :''}
   endif
endfunction

" EscapeRegex <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Backslash escapes the characters for a "magic mode" regex. Returns
"          escaped string.
function! s:EscapeRegex(input)
   return escape(a:input, '\^$.*~[&')
endfunction

" The MIT License (MIT)
"
" Copyright © 2017 Warren Terrall
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to
" deal in the Software without restriction, including without limitation the
" rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
" sell copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" The software is provided "as is", without warranty of any kind, express or
" implied, including but not limited to the warranties of merchantability,
" fitness for a particular purpose and noninfringement. In no event shall the
" authors or copyright holders be liable for any claim, damages or other
" liability, whether in an action of contract, tort or otherwise, arising
" from, out of or in connection with the software or the use or other dealings
" in the software.
"<< End of dirDiff plugin <><><><><><><><><><><><><><><><><><><><><><><><><><><>
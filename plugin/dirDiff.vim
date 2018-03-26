" @Tracked
" Directory Differ Plugin
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 03/01/2018 03:36 PM
let s:Version = 2.05

" TODO: Need to fix manualExplore and SmartExplore not going to script-local versions
" TODO: Add copying of files/dirs (essentially dp and do)
" TODO: Remove unnecessary <SID>s
" TODO: Dynamic update of diffness when you save files (Cause they might have changed)

" Anti-inclusion guard and version
if (exists("g:loaded_dirDiff") && (g:loaded_dirDiff >= s:Version))
   finish
endif
let g:loaded_dirDiff = s:Version

" Options
" Ignores all directories with names that match this list
if (!exists("g:dirDiff_IgnoreDirs"))
   let g:dirDiff_IgnoreDirs = ['CVS']
endif
" Include hidden files in the diff
if (!exists("g:dirDiff_IncludeHiddenFiles"))
   let g:dirDiff_IncludeHiddenFiles = 0
endif
" Use diffthis to add filler to diffDir. This can be useful but it's slower.
if (!exists("g:dirDiff_UseDiffModeOnDirs"))
   let g:dirDiff_UseDiffModeOnDirs = 1
endif

" Definitions:
" A {directory} is a dictionary with the following structure:
"   Key
"   |--dirs[{directory}]         " The key is the dir name the value is another
"   |                            "   directory structure
"   |--files[string]             " A list of files
"   |--path[string]              " An absolute path to the directory
"   |--currentNode[&{directory}] " A reference to the active (currently viewed)
"   |                            "   node
"   |--parentNode[&{directory}]  " A reference to the parent of the active node
"   |--root[bool]                " Whether or not this node is the root of the
"                                "   comparison (has no parent)

let s:DirMode = 0
let s:uniqueID = 0
let s:sortDirs = [[], []]

" DirDiff <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Diffs two directories and allows you to quickly jump between
"          different files in the dirs.
"     input   - optional: [bool] When present opens diff with first dir on left.
"                         Opens on right otherwise.
"     returns - void
function! DirDiff(...)
   if (&filetype == 'netrw')
      " Only works when starting from netrw
      if (expand('%') != '')
         cd %
      endif
      let firstDirTemp = <SID>ExpandDir(getcwd(), 1)
      let secondDirTemp = input("First Directory: " . firstDirTemp . "\n" .
                                \ "What is the other directory you want to compare? ", 'C:/', "dir")
      " This is here so we can type wile still in the netrw tab.
      if (secondDirTemp != '')
         let secondDirTemp = <SID>ExpandDir(secondDirTemp, 1)
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
         if exists('g:loaded_projectManager')
            let list = ProjectManager_ReturnProject(firstDir)
            let firstProject = list[0]
            let firstRoot = list[1]
            let list = ProjectManager_ReturnProject(secondDir)
            let secondProject = list[0]
            let secondRoot = list[1]
            if (firstProject.name != '' && (firstProject.name == secondProject.name))
               " If the projects are the same then diff the whole project
               " (Only works for relative projects)
               for dir in ProjectManager_ReturnProjectDirectories(firstProject.name)
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

" SetUpLegend <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Sets up the "Legend" buffer to show the user what colors mean
"    returns - void
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
   let t:dirDiff_tab = 1
   let g:dirDiff_LegendBuff = bufnr('%')
   nmap <silent><buffer> l :call <SID>BackoutOfSingle()<CR>
   nmap <silent><buffer> - :call <SID>BackoutOfSingle()<CR>
   call <SID>HighlightDir(['IdenticalDirectory/'], ['CommonDifferentDirectory/'], ['UniqueDirectory/'], ['IdenticalFile'], ['CommonDifferentFile'], ['UniqueFile'])
   set nomodifiable
   quit
endfunction

" SetupDirDiffTab <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Sets up a tab as a DirDiff tab. Sets all the neccessary variables and
"          mappings for both windows.
"    input   - firstDir: [string] A path to setup as the first directory
"              secondDir: [string] A path to setup as the secdond directory
"              switchFlag: [bool] Weather or not to switch back to the first
"                          window after setting up the whole tab
"    returns - void
function! s:SetupDirDiffTab(firstDir, secondDir, switchFlag)
   tabnew
   call <SID>SetTabName('Dir Diff')
   let t:dirDiff_tab = 1
   let firstDir = substitute(a:firstDir, '/\=$', '/', '')
   let secondDir = substitute(a:secondDir, '/\=$', '/', '')
   let t:dirDiff_FirstDir = {}
   let t:dirDiff_SecondDir = {}
   call <SID>InitializeDir(firstDir, t:dirDiff_FirstDir)
   call <SID>InitializeDir(secondDir, t:dirDiff_SecondDir)

   let t:dirDiff_SortOrder = {}
   let t:dirDiff_SortOrder.currentNode = t:dirDiff_SortOrder
   let t:dirDiff_SortOrder.index = [0, 0]
   call <SID>PopulateSortOrder(t:dirDiff_SortOrder, t:dirDiff_FirstDir, t:dirDiff_SecondDir)

   call <SID>ViewDirDiff(t:dirDiff_SortOrder, t:dirDiff_FirstDir, t:dirDiff_SecondDir)
   let t:dirDiff_Files = []

   let t:dirDiff_FirstDir.currentNode = t:dirDiff_FirstDir
   let t:dirDiff_SecondDir.currentNode = t:dirDiff_SecondDir
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
   let hiddenFiles = []
   if (g:dirDiff_IncludeHiddenFiles)
      let hiddenFiles = globpath(a:path, '.[^.]*', 1, 1)
   endif
   let a:directory.files = hiddenFiles + globpath(a:path, '*', 1, 1)
   let a:directory.dirs = {}
   let loopCount = 0
   for entry in a:directory.files
      if isdirectory(entry)
         " Take out all directories
         let dirName = fnamemodify(entry, ':t')
         if (index(g:dirDiff_IgnoreDirs, dirName) == -1)
            " Don't add ignored directories.
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
"   brief: Takes a dictionary and fills in all necessary varialbes in order to
"         diff the current dir.
"    input   - sort: [{dictionary}] the dictionary to fill
"              dir1: [{directory}] A dictionary that contains all of the
"                    directory structure for the first dir
"              dir2: [{directory}] A dictionary that contains all of the
"                    directory structure for the second dir
"    returns - void
function! s:PopulateSortOrder(sort, dir1, dir2)
   if (has_key(a:sort, 'Sorted'))
      " Already populated and sorted, move along.
      return
   else
      let dir1 = a:dir1
      let dir2 = a:dir2
      if (<SID>TreeIsDetached(1))
         let dir1 = t:dirDiff_SortOrder.backupNode[0]
      endif
      if (<SID>TreeIsDetached(2))
         let dir2 = t:dirDiff_SortOrder.backupNode[1]
      endif

      call <SID>CompareDirectories(a:sort, dir1, dir2, 1)
   endif
endfunction

" PopulateSingle ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Fills in the necessary variables to "diff" the current single
"         directory
"    input   - dir: [{directory}] A dictionary that contains all of the
"                   directory structure to the dir
"    returns - void
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

" ViewDirDiff <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Views the current structure in the current tab
"     input   - sortOrder: [{dictionary}] The node to inspect
"               dir1: [{directory}] The first dir to diff
"               dir2: [{directory}] The second dir to diff
"     returns - void
function! s:ViewDirDiff(sortOrder, dir1, dir2)
   let savedWindow = winnr()
   if (!has_key(a:sortOrder, "dirDiff_Files"))
      " Files don't exsist, need to create them.
      let a:sortOrder.dirDiff_Files = []
      " A list of temp files where we will store the "directory structure"
      "  to be examined
      if (winnr('$') < 2)
         vsplit
      endif
      call s:SortDirDiff(a:sortOrder, a:dir1, a:dir2)
   else
      " Files already exist, just need to view them.
      if !(<SID>TreeIsDetached(1))
         wincmd h
         exe 'silent e ' . a:sortOrder.dirDiff_Files[a:sortOrder.sortIndex*4 + 1*s:DirMode]
         call <SID>HighlightDir()
         let w:dirDiff_buffNumber = a:sortOrder.browseBuff[0][a:sortOrder.sortIndex*2 + 1*s:DirMode]
      endif
      if !(<SID>TreeIsDetached(2))
         if (winnr('$') < 2)
            exe 'vnew ' . a:sortOrder.dirDiff_Files[a:sortOrder.sortIndex*4+2 + 1*s:DirMode]
            if (!&splitright)
               " Make sure split shows up on side expected
               wincmd L
            endif
         else
            wincmd l
            exe 'silent e ' . a:sortOrder.dirDiff_Files[a:sortOrder.sortIndex*4+2 + 1*s:DirMode]
         endif
         call <SID>HighlightDir()
         let w:dirDiff_buffNumber = a:sortOrder.browseBuff[1][a:sortOrder.sortIndex*2 + 1*s:DirMode]
      endif
   endif
   " This just sets the cursor where it should be
   exe savedWindow . "wincmd w"
   call <SID>NextItem(winnr(), 0)
endfunction

" ViewSingle ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Like ViewDirDiff but only on a single dir
"     input   - dir: [{directory}] The dir to view
"               window: [int] Which window to view it in
"     returns - void
function! s:ViewSingle(dir, window)
   if (!has_key(a:dir, "dirDiff_File"))
      " Files don't exsist, need to create them.
      let a:dir.dirDiff_File = tempname()
      if (len(a:dir.Sorted) <= 0)
         call add(a:dir.Sorted, "** Empty **")
      endif
      call writefile(a:dir.header + a:dir.Sorted, a:dir.dirDiff_File)
      exe 'silent e ' . a:dir.dirDiff_File
      let a:dir.browseBuff = bufnr('%')
      let w:dirDiff_buffNumber = bufnr('%')
      set nomodifiable
      set cursorline
      call <SID>HighlightDir([], [], keys(a:dir.dirs), [], [], a:dir.files)
      call <SID>SetUpSingleMappings(a:window)
   else
      " Files already exist, just need to view them.
      exe 'silent e ' . a:dir.dirDiff_File
      call <SID>HighlightDir()
      let w:difDir_buffNumber = a:dir.browseBuff
   endif
   " This just sets the cursor where it should be
   call <SID>NextSingleItem(a:dir, 0)
endfunction

" ReattachNode ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: When a tree walker becomes detached from the trunk, this function
"          will reattach it to the trunk to be synced and move with the trunk
"          again.
"     input   - sortOrder: [{dictionary}] A reference to the "trunk"
"               window: [int] Which window we're reattaching
"     returns - void
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
         let t:dirDiff_FirstDir.currentNode = t:dirDiff_SortOrder.backupNode[a:window-1]
      else
         let t:dirDiff_SecondDir.currentNode = t:dirDiff_SortOrder.backupNode[a:window-1]
      endif
      let fullySyncedFlag = <SID>DeleteBackupNode(a:window)
      exe 'silent b ' . a:sortOrder.browseBuff[a:window-1][a:sortOrder.sortIndex*2 + 1*s:DirMode]
      call <SID>HighlightDir()
      let w:dirDiff_buffNumber = a:sortOrder.browseBuff[a:window-1][a:sortOrder.sortIndex*2 + 1*s:DirMode]
      if (switchedFlag)
         wincmd w
      endif
      if (fullySyncedFlag)
         echo ""
      endif
      call <SID>NextItem(a:window, 0)
   endif
endfunction

" SetUpMappings <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Sets up all local mappings to control the dirDiff
"     input   - sortOrder: [{dictionary}] A reference to the "trunk"
"               window: [int] Which window we're mapping
"               optional: [bool] If present the function will instead set up
"                         autocommands that will set up the mappings once the
"                         buffer is loaded. This is required because we cannot
"                         setup mappings to a buffer that is not active, but we
"                         CAN set up autocommands in inactive buffers.
"     returns - void
function! s:SetUpMappings(window, ...)
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

" SetUpSingleMappings <><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Same as SetUpMappings except it sets up mappings to the single file
"          version of some of the functions
"     input   - window: [int] Which window to set up
"     returns - void
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

" NextItem ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Moves to next nth item in the current window and updates the view of
"          the alternate window
"     input   - window: [int] Which window is the currnet window
"               n: [int] How far to move the pointer (works with negatives as
"                  well)
"     returns - void
function! s:NextItem(window, n)
   let window = a:window-1
   let arrayLength = len(<SID>GetCurrentNode(0).Sorted[window])
   let lineWithFirstIndex = 5
   if (arrayLength > 0)
      let t:dirDiff_SortOrder.currentNode.index[window] = (<SID>GetCurrentNode(0).index[window] + a:n) % arrayLength
      if (<SID>GetCurrentNode(0).index[window] < 0)
         let t:dirDiff_SortOrder.currentNode.index[window] = arrayLength + <SID>GetCurrentNode(0).index[window]
      endif
      " Retrieve the matching index for the other window (As long as the tree isn't detached)
      if !(<SID>TreeIsDetached(a:window+1))
         let otherIndex = index(<SID>GetCurrentNode(0).Sorted[(window+1)%2], <SID>GetCurrentNode(0).Sorted[window][<SID>GetCurrentNode(0).index[window]])
         wincmd w
         if (otherIndex != -1)
            let t:dirDiff_SortOrder.currentNode.index[(window+1)%2] = otherIndex
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

" NextSingleItem ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Same as NextItem except doesn't update the view of the alternate
"          window
"     input   - dir: [{directory}] The directory to move the pointer in
"               n: [int] How far to move the pointer (works with negativs as
"                  well)
"     returns - void
function! s:NextSingleItem(dir, n)
   let arrayLength = len(a:dir.Sorted)
   if (arrayLength > 0)
      let a:dir.index = (a:dir.index + a:n) % arrayLength
      if (a:dir.index < 0)
         let a:dir.index = arrayLength + a:dir.index
      endif
   endif
   call setpos('.', [0, a:dir.index + 5, 0, 0])
   normal zz
endfunction

" LeftMouse <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Adds support for the mouse. Makes clicking the same as <CR>.
"     input   - window: [int] The window being clicked on
"     returns - void
function! s:LeftMouse(window)
   " TODO: Partial mouse support. Has some bugs. Need to debug later.
   " TODO: Might have problems when clicking on the inactive window.
   let before = getcurpos()[1]
   exe "normal! \<LeftMouse>"
   let difference = getcurpos()[1] - before
   call <SID>NextItem(a:window, difference)
   call <SID>DirDiffSelect(<SID>GetCurrentNode(0), a:window, <SID>GetCurrentNode(1), <SID>GetCurrentNode(2))
endfunction

" DirDiffSelect <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   breif: If over a directory, browse into directory. If over a file, diff the
"          file
"     input   - sortOrder: [{dictionary}] A reference to the "trunk"
"               window: [int] Which window the select is happening in
"               dir1: [{directory}] The current node in the first directory in
"                     the diff
"               dir2: [{directory}] The current node in the second directory in
"                     the diff
"     returns - void
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
         if (!has_key(t:dirDiff_SortOrder, 'backupNode'))
            let t:dirDiff_SortOrder.backupNode = [{}, {}]
         endif
         let t:dirDiff_SortOrder.backupNode[window] = <SID>GetCurrentNode(a:window)
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

" SelectSingle ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Same as DirDiffSelect but only handles one dir
"     input   - path: [string] The path of the dir being selected in
"               file: [string] The name of the item being selected
"               window: [int] The window being selected in
"     returns - void
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

" ToggleDirMode <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Toggles between having the dirs display above all the files and
"   beneath all the files
"     input   - sortOrder: [{dictionary}] A reference to the "trunk"
"               dir1: [{directory}] The current node in the first directory in
"                     the diff
"               dir2: [{directory}] The current node in the second directory in
"                     the diff
"     returns - void
function s:ToggleDirMode(sortOrder, dir1, dir2)
   if (s:DirMode)
      let s:DirMode = 0
   else
      let s:DirMode = 1
   endif
   call <SID>SortDirDiff(a:sortOrder, a:dir1, a:dir2)
endfunction

" SwapEm ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Saps the lists between sorted having the dirs first and last
"     input   - sortOrder: [{dictionary}] A reference to the "trunk"
"     returns - void
function s:SwapEm(sortOrder)
   let save = deepcopy(a:sortOrder.Sorted)
   let a:sortOrder.Sorted = deepcopy(s:sortDirs)
   let s:sortDirs = deepcopy(save)
endfunction

" IncSortOrder ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Advances the index through the valid sort modes
"     input   - sortOrder: [{dictionary}] A reference to the "trunk"
"               dir1: [{directory}] The current node in the first directory in
"                     the diff
"               dir2: [{directory}] The current node in the second directory in
"                     the diff
"     returns - void
function s:IncSortOrder(sortOrder, dir1, dir2)
   let a:sortOrder.sortIndex = (a:sortOrder.sortIndex + 1) % 3
   call <SID>SortDirDiff(a:sortOrder, a:dir1, a:dir2)
endfunction

" SortDirDiff <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Sorts the files in the DirDiff in the following ways:
"          1: All Common files followed by all Unique files (default)
"          2: CommonDiff files, CommonSame files, Unique files
"          3: Alphabetically
"     input   - sortOrder: [{dictionary}] A reference to the "trunk"
"               dir1: [{directory}] The current node in the first directory in
"                     the diff
"               dir2: [{directory}] The current node in the second directory in
"                     the diff
"     return - void
function! s:SortDirDiff(sortOrder, dir1, dir2)
   if exists('t:dirDiff_tab')
      " Only works in a DirDiff tab
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
      for list in a:sortOrder.Sorted
         " If the dir is empty, indicate it.
         if len(list) == 0
            call add(list, '** Empty **')
         endif
      endfor
      if (len(a:sortOrder.dirDiff_Files) < ((a:sortOrder.sortIndex)*4+1))
         call add(a:sortOrder.dirDiff_Files, tempname())
         call add(a:sortOrder.dirDiff_Files, tempname())
         call add(a:sortOrder.dirDiff_Files, tempname())
         call add(a:sortOrder.dirDiff_Files, tempname())
         call writefile(a:sortOrder.firstHeader + a:sortOrder.Sorted[0],  a:sortOrder.dirDiff_Files[(a:sortOrder.sortIndex)*4])
         call writefile(a:sortOrder.firstHeader + s:sortDirs[0],          a:sortOrder.dirDiff_Files[(a:sortOrder.sortIndex)*4+1])
         call writefile(a:sortOrder.secondHeader + a:sortOrder.Sorted[1], a:sortOrder.dirDiff_Files[(a:sortOrder.sortIndex)*4+2])
         call writefile(a:sortOrder.secondHeader + s:sortDirs[1],         a:sortOrder.dirDiff_Files[(a:sortOrder.sortIndex)*4+3])
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

" SetUpBuffer <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Edits the correct buffer calculated from sortOrder and sets up
"          appropriate window variables
"     input   - sortOrder: [{dictionary}] A reference to the "trunk"
"               window: [int] The window to set up
"     returns - void
function s:SetUpBuffer(sortOrder, window)
   if !(<SID>TreeIsDetached(a:window))
      exe 'edit! ' . a:sortOrder.dirDiff_Files[a:sortOrder.sortIndex*4 + 2*(a:window-1) + s:DirMode]
      let a:sortOrder.browseBuff[a:window-1][a:sortOrder.sortIndex*2 + 1*s:DirMode] = bufnr('%')
      let w:dirDiff_buffNumber = bufnr('%')
      if (exists('b:containedCommonSameDirs'))
         call <SID>HighlightDir()
      else
         if (a:window == 1)
            call <SID>HighlightDir(a:sortOrder.CommonSameDir, a:sortOrder.CommonDiffDir, a:sortOrder.firstUniqueDir, a:sortOrder.CommonSame, a:sortOrder.CommonDiff, a:sortOrder.firstUnique)
         else
            call <SID>HighlightDir(a:sortOrder.CommonSameDir, a:sortOrder.CommonDiffDir, a:sortOrder.secondUniqueDir, a:sortOrder.CommonSame, a:sortOrder.CommonDiff, a:sortOrder.secondUnique)
         endif
      endif

      " Create a proper diff with filler and everything.
      if (g:dirDiff_UseDiffModeOnDirs)
         diffthis
      endif

      call <SID>SetUpMappings(winnr())
   else
      let bufnr = bufnr(a:sortOrder.dirDiff_Files[a:sortOrder.sortIndex*4 + 2*(a:window-1) + s:DirMode])
      if (bufnr == -1)
         exe "badd ".a:sortOrder.dirDiff_Files[a:sortOrder.sortIndex*4 + 2*(a:window-1) + s:DirMode]
         let bufnr = bufnr(a:sortOrder.dirDiff_Files[a:sortOrder.sortIndex*4 + 2*(a:window-1) + s:DirMode])
      endif
      if (a:window == 1)
         call <SID>HighlightDir(a:sortOrder.CommonSameDir, a:sortOrder.CommonDiffDir, a:sortOrder.firstUniqueDir, a:sortOrder.CommonSame, a:sortOrder.CommonDiff, a:sortOrder.firstUnique, bufnr)
      else
         call <SID>HighlightDir(a:sortOrder.CommonSameDir, a:sortOrder.CommonDiffDir, a:sortOrder.secondUniqueDir, a:sortOrder.CommonSame, a:sortOrder.CommonDiff, a:sortOrder.secondUnique, bufnr)
      endif
      let a:sortOrder.browseBuff[a:window-1][a:sortOrder.sortIndex*2 + 1*s:DirMode] = bufnr
      call <SID>SetUpMappings(winnr(), bufnr)
      " Buffer is already setup and can't be loaded. Do nothing.
   endif
endfunction

" HighlightDir ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Highlights file names in buffer based on window variables
"    input   - void OR
"              a:1: [string[]] A list of files to highlight as an Identical dir
"              a:2: [string[]] A list of files to highlight as a different dir
"              a:3: [string[]] A list of files to highlight as a unique dir
"              a:4: [string[]] A list of files to highlight as an identical file
"              a:5: [string[]] A list of files to highlight as adifferent file
"              a:6: [string[]] A list of files to highlight as a unique file
"              a:7: [int] The buffer number (only needed if the buffer that
"                   you're highlighting isn't the current buffer)
"    returns - void
function! s:HighlightDir(...)
   if exists('t:dirDiff_tab')
      " Only works in a dirDiff_ tab
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
         let entry = substitute(entry, '/$', '', '')
         let entry = s:EscapeRegex(entry)
         exe "syn match CommonSameDir '" . entry . "\\(/$\\)\\@='"
      endfor
      for entry in CommonDiffDirList
         let entry = substitute(entry, '/$', '', '')
         let entry = s:EscapeRegex(entry)
         exe "syn match CommonDiffDir '" . entry . "\\(/$\\)\\@='"
      endfor
      for entry in UniqueDirList
         let entry = substitute(entry, '/$', '', '')
         let entry = s:EscapeRegex(entry)
         exe "syn match UniqueDir '" . entry . "\\(/$\\)\\@='"
      endfor
      for entry in CommonSameList
         let entry = s:EscapeRegex(entry)
         exe "syn match CommonSame '" . entry . "$'"
      endfor
      for entry in CommonDiffList
         let entry = s:EscapeRegex(entry)
         exe "syn match CommonDiff '" . entry . "$'"
      endfor
      for entry in UniqueList
         let entry = s:EscapeRegex(entry)
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
         hi CommonSameDir cterm=NONE ctermbg=bg ctermfg=120 gui=NONE guibg=bg guifg='#00BB33'
         hi CommonDiffDir cterm=NONE ctermbg=bg ctermfg=116 gui=NONE guibg=bg guifg='#FF55FF'
         hi UniqueDir     cterm=NONE ctermbg=bg ctermfg=173 gui=NONE guibg=bg guifg=DarkRed
         hi CommonSame cterm=NONE ctermbg=bg ctermfg=28  gui=NONE guibg=bg guifg=DarkGreen
         hi CommonDiff cterm=NONE ctermbg=bg ctermfg=30  gui=NONE guibg=bg guifg=Darkcyan
         hi Unique     cterm=NONE ctermbg=bg ctermfg=167 gui=NONE guibg=bg guifg=indianred
      endif
   endif
endfunction

" DiffCurrentFile <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Diffs the two files passed in
"     input   - firstFile: [string] The first file in the diff
"               secondFile: [string] The second file in the diff
"     returns - void
function! s:DiffCurrentFile(firstFile, secondFile)
   if (<SID>GetCurrentNode(0).index[winnr()-1] <
            \ len(<SID>GetCurrentNode(0).Common + <SID>GetCurrentNode(0).CommonDir) && exists('t:dirDiff_tab') &&
            \ a:firstFile != '** Empty **' && a:secondFile != '** Empty **')
      " Only works in a DirDiff tab
      if (winnr() == 1)
         exe 'edit! ' a:firstFile
      else
         exe 'edit! ' a:secondFile
      endif
      set modifiable
      set nocursorline
      diffthis
      noremap <buffer> - :call <SID>BackoutOfDiff()<CR>
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
      noremap <buffer> - :call <SID>BackoutOfDiff()<CR>
      exe "normal! \<C-W>w"
      set visualbell
      normal gg]c[c
      set novisualbell
   endif
endfunction

" SingleFileEnter <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Edits the file and sets up a few settings to link it back to the
"          dirdiff
"     input   - file: [string] The file to edit
"     returns - void
function! s:SingleFileEnter(file)
   if (exists('t:dirDiff_tab') && a:file !~ '\*\* Empty \*\*$')
      " Only works in a DirDiff tab
      exe 'edit! ' a:file
      set modifiable
      set nocursorline
      noremap <buffer> - :call <SID>BackoutOfSingle()<CR>
   endif
endfunction

" BackoutOfDiff <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: returns to DirDiff screen when in a diff
"    return  - void
function! s:BackoutOfDiff()
   if exists('t:dirDiff_tab')
      " Only works in a DirDiff tab
      let l:mod = &mod
      exe "normal! \<C-W>w"
      let l:mod = &mod || l:mod
      exe "normal! \<C-W>w"

      if (l:mod)
         call <SID>EchoError('Please save file first!')
      else
         diffoff!
         exe 'silent b ' . w:dirDiff_buffNumber
         call <SID>HighlightDir()
         exe "normal! \<C-W>w"
         exe 'silent b ' . w:dirDiff_buffNumber
         call <SID>HighlightDir()
         set nomodifiable
         set cursorline
         exe "normal! \<C-W>w"
         set nomodifiable
         set cursorline
         call <SID>NextItem(winnr(), 0)
      endif
   else
      " If we aren't in a DirDiff tab, then we probably were trying to Explore.
      noremap <buffer> - :call SmartExplore('file')<CR>
      call SmartExplore('file')
   endif
endfunction

" BackoutOfSingle <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Same as BackoutOfDiff but only for one side
"     returns - void
function! s:BackoutOfSingle()
   if exists('t:dirDiff_tab')
      " Only works in a DirDiff tab
      let l:mod = &mod
      exe "normal! \<C-W>w"
      let l:mod = &mod || l:mod
      exe "normal! \<C-W>w"

      if (l:mod)
         call <SID>EchoError('Please save file first!')
      else
         try
            exe 'silent b ' . w:dirDiff_buffNumber
            call <SID>HighlightDir()
            set nomodifiable
            set cursorline
            if (<SID>TreeIsDetached(winnr()))
               call <SID>NextSingleItem(<SID>GetCurrentNode(winnr()), 0)
            else
               call <SID>NextItem(winnr(), 0)
            endif
         catch /^Vim\%((\a\+)\)\=:E749/
            " This is an erroneous error. It is documented as a known bug in the
            " help.
         endtry
      endif
   else
      " If we aren't in a DirDiff tab, then we probably were trying to Explore.
      noremap <buffer> - :call SmartExplore('file')<CR>
      call SmartExplore('file')
   endif
endfunction

" Traverse ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Sets all current attached nodes to dir passed in
"     input   - dir: [{directory}] The dir to traverse to
"     returns - void
function! s:Traverse(dir)
   let parentNode = t:dirDiff_SortOrder.currentNode
   if (!has_key(t:dirDiff_SortOrder.currentNode, 'dirs'))
      let t:dirDiff_SortOrder.currentNode.dirs = {}
   endif
   if (!has_key(t:dirDiff_SortOrder.currentNode.dirs, a:dir))
      let t:dirDiff_SortOrder.currentNode.dirs[a:dir] = {}
   endif
   let t:dirDiff_SortOrder.currentNode = t:dirDiff_SortOrder.currentNode.dirs[a:dir]
   let t:dirDiff_SortOrder.currentNode.parentNode = parentNode

   if !(<SID>TreeIsDetached(1))
      let parentNode = t:dirDiff_FirstDir.currentNode
      let t:dirDiff_FirstDir.currentNode = t:dirDiff_FirstDir.currentNode.dirs[a:dir]
      let t:dirDiff_FirstDir.currentNode.parentNode = parentNode
   else
      " First tree is currently detached. Move the backupNode instead.
      let parentNode = t:dirDiff_SortOrder.backupNode[0]
      let t:dirDiff_SortOrder.backupNode[0] = t:dirDiff_SortOrder.backupNode[0].dirs[a:dir]
      let t:dirDiff_SortOrder.backupNode[0].parentNode = parentNode
   endif

   if !(<SID>TreeIsDetached(2))
      let parentNode = t:dirDiff_SecondDir.currentNode
      let t:dirDiff_SecondDir.currentNode = t:dirDiff_SecondDir.currentNode.dirs[a:dir]
      let t:dirDiff_SecondDir.currentNode.parentNode = parentNode
   else
      " Second tree is currently detached. Move the backupNode instead.
      let parentNode = t:dirDiff_SortOrder.backupNode[1]
      let t:dirDiff_SortOrder.backupNode[1] = t:dirDiff_SortOrder.backupNode[1].dirs[a:dir]
      let t:dirDiff_SortOrder.backupNode[1].parentNode = parentNode
   endif
endfunction

" SingleTraverse ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Same as Traverse but only does one dir
"     input   - dir: [{directory}] The dir to traverse to
"               window: [int] The window being used in the traverse
"     returns - void
function! s:SingleTraverse(dir, window)
   if (a:window == 1)
      let parentNode = t:dirDiff_FirstDir.currentNode
      let t:dirDiff_FirstDir.currentNode = t:dirDiff_FirstDir.currentNode.dirs[a:dir]
      let t:dirDiff_FirstDir.currentNode.parentNode = parentNode
   else
      let parentNode = t:dirDiff_SecondDir.currentNode
      let t:dirDiff_SecondDir.currentNode = t:dirDiff_SecondDir.currentNode.dirs[a:dir]
      let t:dirDiff_SecondDir.currentNode.parentNode = parentNode
   endif
endfunction

" ParentDir <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: The opposite of Traverse. Sets all nodes to their parent node.
"     returns - void
function! s:ParentDir()
   if (t:dirDiff_FirstDir.currentNode.root != 1)
      let t:dirDiff_SortOrder.currentNode = t:dirDiff_SortOrder.currentNode.parentNode
      if !(<SID>TreeIsDetached(1))
         let t:dirDiff_FirstDir.currentNode = t:dirDiff_FirstDir.currentNode.parentNode
      else
         let t:dirDiff_SortOrder.backupNode[0] = t:dirDiff_SortOrder.backupNode[0].parentNode
      endif
      if !(<SID>TreeIsDetached(2))
         let t:dirDiff_SecondDir.currentNode = t:dirDiff_SecondDir.currentNode.parentNode
      else
         let t:dirDiff_SortOrder.backupNode[1] = t:dirDiff_SortOrder.backupNode[1].parentNode
      endif
      call <SID>ViewDirDiff(t:dirDiff_SortOrder.currentNode, t:dirDiff_FirstDir.currentNode, t:dirDiff_SecondDir.currentNode)
   else
      echohl ERROR
      echo "Already at root of comparison"
      echohl NORMAL
   endif
endfunction

" SingleParentDir <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Same as ParentDir but only does one dir
"     input   - dir: [{directory}] The dir to traverse from
"               window: [int] The window being used in the traverse
"     returns - void
function! s:SingleParentDir(dir, window)
   if (a:dir.root != 1)
      if (has_key(a:dir.parentNode, 'Sorted'))
         if (a:window == 1)
            let t:dirDiff_FirstDir.currentNode = t:dirDiff_FirstDir.currentNode.parentNode
         elseif (a:window == 2)
            let t:dirDiff_SecondDir.currentNode = t:dirDiff_SecondDir.currentNode.parentNode
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
"   brief: Gets the current node for any of the trees
"     input   - walker: [int] Which tree to fetch
"     returns - [{directory}] The current node of the specified tree
function! s:GetCurrentNode(walker)
   if      (a:walker == 0)
      return t:dirDiff_SortOrder.currentNode
   elseif (a:walker == 1)
      return t:dirDiff_FirstDir.currentNode
   elseif (a:walker == 2)
      return t:dirDiff_SecondDir.currentNode
   else
      return {}
   endif
endfunction

" DeleteBackupNode ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Deletes the reference to the backupNode in the "trunk"
"     input   - window: [int] Which dir we should be deleting it for
"     returns - [bool] True if it removed the entry, false if it only removed
"               one backup and another remains
function! s:DeleteBackupNode(window)
   if (has_key(t:dirDiff_SortOrder, 'backupNode'))
      let t:dirDiff_SortOrder.backupNode[a:window-1] = {}
      if (empty(t:dirDiff_SortOrder.backupNode[0]) && empty(t:dirDiff_SortOrder.backupNode[1]))
         call remove(t:dirDiff_SortOrder, 'backupNode')
         return 1
      endif
   endif
   return 0
endfunction

" TreeIsDetached ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Queries whether the tree is detached from the "trunk"
"     input   - tree: [int] Which tree to query
"     returns - [bool] True if the specified tree is currently detached, false
"               if it is attached
function! s:TreeIsDetached(tree)
   if (a:tree > 2)
      let tree = 1
   elseif a:tree < 1
      return 0
   else
      let tree = a:tree
   endif
   return (has_key(t:dirDiff_SortOrder, 'backupNode') && !empty(t:dirDiff_SortOrder.backupNode[tree-1]))
endfunction

" CompareDirectories ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Takes two directories and does all the work necessary to determine
"          if they are equivalent in evry way or if they differ in some way
"     input   - sortOrder: [{dictionary}] A reference to the "trunk"
"               dir1: [{directory}] The first directory to compare
"               dir2: [{directory}] The second directory to compare
"               mustFinish: [bool] A flag that specifies if the function can
"                           just return once it determines that the directories
"                           are different (for speed) or if it must finish
"                           populating the directory before it can return
"     returns - [bool] True if the two directories are equivalent, false if they
"               differ
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
      for one in a:dir1.files
         let loopCounter = 0
         let UniqueFlag = 1
         for two in a:sortOrder.secondUnique
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
               call remove(a:sortOrder.secondUnique, loopCounter)
               let firstUniquePosition -= 1
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
      for one in keys(a:dir1.dirs)
         let loopCounter = 0
         if (!has_key(a:sortOrder.dirs, one))
            let a:sortOrder.dirs[one] = {}
         endif
         let UniqueFlag = 1
         for two in a:sortOrder.secondUniqueDir
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
               call remove(a:sortOrder.secondUniqueDir, loopCounter)
               let firstUniquePosition -= 1
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

      " Make sure all the directories are in order. (Since they came from a
      " dictionary, there's no telling what order they're in.)
      call sort(a:sortOrder.CommonDir, 1)
      call sort(a:sortOrder.CommonSameDir, 1)
      call sort(a:sortOrder.CommonDiffDir, 1)
      call sort(a:sortOrder.firstUniqueDir, 1)
      call sort(a:sortOrder.secondUniqueDir, 1)

      let a:sortOrder.Sorted = [a:sortOrder.CommonDir + a:sortOrder.firstUniqueDir + a:sortOrder.Common + a:sortOrder.firstUnique,
                              \ a:sortOrder.CommonDir + a:sortOrder.secondUniqueDir + a:sortOrder.Common + a:sortOrder.secondUnique]
   endif
   return retVal
endfunction

" SetTabName ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Sets current tab name and updates all tabs
"     input   - optional: [string] If present sets the tab's name to this, if
"                         not present set the tab's name to the value of
"                         w:mytablabel
"     returns - void
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
"     input   - input: [string] The regex string to escape
"     returns - [string] The resulting escaped regex string
function! s:EscapeRegex(input)
   return escape(a:input, '\^$.*~[&' . "'")
endfunction

" EchoError <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Echos message with error hilighting (usually red background with
"          white text).
"     input   - message: [string] A string to echo on the command line
"     returns - void
function! s:EchoError(message)
   echo "\n"
   echohl ERROR
   echo a:message
   echohl NORMAL
endfunction

" ExpandDir <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Expands relative directories to absolute as well as takes out any
"          Win-slashes.
"     input   - dir: [string] The directory to expand
"     input   - trailingSlashFlag: [bool] Returns a string with a trailing slash
"               if true, without if false.
"     returns - dir: [string] The expanded directory
function! s:ExpandDir(dir, trailingSlashFlag)
   let newDir = a:dir
   if (a:trailingSlashFlag)
      let newDir = fnamemodify(newDir, ":p")
   else
      let newDir = fnamemodify(newDir, ":p:h")
   endif
   let newDir = substitute(newDir, "\\", "/", "g")

   return newDir
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
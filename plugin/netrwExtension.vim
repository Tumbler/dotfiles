" @Tracked
" Netrw Extension Plugin
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 12/13/2016 03:01 PM
" Version: 1.4 <-Change this!

" TODO: Community plugin standards

let g:netrwExtension = 1

let g:vimpathmemFile = $HOME.'/vimfiles/.vimpathmem'

let s:User_autoread = &autoread

command! -nargs=1 -complete=dir Goto :call ManualExplore('<args>')
" Allows to you jump to any directory without having to get there through netrw

nnoremap - :call SmartExplore('file')<CR>
" Press minus to bring up File explorer

let s:netrw_pathmemNum = 200
" Number of paths to remember when navigating using netrw

if has("autocmd")
augroup netrw_Extension
   au!
   autocmd VimEnter     * call CheckForPathMem()
   autocmd filetype netrw call Remap_netrw()
augroup END
endif

" Define g:netrw_startingDir in vimpref if you want a custom starting directory.
if !exists('g:netrw_startingDir')
   if has("win32")
      let g:netrw_startingDir = 'C:/'
   else
      let g:netrw_startingDir = $HOME
   endif
endif

if has("autocmd")
augroup NetrwExtension
   au!
   autocmd VimEnter * let g:netrw_first = 1
augroup END
endif

"  SmartExplore <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Opens explorer pointing at file or dir we just came out of.
" TODO: Seems to be missing files sometimes and instead going to top of file...
" TODO: Figured it out! When you back out of a file but your pwd isn't the same
" as the file your editing, this will cause it to miss the reposition.
function! SmartExplore(origin)
   " If we're in a diff, then close the other window before continuing
   if (&diff)
      diffoff!
      if (winnr('$') > 1)
         wincmd w
         quit
      endif
   endif
   if (&modified && winnr('$') == 1)
      call <SID>EchoError("Save changes first!")
      return
   endif
   if g:netrw_first
      exe "cd " . g:netrw_startingDir
      let g:netrw_first = 0
   endif
   "  If empty document then don't bother
   if (line('$') == 1 && getline(1) == '')
      if !(s:User_autoread)
         set autoread
         Explore
         set noautoread
      else
         Explore
      endif
      call RememberLocation()
      if (&scrolloff =~# '0')
         normal zz
      endif
      normal C
      " Sets the current editing window (Makes netrw open file in same window)
   else
      if (a:origin == 'netrw')
         let l:currentFilename = substitute(fnamemodify(b:netrw_curdir, ':t'), '/\=$', '/', '')
      else
         let l:currentFilename = @%
      endif
      call SyncDirs()
      if (a:origin == 'netrw')
         if !(s:User_autoread)
            set autoread
            call netrw#LocalBrowseCheck( substitute(fnamemodify(b:netrw_curdir, ':p:h:h'), '/\=$', '/', ''))
            set noautoread
         else
            call netrw#LocalBrowseCheck( substitute(fnamemodify(b:netrw_curdir, ':p:h:h'), '/\=$', '/', ''))
         endif
      else
         if !(s:User_autoread)
            set autoread
            Explore
            set noautoread
         else
            Explore
         endif
      endif
      call search('^' . EscapeRegex(l:currentFilename) . '\*\=$')
      call AddToPathList(l:currentFilename)
      if (&scrolloff =~# '0')
         normal zz
      endif
      normal C
   endif
   if exists('g:cvsnetrwIntegration')
      call UpdateCVSHilighting()
   endif
endfunction

"  SmartInspect <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Explores to file or dir under cursor, centers the screen and saves
"          the choice so we can remember it next time we're here.
function! SmartInspect()
   " TODO: Brakes when it tries to edit a file with and unescaped '%' in the name
   " Grabs line up to the first tab
   let file = matchstr(getline('.'), '^[^\t]*')
   call AddToPathList(file)
   call SyncDirs()

   if (file =~ '/$')
      exec "call netrw#LocalBrowseCheck('". <SID>ExpandDir(file, 1). "')"
      if (&scrolloff =~# '0')
         normal zz
      endif
      if exists('g:cvsnetrwIntegration')
         call UpdateCVSHilighting()
      endif
      call RememberLocation()
      normal C
   else
      if (file =~ '\(\.vba\)\|\(.vmb\)$')
         let choice = input("Source Vimball? y/n (no to edit)", "")
         if (choice =~ '^y')
            exe "source ". file
         else
            exe "edit ". fnamemodify(file, ":p")
         endif
      else
         exe "edit ". fnamemodify(file, ":p")
      endif
   endif
endfunction

"  ManualExplore ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Jumps to a directory directly
"    input - dir [String] The directory to jump to
function! ManualExplore(dir)
   let myDir = <SID>ExpandDir(a:dir, 1)
   if isdirectory(myDir)
      call netrw#LocalBrowseCheck(myDir)
   else
      call <SID>EchoError("Not a directory")
   endif
endfunction

function! SyncDirs()
   if (&ft == 'netrw')
      exe "cd " . b:netrw_curdir
   else
      let b:netrw_curdir = expand('%:p:h')
      exe "cd " . expand('%:p:h')
   endif
endfunction

"  AddToPathList ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Adds file to remembered paths file so we can remember that decision
"          next time we're here in netrw.
function! AddToPathList(file)
   let paths = readfile(g:vimpathmemFile)
   let mycwd = b:netrw_curdir
   let idx = 0
   for line in paths
      if (mycwd == substitute(line, '\(.*\)\@<= | .*', '', ''))
         call remove(paths, idx)
         break
      endif
      let idx += 1
   endfor
   call insert(paths, mycwd . ' | ' . a:file)
   while (len(paths) > s:netrw_pathmemNum)
      call remove(paths, -1)
      " remove the last index to keep the list no longer than s:netrw_pathmemNum
   endwhile
   call writefile(paths, g:vimpathmemFile)
endfunction

"  RememberLocation <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Check list to see if we've made a choice at this path before. If we
"          have, then point to it.
function! RememberLocation()
   for line in readfile(g:vimpathmemFile)
      let path = substitute(line, '\(.*\)\@<= | .*', '', '')
      let file = substitute(line, '.* | \(.*\)\@=', '', '')
      if (b:netrw_curdir == path)
         call search('^' . file . '$')
         break
      endif
   endfor
endfunction

"  CheckForPathMem ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Initialize file and variables for path memory.
function! CheckForPathMem()
   if !filereadable(g:vimpathmemFile)
      " If there is no file, then create one"
      if !isdirectory($HOME.'/vimfiles')
         call mkdir($HOME.'/vimfiles')
      endif
      call writefile([], g:vimpathmemFile)
   endif
endfunction

"  Remap_netrw ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: When entering a netrw buffer, remap these keys so we can have more
"          control over netrw.
function! Remap_netrw()
   nnoremap <buffer> -    :call SmartExplore('netrw')<CR>
   nnoremap <buffer> <CR> :call SmartInspect()<CR>
   nnoremap <buffer> X    :call ExecuteRecognizedFile()<CR>
   nnoremap <buffer> dd   :call DirDiff()<CR>
   nnoremap <buffer> dld  :call DirDiff(1)<CR>
   nnoremap <buffer> /    :call DirFind()<CR>
   nmap     <buffer> n    /<UP><CR>
   if (exists('g:cvsnetrwIntegration'))
      nnoremap <buffer> u :call RecursiveUpdate('./'.expand('<cWORD>'))<CR>
   endif
   call timer_start(1, 'Remap_netrwAdditionalOptions')
endfunction

"  Remap_netrwAdditionalOptions <><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Netrw sets a lot of its own options so if we do them immediately
"          they just get reset. Putting them on a timer allows us to set them
"          after netrw and claim the last word.
function! Remap_netrwAdditionalOptions(timer)
   "set buftype=nofile
endfunction

"  DirFind ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Uses search like syntax to jump to a file in netrw. Adds file
"          completion and doesn't pollute the search register.
"    input   - void
"    returns - void
function! DirFind()
   if (&ft == 'netrw')
      " Only works in netrw
      let usr = input("/", "", "file")
      call search(usr)
   endif
endfunction

"  EscapeRegex ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Backslash escapes the characters for a "magic mode" regex. Returns
"          escaped string.
function! EscapeRegex(input)
   return escape(a:input, '\^$.*~[&')
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

"<< End of netrw extension plugin <><><><><><><><><><><><><><><><><><><><><><><>
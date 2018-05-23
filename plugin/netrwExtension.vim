" @Tracked
" Netrw Extension Plugin
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 05/23/2018 10:42 AM
let s:Version = 1.62

" Anti-inclusion guard and version
if (exists("g:loaded_netwExtension") && (g:loaded_netwExtension >= s:Version))
   finish
endif
let g:loaded_netwExtension = s:Version

let g:vimpathmemFile = $HOME.'/vimfiles/.vimpathmem'

let s:User_autoread = &autoread

command! -nargs=1 -complete=dir Goto :call <SID>ManualExplore('<args>')
" Allows to you jump to any directory without having to get there through netrw

nnoremap - :call <SID>SmartExplore('file')<CR>
" Press minus to bring up File explorer

let s:netrw_pathmemNum = 200
" Number of paths to remember when navigating using netrw

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
   autocmd VimEnter     * let g:netrw_first = 1
   autocmd VimEnter     * call <SID>CheckForPathMem()
   autocmd filetype netrw call <SID>Remap_netrw()
augroup END
endif

" SmartExplore ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Opens explorer pointing at file or dir we just came out of.
"     input   - origin: [string] 'file' or 'netrw' based on where we started
"     returns - void
function! s:SmartExplore(origin)
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
   if (g:netrw_first && expand('%') == '')
      exe "cd " . g:netrw_startingDir
   else
      exe "cd " . expand("%:p:h")
   endif
   let g:netrw_first = 0
   "  If empty document then don't bother
   if (line('$') == 1 && getline(1) == '')
      if !(s:User_autoread)
         set autoread
         Explore
         set noautoread
      else
         Explore
      endif
      call s:RememberLocation()
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
      call s:SyncDirs()
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
      call search('^' . s:EscapeRegex(l:currentFilename) . '\*\=$')
      call s:AddToPathList(l:currentFilename)
      if (&scrolloff =~# '0')
         normal zz
      endif
      normal C
   endif
   if exists('g:loaded_cvsnetrwIntegration')
      call UpdateCVSHilighting()
   endif
endfunction

"  SmartInspect <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Explores to file or dir under cursor, centers the screen and saves
"          the choice so we can remember it next time we're here.
function! s:SmartInspect()
   " Grabs line up to the first tab
   let file = matchstr(getline('.'), '^[^\t]*')
   call s:AddToPathList(file)
   call s:SyncDirs()

   if (file =~ '/$')
      exec "call netrw#LocalBrowseCheck('". <SID>ExpandDir(file, 1). "')"
      if (&scrolloff =~# '0')
         normal zz
      endif
      if exists('g:loaded_cvsnetrwIntegration')
         call UpdateCVSHilighting()
      endif
      call s:RememberLocation()
      normal C
   else
      let file = substitute(file, '\*', '', 'g')
      if (file =~ '\(\.vba\)\|\(.vmb\)$')
         let choice = input("Source Vimball? y/n (no to edit)", "")
         if (choice =~ '^y')
            exe "source ". file
         else
            exe "edit ". fnameescape(fnamemodify(file, ":p"))
         endif
      else
         exe "edit ". fnameescape(fnamemodify(file, ":p"))
      endif
   endif
endfunction

"  ManualExplore ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Jumps to a directory directly
"    input - dir [String] The directory to jump to
function! s:ManualExplore(dir)
   let myDir = <SID>ExpandDir(a:dir, 1)
   if isdirectory(myDir)
      call netrw#LocalBrowseCheck(myDir)
   else
      call <SID>EchoError("Not a directory")
   endif
endfunction

function! s:SyncDirs()
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
function! s:AddToPathList(file)
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
function! s:RememberLocation()
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
function! s:CheckForPathMem()
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
function! s:Remap_netrw()
   exe "nnoremap <buffer> -    :call <SID>SmartExplore('netrw')<CR>"
   exe "nnoremap <buffer> <CR> :call <SID>SmartInspect()<CR>"
   exe "nnoremap <buffer> X    :call ExecuteRecognizedFile()<CR>"
   if (exists('g:loaded_dirDiffPlugin'))
      exe "nnoremap <buffer> dd   :call dirDiff#DirDiff()<CR>"
      exe "nnoremap <buffer> dld  :call dirDiff#DirDiff(1)<CR>"
   endif
   exe "nnoremap <buffer> /    :call <SID>DirFind()<CR>"
   exe "nmap     <buffer> n    /<UP><CR>"
   "call timer_start(1, '<SID>Remap_netrwAdditionalOptions')
endfunction

"  Remap_netrwAdditionalOptions <><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Netrw sets a lot of its own options so if we do them immediately
"          they just get reset. Putting them on a timer allows us to set them
"          after netrw and claim the last word.
function! s:Remap_netrwAdditionalOptions(timer)
   "set buftype=nofile
endfunction

"  DirFind ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Uses search like syntax to jump to a file in netrw. Adds file
"          completion and doesn't pollute the search register.
"    input   - void
"    returns - void
function! s:DirFind()
   if (&ft == 'netrw')
      " Only works in netrw
      let usr = input("/", "", "file")
      call search(usr)
   endif
endfunction

"  EscapeRegex ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Backslash escapes the characters for a "magic mode" regex. Returns
"          escaped string.
function! s:EscapeRegex(input)
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

" The MIT License (MIT)
"
" Copyright © 2018 Warren Terrall
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
"<< End of netrw extension plugin <><><><><><><><><><><><><><><><><><><><><><><>
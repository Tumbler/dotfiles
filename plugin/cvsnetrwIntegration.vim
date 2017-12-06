"@Tracked
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 12/16/2016 01:13 PM
" Version: 2.3

" Note: This plugin is merely an extension to the "cvsmenu" plugin. It will
"   not work without it! You can find it here:
"   http://www.vim.org/scripts/script.php?script_id=58
" TODO: Colors might be taking too much time. See if we can make that any better.
" TODO: Community plugin standards
" TODO: EchoError
" TODO: Cach hilighting for faster response?? (Like I do in dirDiff)

let g:cvsnetrwIntegration = 1

if !isdirectory($HOME.'/vimfiles/cvs')
   call mkdir($HOME.'/vimfiles/cvs')
endif
" Makes sure that our location for cvs tracking files exists

autocmd BufWritePost * call CVSCheckForUpdates(1)
autocmd BufCreate * if (&filetype == 'netrw') | call UpdateCVSHilighting() | endif

" TODO: This is cool but has a lot of problems. Need to rethink....
autocmd QuitPre * if (winnr('$') == 2) | wincmd w | if (expand("%:e")=="dif") | quit | else | wincmd w | endif | endif

nnoremap <A-D> :call DiffWithCVS()<CR>
nnoremap <A-C> :call CommitWithCVS()<CR>
nnoremap <A-A> :call AddWithCVS()<CR>
nnoremap <A-U> :call UpdateWithCVS()<CR>
nnoremap <A--> :call StartCheck()<CR>
nnoremap <A-_> :call StartCheck(1)<CR>

command! CVSCommit :call CommitWithCVS()
command! CVSAdd    :call AddWithCVS()
command! CVSUpdate :call UpdateWithCVS()


let s:CVSTMPstatusPath = $HOME.'/vimfiles/cvs'
let s:CVSstatusPath = $HOME.'/vimfiles/cvs'

" ReturnCVSstatusFile <><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Generates appropriate unique file names using the path of the dir.
"     input  - [string] The full path of the directory that the file revised in.
"              [string] The type of file we want to generate (tmp or cvs).
"    returns - [string] The name of the unique file name.
function! ReturnCVSstatusFile(inputDir, type)
   if (a:type == 'cvs')
      let extension = '.vimcvs'
   elseif (a:type == 'tmp')
      let extension = '.vimcvstmp'
   endif
   let currentDir = ""
   if isdirectory(a:inputDir)
      let currentDir = fnamemodify(a:inputDir, ':p')
   else
      return ""
   endif
   let currentDir = substitute(currentDir, '/\|/\|:', '%', 'g')
   return s:CVSstatusPath.'/'.currentDir.extension
endfunction

" CVSstatusFileExists <><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Checks to see if cvs file for the corresponding directory exists.
"     input   - [string] The directory to check for.
"               [string] The type of file we want to check for (Tmp or cvs).
"     returns - [bool] True if file exists, false otherwise.
function! CVSstatusFileExists(inputDir, type)
   if (a:type == 'cvs')
      let extension = '.vimcvs'
   elseif (a:type == 'tmp')
      let extension = '.vimcvstmp'
   endif
   let checkDir = fnamemodify(a:inputDir, ':p')
   let checkFile = substitute(checkDir, '/\|/\|:', '%', 'g')
   let checkFile = s:CVSstatusPath.'/'.checkFile.extension

   if filereadable(checkFile)
      return 1
   else
      return 0
   endif
endfunction

" CVSCheckForUpdates ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Calls cvs throug the command line to check on the satus of the files
"          in the current directory.
"     input: [bool] True: runs completely in the background, but has to be
"                   manually updated when complete. False: runs in the
"                   foreground but will automagically update colors when done.
"     returns: void
function! CVSCheckForUpdates(background)
   if (&ft == 'netrw')
      exe "cd " . fnameescape(b:netrw_curdir)
   else
      exe "cd " . fnameescape(expand('%:p:h'))
   endif
   if isdirectory('./CVS/')
      if (a:background)
         exe "silent !start /b cmd /c cvs status -lq > ".substitute(ReturnCVSstatusFile('.', 'tmp'),'%','\\%','g')." & echo \">>END<<\">>".substitute(ReturnCVSstatusFile('.', 'tmp'),'%','\\%','g')
      else
         exe "silent!! cvs status -lq > ".substitute(ReturnCVSstatusFile('.', 'cvs'), '%', '\\%', 'g')
      end
   endif
endfunction

" UpdateCVSHilighting <><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Checks a directory for any exsisting cvs files and updates the
"          highlighting if possible.
"     input   - void
"     returns - void
function! UpdateCVSHilighting()
   if (&ft == 'netrw')
      " Only works in netrw
      let dirModified = 0
      let fileModified = 0
      let cvsDirStatus = []
      let innerModSave = ''

      exe "cd " . fnameescape(b:netrw_curdir)

      if (&filetype == 'netrw')
         let i = 3
         " Skip ../ and ./
         while (i <= line('$'))
            let currentLine = getline(i)
            " Check if we're looking at a directory
            if (currentLine =~ '.*/$')
               if (CVSstatusFileExists('./'.currentLine, 'cvs'))
                  let innerMod = readfile(ReturnCVSstatusFile('./'.currentLine, 'cvs'), '', 1)
                  if (len(innerMod) > 0 && innerMod[0] =~ '>>MOD<<')
                     " If innerMod[0] has a shorter distance to a modfied file
                     " record the shorter one.
                     if (len(innerMod[0]) < len(innerModSave) || innerModSave == '')
                        let innerModSave = innerMod[0]
                     endif
                     let strippedDir = substitute(currentLine, '\/$', '', '')
                     exe "syn match modifiedDir '" . strippedDir . "\\(\\/\\)\\@='"
                     exe "syn match postDir '\\(" . strippedDir . "\\)\\@<=\\/'"
                     let dirModified = 1
                  endif
               endif
            else
               break
               " Dirs are always first, so once we've found something that isn't
               "   a dir, we're done.
            endif
            let i += 1
         endwhile

         if (CVSstatusFileExists('.', 'cvs') || CVSstatusFileExists('.', 'tmp'))
            " If this dir is tracked by CVS then do some special highlighting
            let ready = 0
            if (CVSstatusFileExists('.', 'tmp'))
               let tmpRead = readfile(ReturnCVSstatusFile('.', 'tmp'))
               if (!empty(tmpRead) && tmpRead[-1] =~ '>>END<<')
                  let ready = 1
               endif
            endif
            if ready
               call writefile(tmpRead, ReturnCVSstatusFile('.', 'cvs'))
               let cvsDirStatus = copy(tmpRead)
               call delete(ReturnCVSstatusFile('.', 'tmp'))
            elseif (CVSstatusFileExists('.', 'cvs'))
               let cvsDirStatus = readfile(ReturnCVSstatusFile('.', 'cvs'))
            endif
            for line in cvsDirStatus
               if (line =~ 'File:.*Status:')
                  let fileMatches = matchlist(line, '\(File:\s\+\)\@<=[-a-zA-Z0-9._]\+\(\s\+Status:.*\)\@=')
                  let statusMatches = matchlist(line, '\(Status:\s\+\)\@<=[- a-zA-Z]\+$')
                  let cvsFile = ""
                  let cvsStatus = ""
                  if len(fileMatches) > 0
                     let cvsFile = fileMatches[0]
                  endif
                  if len(statusMatches) > 0
                     let cvsStatus = statusMatches[0]
                  endif
                  if (cvsStatus =~ 'Up-to-date\|Needs Patch')
                     exe "syn match uptodate '" . cvsFile . "\\*\\=$'"
                  elseif (cvsStatus =~ 'Locally.*\|Needs Merge')
                     exe "syn match modified '" . cvsFile . "\\*\\=$'"
                     if (line !~ '.*mc[pw]')
                        let fileModified = 1
                     endif
                  elseif (cvsStatus =~ 'File had conflicts on merge\|Unresolved Conflict')
                     exe "syn match conflict '" . cvsFile . "\\*\\=$'"
                     if (line !~ '.*mc[pw]')
                        let fileModified = 1
                     endif
                  endif
               elseif (line =~ '?')
                  let fileMatches = matchlist(line, '\(?\s\+\)\@<=[-a-zA-z0-9._]\+')
                  if len(fileMatches) > 0
                     let cvsFile = fileMatches[0]
                     exe "syn match unknown '" . cvsFile . "\\*\\=$'"
                  endif
               endif
            endfor
         else
            " If the folder isn't tracked but has a CVS directory in it then
            " add it to the list.
            "call CVSCheckForUpdates(1)
         endif
         hi uptodate    cterm=NONE ctermbg=bg ctermfg=120 gui=NONE guibg=bg guifg=palegreen
         hi modified    cterm=NONE ctermbg=bg ctermfg=173 gui=NONE guibg=bg guifg=peru
         hi modifiedDir cterm=NONE ctermbg=236 ctermfg=129 gui=NONE guibg=bg guifg=Purple
         hi postDir     cterm=NONE ctermbg=bg ctermfg=120 gui=NONE guibg=bg guifg=palegreen
         hi unknown     cterm=NONE ctermbg=236 ctermfg=30 gui=NONE guibg=bg guifg=darkcyan
         hi conflict    cterm=NONE ctermbg=196 ctermfg=231 gui=NONE guibg=red guifg=black
         if (getcwd() !~ 'C:\\$\|C:\/$')
            " Don't try to save a file to root
            if (dirModified || fileModified)
               if (empty(cvsDirStatus) || cvsDirStatus[0] !~ '>>MOD<<')
                  if (fileModified || len(cvsDirStatus) > 1)
                     call insert(cvsDirStatus, ">>MOD<<")
                  else
                     if (innerModSave =~ '>>MOD<<\.\=$')
                        call insert(cvsDirStatus, innerModSave . '.')
                     else
                        return
                        " Don't write the file if we've fallen too far from the tree
                     endif
                  endif
                  call writefile(cvsDirStatus, ReturnCVSstatusFile('.', 'cvs'))
               endif
            elseif (len(cvsDirStatus) == 1 && cvsDirStatus[0] =~ ">>MOD<<")
               call delete(ReturnCVSstatusFile('.', 'cvs'))
            elseif (len(cvsDirStatus) > 1 && cvsDirStatus[0] =~ ">>MOD<<")
               call remove(cvsDirStatus, 0)
               call writefile(cvsDirStatus, ReturnCVSstatusFile('.', 'cvs'))
            endif
         endif
      endif
   endif
endfunction

"function! RecursiveUpdate(folder)
   "if (ft == 'netrw')
      "" Only works in netrw
      "let currentFolder = fnamemodify(a:folder, ':p')
"
      "if (isdirectory(currentFolder) && isdirectory(currentFolder.'/CVS/'))
         "let directories = []
         "for item in split(globpath(currentFolder, '*'), '\n')
            "if (isdirectory(item))
               "call add(directories, item)
               "" How deep does the rabbit hole go?
               "call RecursiveUpdate(item)
            "else
               "" Not a directory - Base case
            "endif
         "endfor
"
         "exe 'cd ' . currentFolder
         "call CVSUpdateFile(directories)
      "endif
   "endif
"endfunction
"
"function! CVSUpdateFile(directories)
   "let modified = 0
   "for dir in a:directories
      "if (filereadable(dir . s:CVSstatusFile) && readfile(dir . s:CVSstatusFile)[0] =~ ">>MOD<<")
         "let modified = 1
         "break
      "endif
   "endfor
   "exe "silent!! cvs status -lq > .".s:CVSstatusFile
   "let temp = readfile(".".s:CVSstatusFile)
   "for line in temp
      "if (line =~ 'modified\|needs merge\|conflict')
         "let modified = 1
         "break
      "endif
   "endfor
   "if (modified)
      "call insert(temp, ">>MOD<<")
      "call writefile(temp, '.'.s:CVSstatusFile)
   "endif
"endfunction

" DiffWithCVS <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Fetches CVS's last checked in version of the current file and diffs
"          it with the current file.
"     input   - void
"     returns - void
function! DiffWithCVS()
   if (! &diff && winnr('$') == 1)
      set visualbell
      if (&filetype == 'netrw')
         exe "normal \<CR>"
         lclose
         cclose
         call CVSdiff()
         exe "normal! \<C-W>L"
         normal gg]c[c
      else
         call CVSdiff()
         exe "normal! \<C-W>L"
      endif
      set scrolloff=9999

      if (winnr('$') != 1)
         " If there was a problem with CVSdiff() (Such as the file being a new
         " entry) then a new window will not have opened.
         exe "au FileChangedShell <buffer=".bufnr('#')."> echom \"Repository's version on left, your version on right\""
      endif
      set novisualbell
   else
      call EchoError("Please close diff or other window first!")
   endif
endfunction

" CommitWithCVS <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Askes for a commit messege and then commits the current file to CVS
"     input   - void
"     returns - void
function! CommitWithCVS()
   if (&filetype == 'netrw')
      let file = expand('<cWORD>')
      call CVScommit(file)
      call CVSCheckForUpdates(0)
      call UpdateCVSHilighting()
      " Position cursor back on file
      exe "normal /" . file . "\rzz"
   else
      let winnr = winnr()
      call CVScommit()
      call CVSCheckForUpdates(1)
      while (winnr != winnr())
         wincmd w
      endwhile
   endif
endfunction

function! UpdateWithCVS()
   if (&filetype == 'netrw')
      let file = expand('<cWORD>')
      call CVSupdate(file)
      call CVSCheckForUpdates(0)
      call UpdateCVSHilighting()
      " Position cursor back on file
      exe "normal /" . file . "\rzz"
   else
      call CVSupdate()
      call CVSCheckForUpdates(1)
   endif
endfunction

" AddWithCVS ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Adds file to current CVS repository.
"     input   - void
"     returns - void
function! AddWithCVS()
   if (&filetype == 'netrw')
      let file = expand('<cWORD>')
      call CVSadd(file)
      call CVSCheckForUpdates(0)
      call UpdateCVSHilighting()
      " Position cursor back on file
      exe "normal /" . file . "\rzz"
   else
      call CVSadd()
      call CVSCheckForUpdates(1)
   endif
endfunction

" StartCheck ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: starts a check for hilighting when in netrw.
"     input   - [bool](optional) If exists, will force update even if files
"               already exist.
"     returns - void
function! StartCheck(...)
   if (&filetype == 'netrw')
      exe "cd " . fnameescape(b:netrw_curdir)
      if !CVSstatusFileExists('.', 'tmp') && !CVSstatusFileExists('.', 'cvs') || a:0 > 0
         call CVSCheckForUpdates(0)
      endif
      call UpdateCVSHilighting()
   else
      call CVSCheckForUpdates(0)
   endif
endfunction
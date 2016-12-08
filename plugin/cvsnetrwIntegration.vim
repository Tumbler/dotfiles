"@Tracked
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 12/07/2016 04:33 PM
" Version: 2.1

" Note: This plugin is merely an extension to the "cvsmenu" plugin. It will
"   not work without it! You can find it here:
"   http://www.vim.org/scripts/script.php?script_id=58

let g:cvsnetrwIntegration = 1

set wildignore+=.CVSfolderStatus
" Don't generally want this file to be inspected. It should just work in the
"   background.
if !isdirectory($HOME.'/vimfiles/cvs')
   call mkdir($HOME.'/vimfiles/cvs')
endif
" Makes sure that our location for cvs tracking files exists

autocmd BufWritePost * call CVSCheckForUpdates(1)
autocmd BufCreate * if (&filetype == 'netrw') | call UpdateCVSHilighting() | endif

nnoremap <A-D> :call DiffWithCVS()<CR>
nnoremap <A-C> :call CommitWithCVS()<CR>
nnoremap <A-A> :call AddWithCVS()<CR>
nnoremap <A--> :call StartCheck()<CR>
nnoremap <A-_> :call StartCheck(1)<CR>

command! CVSCommit :call CommitWithCVS()
command! CVSAdd    :call AddWithCVS()

let s:CVSTMPstatusFile = '/.CVSfolderStatusTMP'
let s:CVSstatusFile = '/.CVSfolderStatus'

let s:CVSTMPstatusPath = $HOME.'/vimfiles/cvs'
let s:CVSstatusPath = $HOME.'/vimfiles/cvs'

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
         while (i < line('$'))
            let currentLine = getline(i)
            " Check if we're looking at a directory
            if (currentLine =~ '.*/$')
               if (CVSstatusFileExists('./'.currentLine, 'cvs'))
                  let innerMod = readfile(ReturnCVSstatusFile('./'.currentLine, 'cvs'), '', 1)
                  if (innerMod[0] =~ '>>MOD<<')
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
            call CVSCheckForUpdates(1)
         endif
         hi link uptodate     Identifier
         hi link modified     PreProc
         hi link modifiedDir  SpecialKey
         hi link postDir      Identifier
         hi link unknown      Comment
         hi link conflict     ERROR
         syn match cvsfolderstatus '\.CVSfolderStatus\(TMP\)\='
         hi link cvsfolderstatus Ignore
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

function! DiffWithCVS()
   if (! &diff && winnr('$') == 1)
      set visualbell
      if (&filetype == 'netrw')
         normal 
         lclose
         cclose
         call CVSdiff()
         normal L
         normal gg]c[c
      else
         call CVSdiff()
         normal L
      endif
      set scrolloff=9999

      exe "au FileChangedShell <buffer=".bufnr('#')."> echom \"Repository's version on left, your version on right\""
      set novisualbell
   else
      call EchoError("Please close diff or other window first!")
   endif
endfunction

function! CommitWithCVS()
   if (&filetype == 'netrw')
      let file = expand('<cWORD>')
      call CVScommit(file)
      call CVSCheckForUpdates(0)
      call UpdateCVSHilighting()
      " Position cursor back on file
      exe "normal /" . file . "\rzz"
   else
      call CVScommit()
      call CVSCheckForUpdates(1)
   endif
endfunction

function! AddWithCVS()
   if (&filetype == 'netrw')
      call CVSadd(expand('<cWORD>'))
      call CVSCheckForUpdates(0)
      call UpdateCVSHilighting()
   else
      call CVSadd()
      call CVSCheckForUpdates(1)
   endif
endfunction

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

" @Tracked
" Directory Differ Plugin
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 05/23/2018 10:38 AM
let s:Version = 2.07

" Anti-inclusion guard and version
if (exists("g:loaded_dirDiffPlugin") && (g:loaded_dirDiffPlugin >= s:Version))
   finish
endif
let g:loaded_dirDiffPlugin = s:Version

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

" The bulk of this plugin is located in autoload/dirDiff.vim

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
"<< End of dirDiff plugin <><><><><><><><><><><><><><><><><><><><><><><><><><><>
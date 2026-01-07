" @Tracked
" Vim Poject Manager plugin
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 01/07/2026 09:21 AM
let s:Version = 2.22

if (exists("g:loaded_projectManager") && (g:loaded_projectManager >= s:Version))
   finish
endif
let g:loaded_projectManager = s:Version
let projectManager_DirSearchActive = 0

let s:ProjectManagerCommands = ["activate", "add", "blarg", "delete", "exclude", "exit", "help", "ls", "new", "newrel", "optional", "main", "quit", "remove", "rename", "select", "view"]
   " A list of commands that the ExecuteCommand() function can handle
let s:projectFile = $HOME.'/vimfiles/.projects'
   " The file that stores the project information across multiple sessions
let s:activeProject = ""
   " The project that was last interacted with

if has("autocmd")
augroup ProjectManager
   au!
   autocmd VimEnter * call <SID>LoadProject()
augroup END
endif

try
   hi projectManagerArrows   cterm=BOLD ctermbg=bg ctermfg=28  gui=BOLD guibg=bg guifg=Yellow
   hi projectManagerDirs     cterm=NONE ctermbg=bg ctermfg=120 gui=NONE guibg=bg guifg=palegreen
   hi projectManagerOptional cterm=NONE ctermbg=bg ctermfg=116 gui=NONE guibg=bg guifg=SkyBlue
   hi projectManagerExcludes cterm=NONE ctermbg=bg ctermfg=173 gui=NONE guibg=bg guifg=peru
catch /^Vim\%((\a\+)\)\=:E420/
   " BG hasn't been set, we'll have to do without. (see :h E420)
   hi projectManagerArrows   cterm=BOLD            ctermfg=28  gui=BOLD          guifg=Yellow
   hi projectManagerDirs     cterm=NONE            ctermfg=120 gui=NONE          guifg=palegreen
   hi projectManagerOptional cterm=NONE            ctermfg=116 gui=NONE          guifg=SkyBlue
   hi projectManagerExcludes cterm=NONE            ctermfg=173 gui=NONE          guifg=peru
endtry

command! Proj call <SID>Project()
" Brings up the Project Manager, um... Manager...
command! -nargs=1 -complete=custom,<SID>ProjectCompletion ProjSelect call <SID>ExecuteCommand('select', ['<args>'])
" Selects a project so you don't have to go into the manager
command! -nargs=1 -complete=tag DirectorySearch :call <SID>DirSearch('<args>')
" Brings up the Directory Search Prompt (See DirSearch)
command! -nargs=1 -complete=tag ProjectGrep :call <SID>ProjectVimGrep('<args>', [], 0)
" Similar to DirectorySearch but without as much pre-processing. (Use this in mappings)
command! -nargs=1 -complete=tag Tag :call <SID>Tag('<args>')
" Just does a :tag, but makes sure to setlocal tags= first.
cnoreabbrev <expr> tag (getcmdtype() == ':' && getcmdline() =~ '^tag$')? 'Tag' : 'tag'
" Makes regular tag calls use our version of tag.
command! -nargs=1 -complete=custom,<SID>ProjectFileCompletion Edit :call <SID>Edit('<args>')
" Just does an :edit, but makes sure to check the whole project
cnoreabbrev <expr> e (getcmdtype() == ':' && getcmdline() =~ '^e$')? 'Edit' : 'e'
cnoreabbrev <expr> E (getcmdtype() == ':' && getcmdline() =~ '^e$')? 'Edit' : 'e'
cnoreabbrev <expr> edit (getcmdtype() == ':' && getcmdline() =~ '^edit$')? 'Edit' : 'edit'
" Makes regular edit calls use our version of Edit.

" Allows you to set your own key combo if you want to
if (exists('g:projectManager_DirSearchKeyCombo'))
   exe 'nnoremap '.g:projectManager_DirSearchKeyCombo.' :call <SID>StartDirSearch()<CR>'
else
   nnoremap <A-d> :call <SID>StartDirSearch()<CR>
endif
" Brings up the Directory Search Prompt (See DirSearch)

" Allows you to set your own key combo if you want to
if (exists('g:projectManager_TagKeyCombo'))
   exe 'nnoremap '.g:projectManager_TagKeyCombo.' :call <SID>TraverseCtag()<CR>'
else
   nnoremap <C-]> :call <SID>TraverseCtag()<CR>
endif
" Overrides the default mapping for go to tag under cursor

if (exists('g:projectManager_GenTagKeyCombo'))
   exe 'nnoremap '.g:projectManager_GenTagKeyCombo.' :call <SID>GenerateCTags()<CR>'
else
   nnoremap <A-<> :call <SID>GenerateCTags()<CR>
endif
" Runs ctags on current project

let s:maxSplits = 2
if (exists('g:projectManger_MaxSplits'))
   let s:maxSplits = g:projectManger_MaxSplits
endif

" ProjectManager_ReturnProject <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Returns the dirs in a project as list
"     input   - input: [string] A project name or directory as a string
"     returns - [[project{}, root]] a project is a structure defined as the following:
"                Project
"                   .type     " The character 'N' or 'R' (normal or relative)
"                   .dirs     " A list of directories that are in the project
"                   .optional " A list of directories that are in the project
"                                 but are optional
"                   .name     " The name and key of the project
"                   .excludes " A list of files to exclude from searches
"                and the absolute path to the root directory of the project as a
"                  string
"     NOTE: Left public on purpose. (Lets other plugins use projects)
function! ProjectManager_ReturnProject(input)
   if has_key(g:ProjectManager, a:input)
      " Try to match to a project name
      return [g:ProjectManager[a:input], '']
   else
      " Don't have a project called that, try to find a directory that matches
      let dirName = substitute(a:input, "\\", "/", "g")
      " Rectify Windows directory types
      let projectList = {}
      for key in keys(g:ProjectManager)
         for dir in copy(ProjectManager_ReturnProjectDirectories(key))
            if (dir == dirName)
               let currentFile = expand('%:t')
               let inExcludeFile = 0
               " Make sure we're not in an exclude file
               for exclude in copy(g:ProjectManager[key].excludes)
                  if (currentFile == fnamemodify(exclude, ':t'))
                     let inExcludeFile = 1
                  endif
               endfor
               if !(inExcludeFile)
                  let projectList[key] = g:ProjectManager[key]
               endif
               break
            endif
         endfor
      endfor
      " If no project is found, move on to relative projects
      if     len(projectList) == 1
         " If only one project is found, return it.
         let key = keys(projectList)[0]
         let s:activeProject = key
         return [g:ProjectManager[key], g:ProjectManager[key]["dirs"][0]]
      elseif len(projectList) > 1
         " If more than one is found, return the active project

         for project in keys(projectList)
            if (project == s:activeProject)
               return [g:ProjectManager[project], g:ProjectManager[project]["dirs"][0]]
            endif
         endfor
         " We have > 1 matches, but none of them are the current active
         "   project. Pick one at random and tell the user.
         let project = keys(projectList)[0]
         echo "Found multiple projects that match. Using " . project . "."
         let s:activeProject = project
         return [g:ProjectManager[project], g:ProjectManager[project]["dirs"][0]]
      endif
   endif
   " If everything else fails, try to match a relative project
   let originalDir = s:GetCWD()
   if (isdirectory(a:input))
      exe "cd ".a:input
   endif
   let RelativeMatch = 0
   let notInRootDir = 0
   let projects = {}
   let input = substitute(a:input, '/\=$', '/', '')
   for project in keys(g:ProjectManager)
      if (g:ProjectManager[project].type == 'R')
         if (input =~ project.'$')
            " Found inital match; flag for full check later
            let projects[project] = g:ProjectManager[project]
            let projects[project].keyMatch = '.'
         else
            for directory in (ProjectManager_ReturnProjectDirectories(project))[1:]
               " Strip out any leading "../"
               let restOfDir = matchstr(directory, '\(/\)\@<=[^.].*')
               if (input =~ restOfDir.'$')
                  " Found inital match; flag for full check later
                  let projects[project] = g:ProjectManager[project]
                  let projects[project].keyMatch = directory
                  break
               endif
            endfor
         endif
      endif
   endfor
   for project in keys(projects)
      let projects[project].root = s:ReturnAbsoluteRoot(projects[project], projects[project].keyMatch)
      if (projects[project].root != '')
         if (project == s:activeProject)
            " Project valid and is our active project, use this one!
            let key = keys(projects)[0]
            let s:activeProject = project
            let ProjectRoot = projects[project].root
            exe "cd ".originalDir
            return [g:ProjectManager[project], ProjectRoot]
         endif
      else
         " Not valid, it's out of the running
         call remove(projects, project)
      endif
   endfor
   if (len(projects) > 0)
      " At least one project was valid. Return the first one.
      let key = keys(projects)[0]
      let s:activeProject = key
      let ProjectRoot = projects[key].root
      exe "cd ".originalDir
      if (len(projects) > 1)
         echo "Found multiple projects that match. Using " . key . "."
      endif
      return [g:ProjectManager[key], ProjectRoot]
   endif

   exe "cd ".originalDir
   " No form of matching worked, return blank.
   return [{"type": '', "dirs":[], "optional":[], "name": '', "excludes":[]}, '']
endfunction

" ReturnAbsoluteRoot ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Finds out if the relative directory structure of the current project
"          is valid for our cwd.
"  returns: The absolute root path for valid, '' for invalid
function! s:ReturnAbsoluteRoot(project, match)
   if (a:project.type == "N")
      " Normal project. All dirs are already absolute.
      return project.dirs[0]
   elseif (a:project.type == "R")
      " Save for later
      let originalDir = s:GetCWD()

      " Find Root Directory
      if (a:match == '.')
         let root = fnamemodify('.', ':p:h')
      else
         let parents = matchstr(a:match, '\(\.\./\)\+')
         let numOfParents = len(split(parents, '/'))
         let restOfDir = matchstr(a:match, '\(/\)\@<=[^.].*')
         let numOfSpecifiedDirectories = len(split(restOfDir, '/'))
         let numOfDirectoriesInRoot = len(split(a:project.name, '/'))
         " Formula is as follows:
         "   (1) Go up a directory (Add a "../") for as many as you went down
         "       (number of specified directories in the list).
         "   (2) Go down a directory for as many times as we went up
         "       (number of "../" in path). Now we don't necessarily know the
         "       exact name of the dirs to go down to, so we start by filling
         "       them all with "*" to be expanded by glob() later.
         "   (3) Then, starting from the end, we replace each star by however
         "       many directories have been specified in the root of the
         "       project. (Hence number of stars minus the number of directories
         "       in the root) If there are any "*'s" left over, glob() will
         "       take care of them. If not, great! We have our full path!
         let pathToRootDir = repeat("../", numOfSpecifiedDirectories) .
                            \repeat("*/", numOfParents-numOfDirectoriesInRoot) .
                            \a:project.name
         let glob = glob(pathToRootDir,0,1)
         if (len(glob) > 0)
            let root = glob(pathToRootDir,0,1)[0]
            let root = fnamemodify(root, ':p:h')
         else
            " No valid path back to root, invalid Dir
            return ''
         endif
      endif

      " Check all directories from perspective of root
      exe "cd ".root
      for dir in a:project["dirs"]
         if !isdirectory(dir)
            exe "cd ".originalDir
            return ''
         endif
      endfor
      exe "cd ".originalDir

      " All dirs checked out.
      " Last check: Make sure we're not in an excluded file.
      let currentFile = expand('%:t')
      for exclude in a:project["excludes"]
         if (currentFile == fnamemodify(exclude, ':t'))
            return ''
         endif
      endfor

      " Everything checks out
      return root
   endif
endfunction

" ReturnProjectDirectories ><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Takes a project and returns all dirs and valid optional dirs.
"     input   - input: [string] A project name or directory
"     returns - All valid dirs from a project (including optional dirs)
"     NOTE: Left public on purpose. (Lets other plugins use projects)
function! ProjectManager_ReturnProjectDirectories(input)
   let project = copy(ProjectManager_ReturnProject(a:input)[0])
   let dirs = copy(project.dirs)
   for dir in project.optional
      if isdirectory(dir)
         call add(dirs, dir)
      endif
   endfor
   return dirs
endfunction

" Project <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: The "main function" of the project manager
"     input   - void
"     returns - void
function! s:Project()
   if !exists("g:ProjectManager")
      let g:ProjectManager = {}
   endif
   let choice = ""
   let track = 0
   " Change active project to current directory
   call ProjectManager_ReturnProject(s:GetCWD())
   call s:PrintProject("@||", 0)
   while(track != -1)
      let choice = input("\n(1) Print all projects\n" .
                         \ "(2) Add to a current project\n" .
                         \ "(3) Remove a project or directory from a project\n" .
                         \ "(4) Create a new absolute project\n" .
                         \ "(5) Create a new relative project\n" .
                         \ "(You can also just type commands. Type \"help\" for a list of commands)\n\n", "", "custom,". s:SID() ."CommandProjectHybridCompletion")
      let l:argumentlist = split(choice)
      if len(argumentlist) < 1
         echo "\n"
         continue
         "Don't parse anything if they just pressed enter
      endif
      let l:matchlist = s:ParseChoice(l:argumentlist[0], 1)
      if len(l:matchlist) == 1
         if count(s:ProjectManagerCommands, l:matchlist[0]) > 0
            let track = s:ExecuteCommand(l:matchlist[0], l:argumentlist[1:])
         elseif has_key(g:ProjectManager, l:matchlist[0])
            call s:PrintProject(l:matchlist[0], 0)
         else
            call s:EchoError("Parse Error!")
         endif
      elseif len(l:matchlist) > 1
         normal \<Esc>
      else
         if choice == "1"
            call s:PrintProject("@||", 0)
         elseif choice == "2"
            call s:PrintProject("@||", 0)
            call s:ExecuteCommand("add", [])
         elseif choice == "3"
            call s:ExecuteCommand("delete", [])
         elseif choice == "4"
            call s:ExecuteCommand("new", [])
         elseif choice == "5"
            call s:ExecuteCommand("newrel", [])
         endif
      endif
   endwhile
endfunction

" ParseChoice <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Finds commands or projects that user input matches. Exact matches
"          will take precedence. If there are multiple partial matches, a list
"          will be returned instead.
"     input   - choice: [string] User input to match to
"               commandFlag: [bool] False: won't take commands into account when
"                           matching
"     returns - [string[]] a list of matching commands or project names
function! s:ParseChoice(choice, commandFlag)
   let l:matches = []
   if a:commandFlag
      for word in s:ProjectManagerCommands
         if (word == a:choice)
            return [word]
         endif
      endfor
   endif
   for key in keys(g:ProjectManager)
      if (key == a:choice)
         return [key]
      endif
   endfor
   " Default to exact matches first
   if a:commandFlag
      for word in s:ProjectManagerCommands
         if (word =~ "^" . a:choice . ".*")
            call add(l:matches, word)
         endif
      endfor
   endif
   " Partial command matches have next precedence
   if len(l:matches) > 0
      return l:matches
   endif
   for key in keys(g:ProjectManager)
      if (key =~ "^" . a:choice . ".*")
         call add(l:matches, key)
      endif
   endfor
   " Partial project matches have last precedence
   return l:matches
endfunction

" FillProject <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Similar to ParseChoice, but only searches for projects and will
"          return a match only if there is exactly one match
"     input   - partialProject: [string] Typically user input to try to match to
"                             an existing project
"     returns - [string] either the matched project name or the original input
function! s:FillProject(partialProject)
   let project = a:partialProject
   let projectMatches = s:ParseChoice(project, 0)
   if len(projectMatches) == 1
      let project = projectMatches[0]
   endif
   return project
endfunction

" ExecuteCommand ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Executes any command from s:ProjectManagerCommands
"     input   - command: [string] Which command to execute
"               options: [string[]] list of strings with additional, optional
"                        command-line arguments determined by the context of
"                        the command
"     returns - [bool] True: a signal to exit the main loop
function! s:ExecuteCommand(command, options)
   " Note: I'm well aware that this function has a lot of duplicate code and
   " could be made to be many fewer lines. However, I tried converting it one
   " time, and the resulting code is incredibly unreadable. Therefore, for the
   " sake of readability (and my sanity) I've opted to leave it this way.
   let command = tolower(a:command)
   if     (command == "quit" || command == "exit") " ------------ quit
      call s:SaveProject()
      return -1

   elseif (command == "blarg")
      echo " and Gilgamesh!\n"
      return 0

   elseif (command == "help") " ------------ help
      call s:ClearScreen()
      echo "add      [project] [first_dir_to_add] ..."
      echo "    Add at 1 or more dirs to a project"
      echo "delete   [project] [first_dir_to_delete] ..."
      echo "    Deletes a project or directory from a project"
      echo "exclude  [project] [file_to_exclude] ..."
      echo "    Adds exclusion rule to project"
      echo "help"
      echo "    This help message"
      echo "main     [project] [dir_to_make_main]"
      echo "    Change the main dir in a project"
      echo "new      [project] [first_dir_to_add] ..."
      echo "    Create a new project and add dirs to it"
      echo "newrel   [project] [first_dir_to_add] ..."
      echo "    Create a new relative project and add dirs to it"
      echo "optional [project]"
      echo "    Change a directory to be optional"
      echo "remove   [project] [first_dir_to_remove] ..."
      echo "    Removes a project or directory from a project"
      echo "rename   [project] [new_name]"
      echo "    Renames a project"
      echo "view|ls  [project]"
      echo "    Prints a project"
      echo "quit|exit"
      echo "    Exit project manager"
      echo "\n"
      return 0

   elseif (command == "new") " ------------ new
      if len(a:options) == 0
         let project = input("\nWhat should the project be called?\n")
         if !has_key(g:ProjectManager, project)
            let g:ProjectManager[project] = {}
            let g:ProjectManager[project]["type"] = "N"
            let g:ProjectManager[project]["dirs"] = []
            let g:ProjectManager[project]["optional"] = []
            let g:ProjectManager[project]["excludes"] = []
            let s:activeProject = project
         else
            call s:EchoError(project . " already exists in project manager!")
            return 0
         endif
         call s:AddDirectoryInput(project, "N")
         call s:PrintProject(project, 0)
      elseif len(a:options) == 1
         let project = a:options[0]
         if !has_key(g:ProjectManager, project)
            let g:ProjectManager[project] = {}
            let g:ProjectManager[project]["type"] = "N"
            let g:ProjectManager[project]["name"] = project
            let g:ProjectManager[project]["dirs"] = []
            let g:ProjectManager[project]["optional"] = []
            let g:ProjectManager[project]["excludes"] = []
            let s:activeProject = project
         else
            call s:EchoError(project . " already exists in project manager!")
            return 0
         endif
         call s:AddDirectoryInput(project, "N")
         call s:PrintProject(project, 0)
      elseif len(a:options) > 1
         let project = a:options[0]
         if !has_key(g:ProjectManager, project)
            let g:ProjectManager[project] = {}
            let g:ProjectManager[project]["type"] = "N"
            let g:ProjectManager[project]["name"] = project
            let g:ProjectManager[project]["dirs"] = []
            let g:ProjectManager[project]["optional"] = []
            let g:ProjectManager[project]["excludes"] = []
            let s:activeProject = project
         else
            call s:EchoError(project . " already exists in project manager!")
            return 0
         endif
         for dir in a:options[1:]
            call s:AddDirectory(project, dir, "N", 0)
         endfor
      endif

   elseif (command == "newrel") " ------------ newrel
      if len(a:options) == 0
         let project = input("\nWhat is the main directory of the project?\n")
         if !has_key(g:ProjectManager, project)
            let project = substitute(project, '/\?$', '/', '')
            let g:ProjectManager[project] = {}
            let g:ProjectManager[project]["type"] = "R"
            let g:ProjectManager[project]["name"] = project
            let g:ProjectManager[project]["dirs"] = []
            let g:ProjectManager[project]["optional"] = []
            let g:ProjectManager[project]["excludes"] = []
            let s:activeProject = project
         else
            call s:EchoError(project . " already exists in project manager!")
            return 0
         endif
         call s:AddDirectory(project, '.', "R", 0)
         call s:AddDirectoryInput(project, "R")
         call s:PrintProject(project, 0)
      elseif len(a:options) == 1
         let project = a:options[0]
         if !has_key(g:ProjectManager, project)
            let project = substitute(project, '/\?$', '/', '')
            let g:ProjectManager[project] = {}
            let g:ProjectManager[project]["type"] = "R"
            let g:ProjectManager[project]["name"] = project
            let g:ProjectManager[project]["dirs"] = []
            let g:ProjectManager[project]["optional"] = []
            let g:ProjectManager[project]["excludes"] = []
            let s:activeProject = project
         else
            call s:EchoError(project . " already exists in project manager!")
            return 0
         endif
         call s:AddDirectory(project, '.', "R", 0)
         call s:AddDirectoryInput(project, "R")
         call s:PrintProject(project, 0)
      elseif len(a:options) > 1
         let project = a:options[0]
         if !has_key(g:ProjectManager, project)
            let project = substitute(project, '/\?$', '/', '')
            let g:ProjectManager[project] = {}
            let g:ProjectManager[project]["type"] = "R"
            let g:ProjectManager[project]["name"] = project
            let g:ProjectManager[project]["dirs"] = []
            let g:ProjectManager[project]["optional"] = []
            let g:ProjectManager[project]["excludes"] = []
            let s:activeProject = project
         else
            call s:EchoError(project . " already exists in project manager!")
            return 0
         endif
         call s:AddDirectory(project, '.', "R", 0)
         for dir in a:options[1:]
            call s:AddDirectory(project, dir, "R", 0)
         endfor
      endif

   elseif (command == "add") " ------------ add
      if len(a:options) == 0
         let project = s:GetProject()
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
            call s:AddDirectoryInput(project, g:ProjectManager[project].type)
         else
            call s:EchoError(project . " project does not exist! Did you mean new?\n\n")
            return 0
         endif
         call s:PrintProject(project, 0)
      elseif len(a:options) == 1
         let project = s:FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
            call s:ClearScreen()
            call s:AddDirectoryInput(project, g:ProjectManager[project].type)
         else
            call s:ClearScreen()
            call s:EchoError(project . " project does not exist! Did you mean new?")
            return 0
         endif
      elseif len(a:options) > 1
         let project = s:FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
            for dir in a:options[1:]
               call s:AddDirectory(project, dir, g:ProjectManager[project]["type"], 0)
            endfor
         else
            call s:ClearScreen()
            call s:EchoError(project . " project does not exist! Did you mean new?\n\n")
            return 0
         endif
         call s:PrintProject(project, 0)
      endif
      return 0

   elseif (command == "delete" || command == "remove") " ------------ delete/remove
      if len(a:options) == 0
         let choice = input("\nDo you want to delete a (1) project, or (2) a directory in a project? ")
         if choice == 1
            call s:PrintProject("@||", 2)
            let project = s:GetProject()
            if has_key(g:ProjectManager, project)
               echo "\n"
               echohl ERROR
               call inputsave()
               let choice = input("Deleting project " . project . ", Continue? (y/n) ")
               call inputrestore()
               echohl NONE
               if (choice =~ '\<ye\=s\=\>')
                  call remove(g:ProjectManager, project)
                  echo "\n"
                  echo project . " removed!\n\n"
                  if (s:activeProject == project)
                     let s:activeProject = ""
                  endif
               endif
            else
               call s:EchoError(project . " does not exist!")
            endif
         elseif choice == 2
            let project = s:GetProject()
            if has_key(g:ProjectManager, project)
               let s:activeProject = project
               call s:PrintProject(project, 1)
               let choice = input("Which directory? (#) ")
               while (choice > len(g:ProjectManager[project]["dirs"]) + len(g:ProjectManager[project]["excludes"]))
                  normal \<Esc>
                  let choice = input("Which directory? (#) ")
               endwhile
               echo "\n"
               let key = "dirs"
               if (choice > len(g:ProjectManager[project]["dirs"]))
                  let choice -= len(g:ProjectManager[project]["dirs"])
                  let key = "excludes"
               endif
               echo g:ProjectManager[project][key][choice-1] . " removed!"
               call remove(g:ProjectManager[project][key], choice - 1)
               call s:PrintProject(project, 0)
            else
               call s:EchoError(project . " does not exist!")
            endif
         endif
      elseif len(a:options) == 1
         let project = s:FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            echo "\n"
            echohl ERROR
            call inputsave()
            let choice = input("Deleting project " . project . ", Continue? (y/n) ")
            call inputrestore()
            echohl NONE
            if (choice =~ '\<ye\=s\=\>')
               call remove(g:ProjectManager, project)
               echo "\n"
               echo project . " removed!\n\n"
            endif
         else
            call s:EchoError(project . " does not exist!")
         endif
      elseif len(a:options) > 1
         let project = s:FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
            for dir in a:options[1:]
               if (g:ProjectManager[project].type == "N")
                  let safeDir = s:ExpandDir(dir, 1)
               else
                  let safeDir = dir
               endif
               if index(g:ProjectManager[project]["dirs"], safeDir)
                  call filter(g:ProjectManager[project]["dirs"], 'v:val !~ "' . safeDir . '"')
               else
                  call filter(g:ProjectManager[project]["excludes"], 'v:val !~ "' . fnamemodify(dir, ':p') . '"')
               endif
            endfor
            call s:ClearScreen()
            call s:PrintProject(project, 0)
         else
            call s:EchoError(project . " does not exist!")
         endif
      endif

   elseif (command == "view" || command == "ls") " ------------ view
      if len(a:options) == 0
         call s:PrintProject("@||", 0)
      elseif len(a:options) > 0
         let project = s:FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            call s:PrintProject(project, 0)
            let s:activeProject = project
         else
            call s:EchoError(project . " does not exist!")
         endif
      endif

   elseif (command == "rename") " ------------ rename
      if len(a:options) == 0
         let project = s:GetProject()
         if has_key(g:ProjectManager, project)
            let newProject = input("What's the new name?\n")
            if !has_key(g:ProjectManager, newProject)
               let g:ProjectManager[newProject] = deepcopy(g:ProjectManager[project])
               call remove(g:ProjectManager, project)
               echo "\n"
               echon project " renamed to "
               echon newProject
               let s:activeProject = newProject
            else
               call s:EchoError(newProject . " is already a project!")
            endif
         else
            call s:EchoError(project . " is not a valid project!")
         endif
      elseif len(a:options) == 1
         let project = s:FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            let newProject = input("What's the new name?\n")
            if !has_key(g:ProjectManager, newProject)
               let g:ProjectManager[newProject]["dirs"] = deepcopy(g:ProjectManager[project]["dirs"])
               call remove(g:ProjectManager, project)
               echo "\n"
               echon project " renamed to "
               echon newProject
               let s:activeProject = newProject
            else
               call s:EchoError(newProject . " is already a project!")
            endif
         else
            call s:EchoError(project . " is not a valid project!")
         endif
      elseif len(a:options) == 2
         let project = s:FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            let newProject = a:options[1]
            if !has_key(g:ProjectManager, newProject)
               let g:ProjectManager[newProject]["dirs"] = deepcopy(g:ProjectManager[project]["dirs"])
               call remove(g:ProjectManager, project)
               echo "\n"
               echon project " renamed to "
               echon newProject
               let s:activeProject = newProject
            else
               call s:EchoError(newProject . " is already a project!")
            endif
         else
            call s:EchoError(project . " is not a valid project!")
         endif
      endif

   elseif (command =~ 'select\|activate') " ----------- select
      if len(a:options) == 0
         let project = s:GetProject()
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
         endif
         call s:PrintProject('@||', 0)
      elseif len(a:options) == 1
         let project = s:FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
         endif
         call s:PrintProject('@||', 0)
      endif

   elseif (command == "main") " ----------- main
      if len(a:options) == 0
         let project = s:GetProject()
         if has_key(g:ProjectManager, project)
            call s:PrintProject(project, 1)
            let choice = input("Which directory do you want to make the main one? (#) ")
            while (choice > len(g:ProjectManager[project]["dirs"]) || choice < 1)
               normal \<Esc>
               let choice = input("Invalid Choice\nWhich directory do you want to make the main one? (#) ")
            endwhile
            if (choice != 1)
               let newMain = remove(g:ProjectManager[project]["dirs"], choice-1)
               call insert(g:ProjectManager[project]["dirs"], newMain)
            endif
            let s:activeProject = project
            call s:PrintProject(project, 0)
         else
            call s:EchoError(project . " does not exist!")
         endif
      elseif len(a:options) == 1
         let project = s:FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            call s:PrintProject(project, 1)
            let choice = input("Which directory do you want to make the main one? (#) ")
            while (choice > len(g:ProjectManager[project]["dirs"]) || choice < 1)
               normal \<Esc>
               let choice = input("Which directory? (#) ")
            endwhile
            if (choice != 1)
               let newMain = remove(g:ProjectManager[project]["dirs"], choice-1)
               call insert(g:ProjectManager[project]["dirs"], newMain)
            endif
            let s:activeProject = project
            call s:PrintProject(project, 0)
         else
            call s:EchoError(project . " does not exist!")
         endif
      elseif len(a:options) == 2
         let project = s:FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            echo dir
            let newMain = filter(g:ProjectManager[project]["dirs"], dir)
            if (newMain != [])
               call insert(g:ProjectManager[project]["dirs"], newMain[0])
               call s:PrintProject(project, 0)
               let s:activeProject = project
            else
               call s:EchoError(a:options[1] . " does not exist in project " project)
            endif
         else
         endif
      endif

   elseif (command == "exclude") " ------------ exclude
      if len(a:options) == 0
         let project = s:GetProject()
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
            call s:PrintProject(project, 0)
            let file = ""
            while (file != "q")
               let file = input("\nWhat file do you want to exclude? (q to quit)\n", "", "file")
               echo "\n"
               if (file != "q")
                  call s:AddExclusion(project, file, g:ProjectManager[project].type)
               endif
            endwhile
         else
            call s:EchoError(project . " project does not exist!\n\n")
            return 0
         endif
         call s:PrintProject(project, 0)
      elseif len(a:options) == 1
         let project = s:FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
            call s:ClearScreen()
            call s:PrintProject(project, 0)
            let file = ""
            let file = input("\nWhat file do you want to exclude? (q to quit)\n", "", "file")
            echo "\n"
            if (file != "q")
               call s:AddExclusion(project, file, g:ProjectManager[project].type)
            endif
         else
            call s:ClearScreen()
            call s:EchoError(project . " project does not exist!")
            return 0
         endif
      elseif len(a:options) > 1
         let project = s:FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
            for file in a:options[1:]
               call s:AddExclusion(project, file, g:ProjectManager[project].type)
            endfor
         else
            call s:ClearScreen()
            call s:EchoError(project . " project does not exist!\n\n")
            return 0
         endif
         call s:PrintProject(project, 0)
      endif
      return 0

   elseif (command == "optional") " ------------ optional
      if len(a:options) == 0
         let project = s:GetProject()
         if has_key(g:ProjectManager, project)
            echo "\n"
            while (1)
               call s:PrintProject(project, 3)
               let choice = input("Which directory do you want to toggle as optional? (q to quit) (#) ")
               echo "\n"
               let lenOfDirs = len(g:ProjectManager[project]["dirs"])
               while (choice > (lenOfDirs + len(g:ProjectManager[project]["optional"])) || choice < 1 || choice == 'q')
                  if (choice == 'q')
                     return 0
                  endif
                  normal \<Esc>
                  let choice = input("Invalid Choice\nWhich directory do you want to toggle as the optional? (q to quit) (#) ")
               endwhile
               if (choice <= lenOfDirs)
                  call add(g:ProjectManager[project]["optional"], remove(g:ProjectManager[project]["dirs"], choice-1))
               else
                  call add(g:ProjectManager[project]["dirs"], remove(g:ProjectManager[project]["optional"], choice-lenOfDirs-1))
               endif
               let s:activeProject = project
            endwhile
            call s:PrintProject(project, 0)
         else
            call s:EchoError(project . " does not exist!")
         endif
      elseif len(a:options) >= 1
         let project = s:FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            while (1)
               call s:PrintProject(project, 3)
               let choice = input("Which directory do you want to toggle as optional? (q to quit) (#) ")
               echo "\n"
               let lenOfDirs = len(g:ProjectManager[project]["dirs"])
               while (choice > (lenOfDirs + len(g:ProjectManager[project]["optional"])) || choice < 1 || choice == 'q')
                  if (choice == 'q')
                     return 0
                  endif
                  normal \<Esc>
                  let choice = input("Invalid Choice\nWhich directory do you want to toggle as the optional? (q to quit) (#) ")
               endwhile
               if (choice <= lenOfDirs)
                  call add(g:ProjectManager[project]["optional"], remove(g:ProjectManager[project]["dirs"], choice-1))
               else
                  call add(g:ProjectManager[project]["dirs"], remove(g:ProjectManager[project]["optional"], choice-lenOfDirs-1))
               endif
               let s:activeProject = project
            endwhile
            call s:PrintProject(project, 0)
         else
            call s:EchoError(project . " does not exist!")
         endif
      endif

   endif
endfunction

" GetProject ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Asks for a project and then matches against known projects. If there
"          is more than one match it will "beep" but remember the current
"            input, allowing the user to add more input for clarification
"            without having to type the original information over again.
"     input   - void
"     returns - [string] either the matched project or the original input (if
"               there is no match)
function! s:GetProject()
   let project = input("\nWhich project?\n", "", "custom,". s:SID() ."ProjectCompletion")
   let projectpart = project
   let projectMatches = s:ParseChoice(project, 0)
   while len(projectMatches) > 1
      normal \<Esc>
      let projectpart = input(projectpart)
      let project .= projectpart
      let projectMatches = s:ParseChoice(project, 0)
   endwhile
   if len(projectMatches) == 1
      let project = projectMatches[0]
   endif
   return project
endfunction

function! s:AddDirectoryInput(project, rel)
   let dir = ""
   let state = 'n'
   while (dir != "q")
      if (dir == 'e')
         let state = 'e'
      elseif (dir == 'r')
         let state = 'r'
      elseif (dir == 'n')
         let state = 'n'
      endif
      if (state == 'n')
         let dir = input("\nWhat directory do you want to add? (q to quit, e to add an exclusion, r to add a recursive directory)\n", "", "dir")
         echo "\n"
         call s:AddDirectory(a:project, dir, a:rel, 0)
      elseif (state == 'e')
         let dir = input("\nWhat file do you want to exclude? (q to quit, n to switch back to directories)\n", "", "file")
         echo "\n"
         call s:AddExclusion(a:project, dir, a:rel)
      elseif (state == 'r')
         let dir = input("\nWhat recurseive directory do you want to add? (q to quit, e to add an exclusion, n to add a normal directory)\n", "", "dir")
         echo "\n"
         call s:AddDirectory(a:project, dir, a:rel, 1)
      endif
   endwhile
endfunction

" AddDirectory ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Adds dir to project. Properly handles "\"'s, pre-existence, and
"          relative paths
"     input   - project: [string] The key to the dictionary to add the dir to
"               dir: [string] The dir to add to the project
"     returns - [bool] True if add succeeded
function! s:AddDirectory(project, dir, relative, recursive)
   " Don't check if directory exists if the project is relative
   if (a:relative == "R" || isdirectory(a:dir))
      if (a:relative == "R")
         let expandedDir = substitute(a:dir, "/*$", "/", "")
         " Special case for relative projects. Algorithm for ReturnAbsoluteRoot
         " requries that the main dir and the secondary dirs have a common root.
         " So if they're nested in the main dir, point them to the main dir's
         " parent.
         let numOfPojectLayers = len(split(a:project, '/'))
         let substitutionString = repeat("\.\.\/", numOfPojectLayers)
         if (matchstr(expandedDir,  "^\\.\\/\\(.\\+\\)\\@=") != "")
            let expandedDir = substitute(expandedDir, "^\\.\\/\\(.\\+\\)\\@=", substitutionString . a:project, "")
         else
            " Make sure that we back out to behind the project if we have a multi-layered project
            let parents = matchstr(expandedDir, '\(\.\./\)\+')
            let numOfParents = len(split(parents, '/'))

            if (numOfParents < numOfPojectLayers)
               let layers = split(a:project, '/')
               let layerCount = 0
               let partialProject = ''
               while ((numOfPojectLayers - numOfParents) > 0)
                  let partialProject .= layers[layerCount]
                  let partialProject .= '/'
                  let numOfPojectLayers -= 1
                  let layerCount += 1
               endwhile
               let expandedDir = substitute(expandedDir, '^\(\.\./\)\+', substitutionString . partialProject, "")
            endif
         endif
      else
         let expandedDir = s:ExpandDir(a:dir, 1)
      endif

      if !count(g:ProjectManager[a:project]["dirs"], expandedDir)
         "Make sure it doesn't already exist
         call add(g:ProjectManager[a:project]["dirs"], expandedDir)

         " Add recursive
         if (a:recursive > 0)
            let glob = split(globpath(expandedDir, '**'), "\0")
            for record in glob
               let record .= '/'
               if (isdirectory(record) && record != expandedDir)
                  if !count(g:ProjectManager[a:project]["dirs"], record)
                     call add(g:ProjectManager[a:project]["dirs"], record)
                  endif
               endif
            endfor
         endif

         echo "\n" expandedDir . " added!"
      else
         echo "\n"
         echohl ERROR
         echon expandedDir . " already exists in project "
         echon a:project . "!"
         echohl NORMAL
      endif
      return 1
   elseif (a:dir != 'q' && a:dir != 'n' && a:dir != 'r' && a:dir != 'e')
      echohl ERROR
      echo "\n"
      echo a:dir . " directory doesn't exist!\n"
      echohl NORMAL
      return -1
   endif
   return 0
endfunction

" AddExclusion ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Adds an exclusion to a project
"     input   - project: [string] The name of a project
"               file: [string] The file to exclude
"               relative: [char] R if relative, N if normal project.
"     returns - 1 on success, -1 on failure, 0 on other input received
function! s:AddExclusion(project, file, relative)
   " Don't check if file exists if the project is relative
   if (a:relative == "R" || filereadable(a:file))
      if (a:relative == "R")
         let expandedDir = a:file
      else
         let expandedDir = fnamemodify(a:file, ':p')
      endif

      if !count(g:ProjectManager[a:project]["excludes"], expandedDir)
         "Make sure it doesn't already exist
         call add(g:ProjectManager[a:project]["excludes"], expandedDir)
         echo "\n" expandedDir . " added!"
      else
         echo "\n"
         echohl ERROR
         echon expandedDir . " already exists in project "
         echon a:project . "!"
         echohl NORMAL
      endif
      return 1
   elseif (a:file != 'q' && a:file != 'e')
      echohl ERROR
      echo "\n"
      echo a:file . " file doesn't exist!\n"
      echohl NORMAL
      return -1
   endif
   return 0
endfunction

" PrintProject ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Prints out given project in a clean looking manner
"     input - inputProject: [string] The project to print or the string "@||"
"                           to print all projects
"             option: - [int] 0: normal operation
"                             1: print numbers before dirs
"                             2: omit dirs in print
"                             3: like 1, but omit excludes
"             returns - void
function! s:PrintProject(inputProject, option)
   silent! call s:ClearScreen()
   let l:projectList = []
   if a:inputProject == "@||"
      echo "\n"
      let l:projectList = sort(keys(g:ProjectManager))
   else
      if has_key(g:ProjectManager, a:inputProject)
         call add(l:projectList, a:inputProject)
      else
         echo a:inputProject . " does not exist!"
         return
      endif
   endif
   let counter = 1
   for project in l:projectList
      echo project . ":"
      if (project == s:activeProject)
         echohl projectManagerArrows
         echon "  < < < < < < < < < <"
         echohl NONE
      endif
      let dirNum = 0
      if a:option != 2
         echohl projectManagerDirs
         for dir in copy(g:ProjectManager[project]["dirs"])
            if (a:inputProject == "@||" && dirNum >= 10)
               echohl projectManagerArrows
               echo "        ...\n"
               echohl projectManagerDirs
               break
            endif
            echo "        " . (a:option == 1? "(" . counter . ")" : "") . dir ."\n"
            let counter += 1
            let dirNum += 1
         endfor
         if (a:inputProject == "@||" && dirNum >= 10)
            echohl NONE
            continue
         endif
         echohl projectManagerOptional
         for file in copy(g:ProjectManager[project]["optional"])
            if (a:inputProject == "@||" && dirNum >= 10)
               echohl projectManagerArrows
               echo "        ...\n"
               echohl projectManagerDirs
               break
            endif
            echo " (optl) " . (and(a:option, 1) == 1? "(" . counter . ")" : "") . file ."\n"
            let counter += 1
            let dirNum += 1
         endfor
         if (a:inputProject == "@||" && dirNum >= 10)
            echohl NONE
            continue
         endif
         if (a:option != 3)
            echohl projectManagerExcludes
            for file in copy(g:ProjectManager[project]["excludes"])
               if (a:inputProject == "@||" && dirNum >= 10)
                  echohl projectManagerArrows
                  echo "        ...\n"
                  echohl projectManagerDirs
                  break
               endif
               echo " (excl) " . (and(a:option, 1) == 1? "(" . counter . ")" : "") . file ."\n"
               let counter += 1
               let dirNum += 1
            endfor
         endif
         echohl NORMAL
      endif
   endfor
   echo "\n"
endfunction

" ClearScreen <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Clears command line.
"     input   - void
"     returns - void
function! s:ClearScreen()
   let &ch=&lines-1
   redraw!
   let &ch=1
endfunction

" SaveProject <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Saves project information to s:projectFile
"     input   - void
"     returns - void
function! s:SaveProject()
   let l:mySaveList = []
   for project in sort(keys(g:ProjectManager))
      call add(mySaveList, project." ".g:ProjectManager[project]["type"])
      for dir in copy(g:ProjectManager[project]["dirs"])
         call add(l:mySaveList, "\tD " . substitute(dir, '/*$', '/', ''))
      endfor
      for dir in copy(g:ProjectManager[project]["optional"])
         call add(l:mySaveList, "\tO " . substitute(dir, '/*$', '/', ''))
      endfor
      for exclude in copy(g:ProjectManager[project]["excludes"])
         call add(l:mySaveList, "\tE " . exclude)
      endfor
   endfor
   call writefile(l:mySaveList, s:projectFile)
endfunction

" LoadProject <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Loads project information stored at s:projectFile
"     input   - void
"     returns - void
function! s:LoadProject()
   if exists("g:ProjectManager")
      unlet g:ProjectManager
   endif
   let g:ProjectManager = {}
   if filereadable(s:projectFile)
      let l:mySaveList = readfile(s:projectFile)
      for line in l:mySaveList
         if (line[0] != "\t")
            " Look at the first character
            let l:currentProject = split(line)[0]
            let l:currentProjecttype = split(line)[1]
            let g:ProjectManager[currentProject] =
                     \ {"type":currentProjecttype, "dirs":[], "optional":[], "name":currentProject, "excludes":[]}
         else
            if has_key(g:ProjectManager, currentProject)
               let lineType = matchstr(line, '\t\zs\u')
               let strippedLine = substitute(line, '\t\u ', '', 'g')
               if (lineType == 'D') " Directories
                  call add(g:ProjectManager[currentProject]["dirs"], strippedLine)
               elseif (lineType == 'O') " Optional directories
                  call add(g:ProjectManager[currentProject]["optional"], strippedLine)
               elseif (lineType == 'E') " Exclude files
                  call add(g:ProjectManager[currentProject]["excludes"], strippedLine)
               else
                  " Assumes dirs in the case of no leader
                  call add(g:ProjectManager[currentProject]["dirs"], substitute(line, '\t', '', 'g'))
               endif
            else
               return -1
            endif
         endif
      endfor
   else
      " If there is no savefile, then create one"
      if !isdirectory($HOME.'/vimfiles')
         call mkdir($HOME.'/vimfiles')
      endif
      call writefile([], s:projectFile)
   endif
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
      let newDir = substitute(newDir, "\\", "/", "g")
      let newDir = substitute(newDir, "/*$", "/", "")
   else
      let newDir = fnamemodify(newDir, ":p:h")
      let newDir = substitute(newDir, "\\", "/", "g")
      let newDir = substitute(newDir, "/*$", "", "")
   endif

   return newDir
endfunction

" CommandProjectHybridCompletion ><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: This is a custom completion function that will complete the list of
"          commands, projects, or directories based on which argument the
"          user is currently typing.
"     input/returns - see :h command-completion-custom
function! s:CommandProjectHybridCompletion(arg, line, pos)
   let returnString = ""
   let argList = split(a:line, '\%(\%(\%(^\|[^\\]\)\\\)\@<!\s\)\+', 1)
   if     len(argList) == 1
      " One argument, complete commands
      for commands in s:ProjectManagerCommands
         let returnString .= commands . "\n"
      endfor
      return returnString
   elseif len(argList) == 2
      " Two arguments, complete project names
      for project in keys(g:ProjectManager)
         let returnString .= argList[0] . " " . project . "\n"
      endfor
      return returnString
   elseif len(argList) == 3
      " Three arguments, complete dirs
      if (argList[0] == 'rename' || argList[0] == 'optional')
         " rename's third argument is brand new and there's noting to complete
         return ""
      elseif (argList[0] =~ 'delete\|main\|remove')
         " These commands choose dirs that are already a part of the project
         if (has_key(g:ProjectManager, argList[1]))
            for dir in ProjectManager_ReturnProjectDirectories(argList[1])
               let returnString .= argList[0] ." ". argList[1] ." ". dir ."\n"
            endfor
            return returnString
         endif
      else
         " These commands choose dirs that aren't in the project already
         let returnStringList = split(globpath(s:ExpandDir(argList[2], 1), '*'), "\0")
         for line in returnStringList
            if isdirectory(line)
               let returnString .= argList[0] ." ". argList[1] ." ". line ."\n"
            endif
         endfor
         return returnString
      endif
   endif
endfunction

" ProjectCompletion <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: This is a custom completion function that will complete project names
"     input/returns - see :h command-completion-custom
function! s:ProjectCompletion(arg, line, pos)
   let returnString = ""
   let argList = a:arg
   for project in keys(g:ProjectManager)
      let returnString .= project . "\n"
   endfor
   return returnString
endfunction

" ProjectFileCompletion <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: This is a custom completion function that will complete file names in
"          a project.
"     input/returns - see :h command-completion-custom
function! s:ProjectFileCompletion(arg, line, pos)
   let origdir = s:GetCWD()
   " Save for later

   let ReturnedProjectStruct = ProjectManager_ReturnProject(origdir)
   let project = ReturnedProjectStruct[0]
   let projectRoot = ReturnedProjectStruct[1]
   let dirs = ProjectManager_ReturnProjectDirectories(project.name)

   exe "cd " . projectRoot
   let returnList = globpath(join(dirs, ','), '*', 0, 1)
   exe "cd " . origdir

   call filter(returnList, 'filereadable(v:val)')
   call map(returnList, "substitute(v:val, '.*/', '', '')")

   return join(returnList, "\n")
endfunction

" FormatVimGrepFiles ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Gets the current projects directories and formats them properly for
"          a vimgrep.
"     input   - void
"     returns - [string] A string containing all properly formated directories
"               from the current project.
function! s:FormatVimGrepFiles(dirList, typeList)
   let myReturnString = ""
   if len(a:dirList) > 0
      for dir in a:dirList
         if (empty(a:typeList))
            let myReturnString .= " ". dir ."/*"
         else
            for extension in a:typeList
               let myReturnString .= ' '. dir.'/*.'. extension .' '
            endfor
         endif
      endfor
   else
      let myReturnString = './*'
   endif
   return myReturnString
endfunction

" FormatCtagExcludes ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Gets the current projects excludes and formats them properoy for a
"          ctag call.
"     input   - project: [string] The project to use
"     returns - [string] A string containing properly formated for ctags
function! s:FormatCtagExcludes(project)
   let myReturnString = ""
   for exclude in a:project.excludes
      let exclude = substitute(exclude, '.*/', '', '')
      let myReturnString .= " --exclude=". exclude .""
   endfor
   return myReturnString
endfunction

" ProjectVimGrep ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Performs an lvimgrep on the current project
"     input   - searchWord: [string] What to search for
"     returns - void
function! s:ProjectVimGrep(searchWord, typeList, global)
   let turnAleBackOn = 0
   if (exists('g:ale_enabled') && g:ale_enabled)
      let turnAleBackOn = 1
      let g:ale_enabled = 0
   endif
   let g:projectManager_DirSearchActive = 1
   " If ale is installed we need to disable it, because it tries to lint
   " everything we search. It slows things down a TON and sometimes crashes.
   let origdir = s:GetCWD()
   " Save for later

   let ReturnedProjectStruct = ProjectManager_ReturnProject(s:GetCWD())
   let project = ReturnedProjectStruct[0]
   let projectRoot = ReturnedProjectStruct[1]
   let dirs = ProjectManager_ReturnProjectDirectories(project.name)

   let searchDirs = s:FormatVimGrepFiles(dirs, a:typeList)
   if (projectRoot != "")
      exe "cd " . projectRoot
   endif
   " Change directory so that our relative projects can have the correct
   "   starting point

   " If there are any excludes make sure to add them to wildignore so we don't
   "   find them in the search.
   let excludeString = ''
   for exclude in project.excludes
      let excludeString .= substitute(exclude, '.*\/', '', '') . ','
   endfor
   let excludeString = substitute(excludeString, ',$', '', '')
   exe 'set wildignore+='. excludeString

   exe "lvimgrep /" . a:searchWord."/j". (a:global? "g ":" ") . searchDirs
   lw
   exe "normal! \<C-W>j\<CR>"
   echom a:searchWord
   let @/ = a:searchWord . '\c'
   cclose
   call setqflist([])

   " Remove the files from wildignore for future searches
   exe 'set wildignore-='. excludeString

   exe "cd " . origdir
   " Back to where we started
   if (turnAleBackOn)
      let g:ale_enabled = 1
      " Turn ale back on
   endif
   let g:projectManager_DirSearchActive = 0

   set hlsearch
endfunction

" StartDirSearch ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: A wrapper to DirSearch. Prompts the user for input and then passes it
"          to DirSearch.
"     input   - void
"     returns - void
function! s:StartDirSearch()
   cclose
   call setqflist([])
   echo s:GetCWD()
   let pattern = input(":DirectorySearch ", "", "tag")
   call s:DirSearch(pattern)
endfunction

" DirSearch <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Takes a pattern and searches the whole directory (or project) for
"          matches.
"     input   - input: [string] A regex pattern to search for
"               (use \r for recursive or \R for recursive from parent directory)
"     returns - void
function! s:DirSearch(input)
   if len(a:input)
      try
         let search = ""
         let extensions = ""
         let recurse = 0
         let global = 0
         let directoryOverride = 0
         if     (a:input =~# '\(\\\)\@<!\\r')
            " Found "\r" in pattern, recurse this directory
            let recurse = 1
            let search = substitute(a:input, '\(\\\)\@<!\\r\c', "", "g")
         elseif (a:input =~# '\(\\\)\@<!\\R')
            " Found "\R" in pattern, recurse parent directory
            exec "cd .."
            let recurse = 1
            let search = substitute(a:input, '\(\\\)\@<!\\R\c', "", "g")
         else
            let search = a:input
         endif
         if (search =~# '\(\\\)\@<!\\e')
            " Found "\e" in pattern, specifies file types.
            let extensions = split(matchstr(search, '\(\\\)\@<!\\e\zs.*'), ',')
            let search = substitute(search, '\(\\\)\@<!\\e.*', "", "g")
         endif
         if (search =~# '\(\\\)\@<!\\g')
            " Found "\g" in pattern, list all matches.
            let global = 1
            let search = substitute(search, '\(\\\)\@<!\\g.*', "", "g")
         endif
         if (search =~# '\(\\\)\@<!\\d')
            " Found "\d" in pattern, only search in the directory
            let directoryOverride = 1
            let search = substitute(search, '\(\\\)\@<!\\d.*', "", "g")
         endif
         if (recurse)
            exec "lvimgrep /" . search . "/j". (global? "g ":" ") . s:FormatVimGrepFiles(["./**"], extensions)
         elseif (directoryOverride)
            exec "lvimgrep /" . search . "/j". (global? "g ":" ") . s:FormatVimGrepFiles(["./"], extensions)
         else
            call s:ProjectVimGrep(search, extensions, global)
         endif
         lw
         let @/ = search
         exec feedkeys("\<CR>\<C-K>")
      catch /^Vim\%((\a\+)\)\=:E480/
         " E480: No match
         " Not an error, but still need to inform the user that their search
         "   failed
         call s:EchoError(matchstr(v:exception, 'No.*'))
      endtry
   endif
endfunction

" TraverseCtag ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Goes to tag under cursor but tries to intelligently open it in a new
"          split or tab based on certain criteria. Also tries to generate a tag
"          file if there isn't one.
"     input   - (optonal) If present, it will not try to generate a tag file and
"               try again.
"     returns - void
function! s:TraverseCtag(...)
   try
      " If it's part of a project then look in the "root" directory of the
      "   project for the tags file.
      let ReturnedProjectStruct = ProjectManager_ReturnProject(s:GetCWD())
      let project = ReturnedProjectStruct[0]
      let root = ReturnedProjectStruct[1]
      if (len(project) > 0)
         if (project.type == 'N')
            exe "setlocal tags=" . project.dirs[0] . "/tags"
         elseif (project.type == 'R')
            exe "setlocal tags=" . root . "/tags"
         endif
      endif
      let initialWinNum = winnr("$")
      let initialTabNum = tabpagenr()
      if (&diff)
         diffoff!
         wincmd w
         q
      else
         cclose
         lclose
      endif
      let l:windowNr = s:GetNumVerticalSplits()
      echom l:windowNr
      let tag = expand('<cword>')
      let tagFile = s:ReturnTagFile(tag)
      if (&columns >= (80 * (l:windowNr + 1)) && l:windowNr < s:maxSplits)
         vsplit
         wincmd l
         exec "tag " . tag
      elseif (&mod == 0 || expand('%') == tagFile)
         exe "normal! \<C-]>"
      else
         tab split
         exec "tag " . tag
      endif
      if (getline('.') =~ '\s*}')
         " If we're at the end of a c struct then we want to be able to see
         "   the lines before the tag and not after.
         normal! z-
      else
         normal! zt
      endif
   catch /^Vim\%((\a\+)\)\=:E43[34]/
      "No tag file, try to generate them and retry
      if (a:0 == 0)
         silent call s:GenerateCTags()
         call s:TraverseCtag('Non-recursive')
      else
         " Base case: Tried but couldn't generate c-tags.
         call s:EchoError(matchstr(v:exception, '\(E\d\+:\s*\)\@<=\S.*$'))

         "   Quit superfluous buffer
         if (winnr("$") > initialWinNum)
            quit
         endif
      endif
   catch /^Vim\%((\a\+)\)\=:E426/
      "Tag not found
      if (tabpagenr() != initialTabNum)
         tabclose
      elseif (winnr("$") > initialWinNum)
         quit
      endif
      call s:EchoError(matchstr(v:exception, '\(E\d\+:\s*\)\@<=\S.*$'))
   endtry
endfunction

" Tag <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Executes a :tag but sets the local tag to the appropriate file
"          beforehand. Also tries to generate tags file if it doesn't exist.
"     input   - tag: [string] The tag to search for
"     returns - void
function! s:Tag(tag, ...)
   try
      " If it's part of a project then look in the "root" directory of the
      "   project for the tags file.
      let ReturnedProjectStruct = ProjectManager_ReturnProject(s:GetCWD())
      let project = ReturnedProjectStruct[0]
      let root = ReturnedProjectStruct[1]
      if (len(project) > 0)
         if (project.type == 'N')
            exe "setlocal tags=" . project.dirs[0] . "/tags"
         elseif (project.type == 'R')
            exe "setlocal tags=" . root . "/tags"
         endif
      endif
      exec "tag " . a:tag
   catch /^Vim\%((\a\+)\)\=:E43[34]/
      "No tag file, try to generate them and retry
      silent call s:GenerateCTags()
      if (a:0 == 0)
         call s:Tag(a:tag, 'Non-recursive')
      else
         call s:EchoError(matchstr(v:exception, '\(E\d\+:\s*\)\@<=\S.*$'))
      endif
   catch /^Vim\%((\a\+)\)\=:E426/
      "Tag not found
      call s:EchoError(matchstr(v:exception, '\(E\d\+:\s*\)\@<=\S.*$'))
   endtry
endfunction

" Edit ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Executes an :edit but also searches other direcectories in the
"          project for the file
"     input   - file: [string] file to edit
"     returns - void
function! s:Edit(file)
   if filereadable(a:file)
      exe 'edit '.a:file
   else
      let origdir = s:GetCWD()
      " Save for later

      let ReturnedProjectStruct = ProjectManager_ReturnProject(origdir)
      let project = ReturnedProjectStruct[0]
      let projectRoot = ReturnedProjectStruct[1]
      let dirs = ProjectManager_ReturnProjectDirectories(project.name)

      exe "cd " . projectRoot
      " Change directory so that our relative projects can have the correct
      "   starting point

      for dir in dirs
         if filereadable(dir.a:file)
            exe 'edit '.dir.a:file
            return
         endif
      endfor

      call EchoError('File not found! Creating new file.')
      exe "cd " . origdir
      exe 'edit '. a:file
   endif
endfunction

" GenerateCTags <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Generates a tag file for your whole project. This function assumes
"          that you have Ctags installed.
"     input   - void
"     returns - void
function! s:GenerateCTags()
   let currentwd = s:ExpandDir(getcwd(), 0)
   let dirs = ProjectManager_ReturnProjectDirectories(currentwd)
   if len(dirs) == 0
      exe "silent!! ctags " . s:FormatVimGrepFiles(dirs, [])
   else
      let excludes = s:FormatCtagExcludes(ProjectManager_ReturnProject(currentwd)[0])
      if (s:ExpandDir(dirs[0], 0) == currentwd)
         exe "silent!! ctags " . excludes .' '. s:FormatVimGrepFiles(dirs, [])
      else
         exe "cd " . s:ExpandDir(dirs[0], 0)
         exe "! ctags " . excludes .' '. s:FormatVimGrepFiles(dirs, [])
         exe "cd " . currentwd
      endif
   endif
endfunction

" ReturnTagFile <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Finds the file that a tag resides in. If there are more than one, it
"          takes the first one.
"     input   - tag: [string] What tag we're searching for
"     returns - [string] The file that the tag resides in or empty if the tag
"               doesn't exist
function! s:ReturnTagFile(tag)
   try
      let tagString = split(execute("tselect ".a:tag), "\n")[1]
      let tagString = matchstr(tagString, '[^/\\]*$')
      return tagString
   catch /^Vim\%((\a\+)\)\=:E426/
      return ""
   endtry
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

" GetNumVerticalSplits ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Returns the number of vertical splits on the current tab.
"     returns - [int] Number of vertical splits
function! s:GetNumVerticalSplits()
   if (winnr("$") == 1)
      return 1
   endif

   let startingWindow = winnr()
   let vsplits = 0
   wincmd w
   while 1
      if winwidth("$") < &columns
         let vsplits += 1
      endif

      if startingWindow != winnr()
         wincmd w
      else
         break
      endif
   endwhile

   return max([1, vsplits])
endfunction

" GetCWD ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: getcwd() behaves slightly different on different OS's. This
"          standardizes it.
"     returns - [string] The full working directory with a trailing "/"
function! s:GetCWD()
   return substitute(getcwd(), "/*$", "/", "")
endfun


" SID <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Gets the SID for the current script.
"     returns - [string] The string "<SNR>##_" where ## is replaced by the <SID>
function! s:SID()
   return matchstr(expand('<sfile>'), '<SNR>\d\+_\zeSID$')
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
"<< End of Vim Project Manager plugin <><><><><><><><><><><><><><><><><><><><><>
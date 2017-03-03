" @Tracked
" Vim Poject Manager plugin
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 03/02/2017 10:50 AM
" Version: 2.0.0

let g:vimProjectManager = 1

let s:ProjectManagerCommands = ["activate", "add", "blarg", "delete", "help", "new", "newrel", "main", "quit", "remove", "rename", "select", "view"]
   " A list of commands that the ExecuteCommand() function can handle
let s:projectFile = $HOME.'/vimfiles/.projects'
   " The file that stores the project information across multiple sessions
let s:activeProject = ""
   " The project that was last interacted with

if has("autocmd")
augroup ProjectManager
   au!
   autocmd VimEnter * call LoadProject()
augroup END
endif

command! Proj call Project()
" Brings up the Project Manager, um... Manager...
command! -nargs=1 -complete=custom,ProjectCompletion ProjSelect call ExecuteCommand('select', ['<args>'])
" Selects a project so you don't have to go into the manager
command! -nargs=1 -complete=tag DirectorySearch :call DirSearch('<args>')
" Brings up the Directory Search Prompt (See DirSearch)

" Allows you to set your own key combo if you want to
if (exists('g:DirSearchKeyCombo'))
   exe 'nnoremap '.g:DirSearchKeyCombo.' :call StartDirSearch()<CR>'
else
   nnoremap <A-d>   :call StartDirSearch()<CR>
endif
" Brings up the Directory Search Prompt (See DirSearch)

" ReturnProject <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Returns the dirs in a project as list
"     input   - input: [string] a project name or directory as a string
"     returns - [[project{}, root]] a project is a structure defined as the following:
"                Project
"                   .type     " The character 'N' or 'R' (normal or relative)
"                   .dirs     " A list of directories that are in the project
"                   .name     " The name and key of the project
"                and the absolute path to the root directory of the project as a string
function! ReturnProject(input)
   if has_key(g:ProjectManager, a:input)
      " Try to match to a project name
      return [g:ProjectManager[a:input], '']
   else
      " Don't have a project called that, try to find a directory that matches
      let l:filename = substitute(a:input, "\\", "/", "g")
      " Rectify Windows directory types
      let projectList = {}
      for key in keys(g:ProjectManager)
         for dir in copy(g:ProjectManager[key]["dirs"])
            if (dir == filename)
               let projectList[key] = g:ProjectManager[key]
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
   let originalDir = getcwd()
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
            for directory in g:ProjectManager[project]['dirs'][1:]
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
      let projects[project].root = ReturnAbsoluteRoot(projects[project], projects[project].keyMatch)
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
      return [g:ProjectManager[key], ProjectRoot]
   endif

   exe "cd ".originalDir
   " No form of matching worked, return blank.
   return [{"type": '', "dirs":[], "name": ''}, '']
endfunction

" ReturnAbsoluteRoot ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Finds out if the relative directory structure of the current project
"         is valid for our cwd.
"  returns: The absolute root path for valid, '' for invalid
function! ReturnAbsoluteRoot(project, match)
   if (a:project.type == "N")
      " Normal project. All dirs are already absolute.
      return project.dirs[0]
   elseif (a:project.type == "R")
      " Save for later
      let originalDir = getcwd()

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

      " All dirs checked out
      return root
   endif
endfunction

" ReturnProjectDirectories ><><><><><><><><><><><><><><><><><><><><><><><><><><>
function! ReturnProjectDirectories(input)
   return ReturnProject(a:input)[0].dirs
endfunction

" Project <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: The "main function" of the project manager
"     input   - void
"     returns - void
function! Project()
   if !exists("g:ProjectManager")
      let g:ProjectManager = {}
   endif
   let choice = ""
   let track = 0
   call PrintProject("@||", 0)
   while(track != -1)
      let choice = input("\n(1) Print all projects\n" .
                         \ "(2) Add to a current project\n" .
                         \ "(3) Remove a project or directory from a project\n" .
                         \ "(4) Create a new absolute project\n" .
                         \ "(5) Create a new relative project\n" .
                         \ "(You can also just type commands. Type \"help\" for a list of commands)\n\n", "", "custom,ProjectCompletion")
      let l:argumentlist = split(choice)
      if len(argumentlist) < 1
         echo "\n"
         continue
         "Don't parse anything if they just pressed enter
      endif
      let l:matchlist = ParseChoice(l:argumentlist[0], 1)
      if len(l:matchlist) == 1
         if count(s:ProjectManagerCommands, l:matchlist[0]) > 0
            let track = ExecuteCommand(l:matchlist[0], l:argumentlist[1:])
         elseif has_key(g:ProjectManager, l:matchlist[0])
            call PrintProject(l:matchlist[0], 0)
         else
            call EchoError("Parse Error!")
         endif
      elseif len(l:matchlist) > 1
         normal \<Esc>
      else
         if choice == "1"
            call PrintProject("@||", 0)
         elseif choice == "2"
            call PrintProject("@||", 0)
            call ExecuteCommand("add", [])
         elseif choice == "3"
            call ExecuteCommand("delete", [])
         elseif choice == "4"
            call ExecuteCommand("new", [])
         elseif choice == "5"
            call ExecuteCommand("newrel", [])
         endif
      endif
   endwhile
endfunction

" ParseChoice <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Finds commands or projects that user input matches. Exact matches will
"            take precedence. If there are multiple partial matches, a list
"            will be returned instead.
"     input   - choice: [string] User input to match to
"               commandFlag: [bool] False: won't take commands into account when
"                           matching
"     returns - [string[]] a list of matching commands or projects
function! ParseChoice(choice, commandFlag)
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
"  brief: Similar to ParseChoice, but only searches for projects and will
"            return a match only if there is exactly one match
"     input   - partialProject: [string] typically user input to try to match to
"                             an existing project
"     returns - [string] either the matched project or the original input
function! FillProject(partialProject)
   let project = a:partialProject
   let projectMatches = ParseChoice(project, 0)
   if len(projectMatches) == 1
      let project = projectMatches[0]
   endif
   return project
endfunction

" ExecuteCommand ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Executes any command from s:ProjectManagerCommands
"     input   - command: [string] which command to execute
"               options: [string[]] list of strings with additional, optional
"                        command-line arguments determined by the context of
"                        the command
"     returns - [bool] True: a signal to exit the main loop
function! ExecuteCommand(command, options)
   let command = tolower(a:command)
   if     (command == "quit") " ------------ quit
      call SaveProject()
      return -1

   elseif (command == "blarg")
      echo " and Gilgamesh!\n"
      return 0

   elseif (command == "help") " ------------ help
      call ClearScreen()
      echo "add    [project] [first_dir_to_add] ..."
      echo "    Add at 1 or more dirs to a project"
      echo "delete [project] [first_dir_to_delete] ..."
      echo "    Deletes a project or directory from a project"
      echo "help"
      echo "    This help message"
      echo "new    [project] [first_dir_to_add] ..."
      echo "    Create a new project and add dirs to it"
      echo "newrel [project] [first_dir_to_add] ..."
      echo "    Create a new relative project and add dirs to it"
      echo "main   [project] [dir-to_make_main]"
      echo "    Change the main dir in a project"
      echo "remove [project] [first_dir_to_remove] ..."
      echo "    Removes a project or directory from a project"
      echo "rename [project] [new_name]"
      echo "    Renames a project"
      echo "quit"
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
            let s:activeProject = project
         else
            call EchoError(project . " already exists in project manager!")
            return 0
         endif
         let dir = ""
         while (dir != "q")
            let dir = input("\nWhat directory do you want to add? (q to quit)\n", "", "dir")
            echo "\n"
            call AddDirectory(project, dir, "N")
         endwhile
         call PrintProject(project, 0)
      elseif len(a:options) == 1
         let project = a:options[0]
         if !has_key(g:ProjectManager, project)
            let g:ProjectManager[project] = {}
            let g:ProjectManager[project]["type"] = "N"
            let g:ProjectManager[project]["dirs"] = []
            let s:activeProject = project
         else
            call EchoError(project . " already exists in project manager!")
            return 0
         endif
         let dir = ""
         while (dir != "q")
            let dir = input("\nWhat directory do you want to add? (q to quit)\n", "", "dir")
            echo "\n"
            call AddDirectory(project, dir, "N")
         endwhile
         call PrintProject(project, 0)
      elseif len(a:options) > 1
         let project = a:options[0]
         if !has_key(g:ProjectManager, project)
            let g:ProjectManager[project] = {}
            let g:ProjectManager[project]["type"] = "N"
            let g:ProjectManager[project]["dirs"] = []
            let s:activeProject = project
         else
            call EchoError(project . " already exists in project manager!")
            return 0
         endif
         for dir in a:options[1:]
            call AddDirectory(project, dir, "N")
         endfor
      endif

   elseif (command == "newrel") " ------------ newrel
      if len(a:options) == 0
         let project = input("\nWhat is the main directory of the project?\n")
         if !has_key(g:ProjectManager, project)
            let project = substitute(project, '/\?$', '/', '')
            let g:ProjectManager[project] = {}
            let g:ProjectManager[project]["type"] = "R"
            let g:ProjectManager[project]["dirs"] = []
            let s:activeProject = project
         else
            call EchoError(project . " already exists in project manager!")
            return 0
         endif
         call AddDirectory(project, '.', "R")
         let dir = ""
         while (dir != "q")
            let dir = input("\nWhat directory do you want to add? (q to quit)\n", "", "dir")
            echo "\n"
            call AddDirectory(project, dir, "R")
         endwhile
         call PrintProject(project, 0)
      elseif len(a:options) == 1
         let project = a:options[0]
         if !has_key(g:ProjectManager, project)
            let project = substitute(project, '/\?$', '/', '')
            let g:ProjectManager[project] = {}
            let g:ProjectManager[project]["type"] = "R"
            let g:ProjectManager[project]["dirs"] = []
            let s:activeProject = project
         else
            call EchoError(project . " already exists in project manager!")
            return 0
         endif
         call AddDirectory(project, '.', "R")
         let dir = ""
         while (dir != "q")
            let dir = input("\nWhat directory do you want to add? (q to quit)\n", "", "dir")
            echo "\n"
            call AddDirectory(project, dir, "R")
         endwhile
         call PrintProject(project, 0)
      elseif len(a:options) > 1
         let project = a:options[0]
         if !has_key(g:ProjectManager, project)
            let project = substitute(project, '/\?$', '/', '')
            let g:ProjectManager[project] = {}
            let g:ProjectManager[project]["type"] = "R"
            let g:ProjectManager[project]["dirs"] = []
            let s:activeProject = project
         else
            call EchoError(project . " already exists in project manager!")
            return 0
         endif
         call AddDirectory(project, '.', "R")
         for dir in a:options[1:]
            call AddDirectory(project, dir, "R")
         endfor
      endif

   elseif (command == "add") " ------------ add
      if len(a:options) == 0
         let project = GetProject()
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
            let dir = ""
            while (dir != "q")
               let dir = input("\nWhat directory do you want to add? (q to quit)\n", "", "dir")
               echo "\n"
               call AddDirectory(project, dir, g:ProjectManager[project]["type"])
            endwhile
         else
            call EchoError(project . " project does not exist! Did you mean new?\n\n")
            return 0
         endif
         call PrintProject(project, 0)
      elseif len(a:options) == 1
         let project = FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
            call ClearScreen()
            let dir = ""
            while (dir != "q")
               let dir = input("What directory do you want to add? (q to quit)\n", "", "dir")
               call AddDirectory(project, dir, g:ProjectManager[project]["type"])
            endwhile
         else
            call ClearScreen()
            call EchoError(project . " project does not exist! Did you mean new?")
            return 0
         endif
      elseif len(a:options) > 1
         let project = FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
            for dir in a:options[1:]
               call AddDirectory(project, dir, g:ProjectManager[project]["type"])
            endfor
         else
            call ClearScreen()
            call EchoError(project . " project does not exist! Did you mean new?\n\n")
            return 0
         endif
         call PrintProject(project, 0)
      endif
      return 0

   elseif (command == "delete" || command == "remove") " ------------ delete/remove
      if len(a:options) == 0
         let choice = input("\nDo you want to delete a (1) project, or (2) a directory in a project? ")
         if choice == 1
            call PrintProject("@||", 2)
            let project = GetProject()
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
               call EchoError(project . " does not exist!")
            endif
         elseif choice == 2
            let project = GetProject()
            if has_key(g:ProjectManager, project)
               let s:activeProject = project
               call PrintProject(project, 1)
               let choice = input("Which directory? (#) ")
               while (choice > len(g:ProjectManager[project]["dirs"]))
                  normal \<Esc>
                  let choice = input("Which directory? (#) ")
               endwhile
               echo "\n"
               echo g:ProjectManager[project]["dirs"][choice-1] . " removed!"
               call remove(g:ProjectManager[project]["dirs"], choice - 1)
               call PrintProject(project, 0)
            else
               call EchoError(project . " does not exist!")
            endif
         endif
      elseif len(a:options) == 1
         let project = FillProject(a:options[0])
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
            call EchoError(project . " does not exist!")
         endif
      elseif len(a:options) > 1
         let project = FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
            for dir in a:options[1:]
               let safeDir = ExpandDir(dir, 0)
               call filter(g:ProjectManager[project]["dirs"], 'v:val !~ "' . safeDir . '"')
            endfor
            call ClearScreen()
            call PrintProject(project, 0)
         else
            call EchoError(project . " does not exist!")
         endif
      endif

   elseif (command == "view") " ------------ view
      if len(a:options) == 0
         call PrintProject("@||", 0)
      elseif len(a:options) > 0
         let project = FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            call PrintProject(project, 0)
            let s:activeProject = project
         else
            call EchoError(project . " does not exist!")
         endif
      endif

   elseif (command == "rename") " ------------ rename
      if len(a:options) == 0
         let project = GetProject()
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
               call EchoError(newProject . " is already a project!")
            endif
         else
            call EchoError(project . " is not a valid project!")
         endif
      elseif len(a:options) == 1
         let project = FillProject(a:options[0])
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
               call EchoError(newProject . " is already a project!")
            endif
         else
            call EchoError(project . " is not a valid project!")
         endif
      elseif len(a:options) == 2
         let project = FillProject(a:options[0])
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
               call EchoError(newProject . " is already a project!")
            endif
         else
            call EchoError(project . " is not a valid project!")
         endif
      endif

   elseif (command =~ 'select\|activate') " ----------- select
      if len(a:options) == 0
         let project = GetProject()
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
         endif
         call PrintProject('@||', 0)
      elseif len(a:options) == 1
         let project = FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            let s:activeProject = project
         endif
         call PrintProject('@||', 0)
      endif

   elseif (command == "main") " ----------- main
      if len(a:options) == 0
         let project = GetProject()
         if has_key(g:ProjectManager, project)
            call PrintProject(project, 1)
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
            call PrintProject(project, 0)
         else
            call EchoError(project . " does not exist!")
         endif
      elseif len(a:options) == 1
         let project = FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            call PrintProject(project, 1)
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
            call PrintProject(project, 0)
         else
            call EchoError(project . " does not exist!")
         endif
      elseif len(a:options) == 2
         let project = FillProject(a:options[0])
         if has_key(g:ProjectManager, project)
            echo dir
            let newMain = filter(g:ProjectManager[project]["dirs"], dir)
            if (newMain != [])
               call insert(g:ProjectManager[project]["dirs"], newMain[0])
               call PrintProject(project, 0)
               let s:activeProject = project
            else
               call EchoError(a:options[1] . " does not exist in project " project)
            endif
         else
         endif
      endif
   endif
endfunction

" GetProject ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Asks for a project and then matches against known projects. If there
"            is more than one match it will "beep" but remember the current
"            input, allowing the user to add more input for clarification
"            without having to type the original information over again.
"     input   - void
"     returns - [string] either the matched project or the original input (if
"               there is no match)
function! GetProject()
   let project = input("\nWhich project?\n", "", "custom,ProjectCompletion")
   let projectpart = project
   let projectMatches = ParseChoice(project, 0)
   while len(projectMatches) > 1
      normal \<Esc>
      let projectpart = input(projectpart)
      let project .= projectpart
      let projectMatches = ParseChoice(project, 0)
   endwhile
   if len(projectMatches) == 1
      let project = projectMatches[0]
   endif
   return project
endfunction

" AddDirectory ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Adds dir to project. Properly handles "\"'s, pre-existence, and
"            relative paths
"     input   - project: [Dictionary] The dictionary to add the dir to
"               dir: [string] the dir to add to the project
"     returns - [bool] True if add succeeded
function! AddDirectory(project, dir, relative)
   if isdirectory(a:dir)
      if (a:relative == "R")
         let expandedDir = a:dir
      else
         let expandedDir = ExpandDir(a:dir, 0)
      endif

      if !count(g:ProjectManager[a:project]["dirs"], expandedDir) "Make sure it doesn't already exist
         call add(g:ProjectManager[a:project]["dirs"], expandedDir)
         echo "\n" expandedDir . " added!"
      else
         echo "\n"
         echohl ERROR
         echon expandedDir . " already exists in project "
         echon a:project . "!"
         echohl NORMAL
      endif
      return 1
   elseif (a:dir != "q")
      echohl ERROR
      echo "\n"
      echo a:dir . " directory doesn't exist!\n"
      echohl NORMAL
      return -1
   endif
   return 0
endfunction

" PrintProject ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Prints out given project in a clean looking manner
"     input - inputProject: [string] the project to print or the string "@||"
"                           to print all projects
"             option: - [int] 0: normal operation
"                             1: print numbers before dirs
"                             2: omit dirs in print
"             returns - void
function! PrintProject(inputProject, option)
   silent! call ClearScreen()
   let l:projectList = []
   if a:inputProject == "@||"
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
      if (project == s:activeProject)
         echo project . ":  < < < < < < < < < <\n"
      else
         echo project . ":\n"
      endif
      if a:option != 2
         for dir in copy(g:ProjectManager[project]["dirs"])
            echo "\t" . (a:option == 1? "(" . counter . ")" : "") dir . "\n"
            let counter += 1
         endfor
      endif
   endfor
   echo "\n"
endfunction

" ClearScreen <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Clears command line.
"     input   - void
"     returns - void
function! ClearScreen()
   let &ch=&lines-1
   redraw!
   let &ch=1
endfunction

" SaveProject <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Saves project information to s:projectFile
"     input   - void
"     returns - void
function! SaveProject()
   let l:mySaveList = []
   for project in sort(keys(g:ProjectManager))
      call add(mySaveList, project." ".g:ProjectManager[project]["type"])
      for dir in copy(g:ProjectManager[project]["dirs"])
         call add(l:mySaveList, "\t" . dir)
      endfor
   endfor
   call writefile(l:mySaveList, s:projectFile)
endfunction

" LoadProject <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Loads project information stored at s:projectFile
"     input   - void
"     returns - void
function! LoadProject()
   if exists("g:ProjectManager")
      unlet g:ProjectManager
   endif
   let g:ProjectManager = {}
   if filereadable(s:projectFile)
      let l:mySaveList = readfile(s:projectFile)
      for line in l:mySaveList
         if (split(line, '\zs')[0] != "\t")
            " Split into list of characters and looks at the first one
            let l:currentProject = split(line)[0]
            let l:currentProjecttype = split(line)[1]
            let g:ProjectManager[currentProject] = {"type":currentProjecttype, "dirs":[], "name":currentProject}
         else
            if has_key(g:ProjectManager, currentProject)
               call add (g:ProjectManager[currentProject]["dirs"], substitute(line, "\t", "", "g"))
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
"  brief: Expands relative directories to absolute as well as takes out any
"         Win-slashes.
"     input   - dir: [string] the directory to expand
"     input   - trailingSlashFlag: [bool] returns a string with a trailing slash
"               if true, without if false.
"     returns - dir: [string] the expanded directory
function! ExpandDir(dir, trailingSlashFlag)
   let newDir = a:dir
   if (a:trailingSlashFlag)
      let newDir = fnamemodify(newDir, ":p")
   else
      let newDir = fnamemodify(newDir, ":p:h")
   endif
   let newDir = substitute(newDir, "\\", "/", "g")

   return newDir
endfunction

" ProjectCompletion <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: This is a custom completion function that will complete the list of
"         commands, projects, or directories based on which argument the
"         user is currently typing.
"     input/returns - see :h command-completion-custom
function! ProjectCompletion(arg, line, pos)
   let returnString = ""
   if (a:line =~ "^ProjSelect ")
      let argList = a:arg
      for project in keys(g:ProjectManager)
         let returnString .= project . "\n"
      endfor
      return returnString
   else
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
         if (argList[0] == "rename")
            " renames third argument is brand new and there's noting to complete
            return ""
         else
            let returnStringList = split(globpath(ExpandDir(argList[2], 0), '*'), "\0")
            for line in returnStringList
               if isdirectory(line)
                  let returnString .= argList[0] . " " . argList[1] . " " . line . "\n"
               endif
            endfor
            return(returnString)
         endif
      endif
   endif
endfunction

" FormatVimGrepFiles ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Gets the current projects directories and formats them properly for
"          a vimgrep.
"     input   - void
"     returns - [string] A string containing all properly formated directories
"               from the current project.
function! FormatVimGrepFiles(dirList)
   let myReturnString = ""
   if len(a:dirList) > 0
      for dir in a:dirList
         let myReturnString .= " " . dir . "/*"
      endfor
   else
      let myReturnString = './*'
   endif
   return myReturnString
endfunction

" ProjectVimGrep ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
function! ProjectVimGrep(searchWord)
   let origdir = getcwd()
   " Save for later

   let ReturnedProjectStruct = ReturnProject(getcwd())
   let project = ReturnedProjectStruct[0]
   let projectRoot = ReturnedProjectStruct[1]

   let searchDirs = FormatVimGrepFiles(project.dirs)
   exe "cd " . projectRoot
   " Change directory so that our relative projects can have the correct
   "   starting point

   exe "lvimgrep /" . a:searchWord."/j " . searchDirs
   lw
   exe "normal! \<C-W>j\<CR>"
   let @/ = a:searchWord
   cclose
   call setqflist([])

   exe "cd " . origdir
   " Back to where we started

   set hlsearch
endfunction

" StartDirSearch ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: A wrapper to DirSearch. Prompts the user for input and then passes it
"          to DirSearch.
"     input   - void
"     returns - void
function! StartDirSearch()
   cclose
   call setqflist([])
   echo getcwd()
   let pattern = input(":DirectorySearch ", "", "tag")
   call DirSearch(pattern)
endfunction

" DirSearch <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Takes a pattern and searches the whole directory (or project) for
"            matches.
"     input   - input: [string] A regex pattern to search for
"               (use \r for recursive or \R for recursive from parent directory)
"     returns - void
function! DirSearch(input)
   if len(a:input)
      try
         let search = ""
         let recurse = 0
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
         if (recurse)
            exec "lvimgrep /" . search . "/j ./**"
         else
            call ProjectVimGrep(search)
         endif
         lw
         let @/ = search
         exec feedkeys("\<CR>\<C-K>")
      catch /^Vim\%((\a\+)\)\=:E480/
         " E480: No match
         " Not an error, but still need to inform the user that their search failed
         call EchoError(matchstr(v:exception, 'No.*'))
      endtry
   endif
endfunction

" TraverseCtag ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Goes to tag under cursor but tries to intelligently open it in a new
"          split or tab based on certain stimuli. Also tries to generate a tag
"          file if there isn't one.
"     input   - (optonal) If present, it will not try to generate a tag file and
"               try again.
"     returns - void
function! TraverseCtag(...)
   try
      " If it's part of a project then look in the "root" directory of the
      "   project for the tags file.
      let ReturnedProjectStruct = ReturnProject(getcwd())
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
      " This is <A-q>
      normal ñ
      let l:windowNr = winnr("$")
      let tag = expand('<cword>')
      let tagFile = ReturnTagFile(tag)
      if (&columns >= (80 * (l:windowNr + 1)))
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
   catch /^Vim\%((\a\+)\)\=:E433/
      "No tag file, try to generate them and retry
      if (a:0 == 0)
         silent call GenerateCTags()
         call TraverseCtag('Non-recursive')
      else
         " Base case: Tried but couldn't generate c-tags.
         "   Quit superfluous buffer
         quit
      endif
   catch /^Vim\%((\a\+)\)\=:E426/
      "Tag not found
      if (tabpagenr() != initialTabNum)
         tabclose
      elseif (winnr("$") > initialWinNum)
         quit
      endif
      call EchoError(matchstr(v:exception, '\(E\d\+:\s*\)\@<=.*$'))
   endtry
endfunction

" GenerateCTags <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Generates a tag file for your whole project. This function assumes
"          that you have Ctags installed.
"          (Also adds a Microchip directory if it exists.)
"     input   - void
"     returns - void
function! GenerateCTags()
   let currentwd = ExpandDir(getcwd(), 0)
   let dirs = ReturnProjectDirectories(currentwd)
   let microchipDirectoryExist = 0
   if len(dirs) == 0
      exe "silent!! ctags " . FormatVimGrepFiles(dirs)
   else
      if isdirectory(ExpandDir("..\Microchip", 0))
         let microchipDirectoryExist = 1
      endif
      if (ExpandDir(dirs[0], 0) == currentwd)
         exe "silent!! ctags " . FormatVimGrepFiles(dirs)
         if (microchipDirectoryExist)
            exe "silent!! ctags -aR ../Microchip/*"
         endif
      else
         exe "cd " . ExpandDir(dirs[0], 0)
         exe "! ctags " . FormatVimGrepFiles(dirs)
         if (microchipDirectoryExist)
            exe "silent!! ctags -aR ../Microchip/*"
         endif
         exe "cd " . currentwd
      endif
   endif
endfunction

" ReturnTagFile <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Finds the file that a tag resides in. If there are more than one, it
"            takes the first one.
"     input   - tag: [string] What tag we're searching for
"     returns - [string] The file that the tag resides in or empty if the tag
"               doesn't exist
function! ReturnTagFile(tag)
   try
      let tagString = split(execute("tselect ".a:tag), "\n")[1]
      let tagString = matchstr(tagString, '[^/\\]*$')
      return tagString
   catch /^Vim\%((\a\+)\)\=:E426/
      return ""
   endtry
endfunction


"<< End of Vim Project Manager plugin <><><><><><><><><><><><><><><><><><><><><>
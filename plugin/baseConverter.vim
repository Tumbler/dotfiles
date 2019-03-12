" @Tracked
" Base Conversion Plugin
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 12/08/2017 05:02 PM
let s:Version = 1.06

" TODO Leading zeros doesn't work if you have more than 1 nibbles worth of zeros

" Anti-inclusion guard and version
if (exists("g:loaded_baseConverter") && (g:loaded_baseConverter >= s:Version))
   finish
endif
let g:loaded_baseConverter = s:Version

" Options
if (!exists("g:baseConverter_leading_binary_zeros"))
   let g:baseConverter_leading_binary_zeros = 0
endif

command! -nargs=1 Hexcon call <SID>HexConverter('<args>')
" Automatically detect base and convert into 4 most common bases
command! -nargs=+ Base2Base try | echo <SID>BaseConversion(<f-args>) | catch | catch /^Vim\%((\a\+)\)\=:E119/ let g:blarg = 41 | endtry

" Convert any base to any other (2-16)
command! ASCII call <SID>PrintASCIIChart()
" Prints out a staic table for quick number to ASCII conversions

nnoremap <A-f> :call <SID>HexConverter(expand('<cword>'))<CR>
" Brings up the hex converter on number under cursor

if has("autocmd")
augroup BaseConversion
   au!
   autocmd CursorMovedI * call <SID>CheckConversions()
augroup END
endif

" CheckConversions ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Takes word under cursor and determines if it's a number. If it is it
"          will pull up a conversion list, either in the completion list or in
"          a command line print out. (This function is called automatically
"          from a CursorMovedI event)
"    input   - void
"    returns - void
function! s:CheckConversions()
   let column = col('.')
   let wordBeforeCursor = matchstr(getline('.'), '\c\<[0-9a-fx]\+\.\=\x\+\%'.column.'c')
   let wordAfterCursor = matchstr(getline('.'), '\c\%'.(column-1).'c[0-9a-fx]\+\.\=\x\+')
   if (strlen(wordAfterCursor) == 0)
      " None of the word is after the cursor
      let base = s:FindBase(wordBeforeCursor)
      let rawNumber = s:StripLeader(wordBeforeCursor, base)
      let beginingColumn = col('.') - strlen(wordBeforeCursor)

      if (base != 0 && s:IsNumber(rawNumber, base) && rawNumber =~ '\S\{2,}')
         call s:ListConversions(base, rawNumber, beginingColumn, wordBeforeCursor)
      endif
   else
      " Some of the number resides after the cursor... completing not possible

      " This section used to pull up the conversions in a command line print
      " out as you typed, but it wasn't very useful and had some annoying bugs,
      " so I've removed it for now.
   endif
endfunction

" ListConversions <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Calls up a completion popup with conversion suggestions.
"    input   - base: [int] Base The base that the original number is in
"              rawNumber: [int] The number that needs to be converted
"              column: [int] The starting point of the number we're completing
"              origWord: [string] The text that we're completing against
"    returns - void
function! s:ListConversions(base, rawNumber, column, origWord)
   let label = '   ' . {2: 'BIN', 8: 'OCT', 10: 'DEC', 16: 'HEX'}[a:base]
   let decNumber = s:BaseConversion(a:rawNumber, a:base, 10)
   call complete(a:column, [
        \ {'word':a:origWord, 'menu':label},
        \ {'word':s:BaseConversion(a:rawNumber, a:base,  2, 1), 'menu': '   BIN'},
        \ {'word':s:BaseConversion(a:rawNumber, a:base,  8, 1), 'menu': '   OCT'},
        \ {'word':s:BaseConversion(a:rawNumber, a:base, 10, 1), 'menu': '   DEC'},
        \ {'word':s:BaseConversion(a:rawNumber, a:base, 16, 1), 'menu': '   HEX'},
        \ (decNumber > 31 && decNumber < 127)?
        \ {'word':nr2char(s:BaseConversion(a:rawNumber, a:base, 10, 1)), 'menu': ' ASCII'} : {}])
endfunction

" HexConverter ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Brings up a command line print out of conversion suggestions.
"    input   - wordUnderCursor: [string] The number to try to convert
"              optional: [bool] If present won't shift window
"    returns - void
function! s:HexConverter(wordUnderCursor, ...)
   if !exists('t:baseConverter_inConvertMode')
      let t:baseConverter_inConvertMode = 0
   endif
   if !exists('t:baseConverter_lastCheck')
      let t:baseConverter_lastCheck = ''
   endif
   let base = s:FindBase(a:wordUnderCursor)
   let rawNumber = s:StripLeader(a:wordUnderCursor, base)
   if (strlen(a:wordUnderCursor) > 0)
      let N = strlen(s:BaseConversion(rawNumber, base, 2, 1))
   endif
   let shift = 0
   if (a:0 > 0)
      let winPercent = (winline()*100)/winheight(0)
      if (winPercent <= 10)
         let shift = 0
      elseif (winPercent < 36)
         let shift = 1
      elseif (winPercent < 65)
         let shift = 2
      elseif (winPercent < 89)
         let shift = 3
      else
         let shift = 4
      endif
   endif

   if (base != 0 && s:IsNumber(rawNumber, base) && a:wordUnderCursor =~ '\S\{2,}' && (a:0 || (t:baseConverter_lastCheck != a:wordUnderCursor)) && strlen(a:wordUnderCursor) > 0)
      if (!t:baseConverter_inConvertMode)
         set cmdheight=5
         if (shift)
            execute 'call feedkeys("\<C-o>'.shift.'\<C-y>")'
         endif
         let t:baseConverter_inConvertMode = 1
      endif
      exe "echo '  BIN: ' . printf('%".N."s', s:BaseConversion(rawNumber, base, 2, 1)) .'\n'." .
          \    "'  OCT: ' . printf('%".N."s', s:BaseConversion(rawNumber, base, 8, 1)) .'\n'." .
          \    "'  DEC: ' . printf('%".N."s', s:BaseConversion(rawNumber, base, 10, 1)).'\n'." .
          \    "'  HEX: ' . printf('%".N."s', s:BaseConversion(rawNumber, base, 16, 1))"
   else
      if (t:baseConverter_inConvertMode)
         set cmdheight=1
         if (shift)
            execute 'call feedkeys("\<C-o>'.shift.'\<C-e>")'
         endif
         let t:baseConverter_inConvertMode = 0
      endif
   endif
   if (t:baseConverter_lastCheck != a:wordUnderCursor)
      let t:baseConverter_lastCheck = a:wordUnderCursor
   else
      let t:baseConverter_lastCheck = ''
   endif
endfunction

" FindBase ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Does it's best to guess the base of the number.
"    input   - number: [string] The number from which to determine the base
"    returns - [int] The base number (2 for binary, 10 for decimal, etc...)
function! s:FindBase(number)
   if     (a:number[0:1] == '0b' && s:IsNumber(a:number[2:], 2))
      return 2
   elseif (a:number[0:1] =~ '0[0-7]' && s:IsNumber(a:number[2:], 8))
      return 8
   elseif (a:number[0:1] =~ '0x\c' && s:IsNumber(a:number[2:], 16))
      return 16
   elseif (s:IsNumber(a:number, 10))
      return 10
   elseif (s:IsNumber(a:number, 16))
      return 16
   else
      return 0
   endif
endfunction

" IsNumber ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Looks at all the digits of a given number and determines if it is a
"          valid number for the given base.
"    input   - number: [string] The number to check
"              base: [int] The base to check for
"    returns - [bool] True if valid, false if invalid
let s:digitList = {2: '[01.]', 8: '[0-7.]', 10: '[0-9.]', 16: '[0-9a-f.]'}
function! s:IsNumber(number, base)
   return (a:number =~ '^'.s:digitList[a:base].'\+$')
endfunction

" BaseConversion ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Convert any base [2-16] to any other base [2-16].
"    input   - num: [string] A string containing the number to convert
"              inbase: [int] The base of the number to convert
"              outbase: [int] The desired base
"              optional: [bool] Whether or not to prepend a base leader (i.e. 0x)
"    returns - [string] The input number converted to the base specified
let s:prefixes = {2: '0b', 8: '0', 10: '', 16: '0x'}
function! s:BaseConversion(num, inBase, outBase, ...)
   if (a:outBase < 2 || a:outBase > 16)
      call EchoError("Out base must be between 2 and 16!")
   else
      let splitNum = split(a:num, '\.')
      let decNum = s:Base2Dec(splitNum[0], a:inBase)
      let decimalPrecision = 0
      if (len(splitNum) > 1)
         let decNum .= '.'.s:Frac2Dec(splitNum[1], a:inBase)
         let decimalPrecision = len(splitNum[1])
      endif
      let prefix = get(s:prefixes, a:outBase, '')
      return ((a:0)? prefix : "") . s:Decimal2Base(decNum, a:outBase, decimalPrecision)
   endif
endfunction!

" Decimal2Base ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Convert any decimal float to any base = [2-16]
"   input   - number: [string] String representation of decimal float to convert
"             base: [int] Desired base
"             decimalPrecision: [int] If number has a radix portion, how many
"                               places after the radix point before rounding
"   returns - [string] String representation of base [base] number
function! s:Decimal2Base(number, base, decimalPrecision)
   let splitNum = split(a:number, '\.')
   let result = 0
   if (len(splitNum) > 1)
      let precision = (a:decimalPrecision > 4) ? (a:decimalPrecision) : 4
      let result = s:Frac2Base('.'.splitNum[1], a:base, a:decimalPrecision)
      if (result == 1)
         let result = s:AddLeadingZeros(s:Dec2Base(splitNum[0]+1, a:base), a:base)
      else
         let result = s:AddLeadingZeros(s:Dec2Base(splitNum[0], a:base), a:base) . result
      endif
      " Remove any trailing zeros
      return substitute(result, '\..*\zs0\+$', '', '')
   else
      return s:AddLeadingZeros(s:Dec2Base(splitNum[0], a:base), a:base)
   endif
endfunction

" AddLeadingZeros <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: If the number is binary and the g:baseConverter_leading_binary_zeros
"          option is set, then add leading zeros until number is a valid nibble.
"   input   - string: [string] A string representation of an integer binary
"                     number (non-binary numbers get ignored)
"             base: [int] A number describing the base of the number
"   returns - [string] The string representation of the number with the
"             appropriate amount of leading zeros appended to the beginning
function! s:AddLeadingZeros(string, base)
   " Only works in binary
   let outString = a:string
   if (a:base == 2 && g:baseConverter_leading_binary_zeros)
      while (len(outString) % 4 != 0)
         let outString = 0 . outString
      endwhile
   endif
   return outString
endfunction

" Base2Dec ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Convert any base [2-16] to decimal.
"    input   - number: [string] String representation of an int to convert
"              base: [int] This is the base of the input "number"
"    returns - [int] Number converted to decimal
function! s:Base2Dec(number, base)
   let hexdig='0123456789abcdef'
   let result = 0
   let position = 0
   let length = strlen(a:number)
   while position < length
      let digitString = a:number[position]
      let digitInt = match(hexdig, digitString.'\c')
      let result = result * a:base + digitInt
      let position += 1
   endwhile
   return result
endfunction

" Dec2Base ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Convert decimal integer to any base [2-16]
"    input   - number: [string] String representation of a decimal number to
"                      convert
"              base: [int] Desired base
"    returns - [int] Number converted to [base]
function! s:Dec2Base(number, base)
   let nr = str2float(a:number)
   let result = ''
   while (nr >= 1)
      let intresstr = printf("%f", nr / a:base)
      let intresstr = substitute(intresstr, '\.\d\+$', '', '')
      let intres = str2float(intresstr)
      let modres = float2nr(nr - intres * a:base)
      let result = printf("%x",modres) . result
      let nr = intres
   endwhile
   if (result == '')
      let result = '0'
   endif
   return toupper(result)
endfunction

" Frac2Base <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Takes a decimal float less than one (a fraction) and converts it to a
"          different base [2-16]
"    input   - number: [string] String representation of a fraction (i.e. .25)
"              base: [int] Desired base
"              precision: [int] How many digits to compute before rounding
"                 (min 4)
"    returns - [string] String representation of fraction converted to new [base]
function! s:Frac2Base(number, base, precision)
   let hexdig='0123456789ABCDEF'
   let fraction = str2float(a:number)
   let loopCounter = 0
   let result = '.'
   let remainder = fraction
   while (remainder > 0 && ((loopCounter < a:precision) || (loopCounter < 4)))
      let multiplied = remainder * a:base
      let digit = float2nr(multiplied)
      let remainder = multiplied - digit
      let result .= hexdig[digit]
      let loopCounter += 1
   endwhile
   if (remainder != 0)
      let multiplied = remainder * a:base
      let digit = float2nr(multiplied)
      if (digit >= (a:base+1)/2)
         "Need to round
         let index = stridx(hexdig, result[loopCounter])+1
         let numOfTurnovers = 0
         let fullTurnover = 0
         while (index >= a:base)
            let result = result[:-2]
            let numOfTurnovers += 1
            if (numOfTurnovers == loopCounter)
               let fullTurnover = 1
               break
            endif
            let index = stridx(hexdig, result[loopCounter-numOfTurnovers])+1
         endwhile
         if (!fullTurnover)
            let result = result[:loopCounter-numOfTurnovers-1] . hexdig[index]
         else
            let result = 1
         endif
      endif
   endif
   return result
endfunction

" Frac2Dec ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Takes a float less than one (a fraction) in any base [2-16] and
"          converts it to a decimal fraction.
"    input   - number: [string] String representation of fraction (i.e. .25)
"              base: [int] Base of the input number [2-16]
"    returns - [string] String representation of decimal fraction
function! s:Frac2Dec(number, base)
   if (a:base >= 2 && a:base <= 16)
      let hexdig='0123456789abcdef'
      let result = 0.0
      let value  = 0.0
      let pos = 0
      let len = strlen(a:number)
      while pos < len
         let digit = a:number[pos]
         let value = match(hexdig, digit.'\c')
         let result += (value / pow(a:base, (pos+1.0)))
         let pos += 1
      endwhile
      let stringResult = substitute(printf('%.16f', result)[2:], '0\+$', '', '')
      return stringResult
   else
      return 0
   endif
endfunction

" StripLeader <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Takes a string representation of a number and removes any header that
"          isn't a valid digit. (i.e. 0x for hex)
"    input   - number: [string] String representation of the number to strip
"              base: [int] Base of input number
"    returns - [string] String representation of the number without the header
function! s:StripLeader(number, base)
   if (a:base == 2)
      return substitute(a:number, '^0b\c', '', '')
   elseif (a:base == 8)
      return substitute(a:number, '^0', '', '')
   elseif (a:base == 10)
      return a:number
   elseif (a:base == 16)
      return substitute(a:number, '^0x\c', '', '')
   else
      return 0
   endif
endfunction

" PrintASCIIChart <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"   brief: Prints a static chart of ASCII values so I can stop looking it up
"    input   - void
"    returns - void
function! s:PrintASCIIChart()
   echo "| DEC HEX OCT CHR | DEC HEX OCT CHR | DEC HEX OCT CHR | \n"
   let start = 32
   while (start <= 63)
      for i in [0, 1, 2]
         let number = start + (i * 32)
         echon "| "
         echon repeat(" ", 3-len(number))
         echon number
         echon "  "
         echohl PREPROC
         echon s:BaseConversion(number, 10, 16) . " "
         echohl NONE
         let oct = s:BaseConversion(number, 10, 8)
         echon repeat(" ", 3-len(oct))
         echon oct . "  "
         echohl PREPROC
         echon nr2char(number)
         echohl NONE
         echon "  "
      endfor
      echon "|\n"
      let start += 1
   endwhile
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
"<< End of base Conversion plugin <><><><><><><><><><><><><><><><><><><><><><><>
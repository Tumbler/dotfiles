" @Tracked
" Base Conversion Plugin
" Author: Tumbler Terrall [TumblerTerrall@gmail.com]
" Last Edited: 12/13/2016 03:00 PM
" Version: 1.2

let g:vimBaseConversion = 1

command! -nargs=1 Hexcon call HexConverter('<args>')
" Automatically detect base and convert into 4 most common bases
command! -nargs=+ Base2Base echo BaseConversion(<f-args>)
" Convert any base to any other (2-16)
command! ASCII call PrintASCIIChart()
" Prints out a staic table for quick number to ASCII conversions

nnoremap <A-f> :call HexConverter(expand('<cWORD>'))<CR>
" Brings up the hex converter on number under cursor

if has("autocmd")
augroup BaseConversion
   au!
   autocmd CursorMovedI * call CheckConversions()
augroup END
endif

" CheckConversions
"  brief: Takes word under cursor and determines if it's a number. If it is it
"            will pull up a conversion list, either in the completion list or in
"            a command line print out. (This function is called automatically
"            from a CursorMovedI event)
"    input   - void
"    returns - void
function! CheckConversions()

   let column = col('.')
   let wordBeforeCursor = substitute(getline('.'), '\c.\{-}\(\<[0-9a-fx]\+\.\=\x\+\)\%'.column.'c.*', '\1', '')
   let wordAfterCursor = substitute(getline('.'), '\c.\{-}\%'.column.'c\([0-9a-fx]\+\.\=\x\+\).*', '\1', '')
   if (strlen(wordAfterCursor) == strlen(getline('.')))
      let base = FindBase(wordBeforeCursor)
      let rawNumber = StripLeader(wordBeforeCursor, base)
      let beginingColumn = col('.') - strlen(wordBeforeCursor)

      if (base != 0 && IsNumber(rawNumber, base) && rawNumber =~ '\S\{2,}')
         call ListConversions(base, rawNumber, beginingColumn, wordBeforeCursor)
      endif
   else
      " Some of the number resides after the cursor... completing not possible
      let wholeWordUnderCursor = (wordBeforeCursor.wordAfterCursor)
      if (wholeWordUnderCursor =~ '[0-9a-fx]\+\.\=\x\+')
         let base = FindBase(wholeWordUnderCursor)
         let rawNumber = StripLeader(wholeWordUnderCursor, base)
         call HexConverter(wordBeforeCursor.wordAfterCursor, 1)
      endif
   endif
endfunction

" ListConversions
"  brief: Calls up a completion popup with conversion suggestions.
"    input   - base: [int] base The base that the original number is in
"              rawNumber: [int] The number that needs to be converted
"              column: [int] The starting point of the number we're completing
"              origWord: [string] The text that we're completing against
"    returns - void
function! ListConversions(base, rawNumber, column, origWord)
   let label = '   ' . {2: 'BIN', 8: 'OCT', 10: 'DEC', 16: 'HEX'}[a:base]
   let decNumber = BaseConversion(a:rawNumber, a:base, 10)
   call complete(a:column, [
        \ {'word':a:origWord, 'menu':label},
        \ {'word':BaseConversion(a:rawNumber, a:base,  2, 1), 'menu': '   BIN'},
        \ {'word':BaseConversion(a:rawNumber, a:base,  8, 1), 'menu': '   OCT'},
        \ {'word':BaseConversion(a:rawNumber, a:base, 10, 1), 'menu': '   DEC'},
        \ {'word':BaseConversion(a:rawNumber, a:base, 16, 1), 'menu': '   HEX'},
        \ (decNumber > 31 && decNumber < 127)?
        \ {'word':nr2char(BaseConversion(a:rawNumber, a:base, 10, 1)), 'menu': ' ASCII'} : {}])
endfunction

" HexConverter
"  brief: Brings up a command line print out of conversion suggestions.
"    input   - wordUnderCursor: [string] The number to try to convert
"              optional: [bool] If present won't shift window
"    returns - void
function! HexConverter(wordUnderCursor, ...)
   if !exists('t:inConvertMode')
      let t:inConvertMode = 0
   endif
   if !exists('t:lastCheck')
      let t:lastCheck = ''
   endif
   let base = FindBase(a:wordUnderCursor)
   let rawNumber = StripLeader(a:wordUnderCursor, base)
   if (strlen(a:wordUnderCursor) > 0)
      let N = strlen(BaseConversion(rawNumber, base, 2, 1))
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

   if (base != 0 && IsNumber(rawNumber, base) && a:wordUnderCursor =~ '\S\{2,}' && (a:0 || (t:lastCheck != a:wordUnderCursor)) && strlen(a:wordUnderCursor) > 0)
      if (!t:inConvertMode)
         set cmdheight=5
         if (shift)
            execute 'call feedkeys("\<C-o>'.shift.'\<C-y>")'
         endif
         let t:inConvertMode = 1
      endif
      exe "echo '  BIN: ' . printf('%".N."s', BaseConversion(rawNumber, base, 2, 1)) .'\n'." .
          \    "'  OCT: ' . printf('%".N."s', BaseConversion(rawNumber, base, 8, 1)) .'\n'." .
          \    "'  DEC: ' . printf('%".N."s', BaseConversion(rawNumber, base, 10, 1)).'\n'." .
          \    "'  HEX: ' . printf('%".N."s', BaseConversion(rawNumber, base, 16, 1))"
   else
      if (t:inConvertMode)
         set cmdheight=1
         if (shift)
            execute 'call feedkeys("\<C-o>'.shift.'\<C-e>")'
         endif
         let t:inConvertMode = 0
      endif
   endif
   if (t:lastCheck != a:wordUnderCursor)
      let t:lastCheck = a:wordUnderCursor
   else
      let t:lastCheck = ''
   endif
endfunction

" FindeBase ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
"  brief: Does it's best to guess the base of the number.
"    input   - number: [string] The number from which to determin the base
"    returns - [int] The base number (2 for binary, 10 for decimal, etc...)
function! FindBase(number)
   if     (a:number[0:1] == '0b' && IsNumber(a:number[2:], 2))
      return 2
   elseif (a:number[0:1] =~ '0[0-7]' && IsNumber(a:number[2:], 8))
      return 8
   elseif (a:number[0:1] =~ '0x\c' && IsNumber(a:number[2:], 16))
      return 16
   elseif (IsNumber(a:number, 10))
      return 10
   elseif (IsNumber(a:number, 16))
      return 16
   else
      return 0
   endif
endfunction

" IsNumber
"  brief: Looks at all the digits of a given number and determines if it is a
"            valid number for the given base.
"    input   - number: [string] The number to check
"              base: [int] The base to check for
"    returns - [bool] True if valid, false if invalid
function! IsNumber(number, base)
   let digitList = {2: '[01.]', 8: '[0-7.]', 10: '[0-9.]', 16: '[0-9a-f.]'}
   for char in split(a:number, '\zs')
      if char !~ digitList[a:base]
         return 0
      endif
   endfor
   return 1
endfunction

" BaseConversion
"  brief: Convert any base [2-16] to any other base [2-16].
"    input   - num: [string] A string containing the number to convert
"              inbase: [int] The base of the number to convert
"              outbase: [int] The desired base
"              optional: [bool] Whether or not to prepend a base leader (i.e. 0x)
"    returns - void
function! BaseConversion(num, inBase, outBase, ...)
   let splitNum = split(a:num, '\.')
   let decNum = Base2Dec(splitNum[0], a:inBase)
   let decimalPrecision = 0
   if (len(splitNum) > 1)
      let decNum .= '.'.Frac2Dec(splitNum[1], a:inBase)
      let decimalPrecision = len(splitNum[1])
   endif
   if     (a:outBase == 2)
      return (a:0)?"0b".Decimal2Base(decNum, 2, decimalPrecision):Decimal2Base(decNum, 2, decimalPrecision)
   elseif (a:outBase == 8)
      return (a:0)?"0" .Decimal2Base(decNum, 8, decimalPrecision):Decimal2Base(decNum, 8, decimalPrecision)
   elseif (a:outBase == 10)
      return Decimal2Base(decNum, 10, decimalPrecision)
   elseif (a:outBase == 16)
      return (a:0)?"0x".Decimal2Base(decNum, 16, decimalPrecision):Decimal2Base(decNum, 16, decimalPrecision)
   else
      return Decimal2Base(decNum, a:outBase, decimalPrecision)
   endif
endfunction!

" Decimal2Base
"  brief: Convert any decimal float to any base = [2-16]
"   input   - number: [string] String representation of decimal float to convert
"             base: [int] Desired base
"             decimalPrecision: [int] If number has a radix portion, how many
"                               places after the radix point before rounding
"   returns - [string] String representation of base [base] number
function! Decimal2Base(number, base, decimalPrecision)
   let splitNum = split(a:number, '\.')
   let result = 0
   if (len(splitNum) > 1)
      let precision = (a:decimalPrecision > 4) ? (a:decimalPrecision) : 4
      let result = Frac2Base('.'.splitNum[1], a:base, a:decimalPrecision)
      if (result == 1)
         let result = Dec2Base(splitNum[0]+1, a:base)
      else
         let result = Dec2Base(splitNum[0], a:base) . result
      endif
      return substitute(result, '\..*\zs0\+$', '', '')
   else
      return Dec2Base(splitNum[0], a:base)
   endif
endfunction

" Base2Dec
"  brief: Convert any base [2-16] to decimal.
"    input   - number: [string] String representation of an int to convert
"              base: [int] Base of input number
"    returns - [int] Number converted to decimal
function! Base2Dec(number, base)
   let hexdig='0123456789abcdef'
   let result = 0
   let pos = 0
   let len = strlen(a:number)
   while pos < len
      let x = strpart(a:number, pos, 1)
      let d = match(hexdig, x.'\c')
      let result = result * a:base + d
      let pos = pos + 1
   endwhile
   return result
endfunction

" Dec2Base
"  brief: Convert decimal integer to any base [2-16]
"    input   - number: [string] String representation of a decimal number to
"                      convert
"              base: [int] Desired base
"    returns - [int] Number converted to [base]
function! Dec2Base(number, base)
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

" Frac2Base
"  brief: Takes a decimal float less than one (a fraction) and converts it to a
"            different base [2-16]
"    input   - number: [string] String representation of a fraction (i.e. .25)
"              base: [int] Desired base
"              precision: [int] How many digits to compute before rounding
"                 (min 4)
"    returns - [string] String representation of fraction converted to new [base]
function! Frac2Base(number, base, precision)
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
         let index = match(hexdig, result[loopCounter])+1
         let numOfTurnovers = 0
         let fullTurnover = 0
         while (index >= a:base)
            let result = result[:-2]
            let numOfTurnovers += 1
            if (numOfTurnovers == loopCounter)
               let fullTurnover = 1
               break
            endif
            let index = match(hexdig, result[loopCounter-numOfTurnovers])+1
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

" Frac2Dec
"  brief: Takes a float less than one (a fraction) in any base [2-16] and
"            converts it to a decimal fraction.
"    intput  - number: [string] String representation of fraction (i.e. .25)
"              base: [int] Base of the input number [2-16]
"    returns - [string] String representation of decimal fraction
function! Frac2Dec(number, base)
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

" StripLeader
"  brief: Takes a string representation of a number and removes any header that
"            isn't a valid digit. (i.e. 0x for hex)
"    input   - number: [string] String representation of the number to strip
"              base: [int] Base of input number
"    returns - [string] String representation of the number without the header
function! StripLeader(number, base)
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

" PrintASCIIChart
"  brief: Prints a static chart of ASCII values so I can stop looking up
function! PrintASCIIChart()
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
         echon BaseConversion(number, 10, 16) . " "
         echohl NONE
         let oct = BaseConversion(number, 10, 8)
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
"<< End of base Conversion plugin <><><><><><><><><><><><><><><><><><><><><><><>

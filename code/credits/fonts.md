# Super Metroid Fonts in Credits

Font characters are represented as two byte words. A character can either take up a
single line or a double line.

## Single Line Fonts

Single line fonts require one tile to represent a character.
They are made up of 32 characters that start at
a base value and increment like this:

`00-19 = A-Z`

`1A = .`  
`1B = ,`  
`1C = .`  
`1D = '`  
`1E = :`  
`1F = !`  

## Double Line Fonts

Double line fonts require two tiles (top & bottom) to represent
a character.

`20-2f`  
`30-3f = A-P`

`40-49`  
`50-59 = Q-Z`

`4a`  
`7f = '`

`4b`  
`7f = "`

`4c-4e = TIME (one line, always white)`

`4f = space`

`7f`  
`5a = .`

`5a`  
`5a = :`

`5b-5f`  
`6b-6f = アイテム発 (item counter)`

`60-69`  
`70-79 = 0-9`

`6a`  
`7a = %`

`7b`  
`7c = &`

`7d`  
`7e = 1`

`7f = space`

## Colors

Colors for the fonts are determined based on the base value
(i.e. `0001 = white B`, `0401 = yellow B`). The following colors
are available:

`00 = white`  
`04 = yellow`  
`08 = cyan`  
`0C = green`  
`10 = pink`  
`14 = blue`  
`18 = orange`  
`1C = purple`

define white = $0000
define yellow = $0400
define cyan = $0800
define green = $0C00
define pink = $1000
define blue = $1400
define orange = $1800
define purple = $1C00

namespace fonts {

   macro load_single(define base) {
      map 'A',{base},26
      map '.',{base}+$1A
      map ',',{base}+$1B
      map '_',{base}+$1C
      map '\'',{base}+$1D
      map ':',{base}+$1E
      map '!',{base}+$1F
      map ' ',$007F
   }

   macro load_double_top(define base) {
      map 'A',{base}+$20,16
      map 'Q',{base}+$40,10
      map '\'',{base}+$4a    // single quote
      map '^',{base}+$4b     // double quote
      map '.',$007f          // period (blank on top)
      map ':',{base}+$5a     // colon (period on top & bottom)
      map '0',{base}+$60,10
      map '%',{base}+$6a
      map '&',{base}+$7b
      map ' ',$007f
   }

   macro load_double_bottom(define base) {
      map 'A',{base}+$30,16
      map 'Q',{base}+$50,10
      map '\'',$007f         // single quote (blank on bottom)
      map '^',$007f          // double quote (blank on bottom)
      map '.',{base}+$5a     // period
      map ':',{base}+$5a     // colon (period on top & bottom)
      map '0',{base}+$70,10
      map '%',{base}+$7a
      map '&',{base}+$7c
      map ' ',$007f
   }
}

macro font1(define str, define color) {
   fonts.load_single({color})
   evaluate before = pc()
   dw {str}
   if pc() - 64 != {before} {
      error "Invalid string length (not 32)"
   }
   map 0,0,256
}

macro font2(define str, define color) {
   fonts.load_double_top({color})
   evaluate before = pc()
   dw {str}
   if pc() - 64 != {before} {
      error "Invalid string length (not 32)"
   }
   fonts.load_double_bottom({color})
   dw {str}
   map 0,0,256
}

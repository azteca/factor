! Additions to calendar and formatting vocabs
! Copyright (C) 2009 Elie Chaftari.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors annotations arrays assocs calendar combinators
combinators.smart fry i18n kernel macros math math.functions
math.parser memoize namespaces peg.ebnf sequences strings
summary vectors ;
IN: i18n.calendar

ERROR: not-a-month ;
M: not-a-month summary
    drop "Months are indexed starting at 1" ;

<PRIVATE

: check-month ( n -- n )
    [ not-a-month ] when-zero ;

PRIVATE>

MACRO: dip-at ( quots -- )
    [ '[ _ dip at ] ] map [ ] join ;

SYMBOL: override

: set-override ( string -- ) override set-global ;

: get-override ( -- string ) override get ;

: i18n-month-names ( -- array )
    get-override [ get-locales ] unless* load-locales
    { [ "months" ] [ "names" ] } dip-at ;

: month-name ( n -- string )
    check-month 1 - i18n-month-names nth ;

: i18n-month-abbreviations ( -- array )
    get-override [ get-locales ] unless* load-locales
    { [ "months" ] [ "abbrs" ] } dip-at ;

: month-abbreviation ( n -- string )
    check-month 1 - i18n-month-abbreviations nth ;

: i18n-day-names ( -- array )
    get-override [ get-locales ] unless*  load-locales
    { [ "week" ] [ "days" ] } dip-at ;

: day-name ( n -- string ) i18n-day-names nth ;

: i18n-day-abbreviations2 ( -- array )
    get-override [ get-locales ] unless* load-locales
    { [ "week" ] [ "abbrs" ] } dip-at ;

: day-abbreviation2 ( n -- string )
    i18n-day-abbreviations2 nth ; inline

: i18n-day-abbreviations3 ( -- array )
    get-override [ get-locales ] unless* load-locales
    { [ "week" ] [ "abbrs" ] } dip-at ;

: day-abbreviation3 ( n -- string )
    i18n-day-abbreviations3 nth ; inline

: pad-00 ( n -- string ) number>string 2 CHAR: 0 pad-head ; inline

: pad-000 ( n -- string ) number>string 3 CHAR: 0 pad-head ; inline

: >time ( timestamp -- string )
    [ hour>> ] [ minute>> ] [ second>> floor ] tri 3array
    [ pad-00 ] map ":" join ; inline

: >date ( timestamp -- string )
    [ month>> ] [ day>> ] [ year>> ] tri 3array
    [ pad-00 ] map "/" join ; inline

: >datetime ( timestamp -- string )
    [
       {
          [ day-of-week day-abbreviation3 ]
          [ month>> month-abbreviation ]
          [ day>> pad-00 ]
          [ >time ]
          [ year>> number>string ]
       } cleave
    ] output>array " " join ; inline

: (week-of-year) ( timestamp day -- n )
    [ dup clone 1 >>month 1 >>day day-of-week dup ] dip > [ 7 swap - ] when
    [ day-of-year ] dip 2dup < [ 0 2nip ] [ - 7 / 1 + >fixnum ] if ;

: week-of-year-sunday ( timestamp -- n ) 0 (week-of-year) ; inline

: week-of-year-monday ( timestamp -- n ) 1 (week-of-year) ; inline

!TODO needs a DST (daylight saving time) formula to work as supposed
CONSTANT: timezones
    {
        ! { 1 "A" }
        ! { 10.5 "ACDT" }
        { 9.5 "ACST" }
        { -3 "ADT" }
        { 11 "AEDT" }
        { 10 "AEST" }
        { -8 "AKDT" }
        { -9 "AKST" }
        { -4 "AST"  }
        { 9 "AWDT"  }
        { 8 "AWST"  }
        ! { 2 "B"  }
        ! { 1 "BST"  }
        { 3 "C"  }
        ! { 10.5 "CDT"  }
        { -5 "CDT"  }
        ! { 2 "CEDT"  }
        ! { 2 "CEST"  }
        { 1 "CET"  }
        { 10.5 "CST"  }
        { 9.5 "CST"  }
        { -6 "CST"  }
        { 7 "CXT"  }
        { 4 "D"  }
        { 5 "E"  }
        { 11 "EDT"  }
        { -4 "EDT"  }
        { 3 "EEDT"  }
        { 3 "EEST"  }
        { 2 "EET"  }
        { 11 "EST"  }
        { 10 "EST"  }
        { -5 "EST"  }
        { 6 "F"  }
        { 7 "G"  }
        ! { 0 "GMT"  }
        { 8 "H"  }
        { -3 "HAA"  }
        { -5 "HAC"  }
        { -9 "HADT"  }
        { -4 "HAE"  }
        { -7 "HAP"  }
        { -6 "HAR"  }
        { -10 "HAST"  }
        { -2.5 "HAT"  }
        { -8 "HAY"  }
        { -4 "HNA"  }
        { -6 "HNC"  }
        { -5 "HNE"  }
        { -8 "HNP"  }
        { -7 "HNR"  }
        { -3.5 "HNT"  }
        { -9 "HNY"  }
        { 9 "I"  }
        ! { 1 "IST"  }
        { 10 "K"  }
        { 11 "L"  }
        { 12 "M"  }
        { -6 "MDT"  }
        { 2 "MESZ"  }
        ! { 1 "MEZ"  }
        { 4 "MSD"  }
        { 3 "MSK"  }
        { -7 "MST"  }
        { -1 "N"  }
        { -2.5 "NDT"  }
        { 11.5 "NFT"  }
        { -3.5 "NST"  }
        { -2 "O"  }
        { -3 "P"  }
        { -7 "PDT"  }
        { -8 "PST"  }
        { -4 "Q"  }
        { -5 "R"  }
        { -6 "S"  }
        { -7 "T"  }
        { -8 "U"  }
        { 0 "UTC"  }
        { -9 "V"  }
        { -10 "W"  }
        { 9 "WDT"  }
        ! { 1 "WEDT"  }
        ! { 1 "WEST"  }
        ! { 0 "WET"  }
        { 9 "WST"  }
        { 8 "WST"  }
        { -11 "X"  }
        { -12 "Y"  }
        ! { 0 "Z"  }
    }

EBNF: parse-strftime

fmt-%     = "%"                  => [[ [ "%" ] ]]
fmt-a     = "a"                  => [[ [ dup day-of-week day-abbreviation3 ] ]]
fmt-A     = "A"                  => [[ [ dup day-of-week day-name ] ]]
fmt-b     = "b"                  => [[ [ dup month>> month-abbreviation ] ]]
fmt-B     = "B"                  => [[ [ dup month>> month-name ] ]]
fmt-c     = "c"                  => [[ [ dup >datetime ] ]]
fmt-d     = "d"                  => [[ [ dup day>> pad-00 ] ]]
fmt-H     = "H"                  => [[ [ dup hour>> pad-00 ] ]]
fmt-I     = "I"                  => [[ [ dup hour>> dup 12 > [ 12 - ] when pad-00 ] ]]
fmt-j     = "j"                  => [[ [ dup day-of-year pad-000 ] ]]
fmt-m     = "m"                  => [[ [ dup month>> pad-00 ] ]]
fmt-M     = "M"                  => [[ [ dup minute>> pad-00 ] ]]
fmt-p     = "p"                  => [[ [ dup hour>> 12 < "AM" "PM" ? ] ]]
fmt-S     = "S"                  => [[ [ dup second>> floor pad-00 ] ]]
fmt-U     = "U"                  => [[ [ dup week-of-year-sunday pad-00 ] ]]
fmt-w     = "w"                  => [[ [ dup day-of-week number>string ] ]]
fmt-W     = "W"                  => [[ [ dup week-of-year-monday pad-00 ] ]]
fmt-x     = "x"                  => [[ [ dup >date ] ]]
fmt-X     = "X"                  => [[ [ dup >time ] ]]
fmt-y     = "y"                  => [[ [ dup year>> 100 mod pad-00 ] ]]
fmt-Y     = "Y"                  => [[ [ dup year>> number>string ] ]]
fmt-Z     = "Z"                  => [[ [ dup gmt-offset>> hour>> timezones at ] ]]
unknown   = (.)*                 => [[ "Unknown directive" throw ]]

formats_  = fmt-%|fmt-a|fmt-A|fmt-b|fmt-B|fmt-c|fmt-d|fmt-H|fmt-I|
            fmt-j|fmt-m|fmt-M|fmt-p|fmt-S|fmt-U|fmt-w|fmt-W|fmt-x|
            fmt-X|fmt-y|fmt-Y|fmt-Z|unknown

formats   = "%" (formats_)       => [[ second '[ _ dip ] ]]

plain-text = (!("%").)+          => [[ >string '[ _ swap ] ]]

text      = (formats|plain-text)* => [[ reverse [ [ [ push ] keep ] append ] map ]]

;EBNF

PRIVATE>

MACRO: i18n-strftime ( format-string -- )
    parse-strftime [ length ] keep [ ] join
    '[ _ <vector> @ reverse concat nip ] ;

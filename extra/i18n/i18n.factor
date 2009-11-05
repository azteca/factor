! Copyright (C) 2009 Elie Chaftari.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs hashtables io io.directories
io.encodings.utf8 io.files io.files.types json.reader kernel
locals memoize namespaces sequences splitting ;
IN: i18n

CONSTANT: locales-default "en-us"

SYMBOL: locales
locales-default "lang" f ?set-at locales set-global

: get-locales ( -- string ) "lang" locales get at ;

: parse-accept-language ( string -- )
    dup "" = [ drop locales-default "lang" locales get set-at ] [
        "," split first "lang" locales get set-at
    ] if ;

SYMBOL: melting-pot

: pot ( -- melting-pot ) melting-pot get ;

: load-base ( lang -- )
    [ "vocab:i18n/base/" ] dip ".json" 3append
    utf8 file-contents json> melting-pot set ;

: load-locales ( lang -- assoc )
    [ "vocab:i18n/locales/" ] dip ".json" 3append
    utf8 file-contents json> ;

:: lang-directory ( vocab lang -- seq )
    "vocab:" vocab append "/lang/" append :> p
    p directory-entries [ dup type>> +directory+ = [
        name>> "/" append p prepend lang ".json" 3append
        utf8 file-contents json>
    ] [ ] if ] accumulator [ each ] dip ;

: merged-translation ( vocab lang -- new-assoc )
    dup [ load-base ] curry 2dip
    lang-directory [ [ swap pot set-at ] assoc-each ] each pot ;

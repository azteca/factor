! Copyright (C) 2009 Doug Coleman.
! See http://factorcode.org/license.txt for BSD license.
USING: html.parser.state io io.encodings.utf8 io.files
io.streams.string kernel combinators accessors io.pathnames
fry sequences arrays locals namespaces io.directories
assocs math splitting make ;
IN: c.preprocessor

: initial-library-paths ( -- seq )
    V{ "/usr/include" } clone ;

TUPLE: preprocessor-state library-paths symbol-table
include-nesting include-nesting-max processing-disabled?
ifdef-nesting warnings ;

: <preprocessor-state> ( -- preprocessor-state )
    preprocessor-state new
        initial-library-paths >>library-paths
        H{ } clone >>symbol-table
        0 >>include-nesting
        200 >>include-nesting-max
        0 >>ifdef-nesting
        V{ } clone >>warnings ;

DEFER: preprocess-file

ERROR: unknown-c-preprocessor state-parser name ;

ERROR: bad-include-line line ;

ERROR: header-file-missing path ;

:: read-standard-include ( preprocessor-state path -- )
    preprocessor-state dup library-paths>>
    [ path append-path exists? ] find nip
    [
        dup [
            path append-path
            preprocess-file
        ] with-directory
    ] [
        ! path header-file-missing
        drop
    ] if* ;

:: read-local-include ( preprocessor-state path -- )
    current-directory get path append-path dup :> full-path
    dup exists? [
        [ preprocessor-state ] dip preprocess-file
    ] [
        ! full-path header-file-missing
        drop
    ] if ;

: handle-include ( preprocessor-state state-parser -- )
    skip-whitespace advance dup previous {
        { CHAR: < [ CHAR: > take-until-object read-standard-include ] }
        { CHAR: " [ CHAR: " take-until-object read-local-include ] }
        [ bad-include-line ]
    } case ;

: (readlns) ( -- )
    readln "\\" ?tail [ , ] dip [ (readlns) ] when ;

: readlns ( -- string ) [ (readlns) ] { } make concat ;

: handle-define ( preprocessor-state state-parser -- )
    [ take-token ] [ take-rest ] bi 
    "\\" ?tail [ readlns append ] when
    spin symbol-table>> set-at ;

: handle-undef ( preprocessor-state state-parser -- )
    take-token swap symbol-table>> delete-at ;

: handle-ifdef ( preprocessor-state state-parser -- )
    [ [ 1 + ] change-ifdef-nesting ] dip
    take-token over symbol-table>> key?
    [ drop ] [ t >>processing-disabled? drop ] if ;

: handle-ifndef ( preprocessor-state state-parser -- )
    [ [ 1 + ] change-ifdef-nesting ] dip
    take-token over symbol-table>> key?
    [ t >>processing-disabled? drop ]
    [ drop ] if ; 

: handle-endif ( preprocessor-state state-parser -- )
    drop [ 1 - ] change-ifdef-nesting drop ;

: handle-error ( preprocessor-state state-parser -- )
    skip-whitespace
    nip take-rest throw ;

: handle-warning ( preprocessor-state state-parser -- )
    skip-whitespace
    take-rest swap warnings>> push ;

: parse-directive ( preprocessor-state state-parser string -- )
    {
        { "warning" [ handle-warning ] }
        { "error" [ handle-error ] }
        { "include" [ handle-include ] }
        { "define" [ handle-define ] }
        { "undef" [ handle-undef ] }
        { "ifdef" [ handle-ifdef ] }
        { "ifndef" [ handle-ifndef ] }
        { "endif" [ handle-endif ] }
        { "if" [ 2drop ] }
        { "elif" [ 2drop ] }
        { "else" [ 2drop ] }
        { "pragma" [ 2drop ] }
        { "include_next" [ 2drop ] }
        [ unknown-c-preprocessor ]
    } case ;

: parse-directive-line ( preprocessor-state state-parser -- )
    advance dup take-token
    pick processing-disabled?>> [
        "endif" = [
            drop f >>processing-disabled?
            [ 1 - ] change-ifdef-nesting
            drop
         ] [ 2drop ] if
    ] [
        parse-directive
    ] if ;

: preprocess-line ( preprocessor-state state-parser -- )
    skip-whitespace dup current CHAR: # =
    [ parse-directive-line ]
    [ swap processing-disabled?>> [ drop ] [ write-full nl ] if ] if ;

: preprocess-lines ( preprocessor-state -- )
    readln 
    [ <state-parser> [ preprocess-line ] [ drop preprocess-lines ] 2bi ]
    [ drop ] if* ;

ERROR: include-nested-too-deeply ;

: check-nesting ( preprocessor-state -- preprocessor-state )
    [ 1 + ] change-include-nesting
    dup [ include-nesting>> ] [ include-nesting-max>> ] bi > [
        include-nested-too-deeply
    ] when ;

: preprocess-file ( preprocessor-state path -- )
    [ check-nesting ] dip
    [ utf8 [ preprocess-lines ] with-file-reader ]
    [ drop [ 1 - ] change-include-nesting drop ] 2bi ;

: start-preprocess-file ( path -- preprocessor-state string )
    dup parent-directory [
        [
            [ <preprocessor-state> dup ] dip preprocess-file
        ] with-string-writer
    ] with-directory ;
! Copyright (C) 2009 Elie Chaftari.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs combinators eval fry furnace.sessions
furnace.utilities html.templates.chloe.compiler
html.templates.chloe.syntax i18n i18n.calendar kernel macros
present quotations sequences splitting urls xml.syntax ;
IN: i18n.chloe-tags

: translated-lang ( -- assoc )
    "my" "lang" sget [ get-locales ] unless*
    merged-translation ;

: translated-locales ( -- assoc )
    "lang" sget [ get-locales ] unless* load-locales ;

MACRO: dip-at ( quots -- )
    [ '[ _ dip at ] ] map [ ] join ;

: split-keys ( translate -- seq )
     ":" split  [ 1quotation ] { } map-as ;

: timestamp-attr ( tag -- timestamp )
    "ts" required-attr "USE: calendar " prepend
    eval( -- timestamp ) ;

: format-attr ( tag -- translated )
    "format" required-attr [ translated-locales ] dip
    dup ":" subseq? [ at ] [ split-keys dip-at ] if ; inline

: datetime-attrs ( tag -- timestamp string )
    { [ timestamp-attr ] [ format-attr ] } cleave ; inline

CHLOE: dt
    datetime-attrs '[ _ _ i18n-strftime [XML <-> XML] ]
    [xml-code] ;

: translate ( tag -- translated )
    "translate" required-attr [ translated-lang ] dip
    dup ":" subseq? [ at ] [ split-keys dip-at ] if ; inline

CHLOE: i18n
    translate '[ _ [XML <-> XML] ] [xml-code] ;

: src-url ( tag -- url )
    "src" required-attr <url> swap >>path adjust-url present ;

CHLOE: script
    src-url [ [XML
        <script type="text/javascript" src=<->> </script>
    XML] ] curry [xml-code] ;

: alt-text ( tag -- string )
    "alt" optional-attr ;

: img-attrs ( tag -- string string )
    { [ src-url ] [ alt-text ] } cleave ;

CHLOE: img
    img-attrs '[ _ _ [XML
        <img src=<-> alt=<-> />
    XML] ] [xml-code] ;

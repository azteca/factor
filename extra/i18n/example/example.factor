! Copyright (C) 2009 Elie Chaftari.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs db.sqlite fry furnace.actions
furnace.alloy furnace.boilerplate furnace.sessions
html.templates.chloe http http.server http.server.dispatchers
http.server.responses http.server.static i18n i18n.calendar
i18n.chloe-tags i18n.utilities io.files.temp kernel macros
namespaces sequences threads ;
IN: i18n.example

TUPLE: example-app < dispatcher ;

: <static-action> ( -- action )
    "vocab:i18n/example/public/" <static> ;

: <example-homepage-action> ( -- action )
    <page-action>
        [
            "lang" param dup "lang" sset set-override
            reset-cache
        ] >>init
        { example-app "example" } >>template ;

: <show-accept-language> ( -- action )
    <action>
        [
            accept-language
            "&nbsp;&nbsp;&nbsp;<a href=\"javascript: history.go(-1)\">Back</a>"
            append "text/html" <content>
        ] >>display ;

: example-app-db ( -- db ) "example.db" temp-file <sqlite-db> ;

: <example-app> ( -- dispatcher )
    example-app new-dispatcher
        <static-action> "public" add-responder
        <example-homepage-action> "" add-responder
        <show-accept-language> "header" add-responder
        <boilerplate>
            [ accept-language parse-accept-language ] >>init
            { example-app "example-common" } >>template ;

: start-server ( -- )
    <example-app>
        example-app-db <alloy>
        main-responder set-global
    [ 8080 httpd ] in-thread ;

MAIN: start-server

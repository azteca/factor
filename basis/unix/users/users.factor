! Copyright (C) 2008 Doug Coleman.
! See http://factorcode.org/license.txt for BSD license.
USING: alien alien.c-types alien.strings io.encodings.utf8
io.backend.unix kernel math sequences splitting strings
combinators.short-circuit grouping byte-arrays combinators
accessors math.parser fry assocs namespaces continuations
vocabs.loader system classes.struct ;
IN: unix.users
QUALIFIED: unix

TUPLE: passwd user-name password uid gid gecos dir shell ;

HOOK: new-passwd os ( -- passwd )
HOOK: passwd>new-passwd os ( passwd -- new-passwd )

<PRIVATE

M: unix new-passwd ( -- passwd )
    passwd new ;

M: unix passwd>new-passwd ( passwd -- seq )
    [ new-passwd ] dip
    {
        [ pw_name>> >>user-name ]
        [ pw_passwd>> >>password ]
        [ pw_uid>> >>uid ]
        [ pw_gid>> >>gid ]
        [ pw_gecos>> >>gecos ]
        [ pw_dir>> >>dir ]
        [ pw_shell>> >>shell ]
    } cleave ;

: with-pwent ( quot -- )
    [ unix:endpwent ] [ ] cleanup ; inline

PRIVATE>

: all-users ( -- seq )
    [
        [ unix:getpwent dup ] [ unix:passwd memory>struct passwd>new-passwd ] produce nip
    ] with-pwent ;

SYMBOL: user-cache

: <user-cache> ( -- assoc )
    all-users [ [ uid>> ] keep ] H{ } map>assoc ;

: with-user-cache ( quot -- )
    [ <user-cache> user-cache ] dip with-variable ; inline

GENERIC: user-passwd ( obj -- passwd/f )

M: integer user-passwd ( id -- passwd/f )
    user-cache get
    [ at ] [ unix:getpwuid [ unix:passwd memory>struct passwd>new-passwd ] [ f ] if* ] if* ;

M: string user-passwd ( string -- passwd/f )
    unix:getpwnam dup [ unix:passwd memory>struct passwd>new-passwd ] when ;

: user-name ( id -- string )
    dup user-passwd
    [ nip user-name>> ] [ number>string ] if* ;

: user-id ( string -- id )
    user-passwd uid>> ;

: real-user-id ( -- id )
    unix:getuid ; inline

: real-user-name ( -- string )
    real-user-id user-name ; inline

: effective-user-id ( -- id )
    unix:geteuid ; inline

: effective-user-name ( -- string )
    effective-user-id user-name ; inline

GENERIC: set-real-user ( string/id -- )

GENERIC: set-effective-user ( string/id -- )

: with-real-user ( string/id quot -- )
    '[ _ set-real-user @ ]
    real-user-id '[ _ set-real-user ]
    [ ] cleanup ; inline

: with-effective-user ( string/id quot -- )
    '[ _ set-effective-user @ ]
    effective-user-id '[ _ set-effective-user ]
    [ ] cleanup ; inline

<PRIVATE

: (set-real-user) ( id -- )
    unix:setuid unix:io-error ; inline

: (set-effective-user) ( id -- )
    unix:seteuid unix:io-error ; inline

PRIVATE>

M: string set-real-user ( string -- )
    user-id (set-real-user) ;

M: integer set-real-user ( id -- )
    (set-real-user) ;

M: integer set-effective-user ( id -- )
    (set-effective-user) ; 

M: string set-effective-user ( string -- )
    user-id (set-effective-user) ;

os {
    { [ dup bsd? ] [ drop "unix.users.bsd" require ] }
    { [ dup linux? ] [ drop ] }
} cond

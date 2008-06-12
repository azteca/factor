! Copyright (C) 2007 Doug Coleman, Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: arrays combinators concurrency.mailboxes fry io strings
       io.encodings.8-bit io.sockets kernel namespaces sequences
       sequences.lib splitting threads calendar classes.tuple
       classes ascii assocs accessors destructors continuations ;
IN: irc.client

! ======================================
! Setup and running objects
! ======================================

SYMBOL: current-irc-client

: irc-port 6667 ; ! Default irc port

! "setup" objects
TUPLE: irc-profile server port nickname password ;
C: <irc-profile> irc-profile

! "live" objects
TUPLE: nick name channels log ;
C: <nick> nick

TUPLE: irc-client profile nick stream in-messages out-messages join-messages
       listeners is-running connect reconnect-time ;
: <irc-client> ( profile -- irc-client )
    f V{ } clone V{ } clone <nick>
    f <mailbox> <mailbox> <mailbox> H{ } clone f
    [ <inet> latin1 <client> ] 15 seconds irc-client boa ;

TUPLE: irc-listener in-messages out-messages ;
TUPLE: irc-server-listener < irc-listener ;
TUPLE: irc-channel-listener < irc-listener name password timeout ;
TUPLE: irc-nick-listener < irc-listener name ;
UNION: irc-named-listener irc-nick-listener irc-channel-listener ;

: <irc-listener> ( -- irc-listener ) <mailbox> <mailbox> irc-listener boa ;

: <irc-server-listener> ( -- irc-server-listener )
     <mailbox> <mailbox> irc-server-listener boa ;

: <irc-channel-listener> ( name -- irc-channel-listener )
     <mailbox> <mailbox> rot f 60 seconds irc-channel-listener boa ;

: <irc-nick-listener> ( name -- irc-nick-listener )
     <mailbox> <mailbox> rot irc-nick-listener boa ;

! ======================================
! Message objects
! ======================================

SINGLETON: irc-end          ! sent when the client isn't running anymore
SINGLETON: irc-disconnected ! sent when connection is lost
SINGLETON: irc-connected    ! sent when connection is established
UNION: irc-broadcasted-message irc-end irc-disconnected irc-connected ;

TUPLE: irc-message line prefix command parameters trailing timestamp ;
TUPLE: logged-in < irc-message name ;
TUPLE: ping < irc-message ;
TUPLE: join < irc-message ;
TUPLE: part < irc-message name channel ;
TUPLE: quit < irc-message ;
TUPLE: privmsg < irc-message name ;
TUPLE: kick < irc-message channel who ;
TUPLE: roomlist < irc-message channel names ;
TUPLE: nick-in-use < irc-message asterisk name ;
TUPLE: notice < irc-message type ;
TUPLE: mode < irc-message name channel mode ;
TUPLE: unhandled < irc-message ;

: terminate-irc ( irc-client -- )
    [ in-messages>> irc-end swap mailbox-put ]
    [ f >>is-running drop ]
    [ stream>> dispose ]
    tri ;

<PRIVATE

! ======================================
! Shortcuts
! ======================================

: irc> ( -- irc-client ) current-irc-client get ;
: irc-stream> ( -- stream ) irc> stream>> ;
: irc-write ( s -- ) irc-stream> stream-write ;
: irc-print ( s -- ) irc-stream> [ stream-print ] keep stream-flush ;

! ======================================
! IRC client messages
! ======================================

: /NICK ( nick -- )
    "NICK " irc-write irc-print ;

: /LOGIN ( nick -- )
    dup /NICK
    "USER " irc-write irc-write
    " hostname servername :irc.factor" irc-print ;

: /CONNECT ( server port -- stream )
    irc> connect>> call drop ;

: /JOIN ( channel password -- )
    "JOIN " irc-write
    [ " :" swap 3append ] when* irc-print ;

: /PART ( channel text -- )
    [ "PART " irc-write irc-write ] dip
    " :" irc-write irc-print ;

: /KICK ( channel who -- )
    [ "KICK " irc-write irc-write ] dip
    " " irc-write irc-print ;

: /PRIVMSG ( nick line -- )
    [ "PRIVMSG " irc-write irc-write ] dip
    " :" irc-write irc-print ;

: /ACTION ( nick line -- )
    [ 1 , "ACTION " % % 1 , ] "" make /PRIVMSG ;

: /QUIT ( text -- )
    "QUIT :" irc-write irc-print ;

: /PONG ( text -- )
    "PONG " irc-write irc-print ;

! ======================================
! Message parsing
! ======================================

: split-at-first ( seq separators -- before after )
    dupd '[ , member? ] find
        [ cut 1 tail ]
        [ swap ]
    if ;

: remove-heading-: ( seq -- seq ) dup ":" head? [ 1 tail ] when ;

: parse-name ( string -- string )
    remove-heading-: "!" split-at-first drop ;

: split-prefix ( string -- string/f string )
    dup ":" head?
        [ remove-heading-: " " split1 ]
        [ f swap ]
    if ;

: split-trailing ( string -- string string/f )
    ":" split1 ;

: string>irc-message ( string -- object )
    dup split-prefix split-trailing
    [ [ blank? ] trim " " split unclip swap ] dip
    now irc-message boa ;

: parse-irc-line ( string -- message )
    string>irc-message
    dup command>> {
        { "PING" [ \ ping ] }
        { "NOTICE" [ \ notice ] }
        { "001" [ \ logged-in ] }
        { "433" [ \ nick-in-use ] }
        { "JOIN" [ \ join ] }
        { "PART" [ \ part ] }
        { "PRIVMSG" [ \ privmsg ] }
        { "QUIT" [ \ quit ] }
        { "MODE" [ \ mode ] }
        { "KICK" [ \ kick ] }
        [ drop \ unhandled ]
    } case
    [ [ tuple-slots ] [ parameters>> ] bi append ] dip prefix >tuple ;

! ======================================
! Server message handling
! ======================================

: me? ( string -- ? )
    irc> nick>> name>> = ;

: irc-message-origin ( irc-message -- name )
    dup name>> me? [ prefix>> parse-name ] [ name>> ] if ;

: broadcast-message-to-listeners ( message -- )
    irc> listeners>> values [ in-messages>> mailbox-put ] with each ;

GENERIC: handle-incoming-irc ( irc-message -- )

M: irc-message handle-incoming-irc ( irc-message -- )
    f irc> listeners>> at
    [ in-messages>> mailbox-put ] [ drop ] if* ;

M: logged-in handle-incoming-irc ( logged-in -- )
    name>> irc> nick>> (>>name) ;

M: ping handle-incoming-irc ( ping -- )
    trailing>> /PONG ;

M: nick-in-use handle-incoming-irc ( nick-in-use -- )
    name>> "_" append /NICK ;

M: privmsg handle-incoming-irc ( privmsg -- )
    dup irc-message-origin irc> listeners>> [ at ] keep
    '[ f , at ] unless* [ in-messages>> mailbox-put ] [ drop ] if* ;

M: join handle-incoming-irc ( join -- )
    irc> join-messages>> mailbox-put ;

M: irc-broadcasted-message handle-incoming-irc ( irc-broadcasted-message -- )
    broadcast-message-to-listeners ;

! ======================================
! Client message handling
! ======================================

GENERIC: handle-outgoing-irc ( obj -- )

M: privmsg handle-outgoing-irc ( privmsg -- )
   [ name>> ] [ trailing>> ] bi /PRIVMSG ;

! ======================================
! Reader/Writer
! ======================================

: irc-mailbox-get ( mailbox quot -- )
    swap 5 seconds
    '[ , , , mailbox-get-timeout swap call ]
    [ drop ] recover ; inline

: handle-reader-message ( irc-message -- )
    irc> in-messages>> mailbox-put ;

DEFER: (connect-irc)

: (handle-disconnect) ( -- )
    irc>
        [ in-messages>> irc-disconnected swap mailbox-put ]
        [ dup reconnect-time>> sleep (connect-irc) ]
        [ profile>> nickname>> /LOGIN ]
    tri ;

: handle-disconnect ( error -- )
    drop irc> is-running>> [ (handle-disconnect) ] when ;

: (reader-loop) ( -- )
    irc> stream>> [
        |dispose stream-readln [
            parse-irc-line handle-reader-message
        ] [
            irc> terminate-irc
        ] if*
    ] with-destructors ;

: reader-loop ( -- )
    [ (reader-loop) ] [ handle-disconnect ] recover ;

: writer-loop ( -- )
    irc> out-messages>> [ handle-outgoing-irc ] irc-mailbox-get ;

! ======================================
! Processing loops
! ======================================

: in-multiplexer-loop ( -- )
    irc> in-messages>> [ handle-incoming-irc ] irc-mailbox-get ;

: strings>privmsg ( name string -- privmsg )
    privmsg new [ (>>trailing) ] keep [ (>>name) ] keep ;

: maybe-annotate-with-name ( name obj -- obj )
    {
        { [ dup string? ] [ strings>privmsg ] }
        { [ dup privmsg instance? ] [ swap >>name ] }
    } cond ;

: listener-loop ( name listener -- )
    out-messages>> swap
    '[ , swap maybe-annotate-with-name irc> out-messages>> mailbox-put ]
    irc-mailbox-get ;

: spawn-irc-loop ( quot name -- )
    [ '[ irc> is-running>> [ @ ] when irc> is-running>> ] ] dip
    spawn-server drop ;

: spawn-irc ( -- )
    [ reader-loop ] "irc-reader-loop" spawn-irc-loop
    [ writer-loop ] "irc-writer-loop" spawn-irc-loop
    [ in-multiplexer-loop ] "in-multiplexer-loop" spawn-irc-loop ;

! ======================================
! Listener join request handling
! ======================================

: set+run-listener ( name irc-listener -- )
    [ '[ , , listener-loop ] "listener" spawn-irc-loop ]
    [ swap irc> listeners>> set-at ]
    2bi ;

GENERIC: (add-listener) ( irc-listener -- )
M: irc-channel-listener (add-listener) ( irc-channel-listener -- )
    [ [ name>> ] [ password>> ] bi /JOIN ]
    [ [ [ drop irc> join-messages>> ]
        [ timeout>> ]
        [ name>> '[ trailing>> , = ] ]
        tri mailbox-get-timeout? trailing>> ] keep set+run-listener
    ] bi ;

M: irc-nick-listener (add-listener) ( irc-nick-listener -- )
    [ name>> ] keep set+run-listener ;

M: irc-server-listener (add-listener) ( irc-server-listener -- )
    f swap set+run-listener ;

: (connect-irc) ( irc-client -- )
    [ profile>> [ server>> ] [ port>> ] bi /CONNECT ] keep
        swap >>stream
        t >>is-running
    in-messages>> irc-connected swap mailbox-put ;

PRIVATE>

: connect-irc ( irc-client -- )
    dup current-irc-client [
        [ (connect-irc) ] [ profile>> nickname>> /LOGIN ] bi
        spawn-irc
    ] with-variable ;

GENERIC: add-listener ( irc-client irc-listener -- )
M: irc-listener add-listener ( irc-client irc-listener -- )
    current-irc-client swap '[ , (add-listener) ] with-variable ;
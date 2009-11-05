! Copyright (C) 2009 Elie Chaftari.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs http kernel namespaces ;
IN: i18n.utilities

: accept-language ( -- string )
    "accept-language" request get header>> at "" or ;

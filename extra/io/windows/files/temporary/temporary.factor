USING: kernel system ;
IN: io.windows.files.temporary

M: windows-io (temporary-file) ( path -- stream )
    GENERIC_WRITE CREATE_NEW 0 open-file 0 <writer> ;

M: windows-io temporary-path ( -- path )
    "TEMP" os-env ;

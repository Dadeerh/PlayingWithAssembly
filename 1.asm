extrn CreateFileA
extrn GetFileSize

extrn GetStdHandle
extrn WriteConsoleA

extrn ExitProcess

.data
filesize dword 0
filename db "test.txt",0
filehandle 

.code 
Start PROC

    mov rcx, filehandle
    lea rdx, filesize
    call GetFileSize



    mov rcx,0
    call ExitProcess
Start ENDP
End
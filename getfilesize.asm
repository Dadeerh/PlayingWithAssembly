STD_OUTPUT_HANDLE EQU -11
GENERIC_READ EQU 80000000h
GENERIC_READWRITE EQU 0C0000000h 
FILE_SHARE_NONE EQU 0
FILE_SHARE_READ EQU 1
OPEN_EXISTING EQU 3
FILE_ATTRIBUTE_NORMAL EQU 80h
NULL EQU 0

extrn GetStdHandle : PROC
extrn WriteConsoleA : PROC
extrn ExitProcess : PROC
extrn GetCommandLineW : PROC
extrn CommandLineToArgvW  : PROC
extrn CreateFileW : PROC
extrn CreateFileA : PROC
extrn GetFileSize : PROC
extrn GetLastError : PROC
extrn CloseHandle : PROC

.data
    consoleHandle dq ?
    bytesWritten dq ?
    commandline dq ? 
    argc dq ?
    argv dq ?
    filename_ptr dq ?
    filehandle dq ?
    filesize dq ?
    filesize_ascii byte 10 dup(?)
    endlineA db 13,10

.code
    Start PROC
        and rsp, not 08h    ; make sure stack is aligned
        ; Get command line

        sub rsp, 20h    ; shadow space
        call GetCommandLineW
        add rsp, 20h
        mov commandline, rax

        ; Parse commandline
        mov rcx, commandline
        lea rdx, argc
        sub rsp, 20h    ; shadow space
        call CommandLineToArgvW
        add rsp, 20h
        mov argv, rax

        ; Get Filename from commandline
        mov r14, argv
        add r14,8

        ; Createfile on argument
        mov rcx, [r14]         ; lpFileName
        mov rdx, GENERIC_READ       ; dwDesiredAccess
        mov r8, NULL                ; dwShareMode
        mov r9, NULL                ; lpSecurityAttributes
        push NULL                   ; hTemplateFile
        push FILE_ATTRIBUTE_NORMAL  ; dwFlagsAndAttributes
        push OPEN_EXISTING          ; dwCreationDisposition
        sub rsp, 20h     ; shadow space
        call CreateFileW
        add rsp, 20h

        cmp rax, -1
        je createfile_error

        mov filehandle, rax

        ; Get filesize
        mov rcx, filehandle
        mov rdx, 0
        sub rsp, 20h
        call GetFileSize
        add rsp, 20h

        mov filesize, rax

        ; Convert number to ascii number
        mov rcx, filesize
        lea rdx, filesize_ascii
        call NumberToASCII

        ; Get stdout
        mov rcx, STD_OUTPUT_HANDLE
        sub rsp, 20h
        call GetStdHandle
        add rsp, 20h
        mov consoleHandle, rax

        ; Print ascii number 
        lea rcx, filesize_ascii
        xor rdx,rdx
        call WriteLineA

        ; Exit
        
        succesful_end:
            mov rcx, filehandle
            sub rsp, 20h
            call CloseHandle
            add rsp, 20h

            mov rcx, consoleHandle
            sub rsp, 20h
            call CloseHandle
            add rsp, 20h

            mov rcx,0
            call ExitProcess

        createfile_error:
            sub rsp, 20h
            call GetLastError
            add rsp, 20h
            mov rbx, rax

            mov rcx,1
            call ExitProcess

    Start ENDP

    NumberToASCII PROC  ; rcx number, rdx pointer to ascii string to fill with numbers
        push r15

        mov rax, rcx
        mov rdi, rdx

        xor r15,r15 ; our counter of characters
        numbertoascii_pushnumbers:
            xor rdx,rdx         ; divide by 10
            mov rcx, 10
            div rcx

            add rdx, 48         ; make remainder ascii
            push rdx            ; push character (we need to reverse them)
            inc r15

            test rax,rax        ; if result is 0 we're done
            jz numbertoascii_popstuff

            jmp numbertoascii_pushnumbers

        numbertoascii_popstuff:     ; pop stuff and put into string in right order
            test r15,r15            ; check if counter is 0, if it is we're done
            jz numbertoascii_end

            pop rdx                 ; pop number
            mov qword ptr [rdi], rdx    ; put number into string
            inc rdi             ; point to next char in string
            dec r15                 ; decrease counter
            jmp numbertoascii_popstuff
            
        numbertoascii_end: 
            mov qword ptr[rdi], 0    ; null terminate string
            pop r15
            ret
    NumberToASCII ENDP

    WriteLineA PROC ; rcx: pointer to string, rdx number of chars to write (0 = write 0 terminated string)
        push r13
        push r14
        push r15

        mov r15,rcx     ; store the input string as rcx get overwritten
        mov r13, rdx

        cmp r13,0
        jne writelinea_nostrlen

        writelinea_strlen: 
            call StrLenA    ; rcx is already our string
            mov r14, rax    ; store the strlen

            mov rcx, consoleHandle
            mov rdx,r15
            mov r8, r14
            lea r9, bytesWritten
            push 0
            sub rsp, 20h
            call WriteConsoleA
            add rsp, 20h

            jmp writelinea_end

        writelinea_nostrlen:
            mov rcx, consoleHandle
            mov rdx,r15
            mov r8, r13
            lea r9, bytesWritten
            push 0
            sub rsp, 20h
            call WriteConsoleA
            add rsp, 20h

        writelinea_end:
        mov rcx, consoleHandle
        lea rdx, endlineA
        mov r8, 2
        lea r9, bytesWritten
        push 0
        sub rsp, 20h
        call WriteConsoleA
        add rsp, 20h

        pop r15
        pop r14
        pop r13
        ret
    WriteLineA ENDP
    StrLenA PROC
        mov rdi, rcx    ; string will be in first argument rcx
        xor rcx,rcx
        
        strlen_loop:
            cmp byte ptr [rdi],0
            je strlen_done
            inc rcx
            inc rdi
            jmp strlen_loop

        strlen_done:
            mov rax, rcx    ; rax is return value

        ret
    StrLenA ENDP
END
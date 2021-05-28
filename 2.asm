STD_OUTPUT_HANDLE EQU -11

extrn GetStdHandle : PROC
extrn WriteConsoleA : PROC
extrn WriteConsoleW : PROC
extrn ExitProcess : PROC
extrn GetCommandLineW : PROC
extrn CommandLineToArgvW  : PROC


.data
    consoleHandle dq ?
    bytesWritten dq ?
    message1 db 'argc is:',0
    message2 db 'arguments are:',0
    argc dq ?
    varstringA dq ?
    argc_ascii dq 48
    endlineA db 13,10
    endlineW dw 13,10
    commandline dq ? 
    argv dq ?

.code
    Start PROC
        sub rsp, 40 ; shadow space + space for WriteConsoleA argument


        call GetCommandLineW
        mov commandline, rax

        mov rcx, commandline
        lea rdx, argc
        call CommandLineToArgvW

        mov argv, rax
        mov rax, argc
        add argc_ascii, rax

        mov rcx, STD_OUTPUT_HANDLE
        call GetStdHandle
        mov consoleHandle, rax


        ; Print argc
        lea rcx, message1
        xor rdx,rdx
        call WriteLineA
        
        lea rcx, argc_ascii
        mov rdx,1
        call WriteLineA

        ; Print all arguments
        xor r15,r15
        ;mov r14, argv
        ;mov r13, [r14]
        
        lea rcx, message2
        xor rdx,rdx
        call WriteLineA

        arguments_loop:
            mov r14, argv
            mov rax,8
            mul r15 ; rax =  rax * r15 = 8 * r15
            add r14,rax
            mov rcx, [r14]
            ;lea rcx, [r13+r15*4]
            mov rdx, 0
            call WriteLineW

            inc r15
            cmp r15,argc
            jb arguments_loop

        mov rcx, 0
        call ExitProcess

    Start ENDP

    WriteLineA PROC ; rcx: pointer to string, rdx number of chars to write (0 = write 0 terminated string)
        sub rsp, 40
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
            mov qword ptr[rsp+32],0
            call WriteConsoleA


            mov rcx, consoleHandle
            lea rdx, endlineA
            mov r8, 2
            lea r9, bytesWritten
            mov qword ptr [rsp+32],0
            call WriteConsoleA
            jmp writelinea_end

        writelinea_nostrlen:
            mov rcx, consoleHandle
            mov rdx,r15
            mov r8, r13
            lea r9, bytesWritten
            mov qword ptr[rsp+32],0
            call WriteConsoleA


            mov rcx, consoleHandle
            lea rdx, endlineA
            mov r8, 2
            lea r9, bytesWritten
            mov qword ptr [rsp+32],0
            call WriteConsoleA

        writelinea_end:
        pop r15
        pop r14
        pop r13
        add rsp, 40
        ret
    WriteLineA ENDP

    WriteLineW PROC; rcx: pointer to string, rdx number of chars to write (0 = write 0 terminated string)
        sub rsp, 40
        push r13
        push r14
        push r15

        mov r15,rcx     ; store the input string as rcx get overwritten
        mov r13, rdx

        cmp r13,0
        jne writelinew_nostrlen

        writelinew_strlen: 
            call StrLenW    ; rcx is already our string
            mov r14, rax    ; store the strlen

            mov rcx, consoleHandle
            mov rdx,r15
            mov r8, r14
            lea r9, bytesWritten
            mov qword ptr[rsp+32],0
            call WriteConsoleW


            mov rcx, consoleHandle
            lea rdx, endlineW
            mov r8, 2
            lea r9, bytesWritten
            mov qword ptr [rsp+32],0
            call WriteConsoleW
            jmp writelinew_end

        writelinew_nostrlen:
            mov rcx, consoleHandle
            mov rdx,r15
            mov r8, r13
            lea r9, bytesWritten
            mov qword ptr[rsp+32],0
            call WriteConsoleW


            mov rcx, consoleHandle
            lea rdx, endlineW
            mov r8, 2
            lea r9, bytesWritten
            mov qword ptr [rsp+32],0
            call WriteConsoleW

        writelinew_end:
        pop r15
        pop r14
        pop r13
        add rsp, 40
        ret
    WriteLineW ENDP

    StrLenW PROC
        sub rsp, 32

        mov rdi, rcx    ; string will be in first argument rcx
        xor rcx,rcx
        
        strlen_loop:
            cmp word ptr [rdi],0
            je strlen_done
            inc rcx
            add rdi, 2
            jmp strlen_loop

        strlen_done:
            mov rax, rcx    ; rax is return value

        add rsp, 32
        ret
    StrLenW ENDP

    
    StrLenA PROC
        sub rsp, 32

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

        add rsp, 32
        ret
    StrLenA ENDP
END
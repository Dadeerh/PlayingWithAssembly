; Constants
STD_OUTPUT_HANDLE EQU -11
STD_INPUT_HANDLE EQU -10

; kernel32.lib
extrn WriteConsoleA : PROC
extrn WriteConsoleW : PROC
extrn GetCommandLineW : PROC
extrn GetLastError : PROC
extrn GetStdHandle : PROC

; shell32.lib
extrn CommandLineToArgvW : PROC

.data
    endlineA db 13,10
    endlineW dw 13,10
    error_code_ascii byte 20 dup(?)

.code
    OpenStdOut PROC  ; no args
        mov rcx, STD_OUTPUT_HANDLE
        sub rsp, 20h
        call GetStdHandle
        add rsp, 20h

        ret  ; consoleHandle in rax
    OpenStdOut ENDP

    OpenStdIn PROC
        sub rsp, 20h

        mov rcx, STD_INPUT_HANDLE
        call GetStdHandle

        add rsp, 20h
        ret
    OpenStdIn ENDP

    WriteLastError PROC
        push r15
        push r13
        push r12

        mov r15, rcx; rcx consolehandle
        mov r13, rdx; rdx premessage ptr (e.r. "Error code is:",0) null terminated
        mov r12, r8; r8 address of bytesWritten

        mov rcx, r13
        xor rdx,rdx
        mov r8, r15
        mov r9,  r12
        call WriteLineNoBreakA

        sub rsp, 20h
        call GetLastError
        add rsp, 20h

        mov rcx, rax
        lea rdx, error_code_ascii
        call NumberToASCII

        lea rcx, error_code_ascii
        xor rdx,rdx
        mov r8, r15
        mov r9, r12
        call WriteLineA
        
        pop r12
        pop r13
        pop r15
        ret
    WriteLastError ENDP
    
    GetCommandlineArguments PROC
        ; rcx pointer to argc
        ; rdx pointer to argv
        sub rsp, 28h
        push r15
        push r14

        mov r15, rcx  ; argc
        mov r14, rdx  ; argv

        call GetCommandLineW

        mov rcx, rax
        mov rdx, r15
        call CommandLineToArgvW
        
        mov qword ptr[r14], rax

        test rax,rax
        jnz getcommandlinearguments_end

        get_commandlinearguments_end_error:
        mov rax, -1

        getcommandlinearguments_end:
        pop r14
        pop r15
        add rsp, 28h
        ret
    GetCommandlineArguments ENDP

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

    ASCIIToNumber PROC ; rcx pointer to ASCII string, rax returns number
        push r15    ; used for calculations
        push r14    ; multiplied by 10 each round, so 10 - 100 - 1000, etc
        push r13    ; final number
        push rdi
        
        mov rdi, rcx    ; string pointer in rdi

        ; get strlen (string is still in rcx)
        call StrLenA
        mov rbx, rax

        xor r13,r13
        xor rcx, rcx
        xor r14,r14
        inc r14

        asciitonumber_loop:
            ; check if we're at final byte
            test rbx, rbx
            jz asciitonumber_end

            ; subtract 48
            xor r15, r15 
            mov r15b, byte ptr[rdi+rbx-1]
            sub r15, 48

            ; multiply by modifier (r14)
            mov rdx, r14
            mov rax, r15
            mul rdx
            
            ; add to final number
            add r13, rax

            ; increase modifier 10 fold for next iteration
            mov rdx, 10
            mov rax, r14
            mul rdx
            mov r14,rax
            
            ; decrease rbx to point at next number from the right
            dec rbx
            inc rcx

            ; loop
            jmp asciitonumber_loop
        
        asciitonumber_end:
        mov rax, r13

        pop rdi
        pop r13
        pop r14
        pop r15
        ret
    ASCIIToNumber ENDP

    WriteLineA PROC 
        ; rcx: pointer to string
        ; rdx number of chars to write (0 = write 0 terminated string);
        ; r8 consoleHandle
        ; r9 ptr to bytesWritten
        sub rsp, 40
        push r12
        push r13
        push r14
        push r15

        mov r15, rcx     ; r15 = ptr to str
        mov r14, r8     ; r14 = consoleHandle
        mov r13, rdx    ; r13 = number of chars to write
        mov r12, r9     ; r12 = ptr to bytesWritten

        cmp r13,0
        jne writelinea_nostrlen

        writelinea_strlen: 
            call StrLenA    ; rcx is already our string

            mov rcx, r14
            mov rdx, r15
            mov r8, rax
            mov r9, r12
            mov qword ptr[rsp+32],0
            call WriteConsoleA

            test rax, rax
            jz writelinea_error_end


            mov rcx, r14
            lea rdx, endlineA
            mov r8, 2
            mov r9, r12
            mov qword ptr [rsp+32],0
            call WriteConsoleA

            test rax, rax
            jz writelinea_error_end

            jmp writelinea_end

        writelinea_nostrlen:
            mov rcx, r14
            mov rdx, r15
            mov r8, r13
            mov r9, r12
            mov qword ptr[rsp+32],0
            call WriteConsoleA

            test rax, rax
            jz writelinea_error_end


            mov rcx, r14
            lea rdx, endlineA
            mov r8, 2
            mov r9, r12
            mov qword ptr [rsp+32],0
            call WriteConsoleA

            test rax, rax
            jz writelinea_error_end

        writelinea_error_end:
        mov rax, -1

        writelinea_end:
        pop r15
        pop r14
        pop r13
        pop r12
        add rsp, 40
        ret
    WriteLineA ENDP
    
    WriteLineNoBreakA PROC 
        ; rcx: pointer to string
        ; rdx number of chars to write (0 = write 0 terminated string);
        ; r8 consoleHandle
        ; r9 ptr to bytesWritten
        sub rsp, 40
        push r12
        push r13
        push r14
        push r15

        mov r15, rcx     ; r15 = ptr to str
        mov r14, r8     ; r14 = consoleHandle
        mov r13, rdx    ; r13 = number of chars to write
        mov r12, r9     ; r12 = ptr to bytesWritten


        cmp r13,0
        jne writelinea_nostrlen

        writelinea_strlen: 
            call StrLenA    ; rcx is already our string

            mov rcx, r14
            mov rdx, r15
            mov r8, rax
            mov r9, r12
            mov qword ptr[rsp+32],0
            call WriteConsoleA

            test rax, rax
            jz writelinea_error_end

            jmp writelinea_end

        writelinea_nostrlen:
            mov rcx, r14
            mov rdx, r15
            mov r8, r13
            mov r9, r12
            mov qword ptr[rsp+32],0
            call WriteConsoleA

            test rax, rax
            jz writelinea_error_end

            jmp writelinea_end

        writelinea_error_end:
        mov rax, -1

        writelinea_end:
        pop r15
        pop r14
        pop r13
        pop r12
        add rsp, 40
        ret
    WriteLineNoBreakA ENDP

    WriteLineNoBreakW PROC
        ; rcx: pointer to string
        ; rdx number of chars to write (0 = write 0 terminated string)
        ; r8 consoleHandle
        ; r9 bytesWritten address
        sub rsp, 40
        push r12
        push r13
        push r14
        push r15

        mov r15, rcx     ; r15 = ptr to str
        mov r14, r8     ; r14 = consoleHandle
        mov r13, rdx    ; r13 = number of chars to write
        mov r12, r9     ; r12 = ptr to bytesWritten

        cmp r13,0
        jne writelinew_nostrlen

        writelinew_strlen: 
            call StrLenW    ; rcx is already our string

            mov rcx, r14
            mov rdx, r15
            mov r8, rax
            mov r9, r12
            mov qword ptr[rsp+32],0
            call WriteConsoleW

            test rax, rax
            jz writelinew_error_end

            jmp writelinew_end

        writelinew_nostrlen:
            mov rcx, r14
            mov rdx, r15
            mov r8, r13
            mov r9, r12
            mov qword ptr[rsp+32],0
            call WriteConsoleW

            test rax, rax
            jz writelinew_error_end

        writelinew_error_end:
        mov rax, -1

        writelinew_end:
        pop r15
        pop r14
        pop r13
        pop r12
        add rsp, 40
        ret
    WriteLineNoBreakW ENDP

    WriteLineW PROC
        ; rcx: pointer to string
        ; rdx number of chars to write (0 = write 0 terminated string)
        ; r8 consoleHandle
        ; r9 bytesWritten address
        sub rsp, 40
        push r12
        push r13
        push r14
        push r15

        mov r15, rcx     ; r15 = ptr to str
        mov r14, r8     ; r14 = consoleHandle
        mov r13, rdx    ; r13 = number of chars to write
        mov r12, r9     ; r12 = ptr to bytesWritten

        cmp r13,0
        jne writelinew_nostrlen

        writelinew_strlen: 
            call StrLenW    ; rcx is already our string

            mov rcx, r14
            mov rdx,r15
            mov r8, rax
            mov r9, r12
            mov qword ptr[rsp+32],0
            call WriteConsoleW

            test rax, rax
            jz writelinew_error_end


            mov rcx, r14
            lea rdx, endlineW
            mov r8, 2
            mov r9, r12
            mov qword ptr [rsp+32],0
            call WriteConsoleW

            test rax, rax
            jz writelinew_error_end

            jmp writelinew_end

        writelinew_nostrlen:
            mov rcx, r14
            mov rdx, r15
            mov r8, r13
            mov r9, r12
            mov qword ptr[rsp+32],0
            call WriteConsoleW

            test rax, rax
            jz writelinew_error_end


            mov rcx, r14
            lea rdx, endlineW
            mov r8, 2
            mov r9, r12
            mov qword ptr [rsp+32],0
            call WriteConsoleW

            test rax, rax
            jz writelinew_error_end


        writelinew_error_end:
        mov rax, -1

        writelinew_end:
        pop r15
        pop r14
        pop r13
        pop r12
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
        push rdi

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

        pop rdi
        add rsp, 32
        ret
    StrLenA ENDP
    
    WIDEToASCII PROC ; rcx pointer to WIDE string, rdx pointer to ASCII string
        mov rdi, rcx

        widetoascii_loop:
            ; copy byte
            xor rax, rax
            mov al, byte ptr[rdi]
            mov byte ptr [rdx], al

            ; repeat until null
            test al, al
            jz widetoascii_end

            ; move 2 bytes over in wide and 1 byte over in ascii
            add rdi, 2
            inc rdx

            jmp widetoascii_loop

            widetoascii_end:
        ret
    WIDEToASCII ENDP
END
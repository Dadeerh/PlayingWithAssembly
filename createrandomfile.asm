STD_OUTPUT_HANDLE EQU -11
GENERIC_READ EQU 80000000h
GENERIC_READWRITE EQU 0C0000000h 
FILE_SHARE_NONE EQU 0
FILE_SHARE_READ EQU 1
OPEN_EXISTING EQU 3
CREATE_ALWAYS EQU 2
FILE_ATTRIBUTE_NORMAL EQU 80h
NULL EQU 0
MEM_RELEASE EQU 00008000h
MEM_COMMIT EQU 00001000h
MEM_RESERVE EQU 00002000h
MEM_COMMIT_RESERVE EQU 00003000h
PAGE_READWRITE equ 04h


RANDOM_RANGE EQU 255

extrn GetCommandLineW : PROC
extrn CommandLineToArgvW : PROC
extrn CreateFileW : PROC
extrn WriteConsoleA : PROC
extrn GetStdHandle : PROC
extrn CloseHandle : PROC
extrn GetLastError : PROC
extrn ExitProcess : PROC
extrn WriteFile : PROC
extrn VirtualAlloc : PROC
extrn VirtualFree : PROC

.data
    consoleHandle dq ?
    bytesWritten dq ?
    message_error db "Error code: ", 0
    message_incorrect_params db "Not enough parameters. Usage: ", 0
    message_usage db "createrandomfile.exe filename [filesize (default 1GB)] [buffer size (default 1MB)]", 0
    message_file_failed db "Could not open file.", 0
    message_file_write_failed db "Could not write to file.", 0
    message_mem_failed db "Could not allocate buffer.", 0
    error_code byte 20 dup(?)
    message_success db "Succeeded." , 0
    message_param_buffer db "Using buffer size: ", 0
    message_param_filesize db "Using filesize: ", 0
    message_param_filename db "Writing to file: ", 0
    message_done db "Done.",0
    endlineA db 13,10
    commandline dq ?
    argc dq ?
    argv dq ?
    filename dq ?
    filename_ascii byte 260 dup(?)
    filehandle dq ?
    filesize_ascii byte 20 dup(?)
    filesize dq (1024*1024*1024)
    buffersize_ascii byte 20 dup(?)
    buffersize dq 1024*1024    
    random_seed dq ?
    bufferhandle dq ?
    
.code
    Start PROC
        and rsp, not 08h    ; make sure stack is aligned
        ; Get command line

        call Initialize
        test rax,rax
        jnz exit_with_error

        call GarbageToFile
        test rax,rax
        jnz exit_with_error

        graceful_exit:
            lea rcx, message_done
            xor rdx,rdx
            call WriteLineA

            call CloseHandles

            xor rcx, rcx
            call ExitProcess
            
        exit_with_error:
            call CloseHandles

            lea rcx, message_error
            xor rdx,rdx
            call WriteLineNoBreakA

            sub rsp, 20h
            call GetLastError
            add rsp, 20h

            mov rcx, rax
            lea rdx, error_code
            call NumberToASCII

            lea rcx, error_code
            xor rdx, rdx
            call WriteLineA

            mov rcx, 1
            call ExitProcess
        
        ret
    Start ENDP
    
    Initialize PROC
        call OpenStdOut
        cmp rax, -1
        je init_stdout_failed

        call InitializeParameters
        test rax,rax
        jnz init_params_failed

        lea rcx, message_param_filename
        xor rdx,rdx
        call WriteLineNoBreakA

        lea rcx, filename_ascii
        xor rdx,rdx
        call WriteLineA

        lea rcx, message_param_filesize
        xor rdx,rdx
        call WriteLineNoBreakA

        lea rcx, filesize_ascii
        xor rdx,rdx
        call WriteLineA

        lea rcx, message_param_buffer
        xor rdx,rdx
        call WriteLineNoBreakA

        lea rcx, buffersize_ascii
        xor rdx,rdx
        call WriteLineA

        call OpenFileHandle
        cmp rax, -1
        je init_file_failed

        mov rax, 0
        ret

        init_stdout_failed:
            mov rax, -1
            ret
        init_params_failed:
            lea rcx, message_incorrect_params
            xor rdx, rdx
            call WriteLineA

            lea rcx, message_usage
            xor rdx,rdx
            call WriteLineA

            mov rax, -1
            ret
        init_file_failed:
            lea rcx, message_file_failed
            xor rdx,rdx
            call WriteLineA

            mov rax, -1
            ret

        ret
    Initialize ENDP

    InitializeParameters PROC
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
        ; argv : executable
        ; argv + 8 : file to write
        ; argv + 16 : filesize
        ; argv + 24 : buffersize
        cmp argc, 4
        jb skip_buffersize

        mov r15,argv
        add r15,24
        mov rcx, [r15]
        lea rdx, buffersize_ascii
        call WIDEToASCII

        lea rcx, buffersize_ascii
        call ASCIIToNumber
        mov buffersize, rax

        skip_buffersize:
        cmp argc, 3
        jb skip_filesize

        mov r15,argv
        add r15,16
        mov rcx, [r15]
        lea rdx, filesize_ascii
        call WIDEToASCII

        lea rcx, filesize_ascii
        call ASCIIToNumber
        mov filesize, rax

        skip_filesize:

        cmp argc, 2
        jb argument_error

        mov r15, argv
        add r15, 8

        mov rbx, [r15]
        mov filename, rbx
        mov rcx, rbx
        lea rdx, filename_ascii
        call WIDEToASCII


        mov rax, 0
        ret

        argument_error:
        mov rax, -1

        ret
    InitializeParameters ENDP

    OpenStdOut PROC
        mov rcx, STD_OUTPUT_HANDLE
        sub rsp, 20h
        call GetStdHandle
        add rsp, 20h
        mov consoleHandle, rax

        ret
    OpenStdOut ENDP

    OpenFileHandle PROC
        mov rcx, filename
        mov rdx, GENERIC_READWRITE
        mov r8, NULL
        mov r9, NULL
        push NULL
        push FILE_ATTRIBUTE_NORMAL
        push CREATE_ALWAYS
        sub rsp, 20h
        call CreateFileW
        add rsp, 20h

        mov filehandle, rax

        add rsp, 18h
        ret
    OpenFileHandle ENDP


    CloseHandles PROC
        mov rcx, filehandle
        sub rsp, 20h
        call CloseHandle
        add rsp, 20h

        mov rcx, consoleHandle
        sub rsp, 20h
        call CloseHandle
        add rsp, 20h

        ret
    CloseHAndles ENDP

    GarbageToFile PROC
        push r15
        push r14
        push r13

        ; Allocate space for buffer
        mov rcx, NULL
        mov rdx, buffersize
        mov r8, MEM_COMMIT_RESERVE
        mov r9, PAGE_READWRITE
        sub rsp, 20h
        call VirtualAlloc
        add rsp, 20h
        mov bufferhandle,rax

        test rax,rax
        jz garbagetofile_mem_failed

        rdtsc
        mov random_seed, rax
        
        ; divide filesize by buffersize
        mov rax, filesize
        xor rdx,rdx
        mov rcx, buffersize
        div rcx
        ; number of loops with full buffer in rax
        mov r15, rax
        ; remainder in rdx
        mov r14, rdx

        xor r13,r13 ; our counter for number of times to fill the buffer

        garbagetofile_loop:
            mov rbx, buffersize

            mov rcx, bufferhandle
            mov rdx, buffersize
            call FillBuffer

            mov rcx, filehandle
            mov rdx, bufferhandle
            mov r8, buffersize
            lea r9, bytesWritten
            push NULL
            sub rsp, 20h
            call WriteFile
            add rsp, 28h
            
            test rax,rax
            jz garbagetofile_failed

            inc r13
            cmp r13,r15
            jb garbagetofile_loop

            test r14,r14
            jz garbagetofile_succeeded

            mov rcx, bufferhandle
            mov rdx, r14
            call FillBuffer

            mov rcx,filehandle
            mov rdx, bufferhandle
            mov r8, r14
            lea r9, bytesWritten
            push NULL
            sub rsp, 20h
            call WriteFile
            add rsp, 28h
            
            test rax,rax
            jz garbagetofile_failed


        jmp garbagetofile_succeeded

        garbagetofile_failed:
        lea rcx, message_file_write_failed
        xor rdx,rdx
        call WriteLineA

        mov rcx, bufferhandle
        mov rdx, NULL
        mov r8, MEM_RELEASE
        sub rsp, 20h
        call VirtualFree
        add rsp, 20h

        mov rax, -1
        jmp garbagetofile_end

        garbagetofile_mem_failed:
        lea rcx, message_mem_failed
        xor rdx,rdx
        call WriteLineA

        mov rax, -1
        jmp garbagetofile_end

        garbagetofile_succeeded:
        mov rcx, bufferhandle
        mov rdx, NULL
        mov r8, MEM_RELEASE
        sub rsp, 20h
        call VirtualFree
        add rsp, 20h

        mov rax,0

        garbagetofile_end:
        pop r13
        pop r14
        pop r15
        ret
    GarbageToFile ENDP  ; rcx pointer to buffer, rdx number of bytes to write there

    FillBuffer PROC
        push r15
        push r14

        mov r15, rcx
        mov r14, rdx
        
        fillbuffer_loop:
            mov rax, RANDOM_RANGE
            call RandomNumber
            mov byte ptr[r15], al
            inc r15
            dec r14
            test r14,r14
            jnz fillbuffer_loop

        pop r14
        pop r15
        ret
    FillBuffer ENDP

    RandomNumber PROC
        push rdx

        imul rdx, random_seed, 08088405h
        inc rdx
        mov random_seed, rdx
        mul rdx
        mov rax,rdx

        pop rdx
        ret
    RandomNumber ENDP

    
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

        add rsp, 16
        ret
    WriteLineA ENDP

    WriteLineNoBreakA PROC; rcx: pointer to string, rdx number of chars to write (0 = write 0 terminated string)
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

        pop r15
        pop r14
        pop r13

        add rsp, 8
        ret
    WriteLineNoBreakA ENDP
    
    StrLenA PROC
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
        ret
    StrLenA ENDP
END
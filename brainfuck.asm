GENERIC_READ EQU 80000000h
OPEN_EXISTING EQU 3
FILE_ATTRIBUTE_NORMAL EQU 80h
NULL EQU 0
MEM_RELEASE EQU 00008000h
MEM_COMMIT_RESERVE EQU 00003000h
PAGE_READWRITE equ 04h

; kernel32.lib
extrn CreateFileW : PROC
extrn GetStdHandle : PROC
extrn CloseHandle : PROC
extrn GetLastError : PROC
extrn ExitProcess : PROC
extrn VirtualAlloc : PROC
extrn VirtualFree : PROC
extrn GetFileSize : PROC
extrn ReadFile : PROC
extrn WriteConsoleA : PROC
extrn ReadConsoleA : PROC

; user32.lib
; shell32.lib

; common.obj - requires kernel32.lib and shell32.lib
extrn WriteLineA : PROC ; rcx: ptr to str (ascii, null terminated); rdx: chars to write (0 = use StrLenA); r8: stdoutHandle; r9: address of bytesWritten
extrn WriteLineW : PROC ; same as above, except WIDE str
extrn WriteLineNoBreakA : PROC ; same as above
extrn WriteLastError : PROC ; rcx: stdoutHandle; rdx: error value; r8 ptr to premessage (ascii, null terminated); r9 address of bytesWritten
extrn OpenStdOut : PROC ; no args
extrn OpenStdIn : PROC
extrn GetCommandlineArguments : PROC ; rcx: ptr to argc; rdx: ptr to argv
extrn ASCIIToNumber : PROC ; rcx: ptr to str (ASCII, 0 terminated)
extrn NumberToASCII : PROC ; rcx: number; rdx: ptr to ascii string
extrn WIDEToASCII : PROC ; rcx: ptr to str (WIDE, 0 0 terminated); rdx: ptr to result ASCII str

.data
message_usage db "Usage:",13,10, 9, "brainfuck.exe filename [memory size in bytes (default 1MB)]", 0
message_mem_failed db "Could not allocate buffer.", 0
message_file_failed db "Could not open file.", 0
message_args_failed db "Could not parse commandline arguments",0
message_openstdin_fail db "Could not open stdin.",0
message_closestdin_fail db "Could not close stdin.", 0
message_closestdout_fail db "Could not close stdout",0
message_filesize    db "Could not get filesize.",0
message_error_output db "Could not output byte from brainfuck program. ",0
message_error_input db "Could not input byte from brainfuck program." ,0
message_fileread_error db "Could not read from file.",0
message_mem_filecontents db "Could not allocate space for file contents.",0
message_mem_brainfuck db "Could not allocate space for brainfuck memory.",0
message_mem_filecontents_free db  "Could not free filecontents.", 0
message_mem_brainfuck_free db  "Could not free brainfuck memory.", 0
message_bferror_missing_right_loop db "Missing right loop ']'. Exiting.",0
message_bferror_missing_left_loop db "Missing left loop '['. Exiting.",0
message_bferror_oob_left db "Pointer went out of bounds to the left. Exiting. ",0
message_bferror_oob_right db "Pointer went out of bounds to the right. Exiting. ",0
message_error db "Windows error code: ",0
message_args_filename db "Reading from file: ", 0
message_args_buffersize db "Using buffersize (in bytes): ", 0
message_sep_top db "======================[ BRAINFUCK ]=======================", 0
message_sep_bottom db "=========================[ END ]==========================", 0
error_code_ascii byte 20 dup(?)
endlineA db 13,10
commandline dq ?
argc dq ?
argv dq ?
filename dq ?                       ; bf filename (WIDE)
filehandle dq ?                     ; handle to file
filesize dq ?
filecontents dq ?                   ; pointer to memory where bf file is read to
brainfuckbuffer dq ?                ; pointer to memory used for running brainfuck
brainfuckbuffersize dq 1024*1024    ; size of brainfuck memory
brainfuckbuffersize_ascii byte 20 dup(?)
stdoutHandle dq ?
stdinHandle dq ?
bytesWritten dq ?
bytesRead dq ?

.code
    Start PROC
        and rsp, not 08h    ; make sure stack is aligned
        sub rsp, 20h
        
        call Initialize             ; initialize (also opens file, needed for filesize which is needed for the memory alloc)
        cmp rax, -1
        je start_exit_with_error


        call PrintParameters        ; print start stuff
        cmp rax, -1
        je start_exit_with_error

        call PrintStartLine
        cmp rax, -1
        je start_exit_with_error


        call ReadFileToMemory       ; Read file
        cmp rax, -1
        je start_exit_with_error

        call CloseFile              ; Close file (close filehandle)
        cmp rax, -1
        je start_exit_with_error


        call EvaluateBrainfuck      ; Evaluate
        cmp rax, -1
        je start_exit_with_error


        call PrintEndLine           ; print end stuff
        cmp rax, -1
        je start_exit_with_error


        call Close                  ; Deinitialize (deallocate mem, close stdout handle)
        cmp rax, -1
        je start_exit_with_error


        start_graceful_exit:
        xor rcx, rcx
        call ExitProcess

        ret
        
        start_exit_with_error:
        mov rcx, stdoutHandle
        lea rdx, message_error
        lea r8,  bytesWritten
        call WriteLastError

        mov rcx, 1
        call ExitProcess

        add rsp, 20h
        ret
    Start ENDP

    EvaluateBrainfuck PROC
        push rdi
        push r15
        push r14
        push r12

        mov rdi, filecontents       ; bf code
        xor r15,r15                 ; offset in filecontents (ie. bf code)
        mov rbx, brainfuckbuffer    ; position 0 of bf buffer
        xor r14,r14                 ; bf controlled ptr to brainfuckbuffer (i.e. bf memory space) - actually offset from rbx

        xor r12,r12                 ; counter of [
        
        ;; Main evaluation loop
        evaluatebrainfuck_parse_instruction:
            xor rax,rax
            mov al, byte ptr[rdi+r15]
        
            ; Output the character signified by the cell at the pointer 
            cmp al, '.'
            je evaluatebrainfuck_output

            ; Input a character and store it in the cell at the pointer 
            cmp al, ','
            je evaluatebrainfuck_input

            ; Move the pointer to the right 
            cmp al, '>'
            je evaluatebrainfuck_ptr_right

            ; Move the pointer to the left 
            cmp al, '<'
            je evaluatebrainfuck_ptr_left

            ; Increment the memory cell at the pointer
            cmp al, '+'
            je evaluatebrainfuck_inc

            ; Decrement the memory cell at the pointer 
            cmp al, '-'
            je evaluatebrainfuck_dec

            ; Jump past the matching ] if the cell at the pointer is 0
            cmp al, '['
            je evaluatebrainfuck_loop_skipforward

            ; Jump back to the matching [ if the cell at the pointer is nonzero 
            cmp al, ']'
            je evaluatebrainfuck_loop_skipbackwards

            ; any other character is ignored
            jmp evaluatebrainfuck_next_instruction

            evaluatebrainfuck_output:
                mov rcx, stdoutHandle
                lea rdx, [rbx+r14]
                mov r8, 1
                lea r9, bytesWritten
                sub rsp, 20h
                call WriteConsoleA
                add rsp, 20h
                test rax,rax
                jz evaluatebrainfuck_error_output

                jmp evaluatebrainfuck_next_instruction

            evaluatebrainfuck_input:
                mov rcx, stdinHandle
                lea rdx, [rbx+r14]
                mov r8, 1
                lea r9, bytesRead
                push NULL
                sub rsp, 20h
                call ReadConsoleA
                add rsp, 28h
                test rax,rax
                jz evaluatebrainfuck_error_input
                
                jmp evaluatebrainfuck_next_instruction

            evaluatebrainfuck_ptr_right:
                inc r14

                cmp r14, brainfuckbuffersize
                ja evaluatebrainfuck_bferror_oob_right

                jmp evaluatebrainfuck_next_instruction

            evaluatebrainfuck_ptr_left:
                dec r14

                cmp r14, 0
                jl evaluatebrainfuck_bferror_oob_left   ; jl = jump less. That's signed. jb = jump below = unsigned
                
                jmp evaluatebrainfuck_next_instruction

            evaluatebrainfuck_inc:
                inc byte ptr[rbx+r14]

                jmp evaluatebrainfuck_next_instruction

            evaluatebrainfuck_dec:
                dec byte ptr[rbx+r14]

                jmp evaluatebrainfuck_next_instruction

            evaluatebrainfuck_loop_skipforward:
                cmp byte ptr[rbx+r14], 0
                jne evaluatebrainfuck_next_instruction  ; if 0, jump past ] (right), else (jne) just go to next instruction

                xor r12,r12
                evaluatebrainfuck_loop_skipforward_innerloop:   ; skip ahead to matching ]
                    inc r15

                    cmp r15,filesize
                    jae evaluatebrainfuck_bferror_missing_right_loop

                    xor rax,rax
                    mov al, byte ptr[rdi+r15]
                    cmp al, '['
                    jne evaluatebrainfuck_loop_skipforward_noinnerloopfound

                    inc r12 ; inner loop found, increase counter

                    jmp evaluatebrainfuck_loop_skipforward_innerloop

                    evaluatebrainfuck_loop_skipforward_noinnerloopfound:
                        cmp al, ']'
                        jne evaluatebrainfuck_loop_skipforward_innerloop

                        cmp r12,0                               
                        je evaluatebrainfuck_next_instruction  ; no inner loops found and we're at the end, so go to next instruction
                                        ; otherwise, what we are seeing is the end of the inner loop, and not the end of the loop we're currently skipping over
                        dec r12
                        jmp evaluatebrainfuck_loop_skipforward_innerloop

            evaluatebrainfuck_loop_skipbackwards:
                cmp byte ptr[rbx+r14], 0
                je evaluatebrainfuck_next_instruction ; if non-0 jump back to [ (left), else (je) just go to next instruction

                xor r12,r12

                evaluatebrainfuck_loop_skipbackwards_innerloop:
                    dec r15
                    
                    cmp r15,0
                    jl evaluatebrainfuck_bferror_missing_left_loop

                    xor rax,rax
                    mov al, byte ptr[rdi+r15]
                    cmp al, ']'
                    jne evaluatebrainfuck_loop_skipbackwards_noinnerloopfound   ; no inner loop found, just continue

                    inc r12 ; inner loop found, add to counter

                    jmp evaluatebrainfuck_loop_skipbackwards_innerloop

                    evaluatebrainfuck_loop_skipbackwards_noinnerloopfound:
                        cmp al, '['
                        jne evaluatebrainfuck_loop_skipbackwards_innerloop ; if we don't find loop start, just continue searching

                        cmp r12, 0
                        je evaluatebrainfuck_parse_instruction; no inner loops found, but we are at left loop, go to parse next intstruction (PS: we're skipping normal next instruction as start loop needs to be handled as well)

                        dec r12
                        jmp evaluatebrainfuck_loop_skipbackwards_innerloop

            evaluatebrainfuck_next_instruction:
                inc r15

                cmp r15, filesize               ; We reached end of file instruction
                jae evaluatebrainfuck_success

                jmp evaluatebrainfuck_parse_instruction

        ;; This is for brainfuck errors, e.g. going outside memory space, illegal character, etc.
        evaluatebrainfuck_bferror_missing_right_loop:
            lea rcx, message_bferror_missing_right_loop
            xor rdx,rdx
            mov r8, stdoutHandle
            lea r9, bytesWritten
            call WriteLineA
            cmp rax,-1
            je evaluatebrainfuck_error
            jmp evaluatebrainfuck_success

        evaluatebrainfuck_bferror_missing_left_loop:
            lea rcx, message_bferror_missing_left_loop
            xor rdx,rdx
            mov r8, stdoutHandle
            lea r9, bytesWritten
            call WriteLineA
            cmp rax,-1
            je evaluatebrainfuck_error
            jmp evaluatebrainfuck_success

        evaluatebrainfuck_bferror_oob_left:
            lea rcx, message_bferror_oob_left
            xor rdx,rdx
            mov r8, stdoutHandle
            lea r9, bytesWritten
            call WriteLineA
            cmp rax,-1
            je evaluatebrainfuck_error
            jmp evaluatebrainfuck_success

        evaluatebrainfuck_bferror_oob_right:
            lea rcx, message_bferror_oob_right
            xor rdx,rdx
            mov r8, stdoutHandle
            lea r9, bytesWritten
            call WriteLineA
            cmp rax,-1
            je evaluatebrainfuck_error
            jmp evaluatebrainfuck_success
            
        ;; this is for critical windows related errors.     
        evaluatebrainfuck_error_input:
        lea rcx, message_error_input
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA
        jmp evaluatebrainfuck_error

        evaluatebrainfuck_error_output:
        lea rcx, message_error_output
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA

        evaluatebrainfuck_error:
        mov rax,-1
        jmp evaluatebrainfuck_end

        evaluatebrainfuck_success:
        mov rax,0

        evaluatebrainfuck_end:
        pop r12
        pop r14
        pop r15
        pop rdi
        ret
    EvaluateBrainfuck ENDP

    ;;; INITIALIZE, READ FILE, ETC - STARTUP FUNCTIONS
    Initialize PROC
        sub rsp, 20h

        call OpenStdOut             ; open stdout
        cmp rax, -1
        je initialize_error_stdout
        mov stdoutHandle, rax

        call OpenStdIn
        cmp rax, -1
        je initialize_error_stdin
        mov stdinHandle, rax

        call InitializeArguments    ; command line args
        cmp rax, -1
        je initialize_end_error

        call InitializeFileHandle   ; file handle (needed for memory alloc)
        cmp rax, -1
        je initialize_end_error

        call InitializeMemoryAlloc  ; memory alloc
        cmp rax, -1
        je initialize_end_error

        call InitializeZeroOutBFMemory  ; make sure bf memory is zeroed out

        jmp initialize_end_gracefully

        initialize_error_stdout:
        mov rax, 1
        call ExitProcess

        initialize_error_stdin:
        lea rcx, message_openstdin_fail
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA
        jmp initialize_end_error

        initialize_end_gracefully: 
        mov rax, 0
        jmp initialize_end

        initialize_end_error: 
        mov rax, -1

        initialize_end:
        add rsp, 20h
        ret
    Initialize ENDP

    InitializeArguments PROC
        sub rsp, 20h

        lea rcx, argc
        lea rdx, argv
        call GetCommandlineArguments
        cmp rax, -1
        je initializearguments_error_args
        ; argv + 0 = brainfuck.exe
        ; argv + 8 = filename
        ; argv + 16 = buffersize

        cmp argc, 2
        jb initializearguments_printhelp

        cmp argc, 3
        ja initializearguments_printhelp
        jb initializearguments_skip_buffer

        ;; get buffer size argument
        mov rax, argv
        add rax, 16

        mov rcx, qword ptr [rax]
        lea rdx, brainfuckbuffersize_ascii
        call WIDEToASCII

        lea rcx, brainfuckbuffersize_ascii
        call ASCIIToNumber
        mov brainfuckbuffersize, rax

        initializearguments_skip_buffer:
        ;; get filename argument
        mov rax, argv
        add rax, 8
        mov rbx, [rax]
        mov filename, rbx

        jmp initializearguments_end_gracefully

        initializearguments_printhelp:
        call PrintUsage
        cmp rax, -1
        je initializearguments_end_error

        mov rax, 0
        call ExitProcess

        initializearguments_error_args:
        lea rcx, message_args_failed
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA
        cmp rax, -1
        je initializearguments_end_error

        initializearguments_end_gracefully: 
        mov rax, 0
        jmp initializearguments_end

        initializearguments_end_error:
        mov rax, -1

        initializearguments_end: 
        add rsp, 20h
        ret
    InitializeArguments ENDP

    InitializeFileHandle PROC
        sub rsp, 20h
        
        mov rcx, filename
        mov rdx, GENERIC_READ
        mov r8, NULL
        mov r9, NULL
        push NULL
        push FILE_ATTRIBUTE_NORMAL
        push OPEN_EXISTING
        sub rsp, 20h
        call CreateFileW
        add rsp, 38h ; the pushed args + shadowspace

        cmp rax, -1
        je initializefilehandle_error

        mov filehandle, rax

        initializefilehandle_success:
        mov rax, 0
        jmp initializefilehandle_end

        initializefilehandle_error: 
        lea rcx, message_file_failed
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA

        mov rax, -1

        initializefilehandle_end:
        add rsp, 20h
        ret
    InitializeFileHandle ENDP

    InitializeMemoryAlloc PROC
        sub rsp, 20h

        ; Allocate memory for file contents (i.e. filesize)
        mov rcx, filehandle
        mov rdx, NULL
        call GetFileSize
        cmp eax, -1
        je intializememoryalloc_filesize_failed

        mov filesize, rax

        mov rcx, NULL
        mov rdx, filesize
        mov r8, MEM_COMMIT_RESERVE
        mov r9, PAGE_READWRITE
        call VirtualAlloc
        test rax,rax
        jz intializememoryalloc_contents_failed

        mov filecontents, rax

        ; Allocate brainfuck memory
        mov rcx, NULL
        mov rdx, brainfuckbuffersize
        mov r8, MEM_COMMIT_RESERVE
        mov r9, PAGE_READWRITE
        call VirtualAlloc
        test rax,rax
        jz intializememoryalloc_brainfuck_failed

        mov brainfuckbuffer, rax

        jmp initializememoryalloc_success

        intializememoryalloc_filesize_failed:
        lea rcx, message_filesize
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA
        jmp initializememoryalloc_error

        intializememoryalloc_contents_failed:
        lea rcx, message_mem_filecontents
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA
        jmp initializememoryalloc_error

        intializememoryalloc_brainfuck_failed:
        lea rcx, message_mem_brainfuck
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA
        jmp initializememoryalloc_error

        initializememoryalloc_error:
        mov rax, -1
        jmp initializememoryalloc_end
    
        initializememoryalloc_success:
        mov rax, 0
    
        initializememoryalloc_end:
        add rsp, 20h
        ret
    InitializeMemoryAlloc ENDP
    
    InitializeZeroOutBFMemory PROC
        push rdi

        mov rdi, brainfuckbuffer
        xor rcx,rcx

        initalizezerooutbfmemory_loop:
            mov byte ptr[rdi+rcx], 0
            
            inc rcx
            cmp rcx, brainfuckbuffersize
            jb initalizezerooutbfmemory_loop

        pop rdi
        ret
    InitializeZeroOutBFMemory ENDP

    ReadFileToMemory PROC
        sub rsp, 28h
        
        mov rcx, filehandle
        mov rdx, filecontents
        mov r8, filesize
        lea r9, bytesRead
        call ReadFile
        test rax,rax
        jz readfiletomemory_error

        readfiletomemory_succes:
        mov rax, 0
        jmp readfiletomemory_end

        readfiletomemory_error:
        lea rcx, message_fileread_error
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA

        mov rax, -1

        readfiletomemory_end:
        add rsp, 28h
        ret
    ReadFileToMemory ENDP

    ;;; CLOSE EVERYTHING DOWN FUNCTIONS
    Close PROC
        sub rsp, 20h

        mov rcx, stdoutHandle
        call CloseHandle
        test rax,rax
        jz close_error_stdout

        mov rcx, stdinHandle
        call CloseHandle
        test rax,rax
        jz close_error_stdin

        call CloseMemory
        cmp rax, -1
        je close_error

        close_gracefully: 
        mov rax,0
        jmp close_end

        close_error_stdout: 
        lea rcx, message_closestdout_fail
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA

        close_error_stdin: 
        lea rcx, message_closestdin_fail
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA
    
        close_error:
        mov rax, -1

        close_end:

        add rsp, 20h
        ret
    Close ENDP

    CloseFile PROC
        sub rsp, 20h
        
        ; close file handle 
        mov rcx, filehandle
        call CloseHandle
        test rax,rax
        jz closefile_error

        closefile_success:
        mov rax, 0
        jmp closefile_end

        closefile_error:
        mov rax, -1

        closefile_end:
        add rsp, 20h
        ret
    CloseFile ENDP

    CloseMemory PROC
        sub rsp, 20h

        call DeallocateBrainfuckMemory
        cmp rax, -1
        je closememory_error

        call DeallocateFileContentMemory
        cmp rax, -1
        je closememory_error
        
        closememory_success:
        mov rax, 0
        jmp closememory_end

        closememory_error:
        mov rax,-1

        closememory_end:
        add rsp, 20h
        ret
    CloseMemory ENDP

    DeallocateBrainfuckMemory PROC
        sub rsp, 20h

        ; deallocate file buffer
        mov rcx, brainfuckbuffer
        mov rdx, NULL
        mov r8, MEM_RELEASE
        call VirtualFree
        
        test rax,rax
        jz deallocatebrainfuckmemory_virtualfreefailed
        jmp deallocatebrainfuckmemory_success

        deallocatebrainfuckmemory_virtualfreefailed:
        lea rcx, message_mem_brainfuck_free
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA

        jmp deallocatebrainfuckmemory_error

        deallocatebrainfuckmemory_success:
        mov rax, 0
        jmp deallocatebrainfuckmemory_end

        deallocatebrainfuckmemory_error:
        mov rax, -1

        deallocatebrainfuckmemory_end:
        add rsp, 20h
        ret
    DeallocateBrainfuckMemory ENDP

    DeallocateFileContentMemory PROC
        sub rsp, 20h

        ; deallocate file buffer
        mov rcx, filecontents
        mov rdx, NULL
        mov r8, MEM_RELEASE
        call VirtualFree
        
        test rax,rax
        jz deallocatefilecontentmemory_virtualfreefailed
        jmp deallocatefilecontentmemory_success

        deallocatefilecontentmemory_virtualfreefailed:
        lea rcx, message_mem_filecontents_free
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA

        jmp deallocatefilecontentmemory_error

        deallocatefilecontentmemory_success:
        mov rax, 0
        jmp deallocatefilecontentmemory_end

        deallocatefilecontentmemory_error:
        mov rax, -1

        deallocatefilecontentmemory_end:
        add rsp, 20h
        ret
    DeallocateFileContentMemory ENDP

    ;;; PRINTING DEFAULT STUFF TO STDOUT
    PrintUsage PROC
        lea rcx, message_usage
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA
        ret
    PrintUsage ENDP

    PrintParameters PROC
        sub rsp, 20h

        lea rcx, message_args_filename
        xor rdx, rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineNoBreakA
        cmp rax, -1
        je printparameters_exit_with_error

        mov rcx, filename
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineW
        cmp rax, -1
        je printparameters_exit_with_error

        lea rcx, message_args_buffersize
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineNoBreakA
        cmp rax, -1
        je printparameters_exit_with_error

        mov rcx, brainfuckbuffersize
        lea rdx, brainfuckbuffersize_ascii
        call NumberToASCII

        lea rcx, brainfuckbuffersize_ascii
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA
        cmp rax, -1
        je printparameters_exit_with_error

        mov rax, 0
        jmp printparameters_end

        printparameters_exit_with_error:
        mov rax, -1

        printparameters_end: 
        add rsp, 20h
        ret
    PrintParameters ENDP

    PrintStartLine PROC
        sub rsp, 20h

        lea rcx, message_sep_top
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA

        add rsp, 20h
        ret
    PrintStartLine ENDP

    PrintEndLine PROC
        sub rsp, 20h


        lea rcx, endlineA
        mov rdx,2
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineNoBreakA

        lea rcx, message_sep_bottom
        xor rdx,rdx
        mov r8, stdoutHandle
        lea r9, bytesWritten
        call WriteLineA
        
        add rsp, 20h
        ret
    PrintEndLine ENDP

END
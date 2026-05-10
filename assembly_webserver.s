.intel_syntax noprefix

.equ S_SOCKADDR_STRT, 16
.equ SOCK_FD, 17
.equ ACC_SOCK, 18
.equ ACCEPT_TO, 4096
.equ ACCEPT_LEN, 2048
.equ GETREQ_OPEN_FD, 128
.equ GETREQ_READ_OFFSET, 136
.equ GET_READTO, 1024

.section .rodata
    stat_resp: .ascii "HTTP/1.0 200 OK", "\r", "\n", "\r", "\n"
    .equ resp_len, . - stat_resp

    req_get: .ascii "GET "
    .equ rget_len, . - req_get

    req_post: .ascii "POST "
    .equ rpost_len, . - req_post

    content_length: .ascii "Content-Length: "
    .equ clength_len, . - content_length

.section .text
.global _start

_start:
	mov rbp, rsp
	sub rsp, 4096
	
	mov rax, 41 # socket(AF_INET, SOCK_STREAM, 0)
	mov rdi, 2
	mov rsi, 1
	mov rdx, 0
	syscall
	
	mov WORD PTR [rbp - S_SOCKADDR_STRT], 2
	mov WORD PTR [rbp - S_SOCKADDR_STRT + 2], 0x5000
	mov DWORD PTR [rbp - S_SOCKADDR_STRT + 4], 0
	mov QWORD PTR [rbp - S_SOCKADDR_STRT + 8], 0
	
	mov BYTE PTR [rbp - SOCK_FD], al # socket file descriptor
	
	mov rax, 49 # bind(SOCK_FD, S_SOCKADDR_STRT, 16)
    movzx rdi, BYTE PTR [rbp - SOCK_FD]
	lea rsi, [rbp - S_SOCKADDR_STRT]
	mov rdx, 16
	syscall
	
	mov rax, 50 # listen(SOCK_FD, 0)
	movzx rdi, BYTE PTR [rbp - SOCK_FD]
	mov rsi, 0
	syscall
	
    accept_request:

	mov rax, 43 # accept(SOCK_FD, NULL, NULL)
	movzx rdi, BYTE PTR [rbp - SOCK_FD]
	mov rsi, 0
	mov rdx, 0
	syscall
	
    mov BYTE PTR [rbp - ACC_SOCK], al # accepted socket file descriptor

    mov rax, 57 # fork()
    syscall

    cmp rax, 0
    jz child
    jg parent

    fork_error:
        lea rbx, [rip + exit]
        jmp rbx # just exit on failure
    parent:
        mov rax, 3 # close(ACC_SOCK) on the parent
        movzx rdi, BYTE PTR [rbp - ACC_SOCK]
        syscall
        lea rbx, [rip + accept_request]
        jmp rbx
    child:
        mov rax, 3 # close(SOCK_FD) on the child
        movzx rdi, BYTE PTR [rbp - SOCK_FD]
        syscall

        mov rax, 0 # read(ACC_SOCK, accept_to_location, accept_length)
        movzx rdi, BYTE PTR [rbp - ACC_SOCK]
        lea rsi, [rbp - ACCEPT_TO]
        mov rdx, ACCEPT_LEN
        syscall

        mov QWORD PTR [rbp - 2000], rax # number of read bytes

        .get_test:
            lea rsi, [rip + req_get]
            lea rdi, [rbp - ACCEPT_TO]
            mov rcx, rget_len
            cld
            repe cmpsb
            je .get_handler

        .post_test:
            lea rsi, [rip + req_post]
            lea rdi, [rbp - ACCEPT_TO]
            mov rcx, rpost_len
            cld
            repe cmpsb
            je .post_handler
            
        .get_handler:
            lea rdi, [rbp - ACCEPT_TO + rget_len]
            mov al, 0x20
            or ecx, -1
            cld
            repne scasb
            mov BYTE PTR [rdi - 1], 0 # location of the place where we need to replace the space with a null terminator

            .open:
                mov rax, 2
                lea rdi, [rbp - ACCEPT_TO + rget_len]
                mov rsi, 0
                syscall
            
            mov DWORD PTR [rbp - GETREQ_OPEN_FD], eax

            .read:
                mov edi, DWORD PTR [rbp - GETREQ_OPEN_FD]
                mov rax, 0
                lea rsi, [rbp - GET_READTO]
                mov rdx, 511
                syscall
            
            mov DWORD PTR [rbp - GETREQ_READ_OFFSET], eax
            
            mov edi, DWORD PTR [rbp - GETREQ_OPEN_FD]
            mov rax, 3
            syscall

            mov rax, 1 # write(ACC_SOCK, stat_rsp, resp_len)
            movzx rdi, BYTE PTR [rbp - ACC_SOCK]
            lea rsi, [rip + stat_resp]
            mov rdx, resp_len
            syscall

            mov rax, 1 # write(ACC_SOCK, write_file, write_file_count)
            movzx rdi, BYTE PTR [rbp - ACC_SOCK]
            lea rsi, [rbp - GET_READTO]
            mov edx, DWORD PTR [rbp - GETREQ_READ_OFFSET]
            syscall

            mov rax, 3 # close(ACC_SOCK)
            movzx rdi, BYTE PTR [rbp - ACC_SOCK]
            syscall

            lea rax, [rip + exit]
            jmp rax
        
        .post_handler:
            lea rdi, [rbp - ACCEPT_TO + rpost_len]
            mov al, 0x20
            or ecx, -1
            cld
            repne scasb
            mov BYTE PTR [rdi - 1], 0 # location of the place where we need to replace the space with a null terminator for the filename

            .find_end:
                mov al, 0x0d
                repne scasb
                cmp DWORD PTR [rdi - 1], 0x0a0d0a0d # \r\n\r\n end of HTTP headers
                je .open_post
                jmp .find_end

            .open_post:
                add rdi, 3 # now points to request body
                mov r8, rdi

                lea rbx, [rbp - ACCEPT_TO]
                sub rbx, rdi
                neg rbx
                mov r12, QWORD PTR [rbp - 2000]
                sub r12, rbx
                ..actually_open:
                    mov rax, 2
                    lea rdi, [rbp - ACCEPT_TO + rpost_len]
                    mov rsi, 1 | 64
                    mov rdx, 511
                    syscall
            mov r9, rax
            .write:
                mov rdi, rax
                mov rax, 1
                lea rsi, [r8]
                mov rdx, r12
                syscall

            mov rax, 3
            mov rdi, r9
            syscall

            .send_response:
                mov rax, 1 # write(ACC_SOCK, stat_rsp, resp_len)
                movzx rdi, BYTE PTR [rbp - ACC_SOCK]
                lea rsi, [rip + stat_resp]
                mov rdx, resp_len
                syscall

        exit:
            mov rax, 60 # exit(0)
            mov rdi, 0
            syscall
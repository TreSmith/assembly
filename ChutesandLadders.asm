;%include "/usr/local/share/csc314/asm_io.inc"

;Tre' Smith

%define TICK    100000


; the file that stores the initial state
%define BOARD_FILE 'board.txt'

; how to represent everything
%define EMPTY_CHAR '.'
%define WALL_CHAR '#'
%define PLAYER_CHAR 'O'
%define ENEMY_CHAR 'X'

; the size of the game screen in characters
%define HEIGHT 20
%define WIDTH 40

; the player starting position.
; top left is considered (0,0)
%define STARTX 1
%define STARTY 1

; these keys do things
%define EXITCHAR 'x'
%define NEXTMOVE ' '
%define FINISH_LINE 'F'

%define LADDER_CHAR 'H'
%define SLIDE_CHAR '|'
%define LADDER_START '^'
%define SLIDE_START 'S'


segment .data

        ; used to fopen() the board file defined above
        board_file                      db BOARD_FILE,0

        ; used to change the terminal mode
        mode_r                          db "r",0
        raw_mode_on_cmd         db "stty raw -echo",0
        raw_mode_off_cmd        db "stty -raw echo",0

        ; called by system() to clear/refresh the screen
        clear_screen_cmd        db "clear",0

        ; things the program will print
        help_str                        db 13,10,"Chutes and Ladders! Made by Tre' Smith",13,10,"Controls: ", \
                                                        "Space Bar = NEXT MOVE | ", \
                                                        EXITCHAR," = EXIT",13,10, \
                                                        "Enemy Character: ", ENEMY_CHAR,13,10, \
                                                        "Player Character: ", PLAYER_CHAR, \
                                                        13,10,10,0
        rollfmt                         db      13,10,"Turn #: %d, Player roll: %d, Enemy Roll: %d",13,10,0

        pwins_fmt                       db      13,10,"Player Wins! :)",13,10,0
        ewins_fmt                       db      13,10,"Enemy Wins! :(",13,10,0

segment .bss

        ; this array stores the current rendered gameboard (HxW)
        board   resb    (HEIGHT * WIDTH)

        ; these variables store the current player position
        xpos    resd    1
        ypos    resd    1

        expos   resd    1
        eypos   resd    1

        upflag          resd    0
        nothing         resb    256             ; UGLY HACK
        downflag        resd    0

                nothing2                resb    256             ;UGLY HACK Some reason I need these to keep program from overwritting variables
        playerroll      resd    0
                nothing1        resb    256                     ;UGLY HACK
        turn            resd    1
                nothing3        resb    256
        enemyroll       resd    0

segment .text

        global  asm_main
        global  raw_mode_on
        global  raw_mode_off
        global  init_board
        global  render

        extern  system
        extern  putchar
        extern  getchar
        extern  printf
        extern  fopen
        extern  fread
        extern  fgetc
        extern  fclose

        extern  usleep
        extern  fcntl

        extern time
        extern srand
        extern rand

asm_main:
        enter   0,0
        pusha
        ;***************CODE STARTS HERE***************************

        ; put the terminal in raw mode so the game works nicely
        call    raw_mode_on

        ; read the game board file into the global variable
        call    init_board

        ; set the player at the proper start position
        mov             DWORD [xpos], STARTX
        mov             DWORD [ypos], STARTY
        mov             DWORD[expos], STARTX    ;Might have to implement putting the enemy character on the board if the turn count is 0
        mov             DWORD[eypos], STARTY

    push    0               ;Get Random Value % 6
    call    time
    add             esp, 4
    push    eax
    call    srand
    add             esp, 4




        ; the game happens in this loop
        ; the steps are...
        ;   1. render (draw) the current board
        ;   2. get a character from the user
        ;       3. store current xpos,ypos in esi,edi
        ;       4. update xpos,ypos based on character from user
        ;       5. check what's in the buffer (board) at new xpos,ypos
        ;       6. if it's a wall, reset xpos,ypos to saved esi,edi
        ;       7. otherwise, just continue! (xpos,ypos are ok)
        game_loop:
                ; draw the game board
                call    render

                mov             DWORD[playerroll], 0

                ; get an action from the user
                call    getchar

                cmp             al, -1
                je              game_loop



                ; store the current position
                ; we will test if the new position is legal
                ; if not, we will restore these
                mov             esi, [xpos]
                mov             edi, [ypos]


                ; choose what to do

                cmp             eax, NEXTMOVE
                je              nextmove
                cmp             eax, EXITCHAR
                je              game_loop_end

                jmp             game_loop                       ; or just do nothing

                ; move the player according to the input character
                nextmove:
                        inc             DWORD[turn]
                        mov             DWORD[upflag], 0
                        mov             DWORD[downflag], 0      ;Set the flags to 0

                        call    rand    ;Get random number % 6
                        cdq
                        mov             ebx, 6
                        idiv    ebx
                        inc             edx
                        mov             ecx, edx        ;Set the random value as the counter

                        mov             DWORD[playerroll], ecx

                        push    DWORD[ypos]
                        call    getdirection            ;Get what ypos mod 2 it is so you can tell if you have to move left or right
                        cmp             edx, 0
                        je              move_left
                        cmp             edx, 1
                        je              move_right

                        move_left:
                                 mov     esi, DWORD[xpos]
                 mov     edi, DWORD[ypos]

                 cmp     ecx, 0
                    je     input_end
                 dec     DWORD[xpos]
                 mov     eax, WIDTH
                 mul     DWORD [ypos]
                 add     eax, [xpos]
                 lea     eax, [board + eax]
                                cmp             BYTE[eax], FINISH_LINE
                                        je              player_wins
                                cmp             ecx, 1
                                        jne     nextstepl
                                call    flagladder
                                call    flagslide
                                nextstepl:
                                 cmp     BYTE [eax], WALL_CHAR
                      jne     valid_movel
                 mov     DWORD [xpos], esi
                 mov     DWORD [ypos], edi
                 jmp     move_down           ;If byte is wallchar go down

                                valid_movel:
                                        dec             ecx
                                        jmp             move_left


                                ;Add logic to test for wall, if wall then move down

                        move_down:
                                mov             esi, DWORD[xpos]
                                mov             edi, DWORD[ypos]

                                cmp             ecx, 0
                                je              input_end

                                inc             DWORD [ypos]
                                mov     eax, WIDTH
                                        mul     DWORD [ypos]
                                        add     eax, [xpos]
                                lea     eax, [board + eax]
                                cmp     BYTE [eax], WALL_CHAR
                                jne     valid_moved

                                ;Implement code for winning move
                                jmp             game_loop_end           ;just for testing


                                valid_moved:
                                        dec             ecx
                                        push    DWORD[ypos]
                                        call    getdirection

                                        cmp             edx, 1
                                        je              move_right
                                        cmp             edx, 0
                                        je              move_left

                                ;Add logic to test for wall, if wall then don't move down

                        move_right:
                                mov             esi, DWORD[xpos]
                                mov             edi, DWORD[ypos]

                                cmp             ecx, 0
                                je              input_end

                                inc             DWORD[xpos]

                        mov     eax, WIDTH
                mul     DWORD [ypos]
                        add     eax, [xpos]
                        lea     eax, [board + eax]

                                cmp             ecx, 1
                                        jne     nextstepr
                                call    flagladder
                                call    flagslide
                                nextstepr:
                                cmp     BYTE [eax], WALL_CHAR
                                 jne     valid_mover
                                mov     DWORD [xpos], esi
                                mov     DWORD [ypos], edi
                                jmp             move_down                       ;If byte is wallchar go down

                                valid_mover:
                                dec             ecx                     ;inc ecx to mark that one spot out of random%6 has been moved
                                jmp             move_right

                        input_end:

                        ;check if the character is a slide or a ladder

                        cmp             DWORD[upflag], 1
                                je              goupladder
                        cmp             DWORD[downflag], 1
                                je              godownslide
                jmp             enemy_move

        goupladder:
                mov             esi, DWORD[xpos]
                mov             edi, DWORD[ypos]
                upmore:
                        dec             DWORD[ypos]
                        mov             eax, WIDTH
                        mul             DWORD[ypos]
                        add             eax, [xpos]
                        lea             eax, [board + eax]
                        cmp             BYTE[eax], LADDER_CHAR
                                je              upmore
                jmp             enemy_move

        godownslide:
                mov             esi, DWORD[xpos]
                mov             edi, DWORD[ypos]
                downmore:
                        inc             DWORD[ypos]
                        mov             eax, WIDTH
                        mul             DWORD[ypos]
                        add             eax, [xpos]
                        lea             eax, [board + eax]
                        cmp             BYTE[eax], SLIDE_CHAR
                                je      downmore
                jmp             enemy_move

   enemy_move:
                        push    TICK
                        call    usleep
                        add             esp, 4

            mov         DWORD[upflag], 0
            mov     DWORD[downflag], 0      ;Set the flags to 0

                        call    rand                                    ;Get random number % d
                        cdq
                        mov             ebx, 6
                        idiv    ebx
                        inc             edx
                        mov             ecx, edx        ;Set the random value as the counter

                        mov             DWORD[enemyroll], ecx

                        push    DWORD[eypos]
                        call    getdirection            ;Get what ypos mod 2 it is so you can tell if you have to move left or right
                        cmp             edx, 0
                        je              emove_left
                        cmp             edx, 1
                        je              emove_right

                        emove_left:
                 mov     esi, DWORD[expos]
                 mov     edi, DWORD[eypos]

                 cmp     ecx, 0
                    je     einput_end
                 dec     DWORD[expos]
                 mov     eax, WIDTH
                 mul     DWORD [eypos]
                 add     eax, [expos]
                 lea     eax, [board + eax]

                                 cmp             BYTE[eax], FINISH_LINE
                                        je              enemy_wins
                 cmp             ecx, 1
                    jne     enextstepl
                                call    flagladder
                                call    flagslide
                                enextstepl:
                                 cmp     BYTE [eax], WALL_CHAR
                      jne     evalid_movel
                 mov     DWORD [expos], esi
                 mov     DWORD [eypos], edi
                 jmp     emove_down           ;If byte is wallchar go down

                                evalid_movel:
                                        dec             ecx
                                        jmp             emove_left


                                ;Add logic to test for wall, if wall then move down

                        emove_down:
                                mov             esi, DWORD[expos]
                                mov             edi, DWORD[eypos]

                                cmp             ecx, 0
                                je              einput_end

                                inc             DWORD [eypos]
                                mov     eax, WIDTH
                                        mul     DWORD [eypos]
                                        add     eax, [expos]
                                lea     eax, [board + eax]
                                cmp     BYTE [eax], WALL_CHAR
                                jne     evalid_moved

                                ;Implement code for winning move
                                jmp             game_loop_end           ;just for testing

                                evalid_moved:
                                        dec             ecx
                                        push    DWORD[eypos]
                                        call    getdirection

                                        cmp             edx, 1
                                        je              emove_right
                                        cmp             edx, 0
                                        je              emove_left

                                ;Add logic to test for wall, if wall then don't move down

                        emove_right:
                                mov             esi, DWORD[expos]
                                mov             edi, DWORD[eypos]

                                cmp             ecx, 0
                                je              einput_end

                                inc             DWORD[expos]

                        mov     eax, WIDTH
                mul     DWORD [eypos]
                        add     eax, [expos]
                        lea     eax, [board + eax]

                                cmp             ecx, 1
                                        jne     enextstepr
                                call    flagladder
                                call    flagslide
                                enextstepr:
                                cmp     BYTE [eax], WALL_CHAR
                                 jne     evalid_mover
                                mov     DWORD [expos], esi
                                mov     DWORD [eypos], edi
                                jmp             emove_down                       ;If byte is wallchar go down

                                evalid_mover:
                                dec             ecx                     ;inc ecx to mark that one spot out of random%6 has been moved
                                jmp             emove_right

                        einput_end:


                        ;check if the character is a slide or a ladder

                        cmp             DWORD[upflag], 1
                                je              egoupladder
                        cmp             DWORD[downflag], 1
                                je              egodownslide
                jmp             game_loop

        egoupladder:
                mov             esi, DWORD[expos]
                mov             edi, DWORD[eypos]
                eupmore:
                        dec             DWORD[eypos]
                        mov             eax, WIDTH
                        mul             DWORD[eypos]
                        add             eax, [expos]
                        lea             eax, [board + eax]
                        cmp             BYTE[eax], LADDER_CHAR
                                je              eupmore
                jmp             game_loop

        egodownslide:
                mov             esi, DWORD[expos]
                mov             edi, DWORD[eypos]
                edownmore:
                        inc             DWORD[eypos]
                        mov             eax, WIDTH
                        mul             DWORD[eypos]
                        add             eax, [expos]
                        lea             eax, [board + eax]
                        cmp             BYTE[eax], SLIDE_CHAR
                                je      edownmore
                jmp             game_loop


        player_wins:
                push    pwins_fmt
                call    printf
                jmp             game_loop_end

        enemy_wins:
                push    ewins_fmt
                call    printf

        game_loop_end:


        mov             edx, esi

        ; restore old terminal functionality
        call raw_mode_off


        ;***************CODE ENDS HERE*****************************
        popa
        mov             eax, 0
        leave
        ret

flagladder:                     ;Is the next character a slide or a ladder
        push    ebp
        mov             ebp, esp
                cmp             BYTE[eax], LADDER_START
                        je              yesladder
                mov             DWORD[upflag], 0
                jmp             noladder
                yesladder:
                mov             DWORD[upflag], 1
                noladder:
        mov             esp, ebp
        pop             ebp
        ret

flagslide:
        push    ebp
        mov             ebp, esp
                cmp             BYTE[eax], SLIDE_START
                        je      yesslide
                mov             DWORD[downflag], 0
                jmp             noslide
                yesslide:
                mov             DWORD[downflag], 1
                noslide:
        mov             esp, ebp
        pop             ebp
        ret

getdirection:
        push    ebp
        mov             ebp, esp
                cdq
                mov     eax, DWORD[ebp + 8]
                mov     ebx, 2
                idiv    ebx             ;Get what ypos mod 2 it is so you can tell if you have to move left or right
        mov             esp, ebp
        pop             ebp
        ret




; === FUNCTION ===
raw_mode_on:
        push    ebp
        mov             ebp, esp

        push    raw_mode_on_cmd
        call    system
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
raw_mode_off:

        push    ebp
        mov             ebp, esp

        push    raw_mode_off_cmd
        call    system
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
init_board:

        push    ebp
        mov             ebp, esp

        ; FILE* and loop counter
        ; ebp-4, ebp-8
        sub             esp, 8

        ; open the file
        push    mode_r
        push    board_file
        call    fopen
        add             esp, 8
        mov             DWORD [ebp-4], eax

        ; read the file data into the global buffer
        ; line-by-line so we can ignore the newline characters
        mov             DWORD [ebp-8], 0
        read_loop:
        cmp             DWORD [ebp-8], HEIGHT
        je              read_loop_end

                ; find the offset (WIDTH * counter)
                mov             eax, WIDTH
                mul             DWORD [ebp-8]
                lea             ebx, [board + eax]

                ; read the bytes into the buffer
                push    DWORD [ebp-4]
                push    WIDTH
                push    1
                push    ebx
                call    fread
                add             esp, 16

                ; slurp up the newline
                push    DWORD [ebp-4]
                call    fgetc
                add             esp, 4

        inc             DWORD [ebp-8]
        jmp             read_loop
        read_loop_end:

        ; close the open file handle
        push    DWORD [ebp-4]
        call    fclose
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
render:

        push    ebp
        mov             ebp, esp

        ; two ints, for two loop counters
        ; ebp-4, ebp-8
        sub             esp, 8

        ; clear the screen
        push    clear_screen_cmd
        call    system
        add             esp, 4

        ; print the help information
        push    help_str
        call    printf
        add             esp, 4


        ;Print the amount of gold

        ; outside loop by height
        ; i.e. for(c=0; c<height; c++)
        mov             DWORD [ebp-4], 0
        y_loop_start:
        cmp             DWORD [ebp-4], HEIGHT
        je              y_loop_end

                ; inside loop by width
                ; i.e. for(c=0; c<width; c++)
                mov             DWORD [ebp-8], 0
                x_loop_start:
                cmp             DWORD [ebp-8], WIDTH
                je              x_loop_end

                        ; check if (xpos,ypos)=(x,y)
;                       mov             eax, [xpos]
;                       cmp             eax, DWORD [ebp-8]
;                       jne             print_board
;                       mov             eax, [ypos]
;                       cmp             eax, DWORD [ebp-4]
;                       jne             print_board
                                ; if both were equal, print the player
;                               push    PLAYER_CHAR
;                               jmp             print_end

                        ; check if (xpos,ypos)=(x,y)
             mov             eax, [xpos]
             cmp             eax, DWORD [ebp-8]
                                jne             nextstepprint
             mov             eax, [ypos]
             cmp             eax, DWORD [ebp-4]
                                jne     nextstepprint
                                        push    PLAYER_CHAR
                                        jmp             print_end
                        nextstepprint:
                                                ;check if (expos, eypos)=(x,y)
                        mov             eax, [expos]
            cmp             eax, DWORD [ebp-8]
                                jne             print_board
            mov             eax, [eypos]
            cmp             eax, DWORD [ebp-4]
                                jne             print_board
                                ; if both were equal, print the player
                                        push    ENEMY_CHAR
                    jmp     print_end
                        print_board:
                                ; otherwise print whatever's in the buffer
                                mov             eax, [ebp-4]
                                mov             ebx, WIDTH
                                mul             ebx
                                add             eax, [ebp-8]
                                mov             ebx, 0
                                mov             bl, BYTE [board + eax]
                                push                    ebx
                        print_end:
                                                call    putchar
                                                add             esp, 4

                inc             DWORD [ebp-8]
                jmp             x_loop_start
                x_loop_end:

                ; write a carriage return (necessary when in raw mode)
                push    0x0d
                call    putchar
                add             esp, 4

                ; write a newline
                push    0x0a
                call    putchar
                add             esp, 4

        inc             DWORD [ebp-4]
        jmp             y_loop_start
        y_loop_end:

        ;Print out Turn #, Player Roll, and Enemy Roll
        push    DWORD[enemyroll]
        push    DWORD[playerroll]
        push    DWORD[turn]
        push    rollfmt
        call    printf
        add             esp, 12

        mov             esp, ebp
        pop             ebp
        ret




nonblocking_getchar:

; returns -1 on no-data
; returns char on succes

; magic values
%define F_GETFL 3
%define F_SETFL 4
%define O_NONBLOCK 2048
%define STDIN 0

        push    ebp
        mov             ebp, esp

        ; single int used to hold flags
        ; single character (aligned to 4 bytes) return
        sub             esp, 8

        ; get current stdin flags
        ; flags = fcntl(stdin, F_GETFL, 0)
        push    0
        push    F_GETFL
        push    STDIN
        call    fcntl
        add             esp, 12
        mov             DWORD [ebp-4], eax

        ; set non-blocking mode on stdin
        ; fcntl(stdin, F_SETFL, flags | O_NONBLOCK)
        or              DWORD [ebp-4], O_NONBLOCK
        push    DWORD [ebp-4]
        push    F_SETFL
        push    STDIN
        call    fcntl
        add             esp, 12

        call    getchar
        mov             DWORD [ebp-8], eax

        ; restore blocking mode
        ; fcntl(stdin, F_SETFL, flags ^ O_NONBLOCK
        xor             DWORD [ebp-4], O_NONBLOCK
        push    DWORD [ebp-4]
        push    F_SETFL
        push    STDIN
        call    fcntl
        add             esp, 12

        mov             eax, DWORD [ebp-8]

        mov             esp, ebp
        pop             ebp
        ret
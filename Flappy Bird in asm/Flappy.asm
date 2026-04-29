.model tiny
.code
org 100h
jmp start

; ======================================================
; CONSTANTS
; ======================================================

SKY_COLOR      equ 3
PIPE_COLOR     equ 2
BIRD_COLOR     equ 14
TEXT_COLOR     equ 15

SCREEN_W       equ 320
SCREEN_H       equ 200

BIRD_X         equ 80
BIRD_W         equ 14
BIRD_H         equ 14

GAP_H_MIN      equ 70
GAP_H_MAX      equ 100
PIPE_W         equ 40
PIPE_SPEED     equ 3
GRAVITY        equ 1
FLAP_VEL       equ -8
MAX_FALL       equ 10

; ======================================================
; VARIABLES
; ======================================================

pipe_speed     dw PIPE_SPEED
difficulty_mul dw 1
birdY          dw 100
oldBirdY       dw 100
velocity       dw 0
paused         db 0
current_speed  dw PIPE_SPEED
pipeX          dw 320
oldPipeX       dw 320
gapY           dw 70
gapDir         dw 2
gapH           dw 90

score          dw 0
high_score     dw 0
passed         db 0
rand_seed      dw 1234

; ======================================================
; Difficulty
; ======================================================

update_difficulty:

; difficulty =1+score/5

    mov ax, score
    mov bx,  5
    xor dx, dx
    div bx              ; AX=score/5
    inc ax              ; +1 so starts at 1
    cmp ax, 5
    jle no_cap
    mov ax, 5           ; Cap at 5?
no_cap:
    mov difficulty_mul, ax
    ; pipe_speed =PIPE_SPEED*difficulty_mul
    
    mov bx, PIPE_SPEED
    mul bx
    mov pipe_speed, ax

    ; shrink gap height
    mov ax, gapH
    sub ax, difficulty_mul
    cmp ax, 60
    jge ok_gap
    mov ax, 60
ok_gap:
    mov gapH, ax
    ret

; ======================================================
; START
; ======================================================
start:
    call init_gfx
    call draw_sky_once
main_loop:
    call frame_delay

; ==========================
; INPUT (SAFE  pause key)
; ==========================
mov ah, 01h
int 16h
jz noKey                    ;no key,continue

;Pek key withot removig it
mov ah, 01h
int 16h
jz noKey

; AL now contains key but is NOT consumed yet

cmp al, ' '
jne noKey_flap

; SPACE pressed ? now consume it
mov ah, 00h
int 16h
mov velocity, FLAP_VEL
call play_flap_sound
jmp noKey

noKey_flap:
; DO NOT CONSUME the key let pause block read it
noKey:
; =======================
;  CHECK FOR PAUSE KEY
; =======================
mov ah, 01h
int 16h
jz noPauseCheck

mov ah, 00h
int 16h

cmp al, 'p'
jne not_p1
jmp toggle_pause
not_p1:

cmp al, 'P'
jne not_p2
jmp toggle_pause
not_p2:

cmp al, 27         ; ESC
jne noPauseCheck
jmp toggle_pause

noPauseCheck:
    ; PHYSICS
    mov ax, velocity
    add ax, GRAVITY
    cmp ax, MAX_FALL
    jle velOK
    mov ax, MAX_FALL
velOK:
    mov velocity, ax

    mov ax, birdY
    add ax, velocity
    cmp ax, 0
    jge noCeil
    xor ax, ax
    mov velocity, 0
noCeil:
    cmp ax, 175
    jle noFloor
    mov ax, 175
noFloor:
    mov birdY, ax

    ; PIPE MOVEMENT
    mov ax, pipeX
    mov bx, pipe_speed
    sub ax, bx
    mov pipeX, ax
    
    cmp ax, -PIPE_W
    jg noReset

    mov pipeX, SCREEN_W
    mov passed, 0

    ; Random gap Y position (20-110)
    call get_random
    and ax, 127      ; AX = 0-127    comparing random number with 127 
    cmp ax, 90
    jle gap_y_ok
    sub ax, 90
gap_y_ok:
    add ax, 20       ; AX = 20-110
    mov gapY, ax

    ; Random gap height (70-100)
    call get_random
    and ax, 31       ; AX = 0-31
    add ax, GAP_H_MIN ; AX = 70-101
    cmp ax, GAP_H_MAX
    jle gap_h_ok
    mov ax, GAP_H_MAX
gap_h_ok:
    mov gapH, ax

noReset:

    ; SCORING
    mov ax, pipeX
    add ax, PIPE_W
    cmp ax, BIRD_X
jg noScore
cmp passed, 0
jne noScore
mov passed, 1
inc score
call play_score_sound

;call play_flap_sound

call update_difficulty
noScore:

    ; ERASE OLD POSITIONS
    mov bx, BIRD_X
    mov cx, oldBirdY
    mov si, BIRD_W
    mov di, BIRD_H
    mov al, SKY_COLOR
    call rect

    mov bx, oldPipeX
    mov cx, 0
    mov si, PIPE_W
    mov di, SCREEN_H
    mov al, SKY_COLOR
    call rect

    ; DRAW NEW POSITIONS
    mov bx, BIRD_X
    mov cx, birdY
    mov si, BIRD_W
    mov di, BIRD_H
    mov al, BIRD_COLOR
    call rect

    mov bx, pipeX
    mov cx, 0
    mov si, PIPE_W
    mov di, gapY
    cmp di, 1
    jl skip_top
    mov al, PIPE_COLOR
    call rect
skip_top:

    mov bx, pipeX
    mov cx, gapY
    add cx, gapH
    mov si, PIPE_W
    mov ax, SCREEN_H
    sub ax, cx
    cmp ax, 1
    jl skip_bottom
    mov di, ax
    mov al, PIPE_COLOR
    call rect
skip_bottom:

    ; DRAW SCORE HUD (top left)
    call draw_score_hud

    ; Save positions
    mov ax, birdY
    mov oldBirdY, ax
    mov ax, pipeX
    mov oldPipeX, ax

    ; COLLISION
    mov ax, BIRD_X
    add ax, BIRD_W
    cmp ax, pipeX
    jle safe

    mov ax, pipeX
    add ax, PIPE_W
    cmp ax, BIRD_X
    jle safe

    mov ax, birdY
    add ax, BIRD_H
    cmp ax, gapY
    jl crash

    mov ax, birdY
    mov bx, gapY
    add bx, gapH
    cmp ax, bx
    jg crash

    cmp birdY, 175
    jge crash

safe:
    jmp main_loop

crash:
   call play_crash_sound

call show_game_over
jmp main_loop
toggle_pause:
    cmp paused, 0
    je do_pause

; =============== RESUME ===============
resume_game:
    mov paused, 0
    call clear_pause_overlay
    jmp main_loop

; =============== PAUSE ===============
do_pause:
    mov paused, 1
    call draw_pause_overlay

pause_wait:
    mov ah, 00h
    int 16h
    cmp al, 'p'
    je resume_game
    cmp al, 'P'
    je resume_game
    cmp al, 27
    je resume_game
    jmp pause_wait
; ======================================================
; PLAY QUICK SOUND - AX = precomputed divisor
; ======================================================
; ======================================================
; PLAY FLAP SOUND (Mario-style plop)
; ======================================================
play_flap_sound:
    push ax
    push bx
    push cx
    push dx

    ; High starting tone
    mov bx, 800       ; lower divisor = higher pitch
    mov cx, 5         ; 5 steps of frequency sweep

flap_step:
    ; Set timer 2 (PC speaker)
    mov al, 0B6h
    out 43h, al
    mov al, bl
    out 42h, al
    mov al, bh
    out 42h, al
    
    ; Enable speaker
    in al, 61h
    or al, 3
    out 61h, al

    ; Small delay for audible tone
    mov dx, 200       ; slightly longer delay
delay_loop:
    dec dx
    jnz delay_loop

    ; Turn off speaker
    in al, 61h
    and al, 0FCh
    out 61h, al

    ; Next step: slightly lower pitch
    add bx, 60
    loop flap_step

    pop dx
    pop cx
    pop bx
    pop ax
    ret
   play_score_sound:
    push ax
    push bx
    push cx
    push dx

    mov bx, 1200      ; start frequency divisor (lower = higher pitch)
    mov cx, 4         ; 4 gentle notes

score_step:
    ; Set timer 2 for speaker
    mov al, 0B6h
    out 43h, al
    mov al, bl
    out 42h, al
    mov al, bh
    out 42h, al

    ; Turn on speaker
    in al, 61h
    or al, 3
    out 61h, al

    ; Short gentle delay
    mov dx, 250
score_delay:
    dec dx
    jnz score_delay

    ; Turn off speaker
    in al, 61h
    and al, 0FCh
    out 61h, al

    ; Step to next note (slightly higher)
    sub bx, 40        ; smaller pitch increment ? softer rise
    loop score_step

    pop dx
    pop cx
    pop bx
    pop ax
    ret
play_crash_sound:
    push ax
    push bx
    push cx
    push dx

    mov bx, 300       ; start low-pitch
    mov cx, 6         ; 6 steps

crash_step:
    mov al, 0B6h
    out 43h, al
    mov al, bl
    out 42h, al
    mov al, bh
    out 42h, al

    in al, 61h
    or al, 3
    out 61h, al

    mov dx, 200
crash_delay:
    dec dx
    jnz crash_delay

    in al, 61h
    and al, 0FCh
    out 61h, al

    add bx, 50        ; lower pitch gradually
    loop crash_step

    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ======================================================
; DRAW SCORE HUD (FIXED)
; ======================================================
draw_score_hud:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Erase old score area with larger rectangle
    mov bx, 5
    mov cx, 5
    mov si, 70
    mov di, 12
    mov al, SKY_COLOR
    call rect
    
    ; Draw score digits
    mov bx, 8
    mov cx, 6
    mov ax, score
    call draw_number_simple
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    draw_pause_overlay:
    ; Dark transparent rectangle
    mov bx, 60
    mov cx, 70
    mov si, 200
    mov di, 60
    mov al, 0
    call rect

    ; Border
    mov bx, 60
    mov cx, 70
    mov si, 200
    mov di, 2
    mov al, TEXT_COLOR
    call rect

    mov bx, 60
    mov cx, 130
    mov si, 200
    mov di, 2
    mov al, TEXT_COLOR
    call rect

    mov bx, 60
    mov cx, 70
    mov si, 2
    mov di, 60
    mov al, TEXT_COLOR
    call rect

    mov bx, 258
    mov cx, 70
    mov si, 2
    mov di, 60
    mov al, TEXT_COLOR
    call rect

    ; Draw text "PAUSED"
    mov bx, 110
    mov cx, 95
    call draw_text_paused
    ret
; ======================================================
; SHOW GAME OVER SCREEN
; ======================================================
show_game_over:
    ; Update high score
    mov ax, score
    cmp ax, high_score
    jle skip_hs
    mov high_score, ax
skip_hs:

    ; Draw black rectangle
    mov bx, 40
    mov cx, 60
    mov si, 240
    mov di, 80
    mov al, 0
    call rect

    ; Border
    mov bx, 42
    mov cx, 62
    mov si, 236
    mov di, 2
    mov al, TEXT_COLOR
    call rect
    
    mov bx, 42
    mov cx, 136
    mov si, 236
    mov di, 2
    mov al, TEXT_COLOR
    call rect
    
    mov bx, 42
    mov cx, 62
    mov si, 2
    mov di, 76
    mov al, TEXT_COLOR
    call rect
    
    mov bx, 276
    mov cx, 62
    mov si, 2
    mov di, 76
    mov al, TEXT_COLOR
    call rect

    ; Draw "GAME OVER"
    mov bx, 90
    mov cx, 75
    call draw_text_gameover

    ; Draw "SCORE: XX"
    mov bx, 100
    mov cx, 95
    call draw_text_score
    
    mov bx, 180
    mov cx, 95
    mov ax, score
    call draw_number_simple

    ; Draw "BEST: XX"
    mov bx, 105
    mov cx, 110
    call draw_text_best
    
    mov bx, 180
    mov cx, 110
    mov ax, high_score
    call draw_number_simple

    ; Draw "PRESS ENTER "
    mov bx, 80
    mov cx, 125
    call  draw_text_enter

; Wait for Enter
wait_enter:
    mov ah, 00h
    int 16h        ; get key
    cmp al, 27     ; ESC = exit
    je exit_game
    cmp al, 0Dh    ; Enter = retry
    jne wait_enter ; loop until Enter
    
    ; Reset
    mov birdY, 100
    mov oldBirdY, 100
    mov velocity, 0
    mov pipeX, 320
    mov oldPipeX, 320
    mov gapY, 70
    mov gapDir, 2
    mov gapH, 90
    mov score, 0
    mov passed, 0
    mov difficulty_mul, 1   
mov pipe_speed, 3 
    call draw_sky_once
    ret

exit_game:
    mov ax, 3
    int 10h
    mov ah, 4Ch
    int 21h

; ======================================================
; DRAW NUMBER (FIXED)
; BX=x, CX=y, AX=number (0-999)
; ======================================================
draw_number_simple:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    mov si, bx  ; SI = X position
    mov di, cx  ; DI = Y position
    
    ; Convert to digits
    xor dx, dx
    mov bx, 100
    div bx
    mov bx, dx  ; BX = remainder (tens + ones)
    
    ; Draw hundreds (skip if 0)
    push ax
    push bx
    cmp al, 0
    je skip_hundreds
    add al, '0'  
    mov bx, si
    mov cx, di
    call draw_digit_3x5
skip_hundreds:
    pop bx
    pop ax
    add si, 4
    
    ; Draw tens
    mov ax, bx
    xor dx, dx
    mov bx, 10
    div bx
    push dx     ; Save ones
    add al, '0'
    mov bx, si
    mov cx, di
    call draw_digit_3x5
    add si, 4
    
    ; Draw ones
    pop ax
    add al, '0'
    mov bx, si
    mov cx, di
    call draw_digit_3x5
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ======================================================
; DRAW SINGLE DIGIT (FIXED)
; ======================================================
draw_digit_3x5:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    
    ; Set up video segment
    push ax
    mov ax, 0A000h
    mov es, ax
    pop ax
    
    mov bp, bx  ; BP = X position
    push cx     ; Save Y position on stack
    
    sub al, '0'
    cmp al, 9
    ja skip_digit
    
    ; Calculate font offset
    mov ah, 0
    mov si, 15
    mul si
    mov si, ax
    add si, offset digit_font  ;stride
    
    ; Draw 5 rows
    pop dx      ; DX = Y position
    push dx
    mov bx, 5   ; BX = row counter
    
draw_d_row:
    push bp     ; Save X position
    push bx     ; Save row counter
    mov cx, 3   ; CX = column counter
    
draw_d_col:
    push cx
    mov al, byte ptr cs:[si]  ; pointing the first pixel of the digit to be load or single pixel
    inc si
    cmp al, 1
    jne skip_pix
    
    ; Calculate and draw pixel
    push si
    mov ax, dx
    push dx
    mov si, 320
    mul si   ;pixel offset/stride in memory
    pop dx
    add ax, bp ;bp=x
    mov di, ax                                         ;A000:0000 ? (0,0)
                                                       ;A000:0001 ? (1,0)
                                                       ;...
                                                       ;A000:013F ? (319,0)
                                                       ;A000:0140 ? (0,1)
    mov al, TEXT_COLOR
    stosb
    pop si
    
skip_pix:
    inc bp         ;bp=x
    pop cx
    loop draw_d_col
    
    pop bx      ; Restore row counter
    pop bp      ; Restore X position
    inc dx      ; Next row dx=y
    dec bx
    jnz draw_d_row
    
    pop dx      ; Clean up Y from stack
    
skip_digit:
    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret


    draw_text_paused:
    push bx
    push cx

    call draw_letter_p
    add bx, 14
    call draw_letter_a
    add bx, 14
    call draw_letter_u
    add bx, 14
    call draw_letter_s
    add bx, 14
    call draw_letter_e
    add bx, 14
    call draw_letter_d

    pop cx
    pop bx
    ret
draw_letter_u:
    push bx    ;X
    push cx    ;Y
    push si    ;WID
    push di    ;HIE

    mov si, 2
    mov di, 10
    mov al, TEXT_COLOR
    call rect          ; Left vertical

    add bx, 10
    call rect          ; Right vertical

    sub bx, 10
    add cx, 10
    mov si, 12
    mov di, 2
    call rect          ; Bottom bar

    pop di
    pop si
    pop cx
    pop bx
    ret
    draw_letter_d:
    push bx
    push cx
    push si
    push di

    mov si, 2
    mov di, 12
    mov al, TEXT_COLOR
    call rect          ; Left vertical

    mov si, 8
    mov di, 2
    call rect          ; Top bar

    add cx, 10
    mov si, 8
    mov di, 2
    call rect          ; Bottom bar

    add bx, 8
    sub cx, 8
    mov si, 2
    mov di, 8
    call rect          ; Right vertical curve

    pop di
    pop si
    pop cx
    pop bx
    ret
; ======================================================
; 3x5 DIGIT FONT DATA
; ======================================================
digit_font:
db 1,1,1, 1,0,1, 1,0,1, 1,0,1, 1,1,1  ; 0
db 0,1,0, 1,1,0, 0,1,0, 0,1,0, 1,1,1  ; 1
db 1,1,1, 0,0,1, 1,1,1, 1,0,0, 1,1,1  ; 2
db 1,1,1, 0,0,1, 1,1,1, 0,0,1, 1,1,1  ; 3
db 1,0,1, 1,0,1, 1,1,1, 0,0,1, 0,0,1  ; 4
db 1,1,1, 1,0,0, 1,1,1, 0,0,1, 1,1,1  ; 5
db 1,1,1, 1,0,0, 1,1,1, 1,0,1, 1,1,1  ; 6
db 1,1,1, 0,0,1, 0,0,1, 0,1,0, 0,1,0  ; 7
db 1,1,1, 1,0,1, 1,1,1, 1,0,1, 1,1,1  ; 8
db 1,1,1, 1,0,1, 1,1,1, 0,0,1, 1,1,1  ; 9

; ======================================================
; TEXT DRAWING - IMPROVED LETTER SHAPES
; ======================================================
draw_text_gameover:
    push bx
    push cx
    call draw_letter_g
    add bx, 16
    call draw_letter_a
    add bx, 16
    call draw_letter_m
    add bx, 16
    call draw_letter_e
    add bx, 20
    call draw_letter_o
    add bx, 16
    call draw_letter_v
    add bx, 16
    call draw_letter_e
    add bx, 16
    call draw_letter_r
    pop cx
    pop bx
    ret
clear_pause_overlay:
    ; Clear the pause box (draw sky background)
    mov bx, 60
    mov cx, 70
    mov si, 200
    mov di, 60
    mov al, SKY_COLOR     ; same color used in draw_sky_once
    call rect
    ret
draw_text_score:
    push bx
    call draw_letter_s
    add bx, 13
    call draw_letter_c
    add bx, 13
    call draw_letter_o
    add bx, 13
    call draw_letter_r
    add bx, 13
    call draw_letter_e
    pop bx
    ret

draw_text_best:
    push bx
    call draw_letter_b
    add bx, 13
    call draw_letter_e
    add bx, 13
    call draw_letter_s
    add bx, 13
    call draw_letter_t
    pop bx
    ret

draw_text_enter:
    push bx
    call draw_letter_p
    add bx, 11
    call draw_letter_r
    add bx, 11
    call draw_letter_e
    add bx, 11
    call draw_letter_s
    add bx, 11
    call draw_letter_s
    add bx, 16
    call draw_letter_e
    add bx, 11
    call draw_letter_n
    add bx, 11
    call draw_letter_t
    pop bx
    ret
    ; Letter drawing with better shapes (12x12 pixels)
draw_letter_a:
    push bx
    push cx
    push si
    push di
    ; Top horizontal
    mov si, 10
    mov di, 2
    mov al, TEXT_COLOR
    call rect
    add cx, 2
    ; Left vertical
    mov si, 2
    mov di, 8
    call rect
    ; Right vertical
    add bx, 8
    call rect
    sub bx, 8
    ; Middle horizontal
    add cx, 3
    mov si, 10
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_b:
    push bx
    push cx
    push si
    push di
    ; Left vertical
    mov si, 2
    mov di, 12
    mov al, TEXT_COLOR
    call rect
    ; Top horizontal
    mov si, 8
    mov di, 2
    call rect
    ; Middle horizontal
    add cx, 5
    call rect
    ; Bottom horizontal
    add cx, 5
    call rect
    sub cx, 10
    ; Right curves
    add bx, 8
    mov si, 2
    mov di, 2
    call rect
    add cx, 3
    call rect
    add cx, 3
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_c:
    push bx
    push cx
    push si
    push di
    ; Top horizontal
    mov si, 10
    mov di, 2
    mov al, TEXT_COLOR
    call rect
    ; Left vertical
    add cx, 2
    mov si, 2
    mov di, 8
    call rect
    ; Bottom horizontal
    add cx, 8
    mov si, 10
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_e:
    push bx
    push cx
    push si
    push di
    ; Left vertical
    mov si, 2
    mov di, 12
    mov al, TEXT_COLOR
    call rect
    ; Top horizontal
    mov si, 10
    mov di, 2
    call rect
    ; Middle horizontal
    add cx, 5
    mov si, 8
    call rect
    ; Bottom horizontal
    add cx, 5
    mov si, 10
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_g:
    push bx
    push cx
    push si
    push di
    ; Top horizontal
    mov si, 12
    mov di, 2
    mov al, TEXT_COLOR
    call rect
    ; Left vertical
    add cx, 2
    mov si, 2
    mov di, 8
    call rect
    ; Bottom horizontal
    add cx, 8
    mov si, 12
    mov di, 2
    call rect
    sub cx, 8
    ; Right vertical (short)
    add bx, 10
    mov si, 2
    mov di, 5
    call rect
    ; Middle bar
    add cx, 3
    sub bx, 4
    mov si, 6
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_m:
    push bx
    push cx
    push si
    push di
    ; Left vertical
    mov si, 2
    mov di, 12
    mov al, TEXT_COLOR
    call rect
    ; Right vertical
    add bx, 10
    call rect
    sub bx, 10
    ; Left diagonal peak
    add bx, 2
    MOV CX,CX
    mov si, 2
    mov di, 4
    call rect
    
    ADD BX,2
    ADD CX,4
    MOV DI,4
    CALL rect
    ; Right diagonal peak
    SUB bx, 2
    SUB CX,4
    ADD BX,4
    MOV DI,4
    call rect
    ADD BX,2
    ADD CX,4
    MOV DI,4
    CALL rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_o:
    push bx
    push cx
    push si
    push di
    ; Top horizontal
    mov si, 12
    mov di, 2
    mov al, TEXT_COLOR
    call rect
    ; Left vertical
    add cx, 2
    mov si, 2
    mov di, 8
    call rect
    ; Right vertical
    add bx, 10
    call rect
    sub bx, 10
    ; Bottom horizontal
    add cx, 8
    mov si, 12
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_p:
    push bx
    push cx
    push si
    push di
    ; Left vertical
    mov si, 2
    mov di, 12
    mov al, TEXT_COLOR
    call rect
    ; Top horizontal
    mov si, 8
    mov di, 2
    call rect
    ; Right vertical (top half)
    add bx, 8
    add cx, 2
    mov si, 2
    mov di, 3
    call rect
    sub bx, 8
    ; Middle horizontal
    add cx, 3
    mov si, 8
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_r:
    push bx
    push cx
    push si
    push di
    ; Left vertical
    mov si, 2
    mov di, 12
    mov al, TEXT_COLOR
    call rect
    ; Top horizontal
    mov si, 8
    mov di, 2
    call rect
    ; Right vertical (top)
    add bx, 8
    add cx, 2
    mov si, 2
    mov di, 3
    call rect
    sub bx, 8
    ; Middle horizontal
    add cx, 3
    mov si, 8
    mov di, 2
    call rect
    ; Diagonal leg
    add bx, 5
    add cx, 2
    mov si, 2
    mov di, 5
    call rect
    add bx, 2
    add cx, 2
    mov di, 3
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret
draw_letter_n:
    push bx
    push cx
    push si
    push di
    ; Left vertical
    mov si, 2
    mov di, 12
    mov al, TEXT_COLOR
    call rect
    ; Right vertical
    add bx, 10
    call rect
    sub bx, 10
    ; Diagonal
    add bx, 2
    mov si, 2
    mov di, 10
    call rect
    add bx, 2
    mov di, 8
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret
draw_letter_s:
    push bx
    push cx
    push si
    push di
    ; Top horizontal
    mov si, 10
    mov di, 2
    mov al, TEXT_COLOR
    call rect
    ; Left vertical (top)
    add cx, 2
    mov si, 2
    mov di, 3
    call rect
    ; Middle horizontal
    add cx, 3
    mov si, 10
    mov di, 2
    call rect
    ; Right vertical (bottom)
    add bx, 8
    add cx, 2
    mov si, 2
    mov di, 3
    call rect
    sub bx, 8
    ; Bottom horizontal
    add cx, 3
    mov si, 10
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_t:
    push bx
    push cx
    push si
    push di
    ; Top horizontal
    mov si, 10
    mov di, 2
    mov al, TEXT_COLOR
    call rect
    ; Middle vertical
    add bx, 4
    add cx, 2
    mov si, 2
    mov di, 10
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_v:
    push bx
    push cx
    push si ;widht
    push di ;hiehgt
    ; Left diagonal
    mov si, 2
    mov di, 6
    mov al, TEXT_COLOR
    call rect
    add bx, 1
    add cx, 6
    mov di, 4
    call rect
    sub bx, 1
    sub cx, 6
    ; Right diagonal
    add bx, 10
    mov si,2
    mov di,6
    call rect
    sub bx, 1
    add cx, 6
    mov di, 4
    call rect
    sub bx,6
    add cx,1
    mov si,2
    call rect
   ;bottom bar
 


   pop di
    pop si
    pop cx
    pop bx
    ret

; ======================================================
; CORE ROUTINES
; ======================================================
draw_sky_once:
    push ax
    push cx
    push di
    push es
    
    mov ax, 0A000h
    mov es, ax
    xor di, di
    mov al, SKY_COLOR
    mov ah, al
    mov cx, 32000
    rep stosw   ;two pixel at a time by al and ah
    
    pop es
    pop di
    pop cx
    pop ax
    ret

frame_delay:
    mov dx, 3DAh
fd1: 
    in al, dx
    test al,8
    jnz fd1
fd2: 
    in al, dx
    test al,8
    jz fd2
    mov cx, 1500
fd3:
    loop fd3
    ret
    ;Look at a straight wall

    ;Spin camera quickly

    ;Turn VSync OFF

    ;You?ll see horizontal breaks
rect:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp
    
    cmp bx, SCREEN_W
    jge rect_exit
    cmp cx, SCREEN_H
    jge rect_exit
    cmp di, 0
    jle rect_exit
    
    ; Save color
    push ax     ; Save color on stack
    
    mov ax, 0A000h
    mov es, ax
    
    ; Calculate starting position
    mov ax, cx ;ax=x
    mov dx, 320
    mul dx    ;ax=320*x
    add ax, bx  ;ax=(x*320)+Y offset
    mov bp, ax  ; BP = starting offset
    
    pop ax      ; Restore color
    push ax     ; Keep color on stack
    
    mov dx, di  ; DX = height counter
    
rect_row_loop:
    push dx
    mov di, bp
    mov cx, si  ; CX = width
    rep stosb
    add bp, 320  ; Next row
    pop dx
    dec dx
    jnz rect_row_loop
    
    pop ax      ; Clean up color from stack
    
rect_exit:
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

init_gfx:
    mov ax, 13h
    int 10h
    mov ax, 0A000h
    mov es, ax
    
   
    ret

; ======================================================
; RANDOM NUMBER GENERATOR 
; Returns random number in AX
; ======================================================
get_random:
    push bx
    push cx
    push dx
    
    ; Update seed using timer
    mov ah, 00h
    int 1Ah        ;bios time service
    xor rand_seed, dx
    
    ; LCG: seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    ;seed = seed * A + B
    mov ax, rand_seed
    mov bx, 25173
    mul bx
    add ax, 13849
    mov rand_seed, ax
    
    pop dx
    pop cx
    pop bx
    ret

end start

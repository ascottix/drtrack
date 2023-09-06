COMMENT *
  Low level interface to SoundBlaster card
  Copyright (c) 1991 Alessandro Scotti
*

.MODEL TPASCAL
LOCALS

.DATA

EXTRN   SBC_Port        :WORD
EXTRN   SBC_IRQ         :WORD

.CODE

Chk     MACRO   Num
        mov     ax, Num
        call    Check_1
ENDM

DataC   DW      ?
DataE   DW      ?
DataO   DW      ?
DataS   DW      ?
DataX   DW      4*4  DUP( ? )

SwapInt MACRO   IntrNo, Where, NewIntOfs
        mov     bx, IntrNo
        call    Get_Int_Vector
        mov     cs:DataX[Where], ax
        mov     cs:DataX[Where+2], dx
        mov     bx, IntrNo
        mov     ax, OFFSET NewIntOfs
        mov     dx, cs
        call    Set_Int_Vector
ENDM

FreeInt MACRO   IntrNo, Where
        mov     bx, IntrNo
        mov     ax, cs:DataX[Where]
        mov     dx, cs:DataX[Where+2]
        call    Set_Int_Vector
ENDM

.wait   MACRO
        jmp     $+2
        jmp     $+2
        jmp     $+2
        jmp     $+2
        jmp     $+2
ENDM

;  SubRoutine
Set_Int_Vector:
        pushf
        push    ds
        shl     bx, 1
        shl     bx, 1
        cli
        push    ax
        xor     ax, ax
        mov     ds, ax
        pop     ax
        mov     ds:[bx], ax
        mov     ds:[bx+2], dx
        pop     ds
        popf
        ret

;  SubRoutine
Get_Int_Vector:
        pushf
        push    ds
        shl     bx, 1
        shl     bx, 1
        cli
        xor     ax, ax
        mov     ds, ax
        mov     ax, ds:[bx]
        mov     dx, ds:[bx+2]
        pop     ds
        popf
        ret

;  SubRoutine
Set_Timer:
        push    ax
        mov     al, 36h
        out     43h, al
        pop     ax
        out     40h, al
        mov     al, ah
        out     40h, al
        ret

;  Interrupt per test sulla temporizzazione
New_Int_08h:
        not     ax
        push    ax
        mov     al, 20h
        out     20h, al
        pop     ax
        iret

;  SubRoutine
Timer_Test:
        mov     bx, 8
        call    Get_Int_Vector
        mov     cs:[DataO], ax
        mov     cs:[DataS], dx
        cli
        in      al, 21h
        mov     cs:[DataC], ax
        mov     al, 0FEh
        out     21h, al
        mov     ax, 1B58h
        call    Set_Timer
        mov     bx, 8
        mov     dx, cs
        mov     ax, OFFSET New_Int_08h
        call    Set_Int_Vector
        xor     ax, ax
        xor     cx, ax
        sti
Timer_Test_1:
        or      ax, ax
        je      Timer_Test_1
Timer_Test_2:
        or      ax, ax
        jne     Timer_Test_2
Timer_Test_3:
        nop
        inc     cx
        or      ax, ax
        je      Timer_Test_3
        cli
        mov     ax, cs:[DataC]
        out     21h, al
        mov     ax, 0FFFFh
        call    Set_Timer
        sti
        mov     bx, 8
        mov     dx, cs:[DataS]
        mov     ax, cs:[DataO]
        call    Set_Int_Vector
        mov     ax, cx
        shl     cx, 1
        shl     cx, 1
        shl     cx, 1
        add     ax, cx
        mov     cl, 0Ah
        shr     ax, cl
        mov     cs:[DataC], ax
        mov     cx, ax
        shl     ax, 1
        add     cx, ax
        shl     ax, 1
        add     cx, ax
        mov     cs:[DataE], cx
        ret

;  SubRoutine
Check_1:
        push    ax
        push    cx
        push    dx
        mov     dx, [SBC_Port]
        add     dx, 8
        xchg    al, ah
        out     dx, al
        mov     cx, cs:[DataC]
Check_1_Loop1:
        nop
        dec     cx
        or      cx, cx
        jne     Check_1_Loop1
        inc     dx
        mov     al, ah
        out     dx, al
        mov     cx, cs:[DataE]
Check_1_Loop2:
        nop
        dec     cx
        or      cx, cx
        jne     Check_1_Loop2
        pop     dx
        pop     cx
        pop     ax
        ret

;  SubRoutine
Check_2:
        push    cx
        push    dx
        mov     cx, 40h
        mov     ah, al
        and     ah, 0E0h
        mov     dx, [SBC_Port]
        add     dx, 8
Check_2_Loop:
        in      al, dx
        and     al, 0E0h
        cmp     ah, al
        je      Check_2_Exit_NC
        loop    Check_2_Loop
        stc
        jmp     SHORT Check_2_Exit
Check_2_Exit_NC:
        clc
Check_2_Exit:
        pop     dx
        pop     cx
        ret

;  SubRoutine
Read_DSP_Time:
        push    cx
        push    dx
        mov     dx, [SBC_Port]
        add     dx, 0Eh
        mov     cx, 200h
Read_DSP_Time_Loop:
        in      al, dx
        or      al, al
        js      Read_DSP_Time_EndLoop
        loop    Read_DSP_Time_Loop
        stc
        jmp     SHORT Read_DSP_Time_Exit
Read_DSP_Time_EndLoop:
        sub     dx, 4
        in      al, dx
        clc
Read_DSP_Time_Exit:
        pop     dx
        pop     cx
        ret

;  SubRoutine
Write_DSP_Time:
        push    cx
        push    dx
        mov     dx, [SBC_Port]
        add     dx, 0Ch
        mov     cx, 200h
        mov     ah, al
Write_DSP_Time_Loop:
        in      al, dx
        or      al, al
        jns     Write_DSP_Time_EndLoop
        loop    Write_DSP_Time_Loop
        stc
        jmp     Write_DSP_Time_Exit
Write_DSP_Time_EndLoop:
        mov     al, ah
        out     dx, al
        clc
Write_DSP_Time_Exit:
        pop     dx
        pop     cx
        ret

;  SubRoutine
Read_DSP:
        push    dx
        mov     dx, [SBC_Port]
        add     dx, 0Eh
Read_DSP_Loop:
        in      al, dx
        or      al, al
        js      Read_DSP_Exit
        jmp     Read_DSP_Loop
Read_DSP_Exit:
        sub     dx, 4
        in      al, dx
        pop     dx
        ret

;  SubRoutine
Write_DSP:
        push    dx
        mov     dx, [SBC_Port]
        add     dx, 0Ch
        mov     ah, al
Write_DSP_Loop:
        in      al, dx
        or      al, al
        jns     Write_DSP_Exit
        jmp     Write_DSP_Loop
Write_DSP_Exit:
        mov     al, ah
        out     dx, al
        pop     dx
        ret

PUBLIC SBC_IsPro
SBC_IsPro       PROC    FAR
        xor     bx, bx
        mov     dx, [SBC_Port]
        add     dx, 4                           ; Mixer index register
        mov     al, 4
        out     dx, al                          ; Select DAC volume
        .wait
        inc     dx                              ; Mixer data register
        in      al, dx                          ; Read DAC volume
        mov     ah, al                          ; Save old pattern
; CH = pattern to be read, CL = test pattern
        mov     cx, 1111h
        cmp     al, 11h                         ; Same as test pattern?
        jne     @@Ok                            ; No, continue
        mov     cx, 2222h                       ; Change test pattern
@@Ok:
        dec     dx
        mov     al, 4
        out     dx, al
        .wait
        inc     dx
        mov     al, cl
        out     dx, al                          ; Write test pattern
        .wait
        dec     dx
        mov     al, 4
        out     dx, al
        .wait
        inc     dx
        in      al, dx                          ; Read test pattern back
        cmp     al, ch                          ; Is it a valid port?
        jne     @@Exit                          ; No, exit now
        dec     dx
        mov     al, 4
        out     dx, al
        .wait
        inc     dx
        mov     al, ah
        out     dx, al                          ; Restore old pattern
        inc     bx                              ; Return TRUE
@@Exit:
        mov     ax, bx
        ret
SBC_IsPro       ENDP

;  function SBC_ResetDSP: boolean;
PUBLIC SBC_ResetDSP
SBC_ResetDSP PROC FAR
        mov     dx, [SBC_Port]
        add     dx, 6
        mov     al, 1
        out     dx, al
        dec     al
@@Loop1:
        dec     al
        jnz     @@Loop1
        out     dx, al
        mov     cx, 20h
@@Loop2:
        call    Read_DSP_Time
        jc      @@Repeat_Loop2
        cmp     al, 0AAh
        jne     @@Repeat_Loop2
        mov     ax, 1
        clc
        jmp     @@Exit
@@Repeat_Loop2:
        loop    @@Loop2
        xor     ax, ax
        stc
@@Exit:
        ret
SBC_ResetDSP ENDP

;  function SBC_CheckCard: word;
PUBLIC SBC_CheckCard
SBC_CheckCard PROC FAR
        xor     bx, bx
        mov     dx, [SBC_Port]
        add     dx, 6
        mov     al, 0C6h
        out     dx, al
        xor     al, al
        add     dx, 4
        out     dx, al
        in      al, dx
        cmp     al, 0C6h
        jne     @@Part2
        sub     dx, 4
        mov     al, 39h
        out     dx, al
        xor     al, al
        add     dx, 4
        out     dx, al
        in      al, dx
        cmp     al, 39h
        jne     @@Part2
        inc     bx
        jmp     @@Part3
@@Part2:
        call    SBC_ResetDSP
        jc      @@Part3
        mov     al, 0E0h
        call    Write_DSP_Time
        jc      @@Part3
        mov     al, 0C6h
        call    Write_DSP_Time
        jc      @@Part3
        call    Read_DSP_Time
        jc      @@Part3
        cmp     al, 39h
        jne     @@Part3
        call    Timer_Test
        mov     bx, 4
@@Part3:
        Chk     100h
        Chk     460h
        Chk     480h
        mov     al, 0
        call    Check_2
        jc      @@Exit
        Chk     2FFh
        Chk     421h
        mov     al, 0C0h
        call    Check_2
        jc      @@Exit
        Chk     460h
        Chk     480h
        add     bx, 2
@@Exit: mov     ax, bx
        ret
SBC_CheckCard ENDP

;  function SBC_DetectCard: word;
PUBLIC SBC_DetectCard
SBC_DetectCard PROC FAR
        mov     si, 220h
@@Loop:
        mov     [SBC_Port], si
        call    SBC_CheckCard
        or      ax, ax
        jnz     @@Exit
        add     si, 10h
        cmp     si, 260h
        jbe     @@Loop
        mov     si, 210h
        mov     [SBC_Port], si
        call    SBC_CheckCard
@@Exit:
        ret
SBC_DetectCard ENDP

New_0Bh:
        push    ds
        push    ax
        push    dx
        mov     ax, DATA
        mov     ds, ax
        mov     ax, 3
Detect_Ok:
        mov     [SBC_IRQ], ax
        mov     dx, [SBC_Port]
        add     dx, 0Eh
        in      al, dx
        mov     al, 20h
        out     20h, al
        pop     dx
        pop     ax
        pop     ds
        iret

New_0Ah:
        push    ds
        push    ax
        push    dx
        mov     ax, DATA
        mov     ds, ax
        mov     ax, 2
        jmp     Detect_Ok

New_0Dh:
        push    ds
        push    ax
        push    dx
        mov     ax, DATA
        mov     ds, ax
        mov     ax, 5
        jmp     Detect_Ok

New_0Fh:
        push    ds
        push    ax
        push    dx
        mov     ax, DATA
        mov     ds, ax
        mov     ax, 7
        jmp     Detect_Ok


;  function SBC_DetectInt: word;
PUBLIC SBC_DetectInt
SBC_DetectInt PROC FAR
        SwapInt 0Ah, 00, New_0Ah
        SwapInt 0Bh, 04, New_0Bh
        SwapInt 0Dh, 08, New_0Dh
        SwapInt 0Fh, 12, New_0Fh
        in      al, 21h
        mov     cs:[DataE], ax
        and     al, 53h
        out     21h, al
        xor     ax, ax
        mov     [SBC_IRQ], ax
        mov     al, 0F2h
        call    Write_DSP
        xor     ax, ax
        xor     cx, cx
@@Loop:
        cmp     [SBC_IRQ], ax
        jne     @@EndLoop
        loop    @@Loop
@@EndLoop:
        mov     ax, cs:[DataE]
        out     21h, al
        FreeInt 0Fh, 12
        FreeInt 0Dh, 08
        FreeInt 0Bh, 04
        FreeInt 0Ah, 00
        mov     ax, [SBC_IRQ]
        ret
SBC_DetectInt ENDP

END

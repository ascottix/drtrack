;
; Dr. Track
; Video functions and peak meters
; CopyRight (c) 1991-1992,1993 Alessandro Scotti
;
.MODEL TPASCAL
.CODE

LOCALS

DRT_VERSION     EQU     01*256+40
DRT_IDCODE      EQU     1

TRACK_1         EQU     0
TRACK_2         EQU     256
TRACK_3         EQU     512
TRACK_4         EQU     768
PEAKCHAR        EQU     205
SHADOWATTR      EQU     08h

MAGICCX         EQU     'dr'
MAGICDX         EQU     't?'
MAGICSI         EQU     '##'
MAGICDI         EQU     '##'

OUTSI           EQU     'ye'
OUTDI           EQU     's!'

OldInt10h       LABEL   DWORD
Old10hOfs       DW      0
Old10hSeg       DW      0

PF_Attr          DB      ?
PF_HiAttr        DB      ?
PF_FrameAttr     DB      ?
PF_HiFrameAttr   DB      ?
PF_PlayFrameAttr DB      ?
PF_VideoSeg      DW      ?
FirstFrameRow    DW      ?
LastVideoOfs     DW      ?

PN_Names        DB      '..C-C#D-D#E-F-F#G-G#A-A#B-'
PN_Digits       DB      '0123456789ABCDEF'
PN_Colors       DB      10, 10, 10, 10, 10, 10, 10, 10
                DB      10, 10, 14, 14, 14, 14, 12, 12
PN_VideoOfs     LABEL   WORD

; Costruisce la tavola degli offset delle righe video
MyTempY = 0
REPT 60
  DW  MyTempY+14
  MyTempY = MyTempY + 160
ENDM

PrintNote:
        ASSUME  ds:NOTHING
        xchg    cl, ch
        mov     bl, ch
        and     bl, 0Fh
        shl     bl, 1
        xor     bh, bh
        mov     al, PN_Names[bx]
        stosw
        mov     al, PN_Names[bx+1]
        stosw
        mov     al, '.'
        shr     ch, 1
        shr     ch, 1
        shr     ch, 1
        shr     ch, 1
        or      ch, ch
        jz      @@1
        mov     al, ch
        add     al, '0'
@@1:
        stosw
        mov     al, ' '
        stosw
        mov     al, '.'
        mov     ch, '.'
        or      cl, cl
        jz      @@2
        mov     al, cl
        mov     ch, ah
        xor     ah, ah
        mov     cl, 10
        div     cl
        add     ax, '00'
        xchg    ah, ch
@@2:
        stosw
        mov     al, ch
        stosw
        mov     al, ' '
        stosw
        mov     bx, OFFSET PN_Digits
        or      dh, dh
        jnz     @@3
        mov     al, '.'
        or      dl, dl
        jz      @@4
@@3:
        mov     al, dl
        xlat    PN_Digits
@@4:
        stosw
        mov     al, dh
        mov     cl, 4
        shr     al, cl
        xlat    PN_Digits
        stosw
        mov     al, dh
        and     al, 0Fh
        xlat    PN_Digits
        stosw
        inc     di
        inc     di
        ret

PrintFrame:
        ASSUME  ds:NOTHING
        mov     cx, ds:TRACK_1[si]
        mov     dx, ds:TRACK_1[si+2]
        call    PrintNote
        mov     cx, ds:TRACK_2[si]
        mov     dx, ds:TRACK_2[si+2]
        call    PrintNote
        mov     cx, ds:TRACK_3[si]
        mov     dx, ds:TRACK_3[si+2]
        call    PrintNote
        mov     cx, ds:TRACK_4[si]
        mov     dx, ds:TRACK_4[si+2]
        call    PrintNote
        ret

PUBLIC ST_PrintInit
ST_PrintInit PROC FAR VSeg:WORD,A:BYTE,HiA:BYTE,FA:BYTE,HiFA:BYTE,PA:BYTE,FFR:WORD,LVO:WORD
        ASSUME  ds:NOTHING
        mov     ax, [VSeg]
        mov     [PF_VideoSeg], ax
        mov     al, [A]
        mov     [PF_Attr], al
        mov     al, [HiA]
        mov     [PF_HiAttr], al
        mov     al, [FA]
        mov     [PF_FrameAttr], al
        mov     al, [HiFA]
        mov     [PF_HiFrameAttr], al
        mov     al, [PA]
        mov     [PF_PlayFrameAttr], al
        mov     ax, [FFR]
        mov     [FirstFrameRow], ax
        mov     ax, [LVO]
        mov     [LastVideoOfs], ax
        ret
ST_PrintInit ENDP

PUBLIC ST_PrintFrame
ST_PrintFrame PROC FAR aPattPtr:DWORD, aFrame:WORD, aY:WORD
        USES    ds
        ASSUME  ds:NOTHING
        mov     es, [PF_VideoSeg]
        mov     di, [aY]
        add     di, [FirstFrameRow]
        shl     di, 1
        mov     di, PN_VideoOfs[di]
        lds     si, [aPattPtr]
        cld
        mov     ax, [aFrame]
        mov     cl, [PF_Attr]
        mov     dl, [PF_FrameAttr]
        test    ax, 3
        jnz     @@Ok
        mov     cl, [PF_HiAttr]
        mov     dl, [PF_HiFrameAttr]
@@Ok:
        mov     bx, ax
        mov     ch, 10
        div     ch
        add     ax, '00'
        xchg    ah, cl
        stosw
        mov     al, cl
        stosw
        inc     di
        inc     di
        mov     ax, bx
        shl     ax, 1
        shl     ax, 1
        add     si, ax
        mov     ah, dl
        call    PrintFrame
        ret
ST_PrintFrame ENDP

PUBLIC ST_PrintHiFrame
ST_PrintHiFrame PROC FAR aPattPtr:DWORD, aFrame:WORD, aY:WORD
        USES    ds
        ASSUME  ds:NOTHING
        mov     es, [PF_VideoSeg]
        mov     di, [aY]
        add     di, [FirstFrameRow]
        shl     di, 1
        mov     di, PN_VideoOfs[di]
        lds     si, [aPattPtr]
        cld
        mov     ax, [aFrame]
        mov     bx, ax
        mov     ch, 10
        div     ch
        add     ax, '00'
        mov     cl, [PF_PlayFrameAttr]
        mov     ch, cl
        xchg    ah, cl
        stosw
        mov     al, cl
        stosw
        inc     di
        inc     di
        mov     ax, bx
        shl     ax, 1
        shl     ax, 1
        add     si, ax
        mov     ah, ch
        call    PrintFrame
        ret
ST_PrintHiFrame ENDP

PrintPeak:
        mov     di, [LastVideoOfs]
        inc     di
        add     di, cx
        xor     ah, ah
        shr     ax, 1
        shr     ax, 1
        mov     dx, ax
        mov     cx, ax
        jcxz    @@Skip
        xor     ah, ah
@@Loop:
        mov     al, ah
        xlat    PN_Colors
        mov     es:[di], al
        mov     es:[di+2], al
        sub     di, 160
        inc     ah
        loop    @@Loop
@@Skip:
        mov     cx, 16
        sub     cx, dx
        jcxz    @@Exit
@@LoopDel:
        mov     BYTE PTR es:[di], SHADOWATTR
        mov     BYTE PTR es:[di+2], SHADOWATTR
        sub     di, 160
        loop    @@LoopDel
@@Exit:
        ret

InitPeakSub:
        mov     cx, 16
        mov     al, PEAKCHAR
        mov     ah, SHADOWATTR
@@Loop1:
        mov     es:[di], ax
        mov     es:[di+2], ax
        sub     di, 160
        loop    @@Loop1
        ret

InitPeak:
        mov     es, [PF_VideoSeg]
        mov     di, [LastVideoOfs]
        call    InitPeakSub
        mov     di, [LastVideoOfs]
        add     di, 6
        call    InitPeakSub
        mov     di, [LastVideoOfs]
        add     di, 110
        call    InitPeakSub
        mov     di, [LastVideoOfs]
        add     di, 116
        call    InitPeakSub
        ret

PUBLIC ST_PrintPeaks
ST_PrintPeaks PROC FAR aPeak12:WORD, aPeak34:WORD
        ASSUME  ds:NOTHING
        mov     es, [PF_VideoSeg]
        mov     bx, OFFSET PN_Colors
        mov     ax, [aPeak12]
        mov     al, ah
        mov     cx, 0
        call    PrintPeak
        mov     ax, [aPeak34]
        mov     cx, 6
        call    PrintPeak
        mov     ax, [aPeak34]
        mov     al, ah
        mov     cx, 110
        call    PrintPeak
        mov     ax, [aPeak12]
        mov     cx, 116
        call    PrintPeak
        ret
ST_PrintPeaks ENDP

PUBLIC ST_PrintPeakShadow
ST_PrintPeakShadow PROC FAR
        ASSUME  ds:NOTHING
        call    InitPeak
        ret
ST_PrintPeakShadow ENDP

NewInt10h:
        cmp     ah, 03h
        je      @@Check
@@Old:
        jmp     cs:[OldInt10h]
@@Check:
        cmp     cx, MAGICCX
        jne     @@Old
        cmp     dx, MAGICDX
        jne     @@Old
        cmp     si, MAGICSI
        jne     @@Old
        cmp     di, MAGICDI
        jne     @@Old
; Ok, ritorna in BX la versione e in DX il codice
        mov     dx, DRT_VERSION
        mov     bx, DRT_IDCODE
        mov     si, OUTSI
        mov     di, OUTDI
        iret

PUBLIC ST_InstallHook
ST_InstallHook PROC FAR
        USES    ds
        ASSUME  ds:NOTHING
        mov     ax, 3510h
        int     21h
        mov     [Old10hSeg], es
        mov     [Old10hOfs], bx
        mov     ax, 2510h
        push    cs
        pop     ds
        mov     dx, OFFSET NewInt10h
        int     21h
        ret
ST_InstallHook ENDP

PUBLIC ST_RemoveHook
ST_RemoveHook PROC FAR
        USES    ds
        ASSUME  ds:NOTHING
        mov     ax, [Old10hOfs]
        or      ax, [Old10hSeg]
        jz      @@Exit
        mov     ax, 2510h
        lds     dx, OldInt10h
        int     21h
        xor     ax, ax
        mov     [Old10hOfs], ax
        mov     [Old10hSeg], ax
@@Exit:
        ret
ST_RemoveHook ENDP

PUBLIC ST_CheckHook
ST_CheckHook PROC FAR
        ASSUME  ds:NOTHING
        mov     cx, MAGICCX
        mov     dx, MAGICDX
        mov     si, MAGICSI
        mov     di, MAGICDI
        mov     ah, 03h
        xor     bh, bh
        push    bp
        int     10h
        pop     bp
        xor     ax, ax
        cmp     si, OUTSI
        jne     @@Exit
        cmp     di, OUTDI
        jne     @@Exit
        cmp     cx, MAGICCX
        jne     @@Exit
        mov     ax, bx
@@Exit:
        ret
ST_CheckHook ENDP

END

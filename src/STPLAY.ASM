COMMENT /
  The "4 Track Drive" system
  CopyRight (c) 1991 Alessandro Scotti

  Real-time 4-channel mixer
  DMA background module player for the SoundBlaster Card

  Last update: 13 dec 1992

  286 code only!
/
.286
.MODEL TPASCAL
LOCALS

.CODE

;***
;*** Dichiarazione tipi e costanti
;***

HIVERSION       EQU     1
LOVERSION       EQU     50

NULLSAMPLELEN   EQU     1024
MINREPLEN       EQU     2
MAXSAMPLE       EQU     32
TABLELEN        EQU     5*16
MAXPATTERN      EQU     128
VOLUMELEVELS    EQU     65
TRACK_1         EQU     0
TRACK_2         EQU     256
TRACK_3         EQU     512
TRACK_4         EQU     768
MAXINCREMENT    EQU     768     ; Max incr. offset sample in un ciclo
EMM_NIL         EQU     0FFFFh

NONEWPOSITION   EQU     0FFh
MAXVOLUME       EQU     40h
DEFAULTSPEED    EQU     06h
MAX_AMIGAFREQ   EQU     358h
MIN_AMIGAFREQ   EQU     071h
NULLCOMMAND     EQU     0Eh     ; "Set filter", non implementato
TONEPORTAMENTO  EQU     03h
GODOWN          EQU     0       ; Flag per il tone portamento
GOUP            EQU     1       ;  "    "  "    "       "

; Struttura informazioni sui sample
Sample  STRUC
        sOfs    DW      ?       ; Offset sample
        sSeg    DW      ?       ; Segmento sample
        sEnd    DW      ?       ; Offset fine sample
        sRepOfs DW      ?       ; Offset parte da ripetere
        sRepSeg DW      ?       ; Segmento parte da ripetere
        sRepEnd DW      ?       ; Offset fine parte da ripetere
        sVolume DW      ?       ; Volume sample
Sample  ENDS

; Struttura traccia
Track   STRUC
        tNote           DB      ?       ; Nota
        tSample         DB      ?       ; Sample
        tCommand        DB      ?       ; Comando
        tInfoByte       DB      ?       ; Dati per il comando
        tOfs            DW      ?       ; Offset sample
        tSeg            DW      ?       ; Segmento sample
        tEnd            DW      ?       ; Offset fine sample
        tVolume         DW      ?       ; Volume (offset tabella)
        tNo             DW      ?       ; Sample (offset tabella)
        tOfsLo          DW      ?       ; Parte "bassa" offset sample
        tIncrHi         DW      ?       ; Parte alta incremento
        tIncrLo         DW      ?       ; Parte bassa incremento
        tChannelMask    DW      ?       ; Maschera canale (on/off)
        tAmigaNote      DW      ?       ; Frequenza DMA Amiga
        tMyPortDest     DW      ?       ; Destinazione tone portamento
        tMyPortFlag     DB      ?       ; Direzione tone portamento
        tMyPortSpeed    DW      ?       ; Velocit… tone portamento
        tArpeggioCount  DB      ?       ; Contatore arpeggio
        tVibCount       DB      ?       ; Contatore vibrato
        tVibInfo        DB      ?       ; Info vibrato
        tMyNote         DB      ?       ; Copia ultima nota non nulla
        tPeak           DB      ?       ; Picco nota (grafico)
        tVolTable       DW      ?       ; Offset tavola volumi
Track   ENDS

;***
;*** Variabili e tabelle
;***

; Frequenze note Amiga, dall'ottava piu' bassa. Per ogni ottava
; le note (12 semitoni) sono le entrate da 1 a 12, le altre
; (0, 13, 14 e 15) sono nulle ed hanno funzione di segnaposto.
; Nota: il Sound Tracker utilizza in effetti solo le ottave 1, 2, 3.
AmigaNote       LABEL WORD
  DW    0h,06B0h,064Fh,05F5h,059Fh,054Eh,0502h,04BAh    ; Ottava 0
  DW 0476h,0436h,03F9h,03C0h,038Ah,   0h,   0h,   0h
  DW    0h,0358h,0328h,02FAh,02D0h,02A6h,0280h,025Ch    ; Ottava 1
  DW 023Ah,021Ah,01FCh,01E0h,01C5h,   0h,   0h,   0h
  DW    0h,01ACh,0194h,017Dh,0168h,0153h,0140h,012Eh    ; Ottava 2
  DW 011Dh,010Dh,00FEh,00F0h,00E2h,   0h,   0h,   0h
  DW    0h,00D6h,00CAh,00BEh,00B4h,00AAh,00A0h,0097h    ; Ottava 3
  DW 008Fh,0087h,007Fh,0078h,0071h,   0h,   0h,   0h
  DW    0h,006Bh,0064h,005Fh,0059h,0054h,0050h,004Bh    ; Ottava 4
  DW 0047h,0043h,003Fh,003Ch,0038h,   0h,   0h,   0h

; Tavola dei seni usata dal Sound Tracker per il vibrato
AmigaSineTable  LABEL BYTE
  DB 000h, 018h, 031h, 04Ah, 061h, 078h, 08Dh, 0A1h
  DB 0B4h, 0C5h, 0D4h, 0E0h, 0EBh, 0F4h, 0FAh, 0FDh
  DB 0FFh, 0FDh, 0FAh, 0F4h, 0EBh, 0E0h, 0D4h, 0C5h
  DB 0B4h, 0A1h, 08Dh, 078h, 061h, 04Ah, 031h, 018h

dSamples        Sample  MAXSAMPLE       DUP(<>)         ; Array info sample
dSamplesIdx     DW  MAXSAMPLE           DUP(?)          ; Indice array sample
BitsPerSample   DB      ?
                DB      ?
dVolume1        DB  256                 DUP(?)          ; Volumi ch. 1
dVolume2        DB  256                 DUP(?)          ; Volumi ch. 2
dVolume3        DB  256                 DUP(?)          ; Volumi ch. 3
dVolume4        DB  256                 DUP(?)          ; Volumi ch. 4
NullData        DB  NULLSAMPLELEN       DUP(0)          ; Sample nullo
OutBufferIdx    DB  ?
OutBufferSize   DW  ?
Order           DW  MAXPATTERN          DUP(?)          ; Array "order"
Pattern         DD  MAXPATTERN          DUP(?)          ; Array pattern (ptr)
OrderIdx        DW  ?
OrderMin        DW  ?
OrderMax        DW  ?
ThisPattern     DW  ?
ThisFrame       DW  ?
ThisPatternPtr  LABEL DWORD                             ; Ptr pattern in exec.
ThisPatternOfs  DW  ?
ThisPatternSeg  DW  ?
SongSpeed       DW  ?                                   ; Velocit… song
PosJumpFlag     DB  ?                                   ; Flag di jump
BreakFlag       DB  ?                                   ; Flag di break pattern
ReferenceFreq   DW  ?                                   ; Frequenza di rif.
MasterVolume    DB  64                                  ; Master volume

TempSpeed       DW  ?
TempESDI        LABEL DWORD
TempDI          DW  ?
TempES          DW  ?

PLAY_MOD        EQU     0
PLAY_SOLO       EQU     1

PlayMode        DB      ?

EMM_Handle              DW      ?
Buffer1COfs             DW      ?
Buffer2COfs             DW      ?

; Tavola degli "incrementi" necessari a modificare al volo
; la frequenza del sample da riprodurre.
IncrHi          DW  TABLELEN            DUP(?)
IncrLo          DW  TABLELEN            DUP(?)

;***
;*** Variabili gestione DMA
;***

DMABUFSIZE      EQU     420*2           ; Max speed = 21000 hertz
END_OF_DMA      EQU     82h
BUFFER_READY    EQU     81h
BUFFER_USED     EQU     80h
NO_MORE_BLOCKS  EQU     80h

SBC_Port        DW      ?
SBC_IRQ         DW      ?

DMA_irqOfs      DW      ?               ; Offset gestore IRQ DMA
DMA_initOfs     DW      ?               ; Offset routine di init DMA
DMA_doneOfs     DW      ?               ; Offset routine di fine DMA

DMABuffer1      DB      DMABUFSIZE      DUP(?)
DMABuffer2      DB      DMABUFSIZE      DUP(?)
DMABuffer3      DB      DMABUFSIZE      DUP(?)

Buffer1Ptr      LABEL   DWORD
Buffer1Ofs      DW      ?               ; Offset primo buffer
Buffer1Seg      DW      ?               ; Segmento primo buffer
Buffer2Ptr      LABEL   DWORD
Buffer2Ofs      DW      ?               ; Offset secondo buffer
Buffer2Seg      DW      ?               ; Segmento secondo buffer

BufferPage      DB      ?               ; Pagina buffer
BufferOffset    DW      ?               ; Offset buffer in uso
BufferLength    DW      ?               ; Lunghezza buffer
BufferLengthStereo DW   ?               ; Lunghezza buffer stereo
BufferFlag      DB      ?
DMAHook         DW      ?               ; Routine ausiliaria interrupt DMA
TimeConstant    DB      ?               ; Sampling rate per DSP
TimeConstantStereo  DB  ?               ; Sampling rate per DSP (modo stereo)
OldIRQ          LABEL   DWORD           ; Vecchio interrupt SBC_IRQ
OldIRQOfs       DW      0
OldIRQSeg       DW      0

;***
;*** Codice gestione DMA
;***

;  SubRoutine
Set_Int_Vector:
        ASSUME  ds:NOTHING
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
        ASSUME  ds:NOTHING
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
Read_DSP:
        ASSUME  ds:NOTHING
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
        ASSUME  ds:NOTHING
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

; Aggiusta alla pagina il segmento del puntatore DX:AX
;
; L'indirizzo lineare di un puntatore DX:AX si ottiene con (DX shl 4 + AX).
; Dato che DX shl 4 puo' provocare la perdita di alcuni bit facciamo in modo
; che DX:BX = DX shl 4. A questo punto AX = AX + BX e DX = DX + eventuale
; riporto dall'addizione precedente. Ora DX:AX = indirizzo lineare, shiftiamo
; DX a sinistra di 12 bit per ottenere il segmento e siamo a posto.
;
AdjustPointer:
        push    bx
        push    cx
        push    dx
        mov     cl, 12                          ; DX = HMMM
        shr     dx, cl                          ; DX = 000H
        pop     bx                              ; BX = HMMM
        mov     cl, 4                           ; AX = OOOO
        shl     bx, cl                          ; BX = MMM0
        add     ax, bx                          ; AX = nuovo offset
        adc     dx, 0                           ; Tiene conto dell'overflow
        mov     cl, 12
        shl     dx, cl                          ; DX = nuovo segmento
        pop     cx
        pop     bx
        ret

; Controlla se l'offset AX Š valido per un buffer DMA (no page-wrap)
CheckDMABuffer:
        push    ax
        push    bx
        push    dx
        mov     dx, cs
        push    ax
        call    AdjustPointer
        pop     ax
        add     ax, DMABUFSIZE
        mov     bx, dx
        mov     dx, cs
        call    AdjustPointer
        cmp     bx, dx                  ; Z=1 ok, Z=0 buffer non valido
        pop     dx
        pop     bx
        pop     ax
        ret

; Controlla se un buffer e valido ed eventualmente lo salva in SI o DI
CheckAndSet:
        call    CheckDMABuffer
        jne     @@Exit
        or      si, si
        jnz     @@SetDI
        mov     si, ax
        jmp     SHORT @@Exit
@@SetDI:
        mov     di, ax
@@Exit:
        ret

ClearDMABuffers:
        ASSUME  ds:NOTHING
        push    ax
        push    cx
        push    dx
        push    es
        push    di
        mov     ax, cs
        mov     es, ax
        mov     di, OFFSET DMABuffer1
        cld
        mov     cx, DMABUFSIZE*3
        mov     al, 80h
        rep     stosb
        les     ax, [Buffer1Ptr]
        mov     dx, es
        mov     cl, 4
        shr     dh, cl
        mov     [BufferOffset], ax
        mov     [BufferPage], dh
        mov     ax, [OutBufferSize]
        mov     dx, ax
        shl     dx, 1
        dec     dx
        mov     [BufferLengthStereo], dx
        dec     ax
        mov     [BufferLength], ax
        mov     [OutBufferIdx], 0
        pop     di
        pop     es
        pop     dx
        pop     cx
        pop     ax
        ret

PUBLIC ST_SetMasterVolume
ST_SetMasterVolume      PROC    FAR     aVolume:BYTE
        mov     al, [aVolume]
        mov     cs:[MasterVolume], al

        mov     ax, [OldIRQOfs]
        or      ax, [OldIRQSeg]
        jz      @@Exit                          ; Not playing

        push    es
        push    ds

        push    cs
        pop     es
        push    cs
        pop     ds
        mov     si, OFFSET Track1
        mov     ax, cs:[si].tVolume
        mov     bx, cs:[si].tVolTable
        call    ST_SetTrackVolume
        mov     si, OFFSET Track2
        mov     ax, cs:[si].tVolume
        mov     bx, cs:[si].tVolTable
        call    ST_SetTrackVolume
        mov     si, OFFSET Track3
        mov     ax, cs:[si].tVolume
        mov     bx, cs:[si].tVolTable
        call    ST_SetTrackVolume
        mov     si, OFFSET Track4
        mov     ax, cs:[si].tVolume
        mov     bx, cs:[si].tVolTable
        call    ST_SetTrackVolume

        pop     ds
        pop     es
@@Exit:
        ret
ST_SetMasterVolume      ENDP

; Inizializza le variabili interne per il DMA
PUBLIC DMA_Init
DMA_Init PROC FAR aSBC_Port:WORD, aSBC_IRQ:WORD, aTimeConst:BYTE,aTimeConstSt:BYTE
        ASSUME  ds:NOTHING
; Inizializzazione variabili
        mov     ax, [aSBC_Port]
        mov     [SBC_Port], ax
        mov     ax, [aSBC_IRQ]
        mov     [SBC_IRQ], ax
        mov     al, [aTimeConst]
        mov     [TimeConstant], al
        mov     al, [aTimeConstSt]
        mov     [TimeConstantStereo], al
        xor     ax, ax
        mov     [OldIRQOfs], ax
        mov     [OldIRQSeg], ax
        mov     [DMAHook], OFFSET Default_DMAHook
; Controllo e scelta buffer
        xor     si, si
        xor     di, di
        mov     ax, OFFSET DMABuffer1
        call    CheckAndSet
        mov     ax, OFFSET DMABuffer2
        call    CheckAndSet
        mov     ax, OFFSET DMABuffer3
        call    CheckAndSet
        xor     ax, ax
        or      si, si
        jz      @@Exit
        or      di, di
        jz      @@Exit
        mov     ax, si
        mov     [Buffer1COfs], ax
        mov     dx, cs
        call    AdjustPointer
        mov     [Buffer1Ofs], ax
        mov     [Buffer1Seg], dx
        mov     ax, di
        mov     [Buffer2COfs], ax
        mov     dx, cs
        call    AdjustPointer
        mov     [Buffer2Ofs], ax
        mov     [Buffer2Seg], dx
        call    ClearDMABuffers
        mov     ax, 1
@@Exit:
        ret
DMA_Init ENDP

; Routine di interrupt per il DMA mono
DMA_Interrupt:
        ASSUME  ds:NOTHING
        push    ax                      ; Salvataggio registri
        push    bx
        push    cx
        push    dx
        push    ds
        push    es
        push    si
        push    di
        push    bp
        mov     al, 20h                 ; Comando di "fine interrupt"
        out     20h, al                 ; per l'interrupt controller
        mov     dx, [SBC_Port]
        add     dx, 0Eh
        in      al, dx                  ; Riconosce l'interrupt DSP
        mov     ah, [BufferPage]
        mov     bx, [BufferOffset]
        mov     cx, [BufferLength]
        mov     al, END_OF_DMA
        cmp     ah, NO_MORE_BLOCKS
        je      @@Exit                  ; Fine trasferimento
; Riprogramma il DMA per il blocco successivo
        mov     al, 05h
        out     0Ah, al                 ; Maschera il canale 1
        mov     al, ah
        out     83h, al                 ; Pagina
        mov     al, bl
        out     02h, al                 ; LSB offset nella pagina
        mov     al, bh
        out     02h, al                 ; MSB offset nella pagina
        mov     al, cl
        out     03h, al                 ; LSB contatore
        mov     al, ch
        out     03h, al                 ; MSB contatore
        mov     al, 1
        out     0Ah, al                 ; Abilita il canale 1
; Riprogramma il DSP per il blocco successivo
        mov     dx, [SBC_Port]
        add     dx, 0Ch
@@L1:   in      al, dx
        or      al, al
        js      @@L1
        mov     al, 14h
        out     dx, al                  ; DMA mode 8-bit DAC
@@L2:   in      al, dx
        or      al, al
        js      @@L2
        mov     al, cl
        out     dx, al                  ; LSB contatore per il DSP
@@L3:   in      al, dx
        or      al, al
        js      @@L3
        mov     al, ch
        out     dx, al                  ; MSB contatore per il DSP
        mov     al, BUFFER_USED
@@Exit:
        mov     [BufferFlag], al
        cmp     al, END_OF_DMA
        je      @@ExitNow
        call    [DMAHook]
@@ExitNow:
        pop     bp
        pop     di
        pop     si
        pop     es
        pop     ds
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        iret

; Inizia il trasferimento dati in DMA mono
DMA_Start:
        ASSUME  ds:NOTHING
; Setta il "time constant" per il DSP (256-1000000/srate)
        push    ax
        push    bx
        push    cx
        push    dx
        call    ClearDMABuffers
        mov     al, 40h
        call    Write_DSP
        mov     al, [TimeConstant]
        call    Write_DSP               ; Setta il sampling rate
; Istalla la routine per la gestione dell'interrupt di fine DMA
        mov     bx, [SBC_IRQ]
        add     bx, 8
        push    bx
        call    Get_Int_Vector
        pop     bx
        mov     [OldIRQOfs], ax
        mov     [OldIRQSeg], dx
        mov     dx, cs
        mov     ax, OFFSET DMA_Interrupt
        call    Set_Int_Vector
; Inizializza l'8237 (DMAC) e lo predispone per il primo blocco
        mov     ah, [BufferPage]
        mov     bx, [BufferOffset]
        mov     cx, [BufferLength]
        mov     al, 05h
        out     0Ah, al                 ; Maschera canale 1
        xor     al, al
        out     0Ch, al                 ; Inizializza il puntatore al byte
        mov     al, 49h
        out     0Bh, al                 ; Lettura dalla memoria (ch. 0-3)
        mov     al, ah
        out     83h, al                 ; Pagina (ch. 1)
        mov     al, bl
        out     02h, al                 ; LSB offset nella pagina (ch. 1)
        mov     al, bh
        out     02h, al                 ; MSB offset nella pagina (ch. 1)
        mov     al, cl
        out     03h, al                 ; LSB contatore (ch. 1)
        mov     al, ch
        out     03h, al                 ; MSB contatore (ch. 1)
        mov     al, 1
        out     0Ah, al                 ; Abilita canale 1
; Inizializza il DSP
        mov     cx, [SBC_IRQ]
        mov     ah, 1
        shl     ah, cl
        not     ah
        in      al, 21h
        and     al, ah
        out     21h, al                 ; Attiva l'IRQ
        mov     cx, [BufferLength]
        mov     al, 14h                 ; Modo DMA 8 bit
        call    Write_DSP
        mov     al, cl                  ; LSB contatore
        call    Write_DSP
        mov     al, ch                  ; MSB contatore
        call    Write_DSP
        pop     dx
        pop     cx
        pop     bx
        pop     ax
Default_DMAHook:
        ret

; Arresta il DMA e ripristina la situazione precedente la chiamata a
; DMA_Start (mono)
DMA_End:
        ASSUME  ds:NOTHING
        push    ax
        push    bx
        push    cx
        push    dx
        mov     cx, [SBC_IRQ]
        mov     ah, 1
        shl     ah, cl
        in      al, 21h
        or      al, ah
        out     21h, al                 ; Disattiva l'IRQ
        mov     ax, [OldIRQOfs]
        mov     dx, [OldIRQSeg]
        or      ax, dx
        jz      @@Exit
        mov     bx, [SBC_IRQ]
        add     bx, 8
        call    Set_Int_Vector          ; Ripristina il vecchio interrupt
        mov     [OldIRQOfs], 0
        mov     [OldIRQSeg], 0
        pop     dx
        pop     cx
        pop     bx
        pop     ax
@@Exit:
        ret

;------------------------------------------------------------
; Gestione SB Pro

SB_MIXERPORT    EQU     04h             ; Porta mixer SoundBlaster Pro
SB_STEREOREG    EQU     0Eh             ; Registro mixer controllo stereo

SB_OldStereoReg DB      ?
SB_Bit6Status   DB      ?

;------------------------------------------------------------
; Input:
;       AL      = registro mixer
; Output:
;       AL      = contenuto registro mixer
;
Read_SBMixer:
        push    dx
        mov     dx, [SBC_Port]
        add     dx, SB_MIXERPORT
        out     dx, al
        inc     dx
        jmp     $+2
        jmp     $+2
        jmp     $+2
        in      al, dx
        pop     dx
        ret

;------------------------------------------------------------
; Input:
;       AL      = registro mixer
;       AH      = valore da scrivere nel registro
;
Write_SBMixer:
        push    dx
        mov     dx, [SBC_Port]
        add     dx, SB_MIXERPORT
        out     dx, al
        inc     dx
        jmp     $+2
        jmp     $+2
        jmp     $+2
        mov     al, ah
        out     dx, al
        pop     dx
        ret

Init_SBPro:
        ret
        push    dx
        push    ax
        mov     al, SB_STEREOREG
        call    Read_SBMixer
        mov     [SB_OldStereoReg], al
        mov     dl, 1
        and     al, 20h
        jnz     @@Ok
        xor     dl, dl
@@Ok:
        mov     [SB_Bit6Status], dl
        mov     ah, [SB_OldStereoReg]
        or      ah, 20h
        mov     al, SB_STEREOREG
        call    Write_SBMixer
        mov     ah, 2
        mov     al, SB_STEREOREG
        call    Read_SBMixer
        and     al, 0FDh
        or      ah, al
        mov     al, SB_STEREOREG
        call    Write_SBMixer
        pop     ax
        pop     dx
        ret

Done_SBPro:
        ret
        push    cx
        push    ax
        push    dx
        mov     al, SB_STEREOREG
        call    Read_SBMixer
        and     al, 0DDh
        mov     ah, [SB_Bit6Status]
        mov     cl, 5
        shl     ah, cl
        or      ah, al
        mov     al, SB_STEREOREG
        call    Write_SBMixer
        mov     dx, [SBC_Port]
        add     dl, 0Eh
        in      al, dx
        pop     dx
        pop     ax
        pop     cx
        ret

;------------------------------------------------------------
; Routine di interrupt per il DMA stereo
DMA_InterruptStereo:
        ASSUME  ds:NOTHING
        push    ax                      ; Salvataggio registri
        push    bx
        push    cx
        push    dx
        push    ds
        push    es
        push    si
        push    di
        push    bp
        mov     al, 20h                 ; Comando di "fine interrupt"
        out     20h, al                 ; per l'interrupt controller
        mov     dx, [SBC_Port]
        add     dx, 0Eh
        in      al, dx                  ; Riconosce l'interrupt DSP
        mov     ah, [BufferPage]
        mov     bx, [BufferOffset]
        mov     cx, [BufferLengthStereo]
        mov     al, END_OF_DMA
        cmp     ah, NO_MORE_BLOCKS
        je      @@Exit                  ; Fine trasferimento
; Riprogramma il DMA per il blocco successivo
        mov     al, 05h
        out     0Ah, al                 ; Maschera il canale 1
        mov     al, ah
        out     83h, al                 ; Pagina
        mov     al, bl
        out     02h, al                 ; LSB offset nella pagina
        mov     al, bh
        out     02h, al                 ; MSB offset nella pagina
        mov     al, cl
        out     03h, al                 ; LSB contatore
        mov     al, ch
        out     03h, al                 ; MSB contatore
        mov     al, 1
        out     0Ah, al                 ; Abilita il canale 1
; Riprogramma il DSP per il blocco successivo
        mov     dx, [SBC_Port]
        add     dx, 0Ch
@@L1:   in      al, dx
        or      al, al
        js      @@L1
        mov     al, 48h
        out     dx, al                  ;
@@L2:   in      al, dx
        or      al, al
        js      @@L2
        mov     al, cl
        out     dx, al                  ; LSB contatore per il DSP
@@L3:   in      al, dx
        or      al, al
        js      @@L3
        mov     al, ch
        out     dx, al                  ; MSB contatore per il DSP
@@L4:   in      al, dx
        or      al, al
        js      @@L4
        mov     al, 91h
        out     dx, al                  ;
        mov     al, BUFFER_USED
@@Exit:
        mov     [BufferFlag], al
        cmp     al, END_OF_DMA
        je      @@ExitNow
        call    [DMAHook]
@@ExitNow:
        pop     bp
        pop     di
        pop     si
        pop     es
        pop     ds
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        iret

;------------------------------------------------------------
; Inizia il trasferimento dati in DMA stereo
DMA_StartStereo:
        ASSUME  ds:NOTHING
; Setta il "time constant" per il DSP (256-1000000/srate)
        push    ax
        push    bx
        push    cx
        push    dx
        call    ClearDMABuffers
        call    Init_SBPro              ; Inizializzazione stereo
        mov     al, 40h
        call    Write_DSP
        mov     al, [TimeConstantStereo]
        call    Write_DSP               ; Setta il sampling rate
; Istalla la routine per la gestione dell'interrupt di fine DMA
        mov     bx, [SBC_IRQ]
        add     bx, 8
        push    bx
        call    Get_Int_Vector
        pop     bx
        mov     [OldIRQOfs], ax
        mov     [OldIRQSeg], dx
        mov     dx, cs
        mov     ax, OFFSET DMA_InterruptStereo
        call    Set_Int_Vector
; Inizializza l'8237 (DMAC) e lo predispone per il primo blocco
        mov     ah, [BufferPage]
        mov     bx, [BufferOffset]
        mov     cx, [BufferLengthStereo]
        mov     al, 05h
        out     0Ah, al                 ; Maschera canale 1
        xor     al, al
        out     0Ch, al                 ; Inizializza il puntatore al byte
        mov     al, 49h
        out     0Bh, al                 ; Lettura dalla memoria (ch. 0-3)
        mov     al, ah
        out     83h, al                 ; Pagina (ch. 1)
        mov     al, bl
        out     02h, al                 ; LSB offset nella pagina (ch. 1)
        mov     al, bh
        out     02h, al                 ; MSB offset nella pagina (ch. 1)
        mov     al, cl
        out     03h, al                 ; LSB contatore (ch. 1)
        mov     al, ch
        out     03h, al                 ; MSB contatore (ch. 1)
        mov     al, 1
        out     0Ah, al                 ; Abilita canale 1
; Inizializza il DSP
        mov     cx, [SBC_IRQ]
        mov     ah, 1
        shl     ah, cl
        not     ah
        in      al, 21h
        and     al, ah
        out     21h, al                 ; Attiva l'IRQ
        mov     cx, [BufferLengthStereo]
        mov     al, 48h                 ;
        call    Write_DSP
        mov     al, cl                  ; LSB contatore
        call    Write_DSP
        mov     al, ch                  ; MSB contatore
        call    Write_DSP
        mov     al, 91h                 ;
        call    Write_DSP
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

;------------------------------------------------------------
; Arresta il DMA e ripristina la situazione precedente la chiamata a
; DMA_Start (stereo)
DMA_EndStereo:
        ASSUME  ds:NOTHING
        push    ax
        push    bx
        push    cx
        push    dx
        mov     cx, [SBC_IRQ]
        mov     ah, 1
        shl     ah, cl
        in      al, 21h
        or      al, ah
        out     21h, al                 ; Disattiva l'IRQ
        mov     ax, [OldIRQOfs]
        mov     dx, [OldIRQSeg]
        or      ax, dx
        jz      @@Exit
        mov     bx, [SBC_IRQ]
        add     bx, 8
        call    Set_Int_Vector          ; Ripristina il vecchio interrupt
        mov     [OldIRQOfs], 0
        mov     [OldIRQSeg], 0
        call    Done_SBPro
        pop     dx
        pop     cx
        pop     bx
        pop     ax
@@Exit:
        ret

;***
;*** Codice player
;***

;------------------------------------------------------------
; Inizializza le variabili
PUBLIC ST_Init
ST_Init PROC FAR IsStereo:BYTE
        USES    ds
        ASSUME  ds:CODE
        mov     ax, cs
        mov     ds, ax
        mov     [DMA_irqOfs], OFFSET DMA_Interrupt
        mov     [DMA_initOfs], OFFSET DMA_Start
        mov     [DMA_doneOfs], OFFSET DMA_End
        mov     cl, 8
        cmp     [IsStereo], 0           ; SB Pro?
        je      @@Ok
        dec     cl                      ; Guadagna un bit se stereo
        mov     [DMA_irqOfs], OFFSET DMA_InterruptStereo
        mov     [DMA_initOfs], OFFSET DMA_StartStereo
        mov     [DMA_doneOfs], OFFSET DMA_EndStereo
@@Ok:
        mov     [BitsPerSample], cl
        mov     bx, OFFSET SoloVolumeTable
        mov     al, 40h
        call    ST_SetTrackVolume
; Costruzione indice sample
        mov     cx, MAXSAMPLE
        mov     bx, OFFSET dSamplesIdx
        mov     ax, OFFSET dSamples
@@Loop:
        mov     [bx], ax
        inc     bx
        inc     bx
        add     ax, SIZE Sample
        loop    @@Loop
        ret
ST_Init ENDP

PUBLIC ST_InitSamples
ST_InitSamples PROC FAR
        USES    ds
        ASSUME  ds:CODE
        mov     ax, cs
        mov     ds, ax
; Inizializzazione tabella sample (sample nullo)
        mov     bx, OFFSET dSamples
        mov     cx, MAXSAMPLE
@@Loop:
        mov     [bx].sSeg,      cs
        mov     [bx].sOfs,      OFFSET NullData
        mov     [bx].sEnd,      OFFSET NullData+NULLSAMPLELEN
        mov     [bx].sRepSeg,   cs
        mov     [bx].sRepOfs,   OFFSET NullData
        mov     [bx].sRepEnd,   OFFSET NullData+NULLSAMPLELEN
        mov     [bx].sVolume,   0
        add     bx, SIZE Sample
        loop    @@Loop
        ret
ST_InitSamples ENDP

; Inserisce un sample nella tabella
PUBLIC ST_SetSample
ST_SetSample PROC FAR aNum:WORD,aPtr:DWORD,aLen:WORD,aROfs:WORD,aRLen:WORD,aVol:WORD
        ASSUME  ds:DATA
; Lettura e controllo numero sample
        mov     bx, [aNum]
        cmp     bx, 1
        jb      @@Exit
        cmp     bx, MAXSAMPLE
        jae     @@Exit
        shl     bx, 1
        mov     bx, cs:dSamplesIdx[bx]
; Trasferimento dati
        mov     ax, [aVol]
        mov     cs:[bx].sVolume, ax     ; Volume
        les     di, aPtr
        mov     ax, [aLen]
        add     ax, di
        cli
        mov     cs:[bx].sSeg, es        ; Segmento
        mov     cs:[bx].sOfs, di        ; Offset
        mov     cs:[bx].sEnd, ax        ; Offset fine sample
        sti
        add     di, [aROfs]
        mov     cx, [aRLen]
        cmp     cx, MINREPLEN
        ja      @@SetRep
        mov     di, OFFSET NullData
        mov     cx, NULLSAMPLELEN
        mov     ax, cs
        mov     es, ax
@@SetRep:
        add     cx, di
        cli
        mov     cs:[bx].sRepSeg, es     ; Segmento repeat
        mov     cs:[bx].sRepOfs, di     ; Offset repeat
        mov     cs:[bx].sRepEnd, cx     ; Offset fine repeat
        sti
@@Exit:
        ret
ST_SetSample ENDP

; Ritorna in DX:AX la coppia di "divisori" relativi alla nota "Amiga" AX
GetIncrement:
        ASSUME  ds:NOTHING
        xor     dx, dx
        or      ax, ax
        jz      @@Exit
        mov     bx, ax
        mov     ax, [ReferenceFreq]
        div     bx
        push    ax                      ; Parte "alta"
COMMENT /
        cmp     bx, [ReferenceFreq]
        jbe     @@Ok
        mov     dx, [ReferenceFreq]
@@Ok:
        push    dx
        mov     dx, 1
        xor     ax, ax
        div     bx
        pop     dx
        mul     dx                      ; Parte "bassa" in AX
        pop     dx                      ; Parte "alta" in DX
/
        xor     ax, ax
        div     bx
        pop     dx
@@Exit:
        ret

; Costruisce le tabelle degli incrementi relative ad una frequenza base
PUBLIC ST_SetRate
ST_SetRate PROC FAR aRefFreq:WORD, aOutBufSize:WORD
        USES    ds
        ASSUME  ds:CODE
        mov     ax, cs
        mov     ds, ax
        mov     ax, [aOutBufSize]
        mov     [OutBufferSize], ax
        mov     cx, TABLELEN
        xor     di, di
        mov     si, OFFSET AmigaNote
        cld
        mov     ax, [aRefFreq]
        mov     [ReferenceFreq], ax
@@Loop:
        lodsw
        call    GetIncrement
        mov     IncrHi[di], dx
        mov     IncrLo[di], ax
@@EndLoop:
        add     di, 2
        loop    @@Loop
        ret
ST_SetRate ENDP

; Setta il pattern di ordine aNum al valore aData
PUBLIC ST_SetOrder
ST_SetOrder PROC FAR aNum:WORD, aData:WORD
        ASSUME  ds:NOTHING
        mov     bx, [aNum]
        mov     ax, [aData]
        shl     bx, 1
        mov     Order[bx], ax
        ret
ST_SetOrder ENDP

; Setta il puntatore al pattern numero aNum
PUBLIC ST_SetPattern
ST_SetPattern PROC FAR aNum:WORD, aPtr:DWORD
        ASSUME  ds:NOTHING
        les     ax, [aPtr]
        mov     bx, [aNum]
        shl     bx, 1
        shl     bx, 1
        mov     WORD PTR Pattern[bx], ax
        mov     WORD PTR Pattern[bx+2], es
        ret
ST_SetPattern ENDP

; Input:
;       BX      = offset tabella destinazione
;       AL      = volume
ST_SetTrackVolume:
        mul     cs:[MasterVolume]
        shl     ax, 1
        shl     ax, 1
        mov     al, ah          ; AL = AX div 64
        push    di
        mov     di, bx
        mov     dh, al
        xor     dl, dl
        mov     ax, cs
        mov     es, ax
        mov     bx, 256
        mov     cl, cs:[BitsPerSample]
        cld
@@Loop01:
        mov     al, dh
        cbw
        imul    dl
        sar     ax, cl
        stosb
        inc     dl
        dec     bx
        jnz     @@Loop01
        pop     di
        ret

; Input:
;       BX      = offset tabella destinazione
;       AL      = volume
ST_SetSoloTrackVolume:
        push    es
        push    WORD PTR cs:[BitsPerSample]
        push    cs
        pop     es
        mov     cs:[BitsPerSample], 6
        call    ST_SetTrackVolume
        pop     WORD PTR cs:[BitsPerSample]
        pop     es
        ret

; Inizializza le variabili per un nuovo brano
PUBLIC ST_InitSong
ST_InitSong PROC FAR aSpeed:WORD, aFirst:WORD, aLast:WORD
        USES    ds
        ASSUME  ds:CODE
        mov     ax, cs
        mov     ds, ax
; Inizializzazione variabili
        xor     ax, ax
        mov     [ThisFrame], ax
        mov     [TempSpeed], ax
        mov     [OutBufferIdx], al
        mov     [BreakFlag], al
        mov     [RecordNote], al
        mov     [RecordFlag], al
        mov     [PosJumpFlag], NONEWPOSITION
        mov     ax, [aSpeed]
        mov     [SongSpeed], ax
        mov     ax, [aLast]
        mov     [OrderMax], ax
        mov     ax, [aFirst]
        mov     [OrderMin], ax
        mov     [OrderIdx], ax
        mov     bx, ax                          ; Puntatore pattern in play
        shl     bx, 1
        mov     bx, Order[bx]
        mov     [ThisPattern], bx
        shl     bx, 1
        shl     bx, 1
        les     ax, Pattern[bx]
        mov     [ThisPatternOfs], ax
        mov     [ThisPatternSeg], es
; Inizializzazione traccie
        mov     si, OFFSET Track1
        mov     ax, OFFSET dVolume1
        call    InitTrackSI
        mov     si, OFFSET Track2
        mov     ax, OFFSET dVolume2
        call    InitTrackSI
        mov     si, OFFSET Track3
        mov     ax, OFFSET dVolume3
        call    InitTrackSI
        mov     si, OFFSET Track4
        mov     ax, OFFSET dVolume4
        call    InitTrackSI
@@Exit:
        ret
ST_InitSong ENDP

InitTrackSI:
        ASSUME  ds:CODE
        mov     [si].tVolTable, ax
        xor     ax, ax
        mov     [si].tMyPortDest, ax
        mov     [si].tAmigaNote, ax
        mov     [si].tIncrHi, ax
        mov     [si].tIncrLo, ax
        mov     [si].tVolume, ax
        mov     [si].tOfsLo, ax
        mov     [si].tVibCount, al
        mov     [si].tVibInfo, al
        mov     [si].tPeak, al
        mov     [si].tMyNote, 11h
        mov     ax, WORD PTR dSamplesIdx[0]
        mov     [si].tNo, ax
        mov     dx, OFFSET NullData
        mov     cx, OFFSET NullData+NULLSAMPLELEN
        mov     [si].tOfs, dx
        mov     [si].tSeg, cs
        mov     [si].tEnd, cx
        mov     al, 40h
        mov     bx, [si].tVolTable
        call    ST_SetTrackVolume
        ret

; Attiva/disattiva i 4 canali in riproduzione
PUBLIC ST_OnOffChannel
ST_OnOffChannel PROC FAR aCh:WORD, aMask:WORD
        ASSUME  ds:NOTHING
        mov     bx, OFFSET Track1
        cmp     [aCh], 0
        je      @@Ok
        mov     bx, OFFSET Track2
        cmp     [aCh], 1
        je      @@Ok
        mov     bx, OFFSET Track3
        cmp     [aCh], 2
        je      @@Ok
        mov     bx, OFFSET Track4
@@Ok:
        mov     ax, [aMask]
        mov     cs:[bx].tChannelMask, ax
        ret
ST_OnOffChannel ENDP

; ***
; *** Routine per la gestione dei comandi
; ***
        ASSUME ds:CODE
; ***** Comando nullo
cNone:
        ret
; ***** Set volume
cSetVolume:
        mov     al, [si].tInfoByte
        cmp     al, MAXVOLUME
        jbe     @@Ok
        mov     al, MAXVOLUME
@@Ok:   xor     ah, ah
        mov     [si].tPeak, al
        mov     [si].tVolume, ax
        mov     bx, [si].tVolTable
        call    ST_SetTrackVolume
        ret
; ***** Volume slide
cVolumeSlide:
        mov     ax, [si].tVolume
        mov     ah, [si].tInfoByte
        mov     dh, ah
        mov     cl, 4
        shr     dh, cl
        or      dh, dh
        jz      @@VolumeDown
        add     al, dh
        cmp     al, MAXVOLUME
        jbe     @@Set
        mov     al, MAXVOLUME
        jmp     SHORT @@Set
@@VolumeDown:
        and     ah, 0Fh
        sub     al, ah
        jae     @@Set
        xor     al, al
@@Set:
        xor     ah, ah
        mov     [si].tPeak, al
        mov     [si].tVolume, ax
        mov     bx, [si].tVolTable
        call    ST_SetTrackVolume
        ret
; ***** Set speed
cSetSpeed:
        mov     al, [si].tInfoByte
        mov     ah, al
        and     al, 0Fh
        jnz     @@Set
        mov     al, ah
        mov     cl, 4
        shr     al, cl
        or      al, al
        jnz     @@Set
        mov     al, DEFAULTSPEED
@@Set:
        xor     ah, ah
        mov     [SongSpeed], ax
        ret
; ***** Portamento up
cPortUp:
        mov     bl, [si].tInfoByte
        and     bl, 00111111b
        xor     bh, bh
        mov     ax, [si].tAmigaNote
        sub     ax, bx
        cmp     ax, MIN_AMIGAFREQ
        jae     @@Set
        mov     ax, MIN_AMIGAFREQ
@@Set:
        mov     [si].tAmigaNote, ax
        call    GetIncrement
        mov     [si].tIncrHi, dx
        mov     [si].tIncrLo, ax
        ret
; ***** Portamento down
cPortDown:
        mov     bl, [si].tInfoByte
        xor     bh, bh
        mov     ax, [si].tAmigaNote
        add     ax, bx
        cmp     ax, MAX_AMIGAFREQ
        jbe     @@Set
        mov     ax, MAX_AMIGAFREQ
@@Set:
        mov     [si].tAmigaNote, ax
        call    GetIncrement
        mov     [si].tIncrHi, dx
        mov     [si].tIncrLo, ax
        ret
; ***** Tone portamento
cMyPortInit:                            ; Inizializzazione
        cmp     [si].tInfoByte, 0
        je      @@Exit
        mov     bl, [si].tMyNote
        xor     bh, bh
        shl     bx, 1
        mov     ax, AmigaNote[bx]
        mov     [si].tMyPortDest, ax
        mov     cl, GOUP
        cmp     ax, [si].tAmigaNote
        jb      @@Ok
        mov     cl, GODOWN
@@Ok:
        mov     [si].tMyPortFlag, cl
        mov     bl, [si].tInfoByte
        and     bl, 00111111b
        xor     bh, bh
        mov     [si].tMyPortSpeed, bx
@@Exit:
        ret
cMyPort:                                ; Esecuzione
        mov     cx, [si].tMyPortDest
        jcxz    @@Exit
        mov     ax, [si].tAmigaNote
        cmp     [si].tMyPortFlag, GOUP
        je      @@GoUp
        add     ax, [si].tMyPortSpeed
        cmp     ax, cx
        jbe     @@Set
        mov     ax, cx
        mov     [si].tMyPortDest, 0
        jmp     SHORT @@Set
@@GoUp:
        sub     ax, [si].tMyPortSpeed
        cmp     ax, cx
        jae     @@Set
        mov     ax, cx
        mov     [si].tMyPortDest, 0
@@Set:
        mov     [si].tAmigaNote, ax
        call    GetIncrement
        mov     [si].tIncrHi, dx
        mov     [si].tIncrLo, ax
@@Exit:
        ret
; ***** Pattern break
cBreak:
        mov     [BreakFlag], 1
        ret
; ***** Position jump
cPosJump:
        mov     al, [si].tInfoByte
        mov     [PosJumpFlag], al
        ret
; ***** Arpeggio
cArpeggioInit:
        cmp     [si].tInfoByte, 0
        jne     @@Ok
        mov     [si].tCommand, NULLCOMMAND      ; Per risparmiare tempo dopo...
        ret
@@Ok:
        mov     [si].tArpeggioCount, 0
        ret
cArpeggio:
        mov     al, [si].tArpeggioCount
        inc     al
        mov     ah, [si].tInfoByte
        mov     ch, ah
        mov     cl, 4
        shr     ch, cl
        cmp     al, 1
        je      @@SetCount
        mov     ch, ah
        and     ch, 0Fh
        cmp     al, 2
        je      @@SetCount
        xor     al, al
        xor     ch, ch
@@SetCount:
        mov     [si].tArpeggioCount, al
        mov     al, [si].tMyNote
        mov     ah, al
        and     ah, 00F0h
        and     al, 000Fh
        add     al, ch
        cmp     al, 0Ch
        jbe     @@SetNote
        sub     al, 0Ch
        add     ah, 10h
        cmp     al, 0Ch
        jbe     @@SetNote
        sub     al, 0Ch
        add     ah, 10h
@@SetNote:
        or      al, ah
        jz      @@Exit
        cmp     al, 3Ch
        ja      @@Exit
        mov     bl, al
        xor     bh, bh
        shl     bx, 1
        mov     ax, IncrHi[bx]
        mov     [si].tIncrHi, ax
        mov     ax, IncrLo[bx]
        mov     [si].tIncrLo, ax
        mov     ax, AmigaNote[bx]
        mov     [si].tAmigaNote, ax
@@Exit:
        ret
; ***** Vibrato
cVibrato:
        mov     al, [si].tInfoByte
        or      al, al
        jz      @@DontSave
        mov     [si].tVibInfo, al
@@DontSave:
        mov     bl, [si].tVibCount
        shr     bl, 1
        shr     bl, 1
        and     bl, 1Fh
        xor     bh, bh
        mov     bl, AmigaSineTable[bx]
        mov     al, [si].tVibInfo
        and     al, 0Fh
        mul     bl
        mov     cl, 6
        shr     ax, cl
        cmp     [si].tVibCount, 128
        jb      @@Set
        neg     ax
@@Set:
        add     ax, [si].tAmigaNote
        mov     [si].tAmigaNote, ax
        call    GetIncrement
        mov     [si].tIncrHi, dx
        mov     [si].tIncrLo, ax
        mov     al, [si].tVibInfo
        shr     al, 1
        shr     al, 1
        and     al, 3Ch
        add     [si].tVibCount, al
        ret

; Tavola comandi inizio frame
ComTableFirst   DW      cArpeggioInit   ; Arpeggio
                DW      cNone           ; Portamento up
                DW      cNone           ;     "      down
                DW      cMyPortInit     ; Tone portamento
                DW      cNone           ; Vibrato
                DW      cNone           ; -
                DW      cNone           ; -
                DW      cNone           ; -
                DW      cNone           ; -
                DW      cNone           ; -
                DW      cNone           ; Volume slide
                DW      cPosJump        ; Position jump
                DW      cSetVolume      ; Set volume
                DW      cBreak          ; Pattern break
                DW      cNone           ; Set filter
                DW      cSetSpeed       ; Set speed

; Tavola comandi sustain frame
CommandTable    DW      cArpeggio       ; Arpeggio
                DW      cPortUp         ; Portamento up
                DW      cPortDown       ;     "      down
                DW      cMyPort         ; Tone portamento
                DW      cVibrato        ; Vibrato
                DW      cNone           ; -
                DW      cNone           ; -
                DW      cNone           ; -
                DW      cNone           ; -
                DW      cNone           ; -
                DW      cVolumeSlide    ; Volume slide
                DW      cNone           ; Position jump
                DW      cNone           ; Set volume
                DW      cNone           ; Pattern break
                DW      cNone           ; Set filter
                DW      cNone           ; Set speed

PlayCommand:
        ASSUME  ds:CODE
        cmp     [si].tPeak, 0
        je      @@Ok
        dec     [si].tPeak
@@Ok:
        mov     bl, [si].tCommand
        and     bl, 0Fh
        xor     bh, bh
        shl     bx, 1
        add     bx, OFFSET CommandTable
        call    [bx]
        ret

; Ritorna la velocit… attuale
PUBLIC ST_GetSpeed
ST_GetSpeed PROC FAR
        mov     ax, cs:[SongSpeed]
        ret
ST_GetSpeed ENDP

Track1          Track   <>
Track2          Track   <>
Track3          Track   <>
Track4          Track   <>

; Parte introduttiva traccia
PlayNoteIntro:
        ASSUME  ds:CODE
        mov     al, [si].tNote
        or      al, al
        jz      @@CheckSTQuirk                  ; Continua nota precedente
        mov     [si].tMyNote, al
        cmp     [si].tCommand, TONEPORTAMENTO
        je      @@Exit                          ; Nota per il "tone portamento"
        mov     bl, al
        xor     bh, bh
        shl     bx, 1
        mov     ax, IncrHi[bx]
        mov     [si].tIncrHi, ax
        mov     ax, IncrLo[bx]
        mov     [si].tIncrLo, ax
        mov     ax, AmigaNote[bx]
        mov     [si].tAmigaNote, ax
; Controllo sample
        mov     [si].tOfsLo, 0
        mov     [si].tVibCount, 0
        mov     bx, [si].tNo
        mov     cl, [si].tSample
        xor     ch, ch
        jcxz    @@SetSample                     ; Usa il sample corrente
        shl     cx, 1
        mov     bx, cx
        mov     bx, dSamplesIdx[bx]
        mov     ax, [bx].sVolume                ; Aggiorna il volume
        mov     [si].tVolume, ax
@@SetSample:
        mov     [si].tNo, bx                    ; Copia nella traccia
        mov     ax, [bx].sOfs                   ; corrente i dati del
        mov     cx, [bx].sSeg                   ; sample
        mov     dx, [bx].sEnd
        mov     [si].tOfs, ax
        mov     [si].tSeg, cx
        mov     [si].tEnd, dx
        mov     ax, [si].tVolume
        mov     [si].tPeak, al
        mov     bx, [si].tVolTable
        call    ST_SetTrackVolume
; Esecuzione comandi
@@Exit:
        mov     bl, [si].tCommand
        and     bl, 0Fh
        xor     bh, bh
        shl     bx, 1
        add     bx, OFFSET ComTableFirst
        call    [bx]
        ret
@@CheckSTQuirk:
        mov     bl, [si].tSample
        or      bl, bl
        jz      @@Exit
        xor     bh, bh
        shl     bx, 1
        mov     bx, dSamplesIdx[bx]
        mov     ax, [bx].sVolume
        mov     [si].tVolume, ax
        jmp     @@Exit

PlaySavedSI     DW      ?

PlayFirstTrack:
        ASSUME  ds:CODE
; Controllo nota ed eventuale settaggio sample
        call    PlayNoteIntro
        jmp     SHORT PlayFirstTrackResample
PlayFirstTrackSustain:
        ASSUME  ds:CODE
; Controllo comandi
        call    PlayCommand
PlayFirstTrackResample:
; Resample e costruzione dati per output
        mov     [PlaySavedSI], si
        mov     cx, [OutBufferSize]
        mov     dx, [si].tEnd
        mov     bp, [si].tOfsLo
        mov     bx, OFFSET NullData
        cmp     [si].tChannelMask, 0
        je      @@1
        mov     bx, [si].tVolTable
@@1:
        mov     ax, [si].tIncrLo
        mov     @@TempIncrLo, ax
        mov     ax, [si].tIncrHi
        mov     @@TempIncrHi, ax
        les     si, DWORD PTR cs:[si].tOfs
        mov     cx, dx
        sub     cx, si
        cmp     cx, MAXINCREMENT
        mov     cx, [OutBufferSize]
        jae     @@FastSample
        mov     [@@TempIncrHi], ax
        jmp     $+2                     ; Svuota la coda di prefetch
@@Loop:
        mov     al, es:[si]
        SEGCS
        xlat                            ; byte -> Volume[byte]
        mov     [di], al
        inc     di
        DB      81h, 0C5h               ; add bp, [si].tIncrLo
@@TempIncrLo    DW      ?
        DB      81h, 0D6h               ; adc si, [si].tIncrHi
@@TempIncrHi    DW      ?
        cmp     si, dx
        jae     @@Repeat
@@EndLoop:
        loop    @@Loop
@@Exit:
        mov     ax, si
        mov     si, [PlaySavedSI]
        mov     [si].tOfs, ax
        mov     [si].tSeg, es
        mov     [si].tEnd, dx
        mov     [si].tOfsLo, bp
        ret
@@Repeat:
        mov     si, [PlaySavedSI]
        mov     si, [si].tNo
        mov     es, [si].sRepSeg
        mov     dx, [si].sRepEnd
        mov     si, [si].sRepOfs
        xor     bp, bp
        jmp     @@EndLoop
@@FastSample:
        mov     [@@FastIncrHi], ax
        mov     ax, @@TempIncrLo
        mov     [@@FastIncrLo], ax
        jmp     $+2                     ; Svuota la coda di prefetch
@@FastLoop:
        mov     al, es:[si]
        SEGCS
        xlat                            ; byte -> Volume[byte]
        mov     [di], al
        inc     di
        DB      81h, 0C5h               ; add bp, [si].tIncrLo
@@FastIncrLo    DW      ?
        DB      81h, 0D6h               ; adc si, [si].tIncrHi
@@FastIncrHi    DW      ?
        loop    @@FastLoop
        jmp     @@Exit

PlayMiddleTrack:
        ASSUME  ds:CODE
; Controllo nota ed eventuale settaggio sample
        call    PlayNoteIntro
        jmp     SHORT PlayMiddleTrackResample
PlayMiddleTrackSustain:
        ASSUME  ds:CODE
; Controllo comandi
        call    PlayCommand
PlayMiddleTrackResample:
; Resample e costruzione dati per output
        mov     [PlaySavedSI], si
        mov     cx, [OutBufferSize]
        mov     dx, [si].tEnd
        mov     bp, [si].tOfsLo
        mov     bx, OFFSET NullData
        cmp     [si].tChannelMask, 0
        je      @@1
        mov     bx, [si].tVolTable
@@1:
        mov     ax, [si].tIncrLo
        mov     @@TempIncrLo, ax
        mov     ax, [si].tIncrHi
        mov     @@TempIncrHi, ax
        les     si, DWORD PTR cs:[si].tOfs
        mov     cx, dx
        sub     cx, si
        cmp     cx, MAXINCREMENT
        mov     cx, [OutBufferSize]
        jae     @@FastSample
        mov     [@@TempIncrHi], ax
        jmp     $+2                     ; Svuota la coda di prefetch
@@Loop:
        mov     al, es:[si]
        SEGCS
        xlat                            ; byte -> Volume[byte]
        add     [di], al
        inc     di
        DB      81h, 0C5h               ; add bp, [si].tIncrLo
@@TempIncrLo    DW      ?
        DB      81h, 0D6h               ; adc si, [si].tIncrHi
@@TempIncrHi    DW      ?
        cmp     si, dx
        jae     @@Repeat
@@EndLoop:
        loop    @@Loop
@@Exit:
        mov     ax, si
        mov     si, [PlaySavedSI]
        mov     [si].tOfs, ax
        mov     [si].tSeg, es
        mov     [si].tEnd, dx
        mov     [si].tOfsLo, bp
        ret
@@Repeat:
        mov     si, [PlaySavedSI]
        mov     si, [si].tNo
        mov     es, [si].sRepSeg
        mov     dx, [si].sRepEnd
        mov     si, [si].sRepOfs
        xor     bp, bp
        jmp     @@EndLoop
@@FastSample:
        mov     [@@FastIncrHi], ax
        mov     ax, @@TempIncrLo
        mov     [@@FastIncrLo], ax
        jmp     $+2                     ; Svuota la coda di prefetch
@@FastLoop:
        mov     al, es:[si]
        SEGCS
        xlat                            ; byte -> Volume[byte]
        add     [di], al
        inc     di
        DB      81h, 0C5h               ; add bp, [si].tIncrLo
@@FastIncrLo    DW      ?
        DB      81h, 0D6h               ; adc si, [si].tIncrHi
@@FastIncrHi    DW      ?
        loop    @@FastLoop
        jmp     @@Exit

PlayLastTrack:
        ASSUME  ds:CODE
; Controllo nota ed eventuale settaggio sample
        call    PlayNoteIntro
        jmp     SHORT PlayLastTrackResample
PlayLastTrackSustain:
        ASSUME  ds:CODE
; Controllo comandi
        call    PlayCommand
PlayLastTrackResample:
; Resample e costruzione dati per output
        mov     [PlaySavedSI], si
        mov     cx, [OutBufferSize]
        mov     dx, [si].tEnd
        mov     bp, [si].tOfsLo
        mov     bx, OFFSET NullData
        cmp     [si].tChannelMask, 0
        je      @@1
        mov     bx, [si].tVolTable
@@1:
        mov     ax, [si].tIncrLo
        mov     @@TempIncrLo, ax
        mov     ax, [si].tIncrHi
        mov     @@TempIncrHi, ax
        les     si, DWORD PTR cs:[si].tOfs
        mov     cx, dx
        sub     cx, si
        cmp     cx, MAXINCREMENT
        mov     cx, [OutBufferSize]
        jae     @@FastSample
        mov     [@@TempIncrHi], ax
        jmp     $+2                     ; Svuota la coda di prefetch
@@Loop:
        mov     al, es:[si]
        SEGCS
        xlat                            ; byte -> Volume[byte]
        add     [di], al
        xor     BYTE PTR [di], 128
        inc     di
        DB      81h, 0C5h               ; add bp, [si].tIncrLo
@@TempIncrLo    DW      ?
        DB      81h, 0D6h               ; adc si, [si].tIncrHi
@@TempIncrHi    DW      ?
        cmp     si, dx
        jae     @@Repeat
@@EndLoop:
        loop    @@Loop
@@Exit:
        mov     ax, si
        mov     si, [PlaySavedSI]
        mov     [si].tOfs, ax
        mov     [si].tSeg, es
        mov     [si].tEnd, dx
        mov     [si].tOfsLo, bp
        ret
@@Repeat:
        mov     si, [PlaySavedSI]
        mov     si, [si].tNo
        mov     es, [si].sRepSeg
        mov     dx, [si].sRepEnd
        mov     si, [si].sRepOfs
        xor     bp, bp
        jmp     @@EndLoop
@@FastSample:
        mov     [@@FastIncrHi], ax
        mov     ax, @@TempIncrLo
        mov     [@@FastIncrLo], ax
        jmp     $+2                     ; Svuota la coda di prefetch
@@FastLoop:
        mov     al, es:[si]
        SEGCS
        xlat                            ; byte -> Volume[byte]
        add     [di], al
        xor     BYTE PTR [di], 128
        inc     di
        DB      81h, 0C5h               ; add bp, [si].tIncrLo
@@FastIncrLo    DW      ?
        DB      81h, 0D6h               ; adc si, [si].tIncrHi
@@FastIncrHi    DW      ?
        loop    @@FastLoop
        jmp     @@Exit

;------------------------------------------------------------
PlayLastTrackStereo:
        ASSUME  ds:CODE
; Controllo nota ed eventuale settaggio sample
        call    PlayNoteIntro
        jmp     SHORT PlayLastTrackStereoRes
PlayLastTrackStereoSus:
        ASSUME  ds:CODE
; Controllo comandi
        call    PlayCommand
PlayLastTrackStereoRes:
; Resample e costruzione dati per output
        mov     [PlaySavedSI], si
        mov     cx, [OutBufferSize]
        mov     dx, [si].tEnd
        mov     bp, [si].tOfsLo
        mov     bx, OFFSET NullData
        cmp     [si].tChannelMask, 0
        je      @@1
        mov     bx, [si].tVolTable
@@1:
        mov     ax, [si].tIncrLo
        mov     @@TempIncrLo, ax
        mov     ax, [si].tIncrHi
        mov     @@TempIncrHi, ax
        les     si, DWORD PTR cs:[si].tOfs
        mov     cx, dx
        sub     cx, si
        cmp     cx, MAXINCREMENT
        mov     cx, [OutBufferSize]
        jae     @@FastSample
        mov     [@@TempIncrHi], ax
        jmp     $+2                     ; Svuota la coda di prefetch
@@Loop:
        mov     al, es:[si]
        SEGCS
        xlat                            ; byte -> Volume[byte]
        add     [di], al
        xor     BYTE PTR [di], 128
        inc     di
        inc     di
        DB      81h, 0C5h               ; add bp, [si].tIncrLo
@@TempIncrLo    DW      ?
        DB      81h, 0D6h               ; adc si, [si].tIncrHi
@@TempIncrHi    DW      ?
        cmp     si, dx
        jae     @@Repeat
@@EndLoop:
        loop    @@Loop
@@Exit:
        mov     ax, si
        mov     si, [PlaySavedSI]
        mov     [si].tOfs, ax
        mov     [si].tSeg, es
        mov     [si].tEnd, dx
        mov     [si].tOfsLo, bp
        ret
@@Repeat:
        mov     si, [PlaySavedSI]
        mov     si, [si].tNo
        mov     es, [si].sRepSeg
        mov     dx, [si].sRepEnd
        mov     si, [si].sRepOfs
        xor     bp, bp
        jmp     @@EndLoop
@@FastSample:
        mov     [@@FastIncrHi], ax
        mov     ax, @@TempIncrLo
        mov     [@@FastIncrLo], ax
        jmp     $+2                     ; Svuota la coda di prefetch
@@FastLoop:
        mov     al, es:[si]
        SEGCS
        xlat                            ; byte -> Volume[byte]
        add     [di], al
        xor     BYTE PTR [di], 128
        inc     di
        inc     di
        DB      81h, 0C5h               ; add bp, [si].tIncrLo
@@FastIncrLo    DW      ?
        DB      81h, 0D6h               ; adc si, [si].tIncrHi
@@FastIncrHi    DW      ?
        loop    @@FastLoop
        jmp     @@Exit

;------------------------------------------------------------
PlayFirstTrackStereo:
        ASSUME  ds:CODE
; Controllo nota ed eventuale settaggio sample
        call    PlayNoteIntro
        jmp     SHORT PlayFirstTrackStereoRes
PlayFirstTrackStereoSus:
        ASSUME  ds:CODE
; Controllo comandi
        call    PlayCommand
PlayFirstTrackStereoRes:
; Resample e costruzione dati per output
        mov     [PlaySavedSI], si
        mov     cx, [OutBufferSize]
        mov     dx, [si].tEnd
        mov     bp, [si].tOfsLo
        mov     bx, OFFSET NullData
        cmp     [si].tChannelMask, 0
        je      @@1
        mov     bx, [si].tVolTable
@@1:
        mov     ax, [si].tIncrLo
        mov     @@TempIncrLo, ax
        mov     ax, [si].tIncrHi
        mov     @@TempIncrHi, ax
        les     si, DWORD PTR cs:[si].tOfs
        mov     cx, dx
        sub     cx, si
        cmp     cx, MAXINCREMENT
        mov     cx, [OutBufferSize]
        jae     @@FastSample
        mov     [@@TempIncrHi], ax
        jmp     $+2                     ; Svuota la coda di prefetch
@@Loop:
        mov     al, es:[si]
        SEGCS
        xlat                            ; byte -> Volume[byte]
        mov     [di], al
        inc     di
        inc     di
        DB      81h, 0C5h               ; add bp, [si].tIncrLo
@@TempIncrLo    DW      ?
        DB      81h, 0D6h               ; adc si, [si].tIncrHi
@@TempIncrHi    DW      ?
        cmp     si, dx
        jae     @@Repeat
@@EndLoop:
        loop    @@Loop
@@Exit:
        mov     ax, si
        mov     si, [PlaySavedSI]
        mov     [si].tOfs, ax
        mov     [si].tSeg, es
        mov     [si].tEnd, dx
        mov     [si].tOfsLo, bp
        ret
@@Repeat:
        mov     si, [PlaySavedSI]
        mov     si, [si].tNo
        mov     es, [si].sRepSeg
        mov     dx, [si].sRepEnd
        mov     si, [si].sRepOfs
        xor     bp, bp
        jmp     @@EndLoop
@@FastSample:
        mov     [@@FastIncrHi], ax
        mov     ax, @@TempIncrLo
        mov     [@@FastIncrLo], ax
        jmp     $+2                     ; Svuota la coda di prefetch
@@FastLoop:
        mov     al, es:[si]
        SEGCS
        xlat                            ; byte -> Volume[byte]
        mov     [di], al
        inc     di
        inc     di
        DB      81h, 0C5h               ; add bp, [si].tIncrLo
@@FastIncrLo    DW      ?
        DB      81h, 0D6h               ; adc si, [si].tIncrHi
@@FastIncrHi    DW      ?
        loop    @@FastLoop
        jmp     @@Exit

TempCOfs        DW      ?

; Questa routine viene chiamata ogni 50-esimo di secondo dalla
; routine che gestisce l'interrupt del DMA, ed ha il compito di
; costruire il successivo blocco di dati da trasferire
ST_Play50th:
        ASSUME  ds:NOTHING
        mov     ax, cs
        mov     ds, ax
        ASSUME  ds:CODE
; Settaggio buffer
        les     di, [Buffer2Ptr]
        mov     ax, [Buffer2COfs]
        cmp     [OutBufferIdx], 0
        je      @@BufferOk
        les     di, [Buffer1Ptr]
        mov     ax, [Buffer1COfs]
@@BufferOk:
        xor     [OutBufferIdx], 1
        mov     [TempES], es
        mov     [TempDI], di
        mov     [TempCOfs], ax
        cld
; Inizio frame o sustain?
        cmp     [TempSpeed], 0
        je      @@FirstTick
        jmp     @@Sustain
@@FirstTick:
; Lettura note (copia nei rispettivi buffer)
        les     si, [ThisPatternPtr]
        mov     dx, [EMM_Handle]
        cmp     dx, EMM_NIL
        je      @@NoEMM1
        mov     ah, 47h                         ; EMM: save map contest
        int     67h
        mov     ax, [ThisPattern]
        mov     cl, 4
        shr     al, cl
        mov     bx, ax
        mov     ah, 44h                         ; EMM: map page
        mov     dx, [EMM_Handle]
        int     67h
@@NoEMM1:
; C'Š una nota da registrare?
        cmp     BYTE PTR [RecordNote], 0
        je      @@Continue
        mov     cx, WORD PTR [RecordNote]       ; Nota e sample in CX
        xor     dx, dx                          ; Comandi e info in DX
        mov     bx, [RecordTrack]
        mov     BYTE PTR [RecordNote], dl       ; Azzera la nota
        xchg    cx, es:[si+bx]
        xchg    dx, es:[si+bx+2]
@@Continue:
        mov     ax, es:TRACK_1[si]              ; Copia le note
        mov     WORD PTR [Track1].tNote, ax
        mov     ax, es:TRACK_1[si+2]
        mov     WORD PTR [Track1].tCommand, ax
        mov     ax, es:TRACK_2[si]
        mov     WORD PTR [Track2].tNote, ax
        mov     ax, es:TRACK_2[si+2]
        mov     WORD PTR [Track2].tCommand, ax
        mov     ax, es:TRACK_3[si]
        mov     WORD PTR [Track3].tNote, ax
        mov     ax, es:TRACK_3[si+2]
        mov     WORD PTR [Track3].tCommand, ax
        mov     ax, es:TRACK_4[si]
        mov     WORD PTR [Track4].tNote, ax
        mov     ax, es:TRACK_4[si+2]
        mov     WORD PTR [Track4].tCommand, ax
; La nota da registrare, se presente, Š in modo "test"?
        cmp     BYTE PTR [RecordFlag], 0
        je      @@DontMind
        xchg    es:[si+bx], cx                  ; Ripristina la nota corretta
        xchg    es:[si+bx+2], dx                ; Ripristina cmd e info
        mov     BYTE PTR [RecordFlag], 0        ; Azzera il flag
@@DontMind:
        mov     dx, [EMM_Handle]
        cmp     dx, EMM_NIL
        je      @@NoEMM2
        mov     ah, 48h                         ; EMM: restore map contest
        int     67h
@@NoEMM2:
; Calcolo sample in output
        mov     di, [TempCOfs]
        mov     si, OFFSET Track1
        call    PlayFirstTrack
        mov     di, [TempCOfs]
        mov     si, OFFSET Track2
        call    PlayMiddleTrack
        mov     di, [TempCOfs]
        mov     si, OFFSET Track3
        call    PlayMiddleTrack
        mov     di, [TempCOfs]
        mov     si, OFFSET Track4
        call    PlayLastTrack
	jmp	SHORT @@CheckPosition
@@Sustain:
        mov     di, [TempCOfs]
        mov     si, OFFSET Track1
        call    PlayFirstTrackSustain
        mov     di, [TempCOfs]
        mov     si, OFFSET Track2
        call    PlayMiddleTrackSustain
        mov     di, [TempCOfs]
        mov     si, OFFSET Track3
        call    PlayMiddleTrackSustain
        mov     di, [TempCOfs]
        mov     si, OFFSET Track4
        call    PlayLastTrackSustain
@@CheckPosition:
        mov     ax, [TempSpeed]
        inc     ax
        cmp     ax, [SongSpeed]
        jb      @@Exit
; Ricalcolo posizione
        mov     bl, [PosJumpFlag]
        xor     bh, bh
        cmp     bx, NONEWPOSITION
        jne     @@SetNext
        inc     [ThisFrame]
        cmp     [ThisFrame], 64
        jae     @@NextPattern
        cmp     [BreakFlag], 1
        je      @@NextPattern
	add	[ThisPatternOfs], 4
	xor	ax, ax
        jmp     SHORT @@Exit
@@NextPattern:
	mov	bx, [OrderIdx]
	inc	bx
@@SetNext:
        mov     [PosJumpFlag], NONEWPOSITION
        mov     [BreakFlag], 0
        mov     [ThisFrame], 0
        cmp     bx, [OrderMax]
	jb	@@Set
        mov     bx, [OrderMin]
@@Set:
	mov	[OrderIdx], bx
	shl	bx, 1
	mov	bx, Order[bx]
	mov	[ThisPattern], bx
	shl	bx, 1
	shl	bx, 1
        les     si, Pattern[bx]
        mov     [ThisPatternOfs], si
	mov	[ThisPatternSeg], es
	xor	ax, ax
@@Exit:
        mov     [TempSpeed], ax
        mov     ax, [TempES]
        shr     ah, 1
        shr     ah, 1
        shr     ah, 1
        shr     ah, 1
        mov     [BufferPage], ah                ; Pagina per il DMA
        mov     ax, [TempDI]
        mov     [BufferOffset], ax              ; Offset per il DMA
        mov     [BufferFlag], BUFFER_READY      ; Ok, buffer pronto
        ret

;------------------------------------------------------------
; Questa routine viene chiamata ogni 50-esimo di secondo dalla
; routine che gestisce l'interrupt del DMA, ed ha il compito di
; costruire il successivo blocco di dati da trasferire
ST_Play50thStereo:
        ASSUME  ds:NOTHING
        mov     ax, cs
        mov     ds, ax
        ASSUME  ds:CODE
; Settaggio buffer
        les     di, [Buffer2Ptr]
        mov     ax, [Buffer2COfs]
        cmp     [OutBufferIdx], 0
        je      @@BufferOk
        les     di, [Buffer1Ptr]
        mov     ax, [Buffer1COfs]
@@BufferOk:
        xor     [OutBufferIdx], 1
        mov     [TempES], es
        mov     [TempDI], di
        mov     [TempCOfs], ax
        cld
; Inizio frame o sustain?
        cmp     [TempSpeed], 0
        je      @@FirstTick
        jmp     @@Sustain
@@FirstTick:
; Lettura note (copia nei rispettivi buffer)
        les     si, [ThisPatternPtr]
        mov     dx, [EMM_Handle]
        cmp     dx, EMM_NIL
        je      @@NoEMM1
        mov     ah, 47h                         ; EMM: save map contest
        int     67h
        mov     ax, [ThisPattern]
        mov     cl, 4
        shr     al, cl
        mov     bx, ax
        mov     ah, 44h                         ; EMM: map page
        mov     dx, [EMM_Handle]
        int     67h
@@NoEMM1:
; C'Š una nota da registrare?
        cmp     BYTE PTR [RecordNote], 0
        je      @@Continue
        mov     cx, WORD PTR [RecordNote]       ; Nota e sample in CX
        xor     dx, dx                          ; Comandi e info in DX
        mov     bx, [RecordTrack]
        mov     BYTE PTR [RecordNote], dl       ; Azzera la nota
        xchg    cx, es:[si+bx]
        xchg    dx, es:[si+bx+2]
@@Continue:
        mov     ax, es:TRACK_1[si]              ; Copia le note
        mov     WORD PTR [Track1].tNote, ax
        mov     ax, es:TRACK_1[si+2]
        mov     WORD PTR [Track1].tCommand, ax
        mov     ax, es:TRACK_2[si]
        mov     WORD PTR [Track2].tNote, ax
        mov     ax, es:TRACK_2[si+2]
        mov     WORD PTR [Track2].tCommand, ax
        mov     ax, es:TRACK_3[si]
        mov     WORD PTR [Track3].tNote, ax
        mov     ax, es:TRACK_3[si+2]
        mov     WORD PTR [Track3].tCommand, ax
        mov     ax, es:TRACK_4[si]
        mov     WORD PTR [Track4].tNote, ax
        mov     ax, es:TRACK_4[si+2]
        mov     WORD PTR [Track4].tCommand, ax
; La nota da registrare, se presente, Š in modo "test"?
        cmp     BYTE PTR [RecordFlag], 0
        je      @@DontMind
        xchg    es:[si+bx], cx                  ; Ripristina la nota corretta
        xchg    es:[si+bx+2], dx                ; Ripristina cmd e info
        mov     BYTE PTR [RecordFlag], 0        ; Azzera il flag
@@DontMind:
        mov     dx, [EMM_Handle]
        cmp     dx, EMM_NIL
        je      @@NoEMM2
        mov     ah, 48h                         ; EMM: restore map contest
        int     67h
@@NoEMM2:
; Calcolo sample in output
        mov     di, [TempCOfs]
        mov     si, OFFSET Track1
        call    PlayFirstTrackStereo
        mov     di, [TempCOfs]
        mov     si, OFFSET Track4
        call    PlayLastTrackStereo
        mov     di, [TempCOfs]
        inc     di
        mov     si, OFFSET Track3
        call    PlayFirstTrackStereo
        mov     di, [TempCOfs]
        inc     di
        mov     si, OFFSET Track2
        call    PlayLastTrackStereo
	jmp	SHORT @@CheckPosition
@@Sustain:
        mov     di, [TempCOfs]
        mov     si, OFFSET Track1
        call    PlayFirstTrackStereoSus
        mov     di, [TempCOfs]
        mov     si, OFFSET Track4
        call    PlayLastTrackStereoSus
        mov     di, [TempCOfs]
        inc     di
        mov     si, OFFSET Track3
        call    PlayFirstTrackStereoSus
        mov     di, [TempCOfs]
        inc     di
        mov     si, OFFSET Track2
        call    PlayLastTrackStereoSus
@@CheckPosition:
        mov     ax, [TempSpeed]
        inc     ax
        cmp     ax, [SongSpeed]
        jb      @@Exit
; Ricalcolo posizione
        mov     bl, [PosJumpFlag]
        xor     bh, bh
        cmp     bx, NONEWPOSITION
        jne     @@SetNext
        inc     [ThisFrame]
        cmp     [ThisFrame], 64
        jae     @@NextPattern
        cmp     [BreakFlag], 1
        je      @@NextPattern
	add	[ThisPatternOfs], 4
	xor	ax, ax
        jmp     SHORT @@Exit
@@NextPattern:
	mov	bx, [OrderIdx]
	inc	bx
@@SetNext:
        mov     [PosJumpFlag], NONEWPOSITION
        mov     [BreakFlag], 0
        mov     [ThisFrame], 0
        cmp     bx, [OrderMax]
	jb	@@Set
        mov     bx, [OrderMin]
@@Set:
	mov	[OrderIdx], bx
	shl	bx, 1
	mov	bx, Order[bx]
	mov	[ThisPattern], bx
	shl	bx, 1
	shl	bx, 1
        les     si, Pattern[bx]
        mov     [ThisPatternOfs], si
	mov	[ThisPatternSeg], es
	xor	ax, ax
@@Exit:
        mov     [TempSpeed], ax
        mov     ax, [TempES]
        shr     ah, 1
        shr     ah, 1
        shr     ah, 1
        shr     ah, 1
        mov     [BufferPage], ah                ; Pagina per il DMA
        mov     ax, [TempDI]
        mov     [BufferOffset], ax              ; Offset per il DMA
        mov     [BufferFlag], BUFFER_READY      ; Ok, buffer pronto
        ret

PUBLIC ST_OnOffSpeaker
ST_OnOffSpeaker PROC FAR aOnOff:BYTE
        mov     al, 0D1h                        ; Speaker on
        cmp     [aOnOff], 0
        jne     @@Ok
        mov     al,0D3h                         ; Speaker off
@@Ok:
        call    Write_DSP
        ret
ST_OnOffSpeaker ENDP

; Attiva la riproduzione di un modulo con i dati precedentemente inseriti
PUBLIC ST_PlayModule
ST_PlayModule PROC FAR Handle:WORD
        ASSUME  ds:NOTHING
        mov     ax, [Handle]
        mov     [EMM_Handle], ax
        mov     ax, [OldIRQOfs]
        or      ax, [OldIRQSeg]
        jnz     @@Exit                          ; Gestore gi… istallato
        mov     [DMAHook], OFFSET ST_Play50th
        cmp     [DMA_initOfs], OFFSET DMA_Start
        je      @@Ok
        mov     [DMAHook], OFFSET ST_Play50thStereo
@@Ok:
        mov     [PlayMode], PLAY_MOD
        call    [DMA_initOfs]
@@Exit:
        ret
ST_PlayModule ENDP

MYMAXTICK       EQU     9
MyTickCount     DW      ?
OldTickOfs      DW      ?
OldTickSeg      DW      ?

MyTimer:
        inc     [MyTickCount]
        iret

; Disattiva l'eventuale processo di riproduzione in atto (modulo o "solo")
PUBLIC ST_Stop
ST_Stop PROC FAR
        ASSUME  ds:NOTHING
        mov     ax, [OldIRQOfs]
        or      ax, [OldIRQSeg]
        jz      @@Exit                          ; Gestore non istallato
; Istallazione "watchdog"
        mov     bx, 1Ch
        call    Get_Int_Vector
        mov     [OldTickOfs], ax
        mov     [OldTickSeg], dx
        mov     dx, cs
        mov     ax, OFFSET MyTimer
        mov     bx, 1Ch
        call    Set_Int_Vector
@@Sync1:
        cmp     [BufferFlag], BUFFER_READY
        jne     @@Sync1
        mov     [MyTickCount], 0
@@Sync2:
        mov     [BufferPage], NO_MORE_BLOCKS
        cmp     [MyTickCount], MYMAXTICK
        ja      @@Remove
        cmp     [BufferFlag], END_OF_DMA
        jne     @@Sync2                         ; Fine DMA non riconosciuta
@@Remove:
        mov     ax, [OldTickOfs]
        mov     dx, [OldTickSeg]
        mov     bx, 1Ch
        call    Set_Int_Vector
;
        cmp     [PlayMode], PLAY_MOD
        jne     @@Solo
        call    [DMA_doneOfs]
        jmp     @@Exit
@@Solo:
        call    DMA_End
@@Exit:
        mov     [DMAHook], OFFSET Default_DMAHook
        ret
ST_Stop ENDP

PUBLIC ST_GetInfo
ST_GetInfo PROC FAR aOrderPtr:DWORD, aPatternPtr:DWORD, aFramePtr:DWORD
        ASSUME  ds:NOTHING
        les     di, [aOrderPtr]
        mov     ax, [OrderIdx]
        mov     es:[di], ax
        les     di, [aPatternPtr]
        mov     ax, [ThisPattern]
        inc     ax
        mov     es:[di], ax
        les     di, [aFramePtr]
        mov     ax, [ThisFrame]
        mov     es:[di], ax
        ret
ST_GetInfo ENDP

SoloNote        DB      ?
SoloSample      DB      ?
SoloOfsLo       DW      ?
SolotOfs        DW      ?
SolotSeg        DW      ?
SolotEnd        DW      ?
SoloSampleIdx   DW      ?
SoloMask        DW      0FFFFh
SoloIncrHi      DW      ?
SoloIncrLo      DW      ?
SoloVolumeTable DB      256 DUP(?)

; Questa routine viene chiamata ogni 50-esimo di secondo dalla
; routine che gestisce l'interrupt del DMA, ed ha il compito di
; costruire il successivo blocco di dati da trasferire;
; differisce dalla precedente ST_Play50th perch‚ gestisce una
; sola nota per volta e quest'ultima Š selezionabile dall'esterno
ST_PlayNote50th:
        ASSUME  ds:CODE
        mov     ax, cs
        mov     ds, ax
; Settaggio buffer
        les     di, [Buffer2Ptr]
        cmp     [OutBufferIdx], 0
        je      @@BufferOk
        les     di, [Buffer1Ptr]
@@BufferOk:
        xor     [OutBufferIdx], 1
        mov     [TempES], es
        mov     [TempDI], di
        cld
; Calcolo nota
        mov     al, [SoloNote]
        or      al, al
        jz      @@Sustain
        mov     [SoloNote], 0
        mov     bl, al
        xor     bh, bh
        shl     bx, 1
        mov     ax, IncrHi[bx]
        mov     [SoloIncrHi], ax
        mov     ax, IncrLo[bx]
        mov     [SoloIncrLo], ax
; Settaggio sample
        mov     [SoloOfsLo], 0
        mov     bl, [SoloSample]
        xor     bh, bh
        shl     bx, 1
        mov     bx, dSamplesIdx[bx]
        mov     ax, [bx].sOfs
        mov     cx, [bx].sSeg
        mov     dx, [bx].sEnd
        mov     [SolotOfs], ax
        mov     [SolotSeg], cx
        mov     [SolotEnd], dx
        mov     [SoloSampleIdx], bx
@@Sustain:
        mov     ax, [SoloIncrLo]
        mov     [@@TempIncrLo], ax
        mov     ax, [SoloIncrHi]
        mov     [@@TempIncrHi], ax
        mov     cx, [OutBufferSize]
        mov     dx, [SolotEnd]
        mov     bp, [SoloOfsLo]
; !!! Controllare "SoloMask" !!!
        mov     bx, OFFSET SoloVolumeTable
        lds     si, DWORD PTR SolotOfs
        ASSUME  ds:NOTHING
@@Loop:
        mov     al, ds:[si]
        SEGCS
        xlat                            ; byte -> Volume[byte]
        xor     al, 128
        stosb
        DB      81h, 0C5h               ; add bp, TempIncrLo
@@TempIncrLo    DW      ?
        DB      81h, 0D6h               ; adc si, TempIncrHi
@@TempIncrHi    DW      ?
        cmp     si, dx
        jae     @@Repeat
@@EndLoop:
        loop    @@Loop
        mov     [SolotOfs], si
        mov     [SolotSeg], ds
        mov     [SolotEnd], dx
        mov     [SoloOfsLo], bp
        jmp     SHORT @@Exit
@@Repeat:
        mov     si, [SoloSampleIdx]
        mov     ds, cs:[si].sRepSeg
        mov     dx, cs:[si].sRepEnd
        mov     si, cs:[si].sRepOfs
        xor     bp, bp
        jmp     @@EndLoop
@@Exit:
        mov     ax, [TempES]
        shr     ah, 1
        shr     ah, 1
        shr     ah, 1
        shr     ah, 1
        mov     [BufferPage], ah                ; Pagina per il DMA
        mov     ax, [TempDI]
        mov     [BufferOffset], ax              ; Offset per il DMA
        mov     [BufferFlag], BUFFER_READY      ; Ok, buffer pronto
        ret

; Attiva la modalit… "solo": 1 voce pilotata dall'esterno
PUBLIC ST_PlaySolo
ST_PlaySolo PROC FAR
        ASSUME  ds:NOTHING
        mov     ax, [OldIRQOfs]
        or      ax, [OldIRQSeg]
        jnz     @@Exit                          ; Gestore gi… istallato
        mov     [DMAHook], OFFSET ST_PlayNote50th
        xor     ax, ax
        mov     [SoloIncrHi], ax
        mov     [SoloIncrLo], ax
        mov     [SoloOfsLo], ax
        mov     [SoloSample], al
        mov     al, 40h
        mov     bx, OFFSET SoloVolumeTable
        call    ST_SetSoloTrackVolume
        mov     [SoloNote], 10h
        mov     ax, WORD PTR dSamplesIdx[0]
        mov     [SoloSampleIdx], ax
        mov     dx, OFFSET NullData
        mov     cx, OFFSET NullData+NULLSAMPLELEN
        mov     [SolotOfs], dx
        mov     [SolotSeg], cs
        mov     [SolotEnd], cx
        mov     [PlayMode], PLAY_SOLO
        call    DMA_Start                       ; Riproduzione "mono"
@@Exit:
        ret
ST_PlaySolo ENDP

; Seleziona la nota per la ST_PlayNote50th
PUBLIC ST_SetSoloNote
ST_SetSoloNote PROC FAR aNote:BYTE, aSample:BYTE
        ASSUME  ds:NOTHING
        mov     ah, [aSample]
        and     ah, 00011111b
        mov     al, [aNote]
        cmp     al, 3Ch
        jbe     @@NoteOk
        cmp     al, 0FFh
        jne     @@NoteOk
        mov     al, [aSample]
        mov     bx, OFFSET SoloVolumeTable
        call    ST_SetSoloTrackVolume
        jmp     SHORT @@Exit
@@NoteOk:
        cli
        mov     [SoloNote], al
        mov     [SoloSample], ah
        sti
@@Exit:
        ret
ST_SetSoloNote ENDP

PUBLIC ST_GetPeaks
ST_GetPeaks PROC FAR aPeak12:DWORD, aPeak34:DWORD
        ASSUME  ds:NOTHING
        les     di, [aPeak12]
        mov     ah, Track1.tPeak
        and     ah, BYTE PTR Track1.tChannelMask
        mov     al, Track2.tPeak
        and     al, BYTE PTR Track2.tChannelMask
        mov     es:[di], ax
        les     di, [aPeak34]
        mov     ah, Track3.tPeak
        and     ah, BYTE PTR Track3.tChannelMask
        mov     al, Track4.tPeak
        and     al, BYTE PTR Track4.tChannelMask
        mov     es:[di], ax
        ret
ST_GetPeaks ENDP

RecordNote      DB      0
RecordSample    DB      ?
RecordTrack     DW      ?
RecordFlag      DB      0

PUBLIC ST_Record
ST_Record PROC FAR aNote:BYTE, aSample:BYTE, aTrack:BYTE, aFlag:BYTE
        ASSUME  ds:NOTHING
        mov     ah, [aTrack]
        cmp     ah, 3
        ja      @@Exit
        cmp     [aNote], 3Ch
        ja      @@Exit
        mov     al, [aFlag]             ; Flag rec/test
        mov     [RecordFlag], al
        xor     al, al
        mov     [RecordTrack], ax
        mov     al, [aSample]
        mov     [RecordSample], al
        mov     al, [aNote]
        mov     [RecordNote], al
@@Exit:
        ret
ST_Record ENDP

; Ritorna il puntatore all'ultimo buffer calcolato
PUBLIC ST_GetBuffer
ST_GetBuffer    PROC FAR
        ASSUME  ds:NOTHING
        mov     ax, cs:[Buffer1COfs]
        cmp     [OutBufferIdx], 0
        je      @@Exit
        mov     ax, cs:[Buffer2COfs]
@@Exit:
        mov     dx, cs
        ret
ST_GetBuffer    ENDP

END

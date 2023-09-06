(*
   Dr. Track
   Support for graphics in text mode
   CopyRight (c) 1991-1992,1993 Alessandro Scotti
*)
unit ST_Graph;
interface
{$define FULLACCESS}

const
  CHARWIDTH     = 8;
  CHARHEIGHT    : byte = 16;
  MAX_X         = 12;
  MAX_Y         = 3;
  stgValid      : boolean = FALSE;

procedure stgInit( CharList: string );
procedure stgDone;
procedure stgClear;
procedure stgShowAt( X, Y, A: byte );
procedure stgRefresh;
procedure stgSetPixel( X, Y: byte );

implementation uses Crt, Dos, ST_Win;

const
  PIXEL_MASK    : array[ 0..7 ] of byte = (128,64,32,16,8,4,2,1);
  InitFlag      : boolean = FALSE;
  (* Lista caratteri: la riga centrale e' ’∆‘÷”Ã◊Œÿ≈¡, che come si
     vede e' composta tutta da caratteri grafici che sono "aperti"
     verso destra. In modo testo la VGA usa per i caratteri una matrice
     9x16, anche se il font e' in realta' 8x16. La nona colonna e'
     vuota e ha funzione di separatore, in modo che e' possibile
     sfruttare tutte le prime otto colonne per i dati dei caratteri.
     Ma i caratteri speciali del tipo visto sopra devono potersi
     collegare tra loro senza interruzioni, quindi la VGA ottiene la
     nona colonna semplicemente duplicando l'ottava. Per l'utilizzo
     che se ne fa nel Dr. Track, la riga centrale e' la piu' importante,
     eventuali colonne vuote si noterebbero troppo! Una linea orizzontale
     verrebbe disegnata cosi'
     --------------
     nella riga composta da caratteri normali, e cosi'
     ƒƒƒƒƒƒƒƒƒƒƒƒƒƒ
     nella riga centrale. Ci sono altri caratteri speciali da utilizzare,
     ma bisogna lasciarne un po' per l'applicazione! *)
  DEFCHARLIST   = #250#230#248#247#246#245#244#243#242#241#229#226 +
                  #213#198#212#214#211#204#215#206#216#197#193#228 +
                  #240#239#238#237#236#235#234#233#232#231#227#225;
type
  TFontData = array[ 0..15 ] of byte;
  TFontChar = record
    Index   : integer;
    Data    : TFontData;
  end;
var
  BackScreen,
  Screen        : array[ 1..MAX_X, 1..MAX_Y ] of TFontChar;

procedure GetFontChar( Index: byte; var C: TFontChar );
var
  R: registers;
  P: ^byte;
begin
  R.AX := $1130;
  case CHARHEIGHT of
    8  : R.BH := $03;
    14 : R.BH := $02;
    16 : R.BH := $06;
  end;
  Intr( $10, R );
  C.Index := Index;
  Move( Ptr(R.ES,R.BP+Index*CHARHEIGHT)^, C.Data, CHARHEIGHT );
(* Nella VGA quando e' selezionato il set di caratteri 9x16, alcuni
   caratteri vengono ridefiniti rispetto al set 8x16. La funzione seguente
   ottiene l'indirizzo della tavola dei caratteri ridefiniti, strutturata
   come segue:
     byte   = indice del carattere (0=fine tabella)
     16 byte= dati del font del carattere
   Solo pochi caratteri vengono ridefiniti, e questa codifica permette di
   risparmiare spazio. Se il nostro carattere si trova nella tabella usiamo
   la definizione "alternativa" del font. *)
  if( CHARHEIGHT <> 16 ) then Exit;
  R.AX := $1130;
  R.BH := $07;
  Intr( $10, R );
  P := Ptr( R.ES, R.BP );
  while( P^ <> 0 ) do begin
    if( P^ = Index ) then begin
      Inc( P );
      Move( P^, C.Data, CHARHEIGHT );
      Exit;
    end;
    Inc( P, 17 );
  end;
end;

procedure SetFontChar( var C: TFontChar ); assembler;
asm
  push  ds

  mov   dx, $3C4
  mov   ax, $0402
  out   dx, ax
  mov   ax, $0704
  out   dx, ax
  mov   dx, $3CE
  mov   ax, $0406     (* Porta la memoria da $B800,32K ad $A000,64K *)
  out   dx, ax

  lds   si, [C]
  mov   ax, $A000
  mov   es, ax
  mov   di, ds:[si]
  mov   cl, 5
  shl   di, cl
  mov   cl, [CHARHEIGHT]
  xor   ch, ch
  shr   cx, 1
  inc   si
  inc   si
  cld
  rep   movsw

  mov   dx, $3C4
  mov   ax, $0302
  out   dx, ax
  mov   ax, $0304
  out   dx, ax
  mov   dx, $3CE
  mov   ax, $0E06     (* Ripristina la memoria a $B800,32K *)
  out   dx, ax

  pop   ds
end;

(* Disegna un punto *)
procedure stgSetPixel( X, Y: byte );
var
  CX, CY: byte;
begin
  CX := 1 + X shr 3;
  X := PIXEL_MASK[ X and 7 ];
  CY := 1+ Y div CHARHEIGHT;
  Y := Y mod CHARHEIGHT;
  Screen[ CX, CY ].Data[Y] := Screen[ CX, CY ].Data[Y] or X;
end;

(* Pulisce la finestra grafica *)
procedure stgClear;
var
  I, J: byte;
begin
  for I:=1 to MAX_X do
    for J:=1 to MAX_Y do
      FillChar( Screen[ I, J ].Data, SizeOf(TFontData), 0 );
end;

(* Aggiorna la finestra grafica, rendendo visibili i cambiamenti eventualmente
   operati con stgClear ed stgSetPixel. *)
procedure stgRefresh;
var
  I, J: byte;
begin
  if( not stgValid ) then Exit;
  I := MAX_X*MAX_Y;
  asm
    push  ds
    mov   ax, $A000
    mov   es, ax
    mov   si, OFFSET Screen

(* In modo testo la memoria viene utilizzata come segue:
   piano 0      : caratteri,
     "   1      : attributi,
   piani 2 e 3  : font.
   La scheda pero' si trova in un modo particolare, detto "odd/even", nel
   quale gli indirizzi pari vengono rediretti al piano 0 e quelli dispari
   al piano 1, cosicche' la memoria video assume la consueta configurazione
   a coppie carattere/attributo. In questa modalita' i piani 2 e 3 non
   sono accessibili.
   Per accedere a tutti i quattro piani dobbiamo essenzialmente disattivare
   il modo odd/even e abilitare in scrittura i piani desiderati. *)

    mov   dx, $3C4
    mov   ax, $0402     (* Abilita in scrittura il piano 2 *)
    out   dx, ax
    mov   ax, $0704     (* Disabilita il modo O/E *)
    out   dx, ax
    mov   dx, $3CE
{$ifdef FULLACCESS}
    mov   ax, $0204     (* Abilita in lettura il piano 2 *)
    out   dx, ax
    mov   ax, $0005     (* Attiva il write mode 0 *)
    out   dx, ax
{$endif}
    mov   ax, $0406     (* Porta la memoria da $B800,32K ad $A000,64K *)
    out   dx, ax
    cld

    mov   bl, [CHARHEIGHT]
    xor   bh, bh
    mov   dx, 16
    sub   dx, bx
    shr   bx, 1

@@Loop:
    mov   di, ds:[si]   (* In memoria video ogni carattere occupa *)
    mov   cl, 5         (* comunque 32 bytes *)
    shl   di, cl        (* ES:DI -> dati font carattere *)
    mov   cx, bx        (* Altezza effettiva carattere in word *)
    inc   si
    inc   si
    rep   movsw         (* Copia i dati da Screen alla memoria video *)
    add   si, dx        (* Passa al successivo carattere in Screen *)
    dec   [I]
    jnz   @@Loop

(* E ora bisogna rimettere le cose a posto *)
    mov   dx, $3C4
    mov   ax, $0302     (* Abilita in scrittura i piani 0 e 1 *)
    out   dx, ax
    mov   ax, $0304     (* Abilita il modo O/E *)
    out   dx, ax
    mov   dx, $3CE
{$ifdef FULLACCESS}
    mov   ax, $0004     (* Abilita in lettura il piano 0 *)
    out   dx, ax
    mov   ax, $1005     (* Attiva il write mode 1 *)
    out   dx, ax
{$endif}
    mov   ax, $0E06     (* Ripristina la memoria a $B800,32K *)
    out   dx, ax

    pop   ds
  end;
end;

procedure stgShowAt;
var
  I, J: byte;
begin
  if( not stgValid ) then Exit;
  for I:=1 to MAX_X do
    for J:=1 to MAX_Y do
      MemW[ Win_VIDEOSEG:(Y+J-1)*160+2*(X+I-1) ] := Screen[ I, J ].Index + word(A) shl 8;
end;

procedure stgInit;
var
  I, J, K: byte;
  R: registers;
begin
  if( not stgValid ) then Exit;
  R.AX := $1130;
  R.BH := 0;
  Intr( $10, R );
  CHARHEIGHT := R.CX;
  if( Length(CharList) < MAX_X*MAX_Y ) then
    CharList := DEFCHARLIST;
  K := 1;
  for J:=1 to MAX_Y do
    for I:=1 to MAX_X do begin
      GetFontChar( byte(CharList[K]), BackScreen[ I, J ] );
      Screen[ I, J ].Index := byte(CharList[K]);
      Inc( K );
    end;
  InitFlag := TRUE;
end;

procedure stgDone;
var
  I, J, K: byte;
begin
  if( not InitFlag ) then Exit;
  InitFlag := FALSE;
  for J:=1 to MAX_Y do
    for I:=1 to MAX_X do begin
      SetFontChar( BackScreen[ I, J ] );
    end;
end;

end.

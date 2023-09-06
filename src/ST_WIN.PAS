(*
   Dr. Track
   Windowing and screen functions
   CopyRight (c) 1991-1992,1993 Alessandro Scotti
*)
{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S-,V-,X+}

{$ifdef ST286}
{$G+}
{$else}
{$G-}
{$endif}

unit ST_Win;
interface uses Crt;

const
  Win_VIDEOSIZE  = 4000;
  Win_CRSOFF     = $2000;
  SINGLEBORDER   =  0;
  DOUBLEBORDER   =  1;
  NOBORDER       =  255;
  Win_CENTERTEXT =  1;
  Win_TOPLINE    =  2;
  Win_BOTTOMLINE =  4;
  Win_MDA        = 0;
  Win_CGA        = 1;
  Win_EGA        = 2;
  Win_VGA        = 3;
type
  Win_tScreen  = array[ 1..Win_VIDEOSIZE ] of byte;
  Win_tWindPtr = ^Win_tWindow;
  Win_tWindow  = record
                   CursX,
                   CursY,
                   Attr   : byte;
                   WMin,
                   WMax,
                   CSize  : word;
                   Screen : Win_tScreen;
                   Prev   : Win_tWindPtr
                 end;
var
  Win_vVideoPtr : pointer;
  Win_VideoType,
  Win_VIDEOSEG,
  Win_CRSON     : word;
  Win_StackPtr  : Win_tWindPtr;
  Win_TextRows  : byte absolute 0:$484;

procedure DisableEGABlinking;  (* Disabilita il blinking (EGA/VGA) *)
inline (
  $B8/$03/$10/        (* mov ax, $1003 *)
  $31/$DB/            (* xor bx, bx *)
  $CD/$10             (* int $10 *)
);

procedure EnableEGABlinking;  (* Riabilita il blinking *)
inline (
  $B8/$03/$10/        (* mov ax, $1003 *)
  $31/$DB/            (* xor bx, bx *)
  $43/                (* inc bx *)
  $CD/$10             (* int $10 *)
);

procedure MoveFromScreen( var Source, Dest; Count: word );
procedure MoveToScreen( var Source, Dest; Count: word );

procedure Win_Border( Border, Attr: byte );
procedure Win_Box( x1, y1, x2, y2, Border, Attr: byte );
procedure Win_Close;
function  Win_GetCursorSize: word;
procedure Win_GetScreen( var Screen: Win_tScreen );
procedure Win_OldTextMode;
procedure Win_Open( x1, y1, x2, y2, WAttr: byte );
procedure Win_PutScreen( var Screen: Win_tScreen );
procedure Win_SetCursorSize( Size: word );
procedure Win_Shadow( Attr: byte );
procedure Win_SetVideoSeg;
procedure Win_TextMode( Mode: word );
procedure Win_Title( Border, Attr, TitlePos: byte; Title: string );
procedure Win_TitledBox( x1, y1, x2, y2, Brd, A, TPos: byte; Title: string );
procedure Win_WriteAt( X, Y: byte; S: string; A: byte );

implementation

var
  Win_OldMode: integer;
  Win_OldAttr: byte;

procedure MoveFromScreen( var Source, Dest; Count: word ); external;
procedure MoveToScreen( var Source, Dest; Count: word ); external;
{$L MCMVSMEM}

procedure Win_GetScreen( var Screen: Win_tScreen );
begin
  MoveFromScreen( Win_vVideoPtr^, Screen, Win_VIDEOSIZE )
end;

procedure Win_PutScreen( var Screen: Win_tScreen );
begin
  MoveToScreen( Screen, Win_vVideoPtr^, Win_VIDEOSIZE )
end;

(* Apre una nuova finestra e la rende attiva *)
procedure Win_Open( x1, y1, x2, y2, WAttr: byte );
var P: Win_tWindPtr;
begin
  New( P );
  with P^ do begin
    CursX  := WhereX;
    CursY  := WhereY;
    Attr   := TextAttr;
    WMin   := WindMin;
    WMax   := WindMax;
    CSize  := Win_GetCursorSize;
    Win_GetScreen( Screen );
    Prev := Win_StackPtr
  end;
  Win_StackPtr := P;
  TextAttr := WAttr;
  Window( x1, y1, x2, y2 )
end;

(* Chiude la finestra attiva *)
procedure Win_Close;
var P: Win_tWindPtr;
begin
  P := Win_StackPtr;
  if( P <> NIL ) then begin
    with P^ do begin
      Window( Lo(WMin)+1, Hi(WMin)+1, Lo(WMax)+1, Hi(WMax)+1 );
      TextAttr := Attr;
      GotoXY( CursX, CursY );
      Win_SetCursorSize( CSize );
      Win_PutScreen( Screen );
      Win_StackPtr := Prev
    end;
    Dispose( P )
  end
end;

(* Prepara una stringa per la stampa diretta su video *)
function StrToVMem( var S: string; Attr: byte ): string;
begin
  asm
    push ds
    lds  si, S
    les  di, @Result
    cld
    lodsb
    and  al, 127
    mov  cl, al
    xor  ch, ch
    shl  al, 1
    stosb
    jcxz @Exit
    mov  ah, [Attr]
@Loop:
    lodsb
    stosw
    loop @Loop
@Exit:
    pop  ds
  end
end;

procedure GetCoords( var x1, y1, x2, y2, W, H: byte );
begin
  x1 := Lo(WindMin)+1;  y1 := Hi(WindMin)+1;
  x2 := Lo(WindMax)+1;  y2 := Hi(WindMax)+1;
  W := Succ( x2 - x1 );
  H := Succ( y2 - y1 )
end;

(* Ritorna il puntatore in memoria video alle coordinate specificate *)
function VPtr( X, Y: byte ): pointer;
begin
  VPtr := Ptr( Win_VIDEOSEG, Pred(Y)*160+Pred(X)*2 )
end;

procedure Win_WriteAt( X, Y: byte; S: string; A: byte );
var P: ^string;
begin
  S := StrToVMem( S, A );
  MoveToScreen( S[1], VPtr( X, Y )^, Length( S ) )
end;

procedure MyBorder( Border, Attr, TitleX: byte; Title: string; Top: boolean );
const Frames : array[ 0..3 ] of string[6] = (
                 'ÚÄ¿ÀÙ³', 'ÉÍ»È¼º', 'ÖÄ·Ó½º', 'ÕÍ¸Ô¾³'
               );
var I, W, H, x1, y1, x2, y2: byte;
    S, O: string;
    B: string[6];
    F: boolean;
begin
  GetCoords( x1, y1, x2, y2, W, H );
  B := Frames[ Border And 3 ];
  S[0] := Char( W );
  FillChar( S[1], W, B[2] );
  S[1] := B[1];
  S[W] := B[3];
  S := StrToVMem( S, Attr );
  Title := StrToVMem( Title, Attr );
  O := S;
  if( Title <> '' )and( Top ) then
    Move( Title[1], S[ TitleX*2+1 ], Length(Title) );
  MoveToScreen( S[1], VPtr( x1, y1 )^, W*2 );
  S := O;
  S[1] := B[4];
  S[W*2-1] := B[5];
  if( Title <> '' )and( Not Top ) then
    Move( Title[1], S[ TitleX*2+1 ], Length(Title) );
  MoveToScreen( S[1], VPtr( x1, y2 )^, W*2 );
  S := StrToVMem( B, Attr );
  for I:=Succ(y1) to Pred(y2) do begin
    MoveToScreen( S[11], VPtr( x1, I )^, 2 );
    MoveToScreen( S[11], VPtr( x2, I )^, 2 )
  end
end;

procedure Win_Shadow( Attr: byte );
const DEPTH = 2;
var I, W, H, x1, y1, x2, y2: byte;
    S: string;
begin
  GetCoords( x1, y1, x2, y2, W, H );
  if( y2 <= 24 ) then begin
    MoveFromScreen( Ptr( Win_VIDEOSEG, y2*160 )^, S[1], 160 );
    for I:=x1+DEPTH to x2+DEPTH do
      S[I*2] := char(Attr);
    MoveToScreen( S[1], Ptr( Win_VIDEOSEG, y2*160 )^, 160 )
  end;
  if( x2 <= 79 ) then for I:=y1 to y2 do begin
    MoveFromScreen( Ptr( Win_VIDEOSEG, I*160+x2*2 )^, S[1], DEPTH*2 );
    for W:=1 to DEPTH do
      S[W*2] := char(Attr);
    MoveToScreen( S[1], Ptr( Win_VIDEOSEG, I*160+x2*2 )^, DEPTH*2 )
  end
end;

procedure Win_Border( Border, Attr: byte );
begin
  MyBorder( Border, Attr, 0, '', TRUE )
end;

procedure Win_Title( Border, Attr, TitlePos: byte; Title: string );
begin
  MyBorder( Border, Attr, TitlePos, Title, TRUE )
end;

procedure MyBox( x1, y1, x2, y2, Border, Attr, TitlePos: byte; Title: string );
var X, Y, WMin, WMax: word;
begin
  X := WhereX;
  Y := WhereY;
  WMin := WindMin;
  WMax := WindMax;
  Window( x1, y1, x2, y2 );
  if( Title <> '' ) then
    Win_Title( Border, Attr, TitlePos, Title )
  else Win_Border( Border, Attr );
  Window( Lo(WMin)+1, Hi(WMin)+1, Lo(WMax)+1, Hi(WMax)+1 );
  GotoXY( X, Y )
end;

procedure Win_Box;
begin
  MyBox( x1, y1, x2, y2, Border, Attr, 0, '' )
end;

procedure Win_TitledBox;
begin
  MyBox( x1, y1, x2, y2, Brd, A, TPos, Title )
end;

function  Win_GetCursorSize: word;
begin
  asm
    push bp
    mov  ax, $0F00
    int  $10
    mov  ax, $0300
    int  $10
    pop  bp
    mov  @Result, cx
  end
end;

procedure Win_SetCursorSize( Size: word );
begin
  asm
    mov  cx, [Size]
    mov  ax, $0100
    push bp
    int  $10
    pop  bp
  end
end;

function IsVGA: boolean; assembler;
asm
  push bp
  mov  ax, $1A00
  int  $10
  pop  bp
  xor  ah, ah
  cmp  al, $1A
  jne  @@Exit
  inc  ah
@@Exit:
  mov  al, ah
end;

function IsEGA: boolean; assembler;
asm
  push bp
  mov  bh, 0
  mov  dl, $FF
  xor  cx, cx
  mov  ax, $1130
  int  $10
  pop  bp
  xor  ax, ax
  or   dl, dl
  js   @Exit
  or   cx, cx
  jz   @Exit
  inc  ax
@Exit:
  ret
end;

procedure Win_OldTextMode;
begin
  Win_TextMode( Win_OldMode );
  TextAttr := Win_OldAttr;
  ClrScr
end;

procedure Win_TextMode;
begin
  if( Mode <> LastMode ) then begin
    TextMode( Mode );
    Win_CRSON := Win_GetCursorSize
  end
  else begin
    Win_SetCursorSize( Win_CRSON );
    ClrScr
  end
end;

procedure Win_SetVideoSeg;
begin
  case Win_VideoType of
    Win_MDA : Win_VIDEOSEG := $B000;
    else      Win_VIDEOSEG := $B800
  end;
  Win_vVideoPtr := Ptr( Win_VIDEOSEG, 0 )
end;

begin
  Win_StackPtr := NIL;
  Win_OldAttr := TextAttr;
  Win_OldMode := LastMode;
  Win_CRSON   := Win_GetCursorSize;
  case Win_OldMode of
    MONO: Win_VideoType := Win_MDA;
    else  if( IsVGA ) then
            Win_VideoType := Win_VGA
          else if( IsEGA ) then
            Win_VideoType := Win_EGA
          else Win_VideoType := Win_CGA
  end;
  Win_SetVideoSeg
end.

(*
   Dr. Track
   Hypertext viewer
   CopyRight (c) 1992,1993 Alessandro Scotti
*)
{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S-,V-,X+}
{$ifdef ST286}
{$G+}
{$else}
{$G-}
{$endif}

unit ST_Hyper;
interface

{$I DRT.INC}

const
  H_NULL        = 0;

procedure ST_ShowHelp( Context: integer );
procedure HH_Init( FName: string );

implementation uses Crt, ST_Win, ST_Data;

const
  HH_X = 4;
  HH_Y = 3;
  HH_W = 73;
  HH_H = 20;

  HH_Pal: array[ 1..5 ] of byte = ( $3F, $30, $3E, $1E, $3F );
  HWIN    = 1;
  HTXT    = 2;
  HXREFLO = 3;
  HXREFHI = 4;
  HBOLD   = 5;

  (* Hypertext commands *)
  CMDNORMAL = #1;
  CMDLINK   = #2;
  CMDHOTLINK= #3;
  CMDBOLD   = #4;

const
  MAXREF   = 20;        (* Max crossreference number *)
  MAXSTACK = 20;        (* Max number of "last topic" entries *)
type
  PString = ^string;
  PTopic = ^TTopic;
  TTopic = record
    RefName: PString;                    (* Reference name *)
    Ref : word;                          (* Reference number *)
    TextLen: word;                       (* Length of text for this topic *)
    TextOfs: longint;                    (* Offset of text for this topic *)
    SeeNum : byte;                       (* Number of seealso entries *)
    SeeAlso: array[1..MAXREF] of word;   (* Seealso index *)
    Next   : PTopic;                     (* Next topic link *)
  end;
  PStrList = ^TStrList;                  (* Pointer to string array *)
  TStrList = array[ 1..1 ] of PString;   (* Dynamic string array *)
var
  HelpFile  : string;                   (* Help file name *)
  TopicList : PTopic;                   (* Topic list head *)
  TopicStack: array[ 1..MAXSTACK ] of word;  (* Last topic stack *)
  StackTop  : word;                          (* Last topic stack pointer *)
const
  HelpInited: boolean = FALSE;          (* Init flag *)
var
  CurSeeAlso: word;
  SeeAlsoY  : word;
  SeeAlsoX  : word;
  HyperPal  : array[ 0..4 ] of byte;

(* Saves a topic number into the stack *)
procedure PushTopic( Context: word );
begin
  if( StackTop < MAXSTACK ) then  (* Ok to push *)
    Inc( StackTop )
  else                            (* Discard oldest topic *)
    Move( TopicStack[2], TopicStack[1], (MAXSTACK-1)*SizeOf(word) );
  TopicStack[ StackTop ] := Context;
end;

(* Restores a topic number from the stack *)
function PopTopic: word;
begin
  if( StackTop >= 1 ) then begin
    PopTopic := TopicStack[ StackTop ];
    Dec( StackTop );
  end
  else PopTopic := 0;
end;

(* Allocates a dynamic string *)
function NewStr( S: string ): PString;
var P: PString;
begin
  GetMem( P, Length(S)+1 );
  P^ := S;
  NewStr := P
end;

(* Disposes a dynamic string *)
procedure DisposeStr( var P: PString );
begin
  FreeMem( P, Length(P^)+1 );
  P := NIL
end;

(* Creates a topic entry and adds it to the topic list *)
procedure TopicInit( NRefName: string;
                     NRef, NTextLen: word;
                     NTextOfs: longint );
var P: PTopic;
begin
  New( P );                             (* Create the entry *)
  with P^ do begin
    RefName := NewStr( NRefName );
    Ref := NRef;
    TextLen := NTextLen;
    TextOfs := NTextOfs;
    SeeNum := 0;
    Next := TopicList;                  (* Link to last topic *)
  end;
  TopicList := P;                       (* Update the topic list *)
end;

(* Hyperhelp system initialization *)
procedure HH_Init( FName: string );
var
  F             : file;
  RefName       : string;
  Len, Val, N   : word;
  FPos          : longint;
  P             : PTopic;
  Error         : boolean;
begin
  if( HelpInited )or( FName = '' ) then Exit;
  HelpFile := FName;
  TopicList := NIL;
  StackTop := 0;
  Assign( F, HelpFile );
  Reset( F, 1 );                        (* Open the help file *)
  if( IOResult <> 0 ) then Exit;

  BlockRead( F, FPos, 4, N );           (* Get directory offset *)
  Seek( F, FPos );                      (* Go to directory *)
  (* Create the topic list *)
  Error := FALSE;
  while( Not Eof( F ) )and( Not Error ) do begin
    BlockRead( F, RefName, 1, N );
    BlockRead( F, RefName[1], byte(RefName[0]), N );
    BlockRead( F, Val, 2, N );
    BlockRead( F, Len, 2, N );
    BlockRead( F, FPos, 4, N );
    Error := ( N <> 4 );
    if( not Error ) then begin
      TopicInit( RefName, Val, Len, FPos );
      BlockRead( F, Val, 2, N );          (* Get number of seealso *)
      while( Val > 0 )and( N = 2 ) do begin
        Inc( TopicList^.SeeNum );
        TopicList^.SeeAlso[TopicList^.SeeNum] := Val;  (* Add the seealso *)
        BlockRead( F, Val, 2, N );           (* Get next seealso (0=end) *)
      end;
      Error := ( N <> 2 );
    end;
  end;
  Close( F );                           (* Close the file *)
  HyperPal[0] := HH_Pal[HTXT];
  HyperPal[1] := HH_Pal[HTXT];
  HyperPal[2] := HH_Pal[HXREFLO];
  HyperPal[3] := HH_Pal[HXREFHI];
  HyperPal[4] := HH_Pal[HBOLD];
  HelpInited := not Error;                 (* Return *)
end;

(* Returns the pointer to the topic entry for a context *)
function GetTopic( Context: word ): PTopic;
var P: PTopic;
begin
  P := TopicList;
  while( P <> NIL ) do begin            (* Scan the topic list *)
    if( P^.Ref = Context ) then begin   (* Found? *)
      GetTopic := P;                    (* Yes, return it *)
      Exit;
    end
    else P := P^.Next;                  (* Search again *)
  end;
  GetTopic := NIL;                      (* Return failure *)
end;

function InitSeeAlso( L: PStrList; P: PTopic ): word;
begin
  CurSeeAlso := 0;
  if( P^.SeeNum = 0 ) then Exit;
  CurSeeAlso := 1;
  for SeeAlsoY := 1 to P^.TextLen do begin
    SeeAlsoX := Pos( CMDLINK, L^[SeeAlsoY]^ );
    if( SeeAlsoX > 0 ) then begin
      L^[SeeAlsoY]^[SeeAlsoX] := CMDHOTLINK;
      Exit;
    end;
  end;
end;

function NextSeeAlso( L: PStrList; P: PTopic ): boolean;
var
  S: string;
  B: byte;
begin
  NextSeeAlso := FALSE;
  if( CurSeeAlso >= P^.SeeNum ) then Exit;
  NextSeeAlso := TRUE;
  L^[ SeeAlsoY ]^[SeeAlsoX] := CMDLINK;
  B := Pos( CMDLINK, Copy(L^[SeeAlsoY]^,SeeAlsoX+1,80) );
  if( B > 0 ) then begin
    Inc( SeeAlsoX, B );
    L^[SeeAlsoY]^[SeeAlsoX] := CMDHOTLINK;
    Inc( CurSeeAlso );
    Exit;
  end;
  for SeeAlsoY := SeeAlsoY+1 to P^.TextLen do begin
    SeeAlsoX := Pos( CMDLINK, L^[SeeAlsoY]^ );
    if( SeeAlsoX > 0 ) then begin
      L^[SeeAlsoY]^[SeeAlsoX] := CMDHOTLINK;
      Inc( CurSeeAlso );
      Exit;
    end;
  end;
end;

function BackPos( C: char; L: word; var S: string ): byte;
var
  I: word;
begin
  I := L;
  while( I > 1 ) do
    if( S[I] = C ) then begin
      BackPos := I;
      Exit;
    end
    else Dec( I );
  BackPos := 0;
end;

function PrevSeeAlso( L: PStrList; P: PTopic ): boolean;
var
  S: string;
  B: byte;
begin
  PrevSeeAlso := FALSE;
  if( CurSeeAlso <= 1 ) then Exit;
  PrevSeeAlso := TRUE;
  L^[ SeeAlsoY ]^[SeeAlsoX] := CMDLINK;
  SeeAlsoX := BackPos( CMDLINK, SeeAlsoX-1, L^[SeeAlsoY]^ );
  if( SeeAlsoX > 0 ) then begin
    L^[SeeAlsoY]^[SeeAlsoX] := CMDHOTLINK;
    Dec( CurSeeAlso );
    Exit;
  end;
  for SeeAlsoY := SeeAlsoY-1 downto 1 do begin
    SeeAlsoX := BackPos( CMDLINK, byte(L^[SeeAlsoY]^[0]), L^[SeeAlsoY]^ );
    if( SeeAlsoX > 0 ) then begin
      L^[SeeAlsoY]^[SeeAlsoX] := CMDHOTLINK;
      Dec( CurSeeAlso );
      Exit;
    end;
  end;
end;

(* Writes a string with embedded color commands *)
procedure MyWriteAt( X, Y: byte; var S: string );
var
  T: string;
  I, A: byte;
begin
  A := HyperPal[1];
  asm
    push  ds
    lds   si, [S]
    mov   cl, ds:[si]
    xor   ch, ch
    inc   si
    push  ss
    pop   es
    lea   di, [T]
    mov   dx, di
    inc   di
    cld
    mov   ah, [A]
    jcxz  @@Done
  @@Loop:
    lodsb
    cmp   al, 32
    jae   @@Ok
    push  ds
    mov   bx, SEG @Data
    mov   ds, bx
    mov   bx, OFFSET HyperPal
    xlat
    pop   ds
    mov   ah, al
    jmp   @@Skip
  @@Ok:
    stosw
  @@Skip:
    loop  @@Loop
  @@Done:
    mov   cx, HH_W-2
    mov   bx, di
    sub   bx, dx
    shr   bx, 1
    sub   cx, bx
    jcxz  @@Exit
    mov   al, ' '
    rep   stosw
  @@Exit:
    pop   ds
  end;
  T[0] := char((HH_W-2)*2);
  MoveToScreen( T[1], Ptr(Win_VideoSeg,(X-1)*2+(Y-1)*160)^, Length(T) );
end;

function Hyper( L: PStrList; P: PTopic ): integer;
const
  PAGSIZE = HH_H-3;
var
  I     : word;
  C     : char;
  N     : word;
  A     : byte;
  Ref, R: word;
  Pag,
  MaxPag: word;
  S     : string[80];
  F     : boolean;
  SA    : PTopic;
begin
  S[0] := char( HH_W-2 );
  FillChar( S[1], HH_W-2, #205 );
  Win_WriteAt( HH_X+1, HH_Y, S, HH_Pal[HWIN] );
  S := ' ' + P^.RefName^ + ' ';
  Win_WriteAt( HH_X+(HH_W-Length(S)-2) shr 1, HH_Y, S, HH_Pal[HWIN] );
  Win_WriteAt( HH_X+1, HH_Y+1, Padded( '', HH_W-3 ), HH_Pal[HWIN] );
  Hyper := -1;
  Pag := P^.TextLen;                    (* Compute number of pages *)
  InitSeeAlso( L, P );
  F := FALSE;
  if( Pag <= PAGSIZE ) then
    MaxPag := 1
  else MaxPag := Pag-PAGSIZE+1;
  Pag := 1;
  Ref := 1;
  repeat
    (* Move to seealso reference *)
    if( F ) then begin
      while( SeeAlsoY > Pag+PAGSIZE-1 ) do Inc( Pag );
      while( SeeAlsoY < Pag )and( SeeAlsoY > 0 ) do Dec( Pag );
      F := FALSE;
    end;
    (* Write the seealso *)
    S := 'Current link: ';
    if( CurSeeAlso = 0 ) then
      S := S + 'none'
    else begin
      SA := GetTopic( P^.SeeAlso[CurSeeAlso] );
      S := S + SA^.RefName^;
    end;
    Win_WriteAt( HH_X+2, HH_Y+1, Padded(S,HH_W-3), HH_Pal[HTXT] );
    (* Write the text *)
    A := HH_Pal[HTXT];
    for I:=Pag to Pag+PAGSIZE-1 do begin
      if( I <= P^.TextLen ) then
        MyWriteAt( HH_X+2, HH_Y+3+I-Pag, L^[I]^ )
      else Win_WriteAt( HH_X+2, HH_Y+3+I-Pag, Padded( '', HH_W-2 ), A );
    end;

    S := 'อออ';
    if( Pag+PAGSIZE-1 < P^.TextLen ) then
      S[3] := #25;
    if( Pag > 1 ) then
      S[1] := #24;
    Win_WriteAt( HH_X+HH_W-1-Length(S), HH_Y+HH_H, S, HH_Pal[HWIN] );
    C := ReadKey;
    case C of
      #08 : begin Hyper := PopTopic; Exit; end;
      #09 : F := NextSeeAlso( L, P );
      #13 : if( CurSeeAlso > 0 ) then begin
              PushTopic( P^.Ref );    (* Save this topic *)
              Hyper := P^.SeeAlso[ CurSeeAlso ];
              Exit
            end;
      #27 : begin
              PushTopic( P^.Ref );
              Hyper := -1;
              Exit
            end;
      #00 : case byte(ReadKey) of
         15   : F := PrevSeeAlso( L, P );  (* Shift-Tab *)
        kF1   : begin
                  PushTopic( P^.Ref );
                  Hyper:=0;
                  Exit
                end;
        kDOWN : if( Pag < MaxPag ) then Inc( Pag );
        kUP   : if( Pag > 1 )      then Dec( Pag );
        kPGUP : for R:=1 to PAGSIZE do if( Pag > 1 ) then Dec( Pag );
        kPGDN : for R:=1 to PAGSIZE do if( Pag < MaxPag ) then Inc( Pag );
        kC_PGUP: Pag := 1;
        kC_PGDN: Pag := MaxPag;
        kA_F1 : begin
          Hyper := PopTopic;
          Exit;
        end;
      end
    end;
  until( C = #27 );
end;

(* Displays the help screen for a context *)
function HH_Help( var Context: integer ): word;
var
  P: PTopic;
  F: file;
  S: string;
  W: word;
  N: word;
  L: PStrList;
  HeapState: pointer;
begin
  HH_Help := HELP_NOT_FOUND;
  P := GetTopic( Context );     (* Get the topic entry *)
  if( P = NIL ) then            (* If not found, set it to "help on help" *)
    P := GetTopic( 0 );
  Assign( F, HelpFile );
  Reset( F, 1 );
  if( IOResult <> 0 ) then Exit;
  Seek( F, P^.TextOfs );        (* Get offset of text in file *)
  HH_Help := DISK_READ_ERROR;
  Mark( HeapState );            (* Record the state of the heap *)
  GetMem( L, P^.TextLen*SizeOf(PString) );  (* Get mem for text index *)
  for W:=1 to P^.TextLen do begin
    BlockRead( F, S, 1, N );
    if( N = 1 ) then begin
      BlockRead( F, S[1], byte(S[0]), N );
      if( N = byte( S[0] ) ) then N := 1;
    end;
    if( N <> 1 ) then begin
      Release( HeapState );     (* Release memory *)
      Close( F );
      Exit;
    end;
    L^[ W ] := NewStr( S );     (* Add a line of text *)
  end;
  Close( F );
  Context := Hyper( L, P );
  Release( HeapState );         (* Release memory *)
  HH_Help := 0;
end;

procedure ST_ShowHelp( Context: integer );
var
  E: word;
  S: string[HH_W+2];
  OldStatus: byte;
begin
  if( not HelpInited ) then begin
    PrintErrorMsg( HELP_NOT_FOUND );
    Exit;
  end;
  if( MaxRAM < 16*1024 ) then begin
    PrintErrorMsg( OUT_OF_MEMORY );
    Exit;
  end;
  OldStatus := LastStatus;
  ST_StatusLine( S_HELP );
  Win_Open( HH_X, HH_Y, HH_X+HH_W, HH_Y+HH_H, HH_Pal[HWIN] );
  ClrScr;
  Win_Border( DOUBLEBORDER, HH_Pal[HWIN] );
  Win_Shadow( $08 );
  S[0] := char( HH_W+1 );
  FillChar( S[2], HH_W-1, 'ฤ' );
  S[1] := 'ว';
  S[HH_W+1] := 'ถ';
  Win_WriteAt( HH_X, HH_Y+2, S, HH_Pal[HWIN] );
  Win_SetCursorSize( Win_CRSOFF );

  repeat
    E := HH_Help( Context );
    if( E <> 0 ) then begin
      PrintErrorMsg( E );
      Context := -1;
    end;
  until( Context < 0 );

  Win_Close;
  ST_StatusLine( OldStatus );
end;

end.

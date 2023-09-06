(*
   Dr. Track
   Keyboard management
   CopyRight (c) 1991-1992,1993 Alessandro Scotti
*)
{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S-,V-,X+}
unit ST_Keyb;
interface

var
  vMacroRec: boolean;

function Key_Pressed: boolean;
function Read_Key: char;

implementation uses ST_Data, ST_Edit, ST_Hyper;

const
  MACROLEN = 64;
  MACRONUM = 10;
  MACROHOT = $1312;
  ESCAPE   = $011B;
  kbF1     = $3B00;
type
  Macro = record
    Hot: word;
    Len: word;
    Buf: array[ 1..MACROLEN ] of word
  end;
var
  MDef : array[ 1..MACRONUM ] of Macro;
  MRec : word;
  MROfs: word;
  MPlay: word;
  MPOfs: word;

function Key2Def( Code: word ): word;
var I: word;
begin
  Key2Def := 0;
  for I:=1 to MACRONUM do
    if( MDef[I].Hot = Code ) then
       Key2Def := I
end;

procedure HandleHotKey;
label Loop;
var L, I, Code: word;
begin
  if( MRec = 0 ) then begin
    L := LastStatus;
    ST_StatusLine( S_MACROKEY );
    On_Message( 'Assign macro to what key ([Alt][0]..[9])?' );
Loop:
    asm
      xor  ax, ax
      int  $16
      mov  [Code], ax
    end;
    if( Code = kbF1 ) then begin
      ST_ShowHelp( hcMacroRec );
      goto Loop
    end
    else if( Code <> ESCAPE ) then begin
      I := Key2Def(Code);
      if( I > 0 ) then begin
        MRec := I;
        vMacroRec := TRUE;
        MROfs := 1
      end
      else goto Loop
    end;
    Off_Message;
    ST_StatusLine( L );
    Ed_MacroInfo
  end
  else begin
    MDef[MRec].Len := MROfs-1;  (* Stop macro *)
    MRec := 0;
    vMacroRec := FALSE;
    Ed_MacroInfo
  end
end;

procedure RecMacro( Code: word );
begin
  if( MRec > 0 ) then begin
    MDef[MRec].Buf[MROfs] := Code;
    Inc( MROfs );
    if( MROfs > MACROLEN ) then begin
      MDef[MRec].Len := MACROLEN;  (* Stop automatico macro *)
      MRec := 0;
      vMacroRec := FALSE;
      Ed_MacroInfo
    end
  end
end;

function PlayMacro( Code: word ): boolean;
var I: word;
begin
  PlayMacro := FALSE;
  I := Key2Def( Code );
  if( I > 0 ) then begin
    PlayMacro := TRUE;
    if( MDef[I].Len > 0 ) then begin
      MPlay := I;
      MPOfs := 1;
      PlayMacro := TRUE
    end
  end
end;

procedure InitMacro;
var I: word;
begin
  for I:=1 to MACRONUM do begin
    MDef[I].Len := 0;
    MDef[I].Hot := $7700 + I shl 8
  end;
  vMacroRec := FALSE;
  MRec := 0;
  MPlay:= 0
end;

const
  Buf : char = #0;

function Key_Pressed: boolean;
begin
  Key_Pressed := TRUE;
  if( MPlay = 0 )and( Buf = #0 ) then asm
    mov   ah, 1
    int   $16
    jnz   @Ok
    mov   [@Result], 0
@Ok:
  end
end;

function Read_Key: char;
label
  Loop;
var
  Code: word;
begin
Loop:
  if( Buf <> #0 ) then begin
    Read_Key := Buf;
    Buf := #0
  end
  else begin
    if( MPlay > 0 ) then begin
      Code := MDef[MPlay].Buf[MPOfs];
      Inc( MPOfs );
      if( MPOfs > MDef[MPlay].Len ) then
        MPlay := 0
    end
    else begin
      asm
        xor  ax, ax
        int  $16
        mov  [Code], ax
      end;
      if( Code = MACROHOT ) then begin
        HandleHotKey;
        goto Loop
      end
      else if( PlayMacro( Code ) ) then
        goto Loop
    end;
    RecMacro( Code );
    if( Lo(Code) = 0 ) then begin
      Read_Key := #0;
      Buf := char( Hi(Code) )
    end
    else Read_Key := char( Lo(Code) )
  end
end;

begin
  InitMacro
end.

(*
   Dr. Track
   Soundblaster Pro interface
   CopyRight (c) 1991-1992,1993 Alessandro Scotti
*)
unit ST_SBpro;
interface

const
  sbp_DACVOL    = $04;
  sbp_MASTERVOL = $22;

var
  SBC_IsPro: boolean;

function SB_ReadMixer( Reg: byte ): byte;
procedure SB_WriteMixer( Reg, Val: byte );
procedure SB_SetVolume( Reg, Vol: byte );
function SB_GetVolume( Reg: byte ): byte;
function SBC_DetectPro: boolean;

procedure SBP_SetSTVolume;

implementation uses Sbc, Crt, ST_Win, ST_Data;

function SB_ReadMixer( Reg: byte ): byte;
begin
  Port[ SBC_Port+4 ] := Reg;
  SB_ReadMixer := Port[ SBC_Port+5 ];
end;

procedure SB_WriteMixer( Reg, Val: byte );
begin
  Port[ SBC_Port+4 ] := Reg;
  Port[ SBC_Port+5 ] := Val;
end;

procedure SB_SetVolume( Reg, Vol: byte );
begin
  Vol := (Vol and $07) shl 1;
  Vol := (Vol shl 4) or Vol;
  SB_WriteMixer( Reg, Vol );
end;

function SB_GetVolume( Reg: byte ): byte;
begin
  SB_GetVolume := ( SB_ReadMixer( Reg ) and $0F ) shr 1;
end;

function SBC_DetectPro: boolean;
var
  Old, New: byte;
begin
  Old := SB_GetVolume( $22 );
  New := not( Old ) and $07;
  SB_SetVolume( $22, New );
  SBC_DetectPro := ( SB_GetVolume( $22 ) = New );
  SB_SetVolume( $22, Old );
end;

const
  WX = 30;
  WY = 5;
  MAXVOL = 7;
  ATTR = LightMagenta+16*Magenta;
  HIATTR = White+16*Magenta;
  LOATTR = LightGray+16*Magenta;
var
  Volume: array[ 0..1 ] of record
    Vol: byte;
    Old: byte;
    Name: string[8];
  end;
{$I KEYCODES.INC}

procedure SBP_SetSTVolume;
const
  V: byte = 0;
var
  I, J, A: word;
  C: char;
  OS: byte;
  LF: byte;
  F: byte;
procedure SetV( Vol: byte );
begin
  Volume[V].Vol := Vol;
  if( V = 0 ) then
    SB_SetVolume( sbp_MASTERVOL, Vol )
  else SB_SetVolume( sbp_DACVOL, Vol );
end;
begin
  if( Not SBC_IsPro ) then begin
    PrintErrorMsg( NOT_SBPRO );
    Exit;
  end;
  Win_Open( WX, WY, WX+17, WY+15, ATTR );
  Win_SetCursorSize( Win_CrsOff );
  ClrScr;
  Win_Shadow( $08 );
  Win_Border( DOUBLEBORDER, ATTR );
  OS := LastStatus;
  ST_StatusLine( S_SETVOL );
  Win_WriteAt( WX+3, WY, ' SB Control ', ATTR );
  Win_WriteAt( WX+3, WY+12, 'F', HIATTR );
  Win_WriteAt( WX+4, WY+12, ')ilter:', LOATTR );
  Win_WriteAt( WX+3, WY+13, 'S', HIATTR );
  Win_WriteAt( WX+4, WY+13, ')tereo:', LOATTR );

  F := SB_ReadMixer( $0E );
  LF := F;
  with Volume[0] do begin
    Vol := SB_GetVolume( sbp_MASTERVOL );
    Old := Vol;
    Name := 'Master';
  end;
  with Volume[1] do begin
    Vol := SB_GetVolume( sbp_DACVOL );
    Old := Vol;
    Name := 'DAC';
  end;

  repeat
    for I:=0 to 1 do begin
      if( I = V ) then
        A := HIATTR
      else A := LOATTR;
      Win_WriteAt( WX+3+I*8, WY+2, Volume[I].Name, A );
      for J:=0 to MAXVOL do
        if( J <> Volume[I].Vol ) then
          Win_WriteAt( WX+5+I*7, WY+MAXVOL+3-J, 'º', A )
        else Win_WriteAt( WX+5+I*7, WY+MAXVOL+3-J, 'Û', A );
    end;
    if( F and 32 = 0 ) then
      Win_WriteAt( WX+12, WY+12, 'on ', LOATTR )
    else Win_WriteAt( WX+12, WY+12, 'off', LOATTR );
    if( F and 2 = 0 ) then
      Win_WriteAt( WX+12, WY+13, 'off', LOATTR )
    else Win_WriteAt( WX+12, WY+13, 'on ', LOATTR );
    C := ReadKey;
    case C of
      'f','F' : begin
                  F := F xor 32;
                  SB_WriteMixer( $0E, F );
                end;
      's','S' : begin
                  F := F xor 2;
                  SB_WriteMixer( $0E, F );
                end;
      '0'..'7': SetV( byte(C)-48 );
      #09: V := 1-V;
      #00: case byte( ReadKey ) of
        kUP   : if( Volume[V].Vol < MAXVOL ) then SetV( Volume[V].Vol+1 );
        kDOWN : if( Volume[V].Vol > 0 ) then SetV( Volume[V].Vol-1 );
        kLEFT,
        kRIGHT: V := 1-V;
        kEND  : SetV( 0 );
        kHOME : SetV( MAXVOL );
      end;
    end;
  until( C in [#27,#13] );
  Win_Close;
  if( C = #27 ) then begin
    SB_WriteMixer( $0E, LF );
    SB_SetVolume( sbp_MASTERVOL, Volume[0].Old );
    SB_SetVolume( sbp_DACVOL, Volume[1].Old );
  end;
  ST_StatusLine( OS );
end;

end.
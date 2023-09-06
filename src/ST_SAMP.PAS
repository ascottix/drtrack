(*
   Dr. Track
   Samples management
   CopyRight (c) 1991-1992,1993 Alessandro Scotti
*)
{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S-,V-,X+}

{$ifdef ST286}
{$G+}
{$else}
{$G-}
{$endif}

unit ST_Samp;
interface

procedure SA_NewSong;
procedure Edit_Samples;
procedure SA_SetColors( Video: byte );
procedure ST_SetPosVars( var Page, Y: byte; PageLen, Max: byte );

implementation uses Crt, ST_Dir,
                    ST_Graph,
                    ST_Win, ST_Data, ST_File, ST_Play, ST_Hyper;

const
  MAXCOLOR = 7;
  SA_Palette: array[ 1..MAXCOLOR ] of byte = (
    $07, $03, $01, $03, $3F, $01, $13
  );
  LISTEDIT  = 7;
  LISTFRAME = 6;
  HILIST    = 5;
  LIST      = 4;
  INFOFRAME = 3;
  HIINFO    = 2;
  INFO      = 1;

  SA_LISTLEN : byte = 12;
  INFOX      = 15;
  INFOY      : byte = 3;
  LISTX      = 25;
  LISTY      : byte = 12;
var
  vPage: byte;
  vCurY: byte;

function SA_CheckPlay( C: char; Sample: byte ): boolean;
var
  N: byte;
begin
  SA_CheckPlay := FALSE;
  if( C = ' ' )or( C = ^K )or( C = '\' ) then begin
    ST_SetSoloNote( $11, 0 );
    SA_CheckPlay := TRUE
  end
  else begin
    N := ST_KeyToNote( C );
    if( N > 0 ) then begin
      ST_SetSoloNote( N, Sample );
      SA_CheckPlay := TRUE
    end
  end
end;

procedure SA_InitPlay;
begin
  ST_SetupSamples;
  ST_SetMasterVolume( vMasterVolume );
  ST_PlaySolo;
end;

procedure ST_SetPosVars( var Page, Y: byte; PageLen, Max: byte );
begin
  while( Y >= PageLen ) do begin
    Inc( Page );
    Dec( Y )
  end;
  while( Page+PageLen > Max ) do begin
    Dec( Page );
    Inc( Y )
  end;
  if( Y >= PageLen ) then
    Y := PageLen-1;
end;

procedure SA_SetScreen;
var A: byte;
    S: string;
begin
  if( Ega43 ) then begin
    INFOY      := 5;
    LISTY      := 16;
    SA_LISTLEN := 24;
    if( Win_TextRows > 42 ) then
      SA_LISTLEN := 31
  end
  else begin
    SA_LISTLEN := 12;
    INFOY      := 3;
    LISTY      := 12
  end;
  ST_SetPosVars( vPage, vCurY, SA_LISTLEN, MAXSAMPLE );
  S := COPYRIGHTMSG;
  Win_SetCursorSize( Win_CRSOFF );
  S := Spaces( (80-Length(S)) div 2 ) + S;
  Win_WriteAt( 1, 1, Padded( S, 80 ), COPYRIGHTATTR );
  A := SA_Palette[INFO];
  Win_Box( INFOX, INFOY-1, INFOX+51, INFOY+7,
           DOUBLEBORDER, SA_Palette[INFOFRAME] );
  Win_WriteAt( INFOX+2, INFOY,   '         Name:', A );
  Win_WriteAt( INFOX+2, INFOY+1, ' DOS filename:', A );
	Win_WriteAt( INFOX+2, INFOY+2, 'DOS directory:', A );
  Win_WriteAt( INFOX+2, INFOY+3, '       Length:', A );
  Win_WriteAt( INFOX+2, INFOY+4, ' Repeat start:', A );
  Win_WriteAt( INFOX+2, INFOY+5, 'Repeat length:', A );
  Win_WriteAt( INFOX+2, INFOY+6, '       Volume:', A );
  Win_Box( LISTX, LISTY-1, LISTX+31, LISTY+SA_LISTLEN,
           DOUBLEBORDER, SA_Palette[LISTFRAME] );
  VLine( LISTX+5, LISTY-1, LISTY+SA_LISTLEN, SA_Palette[LISTFRAME], '—œ≥' );
  if( stgValid ) then begin
    VLine( INFOX+48-MAX_X, INFOY+3, INFOY+7, SA_Palette[INFOFRAME], '… ∫' );
    S[0] := char(MAX_X-5);
    FillChar( S[1], byte(S[0]), 'Õ' );
    Win_WriteAt( INFOX+49-MAX_X, INFOY+3, 'Õ      '+S+'π', SA_Palette[INFOFRAME] );
    Win_WriteAt( INFOX+51-MAX_X, INFOY+3, 'Wave', A );
  end;
end;

procedure SA_WriteInfo( Index: byte );
var
  A: byte;
  I, J, K, L: word;
  P: ^byte;
begin
  A := SA_Palette[HIINFO];
  with aSample[Index] do begin
    Win_WriteAt( INFOX+17, INFOY,   Padded( Name, 24 ), A );
    Win_WriteAt( INFOX+17, INFOY+1, Padded( FileName, 14 ), A );
    Win_WriteAt( INFOX+17, INFOY+2, Padded( PathName, MAXPATHLEN+2 ), A );
    Win_WriteAt( INFOX+17, INFOY+3, Padded( w2s(Len), 7 ), A );
    Win_WriteAt( INFOX+17, INFOY+4, Padded( w2s(RepStart), 7 ), A );
    Win_WriteAt( INFOX+17, INFOY+5, Padded( w2s(RepLen), 7 ), A );
    Win_WriteAt( INFOX+17, INFOY+6, Padded( w2s(Volume), 4 ), A );
    stgClear;
    if( Address <> NIL ) then begin
      K := Len div (MAX_X*8);
      J := CHARHEIGHT*MAX_Y shr 1;
      P := Address;
      for I:=0 to (MAX_X*8)-1 do begin
        for L:=0 to (P^ xor 128) * J div 256 do begin
          stgSetPixel( I, J+L );
          stgSetPixel( I, J-L );
        end;
        Inc( P, K );
      end;
    end;
    stgRefresh;
    stgShowAt( INFOX + 49-MAX_X, INFOY+3, LightGreen+$80 );
  end;
end;

procedure SA_WriteItem( Y, Num, Attr: byte );
var S: string[4];
begin
  S := ' nn ';
  S[2] := char( Num div 10 + 48 );
  S[3] := char( Num mod 10 + 48 );
  if( Not aSample[Num].Saved )and( aSample[Num].Address <> NIL ) then begin
    S[1] := #249;
    S[4] := #249
  end;
  Win_WriteAt( LISTX+1, LISTY+Y, S, Attr );
  Win_WriteAt( LISTX+6, LISTY+Y, ' '+Padded( aSample[Num].Name, 24 ), Attr )
end;

procedure SA_WriteList( HighAttr: byte );
var I: byte;
begin
  for I:=0 to SA_LISTLEN-1 do
    if( I = vCurY ) then
      SA_WriteItem( I, I+vPage+1, HighAttr )
    else SA_WriteItem( I, I+vPage+1, SA_Palette[LIST] )
end;

function SA_WordEdit( Index, Y, A, MAXLEN: byte; var WC: word; Step, Min, Max, Help: word; VolFlag: boolean ): byte;
var W: word;
    S: string[8];
    C: char;
    X, BIGSTEP, I, R: byte;
begin
  BIGSTEP := Step*16;
  W := WC;
  R := 0;
  repeat
    with aSample[Index] do
      if( VolFlag ) then begin
        ST_SetSample( Index, Address, Len, RepStart, RepLen, Lo(WC) );
        ST_SetSoloNote( $FF, Lo(WC) )
      end
      else ST_SetSample( Index, Address, Len, RepStart, RepLen, Volume );
    Str( WC:MAXLEN, S );
    S := S + ' ';
    Win_WriteAt( INFOX+17, INFOY+Y, S, A );
    C := ReadKey;
    if( Not SA_CheckPlay( C, Index ) ) then case C of
      #13 : R := 1;
      #27 : R := 2;
      #09 : R := 3;
      '-' : if( WC > Min ) then Dec( WC, Step );
      '+' : if( WC < Max ) then Inc( WC, Step );
      #00 : case byte(ReadKey) of
              kF1     : ST_ShowHelp( Help );
              kLEFT   : if( WC > Min ) then Dec( WC, Step );
              kRIGHT  : if( WC < Max ) then Inc( WC, Step );
              kC_LEFT : for I:=1 to BIGSTEP do
                          if( WC > Min ) then Dec( WC );
              kC_RIGHT: for I:=1 to BIGSTEP do
                          if( WC < Max ) then Inc( WC );
              kDOWN   : R := 101;
              kUP     : R := 102;
              kHOME   : WC := Min;
              kEND    : WC := Max
            end
    end
  until( R > 0 );
  if( R in [1,3,101,102] )and( WC <> W ) then
    aSample[Index].Saved := FALSE
  else if( R = 3 ) then
    WC := W;
  with aSample[Index] do
    if( VolFlag ) then
      ST_SetSample( Index, Address, Len, RepStart, RepLen, Lo(WC) )
    else ST_SetSample( Index, Address, Len, RepStart, RepLen, Volume );
  SA_WordEdit := R
end;

function MyLineEdit( Index, Y, A, Max: byte; var S: string; Cmd: string; Help: word ): byte;
var T: string;
begin
  T := S;
  MyLineEdit := ST_LineEdit( INFOX+17, INFOY+Y, Max+2, Max, S, Cmd, Help );
  if( S <> T ) then
    aSample[Index].Saved := FALSE
end;

const
  mMAXVOLUME = 0;

procedure ModifySample( Index, Func: byte );
type
  MySamp = array[ 1..65535 ] of shortint;
  MyPtr  = ^MySamp;
var
  P: MyPtr;
  L: word;
procedure MaxVolume;
var M: integer;
    I: word;
begin
  M := 0;
  for I:=1 to L do
    if( Abs( P^[I] ) > M ) then
      M := Abs( P^[I] );
  if( M <= 127 ) then
    for I:=1 to L do
      P^[I] := shortint( integer( P^[I] ) * 127 div M )
end;
begin
  if( aSample[Index].Address <> NIL ) then begin
    P := MyPtr( aSample[Index].Address );
    L := aSample[Index].Len;
    ST_Stop;
    case Func of
      mMAXVOLUME: MaxVolume;
    end;
    SA_InitPlay
  end
end;

procedure SA_Edit( I: byte );
type Status = (
  sNull, sSong, sFile, sPath, sRepSt, sRepLen, sVolume, sExit );
var S: Status;
    A: byte;
    Lib,
    Cmd: string;
    W: word;
procedure MySave;
  begin
    ST_Stop;
    if( F_SaveSample( I ) ) then
      S := sExit;
    SA_InitPlay
  end;
begin
  Cmd := #13+'S'+#27+'E'+#09+'S|'+
         char(kDOWN)+'S'+char(kUP)+'S'+char(kA_S)+'S';
  S := sSong;
  A := SA_Palette[LISTEDIT];
  while( S <> sExit ) do begin
    SA_WriteInfo( I );
    SA_WriteList( SA_Palette[HILIST] and $0F );
    if( S = sPath ) then
      ST_StatusLine( S_SPATHEDIT )
    else ST_StatusLine( S_SEDIT );
    case S of
      sSong : case MyLineEdit( I, 0, A, 22,
              aSample[I].Name, Cmd, hcSampNameEd ) of
                1, 101 : S := sFile;
                2, 3   : S := sExit;
                102    : S := sVolume;
                103    : MySave
              end;
      sFile : case MyLineEdit( I, 1, A, 12,
              aSample[I].FileName, '@'+Cmd, hcSampFileEd ) of
                1, 101 : S := sPath;
                2, 3   : S := sExit;
                102    : S := sSong;
                103    : MySave
              end;
      sPath : begin
                case MyLineEdit( I, 2, A, MAXPATHLEN, aSample[I].PathName,
                '@'+Cmd+char(kA_D)+'E'+char(kA_B)+'S', hcSampDirEd ) of
                  1, 101 : S := sRepSt;
                  2, 3   : S := sExit;
                  102    : S := sFile;
                  103    : MySave;
		  104 	 : aSample[I].PathName := vSampDir;
                  105    : begin
                             Lib := GF_GetLibrary;
                             if( Lib <> '' ) then
                               aSample[I].PathName := '='+Copy(Lib,3,MAXPATHLEN-1)
                           end
                end
              end;
      sRepSt: case SA_WordEdit( I, 4, A, 6, aSample[I].RepStart, 2, 0,
              aSample[I].Len-aSample[I].RepLen, hcSampRepEd, FALSE ) of
                1, 101 : S := sRepLen;
                2, 3   : S := sExit;
                102    : S := sPath;
                103    : MySave
              end;
      sRepLen:case SA_WordEdit( I, 5, A, 6, aSample[I].RepLen, 2, 2,
              aSample[I].Len-aSample[I].RepStart, hcSampRepEd, FALSE ) of
                1, 101 : S := sVolume;
                2, 3   : S := sExit;
                102    : S := sRepSt;
                103    : MySave
              end;
      sVolume:begin
                W := aSample[I].Volume;
                case SA_WordEdit( I, 6, A, 3, W, 1, 1, 64,
                hcSampVolEd, TRUE ) of
                  1, 2, 3: S := sExit;
                  101    : S := sSong;
                  102    : S := sRepLen;
                  103    : MySave
                end;
                aSample[I].Volume := Lo(W)
              end
    end
  end
end;

procedure SaveAllSamples;
label Exit;
var I, OP, OY: byte;
begin
  OP := vPage;
  OY := vCurY;
  vPage := 0;
  vCurY := 0;
  for I:=1 to 31 do begin
    ST_StatusLine( S_WORK );
    SA_WriteList( SA_Palette[HILIST] );
    SA_WriteInfo( I );
    if( vCurY < SA_LISTLEN-1 ) then
      Inc( vCurY )
    else Inc( vPage );
    if( aSample[I].Address <> NIL ) then
      if( Not F_SaveSample( I ) ) then
        goto Exit
  end;
Exit:
  vPage := OP;
  vCurY := OY
end;

procedure MyClearSamples;
var F: boolean;
    I: byte;
begin
  On_Message( 'Clear samples (Y/n)?' );
  if( GetAnswer in [rYes,rEnter] ) then begin
    ST_Stop;
    DoClearSamples;
    SA_NewSong;
    SA_InitPlay
  end;
  Off_Message
end;

function CheckSave( Index: byte ): ReturnType;
var S: string[80];
begin
  if( aSample[Index].Address = NIL )or( aSample[Index].Saved ) then
    CheckSave := rYes
  else begin
    Str( Index, S );
    S := 'Warning: sample #' + S + ' has not been saved, proceed (Y/n)?';
    On_Message( S );
    CheckSave := GetAnswer;
    Off_Message
  end
end;

procedure Edit_Samples;
var I, Y, OP, OY: byte;
    E: word;
    C: char;
    R: ReturnType;
procedure Redraw;
  begin
    OP := 255
  end;
procedure HandleIO( Command, Index: byte );
  begin
    ST_Stop;
    case Command of
      kA_S : F_SaveSample( Index );  (* Compilare con $X+! *)
      kA_B,
      kA_L : if( CheckSave( Index ) in [rYes,rEnter] ) then
               F_LoadSample( Index, Command = kA_B );
      kA_A : SaveAllSamples
    end;
    SA_InitPlay;
    Redraw
  end;
procedure DoneGraph;
  var I: byte;
  begin
    for I:=INFOY+4 to INFOY+6 do
      Win_WriteAt( INFOX+50-MAX_X, I, Spaces(MAX_X), $80 );
    stgDone;
  end;
begin
  stgInit( '' );
  SA_InitPlay;
  SA_SetScreen;
  Redraw;
  repeat
    Y := vPage+vCurY+1;
    ST_StatusLine( S_SAMPLE );
    if( OP <> vPage ) then
      SA_WriteList( SA_Palette[HILIST] )
    else if( OY <> vCurY ) then begin
      SA_WriteItem( OY, OP+OY+1, SA_Palette[LIST] );
      SA_WriteItem( vCurY, vPage+vCurY+1, SA_Palette[HILIST] )
    end;
    OP := vPage;
    OY := vCurY;
    SA_WriteInfo( Y );
    C := ReadKey;
    if( Not SA_CheckPlay( C, Y ) ) then case C of
      #09,
      #13 : if( aSample[Y].Address <> NIL ) then begin
              SA_Edit( Y );
              Redraw
            end
            else HandleIO( kA_L, Y );
      #00 : begin
              C := ReadKey;
              case byte( C ) of
                kF1      : begin
                             DoneGraph;
                             ST_ShowHelp( hcSampEd );
                             stgInit( '' );
                           end;
                kINS     : if( CheckSave( MAXSAMPLE ) in [rYes,rEnter] ) then begin
                             ST_Stop;
                             ClearSample( MAXSAMPLE );
                             for I:=MAXSAMPLE downto Y+1 do
                               aSample[I] := aSample[I-1];
                             aSample[Y] := NULLSAMPLE;
                             SA_InitPlay;
                             Redraw
                           end;
                kDEL     : if( CheckSave( Y ) in [rYes,rEnter] ) then begin
                             ST_Stop;
                             ClearSample( Y );
                             for I:=Y to MAXSAMPLE-1 do
                               aSample[I] := aSample[I+1];
                             aSample[MAXSAMPLE] := NULLSAMPLE;
                             SA_InitPlay;
                             Redraw
                           end;
                kHOME    : begin vPage := 0; vCurY := 0 end;
                kEND     : begin
                             vCurY := SA_LISTLEN-1;
                             vPage := MAXSAMPLE-SA_LISTLEN
                           end;
                kUP      : if( vCurY > 0 ) then
                             Dec( vCurY )
                           else if( vPage > 0 ) then Dec( vPage );
                kDOWN    : if( Y < MAXSAMPLE ) then
                             if( vCurY < SA_LISTLEN-1 ) then
                               Inc( vCurY )
                             else Inc( vPage );
                kPGUP    : for I:=1 to SA_LISTLEN do
                             if( vPage > 0 ) then
                               Dec( vPage )
                             else if( vCurY > 0 ) then Dec( vCurY );
                kPGDN    : for I:=1 to SA_LISTLEN do
                             if( vPage < MAXSAMPLE-SA_LISTLEN ) then
                               Inc( vPage )
                             else if( vCurY < SA_LISTLEN-1 ) then Inc( vCurY );
                kA_S,
                kA_L,
                kA_B,
                kA_A     : begin
                             DoneGraph;
                             HandleIO( byte(C), Y );
                             stgInit( '' );
                           end;
                kA_C     : begin
                             MyClearSamples;
                             Redraw
                           end;
                kA_E     : if( Win_VideoType >= Win_EGA ) then begin
                             DoneGraph;
                             SetEga43( Not Ega43 );
                             NewVideoMode;
                             SA_SetScreen;
                             Redraw;
                             stgInit( '' );
                           end;
                kA_O     : begin
                             DoneGraph;
                             ST_Stop;
                             E := DosShell;
                             SA_SetScreen;
                             SA_InitPlay;
                             Redraw;
                             PrintErrorMsg( E );
                             stgInit( '' );
                           end;
                kA_M     : ModifySample( Y, mMAXVOLUME )
              end (* extended key case *)
            end
    end; (* case *)
  until( C in [#27] );
  ST_Stop;
  DoneGraph;
end;

procedure SA_SetColors;
begin
  case Video of
    Win_MDA : begin
                SA_Palette[LISTFRAME] := $07;
                SA_Palette[INFOFRAME] := $07;
                SA_Palette[LISTEDIT] := $7F
              end
  end
end;

procedure SA_NewSong;
begin
  vPage := 0;
  vCurY := 0
end;

begin
end.

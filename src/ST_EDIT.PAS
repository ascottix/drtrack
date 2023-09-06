(*
   Dr. Track
   CopyRight (c) 1991-1992,1993 Alessandro Scotti
*)
{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S-,V-,X+}
{$ifdef ST286}
{$G+}
{$else}
{$G-}
{$endif}

unit ST_Edit;

interface uses ST_Data;

procedure Ed_Init;
procedure Ed_Exit;
procedure Ed_MacroInfo;
procedure Ed_NewSong;
procedure Ed_SetScreen;
procedure Ed_SetColors( Video: byte );
function  Ed_EditSong: ReturnType;

implementation uses Crt, Ems,
                    ST_Graph,
                    ST_Win, ST_Play, ST_Hyper, ST_Keyb, ST_Samp, ST_SbPro;

const
  FADE_SPEED  = 5;
  NOTESTRING  : string = '..C-C#D-D#E-F-F#G-G#A-A#B-';
  CMDSTRING   : string = '01234.....ABCDEF';
  HEXSTRING   : string = '0123456789ABCDEF';
  EXITASCII   : string = #9 + '+-';
  EXITSCAN    : string = char(kA_X)+char(kA_L)+char(kA_I)+char(kA_M)+
                         char(kA_S)+char(kA_C)+char(kA_O)+char(kA_P)+
                         char(kF1) +char(kA_R)+char(kA_W)+char(kA_E)+
                         char(kA_D)+char(kF2);
  DIGITS      = ['0'..'9'];
  MAXNAMELEN  = 20;

  ED_EDITX    = 8;
  ED_EDITY    : byte = 8;
  ED_PAGELEN  : byte = 16;  (* Solo potenze di 2 *)
  ED_TRAKWID  = 11;
  ED_ROWWID   = 3;
  ED_ORDERX   = 66;
  ED_ORDERY   : byte = 8;
  ED_ORDLEN   : byte = 16;  (* Solo potenze di 2 *)
  ED_INFOX    = 1;
  ED_INFOY    : byte = 2;
  ED_INFOWID  = 80;

  P_MASKHI    : byte = 240;
  P_MASKLO    : byte = 15;

  MAXCOLOR    = 14;
(* Nero, blu, verde, ciano, rosso, magenta, marrone, grigio *)
  Ed_Palette  : array[0..MAXCOLOR] of byte = (
    $07, $5A, $87, $2E, $03, $0B, $01,
    $03, $0B, $07, $0B, $01, $1B, $3F, $07
  );
  ED_ORDERLO  = 14;
  ED_PLAYING  = 13;
  ED_LEDIT    = 12;
  ED_INFOFRAME= 11;
  ED_INFOHI   = 10;
  ED_INFO     = 9;
  ED_ORDERHI  = 8;
  ED_ORDER    = 7;
  ED_FRAME    = 6;
  ED_HIROW    = 5;
  ED_ROW      = 4;
  ED_CURSOR   = 3;
  ED_HILITE   = 2;
  ED_MARKED   = 1;
  ED_NORMAL   = 0;
type
  BlockProc   = procedure( var N: tNote );
var
  SavedAutoInc: byte;
  vEditSound  : boolean;
  vRecTrack   : byte;
  vRecTest    : boolean;
  vTemp   : tPattern;
  vPage   : byte;
  vTrakNo : byte;
  vCurX   : byte;
  vCurY   : byte;
  vMarkB  : byte;
  vMarkE  : byte;
  vMarkT  : byte;
  vMarkNo : byte;
  vSample : byte;
  vMaxPatt: byte;
  vOrdPage: byte;
  vOrdY   : byte;
  vAutoInc: byte;
  vChMask : array[ 0..3 ] of word;

procedure Ed_MacroInfo;
begin
  if( vMacroRec ) then begin
    Win_WriteAt( ED_INFOX+68, ED_INFOY+2, 'Macro:', Ed_Palette[ED_INFO] );
    Win_WriteAt( ED_INFOX+75, ED_INFOY+2, 'Rec', Ed_Palette[ED_INFOHI] )
  end
  else Win_WriteAt( ED_INFOX+68, ED_INFOY+2, '          ', Ed_Palette[ED_INFOHI] )
end;

procedure OffMacroInfo;
var F: boolean;
begin
  F := vMacroRec;
  vMacroRec := FALSE;
  Ed_MacroInfo;
  vMacroRec := F
end;

procedure WriteSampleName( I, A: byte );
begin
  if( I <= 0 )or( I > 28 ) then
    Exit;
  Win_WriteAt( ((I-1) div 7)*19+6, ED_EDITY+ED_PAGELEN+2+(I-1) mod 7,
               Padded( Copy(aSample[I].Name,1,15), 15 ), A );
end;

procedure Ed_PrintPattern( P: byte );
var S: string[4];
begin
  Str( P:3, S );
  Win_WriteAt( ED_INFOX+ 11, ED_INFOY+2, Copy(S,1,3), Ed_Palette[ED_INFOHI] )
end;

procedure Ed_PrintChannels;
var S: string[4];
    I, A: byte;
begin
  S := ' n ';
  for A:=0 to 3 do
    if( vRecTrack = A ) then
      if( vRecTest ) then
        Win_WriteAt( ED_EDITX+A*ED_TRAKWID+3, ED_EDITY-1, ' Test ', $0A )
      else Win_WriteAt( ED_EDITX+A*ED_TRAKWID+3, ED_EDITY-1, ' Rec ', $0C )
    else begin
      S[2] := char(49+A);
      I := ED_EDITX+A*ED_TRAKWID+3;
      if( vChMask[A] = 0 ) then
        Win_WriteAt( I, ED_EDITY-1, S, Ed_Palette[ED_FRAME] )
      else Win_WriteAt( I, ED_EDITY-1, S, Ed_Palette[ED_INFOHI] );
      Win_WriteAt( I+3, ED_EDITY-1, 'ÍÍÍ', Ed_Palette[ED_FRAME] )
    end
end;

procedure SetRecTrack( Track: byte );
begin
  if( vRecTrack = Track ) then
    if( vRecTest ) then begin;
      vRecTrack := $FF;
      vRecTest := FALSE
    end
    else vRecTest := TRUE
  else vRecTrack := Track;
  Ed_PrintChannels
end;

procedure Ed_PrintNote( Track, Y, A: byte; N: tNote ); forward;
procedure Ed_PrintOrder( Page: byte ); forward;
procedure PrintOrderRow( I, Y, A1, A2: byte ); forward;
procedure Ed_PrintPage( Page: byte ); forward;
procedure Ed_PrintStat; forward;

procedure Ed_PrintInfo( Patt: byte );
begin
  Ed_PrintPattern( Patt );
  Ed_PrintStat;
end;

procedure MyOutPage( Index: byte; Frame: byte );
var I: byte;
begin
  ST_PrintHiFrame( aPattern[Index], Frame, 0 );
  for I:=1 to ED_PAGELEN-1 do
    ST_PrintFrame( aPattern[Index], Frame+I, I )
end;

procedure MySetChannels;
var I, W: word;
begin
  for I:=0 to 3 do begin
    W := vChMask[I];
    if( vRecTrack = I ) then
      W := W or $FFFF;
    ST_OnOffChannel( I, W )
  end
end;

procedure InitPeakGraph;
begin
  ST_PrintInit( Win_VideoSeg,
                Ed_Palette[ED_ROW], Ed_Palette[ED_HIROW],
                Ed_Palette[ED_NORMAL], Ed_Palette[ED_HILITE],
                Ed_Palette[ED_PLAYING],
                ED_EDITY-1, (ED_EDITY+ED_PAGELEN-2)*160 );
  ST_PrintPeakShadow;
  Win_WriteAt( 1, ED_EDITY+ED_PAGELEN, 'c1 c4', Ed_Palette[ED_ORDER] );
  Win_WriteAt( 56, ED_EDITY+ED_PAGELEN, 'c3 c2', Ed_Palette[ED_ORDER] );
end;

procedure DonePeakGraph;
var I, J: byte;
begin
  I := ED_EDITY+ED_PAGELEN;
  for J:=1 to 17 do begin
    Win_WriteAt( 1, I, '     ', 7 );
    Win_WriteAt( 56, I, '     ', 7 );
    Dec( I )
  end
end;

procedure MyInitSong( Start: byte );
var OrderLen, I: byte;
begin
  for I:=1 to LASTPATTERN do
    ST_SetPattern( I-1, aPattern[I] );
  for I:=1 to MAXPATTERN do
    ST_SetOrder( I-1, aOrder[I]-1 );
  if( Start = 0 ) then begin
    Start := Pred( vPattNo );
    ST_SetOrder( Start, Start );
    ST_SetPattern( Start, aPattern[vPattNo] );
    ST_InitSong( vSpeed, Start, Start+1 );
    MyOutPage( vPattNo, 0 )
  end
  else begin
    OrderLen := 0;
    Dec( Start );
    repeat
      Inc( OrderLen )
    until( aOrder[Start+OrderLen] = 0 )or( OrderLen = MAXPATTERN );
    if( aOrder[Start+OrderLen] = 0 ) then
      Dec( OrderLen );
    ST_InitSong( vSpeed, Start, Start+OrderLen );
    MyOutPage( aOrder[Start+1], 0 );
    Ed_PrintOrder( Start and P_MASKHI );
    PrintOrderRow( Start, Start and P_MASKLO, Ed_Palette[ED_PLAYING], Ed_Palette[ED_PLAYING] )
  end;
end;

procedure HandlePlaying;
var
  C: char;
  P12, P34, O, P, F, SavedSpeed, OS, LO, LP, LF: word;
  Err: word;
  A, I, J, K: word;
  Samp: array[ 1..4 ] of byte;
  FadeOut: boolean;
  MastVol: byte;
  FadeCount: word;
  Buf: ^byte;
  BufLen: word;
procedure SyncVideo;
  var I: byte;
  begin
    Ed_SetScreen;
    Win_SetCursorSize( Win_CRSOFF );
    OS := 0;
    ST_StatusLine( S_PLAY );
    InitPeakGraph;
    ST_GetInfo( LO, LP, LF );
    Ed_PrintOrder( LO and P_MASKHI );
    PrintOrderRow( LO, LO and P_MASKLO, A, A );
    P := LP;
    O := LO;
    F := LF;
    for I:=0 to P_MASKLO do
      ST_PrintFrame( aPattern[LP], LF and P_MASKHI + I, I );
    Ed_PrintInfo( LP );
    for I:=1 to 4 do Samp[I] := 0;
  end;
procedure InitGraph;
  begin
    stgInit( '' );
    stgClear;
    stgRefresh;
    stgShowAt( 78-MAX_X, 2, LightGreen );
  end;
procedure DoneGraph;
  var
    I: byte;
  begin
    for I:=1 to 3 do
      Win_WriteAt( 79-MAX_X, 2+I, Spaces(MAX_X), 7 );
    stgDone;
  end;
begin
  InitGraph;
  BufLen := ST_GetBlockLen;
  A := Ed_Palette[ED_PLAYING];
  C := #0;
  ST_GetInfo( LO, LP, LF );
  OS := $FF;
  SavedSpeed := vSpeed;
  P := LP;
  ST_StatusLine( S_PLAY );
  Ed_PrintPattern( P );
  FadeOut := FALSE;
  repeat
    stgClear;
    Buf := ST_GetBuffer;
    K := CHARHEIGHT*3;
    if( not SBC_IsPro ) then begin
      for I:=1 to BufLen do begin
        asm
          mov   ax, [I]
          dec   ax
          mov   dx, MAX_X*8
          mul   dx
          xor   dx, dx
          div   [BufLen]
          push  ax
          les   di, [Buf]
          inc   WORD PTR [Buf]
          mov   al, es:[di]
          mul   BYTE PTR [K]
          mov   al, ah
          push  ax
          call  stgSetPixel
        end;
      end;
    end
    else begin
      for I:=1 to BufLen do begin
        asm
          mov   ax, [I]
          dec   ax
          mov   dx, MAX_X*8
          mul   dx
          xor   dx, dx
          div   [BufLen]
          push  ax
          les   di, [Buf]
          mov   ax, es:[di]
          add   WORD PTR [Buf], 2
          shr   al, 1
          shr   ah, 1
          add   al, ah
          mul   BYTE PTR [K]
          mov   al, ah
          push  ax
          call  stgSetPixel
        end;
      end;
    end;
    if( KeyPressed ) then begin
      C := ReadKey;
      I := ST_KeyToNote( C );
      if( I > 0 ) then begin
        ST_Record( I, vSample, vRecTrack, vRecTest );
        if( Not vRecTest ) then
          vModify := TRUE
      end
      else case C of
        ^H  : begin
                vOctave := (vOctave + 1) mod 3;
                Ed_PrintStat
              end;
        #00 : begin
                C := ReadKey;
                case byte( C ) of
                  kF5..kF8: begin
                              vChMask[byte(C)-kF5] := Not vChMask[byte(C)-kF5];
                              MySetChannels;
                              Ed_PrintChannels
                            end;
                  kA_V    : begin
                              DoneGraph;
                              SBP_SetSTVolume;
                              SyncVideo;
                              InitGraph;
                            end;
                  kA_F5..kA_F8:
                            SetRecTrack( byte(C)-kA_F5 );
                  kC_F1   : begin
                              if( vSample > 1 ) then Dec( vSample );
                              Ed_PrintStat
                            end;
                  kF3     : if( vMasterVolume > 0 ) then begin
                              Dec( vMasterVolume );
                              ST_SetMasterVolume( vMasterVolume );
                              Ed_PrintStat
                            end;
                  kF4     : if( vMasterVolume < 64 ) then begin
                              Inc( vMasterVolume );
                              ST_SetMasterVolume( vMasterVolume );
                              Ed_PrintStat
                            end;
                  kC_F2   : begin
                              if( vSample < MAXSAMPLE ) then Inc( vSample );
                              Ed_PrintStat
                            end;
                  kA_O    : begin
                              DoneGraph;
                              DosShell;
                              SyncVideo;
                              InitGraph;
                              for I:=1 to 4 do Samp[I] := 0;
                            end;
                  kF1     : begin
                              DoneGraph;
                              ST_ShowHelp( hcPlayer );
                              SyncVideo;
                              InitGraph;
                            end;
                  kA_E    : if( Win_VideoType >= Win_EGA ) then begin
                              DoneGraph;
                              SetEga43( Not Ega43 );
                              NewVideoMode;
                              SyncVideo;
                              InitGraph;
                            end;
                  kA_F    : begin
                              MastVol := vMasterVolume;
                              FadeOut := TRUE;
                              FadeCount := 0;
                            end;
                end
              end;  (* extended key case *)
      end
    end;
    vSpeed := ST_GetSpeed;
    ST_GetInfo( O, P, F );
    if( FadeOut )and( F <> LF ) then begin
      Inc( FadeCount, vSpeed );
      if( FadeCount >= FADE_SPEED ) then begin
        Dec( FadeCount, FADE_SPEED );
        if( MastVol > 0 ) then begin
          Dec( MastVol );
          ST_SetMasterVolume( MastVol )
        end
        else C := #27;
      end;
    end;
    if( P <> LP )or( F and P_MASKLO = 0 ) then begin
      MyOutPage( P, F and P_MASKHI );
      Ed_PrintPattern( P );
      LP := P;
      LF := F;
      if( O and P_MASKHI <> LO and P_MASKHI ) then begin
        Ed_PrintOrder( O and P_MASKHI );
        PrintOrderRow( O, O and P_MASKLO, A, A );
        LO := O
      end
      else if( O <> LO ) then begin
        PrintOrderRow( LO, LO and P_MASKLO, Ed_Palette[ED_ORDER], Ed_Palette[ED_ORDERHI] );
        PrintOrderRow( O, O and P_MASKLO, A, A );
        LO := O
      end
    end
    else if( F <> LF ) then begin
      ST_PrintFrame( aPattern[P], LF, LF and P_MASKLO );
      ST_PrintHiFrame( aPattern[P], F, F and P_MASKLO );
      LF := F
    end;
    if( vSpeed <> OS ) then begin
      OS := vSpeed;
      asm
        mov  es, [Win_VideoSeg]
        mov  al, [ED_INFOY]
        xor  ah, ah
        inc  ax
        shl  ax, 1    (* AX = Y*2 *)
        mov  di, ax   (* DI = Y*2 *)
        shl  ax, 1
        shl  ax, 1    (* AX = Y*8 *)
        add  ax, di   (* AX = Y*10 *)
        shl  ax, 1
        shl  ax, 1
        shl  ax, 1
        shl  ax, 1
        mov  di, ax
        mov  al, [ED_INFOX]
        xor  ah, ah
        add  ax, 37
        shl  ax, 1
        add  di, ax
        mov  ax, [OS]
        mov  ah, al
        mov  cl, 4
        shr  al, cl
        add  al, $90
        daa
        adc  al, $40
        daa
        mov  es:[di], al
        mov  al, ah
        and  al, $0F
        add  al, $90
        daa
        adc  al, $40
        daa
        mov  es:[di+2], al
      end;
    end;
    ST_GetPeaks( P12, P34 );
    ST_PrintPeaks( P12, P34 );
    if( Win_TextRows >= 49 ) then begin
      for I:=1 to 4 do begin
        J := aPattern[P]^[I][F].Sample;
        if( J <> 0 )and( J <> Samp[I] ) then begin
          WriteSampleName( Samp[I], Ed_Palette[ED_NORMAL] );
          WriteSampleName( J, Ed_Palette[ED_PLAYING] );
          Samp[I] := J;
        end;
      end;
    end;
(* Wait vertical retrace (seems to be useless)
    asm
      mov dx, $3DA
    @@Loop:
      in   al, dx
      test al, 8
      je   @@Loop
    end;
*)
    stgRefresh;
  until( C = #27 );
  DoneGraph;
  vSpeed := SavedSpeed
end;

procedure MyPlay( Start: byte );
begin
  Win_SetCursorSize( Win_CRSOFF );
  OffMacroInfo;
  MyInitSong( Start );
  MySetChannels;
  ST_SetMasterVolume( vMasterVolume );
  ST_PlayModule( EMM_PattHandle );
  InitPeakGraph;
  HandlePlaying;
  ST_Stop;
  DonePeakGraph;
  Ed_PrintPage( vPage );
  Ed_PrintOrder( vOrdPage );
  Ed_PrintStat;
  Ed_SetScreen;
  Win_SetCursorSize( Win_CRSON );
end;

procedure Ed_EditName( Edit: byte );
var I: byte;
begin
  if( Edit in [1,2] ) then begin
    OffMacroInfo;
    if( Edit = 1 ) then
      I := ST_LineEdit( ED_INFOX+9, ED_INFOY+1, MAXNAMELEN+2,
                        MAXNAMELEN, vSongName, #13+'S'+#27+'E|',
                        hcSONGNAME )
    else I := ST_LineEdit( ED_INFOX+52, ED_INFOY+1, 12+2,
                           12, vFileName, '@'+#13+'S'+#27+'E|',
                           hcSONGFILENAME );
    if( I = 1 ) then vModify := TRUE;
    Ed_MacroInfo
  end;
  Win_WriteAt( ED_INFOX+9, ED_INFOY+1, Padded( vSongName, MAXNAMELEN+2 ),
               Ed_Palette[ED_INFOHI] );
  Win_WriteAt( ED_INFOX+52, ED_INFOY+1, Padded( vFileName, 14 ),
               Ed_Palette[ED_INFOHI] );
end;

procedure Ed_PrintStat;
var S: string[16];
    A: byte;
begin
  S := '   ssoattvv';
  S[4] := char(vSample div 10+48);
  S[5] := char(vSample mod 10+48);
  S[6] := char(vOctave + 49);
  S[7] := char(vAutoInc + 48);
  S[8] := char(vSpeed div 10+48);
  S[9] := char(vSpeed mod 10+48);
  S[10]:= char(vMasterVolume div 10+48);
  S[11]:= char(vMasterVolume mod 10+48);
  A := Ed_Palette[ED_INFOHI];
  Win_WriteAt( ED_INFOX+ 64, ED_INFOY+2, Copy(S,6,1), A );
  Win_WriteAt( ED_INFOX+ 25, ED_INFOY+2, Copy(S,4,2), A );
  Win_WriteAt( ED_INFOX+ 37, ED_INFOY+2, Copy(S,8,2), A );
  Win_WriteAt( ED_INFOX+ 52, ED_INFOY+2, Copy(S,7,1), A );
  Win_WriteAt( ED_INFOX+ 17, ED_INFOY+3, Copy(S,10,2), A );
  Ed_PrintChannels;
end;

procedure Ed_MapEMM;
var I: byte;
begin
  if( EMM_PattHandle <> EMM_NIL ) then
    for I:=0 to 3 do
      EMM_MapMemory( I, I, EMM_PattHandle );
end;

procedure Ed_SetScreen;
var
  A, I: byte;
  S: string;
begin
  if( Ega43 ) then begin
    ED_PAGELEN := 32;
    ED_ORDLEN := 32;
    ED_INFOY := 3;
    ED_EDITY := 9;
    ED_ORDERY := 9;
    if( Win_TextRows >= 49 ) then begin
      ED_INFOY := 2;
      ED_EDITY := 8;
      ED_ORDERY := 8;
      Win_Box( 1, ED_EDITY+ED_PAGELEN+1, 80, 49,
               DOUBLEBORDER, Ed_Palette[ED_FRAME] );
      Win_WriteAt( 2, ED_EDITY+ED_PAGELEN+1, ' Samples ', Ed_Palette[ED_INFOHI] );
      S := 'nn';
      for I:=1 to 28 do begin
        S[1] := char( 48 + I div 10 );
        S[2] := char( 48 + I mod 10 );
        Win_WriteAt( ((I-1) div 7)*19+3, ED_EDITY+ED_PAGELEN+2+(I-1) mod 7,
                     S + ':', Ed_Palette[ED_NORMAL] );
        WriteSampleName( I, Ed_Palette[ED_NORMAL] );
      end
    end
  end
  else begin
    ED_PAGELEN := 16;
    ED_ORDLEN := 16;
    ED_INFOY := 2;
    ED_EDITY := 8;
    ED_ORDERY := 8
  end;
  ST_SetPosVars( vPage, vCurY, ED_PAGELEN, 64 );
  ST_SetPosVars( vOrdPage, vOrdY, ED_ORDLEN, MAXPATTERN );
  P_MASKHI := 256-ED_PAGELEN;
  P_MASKLO := ED_PAGELEN-1;
  ST_PrintInit( Win_VideoSeg,
                Ed_Palette[ED_ROW], Ed_Palette[ED_HIROW],
                Ed_Palette[ED_NORMAL], Ed_Palette[ED_HILITE],
                Ed_Palette[ED_PLAYING],
                ED_EDITY-1, (ED_EDITY+ED_PAGELEN-2)*160 );
  Win_SetCursorSize( Win_CRSOFF );
  S := COPYRIGHTMSG;
  for I:=1 to (80-Length(S)) div 2 do S := ' ' + S;
  while( Length(S) < 80 ) do S := S + ' ';
  Win_WriteAt( 1, 1, S, COPYRIGHTATTR );
  A := Ed_Palette[ED_FRAME];
  Win_Box( ED_EDITX-1, ED_EDITY-1,
           ED_EDITX+ED_ROWWID+ED_TRAKWID*4-1, ED_PAGELEN+ED_EDITY,
           DOUBLEBORDER, A );
  for I:=1 to 3 do
    VLine( ED_EDITX+ED_ROWWID+ED_TRAKWID*I-1,
           ED_EDITY-1, ED_PAGELEN+ED_EDITY,
           A, 'ÑÏ³' );
  VLine( ED_EDITX+ED_ROWWID-1, ED_EDITY-1, ED_PAGELEN+ED_EDITY,
         A, 'ËÊº' );
  Win_Box( ED_ORDERX-1, ED_ORDERY-1, ED_ORDERX+8, ED_ORDLEN+ED_ORDERY,
           DOUBLEBORDER, A );
  VLine( ED_ORDERX+4, ED_ORDERY-1, ED_ORDLEN+ED_ORDERY, A, 'ÑÏ³' );
  Win_Box( ED_INFOX, ED_INFOY, ED_INFOX+ED_INFOWID-1, ED_INFOY+4,
           DOUBLEBORDER, Ed_Palette[ED_INFOFRAME] );
  A := Ed_Palette[ED_INFO];
  Win_WriteAt( ED_INFOX+2, ED_INFOY+1, 'Title:', A );
  Win_WriteAt( ED_INFOX+41, ED_INFOY+1, 'File name:', A );
  Win_WriteAt( ED_INFOX+2, ED_INFOY+2, 'Pattern:', A );
  Win_WriteAt( ED_INFOX+17, ED_INFOY+2, 'Sample:', A );
  Win_WriteAt( ED_INFOX+30, ED_INFOY+2, 'Speed:', A );
  Win_WriteAt( ED_INFOX+42, ED_INFOY+2, 'Autojump:', A );
  Win_WriteAt( ED_INFOX+56, ED_INFOY+2, 'Octave:', A );
  Win_WriteAt( ED_INFOX+2, ED_INFOY+3, 'Global volume:', A );
  Ed_EditName( 0 );
  Ed_PrintOrder( vOrdPage );
  Ed_PrintPage( vPage );
  Ed_MacroInfo;
  Win_SetCursorSize( Win_CRSON )
end;

procedure Ed_ClearTemp;
var I, J: word;
begin
  for I:=1 to 4 do
    for J:=0 to 63 do
      vTemp[I][J] := NULLNOTE;
  vPage := 0;
  vCurX := 1;
  vCurY := 0;
  vTrakNo := 1;
end;

procedure Ed_Init;
var I, J: word;
begin
  vMaxPatt := 0;
  if( EMM_PattHandle <> EMM_NIL ) then begin
    Ed_MapEMM;
    for I:=1 to 64 do
      aPattern[ I ] := Ptr( EMM_GetPageFrame, (I-1)*1024 );
    vMaxPatt := 64;
    J := 65
  end
  else J := 1;
  for I:=J to LASTPATTERN do
    if( MaxRAM >= SizeOf(tPattern) ) then begin
      New( aPattern[I] );
      Inc( vMaxPatt )
    end;
  if( LASTPATTERN <> vMaxPatt ) then Halt( 1 )
end;

procedure Ed_NewSong;
var I, J: word;
begin
  Ed_ClearTemp;
  for I:=1 to LASTPATTERN do begin
    aPattern[ I ]^ := vTemp
  end;
  FillChar( aOrder, MAXPATTERN, 0 );
  for I:=0 to 3 do
    vChMask[I] := $FFFF;
  vModify := FALSE;
  vSpeed := 6;
  vAutoInc := 1;
  vOrdPage := 0;
  vOrdY := 0;
  vSample := 1;
  vMarkB := 0;
  vMarkE := 0;
  vMarkT := 0;
  vMarkNo := 0;
  vPattNo := 1;
  vSongName := '';
  vFileName := 'NONAME'+SONG_EXT;
  vRecTrack := $FF;
  vRecTest := FALSE
end;

procedure Ed_PrintNote( Track, Y, A: byte; N: tNote );
var S: string;
begin
  with N do begin
    S := Copy( NOTESTRING, (Note and 15)*2+1, 2 ) + '. .. ...';
    if( Note and $0F > 0 ) then
      S[3] := char(Note shr 4+48);
    if( Sample > 0 ) then begin
      S[5] := char(Sample div 10+48);
      S[6] := char(Sample mod 10+48)
    end;
    if( Command <> 0 ) then
      S[8] := CMDSTRING[ Command+1 ]
    else if( Info <> 0 ) then
      S[8] := '0';
    S[9] := HEXSTRING[Info shr 4+1];
    S[10] := HEXSTRING[Info and $0F+1]
  end;
  Win_WriteAt( ED_EDITX+ED_ROWWID+(Track-1)*ED_TRAKWID, ED_EDITY+Y, S, A )
end;

function Ed_GetNoteAttr( Track, Y: byte ): byte;
var A: byte;
begin
  if( Y and 3 = 0 ) then
    A := ED_HILITE
  else A := ED_NORMAL;
  if( vMarkNo = vPattNo ) then
    if( Y >= vMarkB )and( Y <= vMarkE ) then
      if( vMarkT = Track )or( vMarkT = 5 ) then
        A := ED_MARKED;
  Ed_GetNoteAttr := Ed_Palette[A]
end;

procedure Ed_PrintPage( Page: byte );
var I, J: byte;
begin
  for I:=Page to Page+ED_PAGELEN-1 do begin
    if( I and 3 = 0 ) then
      J := ED_HIROW
    else J := ED_ROW;
    Win_WriteAt( ED_EDITX, I-Page+ED_EDITY,
                 char(I div 10+48)+char(I mod 10+48),
                 Ed_Palette[J] );
    for J:=1 to 4 do
      Ed_PrintNote( J, I-Page, Ed_GetNoteAttr( J, I ), vTemp[J][I] );
  end
end;

procedure AddHalfNote( var N: tNote ); far;
var I: byte;
begin
  I := N.Note;
  if( I < $3C )and( I <> 0 ) then begin
    Inc( I );
    if( I and $0F > $0C ) then
      I := ( I and $F0 ) + $11;
    vModify := TRUE;
    N.Note := I
  end
end;

procedure SubHalfNote( var N: tNote ); far;
var I: byte;
begin
  I := N.Note;
  if( I > $11 ) then begin
    Dec( I );
    if( I and $0F = $00 ) then
      I := ( I and $F0 ) - $10 + $0C;
    vModify := TRUE;
    N.Note := I
  end
end;

procedure SetCurrentSample( var N: tNote ); far;
begin
  if( N.Note > 0 ) then begin
    N.Sample := vSample;
    vModify := TRUE
  end
end;

function Ed_EditTemp: word;
const
  CrsRight: array[ 1..10 ] of byte = (3,0,5,0,6,8,0,9,10,0);
  CrsLeft : array[ 1..10 ] of byte = (0,0,1,0,3,5,0,6,8,9);
var
  C: char;
  OP, OY, OT, Y, I, J: byte;
  Res: word;
  Redraw: boolean;
  Stop: boolean;
  N: tNote;
procedure GoDown;
  begin
    if( vPage+vCurY < 63 ) then begin
      if( vCurY+1 < ED_PAGELEN ) then
        Inc( vCurY )
      else Inc( vPage )
    end
  end;
procedure GoUp;
  begin
    if( Y > 0 ) then begin
      if( vCurY > 0 ) then
        Dec( vCurY )
      else Dec( vPage )
    end
  end;
procedure MarkBlock( Trak: byte );
  begin
    if( vMarkNo <> vPattNo )or( vMarkT <> Trak ) then begin
      vMarkB := Y;
      vMarkE := Y;
      vMarkT := Trak;
      vMarkNo := vPattNo
    end
    else begin
      if( Y < vMarkB ) then
        vMarkB := Y
      else if( Y > vMarkE ) then
        vMarkE := Y
      else begin
        vMarkB := Y;
        vMarkE := Y
      end
    end;
    Redraw := TRUE
  end;
procedure WipeBlock( Trak: byte );
  var I: byte;
  begin
    if( vMarkNo = vPattNo )and( Trak > 0 ) then begin
      Redraw := TRUE;
      vModify := TRUE;
      for I:=vMarkB to vMarkE do
        vTemp[Trak][I] := NULLNOTE;
      N := vTemp[OT][OP+OY]
    end
  end;
procedure InsNote( Trak, Y, Count: byte );
  var I: byte;
  begin
    I := 63;
    while( I-Count >= Y ) do begin
      vModify := TRUE;
      vTemp[Trak][I] := vTemp[Trak][I-Count];
      Dec( I )
    end;
    for I:=Y to Y+Count-1 do
      vTemp[Trak][I] := NULLNOTE;
    N := vTemp[OT][OP+OY];
    Redraw := TRUE
  end;
procedure DelNote( Trak, Y, Count: byte );
  var I: byte;
  begin
    I := Y;
    while( I+Count <= 63 ) do begin
      vModify := TRUE;
      vTemp[Trak][I] := vTemp[Trak][I+Count];
      Inc( I )
    end;
    for I:=63 downto 63-Count+1 do
      vTemp[Trak][I] := NULLNOTE;
    N := vTemp[OT][OP+OY];
    Redraw := TRUE
  end;
procedure DelBlock( Trak: byte );
  var I: byte;
  begin
    if( vPattNo = vMarkNo )and( Trak > 0 ) then begin
      vModify := TRUE;
      DelNote( Trak, vMarkB, vMarkE-vMarkB+1 )
    end
  end;
procedure CopyBlock( SourceTrak, DestTrak: byte; Overwrite: boolean );
  var I, J, K: byte;
  begin
    K := vMarkE-vMarkB;
    J := Y;
    if( K = 63 ) then
      J := 0;
    if( J+K > 63 ) then
      K := 63-J;
    aPattern[vPattNo]^ := vTemp;
    if( Not OverWrite ) then
      InsNote( DestTrak, J, K+1 );
    for I:=0 to K do
      vTemp[DestTrak][I+J] := aPattern[vMarkNo]^[SourceTrak][I+vMarkB];
    N := vTemp[OT][OP+OY];
    Redraw := TRUE
  end;
procedure DoBlock( Command: BlockProc );
  var I, J: byte;
  begin
    if( vPattNo = vMarkNo )and( vMarkT > 0 ) then begin
      for I:=vMarkB to vMarkE do
        if( vMarkT <= 4 ) then
          Command( vTemp[vMarkT][I] )
        else for J:=1 to 4 do
          Command( vTemp[J][I] );
      N := vTemp[OT][OP+OY];
      Redraw := TRUE
    end
  end;
begin
  Ed_PrintPage( vPage );
  Stop := FALSE;
  ST_PlaySolo;
  repeat
    Y := vPage + vCurY;
    OP := vPage;
    OY := vCurY;
    OT := vTrakNo;
    N := vTemp[OT][Y];
    Redraw := FALSE;
    Ed_PrintNote( vTrakNo, vCurY, Ed_GetNoteAttr( vTrakNo, Y ), N );
    GotoXY( ED_EDITX+ED_ROWWID+(vTrakNo-1)*ED_TRAKWID+vCurX-1,
            ED_EDITY+vCurY );
    Ed_PrintInfo( vPattNo );
    repeat
    until( Key_Pressed );
    C := Read_Key;
    if( C = #0 ) then begin
      C := Read_Key;
      if( Pos( C, EXITSCAN ) > 0 ) then begin
        Res := 100+Pos( C, EXITSCAN );
        Stop := TRUE
      end
      else case byte( C ) of
        kRIGHT  : if( vCurX = 10 ) then begin
                    if( vTrakNo < 4 ) then begin
                      Inc( vTrakNo );
                      vCurX := 1
                    end
                  end
                  else vCurX := CrsRight[vCurX];
        kLEFT   : if( vCurX = 1 ) then begin
                    if( vTrakNo > 1 ) then begin
                      Dec( vTrakNo );
                      vCurX := 10
                    end
                  end
                  else vCurX := CrsLeft[vCurX];
        kDOWN   : GoDown;
        kUP     : GoUp;
        kHOME   : vCurX := 1;
        kEND    : vCurX := 10;
        kPGUP   : for I:=1 to ED_PAGELEN do
                    if( vPage > 0 ) then
                      Dec( vPage )
                    else if( vCurY > 0 ) then
                      Dec( vCurY );
        kPGDN   : for I:=1 to ED_PAGELEN do if( vPage+vCurY < 63 ) then
                    if( vPage+ED_PAGELEN <= 63 ) then
                      Inc( vPage )
                    else Inc( vCurY );
        kC_PGUP : begin
                    vCurY := 0;
                    vPage := 0
                  end;
        kC_PGDN : begin
                    vCurY := ED_PAGELEN-1;
                    vPage := 63-vCurY
                  end;
        kA_F1..kA_F4:
                  begin
                    I := (byte(C)-kA_F1)*16;
                    if( I + ED_PAGELEN <= 64 ) then begin
                      vPage := I;
                      vCurY := 0
                    end
                  end;
        kC_F1,kF9:
                  if( vSample > 1 ) then Dec( vSample );
        kC_F2,kF10:
                  if( vSample < MAXSAMPLE ) then Inc( vSample );
        kF3     : if( vMasterVolume > 0 ) then begin
                    Dec( vMasterVolume );
                  end;
        kF4     : if( vMasterVolume < 64 ) then begin
                    Inc( vMasterVolume );
                  end;
        kC_F3   : if( vSpeed > 1 ) then Dec( vSpeed );
        kC_F4   : if( vSpeed < 12 ) then Inc( vSpeed );
        kA_V    : SBP_SetSTVolume;
        kC_F5..kC_F8:
                  vAutoInc := 1 ShL (byte(C)-kC_F5);
        kF5..kF8: vChMask[byte(C)-kF5] := Not vChMask[byte(C)-kF5];
        kA_F5..kA_F8:
                  SetRecTrack( byte( C )-kA_F5 );
        kC_HOME : vCurY := 0;
        kC_END  : vCurY := ED_PAGELEN-1;
        kINS    : InsNote( vTrakNo, Y, 1 );
        kDEL    : DelNote( vTrakNo, Y, 1 );
        kC_RIGHT: begin
                    if( vTrakNo < 4 ) then Inc( vTrakNo );
                    vCurX := 1
                  end;
        kC_LEFT : begin
                    if( vTrakNo > 1 ) then Dec( vTrakNo );
                    vCurX := 1
                  end
      end
    end
    else if( Pos( C, EXITASCII ) > 0 ) then begin
      Res := Pos( C, EXITASCII );
      Stop := TRUE
    end
    else case C of
      ' '     : if( N.Note <> 0 )and( N.Sample <> 0 ) then
                  ST_SetSoloNote( N.Note, N.Sample );
      ^K,'\'  : ST_SetSoloNote( $11, 0 );
      ^B      : MarkBlock( vTrakNo );   (* Mark block *)
      ^E      : begin
                  vEditSound := Not vEditSound;
                  if( Not vEditSound ) then begin
                    On_Message( 'Edit sound if OFF.' );
                    ST_SetSoloNote( $11, 0 )
                  end
                  else On_Message( 'Edit sound is ON.' );
                  Delay( 500 );
                  Off_Message
                end;
      ^J      : if( vAutoInc = 0 ) then
                  vAutoInc := SavedAutoInc
                else begin
                  SavedAutoInc := vAutoInc;
                  vAutoInc := 0
                end;
      ^U      : begin                   (* Unmark *)
                  vMarkT := 0;
                  vMarkNo := 0;
                  Redraw := TRUE
                end;
      ^L      : MarkBlock( 5 );         (* Mark line *)
      ^T      : begin                   (* Mark track *)
                  vMarkT := vTrakNo;
                  vMarkB := 0;
                  vMarkE := 63;
                  vMarkNo := vPattNo;
                  Redraw := TRUE
                end;
      ^P      : begin                   (* Mark pattern *)
                  vMarkT := 5;
                  vMarkB := 0;
                  vMarkE := 63;
                  vMarkNo := vPattNo;
                  Redraw := TRUE
                end;
      ^Y      : N := NULLNOTE;          (* Del line *)
      ^W      : if( vMarkT <= 4 ) then  (* Wipe block *)
                  WipeBlock( vMarkT )
                else for I:=1 to 4 do WipeBlock( I );
      ^D      : begin                   (* Del block *)
                  if( vMarkT <= 4 ) then
                    DelBlock( vMarkT )
                  else for I:=1 to 4 do DelBlock( I );
                  if( vMarkNo = vPattNo )and( Y > vMarkE )and( vMarkT = vTrakNo ) then
                    for I:=vMarkB to vMarkE do
                      GoUp;
                  N := vTemp[vTrakNo][Y];
                  vMarkNo := 0;
                  vMarkT := 0
                end;
      ^C,^O,^M: if( vMarkT > 0 )and( vMarkNo > 0 ) then begin
                  if( vMarkT <= 4 ) then
                    CopyBlock( vMarkT, vTrakNo, (C=^O) )
                  else for I:=1 to 4 do CopyBlock( I, I, (C=^O) );
                  if( C = ^M ) then begin
                    if( vMarkT <= 4 ) then
                      DelBlock( vMarkT )
                    else for I:=1 to 4 do DelBlock( I )
                  end;
                  I := vMarkE-vMarkB;
                  vMarkNo := vPattNo;
                  if( vMarkT <= 4 ) then
                    vMarkT := vTrakNo;
                  if( I <> 63 ) then begin
                    vMarkB := Y;
                    vMarkE := Y+I;
                    if( vMarkE > 63 ) then
                      vMarkE := 63
                  end
                end;
      ^N      : Ed_EditName( 1 );  (* Name song *)
      ^F      : Ed_EditName( 2 );  (* Name file *)
      ^H      : vOctave := (vOctave+1) mod 3;
      ^A      : DoBlock( AddHalfNote );
      ^S      : DoBlock( SubHalfNote );
      ^V      : DoBlock( SetCurrentSample )
      else    case vCurX of
        01 : begin
               I := ST_KeyToNote( C );
               if( I > 0 ) then begin
                 N.Note := I;
                 if( vSample > 0 ) then
                   N.Sample := vSample;
                 if( vEditSound ) then
                   ST_SetSoloNote( N.Note, N.Sample );
                 for I:=1 to vAutoInc do
                   GoDown;
                 vModify := TRUE
               end
             end;
        03 : if( C in ['1'..'3'] ) then begin
               vModify := TRUE;
               N.Note := (N.Note and $0F) or ((byte(C)-48) ShL 4);
               vCurX := 1;
               for I:=1 to vAutoInc do
                 GoDown
             end;
        05 : if( C in DIGITS ) then begin
               I := (N.Sample mod 10)+10*(byte(C)-48);
               if( I > MAXSAMPLE ) then
                 I := 10*(byte(C)-48);
               if( I <= MAXSAMPLE ) then begin
                 vModify := TRUE;
                 N.Sample := I;
                 vSample := I;
                 Inc( vCurX )
               end
             end;
        06 : if( C in DIGITS ) then begin
               I := (N.Sample div 10)*10+byte(C)-48;
               if( I <= MAXSAMPLE ) then begin
                 vModify := TRUE;
                 N.Sample := I;
                 vSample := I;
                 Dec( vCurX );
                 for I:=1 to vAutoInc do
                   GoDown
               end
             end;
        08 : begin
               C := UpCase( C );
               I := Pos( C, CMDSTRING );
               if( I > 0 )and( C <> '.' ) then begin
                 vModify := TRUE;
                 I := I - 1;
                 N.Command := I;
                 if( I in [$03,$04,$0D] ) then
                   for I:=1 to vAutoInc do GoDown
                 else Inc( vCurX );
               end
             end;
        09 : begin
               I := Pos( UpCase(C), HEXSTRING );
               if( I > 0 ) then begin
                 vModify := TRUE;
                 N.Info := (N.Info and $0F) or ((I-1) ShL 4);
                 Inc( vCurX )
               end
             end;
        10 : begin
               I := Pos( UpCase(C), HEXSTRING );
               if( I > 0 ) then begin
                 vModify := TRUE;
                 N.Info := (N.Info and $F0) or (I-1);
                 Dec( vCurX );
                 if Not( N.Command in [$03,$04] ) then
                   Dec( vCurX );
                 for I:=1 to vAutoInc do
                   GoDown
               end
             end;
      end
    end;
    vTemp[OT][OP+OY] := N;
    if( vPage <> OP )or( Redraw ) then
      Ed_PrintPage( vPage )
    else Ed_PrintNote( OT, OY, Ed_GetNoteAttr( OT, OP+OY ), N );
  until( Stop );
  ST_Stop;
  Ed_EditTemp := Res
end;

procedure PrintOrderRow( I, Y, A1, A2: byte );
var S: string[4];
    O: byte;
begin
  S := ' xx ';
  S[2] := HEXSTRING[I shr 4+1];
  S[3] := HEXSTRING[I and 15+1];
  Win_WriteAt( ED_ORDERX, ED_ORDERY+Y and (ED_ORDLEN-1), S, A1 );
  S := '   ';
  O := aOrder[I+1];
  S[3] := char( 48+O mod 10);
  O := O div 10;
  S[2] := char( 48+O mod 10 );
  S[1] := char( 48+O div 10 );
  if( S[1] = '0' ) then begin
    S[1] := '.';
    if( S[2] = '0' ) then
      S[2] := '.'
  end;
  Win_WriteAt( ED_ORDERX+5, ED_ORDERY+Y and (ED_ORDLEN-1), S, A2 )
end;

procedure Ed_PrintOrder( Page: byte );
var A, I: byte;
begin
  for I:=Page to Page+ED_ORDLEN-1 do begin
    if( aOrder[I+1] = 0 ) then
      A := ED_ORDERLO
    else A := ED_ORDERHI;
    PrintOrderRow( I, I-Page, Ed_Palette[ED_ORDER], Ed_Palette[A] )
  end
end;

function Ed_EditOrder: char;
var C: char;
    I: word;
    X, Y, Max: byte;
procedure GoDown;
  begin
    if( Y < MAXPATTERN ) then begin
      if( vOrdY < ED_ORDLEN-1 ) then
        Inc( vOrdY )
      else Inc( vOrdPage )
    end;
    Y := vOrdPage+vOrdY+1
  end;
procedure GoUp;
  begin
    if( Y > 1 ) then begin
      if( vOrdY > 0 ) then
        Dec( vOrdY )
      else Dec( vOrdPage )
    end;
    Y := vOrdPage+vOrdY+1
  end;
procedure SetMax;
  var I: byte;
  begin
    Max := 0;
    for I:=1 to MAXPATTERN do
      if( aOrder[I] > Max ) then Max := aOrder[I];
  end;
procedure SetX;
  begin
    if( Max >= 100 ) then
      X := 1
    else if( Max >= 10 ) then
      X := 2
    else X := 3
  end;
procedure DoSong( Command: BlockProc );
  var I, T, F: byte;
  begin
    On_Message( 'Working...' );
    for I:=1 to LASTPATTERN do
      for T:=1 to 4 do
        for F:=0 to 63 do
          Command( aPattern[I]^[T][F] );
    Off_Message;
    vTemp := aPattern[vPattNo]^;
    Ed_PrintPage( vPage )
  end;
begin
  SetMax;
  SetX;
  repeat
    ST_StatusLine( S_ORDER );
    Ed_PrintOrder( vOrdPage );
    Y := vOrdPage+vOrdY+1;
    GotoXY( ED_ORDERX+4+X, ED_ORDERY+vOrdY );
    repeat
    until( Key_Pressed );
    C := Read_Key;
    if( C in [#01..#07] ) then
      C := #$FF;
    if( C in DIGITS ) then begin
      I := aOrder[Y];
      case X of
        1: I := I mod 100 + 100*(byte(C)-48);
        2: I := 100*(I div 100) + I mod 10 + 10*(byte(C)-48);
        3: I := 10*(I div 10) + byte(C)-48
      end;
      if( I >= 0 )and( I <= vMaxPatt ) then begin
        aOrder[Y] := I;
        if( I > Max ) then Max := I;
        Inc( X );
        if( X > 3 ) then begin
          SetX;
          GoDown
        end
      end
    end
    else if( C = #0 ) then begin
      C:= Read_Key;
      case byte(C) of
        kF1      : ST_ShowHelp( hcOrderEd );
        kRIGHT   : if( X < 3 ) then Inc( X );
        kLEFT    : if( X > 1 ) then Dec( X );
        kDOWN    : GoDown;
        kUP      : GoUp;
        kC_PGUP  : begin vOrdPage:=0; vOrdY:=0 end;
        kC_PGDN  : begin
                     vOrdY := ED_ORDLEN-1;
                     vOrdPage := MAXPATTERN-vOrdY-1
                   end;
        kC_HOME  : vOrdY := 0;
        kC_END   : vOrdY := ED_ORDLEN-1;
        kHOME    : repeat
                     GoUp
                   until( aOrder[Y] = 0 )or( Y = 1 );
        kEND     : repeat
                     GoDown
                   until( aOrder[Y] = 0 )or( Y = MAXPATTERN );
        kF3     : if( vMasterVolume > 0 ) then begin
                    Dec( vMasterVolume );
                    ED_PrintStat;
                  end;
        kF4     : if( vMasterVolume < 64 ) then begin
                    Inc( vMasterVolume );
                    ED_PrintStat;
                  end;
        kDEL     : begin
                     for I:=Y to MAXPATTERN-1 do
                       aOrder[I] := aOrder[I+1];
                     aOrder[MAXPATTERN] := 0;
                     SetMax
                   end;
        kINS     : begin
                     for I:=MAXPATTERN downto Y+1 do
                       aOrder[I] := aOrder[I-1];
                     aOrder[Y] := 0;
                     SetMax
                   end;
        kPGUP    : for I:=1 to ED_ORDLEN do
                     if( vOrdPage > 0 ) then
                       Dec( vOrdPage )
                     else if( vOrdY > 0 ) then
                       Dec( vOrdY );
        kPGDN    : for I:=1 to ED_ORDLEN do if( vOrdPage+vOrdY < MAXPATTERN-1 ) then
                     if( vOrdPage+ED_ORDLEN <= MAXPATTERN-1 ) then
                       Inc( vOrdPage )
                     else Inc( vOrdY );
        kC_F3    : if( vSpeed > 1 ) then begin
                     Dec( vSpeed );
                     Ed_PrintStat
                   end;
        kC_F4    : if( vSpeed < 12 ) then begin
                     Inc( vSpeed );
                     Ed_PrintStat
                   end;
        kF5..kF8 : begin
                     vChMask[byte(C)-kF5] := Not vChMask[byte(C)-kF5];
                     Ed_PrintChannels;
                   end;
        kA_V     : SBP_SetSTVolume;
        kA_P     : if( aOrder[Y] = 0 ) then
                     PrintErrorMsg( EMPTY_SONG )
                   else MyPlay( Y );
        kA_E     : if( Win_VideoType >= Win_EGA ) then begin
                     SetEga43( Not Ega43 );
                     NewVideoMode;
                     Ed_SetScreen;
                     Ed_PrintInfo( vPattNo );
                   end;
        kA_X     : C := #1;
        kA_L     : C := #2;
        kA_I     : C := #3;
        kA_O     : begin
                     I := DosShell;
                     Ed_SetScreen;
                     Ed_PrintInfo( vPattNo );
                     PrintErrorMsg( I )
                   end
      end
    end
    else case C of
      ^A       : DoSong( AddHalfNote );
      ^S       : DoSong( SubHalfNote )
    end
  until( C in [#1..#7,#9,#13,#27] );
  Ed_EditOrder := C
end;

function Ed_EditSong;
const
  IsOrder: boolean = FALSE;
var
  E, Res: word;
  C: char;
begin
  ST_SetupSamples;
  Ed_SetScreen;
  Ed_PrintInfo( vPattNo );
  repeat
    vTemp := aPattern[vPattNo]^;
    if( Not IsOrder ) then begin
      ST_StatusLine( S_EDIT );
      Res := Ed_EditTemp;
      aPattern[vPattNo]^ := vTemp;
    end
    else begin
      Ed_PrintPage( vPage );
      IsOrder := FALSE;
      Res := 1;
    end;
    case Res of
        1: begin
             C := Ed_EditOrder;
             case C of
               #13: if( aOrder[vOrdPage+vOrdY+1] > 0 ) then begin
                 vPattNo := aOrder[vOrdPage+vOrdY+1];  (* Selezione pattern *)
                 vCurX := 1;
                 vCurY := 0;
                 vPage := 0;
               end;
               #01..#03: begin
                 IsOrder := TRUE;
                 Res := byte( C )+100;
               end;
             end;
           end;
        2: if( vPattNo < vMaxPatt ) then begin
             Inc( vPattNo );
             vCurX := 1;
             vCurY := 0;
             vPage := 0
           end;
        3: if( vPattNo > 1 ) then begin
             Dec( vPattNo );
             vCurX := 1;
             vCurY := 0;
             vPage := 0
           end;
      106: begin  (* Clear song *)
             On_Message( 'Clear song (Y/n)?' );
             if( GetAnswer in [rYes,rEnter] ) then
               Ed_NewSong;
             Off_Message
           end;
      107: begin
             E := DosShell;
             Ed_SetScreen;
             Ed_PrintInfo( vPattNo );
             PrintErrorMsg( E )
           end;
      108: MyPlay( 0 );
      109: ST_ShowHelp( hcModEd );
      112: if( Win_VideoType >= Win_EGA ) then begin
             SetEga43( Not Ega43 );
             NewVideoMode;
             Ed_SetScreen
           end;
      114: ST_ShowHelp( hcModCmds );
    end
  until( Res > 100 );
  case Res of
    101 : Ed_EditSong := rExit;
    102 : Ed_EditSong := rLoad;
    103 : Ed_EditSong := rSample;
    104 : Ed_EditSong := rSaveMod;
    105 : Ed_EditSong := rSaveSng;
    110 : Ed_EditSong := rLoadPat;
    111 : Ed_EditSong := rSavePat;
    113 : Ed_EditSong := rShowInfo;
    else  Ed_EditSong := rOk
  end
end;

procedure Ed_Exit;
var I, J: word;
begin
  if( EMM_PattHandle = EMM_NIL ) then
    J := 1
  else J := 65;
  for I:=vMaxPatt downto J do
    Dispose( aPattern[I] )
end;

procedure Ed_SetColors;
begin
  case Video of
    0 : begin  (* Mono *)
          Ed_Palette[ED_HILITE] := $0F;
          Ed_Palette[ED_FRAME] := $07;
          Ed_Palette[ED_INFOFRAME] := $07
        end;
    1 : begin  (* CGA *)
          Ed_Palette[ED_HILITE] := $0B;
          Ed_Palette[ED_NORMAL] := $03
        end
  end
end;

begin
  vEditSound := TRUE;
  vOctave := 0
end.

(*
   Dr. Track
   File management (mods, songs, samples)
   CopyRight (c) 1991-1992,1993 Alessandro Scotti
*)
{$A+,B-,D+,E-,F-,I-,L+,N-,O-,R-,S-,V-,X+}
{$ifdef ST286}
{$G+}
{$else}
{$G-}
{$endif}

unit ST_File;

interface

function  F_LoadFile( FName: string ): word;
procedure F_LoadPattern( Index: byte; FName: string );
procedure F_LoadSample( Index: byte; FromLib: boolean );

procedure F_SaveModule( FName: string );
procedure F_SavePattern( Index: byte; FName: string );
function  F_SaveSample( Index: byte ): boolean;
function  F_SaveSong( FName: string ): boolean;

procedure F_TestSample( FName: string );

implementation uses Crt, ST_Dir, ST_Data, ST_Win, ST_Play;

const
  OctaveData : array[ 1..3, 1..12 ] of word = (
    ($358, $328, $2FA, $2D0, $2A6, $280, $25C, $23A, $21A, $1FC, $1E0, $1C5),
    ($1AC, $194, $17D, $168, $153, $140, $12E, $11D, $10D, $FE, $F0, $E2),
    ($D6, $CA, $BE, $B4, $AA, $A0, $97, $8F, $87, $7F, $78, $71)
  );
  MAXIDX        = 744;
  MAXSAMPLELEN  = 32767;  (* Massima lunghezza sample in word *)
  MINSAMPLELEN  = 0;      (* Minima lunghezza sample in byte *)
  READ_MODE     = 0;
  WRITE_MODE    = 1;
  ESC_CODE      = $80;    (* Codice escape per RLE pattern *)
type
  Buffer1K      = array[ 1..1024 ] of byte;
  Buffer1KPtr   = ^Buffer1K;
var
  OctaveRaw: array[ 1..12*3 ] of word absolute OctaveData;
  NoteIdx  : array[ 1..MAXIDX ] of byte;
  TempBuf  : array[ 1..512 ] of word;
  TempBufB : Buffer1K absolute TempBuf;
  SongType : word;
  Sign     : array[ 1..4 ] of byte;
  OrderLen : byte;
  PattNum  : byte;
  SampleNum: byte;
  Speed    : byte;
  Temp     : word;
  Error    : integer;

procedure F_InitTable;
var Ref, N, O, I, J: word;
begin
  Ref := $74;
  J := 12*3;
  N := 12;
  O := 3;
  for I:=1 to MAXIDX do begin
    NoteIdx[I] := O*16+N;
    if( $70+I >= Ref ) then begin
      if( J > 1 ) then begin
        Dec( J );
        Ref := OctaveRaw[J] + (OctaveRaw[J-1]-OctaveRaw[J]) div 2;
        Dec( N );
        if( N = 0 ) then begin
          Dec( O );
          N := 12
        end
      end
      else Ref := $358;
    end
  end
end;

function FRead( var F: file; var Buf; Len: word ): word;
var R: word;
begin
  BlockRead( F, Buf, Len, R );
  FRead := R
end;

function FWrite( var F: file; var Buf; Len: word ): word;
var R: word;
begin
  BlockWrite( F, Buf, Len, R );
  FWrite := R
end;

procedure CheckDrive( FName: string );
begin
  if( FName[2] = ':' ) then
    case FName[1] of
      'A' : Mem[ 0:$504 ] := 0;
      'B' : Mem[ 0:$504 ] := 1
    end
end;

procedure FormatFName( var S: string; Max: byte );
var L: byte absolute S;
    K, I: byte;
begin
  if( L > Max ) then begin
    if( S[2] = ':' ) then
      I := 3
    else I := 1;
    repeat
      Delete( S, I, 1 )
    until( L < Max-4 );
    if( Pos( '\', S ) > I ) then
      repeat
        Delete( S, I, 1 )
      until( Pos( '\', S ) = I );
    Insert( '\...', S, I )
  end
end;

function OpenError( I: integer ): byte;
begin
  case I of
    002 : OpenError := FILE_NOT_FOUND;
    003 : OpenError := PATH_NOT_FOUND;
    152 : OpenError := DRIVE_NOT_READY
    else  OpenError := CANNOT_OPEN
  end
end;

procedure MyFOpen( var F: file; FName: string; Mode: byte );
begin
  Error := IOResult;
  CheckDrive( FName );
  Assign( F, FName );
  if( FName = '' ) then
    Error := CANNOT_OPEN
  else begin
    if( Mode = READ_MODE ) then
      Reset( F, 1 )
    else ReWrite( F, 1 );
    Error := IOResult
  end;
  if( Error <> 0 ) then
    Error := OpenError( Error )
end;

procedure MySave( var F: file; var Buf; Len: word );
begin
  if( Error = 0 ) then
    if( FWrite( F, Buf, Len ) <> Len ) then
      Error := DISK_WRITE_ERROR
end;

procedure MyLoad( var F: file; var Buf; Len: word );
begin
  if( Error = 0 ) then
    if( FRead( F, Buf, Len ) <> Len ) then
      Error := DISK_READ_ERROR
end;

procedure MyCheck( Condition: boolean; ErrorCode: integer );
begin
  if( Error = 0 ) then
    if( Condition ) then
      Error := ErrorCode
end;

(* Converte un pattern SoundTracker nel formato usato internamente *)
procedure Mod2Pattern;
var I, L, K, M: word;
    N, O, S, C: byte;
    A: array[ 0..511 ] of word;
begin
  for I:=1 to 256 do begin
    L := TempBuf[I*2-1];
    M := TempBuf[I*2];
    L := Swap( L );
    M := Swap( M );
    if( SongType = 15 ) then
      S := M shr 12
    else S := ((L shr 12) * 16)+(M shr 12);
    L := L and $0FFF;
    N := 0;
    if( L <> 0 ) then begin
      if( L > $358 ) then
        L := $358
      else if( L < $71 ) then
        L := $71;
      N := NoteIdx[L-$70];
    end;
    if( S > 31 ) then begin
      N := 0;
      S := 0;
      M := 0
    end;
    TempBuf[I*2-1] := N+S*256;
    TempBuf[I*2] := Swap(M and $0FFF);
  end;
  for I:=0 to 63 do
    for L:=0 to 3 do begin
      A[L*128+I*2] := TempBuf[1+I*8+L*2];
      A[L*128+I*2+1] := TempBuf[2+I*8+L*2];
    end;
  Move( A, TempBuf, 1024 )
end;

procedure LoadHeader( var F: file );
var I, J, R: word;
    B: array[ 1..30 ] of byte;
    L: longint;
function CheckName( I: byte ): boolean;
  var J: byte;
  begin
    CheckName := FALSE;
    if( GlobalFlags and gfRELAXED = 0 ) then
      for J:=1 to 22 do
        if( aSample[I].Name[J] in [#1..#7,#10..#31,#127..#255] ) then Exit;
    CheckName := TRUE
  end;
begin
  if( Error <> 0 ) then Exit;
  L := FilePos( F );
  Seek( F, 20+15*30 );
  MyLoad( F, B, 30 );
  Seek( F, L );
  if( Error = 0 ) then begin
    SongType := 31;
    for I:=1 to 22 do
      if( B[I] < 32 )and( B[I] > 0 ) then SongType := 15;
    for I:=1 to SongType do if( Error = 0 ) then begin
      MyLoad( F, aSample[I].Name[1], 30 );
      aSample[I].Name[0] := #22;
      J := Length(aSample[I].Name );
      while( J >= 1 )and( aSample[I].Name[J] in [#0,' '] ) do
        Dec( J );
      Delete( aSample[I].Name, J+1, 255 );
      with aSample[I] do begin
        Len := Swap( Len );
        RepStart := Swap( RepStart );
        RepLen := Swap( RepLen );
        MyCheck( Len > MAXSAMPLELEN, SAMPLE_128k );
        Len := Len * 2;
        RepStart := RepStart * 2;
        RepLen := RepLen * 2;
        if( RepLen < 2 ) then
          RepLen := 2;
        MyCheck( Not CheckName( I ), UNKNOWN_TYPE )
      end
    end;
    SampleNum := 0;
    for I:=1 to SongType do
      with aSample[I] do
        if( Error = 0 )and( Len > MINSAMPLELEN ) then begin
          Inc( SampleNum );
          if( longint(RepLen)+longint(RepStart) > longint(Len) ) then
            if( RepStart < Len ) then
              RepLen := Len - RepStart
            else if( RepLen < RepStart ) then
              RepStart := Len - RepLen
            else begin
              RepLen := 2;
              RepStart := 0
            end
        end
        else aSample[I] := NULLSAMPLE
  end;
  if( Error <> 0 ) then
    Error := UNKNOWN_TYPE
end;

procedure LoadPatterns( var F: file );
var I: word;
begin
  if( Error = 0 ) then begin
    Print_Message( 'Loading patterns...' );
    PattNum := 0;
    for I:=1 to 128 do begin
      Inc( aOrder[I] );
      if( aOrder[I] > PattNum ) then
        PattNum := aOrder[I]
    end;
    MyCheck( PattNum > LASTPATTERN, TOO_MANY_PATTERNS );
    for I:=OrderLen+1 to MAXPATTERN do
      aOrder[I] := 0;
    for I:=1 to PattNum do begin
      MyLoad( F, TempBuf, 1024 );
      if( Error = 0 ) then begin
        Mod2Pattern;
        Move( TempBuf, aPattern[I]^, 1024 )
      end
    end
  end
end;

procedure LoadSamples( var F: file );
var
  I, R: word;
  P: ^byte;
begin
  for I:=1 to SongType do if( Error = 0 )and( aSample[I].Len > 0 ) then
    with aSample[I] do begin
      MyCheck( MaxRAM < Len, OUT_OF_MEMORY );
      if( Error <> 0 ) then Exit;
      Print_Message( 'Loading sample: "'+Name+'"' );
      GetMem( Address, Len );
(* Nota: in caso di errore questa memoria verr… deallocata in seguito *)
      BlockRead( F, Address^, Len, R );
      if( R = 0 ) then
        Error := DISK_READ_ERROR
      else if( R < Len ) then begin
        P := Address;
        Inc( P, R );
        FillChar( P^, Len-R, $80 );  (* Clear unloaded data *)
      end;
    end
end;

(* Trasforma i nomi Amiga in nomi adatti al DOS *)
procedure ParseAmigaName( Index: byte );
const
  (* The characters below are not valid in DOS filenames *)
  BadChars : string = '/\[]:;<>+=., ';
var S: string;
    I: byte;
    L: byte absolute S;
begin
  if( aSample[Index].Len = 0 ) then Exit;
  S := aSample[Index].Name;
  for I:=1 to L do
    S[I] := UpCase( S[I] );
  if( L >= 5 ) then
    if(Copy(S,1,3) = 'ST-')and(S[4] in ['0'..'9'])and(S[5] in ['0'..'9']) then
      Delete( S, 1, 5 );
  if( L >= 3 ) then
    if( Copy(S,1,2) = 'DF' )and( S[3] in ['0'..'1'] ) then
      Delete( S, 1, 3 );
  if( L >= 3 ) then
    if( Copy(S,L-2,3) = '.ST' )or( Copy(S,L-2,3) = '.SS' ) then
      Delete( S, L-2, 3 );
  for I:=1 to L do
    if( Pos(S[I],BadChars) > 0 )or( S[I] in [#127..#255] ) then
      S[I] := '\';
  while( Pos( '\', S ) > 0 ) do
    Delete( S, Pos( '\', S ), 1 );
  I := L;
  while( I >= L-2 )and( S[I] in ['0'..'9'] ) do
    Dec( I );
  if( L > 8 ) then
    S := Copy( Copy(S,1,I), 1, 8-L+I ) + Copy( S, I+1, 4 );
  if( S = '' ) then begin
    S := 'NONAMExx';
    S[7] := char(Temp div 10+48);
    S[8] := char(Temp mod 10+48);
    Inc( Temp )
  end;
  S := S + SAMPLE_EXT;
  aSample[Index].FileName := S;
  if( aSample[Index].Name = '' ) then
    aSample[Index].Name := '-';
  aSample[Index].PathName := vSampDir
end;

procedure F_LoadModule( var F: file );
var R: word;
begin
  On_Message( '            Loading header...            ' );
  MyLoad( F, vSongName[1], 20 );
  if( Error = 0 ) then begin
    vSongName[0] := #20;
    R := 20;
    while( R >= 1 )and( vSongName[R] in [#0,#32] ) do
      Dec( R );
    Delete( vSongName, R+1, 20 );
    LoadHeader( F );
    MyLoad( F, OrderLen, 1 );
    MyCheck( OrderLen > MAXPATTERN, TOO_MANY_PATTERNS );
    MyLoad( F, Speed, 1 );
    Speed := Speed div 20;
    if( Speed = 0 ) then Speed := 6;
    MyLoad( F, aOrder, 128 );
    if( SongType = 31 ) then
      MyLoad( F, Sign, 4 );
    LoadPatterns( F );
    LoadSamples( F )
  end;
  Off_Message;
  if( Error = 0 ) then begin
    Temp := 0;
    for R:=1 to SongType do
      ParseAmigaName( R )
  end
end;

(* Ritorna TRUE se si puo' scrivere su FName *)
function CheckOverWrite( FName: string ): boolean;
var F: file;
    I: integer;
begin
  CheckDrive( FName );
  CheckOverWrite := FALSE;
  MyFOpen( F, FName, READ_MODE );
  if( Error = 0 ) then begin
    Close( F );
    FormatFName( FName, 32 );
    On_Message( 'File '+FName+' already exists. Overwrite it (Y/n)?' );
    if( GetAnswer in [rYes,rEnter] ) then
      CheckOverWrite := TRUE;
    Off_Message
  end
  else if( Lo(Error) = FILE_NOT_FOUND ) then
    CheckOverWrite := TRUE
  else PrintErrorMsg( Lo(Error) );
  Error := 0
end;

function F_SaveSample( Index: byte ): boolean;
var F: file;
    I: integer;
    S: string;
begin
  F_SaveSample := TRUE;
  if( aSample[Index].Address = NIL ) then Exit;
  S := aSample[ Index ].PathName;
  if( S[1] = '=' ) then
    S := GF_SearchLibrary( Copy( S, 2, MAXPATHLEN ) );
  if( S = '' ) then
    S := vSampDir;
  S := MkFName( S, aSample[Index].FileName );
  if( Not CheckOverWrite( S ) ) then
    Exit;
  ST_StatusLine( S_WORK );
  F_SaveSample := FALSE;
  MyFOpen( F, S, WRITE_MODE );
  if( Error = 0 ) then begin
    On_Message( 'Saving ' + S + ' ...');
    with aSample[Index] do begin
      MySave( F, SAMPLE_ID, 10 );
      MySave( F, aSample[Index].Name, 31 );
      MySave( F, Address^, Len )
    end;
    Close( F );
    Off_Message;
    if( Error = 0 ) then begin
      aSample[Index].Saved := TRUE;
      F_SaveSample := TRUE
    end
  end;
  if( Error <> 0 ) then
    PrintErrorMsg( Lo(Error) )
end;

(**************** Load VOC, WAV, SMP *********************)

procedure MakeFName( var Sa: tSAMPLE; var FName: string );
var
  I: word;
begin
  I := Length( FName );
  while( I > 0 )and( FName[I] <> '\' ) do
    Dec( I );
  Inc( I );
  Sa.Name := Copy( FName, I, 8 );
  I := Pos( '.', Sa.Name );
  if( I > 0 ) then
    Delete( Sa.Name, I, 255 );
  Sa.FileName := Sa.Name + '.SMP';
end;

procedure MakeSigned( var Sa: tSAMPLE );
var
  P: ^byte;
  I: word;
begin
  P := Sa.Address;
  for I:=1 to Sa.Len do begin
    P^ := P^ xor 128;
    Inc( P );
  end;
end;

var
  TestSampleRate: word;

procedure LoadVOC( var F: file; var Sa: tSAMPLE; Index: word );
var
  Chk: string[20];
  VH: tVOCHDR;
  VD: tVOCDATA;
begin
  MyLoad( F, VH, SizeOf(VH) );
  Move( VH.Id, Chk[1], 20 );
  Chk[0] := #20;
  if( Chk = 'Creative Voice File'#$1A ) then begin
    MyLoad( F, VD, SizeOf(VD) );
    MyCheck( VD.Id <> 1, BAD_VOC );
    MyCheck( VD.LengthHi <> 0, BAD_VOC );
    MyCheck( VD.Length <= 2, BAD_VOC );
    MyCheck( MaxRAM < VD.Length-2, OUT_OF_MEMORY );
    TestSampleRate := 1000000 div (256-VD.Speed);
    if( Error = 0 ) then begin
      ClearSample( Index );
      Sa.Volume := $40;
      Sa.Unknown := 0;
      Sa.RepStart := 0;
      Sa.RepLen := 2;
      Sa.Name := '';
      Sa.Len := VD.Length-2;
      GetMem( Sa.Address, Sa.Len );
      MyLoad( F, Sa.Address^, Sa.Len );
      MakeSigned( Sa );
      if( Error = 0 ) then
        Sa.Saved := TRUE
      else FreeMem( Sa.Address, Sa.Len )
    end;
  end
  else Error := UNKNOWN_TYPE
end;

procedure LoadSMP( var F: file; var Sa: tSAMPLE; Index: word );
var
  Chk: string[10];
begin
  MyLoad( F, Chk, 10 );
  MyCheck( Chk <> SAMPLE_ID, UNKNOWN_TYPE );
  MyLoad( F, Sa, 31 );
  MyCheck( MaxRAM < Sa.Len, OUT_OF_MEMORY );
  if( Error = 0 ) then begin
    ClearSample( Index );
    GetMem( Sa.Address, Sa.Len );
    MyLoad( F, Sa.Address^, Sa.Len );
    if( Error = 0 ) then
      Sa.Saved := TRUE
    else FreeMem( Sa.Address, Sa.Len )
  end;
end;

{$I WAVE.INC}
procedure SeekForm( var F: file; var RC: TRiffChunk; Form: longint );
begin
  repeat
    MyLoad( F, RC, SizeOf(RC) );
    if( RC.FCC <> Form )and( Error = 0 ) then begin
      Seek( F, FilePos(F)+RC.Size );
    end;
  until( RC.FCC = Form )or( Error <> 0 );
end;

procedure LoadWAV( var F: file; var Sa: tSAMPLE; Index: word );
var
  FCC: longint;
  RC : TRiffChunk;
  WF : TWavePCM;
begin
  MyLoad( F, RC, SizeOf(RC) );
  MyCheck( RC.FCC <> FCC_RIFF, UNKNOWN_TYPE );
  MyLoad( F, FCC, SizeOf(FCC) );
  MyCheck( FCC <> FORM_WAVE, BAD_WAVE );
  SeekForm( F, RC, FORM_WFMT );
  MyLoad( F, WF, SizeOf(WF) );
  MyCheck( (WF.FormatTag <> 1) or (WF.Channels <> 1) or (WF.BlockAlign <> 1), BAD_WAVE );
  TestSampleRate := WF.SamplesPerSec;
  SeekForm( F, RC, FORM_WDAT );
  MyCheck( RC.Size > 65500, SAMPLE_128K );
  MyCheck( MaxRAM < RC.Size, OUT_OF_MEMORY );
  if( Error = 0 ) then begin
    Sa.Volume := $40;
    Sa.Unknown := 0;
    Sa.RepStart := 0;
    Sa.RepLen := 2;
    Sa.Name := '';
    Sa.Len := RC.Size;
    ClearSample( Index );
    GetMem( Sa.Address, Sa.Len );
    MyLoad( F, Sa.Address^, Sa.Len );
    MakeSigned( Sa );
    if( Error = 0 ) then
      Sa.Saved := TRUE
    else FreeMem( Sa.Address, Sa.Len )
  end;
end;

function DoLoadSample( Index: byte; FName: string ): byte;
var F: file;
    C: char;
    I: word;
    Sa: tSample;
begin
  Sa := NULLSAMPLE;
  MyFOpen( F, FName, READ_MODE );
  if( Error = 0 ) then begin
    MyLoad( F, C, 1 );
    if( Error = 0 ) then begin
      Seek( F, 0 );
      case C of
        'C': LoadVOC( F, Sa, Index );
        #09: LoadSMP( F, Sa, Index );
        'R': LoadWAV( F, Sa, Index );
        else Error := UNKNOWN_TYPE;
      end;
    end;
    Close( F );
  end;
  if( Error = 0 ) then begin
    if( Sa.Name = '' ) then
      MakeFName( Sa, FName );
    aSample[Index] := Sa;
  end;
  DoLoadSample := Lo( Error )
end;

procedure F_TestSample( FName: string );
const
  SN = MAXSAMPLE+1;
  Octaves: array[ 1..24 ] of byte = (
    $21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,
    $31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C );
var
  Sa: tSample;
begin
  TestSampleRate := 8000;
  aSample[SN].Address := NIL;
  if( DoLoadSample( SN, FName ) = 0 ) then begin
    ST_SetSample( 1, aSample[SN].Address, aSample[SN].Len, 0, 2, 64 );
    ST_PlaySolo;
    (* Set approximate note *)
    if( TestSampleRate <= 8500 ) then
      ST_SetSoloNote( $21, 1 )
    else if( TestSampleRate > 34000 ) then
      ST_SetSoloNote( $3C, 1 )
    else
      ST_SetSoloNote(
        Octaves[ longint(TestSampleRate-8500)*24 div 25500+1], 1 );
    repeat until( KeyPressed );
    ST_Stop;
    ClearSample( SN );
  end
  else PrintErrorMsg( Lo(Error) );
  with aSample[1] do
    ST_SetSample( 1, Address, Len, RepStart, RepLen, Volume );
end;

procedure F_LoadSample( Index: byte; FromLib: boolean );
var P, S: string;
    I: byte;
begin
  P := vSampDir;
  if( FromLib ) then begin
    P := GF_SearchLibrary( GF_GetLibrary );
    if( P = '' ) then Exit
  end;
  ST_StatusLine( S_SAMPLOAD );
  S := GF_GetFileName( P, vSampMask, ' Load sample ' );
  if( Copy( S, 1, 2 ) <> '..' ) then begin
    if( Length(P) > MAXPATHLEN ) then
      PrintErrorMsg( PATH_TOO_LONG )
    else begin
      ST_StatusLine( S_WORK );
      I := DoLoadSample( Index, MkFName( P, S ) );
      if( I = 0 ) then begin
        aSample[Index].PathName := P;
      end
      else PrintErrorMsg( I )
    end
  end
end;

(* Converte un pattern dal formato interno al formato Amiga *)
procedure Pattern2Mod( Index: byte );
var T, F: byte;
    P: tPattern;
    N: tNote;
    I, W: word;
begin
  P := aPattern[Index]^;
  for T:=1 to 4 do begin
    for F:=0 to 63 do begin
      N := P[T][F];
      I := (T-1)*2 + F*8 + 1;
      W := N.Sample and $F0;
      if( N.Note = 0 ) then
        TempBuf[I] := W
      else TempBuf[I] := Swap( (W shl 8) or OctaveData[N.Note shr 4, N.Note and $0F] );
      W := (N.Sample shl 4) or N.Command;
      TempBuf[I+1] := Swap( (W shl 8) or N.Info )
    end
  end
end;

procedure CheckSongData( var SampleInfo: string );
var I, J, K: byte;
    P: tPattPtr;
begin
  OrderLen := 0;
  repeat
    Inc( OrderLen )
  until( aOrder[OrderLen] = 0 )or( OrderLen = MAXPATTERN );
  if( aOrder[OrderLen] = 0 ) then
    Dec( OrderLen );
  PattNum := 0;
  for K:=1 to OrderLen do
    if( aOrder[K] > PattNum ) then
      PattNum := aOrder[K];
  SampleInfo[0] := #32;
  FillChar( SampleInfo[1], 32, ' ' );
  MyCheck( OrderLen = 0, EMPTY_SONG );
  if( Error = 0 ) then for I:=1 to PattNum do begin
    P := aPattern[I];
    for J:=1 to 4 do
      for K:=0 to 63 do
        SampleInfo[ 1+P^[J][K].Sample and 31 ] := '.'
  end;
  for I:=1 to MAXSAMPLE do if( Error = 0 ) then
    if( SampleInfo[I+1] = '.' )and( aSample[I].Address = NIL ) then begin
      ErrorCode := I;
      Error := MISSING_SAMPLE
    end
end;

procedure F_SaveModule( FName: string );
const
  MOD_ID : string[4] = 'M.K.';
var F: file;
    J, K: byte;
    S: tSample;
    A: array[ 1..128 ] of byte;
    SampleInfo: string[32];
begin
{$ifdef STDEMO}
  OutMsg( 'Sorry, but you need the registered version to save a module...' );
{$else}
  if( Not CheckOverWrite( FName ) ) then Exit;
  CheckSongData( SampleInfo );
  if( Error = 0 ) then
    MyFOpen( F, FName, WRITE_MODE );
  if( Error = 0 ) then begin
    On_Message( 'Building SoundTracker module...' );
    for K:=Length(vSongName)+1 to 20 do
      vSongName[K] := #0;
    MySave( F, vSongName[1], 20 );  (* Nome modulo *)
    for J:=1 to MAXSAMPLE do begin
      if( SampleInfo[J+1] = '.' ) then
        S := aSample[J]
      else S := NULLSAMPLE;
      with S do begin
        for K:=Length(Name)+1 to 22 do
          Name[K] := #0;
        Len := Swap( Len shr 1 );
        RepStart := Swap( RepStart shr 1 );
        RepLen := Swap( RepLen shr 1 )
      end;
      MySave( F, S.Name[1], 30 );  (* Header dei sample *)
    end;
    MySave( F, OrderLen, 1 );  (* Numero totale pattern da suonare *)
    if( vSpeed <= 12 ) then
      K := vSpeed * 20
    else K := 255;
    MySave( F, K, 1 );  (* Velocit… globale *)
    FillChar( A, 128, 0 );
    Move( aOrder, A, OrderLen );
    for K:=1 to OrderLen do
      Dec( A[K] );
    MySave( F, A, 128 );  (* Elenco pattern *)
    MySave( F, MOD_ID[1], 4 );
    if( Error = 0 ) then
      for K:=1 to PattNum do begin
        Pattern2Mod( K );
        MySave( F, TempBuf, 1024 )  (* Dati pattern *)
      end;
    for K:=1 to MAXSAMPLE do
      if( SampleInfo[K+1] = '.' ) then
        MySave( F, aSample[K].Address^, aSample[K].Len );  (* Sample *)
    Off_Message;
    Close( F )
  end;
  if( Error <> 0 ) then
    PrintErrorMsg( Lo(Error) )
  else vModify := FALSE
{$endif}
end;

(* Salva i pattern in formato compresso *)
procedure ShrinkPattern( var F: file; Index: byte );
var Count, I, J: word;
    ZeroCount: byte;
    P: tPattPtr;
procedure OutN( N: tNote );
  begin
    Move( N, TempBufB[Count+1], 4 );
    Inc( Count, 4 )
  end;
procedure OutB( B: byte );
  begin
    Inc( Count );
    TempBufB[Count] := B
  end;
procedure MyRLE( N: tNote );
  begin
    if( N.Note or N.Sample or N.Command or N.Info = 0 ) then begin
      Inc( ZeroCount );
      if( ZeroCount = 127 ) then begin
        OutB( ZeroCount or ESC_CODE );
        ZeroCount := 0
      end
    end
    else begin
      if( ZeroCount > 0 ) then
        OutB( ZeroCount or ESC_CODE );
      OutN( N );
      ZeroCount := 0
    end
  end;
begin
  if( Error <> 0 ) then Exit;
  Count := 0;
  ZeroCount := 0;
  P := aPattern[Index];
  for I:=1 to 4 do
    for J:=0 to 63 do
      MyRLE( P^[I][J] );
  if( ZeroCount > 0 ) then
    OutB( ZeroCount or ESC_CODE );
  MySave( F, Count, 2 );
  MySave( F, TempBufB, Count )
end;

function F_SaveSong;
var F: file;
    J, K: byte;
    S: array[ 1..MAXSAMPLE ] of boolean;
begin
{$ifdef STDEMO}
  OutMsg( 'Oops! This command does not work in this demo version...' );
{$else}
  if( Not CheckOverWrite( FName ) ) then Exit;
  MyFOpen( F, FName, WRITE_MODE );
  if( Error = 0 ) then begin
    On_Message( 'Saving song...' );
    MySave( F, SONG_ID, 10 );  (* Identificatore song *)
    MySave( F, vSongName, 21 );  (* Nome modulo *)
    MySave( F, vSpeed, 1 );
    for J:=1 to MAXSAMPLE do
      if( aSample[J].Address = NIL ) then
        S[J] := FALSE
      else S[J] := TRUE;
    MySave( F, S, MAXSAMPLE );  (* Informazioni sui sample utilizzati *)
    for J:=1 to MAXSAMPLE do if( S[J] ) then begin
      MySave( F, aSample[J].FileName, 13 );  (* Nome file sample *)
      MySave( F, aSample[J].PathName, MAXPATHLEN + 1 )  (* Path sample *)
    end;
    MySave( F, aOrder, MAXPATTERN );  (* Array ordine pattern da suonare *)
    PattNum := 0;
    for K:=1 to MAXPATTERN do
      if( aOrder[K] > PattNum ) then
        PattNum := aOrder[K];
    for K:=1 to PattNum do
      ShrinkPattern( F, K );  (* Pattern in formato compresso *)
    Off_Message;
    Close( F )
  end;
  if( Error <> 0 ) then begin
    F_SaveSong := FALSE;
    PrintErrorMsg( Lo(Error) )
  end
  else begin
    vModify := FALSE;
    F_SaveSong := TRUE
  end;
{$endif}
end;

procedure MyLoadSample( Index: byte; FName: string );
label Loop;
var R, X: byte;
    S: string;
    C: char;
begin
  if( Error = 0 ) then begin
Loop:
    R := DoLoadSample( Index, FName );
    if( R in [CANNOT_OPEN,DRIVE_NOT_READY,FILE_NOT_FOUND,PATH_NOT_FOUND] ) then begin
      Win_Open( 7, 9, 73, 15, MSGWINATTR );
      Win_SetCursorSize( Win_CRSOFF );
      ClrScr;
      Win_Border( DOUBLEBORDER, MSGWINATTR );
      Win_Shadow( $08 );
      S := 'Sample ' + FName + ' not found.';
      Win_WriteAt( (80-Length(S)) div 2, 11, S, MSGATTR );
      Win_WriteAt( 13, 12, 'Please insert the correct disk and press ENTER to retry', MSGATTR );
      Win_WriteAt( 17, 13, '(ESC aborts operation, "S" skips this sample).', MSGATTR );
      repeat C:=UpCase(ReadKey) until( C in [#13,#27,'S'] );
      Win_Close;
      case C of
        #13 : goto Loop;
        #27 : Error := SAMPLE_NOT_FOUND;
        'S' : Error := SKIP_SAMPLE
      end
    end
    else Error := R
  end
end;

procedure UnshrinkPattern( var F: file; Index: byte );
var P: Buffer1KPtr;
    Count, OutCount, I, W: word;
    B: byte;
begin
  P := Buffer1KPtr( aPattern[Index] );
  MyLoad( F, Count, 2 );
  MyLoad( F, TempBufB, Count );
  if( Error <> 0 ) then Exit;
  OutCount := 1;
  I := 1;
  while( I <= Count )and( OutCount <= 1024 )and( Error = 0 ) do begin
    B := TempBufB[I];
    if( B and ESC_CODE <> 0 ) then begin
      Inc( I );
      B := B and byte(Not ESC_CODE);
      W := B * 4;
      if( OutCount + W <= 1025 ) then begin
        FillChar( P^[OutCount], W, 0 );
        Inc( OutCount, W )
      end
      else Error := BAD_DATA
    end
    else begin
      Move( TempBufB[I], P^[OutCount], 4 );
      Inc( OutCount, 4 );
      Inc( I, 4 )
    end
  end;
  if( OutCount <> 1025 ) then Error := BAD_DATA
end;

procedure F_LoadSong( var F: file );
var Chk: string[12];
    S: array[ 1..MAXSAMPLE ] of boolean;
    J: byte;
    N: string12;
    D: string[MAXPATHLEN];
    P: stringPath;
begin
  MyLoad( F, Chk, 10 );
  MyLoad( F, vSongName, 21 );
  MyLoad( F, vSpeed, 1 );
  MyLoad( F, S, MAXSAMPLE );
  On_Message( '   Loading samples...   ' );
  for J:=1 to MAXSAMPLE do if( S[J] )and( Error = 0 ) then begin
    MyLoad( F, N, 13 );
    MyLoad( F, D, MAXPATHLEN+1 );
    if( Length(N) > 12 )or( Length(D) > MAXPATHLEN ) then
      Error := BAD_DATA
    else begin
      P := D;
      if( P[1] = '=' ) then
        P := GF_SearchLibrary( Copy( P, 2, MAXPATHLEN ) );
      if( P = '' ) then
        P := vSampDir;
      MyLoadSample( J, MkFName( P, N ) );
      if( Error <> SKIP_SAMPLE ) then begin
        aSample[J].FileName := N;
        aSample[J].PathName := D
      end
      else Error := 0
    end
  end;
  if( Error = 0 ) then begin
    Print_Message( 'Loading patterns...' );
    MyLoad( F, aOrder, MAXPATTERN );
    PattNum := 0;
    for J:=1 to MAXPATTERN do
      if( aOrder[J] > PattNum ) then
        PattNum := aOrder[J];
    for J:=1 to PattNum do
      UnshrinkPattern( F, J );
  end;
  Off_Message
end;

function F_LoadFile( FName: string ): word;
var F: file;
    Chk: string[12];
begin
  MyFOpen( F, FName, READ_MODE );
  MyLoad( F, Chk, 10 );
  Seek( F, 0 );
  if( Error = 0 ) then begin
    if( Chk = SONG_ID ) then
      F_LoadSong( F )
    else F_LoadModule( F );
    Close( F )
  end;
  F_LoadFile := Lo(Error)
end;

procedure F_LoadPattern( Index: byte; FName: string );
var
  F: file;
  P: tPattPtr;
  S: string[12];
begin
  MyFOpen( F, FName, READ_MODE );
  New( P );
  P^ := aPattern[Index]^;
  MyLoad( F, S, 10 );
  MyCheck( S <> PATTERN_ID, UNKNOWN_TYPE );
  UnshrinkPattern( F, Index );
  Close( F );
  if( Error = 0 ) then
    Dispose( P )
  else begin
    aPattern[Index]^ := P^;
    PrintErrorMsg( Lo(Error) )
  end
end;

procedure F_SavePattern( Index: byte; FName: string );
var
  F: file;
begin
  MyFOpen( F, FName, WRITE_MODE );
  MySave( F, PATTERN_ID, 10 );
  ShrinkPattern( F, Index );
  Close( F );
  if( Error <> 0 ) then
    PrintErrorMsg( Lo(Error) )
end;

begin
  F_InitTable
end.

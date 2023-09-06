(*
   Dr. Track
   CopyRight (c) 1991-1992,1993 Alessandro Scotti
*)
{$ifdef STIDE}
{$A+,B-,D+,E-,F-,G+,I-,L+,N-,O-,R-,S-,V-,X+}
{$else}
{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S-,V-,X+}
{$endif}

{$ifdef ST286}
{$G+}
{$else}
{$G-}
{$endif}

unit ST_Data;
interface

{$I KEYCODES.INC}

const
{$ifdef STDEMO}
  COPYRIGHTMSG = 'Dr. Track 1.40 (Demo version) - Copyright (c) 1991-93 Alessandro Scotti';
{$else}
  COPYRIGHTMSG = 'Dr. Track 1.40 - Copyright (c) 1991-93 Alessandro Scotti';
{$endif}
  COPYRIGHTATTR    : byte = $7A;
  HISTATUSLINEATTR : byte = $74;

  FILE_NOT_FOUND   = 1;  (* Codici di errore *)
  UNKNOWN_TYPE     = 2;
  OUT_OF_MEMORY    = 3;
  DISK_READ_ERROR  = 4;
  TOO_MANY_PATTERNS= 5;
  SAMPLE_128K      = 6;
  DRIVE_NOT_READY  = 7;
  PATH_NOT_FOUND   = 8;
  DISK_WRITE_ERROR = 9;
  CANNOT_OPEN      = 10;
  SAMPLE_NOT_FOUND = 11;
  PATH_TOO_LONG    = 12;
  BAD_DATA         = 13;
  SKIP_SAMPLE      = 14;
  EMPTY_SONG       = 15;
  MISSING_SAMPLE   = 16;
  HELP_NOT_FOUND   = 17;
  HELP_CORRUPTED   = 18;
  SHELL_NOTFOUND   = 19;
  SHELL_OUTOFMEM   = 20;
  SHELL_ERROR      = 21;
  LIB_NOT_FOUND    = 22;
  NOT_SBPRO        = 23;
  BAD_VOC          = 24;
  BAD_WAVE         = 25;

  MAXSAMPLE        = 31;
  MAXPATTERN       = 128;
  LASTPATTERN      : byte = MAXPATTERN;
  MSGWINATTR       : byte = $7F;
  MSGATTR          : byte = $70;
  MAXMASKLEN       = 32;
  MAXPATHLEN       = 32;
  SONG_ID          : string[9] = '##SONG##'+#$1A;
  SAMPLE_ID        : string[9] = '#SAMPLE#'+#$1A;
  PATTERN_ID       : string[9] = 'PATTERN#'+#$1A;
  SAMPLE_EXT       = '.SMP';
  PATTERN_EXT      = '.PAT';
  SONG_EXT         = '.DTS';

  S_EDIT           = 0;  (* Codici per la "status line" *)
  S_ORDER          = 1;
  S_SAMPLE         = 2;
  S_SEDIT          = 3;
  S_SPATHEDIT      = 4;
  S_LOAD           = 5;
  S_WORK           = 6;
  S_PLAY           = 7;
  S_CHECK          = 8;
  S_WAITAKEY       = 9;
  S_SETVOL         = 10;
  S_MACROKEY       = 11;
  S_SAMPLOAD       = 12;
  S_LIBRARY        = 13;
  S_HELP           = 14;
type
  ReturnType = (
    rYes, rNo, rLoad, rSample, rEscape, rEnter, rOk,
    rExit, rSaveSng, rSaveMod, rSavePat, rLoadPat, rShowInfo
  );
  tString     = string[22];
  string12    = string[12];
  stringPath  = string[MAXPATHLEN];
  tSample = record
    Name    : tString;
    Len     : word;
    Unknown : byte;
    Volume  : byte;
    RepStart: word;
    RepLen  : word;  (* I campi precedenti non devono essere modificati! *)
    Address : pointer;
    FileName: string12;
    PathName: stringPath;
    Saved   : boolean
  end;
  tVOCHDR = record
    Id      : array[ 1..20 ] of char;
    DataOfs : word;
    Version : word;
    Check   : word;
  end;
  tVOCDATA = record
    Id      : byte;
    Length  : word;
    LengthHi: byte;
    Speed   : byte;
  end;
  tNote   = record
    Note    : byte;     (* Ottava*16+Nota, da $11 a $3C *)
    Sample  : byte;
    Command : byte;
    Info    : byte
  end;
  tTrack  = array[ 0..63 ] of tNote;
  tPattern= array[ 1..4 ] of tTrack;
  tPattPtr= ^tPattern;
const
  NULLNOTE   : tNote = (Note:0;Sample:0;Command:0;Info:0);
  NULLSAMPLE : tSample = (
    Name:'';Len:0;Unknown:0;Volume:0;RepStart:0;RepLen:2;
    Address:NIL;FileName:'';PathName:'';Saved:FALSE
  );
const
  vMasterVolume: byte = 64;

var
  vSongName : string[22];
  vFileName : string[12];
  vDir      : string[80];
  vMask     : string[MAXMASKLEN];
  vSampDir  : string[80];
  vWorkPath : string[80];
  vWorkFile : string[12];
  vSampMask : string[MAXMASKLEN];
  vPattMask : string[MAXMASKLEN];
  vModify   : boolean;
  vSpeed    : byte;
  vPattNo   : byte;
  vOctave   : byte;
  ErrorCode : word;
  aOrder  : array[ 1..MAXPATTERN ] of byte;
  aPattern: array[ 1..MAXPATTERN ] of tPattPtr;
  aSample : array[ 1..MAXSAMPLE+1 ] of tSample;

  LastStatus : byte;
  Ega43      : boolean;

const
  gfSTART43  = 1;
  gfRELAXED  = 2;
  gfLARGE    = 4;
  gfEMS      = 8;
  gfGRAPH    = 16;
  gfPROMPT   = 32;
var
  GlobalFlags: word;
  EMM_PattHandle: word;

function DosShell: word;
function GetAnswer: ReturnType;
function MaxRAM: longint;
function MkFName( Dir, Name: string ): string;
function Padded( S: string; N: byte ): string;
function ST_LineEdit( X, Y, MAXSCR, MAXLEN: byte; var S: string; Cmd: string; Help: word ): byte;
function ST_KeyToNote( C: char ): byte;
function Spaces( Count: byte ): string;
function w2s( W: word ): string;
procedure ClearSample( Index: byte );
procedure DoClearSamples;
procedure Off_Message;
procedure On_Message( Msg: string );
procedure OutMsg( Msg: string );
procedure Print_Message( Msg: string );
procedure PrintErrorMsg( Error: word );
procedure ST_SetupSamples;
procedure ST_SetColors( Video: byte );
procedure ST_ShowInfo;
procedure ST_StatusLine( Status: byte );
function StrUpr( S: string ): string;
procedure SetEga43( F: boolean );
procedure VLine( X, Y1, Y2, A: byte; S: string );
procedure WaitAKey;

procedure NewVideoMode;
procedure OldVideoMode;

implementation uses Crt, Dos, ST_Win, ST_Play, ST_Hyper, ST_SBPro;

const
  SYSTEMRAM = 12*1024;  (* Memoria riservata al programma (finestre, ecc.) *)
  MSGY      = 10;

  LE_Palette : array[ 0..2 ] of byte = ( $2F, $1F, $1A );

function MaxRAM: longint;  (* Memoria disponibile *)
begin
  MaxRAM := MaxAvail - SYSTEMRAM
end;

function MkFName( Dir, Name: string ): string;
begin
  if( Dir[Length(Dir)] <> '\' ) then
    Dir := Dir + '\';
  MkFName := Dir + Name
end;

function Spaces( Count: byte ): string;
var S: string;
begin
  S[0] := char(Count);
  FillChar( S[1], Count, ' ' );
  Spaces := S
end;

(*
    Line-editor.
    X, Y, MAXSCR, MAXLEN = coordinate video, max lunghezza video e stringa
    S = stringa da editare
    Cmd = stringa comandi.
    Help = schermata di help da invocare alla pressione di F1.
    Formato stringa comandi:
      [@] + [tasto_ascii + ['S'|'E']]* + '|' + [tasto_scan + ['S'|'E']]*
    Esempi:
      #13'S'+#27'E'+'|'
    = esci con Return (e salva) o Escape (abbandona);
      #13'S'+#27'E'+'|'+char(kDOWN)+'S'+char(kUP)+'S'
    = come sopra per gli ascii pi— cursore alto e basso (salvando);
      '@' + ...
    = forza uppercase.
    Output:
      il numero del comando ascii che ha provocato l'uscita o
      100 + il numero del comando "scan".
    Esempio: se Cmd Š come sopra
      #13 esce con 1
      #27 esce con 2
      kDOWN esce con 101
      kUP   esce con 102
*)
function ST_LineEdit;
const
  LETTERS = ['0'..'9','a'..'z','A'..'Z','_'];
var
  OS: string;
  L: byte absolute S;
  PosScan, A, I: byte;
  Page, PosX: byte;
  C: char;
  First, Stop: boolean;
  OldCrsSize: word;
procedure EndKey;
  begin
    Page := 0;
    PosX := L+1;
    if( L > MAXSCR ) then begin
      Page := L+1-MAXSCR;
      PosX := MAXSCR;
    end;
  end;
procedure HomeKey;
  begin Page := 0; PosX := 1; end;
function Index: byte;
  begin Index := Page + PosX; end;
procedure RightKey;
  begin if( PosX < MAXSCR ) then Inc( PosX ) else Inc( Page ); end;
procedure LeftKey;
  begin if( PosX > 1 ) then Dec( PosX ) else Dec( Page ); end;
begin
  OldCrsSize := Win_GetCursorSize;
  Win_SetCursorSize( Win_CRSON );
  OS := S;
  PosScan := Pos( '|', Cmd );
  First := TRUE;
  Stop := FALSE;
  Dec( MAXSCR );
  HomeKey;

  while( Not Stop ) do begin
    if( First )and( (Index > 1)or( S <> OS )) then
      First := FALSE;
    A := LE_Palette[ 1 ];
    if( First ) then
      A := LE_Palette[ 0 ];
    if( Page > 0 ) then
      Win_WriteAt( X, Y, '', LE_Palette[ 2 ] )
    else Win_WriteAt( X, Y, ' ', LE_Palette[ 1 ] );
    Win_WriteAt( X+1, Y, Copy( S, Page+1, MAXSCR ), A );
    if( Page+MAXSCR <= L ) then
      Win_WriteAt( X+MAXSCR, Y, '', LE_Palette[ 2 ] )
    else Win_WriteAt( X+1+L-Page, Y, Spaces( MAXSCR+Page-L ), LE_Palette[ 1 ] );
    asm
      push  bp
      mov   ah, $0F
      int   $10         (* Get current page *)
      pop   bp
      push  bp
      mov   dh, [Y]
      dec   dh
      mov   dl, [X]
      add   dl, [PosX]
      dec   dl
      mov   ah, $02
      int   $10         (* Set cursor position for current page *)
      pop   bp
    end;
    repeat
    until( KeyPressed );
    C := ReadKey;
    if( Pos( '@', Cmd ) = 1 ) then
      C := UpCase( C );

    I := Pos( C, Cmd );
    if( I > 0 )and( I < PosScan )and( Not Odd(PosScan-I) ) then begin
      if( Cmd[ I+1 ] <> 'S' ) then S := OS;
      ST_LineEdit := 1 + I shr 1 - Pos( '@', Cmd );
      Stop := TRUE;
    end
    else if( C in [ #32..#127 ] ) then begin
      if( First ) then
        S := '';
      if( L < MAXLEN ) then begin
        Insert( C, S, Index );
        RightKey;
      end
    end
    else case C of
      #08 : if( Index > 1 ) then begin
              if( Page > 0 ) then
                Dec( Page )
              else Dec( PosX );
              Delete( S, Index, 1 )
            end;
      #00 : begin
        C := ReadKey;
        I := Pos( C, Cmd );
        if( I > 0 )and( I > PosScan )and( Odd( I-PosScan) ) then begin
          if( Cmd[I+1] <> 'S' ) then S := OS;
          ST_LineEdit := 101+(I-PosScan) shr 1;
          Stop := TRUE;
        end
        else case byte(C) of
          kF1    : ST_ShowHelp( Help );
          kDEL   : if( Index <= L ) then
                     Delete( S, Index, 1 );
          kLEFT  : if( Index > 1 ) then LeftKey;
          kRIGHT : if( Index <= L ) then RightKey;
          kHOME  : HomeKey;
          kEND   : EndKey;
          kC_HOME: begin
                     Delete( S, 1, Index-1 );
                     HomeKey;
                   end;
          kC_END : begin
                     Delete( S, Index, MAXLEN );
                     EndKey;
                   end;
          kC_LEFT  : begin
                       while( Index > 1 )and Not( S[Index-1] in LETTERS ) do
                         LeftKey;
                       while( Index > 1 )and( S[Index-1] in LETTERS ) do
                         LeftKey;
                     end;
          kC_RIGHT : if( Index <= L ) then begin
                       repeat
                         RightKey;
                       until( Index > L )or Not( S[Index] in LETTERS );
                       while( Index <= L )and Not( S[Index] in LETTERS ) do
                         RightKey;
                     end;
            end
      end
    end;
  end;
  Win_SetCursorSize( OldCrsSize );
end;

procedure Init_Variables;
var I: word;
begin
  for I:=1 to MAXSAMPLE do
    aSample[I] := NULLSAMPLE;
  for I:=1 to MAXPATTERN do begin
    aPattern[I] := NIL;
    aOrder[I] := 0
  end
end;

(* Stampa un messaggio nella finestra aperta con On_Message *)
procedure Print_Message( Msg: string );
var X: byte;
begin
  X := ( 80 - Length(Msg) - 6 ) div 2;
  ClrScr;
  Win_WriteAt( X+4, MSGY+2, Msg, MSGATTR )
end;

(* Apre e centra una finestra col messaggio Msg *)
procedure On_Message( Msg: string );
var X: byte;
begin
  X := ( 80 - Length(Msg) - 6 ) div 2 + 1;
  Win_Open( X, MSGY, X+Length(Msg)+5, MSGY+4, MSGWINATTR );
  Win_SetCursorSize( Win_CRSOFF );
  ClrScr;
  Win_Border( DOUBLEBORDER, MSGWINATTR );
  Win_Shadow( $08 );
  Window( X+1, MSGY+1, X+Length(Msg)+4, MSGY+3 );
  Print_Message( Msg )
end;

procedure Off_Message;
begin
  Win_Close
end;

procedure WaitAKey;  (* Attende un tasto *)
var C: char;
    S: byte;
begin
  S := LastStatus;
  ST_StatusLine( S_WAITAKEY );
  while( KeyPressed ) do C:=ReadKey;
  C := ReadKey;
  while( KeyPressed ) do C:=ReadKey;
  ST_StatusLine( LastStatus )
end;

procedure OutMsg( Msg: string );
begin
  On_Message( Msg );
  WaitAKey;
  Off_Message
end;

procedure ClearSample( Index: byte );
begin
  if( aSample[Index].Address <> NIL ) then
    FreeMem( aSample[Index].Address, aSample[Index].Len );
  aSample[Index] := NULLSAMPLE
end;

procedure DoClearSamples;
var I: byte;
begin
  for I:=1 to MAXSAMPLE do
    ClearSample( I );
end;

function GetAnswer: ReturnType;
var C: char;
    S: byte;
begin
  S := LastStatus;
  ST_StatusLine( S_CHECK );
  repeat
    C := UpCase(ReadKey)
  until( C in ['Y','N',#13,#27] );
  case C of
    'Y' : GetAnswer := rYes;
    'N' : GetAnswer := rNo;
    #13 : GetAnswer := rEnter;
    else  GetAnswer := rEscape
  end;
  ST_StatusLine( S )
end;

procedure VLine( X, Y1, Y2, A: byte; S: string );
var I: byte;
begin
  MemW[ Win_VIDEOSEG:(X-1)*2+(Y1-1)*160 ] := A shl 8 + byte(S[1]);
  MemW[ Win_VIDEOSEG:(X-1)*2+(Y2-1)*160 ] := A shl 8 + byte(S[2]);
  for I:=Y1 to Y2-2 do
    MemW[ Win_VIDEOSEG:(X-1)*2+I*160 ] := A shl 8 + byte(S[3])
end;

function w2s;  (* Trasforma una word in string *)
var S: string;
begin
  Str( W, S );
  w2s := S
end;

(* Aggiusta la lunghezza di S ad N caratteri aggiungendo spazi alla fine *)
function Padded( S: string; N: byte ): string;
begin
  if( N <= Length(S) ) then
    Padded := Copy( S, 1, N )
  else Padded := S + Spaces( N-Length(S) )
end;

procedure PrintErrorMsg( Error: word );
begin
  if( Error = 0 ) then Exit;
  Sound( 800 );
  Delay( 50 );
  NoSound;
  case Error of
    FILE_NOT_FOUND   : OutMsg( 'File not found.' );
    OUT_OF_MEMORY    : OutMsg( 'Out of memory.' );
    UNKNOWN_TYPE     : OutMsg( 'File type not recognized.' );
    TOO_MANY_PATTERNS: OutMsg( 'Module contains too many patterns.' );
    DISK_READ_ERROR  : OutMsg( 'Disk read error.' );
    SAMPLE_128K      : OutMsg( 'Sample too long.' );
    DRIVE_NOT_READY  : OutMsg( 'Drive not ready.' );
    DISK_WRITE_ERROR : OutMsg( 'Disk write error.' );
    CANNOT_OPEN      : OutMsg( 'Error opening file.' );
    PATH_NOT_FOUND   : OutMsg( 'Path not found.' );
    PATH_TOO_LONG    : OutMsg( 'Sample path is too long.' );
    MISSING_SAMPLE   : OutMsg( 'Sample #'+w2s(ErrorCode)+' is used but undefined.' );
    SKIP_SAMPLE,
    SAMPLE_NOT_FOUND : ;
    EMPTY_SONG       : OutMsg( 'Order list is empty.' );
    BAD_DATA         : OutMsg( 'File contains corrupted data.' );
    HELP_NOT_FOUND   : OutMsg( 'Cannot open help file.' );
    HELP_CORRUPTED   : OutMsg( 'Help file is corrupted.' );
    SHELL_NOTFOUND   : OutMsg( 'Cannot find command interpreter.' );
    SHELL_OUTOFMEM   : OutMsg( 'Not enough memory to shell.' );
    SHELL_ERROR      : OutMsg( 'Unidentified DOS error.' );
    LIB_NOT_FOUND    : OutMsg( 'No library available.' );
    NOT_SBPRO        : OutMsg( 'This function is only available with a SoundBlaster Pro.' );
    BAD_VOC          : OutMsg( 'Cannot handle this VOC file.' );
    BAD_WAVE         : OutMsg( 'Cannot handle this WAVE file.' );
    else               OutMsg( 'I/O error.' )
  end
end;

procedure ST_SetupSamples;
var I: byte;
begin
  ST_InitSamples;
  for I:=1 to MAXSAMPLE do with aSample[I] do
    if( Address <> NIL ) then
      ST_SetSample( I, Address, Len, RepStart, RepLen, Volume );
end;

(* Alloca/dealloca memoria per lo shell *)
procedure SetMemTop( P: pointer );
begin
  asm
    les   bx, P
    add   bx, $000F
    mov   cl, 4
    shr   bx, cl
    mov   ax, es
    add   bx, ax
    mov   ax, [PrefixSeg]
    sub   bx, ax
    mov   es, ax
    mov   ah, $4A
    int   21h
  end
end;

function DosShell: word;
var W: word;
    E: integer;
begin
  SetMemTop( HeapPtr );
  W := Win_GetCursorSize;
  Win_SetCursorSize( Win_CRSON );
  OldVideoMode;
  WriteLn( 'Type EXIT to return...' );
  SwapVectors;
  Exec( GetEnv('COMSPEC'), '' );
  E := DosError;
  SwapVectors;
  NewVideoMode;
  Win_SetCursorSize( W );
  SetMemTop( HeapEnd );
  if( E <> 0 ) then case E of
    2, 3: DosShell := SHELL_NOTFOUND;
    8   : DosShell := SHELL_OUTOFMEM
    else  DosShell := SHELL_ERROR
  end
  else DosShell := 0
end;

procedure SetEga43( F: boolean );
begin
  Ega43 := F and (Win_VideoType >= Win_EGA)
end;

procedure NewVideoMode;
var NewMode: integer;
begin
  if( Win_VideoType = Win_MDA ) then
    NewMode := MONO
  else begin
    NewMode := CO80;
    if( Ega43 ) then
      NewMode := NewMode or Font8x8
  end;
  Win_TextMode( NewMode );
  DisableEGABlinking;
  Win_SetVideoSeg;
  TextAttr := $07;
  ClrScr
end;

procedure OldVideoMode;
begin
  Win_OldTextMode;
  EnableEGABlinking;
  ClrScr
end;

procedure ST_StatusLine( Status: byte );
var S, T: string;
    I, A: byte;
begin
  LastStatus := Status;
  case Status of
    S_EDIT      : S := '% ^F1% Help  ^Alt-C% Clear  ^Alt-I% Instruments  ^Alt-L% Load  ^Alt-S% Save  ^Alt-X% Exit';
    S_ORDER     : S := '% ^F1% Help  ^Alt-P% Play';
    S_SAMPLE    : S := '% ^F1% Help  ^Alt-A %Save all  ^Alt-B %Library  ^Alt-C %Clear  ^Alt-L %Load  ^Alt-S %Save';
    S_SEDIT     : S := '% ^F1% Help  ^Alt-S% Save';
    S_SPATHEDIT : S := '% ^F1% Help  ^Alt-B% Library  ^Alt-D% Restore default  ^Alt-S% Save';
    S_LOAD      : S := '% ^Alt-P% Change path/mask';
    S_SAMPLOAD  : S := '% ^Space% Test sample  ^Alt-I% Toggle info  ^Alt-P% Change path/mask';
    S_WORK      : S := '% Working...';
    S_PLAY      : begin
      S := '% ^F1% Help  ^Alt-E% Toggle 43/50 lines  ^Alt-F% Fade out  ^Alt-O% Shell';
      if( SBC_IsPro ) then
        S := S + '  ^Alt-V% Volume';
    end;
    S_CHECK     : S := '% Check ³ Please confirm your choice';
    S_WAITAKEY  : S := '% Pause ³ Press any key to continue';
    S_MACROKEY  : S := '% ^F1% Help';
    S_LIBRARY   : S := '% Select a sample library';
    S_HELP      : S := '% ^F1% Help on help  ^Alt-F1% Previous topic';
    S_SETVOL    : S := '% Cursor keys and hilighted letters change values, ENTER confirms, ESC aborts.';
    else          S := ''
  end;
  T := '';
  for I:=1 to Length( S ) do
    case S[I] of
      '%' : A := $70;
      '^' : A := HISTATUSLINEATTR
      else  T := T + S[I] + char(A)
    end;
  while( Length( T ) < 160 ) do
    T := T + ' ' + #$70;
  if( Ega43 ) then
    I := Win_TextRows
  else I:= 24;
  MoveToScreen( T[1], Ptr( Win_VIDEOSEG, I*160 )^, 160 )
end;

procedure ST_SetColors;
begin
  case Video of
    0 : begin  (* Mono *)
          HISTATUSLINEATTR := $7F
        end
  end
end;

function ST_KeyToNote( C: char ): byte;
const
  KEYB : string = 'ZSXDCVGBHNJMzsxdcvgbhnjmQ2W3ER5T6Y7U';
var
  I, O, N: byte;
begin
  N := 0;
  if( Pos( UpCase(C), 'QWERTYU' ) > 0 ) then
    C := UpCase( C );
  case C of
    ',': C := 'Q';
    ';': C := 'z'
  end;
  I := Pos( C, KEYB );
  if( I > 0 ) then begin
    I := I - 1;
    O := ((I div 12) + vOctave) mod 3 + 1;
    N := O shl 4 + I mod 12 + 1;
  end;
  ST_KeyToNote := N
end;

procedure ST_ShowInfo;
const
  Y   = 8;
  MAX = 60;
  HEI = 6;
  MYX = 15;
var
  X, Wid: byte;
  S: string;
procedure MyWrite( Y: byte; S: string );
  begin
    if( Length(S) > Wid-MYX-1 ) then
      S := Copy( S, 1, Wid-MYX-1-3 ) + '...';
    Win_WriteAt( X+MYX, Y, S, MSGATTR )
  end;
begin
  Wid := Length(vDir);
  if( Length(vSampDir) > Wid ) then
    Wid := Length(vSampDir);
  if( Length(vWorkPath) > Wid ) then
    Wid := Length(vWorkPath);
  Str( MaxRAM, S );
  S := S + ' bytes';
  if( Length(S) > Wid ) then
    Wid := Length(S);
  Wid := Wid + MYX + 1;
  if( Wid > MAX ) then
    Wid := Max;
  X := (80 - Wid) shr 1 + 1;
  Win_Open( X, Y, X+Wid, Y+HEI, MSGWINATTR );
  Win_SetCursorSize( Win_CRSOFF );
  ClrScr;
  Win_Shadow( $08 );
  Win_Border( DOUBLEBORDER, MSGWINATTR );
  Win_WriteAt( X+1, Y, ' Info ', MSGWINATTR );
  Win_WriteAt( X+2, Y+1, 'Free memory:', MSGATTR );
  Win_WriteAt( X+2, Y+3, '   Song dir:', MSGATTR );
  Win_WriteAt( X+2, Y+4, ' Sample dir:', MSGATTR );
  Win_WriteAt( X+2, Y+5, '   Work dir:', MSGATTR );
  MyWrite( Y+3, vDir );
  MyWrite( Y+4, vSampDir );
  MyWrite( Y+5, vWorkPath );
  MyWrite( Y+1, S );
  WaitAKey;
  Win_Close
end;

(* Converts a string to uppercase *)
function StrUpr( S: string ): string; assembler;
asm
  push  ds
  lds   si, [S]
  les   di, @Result
  cld
  lodsb
  stosb
  cbw
  mov   cx, ax
  jcxz  @@Exit
@@Loop:
  lodsb
  cmp   al, 'a'
  jb    @@PutChar
  cmp   al, 'z'
  ja    @@PutChar
  sub   al, 'a'-'A'
@@PutChar:
  stosb
  loop  @@Loop
@@Exit:
  pop   ds
end;

begin
  Init_Variables
end.

(*
   Dr. Track
   CopyRight (c) 1991-1992,1993 Alessandro Scotti

   4-track music composer for SoundBlaster featuring:

   > 4 digitalized channels (SoundTracker compatible)
   > real-time recording and test mode
   > 4-voice background player
   > complete sample management
   > support for EGA/VGA BIOS enhancements (43/50 line mode, full colors)
   > context sensitive hypertextual help
   > macro recording and playback
   > sample libraries
   > EMS support
   > complete support for SB Pro (stereo and mixer control)
   > graphics in text mode
   > VOC and WAVE support
   > antivirus check
   > it's free (from version 1.40 onward)
   > and more...

   Last update:  09 Oct 1993

   Notes:
   - define ST286 to enable 80286 instructions;
   - define STIDE if running inside Turbo Pascal IDE;
   - define STDEMO to compile the demo version.

*)
{$define ST286}

{$ifdef STIDE}
{$A+,B-,D+,E-,F-,I-,L+,N-,O-,R-,S-,V-,X+}
{$else}
{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S-,V-,X+}
{$endif}

{$ifdef ST286}
{$G+}
{$else}
{$G-}
{$endif}

{$M 6144,0,655360}      (* 6K stack, max memory *)
program DrTrack;
uses Crt,       (* TP CRT unit *)
     Dos,       (* TP DOS unit *)
     Sbc,       (* SoundBlaster tools *)
     Crc,       (* Unit to compute the CRC of a file *)
     Ems,       (* EMM manager *)
     Env,       (* Access to DOS environment *)
     ST_Dir,    (* File/lib selection *)
     ST_Win,    (* Windows manager *)
     ST_Edit,   (* Song editor/player *)
     ST_File,   (* File I/O *)
     ST_Data,   (* Global data and functions *)
     ST_Samp,   (* Sample manager *)
     ST_Play,   (* Hi-level interface to ASM functions *)
     ST_Hyper,  (* Help system *)
     ST_Graph,  (* Graphics support in text mode *)
     ST_SBPro;  (* SoundBlaster Pro additional routines *)

const
{$ifdef STIDE}
  MINRAM        = 80*256;
{$else}
  MINRAM        = 256*1024;
{$endif}
const
  DetectSBPro   : boolean = TRUE;
  ForceSBPro    : boolean = FALSE;
type
  StatusType    = ( sNull, sExit, sEdit, sSample, sLoad );
var
  SavedExitProc : pointer;

(* Changes the prompt *)
procedure EnvPrompt( Code: byte );
const
  OldPrompt: string[128] = '';
begin
{$ifdef STIDE}
  Exit;
{$endif}
  if( GlobalFlags and gfPROMPT = 0 ) then Exit;
  case Code of
    0: begin
         OldPrompt := envGetStr( envGetCurSeg, 'PROMPT' );
         envSetStr( envGetCurSeg, 'PROMPT', '[DRT] '+OldPrompt );
       end;
    1: if( OldPrompt <> '' ) then envSetStr( envGetCurSeg, 'PROMPT', OldPrompt );
  end;
end;

(* Write an error message and exit *)
procedure Abort( Msg: string );
begin
  ST_RemoveHook;
  WriteLn( Msg );
  EnvPrompt( 1 );
  ExitProc := NIL;
  Halt( 1 )
end;

(* Critical error handler, exit gently... *)
procedure MyExitProc; far;
begin
  ST_Stop;
  ST_RemoveHook;
  stgDone;
  EnvPrompt( 1 );
  if( EMM_PattHandle <> EMM_NIL ) then
    EMM_FreeMemory( EMM_PattHandle );
  TextMode( CO80 );
  if( ErrorAddr <> NIL ) then begin
    WriteLn( 'A critical error occurred (code: ', ExitCode, ', at: ', Seg(ErrorAddr^), ',', Ofs(ErrorAddr^), ').' );
    WriteLn( 'Additional info: prefix = ', PrefixSeg, ', stack = ', SSeg, ',', SPtr );
    WriteLn( 'Please keep note of the data above and contact the author.' );
    ExitCode := 1;
    ErrorAddr := NIL
  end;
  ExitProc := SavedExitProc
end;

(* Read configuration file *)
procedure ReadCFG( var Speed, Video: byte );
const
  SONGDIRLEN    = 64;
  SAMPDIRLEN    = 32;
  ConfigFile    = 'DRT.CFG';
type
  ConfigRec = record
    Port: word;
    IRQ: word;
    Song: string[SONGDIRLEN];
    Sample: string[SAMPDIRLEN];
    Color: word;
    Speed: word;
    Pref: word
  end;
var
  Config: ConfigRec;
  F: file;
  W: word;
  S: string;
begin
  Assign( F, MkFName( vWorkPath, ConfigFile ) );
  Reset( F, 1 );
  W := IOResult;
  if( W = 0 ) then begin
    BlockRead( F, Config, SizeOf(Config), W );
    if( W = SizeOf(Config) ) then begin
      if( Config.Port <> 0 ) then
        SBC_Port := $200 + Config.Port shl 4;
      case Lo(Config.IRQ) of
        1 : SBC_IRQ := 2;
        2 : SBC_IRQ := 3;
        3 : SBC_IRQ := 5;
        4 : SBC_IRQ := 7
      end;
      vDir := StrUpr( Config.Song );
      vSampDir := StrUpr( Config.Sample );
      Video := Config.Color;
      Speed := Config.Speed;
      GlobalFlags := Config.Pref
    end;
    Close( F )
  end
end;

(* Parse the command line, handle some switches *)
procedure ParseCmdLine;
type
  PString = ^string;
var
  S: string;
  I: byte;
begin
  S := PString( Ptr( PrefixSeg, $80 ) )^;
  I := 1;
  repeat
    if( S[I] = '/' ) then case UpCase(S[I+1]) of
      'G' : case S[I+2] of
              '+': if( Win_VideoType >= Win_VGA ) then stgValid := TRUE;
              '-': stgValid := FALSE;
            end;
      'E' : GlobalFlags := GlobalFlags or gfSTART43;
      'R' : GlobalFlags := GlobalFlags or gfRELAXED;
      'L' : LASTPATTERN := 128;
      'X' : GlobalFlags := GlobalFlags or gfEMS;
      'P' : case S[I+2] of
              '+': begin ForceSBPro := TRUE; end;
              '-': begin ForceSBPro := FALSE; DetectSBPro := FALSE; end;
              else Abort( 'Invalid option. Type DRT /? for help.' );
            end;
      'D' : case S[I+2] of
              '+': GlobalFlags := GlobalFlags or gfPROMPT;
              '-': GlobalFlags := GlobalFlags and (not gfPROMPT);
            end;
      '?',
      'H' : begin
              WriteLn( COPYRIGHTMSG );
              WriteLn( #13#10'Options: ' );
              WriteLn( '  /G[+|-]: enable/disable graphics (VGA only)'#13#10+
                       '  /E     : start in 43/50 line mode (EGA/VGA only)'#13#10+
                       '  /R     : relaxed error checking on external modules' );
              WriteLn( '  /L     : large model (up to 128 different patterns)'#13#10+
                       '  /X     : use expanded memory' );
              WriteLn( '  /P[+|-]: force/disable use of SoundBlaster Pro'#13#10+
                       '  /D[+|-]: enable/disable custom prompt in shell' );
              Abort( '' )
            end
      else  Abort( 'Invalid switch. Type DRT /? for help.' )
    end;
    Inc( I )
  until( I >= Length(S) )
end;

(* Try to allocate an EMS handle *)
procedure Alloc_EMM( var Handle: word; Pages: word );
begin
  Handle := EMM_NIL;
  if( EMM_GetStatus <> 0 ) then Exit;
  Handle := EMM_GetMemory( 4 );
  if( EMM_Result <> 0 ) then
    Handle := EMM_NIL
  else EMM_SetName( Handle, 'Dr.Track' );
end;

(* Initialization *)
procedure InitSystem;
var N: NameStr;
    E: ExtStr;
    Speed, Video: byte;
begin
  if( MaxAvail < MINRAM ) then
    Abort( 'Not enough memory to run.' );
  FSplit( ParamStr(0), vWorkPath, N, E );
  vWorkFile := N + E;
  vMask := '*.NST,*.MOD,*'+SONG_EXT;
  vSampMask := '*'+SAMPLE_EXT+',*.VOC,*.WAV';
  vPattMask := '*'+PATTERN_EXT;
  vDir := '';
  vSampDir := '';
  GlobalFlags := gfPROMPT or gfGRAPH;
  SBC_Port := 0;
  SBC_IRQ := 0;
  Video := Win_VideoType;
  Speed := MAXSPEED;
  LASTPATTERN := 64;
  ReadCFG( Speed, Video );
  if( Video >= Win_VGA )and( GlobalFlags and gfGRAPH <> 0 ) then
    stgValid := TRUE;
  if( vDir = '' ) then
    vDir := vWorkPath;
  if( vSampDir = '' ) then
    vSampDir := Copy( vWorkPath, 1, 31 );
  if( GlobalFlags and gfLARGE <> 0 ) then
    LASTPATTERN := 128;
  ParseCmdLine;
  if( SBC_Port = 0 ) then
    if( SBC_DetectCard and 4 = 0 ) then
      Abort( 'SoundBlaster Card not found.' );
  if( SBC_IRQ = 0 ) then
    if( SBC_DetectInt = 0 ) then
      Abort( 'Unable to detect SBC interrupt.' );
  if( Not SBC_ResetDSP ) then
    Abort( 'Unable to initialize SoundBlaster Card.' );
  if( ForceSBPro = TRUE ) then
    SBC_IsPro := TRUE
  else if( DetectSBPro ) then
    SBC_IsPro := SBC_DetectPro;
  if( Mem[0:$484] >= 42 )or( GlobalFlags and gfSTART43 <> 0 ) then
    Ega43 := TRUE
  else Ega43 := FALSE;
  EMM_PattHandle := EMM_NIL;
  if( GlobalFlags and gfEMS <> 0 ) then begin
    if( EMM_GetStatus = 0 ) then
      if( EMM_GetVersion >= $32 ) then begin
        Alloc_EMM( EMM_PattHandle, 4 );
        if( EMM_PattHandle = EMM_NIL ) then begin
          WriteLn( 'Unable to use EMS memory.' );
          Delay( 1000 )
        end
      end
  end;
  SetEga43( Ega43 );
  NewVideoMode;
  EnvPrompt( 0 );
  GF_ReadLibConfig( 'DRT.LIB' );
{$ifdef STIDE}
  HH_Init( 'D:\TP\DRT.HLP' );
{$else}
  HH_Init( MkFName( vWorkPath, 'DRT.HLP' ) );
{$endif}
  ST_SetupSound( Speed, SBC_IsPro );
  ED_SetColors( Video );
  SA_SetColors( Video );
  ST_SetColors( Video );
  ST_OnOffSpeaker( 1 );
  Ed_Init;
  Ed_NewSong;
  SA_NewSong
end;

(* Check exit *)
function CheckExit: ReturnType;
begin
  On_Message( 'Exit to DOS, are you sure (Y/n)?' );
  CheckExit := GetAnswer;
  Off_Message
end;

(* Set file extension utility *)
function SetExt( FName: string; Ext: string ): string;
var I: byte;
begin
  I := Pos( '.', FName );
  if( I > 0 ) then
    Delete( FName, I, 255 );
  SetExt := FName + Ext
end;

(* Check save *)
function CheckSave: ReturnType;
var S: ReturnType;
begin
  if( vModify ) then begin
    On_Message( 'Save this song (Y/n)?' );
    S := GetAnswer;
    Off_Message;
    CheckSave := S;
    if( S in [rYes,rEnter] ) then
      if( Not F_SaveSong( MkFName(vDir,SetExt(vFileName,SONG_EXT)) ) ) then
        CheckSave := rEscape
  end
  else CheckSave := rOk
end;

(* Select and load a file *)
procedure MyLoadFile;
const
  curDir: string[80] = '';
var
  P: string[80];
  S: string[16];
  R: word;
  L: byte;
begin
  if( curDir = '' ) then
    curDir := vDir;
  P := curDir;
  ST_StatusLine( S_LOAD );
  S := GF_GetFileName( P, vMask, ' Open a file ' );
  if( Copy( S, 1, 2 ) <> '..' ) then begin
    curDir := P;
    if( CheckSave = rEscape ) then Exit;
    ST_StatusLine( S_WORK );
    Ed_NewSong;
    SA_NewSong;
    Ed_SetScreen;
    DoClearSamples;
    R := F_LoadFile( MkFName( P, S ) );
    if( R <> 0 ) then begin
      PrintErrormsg( R );
      Ed_NewSong;
      DoClearSamples
    end
    else vFileName := S
  end
end;

(* Select and load a single pattern *)
procedure MyLoadPattern;
var P: string;
    S: string[16];
begin
  P := vDir;
  ST_StatusLine( S_LOAD );
  S := GF_GetFileName( P, vPattMask, ' Read a pattern from disk ' );
  if( Copy( S, 1, 2 ) <> '..' ) then begin
    ST_StatusLine( S_WORK );
    F_LoadPattern( vPattNo, MkFName( P, S ) )
  end
end;

(* Save a single pattern *)
procedure MySavePattern;
var S: string;
    X, L: byte;
begin
  Str( vPattNo, S );
  if( Length( S ) = 3 ) then
    X := 46
  else X := 45;
  On_Message( ' Write pattern #'+S+' to              ' );
  Window( 1, 1, 80, 25 );
  S := 'PATT_'+S+PATTERN_EXT;
  L := ST_LineEdit( X, 12, 14, 12, S, '@'#27'E'#13'S|', H_NULL );
  Off_Message;
  if( L = 2 ) then
    F_SavePattern( vPattNo, MkFName( vDir, S ) )
end;

(* Shutdown and prepare for exit *)
procedure ShutDown;
begin
  ST_PlaySolo;
  Delay( 100 );
  ST_Stop;
  ST_OnOffSpeaker( 0 );
  Delay( 100 );
  SBC_ResetDSP;
  Ed_Exit;
  if( EMM_PattHandle <> EMM_NIL ) then begin
    EMM_FreeMemory( EMM_PattHandle );
    if( EMM_Result <> 0 ) then begin
      WriteLn( 'Unable to release expanded memory.' );
      Delay( 1000 )
    end
  end;
  EnvPrompt( 1 );
  OldVideoMode
end;

(* Save current file as .MOD or .DTS *)
procedure MySaveFile( Flag: boolean );
begin
  ST_StatusLine( S_WORK );
  if( Flag ) then
    F_SaveModule( MkFName( vDir, SetExt( vFileName, '.MOD' ) ) )
  else F_SaveSong( MkFName( vDir, SetExt( vFileName, SONG_EXT ) ) )
end;

(* Run the doctor *)
procedure Run;
var S: StatusType;
    T: string;
begin
  S := sEdit;
  while( S <> sExit ) do begin
    case S of
      sEdit  : case Ed_EditSong of
                 rExit   : if( CheckSave <> rEscape ) then
                             if( CheckExit in [rYes,rEnter] ) then
                               S := sExit;
                 rLoad   : MyLoadFile;
                 rSaveMod: MySaveFile( TRUE );
                 rSaveSng: MySaveFile( FALSE );
                 rSavePat: MySavePattern;
                 rLoadPat: MyLoadPattern;
                 rShowInfo:ST_ShowInfo;
                 rSample : begin
                             ClrScr;
                             S := sSample
                           end
               end;
      sSample: begin
                 Edit_Samples;
                 ClrScr;
                 S := sEdit
               end
    end
  end
end;

(* Check if DRT already installed (we might be in a shell) *)
procedure CheckHook;
var L: longint;
    V, C: word;
begin
  L := ST_CheckHook;
  C := L and $FFFF;
  V := L shr 16;
  if( C <> 0 ) then begin
    case C of
      1 : begin
            WriteLn( 'DRT ', Hi(V), '.', Lo(V), ' is already in memory.' );
            WriteLn( 'Type EXIT at the DOS prompt...' )
          end;
      2 : WriteLn( 'DRTP ', Hi(V), '.', Lo(V), ' is playing, cannot run DRT right now!' )
    end;
    Halt( 0 )
  end
end;

(* Reboot utility *)
procedure ReBoot; assembler;
asm
  xor   ax, ax
  dec   ax
  push  ax
  inc   ax
  push  ax
  retf          (* Same as "jmp FFFF:0000", but funny *)
end;

(* Check file CRC *)
procedure CheckCRC;
var
  F: file;
  Crc1, Crc2: word;
  W: word;
  Chk: boolean;
begin
  Chk := FALSE;
  Assign( F, ParamStr(0) );
  Reset( F, 1 );
  if( IOResult = 0 ) then begin
    Crc1 := CRC_File( F, FileSize(F)-2 );
    if( not CRC_IOError ) then begin
      Seek( F, FileSize(F)-2 );
      BlockRead( F, Crc2, 2, W );
      if( W = 2 ) then Chk := (Crc1 = Crc2);
    end;
    Close( F );
  end;
  if( not Chk ) then begin
    WriteLn( 'Antivirus check: DRT.EXE has been modified!' );
    WriteLn( 'Press [B] to reboot now or any other key to exit to DOS.' );
    if( UpCase( ReadKey ) = 'B' ) then
      Reboot
    else begin
      Abort( 'Program halted.' );
    end;
  end;
end;

begin
  CheckBreak := FALSE;
  CheckHook;
  SavedExitProc := ExitProc;
  ExitProc := @MyExitProc;
  if( Lo(DosVersion) < 3 ) then
    Abort( 'Incorrect DOS version (use 3.0 or later).' );
  WriteLn( 'Initializing...' );
{$ifndef STIDE}
  CheckCRC;
{$endif}
  InitSystem;
  ST_InstallHook;
  Run;
  ST_RemoveHook;
  ShutDown;
  ExitProc := NIL;
  Halt( 0 );
end.

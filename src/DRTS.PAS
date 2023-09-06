(*
   Dr. Track Setup
   CopyRight (c) 1991-1992,1993 Alessandro Scotti
*)
{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S-,V-,X+}
program DRTSetup;
uses Objects, Drivers, Views, Menus, Dialogs, App, MsgBox;

const
  cmNull        = 200;
  cmSBDialog    = 201;
  cmDirDialog   = 202;
  cmColorDialog = 203;
  cmSpeedDialog = 204;
  cmAbout       = 205;
  cmReadCfg     = 206;
  cmWriteCfg    = 207;
  cmPreferences = 208;
  cmExit        = 209;
  cmOptionMenu  = 210;
type
  TMyApp = object(TApplication)
    procedure HandleEvent( var Event: TEvent ); virtual;
    procedure InitMenuBar; virtual;
    procedure InitStatusLine; virtual;
    procedure SBDialog;
    procedure DirDialog;
    procedure ColorDialog;
    procedure SpeedDialog;
    procedure Preferences;
    procedure ReadConfig;
    procedure WriteConfig;
    procedure About;
  end;

const
  SONGDIRLEN    = 64;
  SAMPDIRLEN    = 32;
  ConfigFile    = 'DRT.CFG';

type
  SbDataRec = record
    Port: word;
    IRQ: word;
  end;

  DirDataRec = record
    Song: string[SONGDIRLEN];
    Sample: string[SAMPDIRLEN];
  end;

  ColorDataRec = record
    Value: word;
  end;

  SpeedDataRec = record
    Value: word;
  end;

  PrefDataRec = record
    Flags: word
  end;

  ConfigRec = record
    SB: SbDataRec;
    Dir: DirDataRec;
    Color: ColorDataRec;
    Speed: SpeedDataRec;
    Pref: PrefDataRec
  end;
var
  Config: ConfigRec;

procedure TMyApp.HandleEvent( var Event: TEvent );
begin
  TApplication.HandleEvent( Event );
  if Event.What = evCommand then begin
    case Event.Command of
      cmSBDialog: begin
        SBDialog;
        end;
      cmDirDialog: begin
        DirDialog;
        end;
      cmColorDialog: begin
        ColorDialog;
        end;
      cmSpeedDialog: begin
        SpeedDialog;
        end;
      cmAbout: About;
      cmPreferences: begin
        Preferences;
        end;
      cmReadCfg: ReadConfig;
      cmWriteCfg: WriteConfig;
      cmExit    : begin
        WriteConfig;
        Event.What := evCommand;
        Event.Command := cmQuit;
        PutEvent( Event );
        end;
    else
      Exit;
    end;
    ClearEvent(Event);
  end;
end;

procedure TMyApp.InitMenuBar;
var R: TRect;
begin
  GetExtent( R );
  R.B.Y := R.A.Y + 1;
  MenuBar := New( PMenuBar, Init( R, NewMenu(
    NewItem( '~ð~', '', kbNoKey, cmAbout, hcNoContext,
    NewSubMenu( '~F~ile', hcNoContext, NewMenu(
      NewItem( '~S~ave options', 'F2', kbF2, cmWriteCfg, hcNoContext,
      NewItem( '~R~etrieve options', 'F3', kbF3, cmReadCfg, hcNoContext,
      NewLine(
      NewItem( 'S~a~ve and exit', 'F4', kbF4, cmExit, hcNoContext,
      NewItem( 'E~x~it', 'Alt-X', kbAltX, cmQuit, hcNoContext,
      NIL)))))),
    NewSubMenu( '~O~ptions', hcNoContext, NewMenu(
      NewItem( 'Sound~B~laster', '', kbNoKey, cmSBDialog, hcNoContext,
      NewItem( '~C~olor set', '', kbNoKey, cmColorDialog, hcNoContext,
      NewItem( '~D~irectories', '', kbNoKey, cmDirDialog, hcNoContext,
      NewItem( '~P~references', '', kbNoKey, cmPreferences, hcNoContext,
      NewItem( '~S~peed', '', kbNoKey, cmSpeedDialog, hcNoContext,
      NIL)))))),
    NIL)))
  )));
end;

procedure TMyApp.InitStatusLine;
var R: TRect;
begin
  GetExtent( R );
  R.A.Y := R.B.Y - 1;
  StatusLine := New( PStatusLine, Init( R,
    NewStatusDef( 0, $FFFF,
      NewStatusKey('', kbF10, cmMenu,
      NewStatusKey( '~F2~ Save', kbF2, cmWriteCfg,
      NewStatusKey( '~F3~ Load', kbF3, cmReadCfg,
      NewStatusKey( '~F4~ Save and exit', kbF4, cmExit,
      NewStatusKey( '~F10~ Menu', kbF10, cmMenu,
      NIL))))),
    NIL)
  ));
end;

procedure TMyApp.SBDialog;
var
  Dummy: PView;
  Dialog: PDialog;
  R: TRect;
  C: word;
begin
  R.Assign( 20, 4, 60, 18 );
  Dialog := New( PDialog, Init( R, 'SoundBlaster' ) );
  with Dialog^ do begin
    R.Assign( 3, 3, 18, 10 );
    Dummy := New( PRadioButtons, Init( R,
      NewSItem( '~D~etect',
      NewSItem( '2~1~0h',
      NewSItem( '2~2~0h',
      NewSItem( '2~3~0h',
      NewSItem( '2~4~0h',
      NewSItem( '2~5~0h',
      NewSItem( '2~6~0h',
      NIL)))))))
    ));
    Dummy^.Options := Dummy^.Options and (not ofPostProcess);
    Insert( Dummy );
    R.Assign( 2, 2, 16, 3 );
    Insert( New( PLabel, Init( R, 'Base address', Dummy )));
    R.Assign( 22, 3, 37, 9 );
    Dummy := New( PRadioButtons, Init( R,
      NewSItem( '~D~etect',
      NewSItem( '~2~',
      NewSItem( '~3~',
      NewSItem( '~5~',
      NewSItem( '~7~',
      NewSItem( '~10~',
      NIL))))))
    ));
    Dummy^.Options := Dummy^.Options and (not ofPostProcess);
    Insert( Dummy );
    R.Assign( 21, 2, 32, 3 );
    Insert( New( PLabel, Init( R, 'Interrupt', Dummy )));
    R.Assign( 14, 11, 24, 13 );
    Insert( New( PButton, Init( R, '~O~k', cmOK, bfDefault )));
    R.Assign( 27, 11, 37, 13 );
    Insert( New( PButton, Init(R, 'Cancel', cmCancel, bfNormal )));
  end;
  Dialog^.SetData( Config.Sb );
  Dialog^.SelectNext( FALSE );
  C := DeskTop^.ExecView( Dialog );
  if( C <> cmCancel ) then
    Dialog^.GetData( Config.Sb );
  Dispose( Dialog, Done );
end;

procedure TMyApp.DirDialog;
var
  Dummy: PView;
  Dialog: PDialog;
  R: TRect;
  C: word;
begin
  R.Assign( 20, 4, 60, 16 );
  Dialog := New( PDialog, Init( R, 'Directories' ) );
  with Dialog^ do begin
    R.Assign( 3, 3, 37, 4 );
    Dummy := New( PInputLine, Init( R, SONGDIRLEN ) );
    Insert( Dummy );
    R.Assign( 2, 2, 24, 3 );
    Insert( New( PLabel, Init( R, '~M~odule/Song directory', Dummy )));
    R.Assign( 3, 6, 37, 7 );
    Dummy := New( PInputLine, Init( R, SAMPDIRLEN ) );
    Insert( Dummy );
    R.Assign( 2, 5, 19, 6 );
    Insert( New( PLabel, Init( R, '~S~ample directory', Dummy )));
    R.Assign( 14, 9, 24, 11 );
    Insert( New( PButton, Init( R, '~O~k', cmOK, bfDefault )));
    R.Assign( 27, 9, 37, 11 );
    Insert( New( PButton, Init(R, 'Cancel', cmCancel, bfNormal )));
  end;
  Dialog^.SetData( Config.Dir );
  Dialog^.SelectNext( FALSE );
  C := DeskTop^.ExecView( Dialog );
  if( C <> cmCancel ) then
    Dialog^.GetData( Config.Dir );
  Dispose( Dialog, Done );
end;

procedure TMyApp.ColorDialog;
var
  Dummy: PView;
  Dialog: PDialog;
  R: TRect;
  C: word;
begin
  R.Assign( 20, 4, 60, 14 );
  Dialog := New( PDialog, Init( R, 'Color set' ) );
  with Dialog^ do begin
    R.Assign( 3, 2, 37, 5 );
    Dummy := New( PRadioButtons, Init( R,
      NewSItem( '~M~onochrome (MDA, Hercules)',
      NewSItem( '~C~olor (CGA)',
      NewSItem( '~E~nhanced color (EGA/VGA)',
      NIL)))
    ));
    Insert( Dummy );
    R.Assign( 14, 7, 24, 9 );
    Insert( New( PButton, Init( R, '~O~k', cmOK, bfDefault )));
    R.Assign( 27, 7, 37, 9 );
    Insert( New( PButton, Init(R, 'Cancel', cmCancel, bfNormal )));
  end;
  Dialog^.SetData( Config.Color );
  Dialog^.SelectNext( FALSE );
  C := DeskTop^.ExecView( Dialog );
  if( C <> cmCancel ) then
    Dialog^.GetData( Config.Color );
  Dispose( Dialog, Done );
end;

procedure TMyApp.SpeedDialog;
var
  Dummy: PView;
  Dialog: PDialog;
  R: TRect;
  C: word;
begin
  R.Assign( 20, 4, 60, 14 );
  Dialog := New( PDialog, Init( R, 'Player speed' ) );
  with Dialog^ do begin
    R.Assign( 3, 2, 37, 5 );
    Dummy := New( PRadioButtons, Init( R,
      NewSItem( '~S~low   (8000 Hz)',
      NewSItem( '~M~edium (16000 Hz)',
      NewSItem( '~F~ast   (21000 Hz)',
      NIL)))
    ));
    Insert( Dummy );
    R.Assign( 14, 7, 24, 9 );
    Insert( New( PButton, Init( R, '~O~k', cmOK, bfDefault )));
    R.Assign( 27, 7, 37, 9 );
    Insert( New( PButton, Init(R, 'Cancel', cmCancel, bfNormal )));
  end;
  Dialog^.SetData( Config.Speed );
  Dialog^.SelectNext( FALSE );
  C := DeskTop^.ExecView( Dialog );
  if( C <> cmCancel ) then
    Dialog^.GetData( Config.Speed );
  Dispose( Dialog, Done );
end;

procedure TMyApp.Preferences;
var
  Dummy: PView;
  Dialog: PDialog;
  R: TRect;
  C: word;
begin
  R.Assign( 20, 4, 60, 17 );
  Dialog := New( PDialog, Init( R, 'Preferences' ) );
  with Dialog^ do begin
    R.Assign( 3, 2, 37, 8 );
    Dummy := New( PCheckBoxes, Init( R,
      NewSItem( '~E~GA/VGA 43/50 line mode',
      NewSItem( '~R~elaxed error checking',
      NewSItem( '~L~arge model (128 patterns)',
      NewSItem( 'Use e~X~panded memory',
      NewSItem( 'Use text mode ~G~raphics',
      NewSItem( 'Change ~D~OS prompt',
      NIL))))))
    ));
    Insert( Dummy );
    R.Assign( 14, 10, 24, 12 );
    Insert( New( PButton, Init( R, '~O~k', cmOK, bfDefault )));
    R.Assign( 27, 10, 37, 12 );
    Insert( New( PButton, Init(R, 'Cancel', cmCancel, bfNormal )));
  end;
  Dialog^.SetData( Config.Pref );
  Dialog^.SelectNext( FALSE );
  C := DeskTop^.ExecView( Dialog );
  if( C <> cmCancel ) then
    Dialog^.GetData( Config.Pref );
  Dispose( Dialog, Done );
end;

function GetConfig: byte;
var F: file;
    N: word;
    C: ConfigRec;
begin
  GetConfig := 2;  (* Cannot open *)
  Assign( F, ConfigFile );
  Reset( F, 1 );
  if( IOResult = 0 ) then begin
    GetConfig := 1;  (* Cannot read *)
    BlockRead( F, C, SizeOf( C ), N );
    if( N = SizeOf( C ) ) then begin
      Config := C;
      GetConfig := 0
    end;
    Close( F )
  end
end;

procedure TMyApp.ReadConfig;
begin
  case GetConfig of
    1: MessageBox( #3#13#3'Cannot read configuration file.',
                   NIL, mfError+mfOkButton );
    2: MessageBox( #3#13#3'Cannot open configuration file.',
                   NIL, mfError+mfOkButton );
  end
end;

procedure TMyApp.WriteConfig;
var F: file;
    N: word;
begin
  Assign( F, ConfigFile );
{$I-}
  ReWrite( F, 1 );
  if( IOResult = 0 ) then begin
    BlockWrite( F, Config, SizeOf(Config), N );
    if( N <> SizeOf(Config) ) then
      MessageBox( #3#13#3'Error writing file.', NIL, mfError+mfOkButton );
    Close( F )
  end
  else MessageBox( #3#13#3'Cannot open configuration file.',
                   NIL, mfError+mfOkButton );
{$I+}
end;

procedure TMyApp.About;
begin
  MessageBox( #3'Dr. Track Setup 1.40'#13 +
              #3'CopyRight (c) 1991-93 by'#13 +
              #3'Alessandro Scotti',
              NIL, mfOkButton+mfInformation );
end;

function Is8086: boolean; assembler;
asm
  mov  ax, $FFFF
  mov  cl, 33
  shl  ax, cl
  mov  ax, 0
  jnz  @Exit
  inc  ax
@Exit:
  ret
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

procedure DefaultConfig;
begin
  with Config do begin
    Sb.Port := 0;
    Sb.IRQ := 0;
    Dir.Song := '';
    Dir.Sample := '';
    if( ParamCount >= 1 ) then
      Dir.Song := Copy( ParamStr( 1 ), 1, SONGDIRLEN );
    if( ParamCount >= 2 ) then
      Dir.Sample := Copy( ParamStr( 2 ), 1, SAMPDIRLEN );
    if( StartupMode = smMono ) then
      Color.Value := 0
    else if( IsEGA ) then
      Color.Value := 2
    else Color.Value := 1;
    if( Is8086 ) then
      Speed.Value := 0
    else Speed.Value := 2;
    Pref.Flags := 16+32;
  end;
end;

var
  MyApp: TMyApp;
begin
  if( GetConfig <> 0 ) then
    DefaultConfig;
  MyApp.Init;
  MyApp.About;
  MyApp.Run;
  MyApp.Done
end.

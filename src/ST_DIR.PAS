(*
   Dr. Track
   CopyRight (c) 1991-1992,1993 Alessandro Scotti
*)
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

unit ST_Dir;
interface

const
  GF_Palette : array[ 1..9 ] of byte = (
    $30, $3E, $7F, $30, $30, $1F, $30, $3F, $F3
  );
  FN_EXITDOS = '..X';
  FN_ESCAPE  = '..E';
  FN_OUTOFMEM= '..O';
var
  AlternateList : boolean;
  DirType       : byte;

function GF_GetFileName( var Path, Mask: string; Title: string ): string;
function GF_GetLibrary: string;
function GF_SearchLibrary( Name: string ): string;
procedure GF_ReadLibConfig( LibName: string );

implementation uses Crt, Dos, ST_Win, ST_Data, ST_File, ST_Hyper, ST_Play;

{$I KEYCODES.INC}
const
  LIBSCROLLBAR  = 9;
  HIWINFRAME    = 8;
  WINFRAME      = 7;
  HIFILEATTR    = 6;
  SCROLLBAR     = 5;
  FILEATTR      = 4;
  WINATTR       = 3;
  HIMASKATTR    = 2;
  MASKATTR      = 1;

  DIRLEN        = 56;
  DIRX          = 11;
  DIRY          = 6;
  FILEX1        = 11;
  FILEX2        = 54;
  FILEY         = DIRY+4;

  DIR_SAMPLE    = 1;
type
  Item_Str = string[40];
  Item_Ptr = ^Item_Rec;
  Item_Rec = record
    Name : Item_Str;
    Code : word;
    Prev,
    Next : Item_Ptr
  end;
  List_Rec = record
    Mbar,            (* Scroll-bar On/Off          *)
    Txt   : boolean; (* File di testo              *)
    Mback,           (* Car. sfondo scroll-bar     *)
    Mtext : char;    (* Car. testo scroll-bar      *)
    Mx, My,          (* Coordinate scroll-bar      *)
    Mpos,            (* Posizione scroll-bar       *)
    Mlen,            (* Lunghezza della scroll-bar *)
    MAttr,           (* Attributi della scroll-bar *)
    X, Y  : byte;    (* Coordinate della finestra  *)
    Width,           (* Larghezza della finestra   *)
    Height: byte;    (* Altezza della finestra     *)
    Attr,            (* Attributi testo            *)
    HiAttr: byte;    (* Attributi voce selezionata *)
    Num,             (* Numero di elementi         *)
    TopNum,          (* Num. 1ø elem. finestra     *)
    HiLite: word;    (* Num. elemento selezionato  *)
    Head,            (* Puntatore inizio lista     *)
    Top,             (* Punt. 1ø elem. finestra    *)
    Select: Item_Ptr (* Punt. elemento selezionato *)
  end;

(* Inizializza la lista *)
procedure Init_List( var L: List_Rec );
begin
  with L do begin
    Select := Head;
    Top := Head;
    Hilite := 1;
    TopNum := 1;
    Mpos := 0;
    Num := 0;
    while( Select <> NIL ) do begin
      Inc( Num );
      Select := Select^.Next
    end;
    Select := Head
  end
end;

function Spaces( N: byte ): string;
var S: string;
begin
  S[0] := char( N );
  FillChar( S[1], N, ' ' );
  Spaces := S
end;

procedure Print_Item( X, Y, Attr: byte; S: string; W: byte );
begin
  if( Length( S ) < W ) then
    S := S + Spaces( W );
  Win_WriteAt( X, Y, Copy( S, 1, W ), Attr )
end;

function Get_Scroll_Bar( L: List_Rec; N: word ): byte;
begin
  with L do
    if( MLen < Num ) then
      Get_Scroll_Bar := ( Pred(N) * MLen ) div Num
    else
      Get_Scroll_Bar := ( N * MLen ) div Num - 1
end;

procedure Show_List( var L: List_Rec );
var P: Item_Ptr;
    A, I: byte;
begin
  with L do begin
    P := Top;
    for I:=0 to Pred( Height ) do begin
      if( P = Select )and( Not Txt ) then
        A := HiAttr
      else A := Attr;
      if( P = NIL ) then
        Print_Item( X, Y+I, A, '', Width )
      else begin
        Print_Item( X, Y+I, A, P^.Name, Width );
        P := P^.Next
      end
    end;
    if( Mbar ) then begin
      I := Get_Scroll_Bar( L, HiLite );
      Win_WriteAt( Mx, My+MPos, Mback, MAttr );
      Win_WriteAt( Mx, My+I, Mtext, MAttr );
      Mpos := I;
    end
  end
end;

procedure Select_Item( var L: List_Rec; Delta: integer );
var H: word;
begin
  H := L.HiLite;
  with L do begin
    while( Delta > 0 ) do begin
      Dec( Delta );
      if( HiLite < Num ) then begin
        Inc( HiLite );
        Select := Select^.Next;
        if( HiLite = TopNum+Height ) then begin
          Inc( TopNum );
          Top := Top^.Next
        end
      end
    end;
    while( Delta < 0 ) do begin
      Inc( Delta );
      if( HiLite > 1 ) then begin
        Dec( HiLite );
        Select := Select^.Prev;
        if( HiLite < TopNum ) then begin
          Dec( TopNum );
          Top := Top^.Prev
        end
      end
    end
  end;
  if( H <> L.HiLite ) then
    Show_List( L )
end;

procedure Select_Absolute_Item( var L: List_Rec; Num: word );
begin
  Select_Item( L, integer(Num-L.HiLite) )
end;

procedure Shift_Window( var L: List_Rec; Delta: integer );
var H: word;
begin
  with L do begin
    H := HiLite;
    while( Delta > 0 ) do begin
      if( HiLite < Num ) then begin
        Inc( HiLite );
        Select := Select^.Next
      end;
      if( TopNum+Height <= Num ) then begin
        Inc( TopNum );
        Top := Top^.Next
      end;
      Dec( Delta )
    end;
    while( Delta < 0 ) do begin
      if( HiLite > 1 ) then begin
        Dec( HiLite );
        Select := Select^.Prev
      end;
      if( TopNum > 1 ) then begin
        Dec( TopNum );
        Top := Top^.Prev
      end;
      Inc( Delta )
    end;
    if( H <> HiLite ) then
      Show_List( L )
  end
end;

procedure Do_Cursor( var L: List_Rec; C: char );
begin
  case byte( C ) of
    kHOME  : Select_Absolute_Item( L, 1 );
    kEND   : Select_Absolute_Item( L, L.Num );
    kUP    : if( L.Txt ) then
               Shift_Window( L, -1 )
             else Select_Item( L, -1 );
    kDOWN  : if( L.Txt ) then
               Shift_Window( L, 1 )
             else Select_Item( L, 1 );
    kPGUP  : Shift_Window( L, 1-L.Height );
    kPGDN  : Shift_Window( L, L.Height-1 )
  end
end;

procedure Dispose_List( Head: Item_Ptr );
var P: Item_Ptr;
begin
  while( Head <> NIL ) do begin
    P := Head;
    Head := Head^.Next;
    Dispose( P )
  end
end;

procedure Add_To_List( var Head, Last: Item_Ptr; N: Item_Str );
var P: Item_Ptr;
begin
  if( MaxRAM < SizeOf( Item_Rec )+128 ) then Exit;
  if( Head = NIL ) then begin
    New( Head );
    Head^.Prev := NIL;
    Head^.Next := NIL;
    Head^.Name := N;
    Last := Head
  end
  else begin
    New( P );
    Last^.Next := P;
    P^.Prev := Last;
    P^.Next := NIL;
    P^.Name := N;
    Last := P
  end
end;

procedure Sort_List_Ascending( Head: Item_Ptr );
var Min, I, J: Item_Ptr;
    S: Item_Str;
    W: word;
begin
  I := Head;
  if( I = NIL ) then
    Exit;
  while( I^.Next <> NIL ) do begin
    Min := I;
    J := I^.Next;
    while( J <> NIL ) do begin
      if( J^.Name < Min^.Name ) then
        Min := J;
      J := J^.Next
    end;
    if( Min <> I ) then begin
      S := Min^.Name;
      W := Min^.Code;
      Min^.Name := I^.Name;
      Min^.Code := I^.Code;
      I^.Name := S;
      I^.Code := W
    end;
    I := I^.Next
  end
end;

function TimeToString( Time: longint ): string;
const Mesi: string = 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec ';
var T: DateTime;
  function LZ( W: word ): string;
  var S: string;
  begin
    Str( W, S );
    if( Length(S) = 1 ) then
      S := ' ' + S;
    LZ := S
  end;
  function RG( N, L1, L2: word ): boolean;
  begin
    RG := ( N >= L1 )and( N <= L2 )
  end;
begin
  UnPackTime( Time, T );
  if( RG( T.Day, 1, 31 ) And RG( T.Month, 1, 12 ) ) then
    TimeToString := '   '+LZ(T.Day)+' '+Copy(Mesi,1+(T.Month-1)*4,4)+LZ(T.Year)
  else TimeToString := ''
end;

procedure Get_File_List( var Head: Item_Ptr; Path, Mask: string );
var Tail: Item_Ptr;
    S: string;
    F: SearchRec;
    MyF: file;
    MyS: tSample;
    MyW: word;
    MyB: boolean;
begin
  Head := NIL;
  Mask := Mask + ',';
  while( Mask <> '' ) do begin
    FindFirst( Path+Copy( Mask,1,Pos(',',Mask)-1 ), AnyFile, F );
    while( DosError = 0 ) do begin
      if( F.Attr And (Directory+VolumeID) = 0 ) then
        if( AlternateList )and( DirType > 0 ) then begin
          Assign( MyF, Path+F.Name );
          MyW := IOResult;
          Reset( MyF, 1 );
          MyB := TRUE;
          if( IOResult = 0 ) then case DirType of
            DIR_SAMPLE: begin
              BlockRead( MyF, S, 10, MyW );
              if( MyW = 10 ) then
                if( S = SAMPLE_ID ) then begin
                  BlockRead( MyF, MyS, 31, MyW );
                  if( MyW = 31 ) then begin
                    S := MyS.Name;
                    MyB := FALSE
                  end
                end
            end
          end;
          Close( MyF );
          if( MyB ) then S := '?';
          S := '  ' + Padded( F.Name, 14 ) + S;
          Add_To_List( Head, Tail, S )
        end
        else begin
          Str( F.Size:8, S );
          S := Spaces( 13-Length(F.Name) ) + S;
          S := '  ' + F.Name + S + TimeToString( F.Time ) + '  ';
          Add_To_List( Head, Tail, S )
        end;
      FindNext( F )
    end;
    Delete( Mask, 1, Pos( ',', Mask ) )
  end;
  if( Head = NIL ) then
    Add_To_List( Head, Tail, '  No file found.' )
end;

procedure Get_Dir_List( var Head: Item_Ptr; Path: string );
var Tail: Item_Ptr;
    S: string;
    F: SearchRec;
    R: Registers;
    D: string[7];
begin
  Head := NIL;
  FindFirst( Path+'*.*', AnyFile, F );
  while( DosError = 0 ) do begin
    if( F.Name <> '.' ) then
      if( F.Attr And Directory > 0 )and( F.Attr And VolumeID = 0 ) then begin
        S := '  ' + F.Name;
        Add_To_List( Head, Tail, S )
      end;
    FindNext( F )
  end;
  D := '  [-A-]';
  R.AH := $19;
  MsDos( R );
  R.DL := R.AL;
  R.AH := $0E;
  MsDos( R );
  while( R.AL > 0 ) do begin
    Add_To_List( Head, Tail, D );
    Inc( byte( D[5] ) );
    Dec( R.AL )
  end
end;

procedure Check_BackSlash( var Path: string );
begin
  if( Path[ Length(Path) ] <> '\' ) then
    Path := Path + '\';
  case Path[1] of
    'A' : Mem[ 0:$504 ] := 0;
    'B' : Mem[ 0:$504 ] := 1
  end;
end;

function FExist( FName: string ): integer;
var
  F: file;
  E: integer;
begin
  E := IOResult;
  Assign( F, FName );
  Reset( F );
  E := IOResult;
  if( E = 0 ) then Close( F );
  FExist := E;
end;

function Test_Path( Path: string ): integer;
begin
  Test_Path := FExist( MkFName( Path, 'DRT$CHK.$$$' ) );
end;

procedure Change_Directory( var Path: string; Dir: string );
var I: byte;
begin
  if( Dir = '..' ) then begin
    I := Length( Path );
    repeat
      Dec( I );
      Delete( Path, I+1, 1 )
    until( Path[ I ] = '\' );
  end
  else Path := Path + Dir + '\'
end;

function Change_Drive( var Path: string; Drive: char ): integer;
var E: integer;
begin
  E := Test_Path( Drive + ':\' );
  case E of
    0, 2: begin
      GetDir( Ord( Drive ) - 64, Path );
      Check_BackSlash( Path );
      E := 0;
    end;
    152 : PrintErrorMsg( DRIVE_NOT_READY );
  end;
  Change_Drive := E
end;

const
  LETTERS    = [ 'a'..'z','A'..'Z','_' ];
type
  ExitType = ( eAltI, eAltP,
               eNull,
               eEnter, eExitDos, eTab, eEscape, eSpace,
               eHelp );
  StatusType = ( sExit, sFile, sDir, sMask, sAlternate );
var
  FileList,
  DirList  : List_Rec;

(* Disegna una scroll-bar *)
procedure Scroll_Bar( L: List_Rec );
var I: byte;
begin
  with L do begin
    Win_WriteAt( Mx, My-1, #30, MAttr );
    for I:=1 to MLen-1 do
      Win_WriteAt( Mx, My+I, MBack, MAttr );
    Win_WriteAt( Mx, My+MLen, #31, MAttr )
  end
end;

procedure Do_Ascii( var L: List_Rec; C: char );
var P: Item_Ptr;
    I, N: word;
begin
  if( L.Txt ) then
    Exit;
  C := UpCase( C );
  with L do begin
    P := Head;
    I := 1;
    N := 0;
    if( Select^.Name[3] = C )and( Select^.Next <> NIL ) then
      if( Select^.Next^.Name[3] = C ) then
        N := HiLite + 1;
    if( N = 0 ) then begin
      while( P <> NIL )and( N = 0 ) do begin
        if( P^.Name[3] = C ) then
          N := I;
        Inc( I );
        P := P^.Next
      end
    end;
    if( N > 0 ) then
      Select_Absolute_Item( L, N )
  end
end;

function List_Handler( var L: List_Rec ): ExitType;
var C: char;
    S: ExitType;
begin
  S := eNull;
  while( S = eNull ) do begin
    repeat
    until( KeyPressed );
    C := ReadKey;
    case C of
      #09 : S := eTab;
      #13 : S := eEnter;
      #27 : S := eEscape;
      #32 : if( DirType = DIR_SAMPLE ) then
              S := eSpace;
      #00 : begin
              C := ReadKey;
              case byte( C ) of
                15   : S := eTab;
                kINS,
                kA_P : S := eAltP;
                kA_I : if( DirType > 0 ) then
                         S := eAltI;
                else   Do_Cursor( L, C )
              end
            end
      else  Do_Ascii( L, C )
    end
  end;
  List_Handler := S
end;

procedure Init_All( Title: string );
begin
  with FileList do begin
    Head := NIL;
    Txt := FALSE;
    X := FILEX1;
    Y := FILEY;
    Width := 39;
    Height := 11;
    Mbar := TRUE;
    Mback := 'º';
    Mtext := 'þ';
    Mx := FILEX1+40;
    My := FILEY;
    Mlen := 11;
    MAttr := GF_Palette[SCROLLBAR];
    Attr := GF_Palette[FILEATTR];
    HiAttr := GF_Palette[HIFILEATTR]
  end;
  DirList := FileList;
  with DirList do begin
    X := FILEX2;
    Y := FILEY;
    Width := 16;
    Height := 11;
    Mx := FILEX2+17;
    My := FILEY
  end;
  Win_Open( DIRX-3, DIRY-3, DIRX+DIRLEN+6, DIRY+17, GF_Palette[WINATTR] );
  Win_SetCursorSize( Win_CRSOFF );
  ClrScr;
  Win_Border( SINGLEBORDER, GF_Palette[WINATTR] );
  Win_WriteAt( DIRX-1, DIRY-3, Title, GF_Palette[WINATTR] );
  Win_Shadow( $08 )
end;

(* Stampa il path e la maschera correnti *)
procedure Write_Directory( Path, Mask: string );
var S: string;
    I: byte;
begin
  S := Path + Mask;
  if( Length( S ) > DIRLEN ) then begin
    repeat
      Delete( S, 3, 1 )
    until( S[3] = '\' )and( Length( S ) <= DIRLEN-4 );
    Insert( '...\', S, 4 )
  end;
  Win_WriteAt( DIRX, DIRY, '  ' + S + Spaces( DIRLEN+2-Length(S) ), GF_Palette[MASKATTR] )
end;

procedure On_Box( S: StatusType );
var A, B, C, H: byte;
begin
  A := GF_Palette[WINFRAME];
  B := A;
  C := A;
  H := GF_Palette[HIWINFRAME];
  case S of
    sMask  : A := H;
    sFile  : B := H;
    sDir   : C := H
  end;
  Win_TitledBox( DIRX-1, DIRY-1, DIRX+DIRLEN+4, DIRY+1, byte(A=H), A, 2, ' Path ' );
  Win_TitledBox( FILEX1-1, FILEY-1, FILEX1+39, FILEY+11, byte(B=H), B, 2, ' File ' );
  Win_TitledBox( FILEX2-1, FILEY-1, FILEX2+16, FILEY+11, byte(C=H), C, 2, ' Directory ' )
end;

(* Legge una directory *)
procedure Log_Directory( Path, Mask: string );
begin
  Dispose_List( FileList.Head );
  Dispose_List( DirList.Head );
  Get_File_List( FileList.Head, Path, Mask );
  Get_Dir_List( DirList.Head, Path );
  Sort_List_Ascending( FileList.Head );
  Sort_List_Ascending( DirList.Head );
  Init_List( FileList );
  Init_List( DirList );
  Scroll_Bar( FileList );
  Scroll_Bar( DirList );
  Write_Directory( Path, Mask );
  Show_List( FileList );
  Show_List( DirList )
end;

(* Cambio drive/directory *)
procedure Log_New_Directory( var Path: string; Mask: string );
var
  P: string;
  I: Item_Str;
  Err: integer;
begin
  I := Copy( DirList.Select^.Name, 3, 255 );
  P := Path;
  Err := 0;
  if( I[1] = '[' ) then begin
    Err := Change_Drive( P, I[3] );
  end
  else Change_Directory( P, I );
  if( Err = 0 ) then begin
    Path := P;
    Log_Directory( Path, Mask )
  end
end;

function Mask_Handler( var Path, Name, Mask: string ): ExitType;
var
  E: ExitType;
  D, S: string;
  I, P: integer;
  SR: SearchRec;
procedure Sel_NameMask( D, S: string );
label
  Restart;
begin
Restart:
  if( S = '' ) then
    S := '*.*';
  FindFirst( D + '*.*', AnyFile, SR );
  if( DosError = 3 ) then
    I := 3
  else I := FExist( MkFName( D, S ) );
  case I of
    0  : begin
         Path := D;
         Name := Copy( S, 1, 12 );
         E := eTab;
         end;
    3  : PrintErrorMsg( PATH_NOT_FOUND );
    152: PrintErrorMsg( DRIVE_NOT_READY );
    else begin
      if( Pos( '*', S ) > 0 )or( Pos( '?', S ) > 0 ) then begin
        Path := D;
        Mask := S;
        E := eEnter;
      end
      else begin
        if( Pos( '.', S ) = 0 ) then begin
          S := S + '.MOD';
          goto Restart;
        end;
        PrintErrorMsg( FILE_NOT_FOUND );
      end;
    end
  end;
end;
begin
  E := eNull;
  while( E = eNull ) do begin
    S := Mask;
    case ST_LineEdit( DIRX+1,DIRY,DIRLEN+2,79+MAXMASKLEN,S, '@'#13'S'#27'E|', H_NULL ) of
      1 : begin
            if( Pos( ':', S ) > 0 )or( Pos( '\', S ) > 0 ) then
              S := FExpand( S );
            if( S[ Length(S) ] = '\' ) then
              S := S + Mask
            else begin
              FindFirst( S, AnyFile, SR );
              if( DosError = 0 )and( SR.Attr and Directory > 0 )and
                ( SR.Name <> '.' )and( SR.Name <> '..' ) then
                S := S + '\' + Mask;
            end;
            I := Length( S );
            P := 0;
            while( I > 0 )and( P = 0 ) do
              if( S[I] = '\' ) then
                P := I
              else Dec( I );
            if( P > 0 ) then
              Sel_NameMask( Copy( S, 1, P ), Copy( S, P+1, MAXMASKLEN ) )
            else Sel_NameMask( Path, Copy( S, 1, MAXMASKLEN ) );
          end;
      2 : E := eEscape
    end;
  end;
  Mask_Handler := E;
  if( Mask = '' ) then Mask := '*.*';
  Write_Directory( Path, Mask )
end;

function GF_GetFileName;
var
  O, S: StatusType;
  N: string[12];
function AdjName( N: string ): string;
  begin
    while( N[1] = ' ' ) do
      Delete( N, 1, 1 );
    if( Pos( ' ', N ) > 0 ) then
      Delete( N, Pos( ' ', N ), 255 );
    AdjName := N;
  end;
procedure Return( FN: string );
  begin
    S := sExit;
    GF_GetFileName := AdjName( FN );
  end;
begin
  DirType := 0;
  if( Pos( 'sample', Title ) > 0 ) then
    DirType := DIR_SAMPLE;
  if( MaxRAM < 1024 ) then
    Return( FN_OUTOFMEM );
  if( Win_VideoSeg = $B000 ) then
    GF_Palette[HIFILEATTR] := $0F;
  if( Path = '' ) then
    GetDir( 0, Path );
  if( Path = '' ) then
    Path := vWorkPath;
  Check_BackSlash( Path );
  if( Mask = '' ) then
    Mask := '*.*';
  Path := StrUpr( Path );
  Mask := StrUpr( Mask );
  Init_All( Title );
  Log_Directory( Path, Mask );
  S := sFile;
  while( S <> sExit ) do begin
    if( S in [sFile,sDir] ) then O := S;
    On_Box( S );
    case S of
      sFile : case List_Handler( FileList ) of
                eEnter      : if( Pos( 'file', FileList.Select^.Name ) = 0 ) then
                                Return( FileList.Select^.Name );
                eTab        : S := sDir;
                eAltP       : S := sMask;
                eAltI       : S := sAlternate;
                eExitDos    : Return( FN_EXITDOS );
                eEscape     : Return( FN_ESCAPE );
                eSpace      : if( Pos( 'file', FileList.Select^.Name ) = 0 ) then
                                F_TestSample( Path + AdjName( FileList.Select^.Name ) );
              end;
      sDir  : case List_Handler( DirList ) of
                eEnter      : Log_New_Directory( Path, Mask );
                eTab        : S := sFile;
                eAltP       : S := sMask;
                eAltI       : S := sAlternate;
                eEscape     : Return( FN_ESCAPE );
                eExitDos    : Return( FN_EXITDOS )
              end;
      sMask : case Mask_Handler( Path, N, Mask ) of
                eTab       : Return( N );
                eEnter     : begin
                               Log_Directory( Path, Mask );
                               S := O
                             end;
                else         S := O
              end;
      sAlternate : begin
                if( DirType > 0 ) then begin
                  AlternateList := Not AlternateList;
                  Log_Directory( Path, Mask )
                end;
                S := O
              end;
    end
  end;
  Dispose_List( FileList.Head );
  Dispose_List( DirList.Head );
  Win_Close;
end;

(**************************************
   Sample library
**************************************)

const
  BLANK = #32;
type
  PStringNode = ^StringNode;
  StringNode = record
    PData: ^string;
    Prev,
    Next : PStringNode
  end;
var
  LibList: List_Rec;
  SHead: PStringNode;

function Trim( S: string ): string;
begin
  while( S[1] = BLANK ) do Delete( S, 1, 1 );
  while( S[ Length(S) ] = BLANK ) do Delete( S, Length(S), 1 );
  Trim := S
end;

procedure Add_StringNode( var Head, Last: PStringNode; S: string );
var P: PStringNode;
begin
  S := StrUpr( Trim( S ) );
  if( Head = NIL ) then begin
    New( Head );
    Head^.Prev := NIL;
    Head^.Next := NIL;
    Last := Head;
    P := Head
  end
  else begin
    New( P );
    Last^.Next := P;
    P^.Prev := Last;
    P^.Next := NIL;
    Last := P
  end;
  GetMem( P^.PData, Length( S )+1 );
  Move( S, P^.PData^, Length( S )+1 );
end;

procedure GF_ReadLibConfig;
var
  F: text;
  S, T: string;
  I, J, Count: word;
  Tail: Item_Ptr;
  STail: PStringNode;
begin
  with LibList do begin
    Head := NIL;
    Txt := FALSE;
    X := FILEX1+10;
    Y := 7;
    Width := 39;
    Height := 11;
    Mbar := TRUE;
    Mback := '²';
    Mtext := 'þ';
    Mx := X+39;
    My := Y+1;
    Mlen := 9;
    MAttr := GF_Palette[LIBSCROLLBAR];
    Attr := GF_Palette[FILEATTR];
    HiAttr := GF_Palette[HIFILEATTR]
  end;
  Count := 0;
  SHead := NIL;
  Assign( F, MkFName( vWorkPath, LibName ) );
  Reset( F );
  if( IOResult = 0 ) then begin
    while( Not Eof( F ) ) do begin
      ReadLn( F, S );
      while( Pos( #9, S ) > 0 ) do
        S[ Pos( #9, S ) ] := #32;
      S := Trim( S );
      if( S <> '' ) then if( S[1] <> ';' ) then begin
        I := Pos( BLANK, S );
        if( I > 0 ) then begin
          T := Copy( S, 1, I-1 );
          Delete( S, 1, I );
          S := Copy( Trim( S ), 1, MAXPATHLEN-1 );
          if( S <> '' ) then begin
            Add_To_List( LibList.Head, Tail, '  ' + S );
            Add_StringNode( SHead, STail, T );
            Inc( Count );
            Tail^.Code := Count
          end;
        end
      end
    end;
    Close( F );
    Sort_List_Ascending( LibList.Head )
  end;
  Init_List( LibList )
end;

function Get_StringNode( N: word ): string;
var
  P: PStringNode;
  I: word;
begin
  P := NIL;
  if( N > 0 ) then begin
    P := SHead;
    for I:=1 to N-1 do
      if( P <> NIL ) then
        P := P^.Next;
  end;
  if( P = NIL ) then
    Get_StringNode := ''
  else Get_StringNode := P^.PData^
end;

function GF_SearchLibrary( Name: string ): string;
var
  P: Item_Ptr;
  R: word;
begin
  R := 0;
  if( Name <> '' ) then begin
    Name := '  ' + StrUpr( Trim( Name ) );
    P := LibList.Head;
    while( P <> NIL )and( R = 0 ) do
      if( StrUpr( P^.Name ) = Name ) then
        R := P^.Code
      else P := P^.Next;
  end;
  GF_SearchLibrary := Get_StringNode( R )
end;

function GF_GetLibrary: string;
var
  S: string;
  E: ExitType;
begin
  S := '';
  if( LibList.Head <> NIL ) then begin
    with LibList do begin
      Win_SetCursorSize( Win_CRSOFF );
      Win_Open( X-1, Y-1, Mx, Y+MLen+2, Attr );
      Win_Shadow( $08 );
      ClrScr;
      Win_Border( DOUBLEBORDER, GF_Palette[HIWINFRAME] );
      Win_WriteAt( X+1, Y-1, ' Sample libraries ', GF_Palette[HIWINFRAME] );
      Scroll_Bar( LibList );
    end;
    ST_StatusLine( S_LIBRARY );
    Show_List( LibList );
    repeat
      E := List_Handler( LibList )
    until( E in [eEscape, eEnter] );
    if( E = eEnter ) then
      S := LibList.Select^.Name;
    Win_Close
  end
  else PrintErrorMsg( LIB_NOT_FOUND );
  GF_GetLibrary := S
end;

begin
  AlternateList := FALSE;
end.

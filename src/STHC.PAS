(*
   Help compiler 1.20 - Copyright (c) 1993 by Alessandro Scotti

   Syntax of source file: same as multi-edit, except:
     '^' in ME is '&' in STHC
     '^B' and '^b' (bold on/off) are '&B' and '&N' in STHC (bold/normal)
*)
program STHC;
uses Objects;

type
  PTopic = ^TTopic;
  TTopic = object( TObject )
    TopicName: PString;
    RefName: PString;
    TextOfs: longint;
    TextLen: word;
    AkaWord: word;
    SeeAlso: PCollection;
    constructor Init( Name, RName: string; FPos: longint );
    destructor Done; virtual;
  end;

  PTopicCollection = ^TTopicCollection;
  TTopicCollection = object( TSortedCollection )
    function KeyOf( Item: pointer ): pointer; virtual;
    function Compare( Key1, Key2: pointer ): integer; virtual;
  end;
type
  TToken = ( tkTOPIC, tkTEXT, tkEOF, tkUNKNOWN );
  TKWord = record
    KWord: string[10];
    Token: TToken;
  end;
const
  HYPERLINK = '@';
  HYPERSTART = '[';
  HYPEREND = ']';
  ESCAPECHAR = '&';
  ESCBOLDON = 'B';
  ESCNORMAL = 'N';
  CMDNORMAL = #1;
  CMDLINK = #2;  (* #3 is reserved *)
  CMDBOLD = #4;
  BLANKS = [ #09, #32 ];
  OUTNAME = 'DRT.HLP';
  OUTUNIT = 'DRT.INC';
  INBUFSIZE = 10*1024;
var
  InBuffer: array[ 1..INBUFSIZE ] of char;
  InFile : text;
  OutFile: file;
  InString: string;
  InLineNum: word;
  CurAkaWord: word;
  TopicList: PCollection;
  CurTopic: PTopic;
  TopicNum: word;

function Upr( S: string ): string;
var I: byte;
begin
  for I:=1 to Length( S ) do
    S[I] := UpCase( S[I] );
  Upr := S
end;

(***
    Oggetti
***)
constructor TTopic.Init;
begin
  TopicName := NewStr( Name );
  RefName := NewStr( RName );
  TextOfs := FPos;
  TextLen := 0;
  AkaWord := CurAkaWord;
  Inc( CurAkaWord );
  SeeAlso := New( PCollection, Init( 10, 10 ) );
end;

destructor TTopic.Done;
begin
  Dispose( SeeAlso, Done );
  DisposeStr( RefName );
  DisposeStr( TopicName );
end;

function TTopicCollection.KeyOf;
begin
  KeyOf := PTopic( Item )^.TopicName;
end;

function TTopicCollection.Compare;
begin
  if( Upr(PString(Key1)^) < Upr(PString(Key2)^) ) then
    Compare := -1
  else if( Upr(PString(Key1)^) = Upr(PString(Key2)^) ) then
    Compare := 0
  else
    Compare := 1;
end;

(***
    Routine per la compilazione
***)
procedure Warning( Line: word; Msg: string );
begin
  if( Line = 0 ) then
    WriteLn( 'Warning: ', Msg, '.' )
  else WriteLn( 'Warning, line ', InLineNum, ': ', Msg, '.' )
end;

function PChar( C: char ): byte;
begin
  PChar := Pos( C, InString )
end;

procedure Trim( var S: string );
begin
  while( S[1] in BLANKS ) do Delete( S, 1, 1 );
end;

procedure NewTopic;
var
  Name, RName: string;
  N, E: word;
begin
  if( PChar( '=' ) = 0 ) then
    Name := InString
  else begin
    Name := Copy( InString, 1, PChar( '=' )-1 );
    Delete( InString, 1, Length( Name )+1 );
    if( InString <> '' ) then begin
      Val( InString, N, E );
      if( E = 0 ) then
        CurAkaWord := N
    end
  end;
  if( Pos( ',', Name ) > 0 ) then begin
    RName := Name;
    Name := Copy( Name, 1, Pos( ',', Name )-1 );
    Delete( RName, 1, Length( Name )+1 );
  end
  else RName := Name;
  Trim( Name );
  Trim( RName );
  Inc( TopicNum );
  WriteLn( 'Topic: "', RName, '" (key: ', Name, ' = ', CurAkaWord, ')' );
  CurTopic := New( PTopic, Init( Name, RName, FilePos(OutFile) ) );
  TopicList^.Insert( CurTopic );
end;

procedure DoSeeAlso( Name: string );
begin
  WriteLn( '  Ref: ', Name );
  CurTopic^.SeeAlso^.Insert( NewStr(Name) );
end;

function Padded( S: string; N: byte ): string;
begin
  while( Length( S ) < N ) do
    S := S + ' ';
  Padded := Copy( S, 1, N );
end;

procedure BuildUnit;
var F: text;
procedure PrintName( P: PTopic ); far;
  begin
    Write( F, '  hc', Padded(P^.TopicName^,22), '= ', P^.AkaWord, ';  (* ' );
    WriteLn( F, P^.RefName^, ' *)' );
  end;
begin
  Assign( F, OUTUNIT );
  ReWrite( F );
  WriteLn( '*** Building include...' );
  WriteLn( F, '(*' );
  WriteLn( F, '    Help context constants' );
  WriteLn( F, '*)' );
  WriteLn( F, 'const' );
  TopicList^.ForEach( @PrintName );
  Close( F );
end;

function SearchTopic( Name: string ): PTopic;
  function Match( P: PTopic ): boolean; far;
  begin
    Match := Pos( Name, Upr( P^.TopicName^ ) ) = 1;
  end;
begin
  Name := Upr( Name );
  SearchTopic := TopicList^.FirstThat( @Match );
end;

procedure WriteSeeAlsoList( Item: PTopic; C: PCollection );
var W: word;
procedure WriteItem( P: PString ); far;
  var T: PTopic;
  begin
    T := SearchTopic( P^ );
    if( T = NIL ) then
      Warning( 0, 'unresolved seealso (topic: "'+Item^.TopicName^+'", key: '+P^+')' )
    else BlockWrite( OutFile, T^.AkaWord, 2 );
  end;
begin
  C^.ForEach( @WriteItem );
  W := 0;
  BlockWrite( OutFile, W, 2 );
end;

procedure CrossRef;
  procedure WriteTopic( P: PTopic ); far;
  var W: word;
  begin
    with P^ do begin
      BlockWrite( OutFile, RefName^, Length(RefName^)+1 );
      BlockWrite( OutFile, AkaWord, 2 );
      BlockWrite( OutFile, TextLen, 2 );
      BlockWrite( OutFile, TextOfs, 4 );
      WriteSeeAlsoList( P, SeeAlso )
    end
  end;
var L: longint;
begin
  WriteLn( '*** Building index...' );
  Close( OutFile );
  Reset( OutFile, 1 );
  L := FileSize( OutFile );
  Seek( OutFile, 0 );
  BlockWrite( OutFile, L, 4 );
  Seek( OutFile, L );
  TopicList^.ForEach( @WriteTopic );
end;

(***
    Routine di I/O
***)
function GetToken: TToken;
var
  I, Found: word;
begin
  if( Eof( InFile ) ) then
    GetToken := tkEOF
  else begin
    ReadLn( InFile, InString );
    Inc( InLineNum );
    if( InString[ 1 ] = #12 ) then begin
      Delete( InString, 1, 1 );
      GetToken := tkTOPIC;
    end
    else GetToken := tkTEXT;
  end;
end;

procedure DoOutText;
var
  I: byte;
  S: string;
begin
  S := '';
  while( InString <> '' ) do begin
    case InString[1] of
      HYPERLINK: begin
        Delete( Instring, 1, 1 );
        DoSeeAlso( Copy( Instring, 1, Pos(HYPERSTART,InString)-1 ) );
        S := S + CMDLINK;
        Delete( Instring, 1, Pos(HYPERSTART,InString) );
        Instring[ Pos(HYPEREND,Instring) ] := CMDNORMAL;
        end;
      ESCAPECHAR: begin
        Delete( Instring, 1, 1 );
        case Upcase(Instring[1]) of
          ESCBOLDON: S := S + CMDBOLD;
          ESCNORMAL: S := S + CMDNORMAL;
          else       S := S + Instring[1];
        end;
        Delete( Instring, 1, 1 );
        end;
      else begin
        S := S + Instring[1];
        Delete( Instring, 1, 1 );
      end;
    end;
  end;
  BlockWrite( OutFile, S, Length(S)+1 );
  Inc( CurTopic^.TextLen );
end;

procedure Compile( FName: string );
var
  T: TToken;
begin
  Assign( InFile, FName );
  Reset( InFile );
  SetTextBuf( InFile, InBuffer, INBUFSIZE );
  WriteLn( '*** Compiling...' );
  T := GetToken;
  while( T <> tkEOF ) do begin
    case T of
      tkUNKNOWN: Warning( InLineNum, 'unknown command' );
      tkTOPIC  : NewTopic;
      tkTEXT   : DoOutText;
    end;
    T := GetToken;
  end;
  Close( InFile );
  CrossRef;
  BuildUnit;
  WriteLn( '*** Done: ', InLineNum, ' lines, ', TopicNum, ' topics.' );
end;

(***
    Applicazione
***)
procedure AppInit;
var
  L: longint;
  S: string;
begin
  WriteLn( 'ST Help Compiler - CopyRight (c) 1993 Alessandro Scotti' );
  WriteLn( 'Internal use only.' );
  InLineNum := 0;
  TopicList := New( PCollection, Init( 50, 10 ) );
  CurAkaWord := 0;
  TopicNum := 0;
  Assign( OutFile, OUTNAME );
  ReWrite( OutFile, 1 );
  L := 0;
  BlockWrite( OutFile, L, 4 );
  S := #13'Help Compiler 1.20 (c) 1993 Alessandro Scotti'#$1A;
  BlockWrite( OutFile, S[1], Length( S ) );
end;

procedure AppDone;
begin
  Close( OutFile );
end;

procedure AppRun;
begin
  Compile( 'DRTHELP.SRC' );
end;

begin
  AppInit;
  AppRun;
  AppDone;
end.
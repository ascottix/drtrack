(*
   Dr. Track
   Online help
   CopyRight (c) 1991-1992,1993 Alessandro Scotti
*)
{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S-,V-,X+}
unit ST_Help;
interface

const
  H_EDIT        = 0;
  H_ORDER       = 1;
  H_SAMPLE      = 2;
  H_S_NAME      = 3;
  H_S_FILENAME  = 4;
  H_S_PATHNAME  = 5;
  H_S_NUMBER    = 6;
  H_WRITEPATT   = 7;
  H_COMMANDLIST = 8;

  H_NULL        = $FFFF;

procedure ST_ShowHelp( Index: word );

implementation uses Crt, ST_Win, ST_Data;

type
  HelpRec = record
    Offset  : word;
    Width,
    Height  : byte
  end;

procedure ST_ShowHelp;
type
  MyScreen = array[1..24] of string[80];
var
  H: HelpRec;
  I, E, W: word;
  F: file;
  P: ^MyScreen;
  X, Y: byte;
begin
  if( Index = H_NULL ) then Exit;
  New( P );
  Assign( F, MkFName( vWorkPath, 'DRT.HLP' ) );
  Reset( F, 1 );
  E := IOResult;
  if( E <> 0 ) then
    PrintErrorMsg( HELP_NOT_FOUND )
  else begin
    Seek( F, 10+2+Index*SizeOf(HelpRec) );
    BlockRead( F, H, SizeOf(HelpRec), E );
    if( E = SizeOf(HelpRec) )and( H.Width <= 80 )and( H.Height <= 24 ) then
      E := $FFFF;
    Seek( F, H.Offset );
    W := H.Width;
    for I:=1 to H.Height do if( E = $FFFF ) then begin
      BlockRead( F, P^[I][1], W, E );
      P^[I][0] := char( Lo(W) );
      if( E = W ) then
        E := $FFFF
    end;
    Close( F );
    if( E = $FFFF ) then begin
      X := (78 - W) div 2 + 1;
      Y := (23 - H.Height) div 2 + 1;
      Win_Open( X, Y, X+W+1, Y+H.Height+1, $70 );
      Win_SetCursorSize( Win_CRSOFF );
      Win_Border( SINGLEBORDER, $7F );
      Win_WriteAt( X+2, Y, ' Help ', $7F );
      Win_Shadow( $08 );
      for I:=1 to H.Height do
        Win_WriteAt( X+1, Y+I, P^[I], $70 );
      WaitAKey;
      Win_Close
    end
    else PrintErrorMsg( HELP_CORRUPTED )
  end;
  Dispose( P )
end;

begin
end.

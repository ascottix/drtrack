{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S-,V-,X+}
(*
   Dr. Track
   ST_EDIT and ST_SAMP interface (sound player is written in Assembly)
   CopyRight (c) 1991-1992,1993 Alessandro Scotti

*)
unit ST_Play;

interface

const
  MAXSPEED = 2;

function  ST_GetSpeed: word;
procedure DMA_Init( Port, IRQ: word; TimeConst, TimeConstStereo: byte );
procedure ST_GetInfo( var Order, Pattern, Frame: word );
procedure ST_GetPeaks( var P12, P34: word );
procedure ST_Init( SBpro: boolean );
procedure ST_InitSamples;
procedure ST_InitSong( Speed, First, Last: word );
procedure ST_OnOffChannel( Channel, Mask: word );
procedure ST_OnOffSpeaker( Flag: byte );
procedure ST_PlayModule( EMM_Handle: word );
procedure ST_PlaySolo;
procedure ST_Record( Note, Sample, Track: byte; Flag: boolean );
procedure ST_SetOrder( N, P: word );
procedure ST_SetPattern( Num:word; PattPtr:pointer );
procedure ST_SetRate( RefFreq, BufLen: word );
procedure ST_SetSample( N:word; P:pointer; L, RS, RL, V: word );
procedure ST_SetSoloNote( Note, Sample: byte );
procedure ST_Stop;
procedure ST_SetMasterVolume( Vol: byte );
function  ST_GetBuffer: pointer;

function ST_GetBlockLen: word;
procedure ST_SetupSound( Speed: byte; SBPro: boolean );

function  ST_CheckHook: longint;
procedure ST_InstallHook;
procedure ST_PrintFrame( PattPtr: pointer; Frame, Y: word );
procedure ST_PrintHiFrame( PattPtr: pointer; Frame, Y: word );
procedure ST_PrintInit( VSeg:word; A,HiA,FA,HiFA,PA:byte; FFR,LVO:word );
procedure ST_PrintPeakShadow;
procedure ST_PrintPeaks( Peak12, Peak34: word );
procedure ST_RemoveHook;

implementation uses SBC, ST_SBPro;

function  ST_GetSpeed: word; external;
procedure DMA_Init; external;
procedure ST_GetInfo( var Order, Pattern, Frame: word ); external;
procedure ST_GetPeaks( var P12, P34: word ); external;
procedure ST_Init; external;
procedure ST_InitSamples; external;
procedure ST_InitSong( Speed, First, Last: word ); external;
procedure ST_OnOffChannel( Channel, Mask: word ); external;
procedure ST_OnOffSpeaker( Flag: byte ); external;
procedure ST_PlayModule( EMM_Handle: word ); external;
procedure ST_PlaySolo; external;
procedure ST_Record( Note, Sample, Track: byte; Flag: boolean ); external;
procedure ST_SetOrder( N, P: word ); external;
procedure ST_SetPattern( Num:word; PattPtr:pointer ); external;
procedure ST_SetRate( RefFreq, BufLen: word ); external;
procedure ST_SetSample( N:word; P:pointer; L, RS, RL, V: word ); external;
procedure ST_SetSoloNote( Note, Sample: byte ); external;
procedure ST_Stop; external;
procedure ST_SetMasterVolume( Vol: byte ); external;
function  ST_GetBuffer: pointer; external;
{$L STPLAY}

function  ST_CheckHook: longint; external;
procedure ST_InstallHook; external;
procedure ST_PrintFrame( PattPtr: pointer; Frame, Y: word ); external;
procedure ST_PrintHiFrame( PattPtr: pointer; Frame, Y: word ); external;
procedure ST_PrintInit( VSeg:word; A,HiA,FA,HiFA,PA:byte; FFR,LVO:word ); external;
procedure ST_PrintPeakShadow; external;
procedure ST_PrintPeaks( Peak12, Peak34: word ); external;
procedure ST_RemoveHook; external;
{$L STVIDEO}

type
  Info = record
    RefFreq  : word;
    TimeConst: byte;
    TimeConstStereo: byte;
    BlockLen : word
   end;
const
  aSBCinfo : array[ 0..MAXSPEED ] of Info = (
    ( RefFreq:$1AC; TimeConst:$8A; TimeConstStereo:$C5; BlockLen:165 ),
    ( RefFreq:$E1 ; TimeConst:$C2; TimeConstStereo:$E1; BlockLen:315 ),
    ( RefFreq:$AD ; TimeConst:$D0; TimeConstStereo:$E8; BlockLen:410 )
  );
  CurBlockLen     : word = 0;

function ST_GetBlockLen;
begin
  ST_GetBlockLen := CurBlockLen;
end;

procedure ST_SetupSound;
begin
  if( Speed > MAXSPEED ) then Speed := MAXSPEED;
  ST_Init( SBPro );
  with aSBCinfo[Speed] do begin
    DMA_Init( SBC_Port, SBC_IRQ, TimeConst, TimeConstStereo );
    ST_SetRate( RefFreq, BlockLen );
    CurBlockLen := BlockLen;
  end;
  if( SBPro ) then begin
    (* Disable low-pass filter, enable virtual stereo *)
    SB_WriteMixer( $0E, SB_ReadMixer( $0E ) or $22 );
  end;
end;

end.

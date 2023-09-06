{$A+,B-,D-,E-,F-,G-,I-,L-,N-,O-,R-,S-,V-,X+}
(*
    Dr. Track - Low-level soundblaster interface
    CopyRight (c) 1991 Alessandro Scotti
*)
unit SBC;
interface

var
  SBC_Port: word;
  SBC_IRQ : word;

function SBC_ResetDSP: boolean;
function SBC_DetectCard: word;
function SBC_CheckCard: word;
function SBC_DetectInt: word;

implementation

function SBC_ResetDSP: boolean; external;
function SBC_DetectCard: word; external;
function SBC_CheckCard: word; external;
function SBC_DetectInt: word; external;
{$L SB_DSP}

begin
end.

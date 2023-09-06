const
  FCC_RIFF  = $46464952;        (* 'RIFF' *)
  FCC_LIST  = $5453494C;        (* 'LIST' *)
  FORM_WAVE = $45564157;        (* 'WAVE' *)
  FORM_WFMT = $20746D66;        (* 'fmt ' *)
  FORM_WDAT = $61746164;        (* 'data' *)
type
  TRiffChunk  = record
    FCC       : longint;
    Size      : longint;
  end;
  TWavePCM    = record
    FormatTag     : word;               (* 1 = PCM *)
    Channels      : word;               (* Number of channels *)
    SamplesPerSec : longint;            (* Sampling rate *)
    AvgBytesPerSec: longint;
    BlockAlign    : word;
    BitsPerSample : word;
  end;


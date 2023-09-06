(*
   Expanded memory management
   CopyRight (c) 1991-1992,1993 Alessandro Scotti
*)
{$A+,B-,D-,E-,F-,I-,L-,N-,O-,R-,S-,V-,X+}
unit EMS;
interface

const
  EMM_NIL = $FFFF;
var
  EMM_Result: byte;
  EMM_Version: byte;
  EMM_Frame: word;

function EMM_GetFreePages: word;
function EMM_GetHandleCount: byte;
function EMM_GetMemory( Pages: word ): word;
function EMM_GetPageFrame: word;
function EMM_GetPagesForHandle( Handle: word ): word;
function EMM_GetStatus: byte;
function EMM_GetTotalPages: word;
function EMM_GetVersion: byte;
procedure EMM_FreeMemory( Handle: word );
procedure EMM_GetPageMap( Buffer: pointer );
procedure EMM_MapMemory( PhysicalPage: byte; LogicalPage, Handle: word );
procedure EMM_SetName( Handle: word; Name: string );
procedure EMM_SetPageMap( Buffer: pointer );

implementation

var
  EMM_Found: boolean;

procedure Check_EMM; assembler;
asm
  jmp   @@Start
@@DriverName:
  db    'EMMXXXX0'
@@Start:
  mov   [EMM_Found], 0
  push  ds
  mov   ax, $3567
  int   $21
  mov   di, $000A
  mov   si, OFFSET @@DriverName
  mov   ax, cs
  mov   ds, ax
  mov   cx, $08
  cld
  rep   cmpsb
  pop   ds
  jne   @@Exit
  mov   ah, $46
  int   $67
  or    ah, ah
  jnz   @@Exit
  mov   [EMM_Version], al
  mov   ah, $41
  int   $67
  or    ah, ah
  jnz   @@Exit
  mov   [EMM_Frame], bx
  inc   [EMM_Found]
@@Exit:
end;

function EMM_GetStatus: byte; assembler;
asm
  mov   ah, $FF
  cmp   [EMM_Found], 0
  je    @@Exit
  mov   ah, $40
  int   $67
@@Exit:
  mov   al, ah
  xor   ah, ah
  mov   [EMM_Result], al
end;

function EMM_GetPageFrame: word; assembler;
asm
  mov   ah, $41
  int   $67
  mov   [EMM_Result], ah
  mov   ax, bx
end;

function EMM_GetFreePages: word; assembler;
asm
  mov   ah, $42
  int   $67
  mov   [EMM_Result], ah
  mov   ax, bx
end;

function EMM_GetTotalPages: word; assembler;
asm
  mov   ah, $42
  int   $67
  mov   [EMM_Result], ah
  mov   ax, dx
end;

function EMM_GetMemory( Pages: word ): word; assembler;
asm
  mov   ah, $43
  mov   bx, [Pages]
  int   $67
  mov   [EMM_Result], ah
  mov   ax, dx
end;

procedure EMM_MapMemory( PhysicalPage: byte; LogicalPage, Handle: word ); assembler;
asm
  mov   ah, $44
  mov   al, [PhysicalPage]
  mov   bx, [LogicalPage]
  mov   dx, [Handle]
  int   $67
  mov   [EMM_Result], ah
end;

procedure EMM_FreeMemory( Handle: word ); assembler;
asm
  mov   ah, $45
  mov   dx, [Handle]
  int   $67
  mov   [EMM_Result], ah
end;

function EMM_GetVersion: byte; assembler;
asm
  mov   ah, $46
  int   $67
  mov   [EMM_Result], ah
  xor   ah, ah
end;

function EMM_GetHandleCount: byte; assembler;
asm
  mov   ah, $4B
  int   $67
  mov   [EMM_Result], ah
  mov   al, bl
  xor   ah, ah
end;

function EMM_GetPagesForHandle( Handle: word ): word; assembler;
asm
  mov   ah, $4C
  mov   dx, [Handle]
  int   $67
  mov   [EMM_Result], ah
  mov   ax, bx
end;

procedure EMM_GetPageMap( Buffer: pointer ); assembler;
asm
  mov   ax, $4E00
  les   di, [Buffer]
  int   $67
  mov   [EMM_Result], ah
end;

procedure EMM_SetPageMap( Buffer: pointer ); assembler;
asm
  push  ds
  mov   ax, $4E01
  lds   si, [Buffer]
  int   $67
  pop   ds
  mov   [EMM_Result], ah
end;

procedure EMM_SetName( Handle: word; Name: string );
var P: pointer;
begin
  EMM_Result := $84;
  if( EMM_Version < $40 ) then Exit;
  while( Length( Name ) < 8 ) do Name := Name + #0;
  P := @Name;
  asm
    push  ds
    mov   ax, $5301
    mov   dx, [Handle]
    lds   si, [P]
    inc   si
    int   $67
    pop   ds
    mov   [EMM_Result], ah
  end
end;

begin
  Check_EMM
end.

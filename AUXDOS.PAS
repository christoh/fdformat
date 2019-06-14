{$A+,B-,D+,E-,F-,I-,L+,N-,O-,R-,S-,V-,X+}

UNIT AuxDos;

{Auxiliary DOS-Interface-Routines}
{Copyright (c) 1990-1991, Christoph H. Hochst„tter}
{Written in Turbo-Pascal 6.0}

INTERFACE

USES dos;

{File open mode and sharing constants}

CONST OReadOnly = 0;
  OWriteOnly    = 1;
  OReadWrite    = 2;
  OCompatibility= $00;
  ODenyAll      = $10;
  ODenyWrite    = $20;
  ODenyRead     = $30;
  ODenyNone     = $40;
  ONoInheritance= $80;

{DOS-File-Handles}

CONST StdNulHandle = 0;
  StdOutHandle     = 1;
  StdErrHandle     = 2;

VAR StdErr        : Text;                       {Define a file variable for standard error output}
    old1B         : Pointer;                                       {Save old Ctrl-Break-Interrupt}
    old23         : Pointer;                                     {Save Old abnormal End Procedure}

CONST ExitRequest : Boolean   = FALSE;                                       {Ctrl-Break pressed?}

PROCEDURE CtrlBreak;
PROCEDURE EndProgram(x: Byte;s: String);
PROCEDURE DefExitProc;
PROCEDURE IgnoreInt;

IMPLEMENTATION

  PROCEDURE CtrlBreak; Assembler;                     {Don't invoke directly (or go to neverland)}
  ASM
    push    ds                 {Save DS}
    {$IFOPT G+}
    push    seg @data          {Push data-segment on stack}
    pop     ds                 {Pop it in DS}
    {$ELSE}
    push    ax                 {Save AX, because it is interrupt}
    mov     ax,seg @data       {Get data segment in AX}
    mov     ds,ax              {Put it in DS}
    pop     ax                 {Restore AX}
    {$ENDIF}
    mov     ExitRequest,True   {Set ExitRequest}
    pop     ds                 {Restore DS}
    iret                       {Exit}
  END;

  PROCEDURE IgnoreInt; Assembler;
  ASM
    iret
  END;

  PROCEDURE EndProgram;
  BEGIN
    IF ExitRequest THEN BEGIN
      WriteLn(stderr,#13#10,s);
      Halt(x);
    END;
  END;

  PROCEDURE DefExitProc;                                                  {Default Exit-Procedure}
  BEGIN
    SetIntVec($1B,old1B);                                       {Restore old Ctrl-Break-Procedure}
    SetIntVec($23,old23);                                   {Restore old abnormal abort Procedure}
    ExitProc:=NIL;
  END;

BEGIN
  move(Output,stderr,SizeOf(stderr));           {Copy Standard-Output File to Standard-Error File}
  TextRec(stderr).Handle:=StdErrHandle;                      {Standard-Error is DOS-File-Handle 2}
  TextRec(stderr).BufPtr:=@TextRec(stderr).Buffer;                            {set our own Buffer}
  GetIntVec($1B,old1B);                                            {Save old Ctrl-Break interrupt}
  GetIntVec($13,old23);
  ExitProc:=@DefExitProc;                             {Restore Ctrl-Break-Interrupt, when exiting}
END.

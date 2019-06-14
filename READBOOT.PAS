{$A+,B-,D+,E-,F-,I-,L+,N-,O-,R-,S-,V-}
{$M 4096,0,655360}
PROGRAM READBOOT;

  {READBOOT - Get Boot Sector from file/Write File to Boot-Sector - Ver 1.21}
  {Compiled with Turbo-Pascal Ver 6.0}
  {Does not compile with earlier versions of Turbo-Pascal}

USES dos,auxdos,diskio;

VAR para   : String[50];
  fn       : String[50];
  f        : FILE;
  lw       : Byte;
  ok       : Boolean;
  written  : Word;
  readdisk : Boolean;
  FileBoot : ^bpbtyp;
  ysec     : LongInt;
  stderr   : Text;

  PROCEDURE SyntaxError;
  BEGIN
    WriteLn(stderr,'Syntax Error.');
    WriteLn(stderr);
    WriteLn(stderr,'Syntax is:  READBOOT <drive>: <file>  (write Boot-Sector to file)');
    WriteLn(stderr,'            READBOOT <file> <drive>:  (read Boot-Sector from file)');
    WriteLn(stderr);
    WriteLn(stderr,'Exapmles: READBOOT A: C:\DISKS\BOOT1.SYS');
    WriteLn(stderr,'          READBOOT C:\DISKS\BOOT1.SYS A:');
    WriteLn(stderr);
    Halt(1);
  END;

  PROCEDURE BootError;
  BEGIN
    WriteLn(stderr,'File ',fn,' is no Boot-Sector image.');
    Close(f);
    Halt(9);
  END;

  PROCEDURE DosError;
  BEGIN
    WriteLn(stderr,'This program requires DOS 3.20 or higher.');
    Halt(10);
  END;

BEGIN
  WriteLn;
  WriteLn('READBOOT-Read/Write Boot-Sector from/to File  V1.21');
  WriteLn('Copyright (c) 1988 - 1991, Christoph H. Hochst„tter');
  WriteLn;
  IF Swap(DosVersion)<$314 THEN DosError;
  IF (Length(ParamStr(1))=2) AND (Length(ParamStr(2))=2) THEN SyntaxError;
  IF Length(ParamStr(1))=2 THEN BEGIN
    para:=ParamStr(1);
    fn:=ParamStr(2);
    readdisk:=True;
  END ELSE IF Length(ParamStr(2))=2 THEN BEGIN
    para:=ParamStr(2);
    fn:=ParamStr(1);
    readdisk:=False;
  END ELSE
    SyntaxError;
  IF fn='' THEN SyntaxError;
  FOR lw:=1 TO Length(fn) DO fn[lw]:=Upcase(fn[lw]);
  IF para[2]<>':' THEN SyntaxError;
  lw:=Ord(Upcase(para[1]))-$40;
  BootSec.init(ok);
  IF NOT(ok) THEN BEGIN
    WriteLn(stderr,'Not enough Memory.');
    Halt(4);
  END;
  BootSec.Readx(lw);
  IF BootSec.UnknownDrive THEN BEGIN
    WriteLn(stderr,'Drive does not exist.');
    Halt(3);
  END;
  IF (BootSec.Status AND $9200) <> 0 THEN BEGIN
    WriteLn(stderr,'READBOOT does not work with a SUBST/ASSIGN/NETWORK Drive.');
    Halt(2);
  END;
  WITH BootSec.bpb^ DO BEGIN
    WriteLn('Information from the floppy:');
    WriteLn('Sectors/Track: ',spt);
    WriteLn('Sides        : ',hds);
    WriteLn('Bytes total  : ',DiskSize(lw));
    WriteLn('Bytes free   : ',DiskFree(lw));
    WriteLn;
    Assign(f,fn);
    IF readdisk THEN BEGIN
      FileMode:=OWriteOnly OR ODenyWrite;
      Rewrite(f,1);
      Reset(f,1);
    END ELSE BEGIN
      FileMode:=OReadOnly OR ODenyWrite;
      Reset(f,1);
    END;
    IF IoResult<>0 THEN BEGIN
      WriteLn(stderr,'File ',fn,' cannot be openend.');
      Close(f);
      Halt(6);
    END;
    IF NOT(readdisk) THEN BEGIN
      IF FileSize(f)<>512 THEN BootError;
      GetMem(FileBoot,512);
      BlockRead(f,FileBoot^,512,written);
      IF (written<>512) OR
      (FileBoot^.boot_code[511]<>$AA) OR
      (FileBoot^.boot_code[510]<>$55) THEN BEGIN
        BootError;
      END;
      WriteLn('Sector-Type  : ',FileBoot^.oem);
      WriteLn;
      Seek(f,0);
    END;
    IF readdisk THEN BEGIN
      BlockWrite(f,BootSec.bpb^,512,written);
      IF written<>512 THEN BEGIN
        WriteLn(stderr,'Disk full - File: ',fn);
        Close(f);
        Halt(19);
      END;
    END ELSE BEGIN
      jmp:=FileBoot^.jmp;
      boot_code:=FileBoot^.boot_code;
      oem:=FileBoot^.oem;
      BootSec.writex(lw);
    END;
    Close(f);
  END;
END.

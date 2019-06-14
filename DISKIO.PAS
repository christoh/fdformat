{$A+,B-,D+,E-,F+,I-,L+,N-,O+,R-,S-,V-,X+}

UNIT diskio;

INTERFACE

USES dos,auxdos;

TYPE Split      = RECORD
                    O: Word;
                    S: Word;
                  END;

TYPE filtyp     = FILE OF ARRAY[0..511] OF Byte;
     fileptr    = ^filtyp;
     boottyp    = ARRAY[62..511] OF Byte;

TYPE bpbtyp     =  RECORD
                     jmp: ARRAY[1..3] OF Byte;                     {Die ersten drei Bytes fr JUMP}
                     oem: ARRAY[1..8] OF Char;                                        {OEM-Eintrag}
                     bps: Word;                                                  {Bytes pro Sektor}
                     spc: Byte;                                              {Sektoren pro Cluster}
                     res: Word;                                                     {BOOT-Sektoren}
                     fat: Byte;                                                  {Anzahl der FAT's}
                     rde: Word;                                          {Basisverzeichniseintr„ge}
                     sec: Word;                                       {Gesamtsektoren der Diskette}
                     mds: Byte;                                                  {Media-Deskriptor}
                     spf: Word;                                                  {Sektoren pro FAT}
                     spt: Word;                                                 {Sektoren pro Spur}
                     hds: Word;                                                            {Seiten}
                     shh: Longint;                                            {Versteckte Sektoren}
                     lsc: Longint;                     {Anzahl der Sektoren bei groáen Partitionen}
                     pdn: Word;                                             {Physical Drive Number}
                     ebs: Byte;                                           {Extended Boot Signature}
                     vsn: LongInt;                                           {Volume Serial-Number}
                     vlb: ARRAY[1..11] OF Char;                                      {Volume Label}
                     fsi: ARRAY[1..8] OF Char;                                     {File System Id}
                     boot_code: boottyp;                                     {Puffer fr BOOT-Code}
                   END;

      bdib      = RECORD
                    flag   : Byte;                                                {Bitmapped flags}
                    dtyp   : Byte;                                                     {Drive Type}
                    dflag  : Word;                                                {Bitmapped flags}
                    noc    : Word;                                            {Number of cylinders}
                    mt     : Byte;                                                     {Media Type}
                    bpb    : ARRAY[0..30] OF Byte;                                            {BPB}
                    nos    : Word;                                    {Number of sectors per track}
                    sly    : ARRAY[0..63] OF RECORD                                 {sector layout}
                                                 num: Word;                         {Sector Number}
                                                 siz: Word;                        {Size of sector}
                                               END;
                  END;

      dos4rw    = RECORD                                                   {Disk Read/Write Packet}
                    sector   : LongInt;                                     {fr Partitionen >=32M}
                    count    : Word;
                    Transfer : Pointer;
                  END;

TYPE  SectorTyp = Object
                    data: Pointer;
                    Start: LongInt;
                    datalen: Word;
                    Constructor init(VAR allocated: Boolean);
                    PROCEDURE Error(lw,rw,err:Byte; VAR er:Boolean; Sector:Longint); virtual;
                    PROCEDURE DiskRw(rw,lw:Byte; Sector:LongInt; Count:Byte; Transfer:Pointer);
                    PROCEDURE Readx(lw: Byte; x: LongInt);
                    PROCEDURE Writex(lw: Byte; x: LongInt);
                    Destructor Done;
                  END;


TYPE CylTyp    = Object (SectorTyp)
                   Constructor init(spcyl: Word; VAR allocated: Boolean);
                   PROCEDURE Readx(lw: Byte; x: Word);
                   PROCEDURE Writex(lw: Byte; x: Word);
                 END;


TYPE BootSecTyp = Object(SectorTyp)
                    bpb: ^bpbtyp;
                    status: Word;
                    Media: Byte;
                    UnknownDrive: Boolean;
                    dos4: Boolean;
                    Constructor init(VAR allocated: Boolean);
                    PROCEDURE Readx(lw: Byte);
                    PROCEDURE Writex(lw: Byte);
                    PROCEDURE Remount(lw: Byte);
                  END;

TYPE STyp       = ARRAY[0..0] OF ^SectorTyp;
     CTyp       = ARRAY[0..0] OF ^CylTyp;
     Smtyp      = ^Styp;
     Cmtyp      = ^CTyp;



VAR BootSec         : BootSecTyp;
  maxsec            : Word;
  maxcyl            : Word;


  PROCEDURE CheckDrive(lw:Byte; VAR Status:Word; VAR error1:Boolean; VAR Media:Byte);
  PROCEDURE DeallocCyl(Var Cylmem:Cmtyp; Stop:Word);
  PROCEDURE DeallocSec(Var Secmem:Smtyp; Stop:Word);
  FUNCTION AllocCyl(VAR Cylmem:Cmtyp; Stop:Word): Word;
  FUNCTION AllocSec(VAR secmem:Smtyp; stop:Word): Word;
  FUNCTION ReadKey: Char;

IMPLEMENTATION

  FUNCTION ReadKey:Char; Assembler;
    ASM
      mov   ah,8
      int   21h
    END;

  PROCEDURE Sectortyp.error(lw,rw,err:Byte; VAR er:Boolean; Sector:Longint);
  VAR chx: Char;
  BEGIN
    WITH BootSec DO BEGIN
      WriteLn(stderr);
      IF rw=0 THEN
        Write(stderr,'Read')
      ELSE
        Write(stderr,'Write');
      Write(stderr,'-Error Drive ',chr(lw+$40),': ');
      CASE err OF
        $00: Write(stderr,'Disk is write protected');
        $01: Write(stderr,'Unknown unit');
        $02: Write(stderr,'Drive not ready');
        $03: Write(stderr,'Unknown command');
        $04: Write(stderr,'Bad CRC');
        $05: Write(stderr,'Bad request structure length');
        $06: Write(stderr,'Seek error');
        $07: Write(stderr,'Unknown media type');
        $08: Write(stderr,'Sector not found');
        $09: Write(stderr,'Printer out of paper');
        $0A: Write(stderr,'Write fault');
        $0B: Write(stderr,'Read fault');
        $0C: Write(stderr,'General failure');
        $0D: Write(stderr,'Sharing violation');
        $0E: Write(stderr,'Lock violation');
        $0F: Write(stderr,'Invalid disk change');
        $10: Write(stderr,'FCB unavailable');
        $11: Write(stderr,'Sharing buffer overflow');
        ELSE Write(stderr,'Unknown error');
      END;
      Writeln(stderr,'.');
      Write(stderr,'Error ',err,': Sector: ',Sector,' ');
      IF Sector=0 THEN
        WriteLn(stderr,'BOOT-Sector')
      ELSE BEGIN
        IF (Sector>=1) and (Sector<=bpb^.spf) THEN
          WriteLn(stderr,'FAT 1');
        IF (Sector>=bpb^.spf+1) and (sector<=Longint(bpb^.spf) shl 1) THEN
          WriteLn(stderr,'FAT 2');
      END;
      REPEAT
        Write(stderr,'(A)bort, (R)etry, (I)gnore ? ');
        chx:=Upcase(ReadKey); WriteLn(stderr,chx);
      UNTIL chx IN ['A','I','R'];
      CASE chx OF
        'A': Halt(255);
        'I': BEGIN
               er:=False;
             END;
        'R': er:=True;
      END;
    END;
  END;

  Constructor SectorTyp.init(VAR allocated: Boolean);
  BEGIN
    allocated:=True;
    IF MaxAvail<512 THEN allocated:=False;
    IF allocated THEN BEGIN
      GetMem(self.data,512);
      datalen:=512;
    END;
  END;

  PROCEDURE int2526(rw,lw:Byte; Sector:Longint; Count:Word; Transfer:Pointer; Var flags,rax: Word); Far;
  LABEL common;
  VAR rwpacket: dos4rw;
  BEGIN
    IF NOT(BootSec.Dos4) THEN BEGIN
      ASM
        @start: mov   dx,ss:[bp+20]            {Low half of Sector}
                mov   cx,count
                push  ds
                lds   bx,transfer
        common: mov   al,lw
                cmp   byte ptr ss:[bp+26],1    {rw}
                push  bp                       {DOS 3 alters BP, grrrr...}
                jz    @write
                int   25h
                jmp   @all
        @write: int   26h
        @all:   pop   cx
                pop   bp
                pop   ds
                les   bx,flags
                pushf
                pop   cx
                mov   es:[bx],cx
                les   bx,rax
                mov   es:[bx],ax
      END;
    END ELSE BEGIN
      rwpacket.sector:=sector;
      rwpacket.count:=count;
      rwpacket.Transfer:=Transfer;
      ASM
        @start: mov   cx,0ffffh
                push  ds
                push  ss
                pop   ds
                lea   bx,rwpacket
                jmp   common
      END;
    END;
  END;

  PROCEDURE SectorTyp.DiskRw(rw,lw:Byte; Sector:Longint; Count:Byte; Transfer:Pointer);
  VAR flags,rax: Word;
    er         : Boolean;
    i          : Word;
  BEGIN
    int2526(rw,lw-1,Sector,Count,Transfer,flags,rax);
      IF (FCarry AND Flags) <> 0 THEN
        FOR i:=0 TO Count-1 DO
          REPEAT
            int2526(rw,lw-1,Sector+i,1,ptr(Split(Transfer).S,Split(Transfer).O+(i shl 9)),flags,rax);
            er:=False;
            IF (FCarry AND Flags) <> 0 THEN error(lw,rw,lo(rax),er,Sector+i);
          UNTIL NOT er;
  END;

  PROCEDURE SectorTyp.Readx(lw: Byte; x: LongInt);
  BEGIN
    self.DiskRw(0,lw,x,1,self.data);
  END;

  PROCEDURE SectorTyp.Writex(lw: Byte; x: LongInt);
  BEGIN
    self.DiskRw(1,lw,x,1,self.data);
  END;

  Constructor CylTyp.init(spcyl: Word; VAR allocated: Boolean);
  BEGIN
    allocated:=True;
    datalen:=spcyl SHL 9;
    IF MaxAvail<datalen THEN allocated:=False;
    IF allocated THEN BEGIN
      GetMem(self.data,datalen);
    END;
  END;

  PROCEDURE CylTyp.Readx(lw: Byte; x:Word);
  BEGIN
    self.DiskRw(0,lw,LongInt(x)*(datalen SHR 9),datalen SHR 9,self.data);
  END;

  PROCEDURE CylTyp.Writex(lw: Byte; x:Word);
  BEGIN
    self.DiskRw(1,lw,LongInt(x)*(datalen SHR 9),datalen SHR 9,self.data);
  END;

  Constructor BootSecTyp.init(VAR allocated: Boolean);
  BEGIN
    allocated:=True;
    IF MaxAvail<512 THEN allocated:=False;
    IF allocated THEN BEGIN
      GetMem(self.data,512);
      self.bpb:=self.data;
      datalen:=512;
    END;
  END;

  PROCEDURE BootSecTyp.Readx(lw: Byte);
  BEGIN
    CheckDrive(lw,self.status,self.UnknownDrive,self.Media);
    self.dos4:=false;
    if not(UnknownDrive) and ((self.status and $9202)=2) then
      self.dos4:=true;
    if not(UnknownDrive) and ((self.status and $9200)=0) then
    self.DiskRw(0,lw,0,1,self.data);
  END;

  PROCEDURE BootSecTyp.Writex(lw: Byte);
  BEGIN
    self.DiskRw(1,lw,0,1,self.data);
  END;

  Destructor SectorTyp.Done;
  BEGIN
    FreeMem(self.data,datalen);
  END;

  PROCEDURE BootSecTyp.Remount(lw: Byte);
  VAR buffer: bdib;
   regs     : Registers;
   er       : Boolean;
  BEGIN
    Self.Readx(lw);
    er:=False;
    REPEAT
      regs.bx:=lw;
      regs.ax:=$440D;
      regs.cx:=$860;
      regs.ds:=Seg(buffer);
      regs.dx:=Ofs(buffer);
      buffer.flag:=5;
      msdos(regs);
      IF (regs.Flags AND FCarry) <> 0 THEN self.Error(lw,0,regs.al,er,0);
    UNTIL not(er);
    Move(bpb^.bps,buffer.bpb,31);
    REPEAT
      regs.bx:=lw;
      regs.ax:=$440D;
      regs.cx:=$840;
      regs.ds:=Seg(buffer);
      regs.dx:=Ofs(buffer);
      buffer.flag:=4;
      buffer.nos:=0;
      msdos(regs);
      IF (regs.Flags AND FCarry) <> 0 THEN self.Error(lw,0,regs.al,er,0);
    UNTIL not(er);
  END;


  FUNCTION AllocSec(VAR secmem:Smtyp; Stop:Word): Word;
  VAR i: Word;
    ok: Boolean;
  BEGIN
    GetMem(secmem,(Stop+1)*4);
    FOR i:=0 to Stop do Secmem^[i]:=NIL;
    i:=0;
    REPEAT
      IF (4512>MaxAvail) OR (secmem^[i]<>NIL) THEN
        ok:=False
      ELSE BEGIN
        New(secmem^[i],init(ok));
        IF ok THEN Inc(i);
      END;
    UNTIL NOT(ok) OR (i>stop);
    Dec(i);
    AllocSec:=i;
  END;

  FUNCTION AllocCyl(VAR Cylmem:Cmtyp; Stop:Word): Word;
  VAR i: Word;
    ok: Boolean;
  BEGIN
    GetMem(cylmem,(Stop+1)*4);
    FOR i:=0 to Stop do Cylmem^[i]:=NIL;
    i:=0;
    REPEAT
      IF (((BootSec.bpb^.spt*BootSec.bpb^.hds) SHL 9)+4000>MaxAvail) OR
      (cylmem^[i]<>NIL) THEN
        ok:=False
      ELSE BEGIN
        New(cylmem^[i],init(BootSec.bpb^.spt*BootSec.bpb^.hds,ok));
        IF ok THEN Inc(i);
      END;
    UNTIL NOT(ok) OR (i>stop);
    Dec(i);
    AllocCyl:=i;
  END;

  PROCEDURE DeallocCyl(Var Cylmem:Cmtyp; Stop:Word);
  VAR i: Word;
  BEGIN
    FOR i:=0 TO stop DO BEGIN
      Dispose(cylmem^[i],Done);
    END;
    FreeMem(cylmem,(Stop+1)*4);
  END;

  PROCEDURE DeallocSec(Var Secmem:Smtyp; Stop:Word);
  VAR i: Word;
  BEGIN
    FOR i:=0 TO stop DO BEGIN
      Dispose(secmem^[i],Done);
    END;
    FreeMem(secmem,(Stop+1)*4);
  END;

  PROCEDURE CheckDrive(lw:Byte; VAR Status:Word; VAR error1:Boolean; VAR Media:Byte);
  VAR regs: registers;
    driveinfo : ARRAY[0..48] OF Byte;
  BEGIN
    WITH regs DO BEGIN
      ax:=$4409;
      bl:=lw;
      bh:=0;
      intr($21,regs);
      error1:=(FCarry AND Flags) <> 0;
      Status:=dx;
      ax:=$440d;
      cx:=$860;
      bl:=lw;
      bh:=0;
      dx:=Ofs(driveinfo);
      ds:=Seg(driveinfo);
      intr($21,regs);
      Media:=driveinfo[1];
    END;
  END;

END.

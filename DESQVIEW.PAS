{$F+,O+,I-}

UNIT desqview;

INTERFACE

USES dos;

TYPE   str2   = String[2];

VAR desqresult  : Byte;
  desqregs    : Registers;
  desqversion : Word;

FUNCTION DesqviewPresent:Boolean;
PROCEDURE StartTask(x: str2);
PROCEDURE GiveUpCPU;
PROCEDURE GiveUpIdle;
PROCEDURE ExitTask;

IMPLEMENTATION

  FUNCTION DesqviewPresent;
  BEGIN
    desqresult:=0;
    WITH desqregs DO BEGIN
      ax:=$2b01;
      bx:=0;
      cx:=$4445;
      dx:=$5351;
      msdos(desqregs);
      IF bx=2 THEN bx:=Swap(bx);
      IF bx=0 THEN DesqviewPresent:=False ELSE DesqviewPresent:=True;
      desqversion:=bx;
    END;
  END;

  PROCEDURE StartTask;
  VAR fn: pathstr;
    pif : ARRAY[0..415] OF Byte;
    f   : FILE;
  BEGIN
    desqresult:=0;
    IF (DesqviewPresent) AND (desqversion>=$200) THEN BEGIN
      fn:=FSearch(x+'-PIF.DVP',GetEnv('PATH'));
      IF fn='' THEN BEGIN
        desqresult:=1;
        Exit;
      END;
      Assign(f,fn);
      Reset(f,1);
      IF IoResult<>0 THEN BEGIN
        desqresult:=2;
        Exit;
      END;
      IF FileSize(f)<>416 THEN BEGIN
        desqresult:=3;
        Close(f);
        Exit;
      END;
      BlockRead(f,pif,416);
      IF IoResult<>0 THEN BEGIN
        desqresult:=4;
        Close(f);
        Exit;
      END;
      Close(f);
      WITH desqregs DO BEGIN
        ds:=Seg(pif);
        es:=Seg(pif);
        di:=Ofs(pif);
        bx:=$1a0;
        ax:=$102c;
        intr($15,desqregs);
        IF bx=0 THEN BEGIN
          desqresult:=6;
          Exit;
        END;
      END;
    END ELSE
      desqresult:=5;
  END;

  PROCEDURE GiveUpCPU;
  BEGIN
    WITH desqregs DO BEGIN
      ax:=$1000;
      intr($15,desqregs);
    END;
  END;

  PROCEDURE GiveUpIdle;
  BEGIN
    WITH desqregs DO BEGIN
      ah:=1;
      intr($16,desqregs);
      IF (flags AND FZero) <> 0 THEN GiveUpCPU;
    END;
  END;

  PROCEDURE ExitTask;
  BEGIN
    IF DesqviewPresent THEN intr($19,desqregs);
    desqresult:=1;
  END;

END.

{BASE Convert Unit for Turbo-Pascal 5.5}
{Copyright (c) 1989 Christoph H. Hochst„tter}


{$A+,B-,D+,F-,I-,L+,R-,S-,V-}
UNIT baseconv;

INTERFACE

TYPE basestr = String[32];

VAR BaseError: Byte;

FUNCTION base(x:LongInt;b:Byte):basestr;                                                {Convert x to base b}
FUNCTION basef(x:LongInt;b,f:Byte):basestr;                                    {Convert x to base b length f}
FUNCTION hex(x:LongInt):basestr;                                                       {Convert x to base 16}
FUNCTION hexf(x:LongInt;f:Byte):basestr;                                      {Convert x to base 16 length f}
FUNCTION dez(x:basestr;s:Byte):LongInt;                                    {Convert x from Base s to decimal}
FUNCTION dezh(x:basestr):LongInt;                                          {Convert hexadecimal x to decimal}

IMPLEMENTATION

VAR   o: basestr;
CONST h: String[36] = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
VAR   i: Byte;
CONST n: String[31] = '0000000000000000000000000000000';

  FUNCTION base;

    PROCEDURE base1(x: LongInt);
    BEGIN
      IF x>Pred(b) THEN base1(x DIV b);
      o:=o+h[Succ(x MOD b)];
    END;

  BEGIN                                                                                                {base}
    IF b>36 THEN BEGIN
      BaseError:=1;
      Exit;
    END ELSE
      BaseError:=0;
    IF x<0 THEN
      o:='-'
    ELSE
      o[0]:=Chr(0);
    base1(Abs(x));
    base:=o;
  END;

  FUNCTION hex;
  BEGIN
    hex:=base(x,16);
  END;


  FUNCTION basef;
  BEGIN
    o:=base(x,b);
    IF BaseError <> 0 THEN Exit;
    IF Ord(o[0])>f THEN
      BaseError:=2
    ELSE BEGIN
      n[0]:=Chr(f-Ord(o[0]));
      IF x<0 THEN i:=2 ELSE i:=1;
      Insert(n,o,i);
    END;
    basef:=o;
  END;

  FUNCTION hexf;
  BEGIN
    hexf:=basef(x,16,f);
  END;

  FUNCTION dez;
  VAR a: Byte;
    b,c: LongInt;
  BEGIN
    BaseError:=0;
    c:=1;
    b:=0;
    FOR i:=Length(x) DOWNTO 1 DO
      IF BaseError=0 THEN BEGIN
        a:=Pred(pos(Upcase(x[i]),h));
        IF (a=255) OR (a>=s) THEN BaseError:=1;
        b:=b+c*a;
        c:=s*c;
      END;
    dez:=b;
  END;

  FUNCTION dezh;
  BEGIN
    dezh:=dez(x,16);
  END;

END.

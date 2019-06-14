USES baseconv;

VAR c: Byte;
  f:   FILE OF Byte;
  g:   Text;
  i:   Word;

BEGIN
  Assign(f,ParamStr(1));
  Assign(g,ParamStr(2));
  Reset(f);
  Rewrite(g);
  Seek(f,62);
  FOR i:=63 TO 512 DO BEGIN
    Read(f,c);
    if i<>512 then
      write(g,'$',hexf(c,2),',')
    else
      write(g,'$',hexf(c,2));
    IF i MOD 16=0 THEN WriteLn(g);
  END;
  Close(f);
  Close(g);
END.

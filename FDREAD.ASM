             page      68,129

IFIS286      MACRO     cp,i
             IFIDN     <CP>,</$G+>
             ENDM

IFIS88       MACRO     cp,i
             IFIDN     <CP>,</$G->
             ENDM

             IFNDEF    CPU
             %out      No CPU defined for Assembly, defaulting to 286
CPU          EQU       </$G+>
             ENDIF
             IFIS286   %CPU
             .286
             ENDIF
             title     fdread - lesen von disketten aller formate

             .radix    10

startadr     equ       0ff80h

cseg         segment   use16 word public 'code'
             assume    cs:cseg,ds:nothing,es:nothing,ss:nothing

             org       0

lex          equ       offset end_hdr-offset int13_2
lex2         equ       (lex+15)/16
lex3         equ       offset begin-offset start
lex4         equ       (lex3+15)/16

int13_2      label     dword                ;HMA Einsprung INT13
int13_2ofs   dw        entry                ;Offset-Teil
int13_2seg   dw        ?                    ;Segment-Teil

xms          label     dword                ;Speicher fÅr XMS-Einsprungaddresse
xms_ofs      dw        ?
xms_seg      dw        ?

             .286                           ;Der folgende Teil wird nur bei 286+ relevant
int13_1      proc      far                  ;INT-09 Handler
             pusha                          ;Alle Register retten
             mov       ah,7                 ;Code fÅr A20 testen
             call      dword ptr xms        ;Rufe XMS-Manager auf
             dec       ax                   ;Ist A20 enabled (Ja: AX=1)
             jz        ret1                 ;Wenn, ja ist hier alles erledigt
             mov       ah,5                 ;Code fÅr A20 local enablen
             call      dword ptr xms        ;Rufe XMS-Manager auf
ret1:        popa                           ;Alle Register wiederherstellen
             jmp       int13_2              ;FÅhre den eigentlichen Handler aus
int13_1      endp

             .8086

end_hdr:

             org       startadr

start:

             IFIS286   %CPU
             even
             .286
             ENDIF

old13        label     dword                               ;Speicherung des alten Interrupt 13
old13_ofs    dw        ?                                   ;Offset-Teil
old13_seg    dw        ?                                   ;Segment-Teil
oldsec       db        ?

entry        proc      far
             push      ax                                  ;AX retten
             or        ah,ah                               ;Wurde Funktion 0 RESET aufgerufen?
             jz        donothing                           ;Ja, dann Ende
             cmp       ah,4                                ;Wurde Funktion Åber 4 aufgerufen?
             ja        donothing                           ;Ja, dann Ende
             cmp       dl,3
             ja        donothing
             push      bx                                  ;...Register...
             push      ds                                  ;...retten
             IFIS286   %CPU
             push      0
             ELSE
             xor       bx,bx
             push      bx
             ENDIF
             pop       ds
             lds       bx,ds:[78h]                         ;Disk-Parameter Tabelle in DS:BX
             mov       al,ds:[bx+4]
             mov       oldsec,al
             mov       byte ptr ds:[bx+4],1Bh              ;Setze auf maximal 25 Sektoren/Spur
             IFIS286   %CPU
             or        ch,ch                               ;Track 0 ?
             jz        exit                                ;Ja, dann Ende
             ENDIF
             pop       ds                                  ;Alle...
             pop       bx                                  ;...Register...
             pop       ax                                  ;...zurÅckholen.
             push      ax                                  ;AX fÅr spÑter speichern
             pushf                                         ;Flags pushen da INT-CALL
             call      old13                               ;Alten INT 13 aufrufen
             IFIS286   %CPU
             jnc       okexit                              ;Kein Fehler, dann Ende
             pop       ax                                  ;Hole uns AX zurÅck
             push      ds                                  ;Speichere...
             push      bx                                  ;...DS & BX
             push      40h                                 ;BIOS-Data Segment...
             pop       ds                                  ;...nach DS
             mov       bx,90h                              ;Beginn der Drive-Tabelle
             add       bl,dl                               ;Offset des Laufwerks
             cmp       ch,43                               ;Track>43
             ja        nodstep                             ;Ja, dann niemals DSTEP
             xor       byte ptr ds:[bx],20h                ;invertiere das Stepper-Bit
             jmp       short stepend                       ;Ende vom Stepping
nodstep:     and       byte ptr ds:[bx],0dfh               ;Kein Double-Stepping
stepend:     pop       bx                                  ;Hole BX und..
             pop       ds                                  ;...DS zurÅck
             jmp       short endrout2                      ;Routine zu Ende
exit:        pop       ds                                  ;Hole alle benutzten...
             pop       bx                                  ;...Register...
             pop       ax                                  ;...wieder zurÅck
endrout2:    pushf
endrout:     call      old13                               ;Springe an den alten Interrupt 13
             push      ax
             ENDIF
okexit:      push      ax
             push      bx
             push      ds
             IFIS286   %CPU
             push      0
             ELSE
             xor       bx,bx
             push      bx
             ENDIF
             pop       ds
             lds       bx,ds:[78h]                         ;Disk-Parameter Tabelle in DS:BX
             mov       al,oldsec
             mov       ds:[bx+4],al
             pop       ds
             pop       bx
             pop       ax

             inc       sp                                  ;Werfe den...
             inc       sp                                  ;...gesicherten AX weg
             ret       2                                   ;Und Ende mit original Flags

donothing:   pop       ax
             jmp       old13

entry        endp

begin:

cseg         ends

iseg         segment   use16 para public 'code'
             assume    cs:iseg,ds:iseg      ;Assembler die...
             assume    es:cseg,ss:sseg      ;...Segment Register mitteilen

umbok        dw        ?
loadseg      dw        cseg

begin2:
             push      cs                   ;
             pop       ds                   ;DS=CS
             mov       dx,offset texthallo  ;Begruessungstext in DX
             mov       ah,9                 ;Ausgabe...
             int       21h                  ;...Åber DOS
             mov       ah,30h               ;Hole...
             int       21h                  ;...die DOS-Version
             xchg      ah,al                ;AH und AL vertauschen
             cmp       ax,314h              ;Ist es mindestens DOS 3.20
             jae       versionok            ;Ja, Ok
             mov       dx,offset textdosbad ;Sonst leider Pech
             mov       ah,9                 ;Und Meldung...
             int       21h                  ;...ausgeben
             mov       ax,4c04h             ;Fehlernummer 4
             int       21h                  ;Und Ende

             include   cputest.asm

versionok:
             IFIS286   %CPU
             call      MachineCheck
             cmp       ax,1
             jnz       cpuok
             mov       dx,offset textlp
             mov       ah,9
             int       21h
             ENDIF
cpuok:       mov       ah,51h               ;Hole den PSP...
             int       21h                  ;...in BX
             push      bx                   ;Speichern fÅr spÑter
             push      bx                   ;Und auch in...
             pop       ds                   ;...DS
             mov       es,ds:[2ch]          ;Environment in ES
             mov       ah,49h               ;Und freigeben,...
             int       21h                  ;...da wir es nicht brauchen
             pop       es                   ;PSP nun in ES
             mov       bx,6                 ;Grî·e des Blocks auf...
             mov       ah,4ah               ;Minimum von 6*16 Bytes...
             int       21h                  ;...=6 Paragraphen Ñndern
             mov       ax,cseg              ;CSEG...
             mov       es,ax                ;...in ES
             mov       ax,cs                ;Mal schauen,
             cmp       ax,0a000h            ;ob High-Load Versuch
             jb        nohi                 ;Nein, dann ok.
             mov       dx,offset hitext     ;Sonst Meldung...
             mov       ah,9                 ;...ausgeben...
             int       21h                  ;...Åber DOS
             mov       ax,4c02h             ;Programm mit Fehler 2...
             int       21h                  ;...beenden

nohi:        mov       ah,30h               ;So, noch mal die DOS-Version...
             int       21h                  ;...in AX
             cmp       al,9                 ;Ist es OS/2
             jbe       noos_2               ;Nein, dann weiter
             mov       dx,offset os2text    ;Sonst Falsche DOS-Version...
             mov       ah,9                 ;...ausgeben
             int       21h
             mov       ax,4c03h             ;Programm mit Fehler 3
             int       21h                  ;beenden

nohma:       jmp       nohma2               ;Hilfssprung
noxms:       jmp       noxms2

noos_2:      cmp       al,5                 ;Ist es mindestens DOS5?
             jb        nohma                ;Nein, dann ohne HMA
             mov       ax,4300h             ;Mal sehen,...
             int       2fh                  ;...ob ein XMS-Treiber da ist?
             cmp       al,80h               ;Nein?
             jnz       noxms                ;Dann keine HMA
             .286                           ;Wenn XMS da, dann auch mindestens 80286
             assume    es:nothing,ds:cseg
             push      es                   ;Sichere ES
             push      cseg                 ;Das CSEG...
             pop       ds                   ;in DS
             mov       ax,4310h             ;Wir...
             int       2fh                  ;...holen wir uns die...
             mov       xms_ofs,bx           ;...Far-Call-Adresse...
             mov       xms_seg,es           ;...und speichern sie ab
             pop       es                   ;ES restaurieren
             mov       ax,4a01h             ;Suche nach freien Bytes...
             int       2fh                  ;...in der HMA
             cmp       di,startadr          ;Sind genug Bytes frei?
             ja        nohma                ;Nein, dann ohne HMA
             mov       dx,offset texthma    ;Aha, wir kînnen in die HMA laden
             assume    ds:iseg
             push      ds                   ;Speichere DS
             push      cs                   ;Und lade DS...
             pop       ds                   ;...mit CS
             mov       ah,9                 ;So nun Text...
             int       21h                  ;...Åber DOS ausgeben
             pop       ds                   ;DS wiederherstellen
             assume    ds:cseg,es:cseg
             mov       ax,4a02h             ;Wir benîtigen einige Bytes aus der HMA
             mov       bx,offset 0-startadr ;Anzahl in BX
             int       2fh                  ;Und reservieren
             mov       ax,offset startadr   ;Damit die startadr immer gleichbleibt...
             sub       ax,di                ;...mÅssen wir das Segment...
             shr       ax,4                 ;...entsprechend anpassen
             not       ax                   ;Noch mal negieren
             mov       es,ax                ;Und in ES schreiben
             mov       si,startadr          ;SI und DI
             mov       di,si                ;beide auf Startadr
             mov       cx,offset begin-start;Anzahl der Bytes
             cld                            ;Direction Bit auf forward
             rep       movsb                ;Und Block in die HMA bewegen
             push      cseg                 ;Das CSEG...
             pop       ds                   ;In DS
             mov       ds:int13_2seg,es     ;Und das neue HMA-Segment abspeichern
             push      es                   ;Jetzt wieder das alte...
             pop       ds                   ;...in DS
             assume    es:nothing,ds:cseg
             mov       ax,3513h             ;Alter INT13-Handler...
             int       21h                  ;...in ES:BX
             mov       old13_seg,es         ;Und...
             mov       old13_ofs,bx         ;...abspeichern
             push      cseg
             pop       ds
             mov       dx,lex2
             push      dx                   ;Merke die benîtigten Paragraphen
             mov       ah,10h               ;XMS-Call 10 (Request-UMB)
             call      xms                  ;Rufe XMS-Driver
             pop       cx                   ;Benîtigte Paragraphen in CX
             cmp       ax,1                 ;Ist was schiefgelaufen?
             jnz       noumb                ;Ja, dann machen wirs ohne UMB
             mov       loadseg,bx           ;Speichere das HMA-Segment
             cmp       dx,cx                ;Vergleiche benîtigte und erhaltene Paragraphen
             jb        toosmall             ;UMB-Block zu klein?
             mov       dx,offset textumb    ;Text, da· die 48 Bytes Einsprung im UMB liegen
             jmp       short notsmall       ;Und Sprung

toosmall:    mov       dx,bx                ;Ok, war zu klein
             mov       ah,11h               ;Dann werfen wir ihn wieder weg
             call      xms                  ;Aufrufen

noumb:       mov       ax,5800h             ;Da es im UMB nicht ging, versuchen wirs mit DOS
             int       21h                  ;Erstmal die alte Allocation-Strategy in AX
             push      ax                   ;Abspeichern
             mov       ax,5802h             ;Alten UMB Link State...
             int       21h                  ;...in AX
             push      ax                   ;Abspeichern
             mov       ax,5803h             ;Jetzt UMBs linken
             mov       bx,1
             int       21h
             mov       bx,81h               ;Neue Strategie. So klein wie mîglich,...
             mov       ax,5801h             ;...aber zuerst im High-Memory suchen.
             int       21h
             mov       bx,lex2              ;LÑnge des Einsprungs
             mov       ah,48h               ;DOS-Call: Speicher anfordern
             int       21h
             mov       loadseg,ax           ;Segment abspeichern
             dec       ax                   ;Auf den MCB des Segments zeigen
             mov       ds,ax                ;Und in DS
             mov       word ptr ds:[1],8    ;Auf System-Block, damit er nicht verschwindet
             pop       bx                   ;UMB-Link State restaurieren
             xor       bh,bh                ;BH muss 0 sein fÅr DOS 5
             mov       ax,5803h             ;Und Åber DOS...
             int       21h                  ;...wieder installieren
             pop       bx                   ;Memory-Allocation Strategy restaurieren
             mov       ax,5801h             ;Setze Allocation-Strategy
             xor       bh,bh                ;Auch hier BH=0!!!
             int       21h                  ;So und installieren
             mov       dx,offset textdos5   ;Text-laden
notsmall:    push      iseg                 ;Install-Segment...
             pop       ds                   ;in DS
             assume    ds:iseg
             mov       ah,9                 ;Text Åber DOS...
             int       21h                  ;ausgeben
             cld                            ;Direction Flag auf forward
             xor       si,si                ;SI und DI sind immer 0
             mov       di,si
             mov       es,loadseg           ;Das Ladesegment in ES (DOS oder UMB)
             push      cseg                 ;Code-Segment...
             pop       ds                   ;...in DS
             assume    ds:cseg
             mov       cx,offset end_hdr    ;Anzahl der Bytes (48)
             rep       movsb                ;Und verschieben
             push      es                   ;Ladesegment auch...
             pop       ds                   ;in DS
             mov       ax,2513h             ;Neuen INT13-Handler...
             mov       dx,offset int13_1    ;installieren
             int       21h
stdexit:     mov       ax,4c00h             ;Programm erfolgreich...
             int       21h                  ;...beendet

             .8086
nohma2:      mov       ax,4300h             ;Mal sehen,...
             int       2fh                  ;...ob ein XMS-Treiber da ist?
             cmp       al,80h               ;Nein?
             jnz       noxms3               ;Dann auch kein UMB
             .286                           ;Wenn XMS da, dann auch mindestens 80286
             assume    es:nothing,ds:cseg
             push      cseg
             pop       ds
             mov       ax,4310h             ;Wir...
             int       2fh                  ;...holen wir uns die...
             mov       xms_ofs,bx           ;...Far-Call-Adresse...
             mov       xms_seg,es           ;...und speichern sie ab
             mov       dx,lex4
             push      dx                   ;Merke die benîtigten Paragraphen
             mov       ah,10h               ;XMS-Call 10 (Request-UMB)
             call      xms                  ;Rufe XMS-Driver
             pop       cx                   ;Benîtigte Paragraphen in CX
             cmp       ax,1                 ;Ist was schiefgelaufen?
noxms3:      jnz       noxms2               ;Ja, dann machen wirs ohne UMB
             mov       cs:loadseg,bx        ;Ladesegment abspeichern
             cmp       dx,cx                ;Vergleiche benîtigte und erhaltene Paragraphen
             jb        toosmall2            ;UMB-Block zu klein?
             mov       dx,offset textumb2   ;Text, da· in UMB geladen wird.

             .8086                          ;Hier kommen auch unsere XT-Freunde wieder hin.
loadgem:     mov       ax,iseg
             mov       ds,ax
             mov       ah,9
             int       21h
             mov       ax,cseg              ;CSEG...
             mov       ds,ax                ;...in DS
             assume    es:nothing,ds:cseg
             mov       ax,3513h             ;Alter INT16-Handler...
             int       21h                  ;...in ES:BX
             mov       old13_seg,es         ;Und...
             mov       old13_ofs,bx         ;...abspeichern
             mov       bx,cs:loadseg        ;Ladesegment in BX
             sub       bx,startadr/16       ;So Startadr abziehen, damit Offset=startadr
             jc        schade               ;Wenn öberlauf, dann kînnen wir nicht laden
             push      bx                   ;Neues Ladesegment
             pop       es                   ;in ES
             mov       di,startadr          ;DI und SI...
             mov       si,di                ;...auf startadr
             cld                            ;VorwÑrts verschieben
             mov       cx,lex3              ;LÑnge in CX
             mov       ax,cseg              ;Code-Segment...
             mov       ds,ax                ;...in DS
             rep       movsb                ;Und verschieben
             push      es                   ;Das neue Segment...
             pop       ds                   ;...auch in DS
             assume    ds:cseg,es:cseg
             mov       dx,offset entry      ;Neuer INT09 Einsprung...
             mov       ax,2513h             ;...in DS
             int       21h                  ;Installieren
             jmp       stdexit              ;Und normal beenden

toosmall2:   mov       dx,bx                ;Ok, war zu klein
             mov       ah,11h               ;Dann werfen wir ihn wieder weg
             call      xms                  ;Aufrufen

noxms2:      mov       ax,5800h             ;Alte Speicherzuweisungsstrategie...
             int       21h                  ;...in AX
             push      ax                   ;Speichern fÅr spÑter
             mov       ax,5802h             ;UMB Link-State...
             int       21h                  ;in AX
             push      ax                   ;Speichern fÅr spÑter
             mov       ax,5803h             ;UMB-Link-State...
             mov       bx,1                 ;...auf on...
             int       21h                  ;setzen
             mov       bx,81h               ;Erstmal High-Memory absuchen
             jnc       dos5                 ;Alles klar, dann weiter
             mov       bx,1                 ;Oh, Uralt-DOS <= 4, dann kein High-Memory
dos5:        mov       ax,5801h             ;Setze die...
             int       21h                  ;...Speicherzuweisungsstrategie
             mov       bx,lex4              ;LÑnge des residenten Teils in Paragraphen
             mov       ah,48h               ;anfordern von DOS
             int       21h
             mov       cs:loadseg,ax        ;Und erstmal abspeichern
             dec       ax                   ;Auf MCB vom Segment zeigen
             mov       ds,ax                ;Und ins DS
             mov       word ptr ds:[1],8    ;Jetzt als System markieren, damits reserviert bleibt
             pop       bx                   ;UMB-Link State restaurieren
             xor       bh,bh                ;BH immer 0, sonst flippt DOS 5 aus.
             mov       ax,5803h             ;Und den alten State...
             int       21h                  ;...Åber DOS wiederherstellen
             pop       bx                   ;Alte Speicherzuweisungsstrategie wieder vom Stack
             mov       ax,5801h             ;Funktion Setze Speicherzuweisungsstrategie
             xor       bh,bh                ;Auch hier BH wieder auf 0
             int       21h                  ;Und restaurieren
             mov       dx,offset textconv   ;Kleine Meldung
             jmp       loadgem              ;Und dann laden, wie bei UMB

schade:      mov       dx,offset textfzk    ;Tja zuviel Speicher unterhalb 640 kB
             mov       ax,iseg              ;Offset in DX
             mov       ds,ax                ;Segment in DS
             mov       ah,9                 ;Funktion: Textstring ausgeben
             int       21h                  ;Und Åber DOS ausgeben.
             mov       ax,4c03h             ;Mit Errorlevel 3...
             int       21h                  ;beenden.

             IFIS286   %CPU
texthallo    db        'FDREAD/286 - (c) Christoph HochstÑtter - Version 1.8',10,10,13,"$"
textlp       db        'This program requires at least a 286 processor.',10,13,"$"
             db        'Use FDR88 instead.',10,13,"$"
             ELSE
texthallo    db        'FDREAD/88 - (c) Christoph HochstÑtter - Version 1.8',10,10,13,"$"
             ENDIF
hitext       db        'Do not load this program high!!!',10,13,"$"
os2text      db        'This program has no effect in the (in)compatibilitybox of OS/2.',10,13,"$"
texthma      db        'FDREAD installed in the HMA.',10,13,"$"
texthmasmall db        'Not enough space in the HMA.',10,13,"$"
textumb      db        'INT 13 entry loaded in a UMB.',10,13,"$"
textdos5     db        'INT 13 entry loaded in a DOS-Block.',10,13,"$"
textumb2     db        'FDREAD completely loaded in a UMB.',10,13,"$"
textconv     db        'FDREAD loaded in a DOS-block.',10,13,"$"
textdosbad   db        'DOS 3.20 or higher required.',10,13,"$"
textfzk      db        'Too MUCH memory available.',10,13,"$"

iseg         ends

sseg         segment   use16 word stack 'stack'

             dw        1024 dup(?)              ;2 kB Stack sollte genÅgen

sseg         ends
             end       begin2

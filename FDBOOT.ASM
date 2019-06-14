             page      66,128
cseg         segment   para public 'CODE'
             assume    cs:cseg

             org       100h                     ;Allow Boot-Sector as COM-File
begin:       jmp       short start              ;Jump
             nop
bpb          db        3FH DUP (0)              ;Reserve enough space for BPB

start        proc      far
             cli                                ;Clear Interrupts, while modifying stack
             xor       ax,ax                    ;Zero AX
             mov       ss,ax                    ;Set SS...
             mov       sp,7c00h                 ;..and SP below Code
             mov       ax,7b0h                  ;Set Segment-Registers that Offset is 100H
             push      ax                       ;Push Segment twice
             push      ax
             pop       ds                       ;Get Segment in DS
             pop       es                       ;and also in ES
             mov       si,100h                  ;Set Source to 100H
             mov       di,300h                  ;Set Destination to 300H
             mov       cx,100h                  ;Set Count to 512 Bytes (1 Sector)
             rep       movsw                    ;Move Code
             mov       ax,7d0h                  ;New Segment at 7d0h (+20H)
             push      ax                       ;Push Segment three times
             push      ax
             push      ax
             pop       ds                       ;Get new segment in DS
             pop       es                       ;and also in ES
             mov       ax,offset entry          ;Offset of next instruction
             push      ax                       ;Push to stack
             ret                                ;and pop it to CS:IP
start        endp

entry        proc      far
             sti                                ;Start Interrupts again
             mov       si,offset text1          ;Move SI to text
             call      output                   ;display to screen
             mov       ax,201h                  ;AH=2 (read sector), AL=1 (count)
             mov       cx,1                     ;CH=0 (Track), CL=1 (Sector)
             mov       dx,128                   ;DH=0 (Head), DL=128 (Fixed Disk C)
             xor       bx,bx                    ;Segment of Transfer buffer
             push      bx                       ;Push to Stack
             pop       es                       ;Get Segment in ES
             mov       bx,7c00h                 ;Offset of Transfer buffer
             push      es                       ;Push Segment...
             push      bx                       ;And Offset to stack
             int       13h                      ;Read from Harddisk
             jc        error                    ;Jump if error
             cmp       word ptr es:7dfeh,0aa55h ;Valid Boot Secotor?
             jnz       error                    ;No, error
             ret                                ;Continue with Boot-Sector of C:

error:       mov       si,offset text2          ;Move SI to text
             call      output                   ;display to screen
loop1:       mov       ah,1                     ;Get Status of...
             int       16h                      ;...Keyboard buffer
             jz        boot_new                 ;if keypressed, reboot
             xor       ah,ah                    ;flush....
             int       16h                      ;...Keyboard Buffer
             jmp       loop1                    ;And try again
boot_new:    xor       ah,ah                    ;flush...
             int       16h                      ;...Keyboard buffer
             xor       dx,dx                    ;Zero DX
             int       19h                      ;Reboot
entry        endp

output       proc      near
             cld
loop_o:      lodsb                              ;Get one character
             or        al,al                    ;Is it zero?
             jnz       weiter                   ;No, continue
             ret                                ;else return
weiter:      push      si                       ;Save SI
             mov       ah,0eh                   ;Output character...
             int       10h                      ;...in AL to screen
             pop       si                       ;restore SI
             jmp       short loop_o             ;repeat loop
output       endp

             IF        LANGUAGE EQ 1
text1        db        'FDBOOT Version 1.8',10,13
             db        'No Systemdisk. Booting from harddisk.',10,13,0
text2        db        'Cannot load from harddisk.',10,13
             db        'Insert Systemdisk and press any key.',10,13,0
             ENDIF

             IF        LANGUAGE EQ 49
text1        db        'FDBOOT Version 1.8',10,13
             db        'Keine Systemdiskette. Starten von Festplatte.',10,13,0
text2        db        'Kann nicht von der Festplatte starten.',10,13
             db        'System-Diskette in Laufwerk A: einlegen',10,13
             db        'Anschlie·end eine Taste drÅcken',10,13,0
             ENDIF

             org       2feh
             db        55h,0aah

cseg         ends
             end       begin

MachineCheck proc   near                        ;Teste CPU-Typ (offizielle INTEL Methode...
                                                ;...aber schwachsinnig)
             xor       ax,ax                    ;Pushe 0...
             push      ax                       ;auf den Stack
             popf                               ;Ziehe Flags runter
             pushf                              ;Pushe sie wieder drauf
             pop       ax                       ;und wieder in AX
             and       ax,0F000h                ;Nimm nur die Bits 11-8
             cmp       ax,0F000h                ;Wenn alle gesetzt....
             je        short MC_8086            ;...dann ist es ein 8086

             mov       ax,0F000h                ;Pushe f00...
             push      ax                       ;...auf den Stack
             popf                               ;Ziehe die Flags runter
             pushf                              ;und wieder auf den Stack
             pop       ax                       ;Als AX vom Stack
             and       ax,0F000h                ;Nimm nur Bits 11-8
             jz        short MC_80286           ;Wenn Null, dann 80286

             mov       ax,3                     ;Setze AX=3 fÅr 80386/80386SX/80486
             ret                                ;Ende

mc_80286:    mov       ax,2                     ;Setze AX=2 fÅr 80286
             ret                                ;Ende

mc_8086:     mov       ax,1                     ;Setze AX=1 fÅr 8086/8088
             ret                                ;Ende
MachineCheck endp

;Man kann von den Jungs bei Intel zwar nicht verlangen, da· die gleich eine Routine
;verîffentlichen, die auch V20/V30/... erkennen, aber den 80188/80186 hÑtten die ja
;mal einbauen kînnen, da die Dinger alle Nicht-Priviligierten 286er Befehle kînnen.

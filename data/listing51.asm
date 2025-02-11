; ========================================================================
; LISTING 51
; ========================================================================

bits 16

mov word [1000], 1
mov word [1002], 2
mov word [1004], 3
mov word [1006], 4

mov bx, 1000
mov word [bx + 4], 10

mov bx, word [1000]
mov cx, word [1002]
mov dx, word [1004]
mov bp, word [1006]

; --- test\listing_0051_memory_mov execution ---
; mov word [+1000], 1 ; ip:0x0->0x6 
; mov word [+1002], 2 ; ip:0x6->0xc 
; mov word [+1004], 3 ; ip:0xc->0x12 
; mov word [+1006], 4 ; ip:0x12->0x18 
; mov bx, 1000 ; bx:0x0->0x3e8 ip:0x18->0x1b 
; mov word [bx+4], 10 ; ip:0x1b->0x20 
; mov bx, [+1000] ; bx:0x3e8->0x1 ip:0x20->0x24 
; mov cx, [+1002] ; cx:0x0->0x2 ip:0x24->0x28 
; mov dx, [+1004] ; dx:0x0->0xa ip:0x28->0x2c 
; mov bp, [+1006] ; bp:0x0->0x4 ip:0x2c->0x30 

; Final registers:
;       bx: 0x0001 (1)
;       cx: 0x0002 (2)
;       dx: 0x000a (10)
;       bp: 0x0004 (4)
;       ip: 0x0030 (48)
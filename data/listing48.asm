; ========================================================================
; LISTING 48
; ========================================================================

bits 16

mov cx, 200
mov bx, cx
add cx, 1000
mov bx, 2000
sub cx, bx

; --- test\listing_0048_ip_register execution ---
; mov cx, 200 ; cx:0x0->0xc8 ip:0x0->0x3 
; mov bx, cx ; bx:0x0->0xc8 ip:0x3->0x5 
; add cx, 1000 ; cx:0xc8->0x4b0 ip:0x5->0x9 flags:->A 
; mov bx, 2000 ; bx:0xc8->0x7d0 ip:0x9->0xc 
; sub cx, bx ; cx:0x4b0->0xfce0 ip:0xc->0xe flags:A->CS 

; Final registers:
;       bx: 0x07d0 (2000)
;       cx: 0xfce0 (64736)
;       ip: 0x000e (14)
;    flags: CS
; ========================================================================
; LISTING 49
; ========================================================================

bits 16

mov cx, 3
mov bx, 1000
loop_start:
add bx, 10
sub cx, 1
jnz loop_start

; --- test\listing_0049_conditional_jumps execution ---
; mov cx, 3 ; cx:0x0->0x3 ip:0x0->0x3 
; mov bx, 1000 ; bx:0x0->0x3e8 ip:0x3->0x6 
; add bx, 10 ; bx:0x3e8->0x3f2 ip:0x6->0x9 flags:->A 
; sub cx, 1 ; cx:0x3->0x2 ip:0x9->0xc flags:A-> 
; jne $-6 ; ip:0xc->0x6 
; add bx, 10 ; bx:0x3f2->0x3fc ip:0x6->0x9 flags:->P 
; sub cx, 1 ; cx:0x2->0x1 ip:0x9->0xc flags:P-> 
; jne $-6 ; ip:0xc->0x6 
; add bx, 10 ; bx:0x3fc->0x406 ip:0x6->0x9 flags:->PA 
; sub cx, 1 ; cx:0x1->0x0 ip:0x9->0xc flags:PA->PZ 
; jne $-6 ; ip:0xc->0xe 

; Final registers:
;       bx: 0x0406 (1030)
;       ip: 0x000e (14)
;    flags: PZ
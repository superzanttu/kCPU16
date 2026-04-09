; Example 2: Screen output with colors
; Demonstrates VRAM write with color attributes

.origin 0x0100

; Write 'H' with red foreground and white background to screen
; VRAM word format: [BG:1][FG:3][ATTR:4][ASCII:8]
; Red=1, White=1, no attributes
; 0x9148 = 1001 0001 0100 1000
;           BG=1 FG=1 ATTR=0000 ASCII=H(72=0x48)

START:
    LOAD R0, 0xF800       ; VRAM start address
    LOAD R1, 0x9148       ; 'H' with red/white colors
    STORE [R1], R0  ; Write R1 to address in R0

    ; Write 'i' at next position
    LOAD R0, 0xF801
    LOAD R1, 0x9169       ; 'i' (0x69) with red/white
    STORE [R1], R0

    HALT

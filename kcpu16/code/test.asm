; testi

.origin 0x100

        LOAD      r0, vram_start
        LOAD      r1, vram_end
        nop

SILMU:
        STORE [R0], 77
        ADD R0, 1
        CMP R0, R1      
        JZ SILMU
        exit

.db 0x0101, 0x0000

        NOP

.dstr "tämä on testi"
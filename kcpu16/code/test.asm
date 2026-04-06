; testi

.origin 0x100

        LOAD      r0, vram_start
        LOAD      r1, vram_end

SILMU:

        STORE [R0], 77
        EXIT

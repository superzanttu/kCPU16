; testi

.origin 0x100

        JARI      r0, vram_start
        JARI      r1, vram_end

SILMU:

        STORE [R0], 77
        EXIT

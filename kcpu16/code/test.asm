; testi

.orgin 0x100

        LOAD      r0, vram_start
        LOAD      r1, vram_end

SILMU:
store_ind 1,r0
; include_lib_b.asm — kirjasto B (.include-testeja varten)

.const LIB_B, 3

ADD_THREE:
    LOAD R1, 3
    ADD  R0, R1
    RET

; include_lib_a.asm — kirjasto A (.include-testeja varten)

.const LIB_A, 5

ADD_FIVE:
    READ R1, 5
    ADD  R0, R1
    RET

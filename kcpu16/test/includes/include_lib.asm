; include_lib.asm — Kirjasto jota kaytettaan .include-testeissa.
; Maarittaa vakion ja alirutiinin.

.const LIB_CONST, 99

ADD_TEN:
    ; R0 = R0 + 10, palaa kutsujalle
    READ R1, 10
    ADD  R0, R1
    RET

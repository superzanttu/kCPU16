; fibonacci.asm
; Laske Fibonacci-luku F(9) = 34 iteratiivisesti.
;
; Algoritmi:
;   R0 = F(n-2),  R1 = F(n-1)  (aloitus: F(0)=0, F(1)=1)
;   R2 = kierroslaskuri
;   R3 = vakio 1
;
; Tulostaa naytolle: 0 1 1 2 3 5 8 13 21 34
; Tulos: R1 = 34 = F(9)

        LOAD  R0, 0       ; a = F(0)
        LOAD  R1, 1       ; b = F(1)
        LOAD  R2, 8       ; 8 seuraavaa -> F(2)..F(9)
        LOAD  R3, 1       ; vakio +1/-1
        LOAD  FP, 0xF820  ; nayttopointteri

        ; Tulosta alku: "0 1 "
        LOAD  SP, 0xE030  ; '0'
        STORE_IND FP, SP
        ADD   FP, R3
        LOAD  SP, 0xE020  ; ' '
        STORE_IND FP, SP
        ADD   FP, R3
        LOAD  SP, 0xE031  ; '1'
        STORE_IND FP, SP
        ADD   FP, R3
        LOAD  SP, 0xE020  ; ' '
        STORE_IND FP, SP
        ADD   FP, R3

fib_loop:
        ; b = a + b, a = vanha b
        STORE R1, 0x0210
        ADD   R1, R0
        READ  R0, 0x0210

        ; Tulosta b
        LOAD  SP, 13
        CMP   R1, SP
        JZ    print_13

        LOAD  SP, 21
        CMP   R1, SP
        JZ    print_21

        LOAD  SP, 34
        CMP   R1, SP
        JZ    print_34

        ; Yksinumeroinen (1,2,3,5,8)
        STORE R0, 0x0211
        CPY   SP, R1
        LOAD  R0, 0xE030
        ADD   SP, R0
        READ  R0, 0x0211
        STORE_IND FP, SP
        ADD   FP, R3
        JUMP  print_space

print_13:
        LOAD  SP, 0xE031
        STORE_IND FP, SP
        ADD   FP, R3
        LOAD  SP, 0xE033
        STORE_IND FP, SP
        ADD   FP, R3
        JUMP  print_space

print_21:
        LOAD  SP, 0xE032
        STORE_IND FP, SP
        ADD   FP, R3
        LOAD  SP, 0xE031
        STORE_IND FP, SP
        ADD   FP, R3
        JUMP  print_space

print_34:
        LOAD  SP, 0xE033
        STORE_IND FP, SP
        ADD   FP, R3
        LOAD  SP, 0xE034
        STORE_IND FP, SP
        ADD   FP, R3

print_space:
        LOAD  SP, 0xE020
        STORE_IND FP, SP
        ADD   FP, R3

        SUB   R2, R3
        JNZ   fib_loop

        HALT

; =============================================================================
; state.asm - STATE-kaskyn ja .state_text-viiveiden esittely
; =============================================================================
;
; Tämä demo määrittelee kaikki 16 tilatekstiä (0..15) ja laukaisee ne järjestyksessä.
; Jokaisessa .state_text-rivissä on 2 sekunnin viive.
;
; Aja ohjelma TUI:ssa: Output-paneeliin tulostuu STATE-viestit viiveineen.
; =============================================================================

        .origin 0x0200

        .state_text 0, 2, "State 0: Boot"
        .state_text 1, 2, "State 1: Init memory"
        .state_text 2, 2, "State 2: Init devices"
        .state_text 3, 2, "State 3: Load assets"
        .state_text 4, 2, "State 4: Build tables"
        .state_text 5, 2, "State 5: Setup interrupts"
        .state_text 6, 2, "State 6: Preflight checks"
        .state_text 7, 2, "State 7: Enter main loop"
        .state_text 8, 2, "State 8: Frame begin"
        .state_text 9, 2, "State 9: Update logic"
        .state_text 10, 2, "State 10: Draw"
        .state_text 11, 2, "State 11: Flip"
        .state_text 12, 2, "State 12: IO poll"
        .state_text 13, 2, "State 13: Save sync"
        .state_text 14, 2, "State 14: Idle"
        .state_text 15, 2, "State 15: Shutdown"

main:
        STATE 0
        STATE 1
        STATE 2
        STATE 3
        STATE 4
        STATE 5
        STATE 6
        STATE 7
        STATE 8
        STATE 9
        STATE 10
        STATE 11
        STATE 12
        STATE 13
        STATE 14
        STATE 15
        JUMP  main

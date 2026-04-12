; =============================================================================
; demo_diskboot.asm — Bootblock directive demonstration
; =============================================================================
;
; DESCRIPTION:
;   Demonstrates the usage of the .bootblock directive, which allows
;   assembling a boot sector (256 words starting at 0x0100) into a disk
;   image while keeping normal program code separate in RAM.
;
;   This demo shows:
;   1. A bootblock that initializes boot-area constants and waits
;   2. A main program loaded at 0x0200 that checks boot-area values
;   3. Optional automatic boot after disk image creation
;
; BOOT AREA (0x0100-0x01FF, 256 words):
;   This is where the bootblock code is assembled. It must fit
;   entirely within these 256 words. The bootblock is written to
;   block 0 of the disk image, and on cold boot, the CPU copies
;   this block from storage to the boot area in RAM.
;
; NORMAL PROGRAM AREA (0x0200+):
;   Regular program code that runs after boot. Can be in the same
;   .asm file as the bootblock but will be assembled separately.
;
; BOOTBLOCK DIRECTIVE SYNTAX:
;   .bootblock "path/to/disk.dsk", overwrite=1, boot=0
;       ; bootblock code here
;   .endbootblock
;
; OPTIONS:
;   - overwrite: 0/1 - Whether to overwrite existing bootblock in disk image
;   - boot: 0/1 - Whether to automatically boot from this disk image after writing
;
; DISK IMAGE PATH:
;   Relative to the .asm source file location. In this example,
;   we save to "../storage/boot.dsk" which is one level up
;   from the code/ directory.
;
; =============================================================================

; =============================================================================
; BOOTBLOCK SECTION (0x0100-0x01FF)
; =============================================================================
;
; This bootblock is written to disk image block 0 and, with boot=1,
; the emulator cold-boots from that disk like a real machine.
; The boot code initializes the boot area and then jumps to the
; normal RAM program at 0x0200.
;

.bootblock "../storage/demo_boot.dsk", overwrite=1, boot=1

; Boot-area constants and boot-loader logic.
; These values will be initialized when the CPU boots from disk.

boot_entry:
    ; Initialize boot-area marker: write a signature value
    READ  R0, 0xBEEF       ; Magic number for "boot executed"
    STORE [0x0100], R0     ; Store at boot area start

    ; Initialize boot constants
    READ  R1, 42           ; The answer to everything
    STORE [0x0101], R1     ; Store boot constant #1

    READ  R2, 256          ; Boot block size in words
    STORE [0x0102], R2     ; Store boot constant #2


    ; Continue to the normal program loaded into RAM.
    JUMP  0x0200

.endbootblock

; =============================================================================
; MAIN PROGRAM SECTION (0x0200+)
; =============================================================================
;
; This section demonstrates that normal code can coexist in the same file
; as bootblock code. We'll verify the bootblock was properly initialized.
;

.origin 0x0200

    JUMP  main_start

; =============================================================================
; INCLUDE SCREEN LIBRARY
; =============================================================================
;
; The entry jump above ensures execution starts from main_start rather than
; from the library's global data that gets assembled before its functions.
;

.include "lib-screen.asm"

main_start:
    ; This is the standard program area (always present)
    ; Clear screen for fresh output
    CALL  scr_cls

    ; Set color: bright yellow on black
    READ  R0, 0x0E00
    CALL  scr_set_color

    ; Print main program title
    READ  R0, MSG_TITLE
    CALL  scr_print

    ; Set color: white on black for checks
    READ  R0, 0x0700
    CALL  scr_set_color

    ; Print status line 1
    READ  R0, MSG_START
    CALL  scr_print

    ; Print status line 2: Checking boot signature
    READ  R0, MSG_CHECK1
    CALL  scr_print

    ; Check boot-area signature
    READ  R3, [0x0100]     ; Load boot signature
    READ  R4, 0xBEEF       ; Expected signature
    CMP   R3, R4
    JNZ   boot_check_fail  ; If signature mismatch, fail

    ; Print status line 3: Checking boot constant #1
    READ  R0, MSG_CHECK2
    CALL  scr_print

    READ  R5, [0x0101]     ; Load boot constant #1
    READ  R6, 42           ; Expected value
    CMP   R5, R6
    JNZ   boot_check_fail  ; If value mismatch, fail

    ; Print status line 4: Checking boot constant #2
    READ  R0, MSG_CHECK3
    CALL  scr_print

    READ  R7, [0x0102]     ; Load boot constant #2
    READ  R8, 256          ; Expected value
    CMP   R7, R8
    JNZ   boot_check_fail  ; If value mismatch, fail

    ; All checks passed - print success
    READ  R0, 0x0200       ; Color: green on black
    CALL  scr_set_color
    READ  R0, MSG_PASS
    CALL  scr_print
    HALT

boot_check_fail:
    ; Boot check failed
    READ  R0, 0x0400       ; Color: red on black
    CALL  scr_set_color
    READ  R0, MSG_FAIL
    CALL  scr_print
    HALT

; =============================================================================
; STRING DATA
; =============================================================================

MSG_TITLE:
    .dstr "\n=== BOOTBLOCK DIRECTIVE DEMO ===\n"

MSG_START:
    .dstr "Booted from disk block 0, now running main program (0x0200+)\n"
    .dstr "Verifying boot-area values...\n"

MSG_CHECK1:
    .dstr "  [1] Boot signature (0xBEEF)... "

MSG_CHECK2:
    .dstr "OK\n  [2] Boot constant #1 (42)... "

MSG_CHECK3:
    .dstr "OK\n  [3] Boot constant #2 (256)... "

MSG_PASS:
    .dstr "OK\n\n✓ SUCCESS: Bootblock feature working!\n"

MSG_FAIL:
    .dstr "FAILED\n\n✗ ERROR: Boot-area verification failed!\n"

; =============================================================================
; END OF DEMO
; =============================================================================

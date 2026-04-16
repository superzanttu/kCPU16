.origin 0x0200

        JUMP  main

        .include "../lib/lib-screen.asm"
        .include "../lib/lib-disk.asm"

.const CH_SLASH, 47
.const CH_BSLASH, 92
.const MORE_BUF_WORDS, 512
.const MORE_PAGE_LINES, 20
.const LOREM_RAM_BASE, 0x8000

; -----------------------------------------------------------------------------
; Data
; -----------------------------------------------------------------------------

fdisk_done:
        .dw  0
format_done:
        .dw  0

input_buf:
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

cmd_buf:
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
arg_buf:
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
arg2_buf:
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
scoped_name_buf:
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
cwd_buf:
        ; "/" = root directory
        .dw  47,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

line_buf:
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

list_buf:
        .dw  0,0,0,0,0,0,0,0

io_stat_buf:
        .dw  0,0,0,0,0,0,0,0,0,0
ls_space_buf:
        .dw  0,0,0,0
copy_src_buf:
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
copy_dst_buf:
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
copy_dst_base_buf:
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
io_read_buf:
        .dw  0,0,0,0,0,0,0,0
io_demo_buf:
        .dw  75,68,79,83,33      ; "KDOS!"
more_buf:
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
more_read_words:
        .dw  0
more_truncated:
        .dw  0
lorem_total_words:
        .dw  0
lorem_written_words:
        .dw  0
lorem_chunk_words:
        .dw  0
lorem_max_words:
        .dw  0

; constants as data words
char_space:
        .dw  32
char_slash:
        .dw  47
char_nl:
        .dw  10
char_zero:
        .dw  0
char_dot:
        .dw  46
prompt_char_buf:
        .dw  0,0

; -----------------------------------------------------------------------------
; Strings
; -----------------------------------------------------------------------------

str_banner:
        .dstr "Microsoft MS-DOS Version 6.22\n(C)Copyright Microsoft Corp 1981-1994.\n\n"
str_prompt_drive:
        .dstr "D:"
str_prompt_tail:
        .dstr "> "
str_empty_prompt:
        .dstr ""
str_ok:
        .dstr "OK\n"
str_unknown:
        .dstr "Bad command or file name\n"
str_need_arg:
        .dstr "Missing argument.\n"
str_need_arg2:
        .dstr "Missing second argument.\n"
str_bad_count:
        .dstr "Word count out of range.\n"
str_need_fdisk:
        .dstr "Storage not partitioned. Run fdisk.\n"
str_need_format:
        .dstr "Storage not formatted. Run format.\n"
str_need_fdisk_first:
        .dstr "Run fdisk before format.\n"
str_fs_bad:
        .dstr "Storage check failed. Re-run fdisk + format.\n"
str_name_long:
        .dstr "Name/path too long (max 15 chars on disk).\n"
str_exists:
        .dstr "Already exists.\n"
str_not_found:
        .dstr "Not found.\n"
str_dir_full:
        .dstr "Directory full.\n"
str_disk_full:
        .dstr "Disk full.\n"
str_range:
        .dstr "Invalid range/corrupt entry.\n"
str_not_dir:
        .dstr "Not a directory.\n"
str_not_file:
        .dstr "Not a file.\n"
str_dir_not_empty:
        .dstr "Directory not empty.\n"
str_format_done:
        .dstr "Format complete.\n"
str_fdisk_done:
        .dstr "Partition table initialized.\n"
str_ls_empty:
        .dstr "(empty)\n"
str_ls_dir_tag:
        .dstr "<DIR> "
str_ls_files_lbl:
        .dstr "files: "
str_ls_dirs_lbl:
        .dstr " dirs: "
str_ls_free_lbl:
        .dstr " free: "
str_ls_used_lbl:
        .dstr " used: "
str_ls_words_nl:
        .dstr " words\n"
str_cancelled:
        .dstr "Cancelled.\n"
str_confirm_fdisk:
        .dstr "fdisk will reinitialize partition metadata. Continue? (y/N): "
str_confirm_format:
        .dstr "format will destroy filesystem metadata. Continue? (y/N): "
str_run_err42:
        .dstr "Error 42: Life not found\n"
str_cd_now:
        .dstr "Current dir: "
str_nl:
        .dstr "\n"
str_found_file:
        .dstr "File found.\n"
str_stat_ok:
        .dstr "STAT OK\n"
str_read_match:
        .dstr "READ OK (matches demo data)\n"
str_read_diff:
        .dstr "READ OK (content differs from demo data)\n"
str_copy_wildcard:
        .dstr "Wildcard copy supports only '*'.\n"
str_more_prompt:
        .dstr "\n-- More -- (Enter)"
str_more_empty:
        .dstr "(empty file)\n"
str_more_truncated:
        .dstr "[output truncated]\n"

cmd_help:
        .dstr "help"
cmd_fdisk:
        .dstr "fdisk"
cmd_format:
        .dstr "format"
cmd_check:
        .dstr "check"
cmd_sync:
        .dstr "sync"
cmd_ls:
        .dstr "ls"
cmd_dir:
        .dstr "dir"
cmd_find:
        .dstr "find"
cmd_stat:
        .dstr "stat"
cmd_mkdir:
        .dstr "mkdir"
cmd_cd:
        .dstr "cd"
cmd_rmdir:
        .dstr "rmdir"
cmd_touch:
        .dstr "touch"
cmd_rm:
        .dstr "rm"
cmd_del:
        .dstr "del"
cmd_copy:
        .dstr "copy"
cmd_write:
        .dstr "write"
cmd_lorem:
        .dstr "lorem"
cmd_read:
        .dstr "read"
cmd_more:
        .dstr "more"
cmd_run:
        .dstr "run"
cmd_dotdot:
        .dstr ".."
cmd_star:
        .dstr "*"
cmd_format_zero:
        .dstr "/z"

str_help:
        .dstr "Commands:\n  help fdisk format check sync ls dir\n  find stat mkdir cd rmdir touch rm del\n  copy lorem more run\nUse 'help' for quick list.\n"

lorem_seed:
        .dstr "lorem ipsum "

; -----------------------------------------------------------------------------
; Utility: print string
; In: R0=ptr
; -----------------------------------------------------------------------------

print_str:
        CALL  scr_print
        RET

; -----------------------------------------------------------------------------
; Utility: print one ASCII character
; In: R0=ASCII code
; -----------------------------------------------------------------------------

print_char:
        PUSH  R1
        PUSH  R2
        CPY   R2, R0
        READ  R1, prompt_char_buf
        STORE [R1], R2
        READ  R2, 1
        ADD   R1, R2
        READ  R0, 0
        STORE [R1], R0
        READ  R0, prompt_char_buf
        CALL  print_str
        POP   R2
        POP   R1
        RET

; -----------------------------------------------------------------------------
; Utility: print unsigned 16-bit decimal
; In: R0=value
; -----------------------------------------------------------------------------

print_u16_dec:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5
        PUSH  R6
        PUSH  R7

        CPY   R7, R0              ; remaining value
        READ  R6, 0               ; started flag
        READ  R5, 48              ; ASCII '0'

        READ  R1, 10000
        CALL  _pu16_emit_div
        READ  R1, 1000
        CALL  _pu16_emit_div
        READ  R1, 100
        CALL  _pu16_emit_div
        READ  R1, 10
        CALL  _pu16_emit_div

        ; ones place
        CPY   R2, R7
        ADD   R2, R5
        CPY   R0, R2
        CALL  print_char

        POP   R7
        POP   R6
        POP   R5
        POP   R4
        POP   R3
        POP   R2
        POP   R1
        RET

_pu16_emit_div:
        CPY   R2, R7
        DIV   R2, R1              ; digit
        CPY   R3, R2
        MUL   R3, R1              ; digit * divisor
        SUB   R7, R3              ; update remaining

        READ  R4, 0
        CMP   R6, R4
        JNZ   _pu16_emit_print
        CMP   R2, R4
        JZ    _pu16_emit_ret
        READ  R6, 1

_pu16_emit_print:
        ADD   R2, R5
        CPY   R0, R2
        CALL  print_char

_pu16_emit_ret:
        RET

; -----------------------------------------------------------------------------
; Utility: print two digits with leading zero
; In: R0=value 0..99
; -----------------------------------------------------------------------------

print_u16_2:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4

        READ  R1, 10
        CPY   R2, R0
        DIV   R2, R1              ; tens
        CPY   R3, R2
        MUL   R3, R1
        SUB   R0, R3              ; ones
        CPY   R3, R0              ; save ones

        READ  R4, 48
        ADD   R2, R4
        ADD   R3, R4

        CPY   R0, R2
        CALL  print_char
        CPY   R0, R3
        CALL  print_char

        POP   R4
        POP   R3
        POP   R2
        POP   R1
        RET

; -----------------------------------------------------------------------------
; Utility: print N spaces
; In: R0=count
; -----------------------------------------------------------------------------

print_spaces:
        PUSH  R1
        PUSH  R2
        PUSH  R3

        CPY   R2, R0
        READ  R1, 1
        READ  R3, 0

_ps_loop:
        CMP   R2, R3
        JZ    _ps_done
        READ  R0, 32
        CALL  print_char
        SUB   R2, R1
        JUMP  _ps_loop

_ps_done:
        POP   R3
        POP   R2
        POP   R1
        RET

; -----------------------------------------------------------------------------
; Utility: print single hex nibble
; In: R0=0..15
; -----------------------------------------------------------------------------

print_hex_nibble:
        PUSH  R1
        PUSH  R2
        CPY   R1, R0
        READ  R2, 10
        CMP   R1, R2
        JLT   _phn_digit
        READ  R2, 55              ; 'A' - 10
        ADD   R1, R2
        JUMP  _phn_emit
_phn_digit:
        READ  R2, 48              ; '0'
        ADD   R1, R2
_phn_emit:
        CPY   R0, R1
        CALL  print_char
        POP   R2
        POP   R1
        RET

; -----------------------------------------------------------------------------
; Utility: print 16-bit value as 4 hex digits
; In: R0=word
; -----------------------------------------------------------------------------

print_u16_hex:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4

        CPY   R1, R0
        READ  R2, 12
        SHR   R1, R2
        READ  R3, 0x000F
        AND   R1, R3
        CPY   R0, R1
        CALL  print_hex_nibble

        CPY   R1, R0
        READ  R2, 8
        SHR   R1, R2
        READ  R3, 0x000F
        AND   R1, R3
        CPY   R0, R1
        CALL  print_hex_nibble

        CPY   R1, R0
        READ  R2, 4
        SHR   R1, R2
        READ  R3, 0x000F
        AND   R1, R3
        CPY   R0, R1
        CALL  print_hex_nibble

        CPY   R1, R0
        READ  R3, 0x000F
        AND   R1, R3
        CPY   R0, R1
        CALL  print_hex_nibble

        POP   R4
        POP   R3
        POP   R2
        POP   R1
        RET

; -----------------------------------------------------------------------------
; print_prompt_dos
; Tulostaa DOS-tyylisen kehotteen: D:\path>
; Sisäinen cwd_buf käyttää '/'-erottimia; tässä ne muunnetaan '\\':ksi.
; Root-hakemistossa tulos on D:\>
; -----------------------------------------------------------------------------

print_prompt_dos:
        PUSH  R0
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5

        READ  R1, 1
        READ  R5, 0

        ; "D:"
        READ  R0, str_prompt_drive
        CALL  print_str

        ; "\\"
        READ  R0, prompt_char_buf
        READ  R2, CH_BSLASH
        STORE [R0], R2
        ADD   R0, R1
        STORE [R0], R5
        READ  R0, prompt_char_buf
        CALL  print_str

        ; cwd without leading '/': print chars and convert '/' -> '\\'
        READ  R4, cwd_buf
        ADD   R4, R1
_ppd_loop:
        READ  R2, [R4]
        CMP   R2, R5
        JZ    _ppd_tail
        READ  R3, CH_SLASH
        CMP   R2, R3
        JNZ   _ppd_emit
        READ  R2, CH_BSLASH
_ppd_emit:
        READ  R3, prompt_char_buf
        STORE [R3], R2
        ADD   R3, R1
        STORE [R3], R5
        READ  R0, prompt_char_buf
        CALL  print_str
        ADD   R4, R1
        JUMP  _ppd_loop

_ppd_tail:
        READ  R0, str_prompt_tail
        CALL  print_str

        POP   R5
        POP   R4
        POP   R3
        POP   R2
        POP   R1
        POP   R0
        RET

; -----------------------------------------------------------------------------
; Utility: string equals
; In: R0=a, R1=b
; Out: R0=1 equal, 0 not equal
; -----------------------------------------------------------------------------

str_eq2_a:
        .dw 0
str_eq2_b:
        .dw 0
str_eq2:
        PUSH  R2
        PUSH  R3
        PUSH  R4
        STORE [str_eq2_a], R0
        STORE [str_eq2_b], R1
        READ  R4, 1
        READ  R3, 0
_seq2_loop:
        READ  R0, [str_eq2_a]
        READ  R1, [str_eq2_b]
        READ  R2, [R0]
        READ  R1, [R1]
        CMP   R2, R1
        JNZ   _seq2_no
        CMP   R2, R3
        JZ    _seq2_yes
        READ  R0, [str_eq2_a]
        ADD   R0, R4
        STORE [str_eq2_a], R0
        READ  R0, [str_eq2_b]
        ADD   R0, R4
        STORE [str_eq2_b], R0
        JUMP  _seq2_loop
_seq2_yes:
        READ  R0, 1
        POP   R4
        POP   R3
        POP   R2
        RET

; -----------------------------------------------------------------------------
; Utility: compare word buffers
; In: R0=a ptr, R1=b ptr, R2=count
; Out: R0=1 equal, 0 not equal
; -----------------------------------------------------------------------------

cmp_words:
        PUSH  R3
        PUSH  R4
        PUSH  R5
        READ  R5, 1
        READ  R4, 0
_cw_loop:
        CMP   R2, R4
        JZ    _cw_yes
        READ  R3, [R0]
        READ  R4, [R1]
        CMP   R3, R4
        JNZ   _cw_no
        ADD   R0, R5
        ADD   R1, R5
        SUB   R2, R5
        READ  R4, 0
        JUMP  _cw_loop
_cw_yes:
        READ  R0, 1
        POP   R5
        POP   R4
        POP   R3
        RET
_cw_no:
        READ  R0, 0
        POP   R5
        POP   R4
        POP   R3
        RET

; -----------------------------------------------------------------------------
; Utility: paged hex output for "more"
; In: R0=buffer ptr, R1=word count
; -----------------------------------------------------------------------------

more_print_paged:
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5
        PUSH  R6
        PUSH  R7
        CPY   R6, R0
        CPY   R7, R1
        READ  R5, 0                 ; lines in current page
        READ  R4, MORE_PAGE_LINES
        READ  R3, 1                 ; one word step
        READ  R2, 0                 ; zero
        READ  R1, 0                 ; words in current line
_mpp_loop:
        CMP   R7, R2
        JZ    _mpp_done
        READ  R0, [R6]
        CALL  print_u16_hex

        READ  R0, 32                ; ' '
        CALL  print_char

        ADD   R1, R3                ; words in line++
        READ  R0, 8
        CMP   R1, R0
        JLT   _mpp_next_word

        READ  R0, str_nl
        CALL  print_str
        READ  R1, 0
        ADD   R5, R3                ; page lines++
        CMP   R5, R4
        JLT   _mpp_next_word

        READ  R0, str_more_prompt
        CALL  print_str
        READ  R0, str_empty_prompt
        READ  R1, input_buf
        READ  R2, 2
        CALL  scr_input
        READ  R5, 0

_mpp_next_word:
        ADD   R6, R3
        SUB   R7, R3
        JUMP  _mpp_loop
_mpp_done:
        READ  R0, 0
        CMP   R1, R0
        JZ    _mpp_ret
        READ  R0, str_nl
        CALL  print_str

_mpp_ret:
        POP   R7
        POP   R6
        POP   R5
        POP   R4
        POP   R3
        POP   R2
        RET
_seq2_no:
        READ  R0, 0
        POP   R4
        POP   R3
        POP   R2
        RET

; -----------------------------------------------------------------------------
; parse_u16_dec
; In: R0=ptr to decimal ascii
; Out: R0=value, R1=1 ok / 0 fail
; -----------------------------------------------------------------------------

parse_u16_dec:
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5
        PUSH  R6
        CPY   R2, R0
        READ  R3, 0              ; value
        READ  R4, 1
        READ  R5, 48             ; '0'
        READ  R6, 57             ; '9'

        READ  R0, [R2]
        READ  R1, 0
        CMP   R0, R1
        JZ    _pud_fail

_pud_loop:
        READ  R0, [R2]
        READ  R1, 0
        CMP   R0, R1
        JZ    _pud_ok
        CMP   R0, R5
        JLT   _pud_fail
        CMP   R0, R6
        JGT   _pud_fail
        SUB   R0, R5             ; digit
        READ  R1, 10
        MUL   R3, R1
        ADD   R3, R0
        ADD   R2, R4
        JUMP  _pud_loop

_pud_ok:
        CPY   R0, R3
        READ  R1, 1
        JUMP  _pud_ret

_pud_fail:
        READ  R0, 0
        READ  R1, 0

_pud_ret:
        POP   R6
        POP   R5
        POP   R4
        POP   R3
        POP   R2
        RET

; -----------------------------------------------------------------------------
; arg_has_wildcard
; In: R0=string ptr
; Out: R0=1 if contains '*', else 0
; -----------------------------------------------------------------------------

arg_has_wildcard:
        PUSH  R1
        PUSH  R2
        READ  R2, 1
_ahw_loop:
        READ  R1, [R0]
        READ  R2, 0
        CMP   R1, R2
        JZ    _ahw_no
        READ  R2, 42              ; '*'
        CMP   R1, R2
        JZ    _ahw_yes
        READ  R2, 1
        ADD   R0, R2
        JUMP  _ahw_loop
_ahw_yes:
        READ  R0, 1
        POP   R2
        POP   R1
        RET
_ahw_no:
        READ  R0, 0
        POP   R2
        POP   R1
        RET

; -----------------------------------------------------------------------------
; build_copy_target_name
; Build copy_dst_buf = copy_dst_base_buf + '/' + line_buf
; Out: R0=1 ok, 0 fail (too long)
; -----------------------------------------------------------------------------

build_copy_target_name:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5

        ; dst <- base
        READ  R0, copy_dst_base_buf
        READ  R1, copy_dst_buf
        READ  R2, 16
        CALL  _disk_str_copy

        ; find end(dst)
        READ  R1, copy_dst_buf
        READ  R2, 1
        READ  R3, 0
        READ  R4, 16
_bct_seek:
        CMP   R4, R3
        JZ    _bct_fail
        READ  R5, [R1]
        CMP   R5, R3
        JZ    _bct_at_end
        ADD   R1, R2
        SUB   R4, R2
        JUMP  _bct_seek

_bct_at_end:
        ; append '/'
        READ  R5, 1
        CMP   R4, R5
        JLE   _bct_fail
        READ  R5, CH_SLASH
        STORE [R1], R5
        ADD   R1, R2
        SUB   R4, R2

        ; append line_buf
        READ  R0, line_buf
_bct_copy_loop:
        READ  R5, [R0]
        READ  R3, 0
        CMP   R5, R3
        JZ    _bct_done
        READ  R3, CH_SLASH
        CMP   R5, R3
        JZ    _bct_done
        READ  R3, 1
        CMP   R4, R3
        JLE   _bct_fail
        STORE [R1], R5
        ADD   R1, R2
        ADD   R0, R2
        SUB   R4, R2
        JUMP  _bct_copy_loop

_bct_done:
        READ  R5, 0
        STORE [R1], R5
        READ  R0, 1
        JUMP  _bct_ret

_bct_fail:
        READ  R0, 0

_bct_ret:
        POP   R5
        POP   R4
        POP   R3
        POP   R2
        POP   R1
        RET

; -----------------------------------------------------------------------------
; confirm_action
; In: R0=prompt ptr
; Out: R0=1 if user answered y/Y, else 0
; -----------------------------------------------------------------------------

confirm_action:
        PUSH  R1
        PUSH  R2

        CALL  print_str
        READ  R0, str_empty_prompt
        READ  R1, input_buf
        READ  R2, 4
        CALL  scr_input

        READ  R0, [input_buf]
        READ  R1, 121             ; 'y'
        CMP   R0, R1
        JZ    _ca_yes
        READ  R1, 89              ; 'Y'
        CMP   R0, R1
        JZ    _ca_yes
        READ  R0, 0
        JUMP  _ca_ret

_ca_yes:
        READ  R0, 1

_ca_ret:
        POP   R2
        POP   R1
        RET

; -----------------------------------------------------------------------------
; fill_lorem_words
; In: R0=dst ptr, R1=word count
; -----------------------------------------------------------------------------

fill_lorem_words:
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5
        PUSH  R6
        CPY   R4, R0
        CPY   R3, R1
        READ  R5, lorem_seed
        READ  R2, 1
        READ  R6, 0

_flw_loop:
        CMP   R3, R6
        JZ    _flw_done
        READ  R1, [R5]
        CMP   R1, R6
        JNZ   _flw_emit
        READ  R5, lorem_seed
        READ  R1, [R5]
_flw_emit:
        STORE [R4], R1
        ADD   R4, R2
        ADD   R5, R2
        SUB   R3, R2
        JUMP  _flw_loop

_flw_done:
        POP   R6
        POP   R5
        POP   R4
        POP   R3
        POP   R2
        RET

; -----------------------------------------------------------------------------
; parse_input
; In: R0=input pointer
; Out: R0=1 if command exists else 0
; Fills cmd_buf, arg_buf and arg2_buf
; -----------------------------------------------------------------------------

parse_input:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5

        CPY   R1, R0
        READ  R2, cmd_buf
        READ  R3, arg_buf
        READ  R0, arg2_buf
        READ  R4, 0
        STORE [R2], R4
        STORE [R3], R4
        STORE [R0], R4

        READ  R5, 1
_pi_skip_lead:
        READ  R0, [R1]
        READ  R4, 32
        CMP   R0, R4
        JNZ   _pi_cmd_copy
        ADD   R1, R5
        JUMP  _pi_skip_lead

_pi_cmd_copy:
        READ  R2, cmd_buf
        READ  R4, 15
_pi_cmd_loop:
        READ  R0, [R1]
        READ  R3, 0
        CMP   R0, R3
        JZ    _pi_cmd_done
        READ  R3, 32
        CMP   R0, R3
        JZ    _pi_cmd_done
        READ  R3, 0
        CMP   R4, R3
        JZ    _pi_cmd_done
        STORE [R2], R0
        ADD   R2, R5
        ADD   R1, R5
        SUB   R4, R5
        JUMP  _pi_cmd_loop
_pi_cmd_done:
        READ  R3, 0
        STORE [R2], R3

_pi_skip_gap:
        READ  R0, [R1]
        READ  R3, 32
        CMP   R0, R3
        JNZ   _pi_arg_copy
        ADD   R1, R5
        JUMP  _pi_skip_gap

_pi_arg_copy:
        READ  R2, arg_buf
        READ  R4, 15
_pi_arg_loop:
        READ  R0, [R1]
        READ  R3, 0
        CMP   R0, R3
        JZ    _pi_arg_done
        READ  R3, 32
        CMP   R0, R3
        JZ    _pi_arg_done
        READ  R3, 0
        CMP   R4, R3
        JZ    _pi_arg_done
        STORE [R2], R0
        ADD   R2, R5
        ADD   R1, R5
        SUB   R4, R5
        JUMP  _pi_arg_loop
_pi_arg_done:
        READ  R3, 0
        STORE [R2], R3

_pi_skip_gap2:
        READ  R0, [R1]
        READ  R3, 32
        CMP   R0, R3
        JNZ   _pi_arg2_copy
        ADD   R1, R5
        JUMP  _pi_skip_gap2

_pi_arg2_copy:
        READ  R2, arg2_buf
        READ  R4, 15
_pi_arg2_loop:
        READ  R0, [R1]
        READ  R3, 0
        CMP   R0, R3
        JZ    _pi_arg2_done
        READ  R3, 32
        CMP   R0, R3
        JZ    _pi_arg2_done
        READ  R3, 0
        CMP   R4, R3
        JZ    _pi_arg2_done
        STORE [R2], R0
        ADD   R2, R5
        ADD   R1, R5
        SUB   R4, R5
        JUMP  _pi_arg2_loop
_pi_arg2_done:
        READ  R3, 0
        STORE [R2], R3

        READ  R0, [cmd_buf]
        READ  R3, 0
        CMP   R0, R3
        JZ    _pi_none
        READ  R0, 1
        JUMP  _pi_ret
_pi_none:
        READ  R0, 0
_pi_ret:
        POP   R5
        POP   R4
        POP   R3
        POP   R2
        POP   R1
        RET

; -----------------------------------------------------------------------------
; ensure_storage_ready
; Out: R0=1 ready, 0 not ready (and prints message)
; -----------------------------------------------------------------------------

ensure_storage_ready:
        READ  R1, [fdisk_done]
        READ  R2, 0
        CMP   R1, R2
        JNZ   _esr_chk_fmt
        READ  R0, str_need_fdisk
        CALL  print_str
        READ  R0, 0
        RET
_esr_chk_fmt:
        READ  R1, [format_done]
        READ  R2, 0
        CMP   R1, R2
        JNZ   _esr_chk_fs
        READ  R0, str_need_format
        CALL  print_str
        READ  R0, 0
        RET
_esr_chk_fs:
        CALL  disk_check
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _esr_ok
        READ  R0, str_fs_bad
        CALL  print_str
        READ  R0, 0
        RET
_esr_ok:
        READ  R0, 1
        RET

; -----------------------------------------------------------------------------
; print_disk_error
; In: R0=disk error code
; -----------------------------------------------------------------------------

print_disk_error:
        PUSH  R1
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JNZ   _pde_2
        READ  R0, str_not_found
        CALL  print_str
        POP   R1
        RET
_pde_2:
        READ  R1, DISK_ERR_DIR_FULL
        CMP   R0, R1
        JNZ   _pde_3
        READ  R0, str_dir_full
        CALL  print_str
        POP   R1
        RET
_pde_3:
        READ  R1, DISK_ERR_DISK_FULL
        CMP   R0, R1
        JNZ   _pde_4
        READ  R0, str_disk_full
        CALL  print_str
        POP   R1
        RET
_pde_4:
        READ  R1, DISK_ERR_EXISTS
        CMP   R0, R1
        JNZ   _pde_def
        READ  R0, str_exists
        CALL  print_str
        POP   R1
        RET
_pde_def:
        READ  R0, str_range
        CALL  print_str
        POP   R1
        RET

; -----------------------------------------------------------------------------
; build_scoped_name
; In: R0=arg ptr
; Out: R0=1 ok, 0 fail (too long/invalid)
; scoped_name_buf filled
; -----------------------------------------------------------------------------

build_scoped_name:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5
        PUSH  R6

        CPY   R6, R0
        READ  R1, scoped_name_buf
        READ  R2, 15
        READ  R3, 1

        ; empty arg?
        READ  R0, [R6]
        READ  R4, 0
        CMP   R0, R4
        JZ    _bsn_fail

        ; root cwd? cwd_buf == "/" + null
        READ  R4, [cwd_buf]
        READ  R5, CH_SLASH
        CMP   R4, R5
        JNZ   _bsn_with_prefix
        READ  R4, cwd_buf
        READ  R5, 1
        ADD   R4, R5
        READ  R4, [R4]
        READ  R5, 0
        CMP   R4, R5
        JNZ   _bsn_with_prefix
        JUMP  _bsn_copy_arg_only

_bsn_with_prefix:
        READ  R0, cwd_buf
        ADD   R0, R3                  ; skip leading '/'
_bsn_pref_loop:
        READ  R4, [R0]
        READ  R5, 0
        CMP   R4, R5
        JZ    _bsn_add_slash
        READ  R5, 0
        CMP   R2, R5
        JZ    _bsn_fail
        STORE [R1], R4
        ADD   R1, R3
        ADD   R0, R3
        SUB   R2, R3
        JUMP  _bsn_pref_loop
_bsn_add_slash:
        READ  R5, 0
        CMP   R2, R5
        JZ    _bsn_fail
        READ  R4, CH_SLASH
        STORE [R1], R4
        ADD   R1, R3
        SUB   R2, R3

_bsn_copy_arg_only:
        CPY   R0, R6
_bsn_arg_loop:
        READ  R4, [R0]
        READ  R5, 0
        CMP   R4, R5
        JZ    _bsn_done
        READ  R5, CH_SLASH
        CMP   R4, R5
        JZ    _bsn_fail
        READ  R5, 0
        CMP   R2, R5
        JZ    _bsn_fail
        STORE [R1], R4
        ADD   R1, R3
        ADD   R0, R3
        SUB   R2, R3
        JUMP  _bsn_arg_loop
_bsn_done:
        READ  R4, 0
        STORE [R1], R4
        READ  R0, 1
        JUMP  _bsn_ret
_bsn_fail:
        READ  R4, 0
        READ  R1, scoped_name_buf
        STORE [R1], R4
        READ  R0, 0
_bsn_ret:
        POP   R6
        POP   R5
        POP   R4
        POP   R3
        POP   R2
        POP   R1
        RET

; -----------------------------------------------------------------------------
; cwd_set_root
; -----------------------------------------------------------------------------

cwd_set_root:
        READ  R0, cwd_buf
        READ  R1, CH_SLASH
        STORE [R0], R1
        READ  R1, 1
        ADD   R0, R1
        READ  R1, 0
        STORE [R0], R1
        RET

; -----------------------------------------------------------------------------
; cwd_parent (cd ..)
; -----------------------------------------------------------------------------

cwd_parent:
        PUSH  R0
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4

        READ  R0, cwd_buf
        READ  R1, 1
        READ  R2, 0
        ADD   R0, R1
        READ  R3, [R0]
        CMP   R3, R2
        JZ    _cwp_done               ; already root

        READ  R0, cwd_buf
_cwp_seek_end:
        READ  R3, [R0]
        CMP   R3, R2
        JZ    _cwp_back
        ADD   R0, R1
        JUMP  _cwp_seek_end

_cwp_back:
        SUB   R0, R1                  ; last char
        READ  R4, cwd_buf
_cwp_scan:
        CMP   R0, R4
        JZ    _cwp_root
        READ  R3, [R0]
        READ  R2, CH_SLASH
        CMP   R3, R2
        JZ    _cwp_cut
        SUB   R0, R1
        JUMP  _cwp_scan

_cwp_root:
        CALL  cwd_set_root
        JUMP  _cwp_done

_cwp_cut:
        READ  R2, 0
        STORE [R0], R2

_cwp_done:
        POP   R4
        POP   R3
        POP   R2
        POP   R1
        POP   R0
        RET

; -----------------------------------------------------------------------------
; cwd_append_arg (relative)
; In: R0=arg pointer
; -----------------------------------------------------------------------------

cwd_append_arg:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5

        CPY   R5, R0
        READ  R1, cwd_buf
        READ  R2, 1

_caa_seek_end:
        READ  R3, [R1]
        READ  R4, 0
        CMP   R3, R4
        JZ    _caa_at_end
        ADD   R1, R2
        JUMP  _caa_seek_end

_caa_at_end:
        READ  R3, cwd_buf
        ADD   R3, R2
        CMP   R1, R3
        JZ    _caa_copy_arg
        READ  R3, CH_SLASH
        STORE [R1], R3
        ADD   R1, R2

_caa_copy_arg:
        CPY   R0, R5
_caa_loop:
        READ  R3, [R0]
        READ  R4, 0
        CMP   R3, R4
        JZ    _caa_done
        STORE [R1], R3
        ADD   R1, R2
        ADD   R0, R2
        JUMP  _caa_loop
_caa_done:
        READ  R3, 0
        STORE [R1], R3

        POP   R5
        POP   R4
        POP   R3
        POP   R2
        POP   R1
        RET

; -----------------------------------------------------------------------------
; get_entry_status_by_index
; In: R0=index
; Out: R0=status
; Requires disk_io_buf contains directory block
; -----------------------------------------------------------------------------

get_entry_status_by_index:
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R0, R1
        READ  R1, disk_io_buf
        ADD   R0, R1
        READ  R0, [R0]
        RET

; -----------------------------------------------------------------------------
; dir_has_children
; In: R0=full dirname (scoped name)
; Out: R0=1 has children, 0 empty
; -----------------------------------------------------------------------------

dhc_target_ptr:
        .dw 0
dir_has_children:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5
        PUSH  R6
        PUSH  R7

        STORE [dhc_target_ptr], R0
        READ  R0, list_buf
        READ  R1, 8
        CALL  disk_list
        CPY   R6, R0
        READ  R5, list_buf
        READ  R7, 1

_dhc_loop:
        READ  R4, 0
        CMP   R6, R4
        JZ    _dhc_empty
        READ  R1, [R5]               ; name ptr
        READ  R0, [dhc_target_ptr]

_dhc_cmp_pref:
        READ  R2, [R0]
        READ  R3, 0
        CMP   R2, R3
        JZ    _dhc_need_slash
        READ  R4, [R1]
        CMP   R2, R4
        JNZ   _dhc_next
        ADD   R0, R7
        ADD   R1, R7
        JUMP  _dhc_cmp_pref

_dhc_need_slash:
        READ  R4, CH_SLASH
        READ  R2, [R1]
        CMP   R2, R4
        JNZ   _dhc_next
        READ  R0, 1
        JUMP  _dhc_ret

_dhc_next:
        ADD   R5, R7
        SUB   R6, R7
        JUMP  _dhc_loop

_dhc_empty:
        READ  R0, 0
_dhc_ret:
        POP   R7
        POP   R6
        POP   R5
        POP   R4
        POP   R3
        POP   R2
        POP   R1
        RET

; -----------------------------------------------------------------------------
; ls_print_filtered
; -----------------------------------------------------------------------------

lpf_count:
        .dw 0
lpf_ptr:
        .dw 0
lpf_name:
        .dw 0
lpf_files:
        .dw 0
lpf_dirs:
        .dw 0
lpf_shown:
        .dw 0
ls_print_filtered:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5
        PUSH  R6
        PUSH  R7

        READ  R0, list_buf
        READ  R1, 8
        CALL  disk_list
        STORE [lpf_count], R0
        READ  R1, list_buf
        STORE [lpf_ptr], R1
        READ  R0, 0
        STORE [lpf_files], R0
        STORE [lpf_dirs], R0
        STORE [lpf_shown], R0

_lpf_loop:
        READ  R0, [lpf_count]
        READ  R1, 0
        CMP   R0, R1
        JZ    _lpf_done

        READ  R0, [lpf_ptr]
        READ  R0, [R0]
        STORE [lpf_name], R0

        ; build display name into line_buf based on cwd filter
        CALL  _lpf_build_line
        READ  R1, 0
        CMP   R0, R1
        JZ    _lpf_next
        CALL  _lpf_print_entry
        READ  R0, [lpf_shown]
        READ  R1, 1
        ADD   R0, R1
        STORE [lpf_shown], R0

_lpf_next:
        READ  R0, [lpf_ptr]
        READ  R1, 1
        ADD   R0, R1
        STORE [lpf_ptr], R0
        READ  R0, [lpf_count]
        SUB   R0, R1
        STORE [lpf_count], R0
        JUMP  _lpf_loop

_lpf_done:
        READ  R0, [lpf_shown]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _lpf_summary
        READ  R0, str_ls_empty
        CALL  print_str

_lpf_summary:
        CALL  _lpf_print_summary

        POP   R7
        POP   R6
        POP   R5
        POP   R4
        POP   R3
        POP   R2
        POP   R1
        RET

; _lpf_build_line
; In: lpf_name points to flat name
; Out: R0=1 included, 0 skipped. line_buf contains rendered "name[/]"
_lpf_build_line:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5
        PUSH  R6
        PUSH  R7

        READ  R1, [lpf_name]
        READ  R2, line_buf
        READ  R7, 1

        ; root?
        READ  R3, [cwd_buf]
        READ  R4, CH_SLASH
        CMP   R3, R4
        JNZ   _lpf_skip
        READ  R3, cwd_buf
        READ  R4, 1
        ADD   R3, R4
        READ  R3, [R3]
        READ  R4, 0
        CMP   R3, R4
        JNZ   _lpf_nonroot

        ; root: accept only names without '/'
_lpf_root_copy:
        READ  R3, [R1]
        READ  R4, 0
        CMP   R3, R4
        JZ    _lpf_finish_name
        READ  R4, CH_SLASH
        CMP   R3, R4
        JZ    _lpf_skip
        STORE [R2], R3
        ADD   R1, R7
        ADD   R2, R7
        JUMP  _lpf_root_copy

_lpf_nonroot:
        ; require prefix cwd_without_leading_slash + '/'
        READ  R5, cwd_buf
        ADD   R5, R7
_lpf_pref_cmp:
        READ  R3, [R5]
        READ  R4, 0
        CMP   R3, R4
        JZ    _lpf_pref_slash
        READ  R6, [R1]
        CMP   R3, R6
        JNZ   _lpf_skip
        ADD   R5, R7
        ADD   R1, R7
        JUMP  _lpf_pref_cmp
_lpf_pref_slash:
        READ  R3, [R1]
        READ  R4, CH_SLASH
        CMP   R3, R4
        JNZ   _lpf_skip
        ADD   R1, R7

_lpf_child_copy:
        READ  R3, [R1]
        READ  R4, 0
        CMP   R3, R4
        JZ    _lpf_finish_name
        READ  R4, CH_SLASH
        CMP   R3, R4
        JZ    _lpf_skip
        STORE [R2], R3
        ADD   R1, R7
        ADD   R2, R7
        JUMP  _lpf_child_copy

_lpf_finish_name:
        READ  R3, 0
        STORE [R2], R3
        READ  R0, 1
        JUMP  _lpf_ret

_lpf_skip:
        READ  R0, 0
_lpf_ret:
        POP   R7
        POP   R6
        POP   R5
        POP   R4
        POP   R3
        POP   R2
        POP   R1
        RET

; _lpf_print_entry
; In: lpf_name points to entry name, line_buf contains display name
; Prints: MM-DD HH:MM  <DIR>|<size>  name
_lpf_print_entry:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5
        PUSH  R6
        PUSH  R7

        ; entry base = name_ptr - 1
        READ  R1, [lpf_name]
        READ  R2, 1
        SUB   R1, R2

        ; size (offset 17)
        CPY   R3, R1
        READ  R2, 17
        ADD   R3, R2
        READ  R7, [R3]

        ; modified month/day (offset 21)
        CPY   R3, R1
        READ  R2, 21
        ADD   R3, R2
        READ  R5, [R3]

        ; modified hour/min (offset 25)
        CPY   R3, R1
        READ  R2, 25
        ADD   R3, R2
        READ  R6, [R3]

        ; MM
        CPY   R0, R5
        READ  R4, 8
        SHR   R0, R4
        CALL  print_u16_2
        READ  R0, 45              ; '-'
        CALL  print_char

        ; DD
        CPY   R0, R5
        READ  R4, 0x00FF
        AND   R0, R4
        CALL  print_u16_2
        READ  R0, 32              ; ' '
        CALL  print_char

        ; HH
        CPY   R0, R6
        READ  R4, 8
        SHR   R0, R4
        CALL  print_u16_2
        READ  R0, 58              ; ':'
        CALL  print_char

        ; MM
        CPY   R0, R6
        READ  R4, 0x00FF
        AND   R0, R4
        CALL  print_u16_2
        READ  R0, 2
        CALL  print_spaces

        ; type/size
        READ  R3, [R1]            ; status
        READ  R4, DISK_ENTRY_DIR
        CMP   R3, R4
        JNZ   _lpf_print_file

        READ  R0, str_ls_dir_tag
        CALL  print_str
        READ  R0, [lpf_dirs]
        READ  R2, 1
        ADD   R0, R2
        STORE [lpf_dirs], R0
        JUMP  _lpf_print_name

_lpf_print_file:
        CPY   R0, R7
        CALL  print_u16_dec
        READ  R0, 2
        CALL  print_spaces
        READ  R0, [lpf_files]
        READ  R2, 1
        ADD   R0, R2
        STORE [lpf_files], R0

_lpf_print_name:
        READ  R0, line_buf
        CALL  print_str
        READ  R0, str_nl
        CALL  print_str

        POP   R7
        POP   R6
        POP   R5
        POP   R4
        POP   R3
        POP   R2
        POP   R1
        RET

; _lpf_print_summary
; Prints file/dir counts and free/used space summary.
_lpf_print_summary:
        PUSH  R1
        PUSH  R2

        READ  R0, ls_space_buf
        CALL  disk_space

        READ  R0, str_ls_files_lbl
        CALL  print_str
        READ  R0, [lpf_files]
        CALL  print_u16_dec

        READ  R0, str_ls_dirs_lbl
        CALL  print_str
        READ  R0, [lpf_dirs]
        CALL  print_u16_dec

        READ  R0, str_ls_free_lbl
        CALL  print_str
        READ  R1, ls_space_buf
        READ  R2, 2
        ADD   R1, R2
        READ  R0, [R1]            ; free words
        CALL  print_u16_dec

        READ  R0, str_ls_used_lbl
        CALL  print_str
        READ  R1, ls_space_buf
        READ  R2, 3
        ADD   R1, R2
        READ  R0, [R1]            ; used words
        CALL  print_u16_dec

        READ  R0, str_ls_words_nl
        CALL  print_str

        POP   R2
        POP   R1
        RET

; -----------------------------------------------------------------------------
; Main
; -----------------------------------------------------------------------------

main:
        READ  R0, 0x0700
        CALL  scr_set_color
        CALL  scr_cls
        CALL  cwd_set_root
        READ  R0, str_banner
        CALL  print_str

main_loop:
        CALL  print_prompt_dos

        READ  R0, str_empty_prompt
        READ  R1, input_buf
        READ  R2, 64
        CALL  scr_cursor_blink_on
        CALL  scr_input
        CALL  scr_cursor_blink_off

        READ  R0, input_buf
        CALL  parse_input
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop

        ; help
        READ  R0, cmd_buf
        READ  R1, cmd_help
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_fdisk
        READ  R0, str_help
        CALL  print_str
        JUMP  main_loop

_cmd_fdisk:
        READ  R0, cmd_buf
        READ  R1, cmd_fdisk
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_format
        READ  R0, [fdisk_done]
        READ  R1, 0
        CMP   R0, R1
        JZ    _fdisk_go
        READ  R0, str_confirm_fdisk
        CALL  confirm_action
        READ  R1, 1
        CMP   R0, R1
        JZ    _fdisk_go
        READ  R0, str_cancelled
        CALL  print_str
        JUMP  main_loop
_fdisk_go:
        READ  R0, 1
        STORE [fdisk_done], R0
        READ  R0, 0
        STORE [format_done], R0
        CALL  cwd_set_root
        READ  R0, str_fdisk_done
        CALL  print_str
        JUMP  main_loop

_cmd_format:
        READ  R0, cmd_buf
        READ  R1, cmd_format
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_check
        READ  R0, [fdisk_done]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _fmt_do
        READ  R0, str_need_fdisk_first
        CALL  print_str
        JUMP  main_loop
_fmt_do:
        READ  R0, [format_done]
        READ  R1, 0
        CMP   R0, R1
        JZ    _fmt_do_now
        READ  R0, str_confirm_format
        CALL  confirm_action
        READ  R1, 1
        CMP   R0, R1
        JZ    _fmt_do_now
        READ  R0, str_cancelled
        CALL  print_str
        JUMP  main_loop

_fmt_do_now:
        CALL  disk_format
        READ  R1, DISK_OK
        CMP   R0, R1
        JNZ   _fmt_err

        ; Optional: format /z -> nollaa myös vapaat datablokit.
        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JZ    _fmt_done_flags
        READ  R0, arg_buf
        READ  R1, cmd_format_zero
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _fmt_done_flags
        CALL  disk_zero_free_blocks
        READ  R1, DISK_OK
        CMP   R0, R1
        JNZ   _fmt_err

_fmt_done_flags:
        READ  R0, 1
        STORE [format_done], R0
        CALL  cwd_set_root
        READ  R0, str_format_done
        CALL  print_str
        JUMP  main_loop
_fmt_err:
        CALL  print_disk_error
        JUMP  main_loop

_cmd_check:
        READ  R0, cmd_buf
        READ  R1, cmd_check
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_sync
        CALL  disk_check
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _check_ok
        CALL  print_disk_error
        JUMP  main_loop
_check_ok:
        READ  R0, str_ok
        CALL  print_str
        JUMP  main_loop

_cmd_sync:
        READ  R0, cmd_buf
        READ  R1, cmd_sync
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_ls
        CALL  disk_sync
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _sync_ok
        CALL  print_disk_error
        JUMP  main_loop
_sync_ok:
        READ  R0, str_ok
        CALL  print_str
        JUMP  main_loop

_cmd_ls:
        READ  R0, cmd_buf
        READ  R1, cmd_ls
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JZ    _cmd_ls_run
        READ  R0, cmd_buf
        READ  R1, cmd_dir
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_find
_cmd_ls_run:
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop
        CALL  ls_print_filtered
        JUMP  main_loop

_cmd_find:
        READ  R0, cmd_buf
        READ  R1, cmd_find
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_stat
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop
        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _find_go
        READ  R0, str_need_arg
        CALL  print_str
        JUMP  main_loop
_find_go:
        READ  R0, arg_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _find_call
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_find_call:
        READ  R0, scoped_name_buf
        CALL  disk_find
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JNZ   _find_ok
        READ  R0, str_not_found
        CALL  print_str
        JUMP  main_loop
_find_ok:
        READ  R0, str_found_file
        CALL  print_str
        JUMP  main_loop

_cmd_stat:
        READ  R0, cmd_buf
        READ  R1, cmd_stat
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_mkdir
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop
        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _stat_go
        READ  R0, str_need_arg
        CALL  print_str
        JUMP  main_loop
_stat_go:
        READ  R0, arg_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _stat_call
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_stat_call:
        READ  R0, scoped_name_buf
        READ  R1, io_stat_buf
        CALL  disk_stat
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _stat_ok
        CALL  print_disk_error
        JUMP  main_loop
_stat_ok:
        READ  R0, str_stat_ok
        CALL  print_str
        JUMP  main_loop

_cmd_mkdir:
        READ  R0, cmd_buf
        READ  R1, cmd_mkdir
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_cd
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop
        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _mkdir_go
        READ  R0, str_need_arg
        CALL  print_str
        JUMP  main_loop
_mkdir_go:
        READ  R0, arg_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _mkdir_call
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_mkdir_call:
        READ  R0, scoped_name_buf
        CALL  disk_mkdir
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _mkdir_ok
        CALL  print_disk_error
        JUMP  main_loop
_mkdir_ok:
        READ  R0, str_ok
        CALL  print_str
        JUMP  main_loop

_cmd_cd:
        READ  R0, cmd_buf
        READ  R1, cmd_cd
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_rmdir
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop
        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _cd_has_arg
        READ  R0, str_need_arg
        CALL  print_str
        JUMP  main_loop
_cd_has_arg:
        READ  R0, arg_buf
        READ  R1, cmd_dotdot
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cd_into
        CALL  cwd_parent
        READ  R0, str_cd_now
        CALL  print_str
        READ  R0, cwd_buf
        CALL  print_str
        READ  R0, str_nl
        CALL  print_str
        JUMP  main_loop
_cd_into:
        READ  R0, arg_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _cd_find
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_cd_find:
        READ  R0, scoped_name_buf
        CALL  disk_find_any
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JNZ   _cd_chk_type
        READ  R0, str_not_found
        CALL  print_str
        JUMP  main_loop
_cd_chk_type:
        CALL  get_entry_status_by_index
        READ  R1, DISK_ENTRY_DIR
        CMP   R0, R1
        JZ    _cd_set
        READ  R0, str_not_dir
        CALL  print_str
        JUMP  main_loop
_cd_set:
        READ  R0, arg_buf
        CALL  cwd_append_arg
        READ  R0, str_cd_now
        CALL  print_str
        READ  R0, cwd_buf
        CALL  print_str
        READ  R0, str_nl
        CALL  print_str
        JUMP  main_loop

_cmd_rmdir:
        READ  R0, cmd_buf
        READ  R1, cmd_rmdir
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_touch
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop
        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _rmdir_go
        READ  R0, str_need_arg
        CALL  print_str
        JUMP  main_loop
_rmdir_go:
        READ  R0, arg_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _rmdir_find
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_rmdir_find:
        READ  R0, scoped_name_buf
        CALL  disk_find_any
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JNZ   _rmdir_type
        READ  R0, str_not_found
        CALL  print_str
        JUMP  main_loop
_rmdir_type:
        CALL  get_entry_status_by_index
        READ  R1, DISK_ENTRY_DIR
        CMP   R0, R1
        JZ    _rmdir_empty
        READ  R0, str_not_dir
        CALL  print_str
        JUMP  main_loop
_rmdir_empty:
        READ  R0, scoped_name_buf
        CALL  dir_has_children
        READ  R1, 0
        CMP   R0, R1
        JZ    _rmdir_delete
        READ  R0, str_dir_not_empty
        CALL  print_str
        JUMP  main_loop
_rmdir_delete:
        READ  R0, scoped_name_buf
        CALL  disk_delete
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _rmdir_ok
        CALL  print_disk_error
        JUMP  main_loop
_rmdir_ok:
        READ  R0, str_ok
        CALL  print_str
        JUMP  main_loop

_cmd_touch:
        READ  R0, cmd_buf
        READ  R1, cmd_touch
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_rm
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop
        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _touch_go
        READ  R0, str_need_arg
        CALL  print_str
        JUMP  main_loop
_touch_go:
        READ  R0, arg_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _touch_call
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_touch_call:
        READ  R0, scoped_name_buf
        CALL  disk_create
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _touch_ok
        CALL  print_disk_error
        JUMP  main_loop
_touch_ok:
        READ  R0, str_ok
        CALL  print_str
        JUMP  main_loop

_cmd_rm:
        READ  R0, cmd_buf
        READ  R1, cmd_rm
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JZ    _cmd_rm_run
        READ  R0, cmd_buf
        READ  R1, cmd_del
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_copy
_cmd_rm_run:
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop
        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _rm_go
        READ  R0, str_need_arg
        CALL  print_str
        JUMP  main_loop
_rm_go:
        READ  R0, arg_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _rm_find
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_rm_find:
        READ  R0, scoped_name_buf
        CALL  disk_find_any
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JNZ   _rm_type
        READ  R0, str_not_found
        CALL  print_str
        JUMP  main_loop
_rm_type:
        CALL  get_entry_status_by_index
        READ  R1, DISK_ENTRY_FILE
        CMP   R0, R1
        JZ    _rm_delete
        READ  R0, str_not_file
        CALL  print_str
        JUMP  main_loop
_rm_delete:
        READ  R0, scoped_name_buf
        CALL  disk_delete
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _rm_ok
        CALL  print_disk_error
        JUMP  main_loop
_rm_ok:
        READ  R0, str_ok
        CALL  print_str
        JUMP  main_loop

_cmd_copy:
        READ  R0, cmd_buf
        READ  R1, cmd_copy
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_lorem
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop

        ; copy tarvitsee kaksi argumenttia
        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _copy_have_arg1
        READ  R0, str_need_arg
        CALL  print_str
        JUMP  main_loop
_copy_have_arg1:
        READ  R0, [arg2_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _copy_check_wild
        READ  R0, str_need_arg2
        CALL  print_str
        JUMP  main_loop

_copy_check_wild:
        READ  R0, arg_buf
        CALL  arg_has_wildcard
        READ  R1, 1
        CMP   R0, R1
        JZ    _copy_wild

        ; Normaali kopio: copy <src> <dst>
        READ  R0, arg_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _copy_src_ok
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_copy_src_ok:
        READ  R0, scoped_name_buf
        READ  R1, copy_src_buf
        READ  R2, 16
        CALL  _disk_str_copy

        READ  R0, arg2_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _copy_dst_ok
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_copy_dst_ok:
        READ  R0, scoped_name_buf
        READ  R1, copy_dst_buf
        READ  R2, 16
        CALL  _disk_str_copy

        READ  R0, [lorem_max_words]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _copy_have_max
        READ  R0, VRAM_START
        READ  R1, LOREM_RAM_BASE
        SUB   R0, R1
        STORE [lorem_max_words], R0
_copy_have_max:
        READ  R0, copy_src_buf
        READ  R1, copy_dst_buf
        READ  R2, LOREM_RAM_BASE
        READ  R3, [lorem_max_words]
        CALL  disk_copy
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _copy_ok
        CALL  print_disk_error
        JUMP  main_loop

_copy_wild:
        ; Wildcard-tuettu muoto: copy * <dst_dir>
        READ  R0, arg_buf
        READ  R1, cmd_star
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JZ    _copy_wild_prepare_dst
        READ  R0, str_copy_wildcard
        CALL  print_str
        JUMP  main_loop

_copy_wild_prepare_dst:
        ; Laske kohdehakemiston scoped nimi
        READ  R0, arg2_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _copy_wild_have_dst
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_copy_wild_have_dst:
        READ  R0, scoped_name_buf
        READ  R1, copy_dst_base_buf
        READ  R2, 16
        CALL  _disk_str_copy

        READ  R0, [lorem_max_words]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _copy_wild_have_max
        READ  R0, VRAM_START
        READ  R1, LOREM_RAM_BASE
        SUB   R0, R1
        STORE [lorem_max_words], R0
_copy_wild_have_max:

        ; Varmista että kohde on hakemisto (luodaan jos puuttuu)
        READ  R0, copy_dst_base_buf
        CALL  disk_find_any
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JNZ   _copy_wild_chk_dst_type
        READ  R0, copy_dst_base_buf
        CALL  disk_mkdir
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _copy_wild_list
        CALL  print_disk_error
        JUMP  main_loop
_copy_wild_chk_dst_type:
        CALL  get_entry_status_by_index
        READ  R1, DISK_ENTRY_DIR
        CMP   R0, R1
        JZ    _copy_wild_list
        READ  R0, str_not_dir
        CALL  print_str
        JUMP  main_loop

_copy_wild_list:
        READ  R0, list_buf
        READ  R1, 8
        CALL  disk_list
        STORE [lpf_count], R0
        READ  R0, list_buf
        STORE [lpf_ptr], R0

_copy_wild_loop:
        READ  R0, [lpf_count]
        READ  R1, 0
        CMP   R0, R1
        JZ    _copy_ok

        READ  R0, [lpf_ptr]
        READ  R0, [R0]            ; name ptr in disk_io_buf
        STORE [lpf_name], R0

        ; Ota vain nykyhakemiston välittömät lapset
        CALL  _lpf_build_line
        READ  R1, 0
        CMP   R0, R1
        JZ    _copy_wild_next

        ; source = full name (copy_src_buf)
        READ  R0, [lpf_name]
        READ  R1, copy_src_buf
        READ  R2, 16
        CALL  _disk_str_copy

        ; dest = dst_base + '/' + child_name
        CALL  build_copy_target_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _copy_wild_do
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop

_copy_wild_do:
        READ  R0, copy_src_buf
        READ  R1, copy_dst_buf
        READ  R2, LOREM_RAM_BASE
        READ  R3, [lorem_max_words]
        CALL  disk_copy
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _copy_wild_next
        CALL  print_disk_error
        JUMP  main_loop

_copy_wild_next:
        READ  R0, [lpf_ptr]
        READ  R1, 1
        ADD   R0, R1
        STORE [lpf_ptr], R0
        READ  R0, [lpf_count]
        SUB   R0, R1
        STORE [lpf_count], R0
        JUMP  _copy_wild_loop

_copy_ok:
        READ  R0, str_ok
        CALL  print_str
        JUMP  main_loop

_cmd_write:
        READ  R0, cmd_buf
        READ  R1, cmd_write
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_lorem
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop
        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _write_go
        READ  R0, str_need_arg
        CALL  print_str
        JUMP  main_loop
_write_go:
        READ  R0, arg_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _write_call
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_write_call:
        READ  R0, scoped_name_buf
        READ  R1, io_demo_buf
        READ  R2, 5
        CALL  disk_write
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _write_ok
        CALL  print_disk_error
        JUMP  main_loop
_write_ok:
        READ  R0, str_ok
        CALL  print_str
        JUMP  main_loop

_cmd_lorem:
        READ  R0, cmd_buf
        READ  R1, cmd_lorem
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_more
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop

        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _lorem_have_name
        READ  R0, str_need_arg
        CALL  print_str
        JUMP  main_loop
_lorem_have_name:
        READ  R0, [arg2_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _lorem_build_name
        READ  R0, str_need_arg2
        CALL  print_str
        JUMP  main_loop

_lorem_build_name:
        READ  R0, arg_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _lorem_parse_count
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop

_lorem_parse_count:
        READ  R0, arg2_buf
        CALL  parse_u16_dec
        READ  R2, 1
        CMP   R1, R2
        JZ    _lorem_chk_range
        READ  R0, str_bad_count
        CALL  print_str
        JUMP  main_loop

_lorem_chk_range:
        READ  R1, 0
        CMP   R0, R1
        JGT   _lorem_chk_max
        READ  R0, str_bad_count
        CALL  print_str
        JUMP  main_loop
_lorem_chk_max:
        READ  R1, [lorem_max_words]
        READ  R2, 0
        CMP   R1, R2
        JNZ   _lorem_have_max
        READ  R1, VRAM_START
        READ  R2, LOREM_RAM_BASE
        SUB   R1, R2
        STORE [lorem_max_words], R1
_lorem_have_max:
        CMP   R0, R1
        JLE   _lorem_fill
        READ  R0, str_bad_count
        CALL  print_str
        JUMP  main_loop

_lorem_fill:
        STORE [lorem_total_words], R0

        ; Luo tiedosto jos sitä ei ole vielä olemassa.
        ; Olemassa oleva tiedosto on OK (disk_write ylikirjoittaa sisällön).
        READ  R0, scoped_name_buf
        CALL  disk_create
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _lorem_fill_continue
        READ  R1, DISK_ERR_EXISTS
        CMP   R0, R1
        JZ    _lorem_fill_continue
        CALL  print_disk_error
        JUMP  main_loop

_lorem_fill_continue:
        READ  R0, 0
        STORE [lorem_written_words], R0

_lorem_chunk_loop:
        READ  R0, [lorem_written_words]
        READ  R1, [lorem_total_words]
        CMP   R0, R1
        JGE   _lorem_ok

        CPY   R2, R1
        SUB   R2, R0                  ; remaining
        READ  R3, MORE_BUF_WORDS      ; chunk size cap (512)
        CMP   R2, R3
        JLE   _lorem_chunk_set
        CPY   R2, R3
_lorem_chunk_set:
        STORE [lorem_chunk_words], R2

        ; Fill next chunk to RAM at (LOREM_RAM_BASE + written).
        READ  R0, LOREM_RAM_BASE
        READ  R1, [lorem_written_words]
        ADD   R0, R1
        READ  R1, [lorem_chunk_words]
        CALL  fill_lorem_words

        ; Increase total bytes to write.
        READ  R0, [lorem_written_words]
        READ  R1, [lorem_chunk_words]
        ADD   R0, R1
        STORE [lorem_written_words], R0

        ; Write accumulated lorem data with disk_write API.
        READ  R0, scoped_name_buf
        READ  R1, LOREM_RAM_BASE
        READ  R2, [lorem_written_words]
        CALL  disk_write
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _lorem_chunk_loop
        CALL  print_disk_error
        JUMP  main_loop
_lorem_ok:
        READ  R0, str_ok
        CALL  print_str
        JUMP  main_loop

_cmd_read:
        READ  R0, cmd_buf
        READ  R1, cmd_read
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_more
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop
        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _read_go
        READ  R0, str_need_arg
        CALL  print_str
        JUMP  main_loop
_read_go:
        READ  R0, arg_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _read_call
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_read_call:
        READ  R0, scoped_name_buf
        READ  R1, io_read_buf
        READ  R2, 5
        CALL  disk_read
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _read_cmp
        CALL  print_disk_error
        JUMP  main_loop
_read_cmp:
        READ  R0, io_read_buf
        READ  R1, io_demo_buf
        READ  R2, 5
        CALL  cmp_words
        READ  R1, 1
        CMP   R0, R1
        JZ    _read_match
        READ  R0, str_read_diff
        CALL  print_str
        JUMP  main_loop
_read_match:
        READ  R0, str_read_match
        CALL  print_str
        JUMP  main_loop

_cmd_more:
        READ  R0, cmd_buf
        READ  R1, cmd_more
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_run
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop
        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _more_go
        READ  R0, str_need_arg
        CALL  print_str
        JUMP  main_loop
_more_go:
        READ  R0, arg_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _more_stat
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_more_stat:
        READ  R0, scoped_name_buf
        READ  R1, io_stat_buf
        CALL  disk_stat
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _more_size
        CALL  print_disk_error
        JUMP  main_loop
_more_size:
        READ  R0, io_stat_buf
        READ  R0, [R0]            ; file size words
        READ  R1, 0
        CMP   R0, R1
        JNZ   _more_limit
        READ  R0, str_more_empty
        CALL  print_str
        JUMP  main_loop
_more_limit:
        READ  R1, MORE_BUF_WORDS
        CMP   R0, R1
        JLE   _more_use_full
        STORE [more_read_words], R1
        READ  R0, 1
        STORE [more_truncated], R0
        JUMP  _more_read
_more_use_full:
        STORE [more_read_words], R0
        READ  R0, 0
        STORE [more_truncated], R0
_more_read:
        READ  R0, scoped_name_buf
        READ  R1, more_buf
        READ  R2, [more_read_words]
        CALL  disk_read
        READ  R1, DISK_OK
        CMP   R0, R1
        JZ    _more_print
        CALL  print_disk_error
        JUMP  main_loop
_more_print:
        READ  R0, more_buf
        READ  R1, [more_read_words]
        CALL  more_print_paged
        READ  R0, [more_truncated]
        READ  R1, 0
        CMP   R0, R1
        JZ    _more_done
        READ  R0, str_more_truncated
        CALL  print_str
_more_done:
        JUMP  main_loop

_cmd_run:
        READ  R0, cmd_buf
        READ  R1, cmd_run
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_unknown
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop
        READ  R0, [arg_buf]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _run_go
        READ  R0, str_need_arg
        CALL  print_str
        JUMP  main_loop
_run_go:
        READ  R0, arg_buf
        CALL  build_scoped_name
        READ  R1, 1
        CMP   R0, R1
        JZ    _run_find
        READ  R0, str_name_long
        CALL  print_str
        JUMP  main_loop
_run_find:
        READ  R0, scoped_name_buf
        CALL  disk_find_any
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JNZ   _run_type
        READ  R0, str_not_found
        CALL  print_str
        JUMP  main_loop
_run_type:
        CALL  get_entry_status_by_index
        READ  R1, DISK_ENTRY_FILE
        CMP   R0, R1
        JZ    _run_err42
        READ  R0, str_not_file
        CALL  print_str
        JUMP  main_loop
_run_err42:
        READ  R0, str_run_err42
        CALL  print_str
        JUMP  main_loop

_cmd_unknown:
        READ  R0, str_unknown
        CALL  print_str
        JUMP  main_loop

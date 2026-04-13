.origin 0x0200

        JUMP  main

        .include "lib-screen.asm"
        .include "lib-disk.asm"

.const CH_SLASH, 47

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

; -----------------------------------------------------------------------------
; Strings
; -----------------------------------------------------------------------------

str_banner:
        .dstr "kDOS 0.1\\nType 'help' for commands.\\n"
str_prompt_a:
        .dstr "kdos:"
str_prompt_b:
        .dstr "> "
str_empty_prompt:
        .dstr ""
str_ok:
        .dstr "OK\\n"
str_unknown:
        .dstr "Unknown command. Type 'help'.\\n"
str_need_arg:
        .dstr "Missing argument.\\n"
str_need_fdisk:
        .dstr "Storage not partitioned. Run fdisk.\\n"
str_need_format:
        .dstr "Storage not formatted. Run format.\\n"
str_need_fdisk_first:
        .dstr "Run fdisk before format.\\n"
str_fs_bad:
        .dstr "Storage check failed. Re-run fdisk + format.\\n"
str_name_long:
        .dstr "Name/path too long (max 15 chars on disk).\\n"
str_exists:
        .dstr "Already exists.\\n"
str_not_found:
        .dstr "Not found.\\n"
str_dir_full:
        .dstr "Directory full.\\n"
str_disk_full:
        .dstr "Disk full.\\n"
str_range:
        .dstr "Invalid range/corrupt entry.\\n"
str_not_dir:
        .dstr "Not a directory.\\n"
str_not_file:
        .dstr "Not a file.\\n"
str_dir_not_empty:
        .dstr "Directory not empty.\\n"
str_format_done:
        .dstr "Format complete.\\n"
str_fdisk_done:
        .dstr "Partition table initialized.\\n"
str_ls_empty:
        .dstr "(empty)\\n"
str_run_err42:
        .dstr "Error 42: Life not found\\n"
str_cd_now:
        .dstr "Current dir: "
str_nl:
        .dstr "\\n"

cmd_help:
        .dstr "help"
cmd_fdisk:
        .dstr "fdisk"
cmd_format:
        .dstr "format"
cmd_ls:
        .dstr "ls"
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
cmd_run:
        .dstr "run"
cmd_dotdot:
        .dstr ".."

str_help:
        .dstr "Commands:\\n"
        .dstr "  help\\n"
        .dstr "  fdisk\\n"
        .dstr "  format\\n"
        .dstr "  ls\\n"
        .dstr "  mkdir <name>\\n"
        .dstr "  cd <name|..>\\n"
        .dstr "  rmdir <name>\\n"
        .dstr "  touch <name>\\n"
        .dstr "  rm <name>\\n"
        .dstr "  run <name>\\n"

; -----------------------------------------------------------------------------
; Utility: print string
; In: R0=ptr
; -----------------------------------------------------------------------------

print_str:
        CALL  scr_print
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
_seq2_no:
        READ  R0, 0
        POP   R4
        POP   R3
        POP   R2
        RET

; -----------------------------------------------------------------------------
; parse_input
; In: R0=input pointer
; Out: R0=1 if command exists else 0
; Fills cmd_buf and arg_buf
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
        READ  R4, 0
        STORE [R2], R4
        STORE [R3], R4

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
        READ  R0, line_buf
        CALL  print_str

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
; Out: R0=1 included, 0 skipped. line_buf contains rendered "name[/]\\n"
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
        ; append '/' for directories (status at name_ptr-1)
        READ  R1, [lpf_name]
        READ  R3, 1
        SUB   R1, R3
        READ  R3, [R1]
        READ  R4, DISK_ENTRY_DIR
        CMP   R3, R4
        JNZ   _lpf_add_nl
        READ  R3, CH_SLASH
        STORE [R2], R3
        ADD   R2, R7
_lpf_add_nl:
        READ  R3, 10
        STORE [R2], R3
        ADD   R2, R7
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
        READ  R0, str_prompt_a
        CALL  print_str
        READ  R0, cwd_buf
        CALL  print_str
        READ  R0, str_prompt_b
        CALL  print_str

        READ  R0, str_empty_prompt
        READ  R1, input_buf
        READ  R2, 64
        CALL  scr_input

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
        JNZ   _cmd_ls
        READ  R0, [fdisk_done]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _fmt_do
        READ  R0, str_need_fdisk_first
        CALL  print_str
        JUMP  main_loop
_fmt_do:
        CALL  disk_format
        READ  R1, DISK_OK
        CMP   R0, R1
        JNZ   _fmt_err
        READ  R0, 1
        STORE [format_done], R0
        CALL  cwd_set_root
        READ  R0, str_format_done
        CALL  print_str
        JUMP  main_loop
_fmt_err:
        CALL  print_disk_error
        JUMP  main_loop

_cmd_ls:
        READ  R0, cmd_buf
        READ  R1, cmd_ls
        CALL  str_eq2
        READ  R1, 1
        CMP   R0, R1
        JNZ   _cmd_mkdir
        CALL  ensure_storage_ready
        READ  R1, 0
        CMP   R0, R1
        JZ    main_loop
        CALL  ls_print_filtered
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
        JNZ   _cmd_run
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

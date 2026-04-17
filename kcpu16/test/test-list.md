# Testiluettelo — kCPU16

Tässä dokumentissa kuvataan kaikkien `test/`-hakemiston `.asm`-testitiedostojen tarkoitus.
Testit on ryhmitelty loogisesti aiheen mukaan.

Jokainen testi kuvaa yhden toiminnon tai ominaisuuden ja käyttää `.expect_reg`,
`.expect_flag` sekä `.expect_mem` -direktiivejä tulosten tarkistamiseen.

---

## 1. Yhteenlasku: ADD ja ADC

| Tiedosto                      | Kuvaus                                                                                      |
| ----------------------------- | ------------------------------------------------------------------------------------------- |
| `test_add.asm`                | ADD perustoiminta: R0 = 15 + 27 = 42; ei erikoislippuja.                                    |
| `test_add_carry.asm`          | ADD etumerkitön ylivuoto: 0xFFFE + 3 → C=1.                                                 |
| `test_add_carry_overflow.asm` | ADD sekä C=1 että V=1 samanaikaisesti: 0x8000 + 0x8000 → 0, C=1, V=1, Z=1.                  |
| `test_add_clears_flags.asm`   | ADD nollaa kaikki liput (1→0) kun tulos ei enää aseta niitä.                                |
| `test_add_flags_1to1.asm`     | ADD pitää Z=1, C=1, V=1 ennallaan (1→1) kun sama ylivuotava operaatio toistetaan.           |
| `test_add_n_1to1.asm`         | ADD pitää N=1 ja V=1 ennallaan (1→1) kun tulos on jälleen negatiivinen.                     |
| `test_add_overflow.asm`       | ADD etumerkillinen ylivuoto: 0x7FFF + 1 → V=1, N=1.                                         |
| `test_adc.asm`                | ADC perustoiminta: ADD asettaa ensin C=1, sitten ADC lisää sen tulokseen (10 + 5 + 1 = 16). |
| `test_adc_carry.asm`          | ADC tuottaa oman carryn: 0xFFFE + 1 + C(1) → R2=0, C=1.                                     |
| `test_adc_clears_flags.asm`   | ADC nollaa kaikki liput (1→0) kun tulos ei enää aseta niitä.                                |
| `test_adc_flags_1to1.asm`     | ADC pitää Z=1 ja C=1 ennallaan (1→1) kun 0xFFFF + 0 + C(1) ylivuotaa uudelleen.             |
| `test_adc_nv_1to1.asm`        | ADC pitää V=1 ennallaan (1→1); samalla testataan N:0→1 ja N:1→1.                            |
| `test_adc_overflow.asm`       | ADC etumerkillinen ylivuoto: 0x7FFF + 0 + C(1) → V=1.                                       |
| `test_adc_v_1to1.asm`         | ADC pitää V=1 ennallaan (1→1) erillisenä, eksplisiittisenä loppuarvona.                     |

---

## 2. Vähennyslasku: SUB

| Tiedosto                      | Kuvaus                                                                                      |
| ----------------------------- | ------------------------------------------------------------------------------------------- |
| `test_sub.asm`                | SUB perustoiminta: 50 − 30 = 20; ei erikoislippuja.                                         |
| `test_sub_borrow.asm`         | SUB lainaus: 5 − 10 → C=1, N=1, R0=0xFFFB.                                                  |
| `test_sub_carry_overflow.asm` | SUB C=1 ja V=1 samanaikaisesti: 0x7FFF − 0xFFFF → 0x8000, C=1, V=1.                         |
| `test_sub_clears_flags.asm`   | SUB nollaa C, V, N liput (1→0) kun tulos ei aseta niitä.                                    |
| `test_sub_cnv_1to1.asm`       | SUB pitää C=1, N=1, V=1 ennallaan (1→1) toistamalla saman operaation.                       |
| `test_sub_overflow.asm`       | SUB etumerkillinen ylivuoto: 0x8000 − 1 → V=1 (negatiivinen − positiivinen = positiivinen). |
| `test_sub_v_1to1.asm`         | SUB pitää V=1 ennallaan (1→1) itsenäisesti.                                                 |
| `test_sub_z_1to1.asm`         | SUB pitää Z=1 ennallaan (1→1) kun tulos on jälleen nolla (a − a = 0).                       |

---

## 3. Kertolasku ja jako: MUL, DIV

| Tiedosto                    | Kuvaus                                                                           |
| --------------------------- | -------------------------------------------------------------------------------- |
| `test_mul.asm`              | MUL perustoiminta: 6 × 7 = 42; myös 0 × 100 = 0 (Z=1).                           |
| `test_mul_clears_flags.asm` | MUL nollaa C, V, Z, N liput (1→0) kun tulos on pieni positiivinen.               |
| `test_mul_nv_1to1.asm`      | MUL pitää N=1 ja V=1 ennallaan (1→1): 2 × 0x4000 = 0x8000.                       |
| `test_mul_overflow.asm`     | MUL C=1 ja V=1: 0x0100 × 0x0100 = 0x10000 → katkaistu 0, C=1, V=1.               |
| `test_mul_v_1to0.asm`       | MUL nollaa V-lipun (1→0) kun tulos ei ylivuoda.                                  |
| `test_mul_v_explicit.asm`   | MUL asettaa V-lipun (0→1): 2 × 0x4000 = 0x8000.                                  |
| `test_mul_zc_1to1.asm`      | MUL pitää Z=1 ja C=1 ennallaan (1→1): 0x100 × 0x100 = 0x10000 → 0.               |
| `test_div.asm`              | DIV perustoiminta: 100 / 4 = 25; 17 / 5 = 3 (katkaisu).                          |
| `test_div_n_1to0.asm`       | DIV nollaa N-lipun (1→0) kun tulos on pieni positiivinen luku.                   |
| `test_div_n_flags.asm`      | DIV asettaa N=1 (0→1 ja 1→1): 0xFFFF / 1 = 0xFFFF → N=1.                         |
| `test_div_zero_int.asm`     | Nollalla jako laukaisee INT 0 (divide-by-zero); handler ohittaa DIV:n ja jatkaa. |
| `test_div_zero_result.asm`  | DIV nollatulos: 0 / n = 0 → Z=1; C ja V eivät muutu (DIV ei kosketa niitä).      |
| `test_div_z_1to1.asm`       | DIV pitää Z=1 ennallaan (1→1): 0 / n = 0 toistetaan.                             |

---

## 4. Vertailu: CMP

| Tiedosto                    | Kuvaus                                                                         |
| --------------------------- | ------------------------------------------------------------------------------ |
| `test_cmp.asm`              | CMP perustoiminta: yhtäsuuruus (JZ) ja pienempi (JLT); operandit eivät muutu.  |
| `test_cmp_all_cases.asm`    | CMP kaikki tapaukset: A=B (Z=1), A>B (Z=0,N=0), A<B (C=1,N=1), etumerkillinen. |
| `test_cmp_clears_flags.asm` | CMP nollaa liput (1→0) kun tulos ei aseta niitä.                               |
| `test_cmp_cnv_1to1.asm`     | CMP pitää C=1, N=1, V=1 ennallaan (1→1) toistamalla.                           |
| `test_cmp_v_explicit.asm`   | CMP asettaa V=1 (0→1): 0x7FFF vs 0xFFFF → etumerkillinen ylivuoto.             |
| `test_cmp_z_1to1.asm`       | CMP pitää Z=1 ennallaan (1→1): 55−55=0 toistetaan 99−99=0.                     |

---

## 5. Logiikkaoperaatiot: AND, OR, XOR, NOT

| Tiedosto                   | Kuvaus                                                               |
| -------------------------- | -------------------------------------------------------------------- |
| `test_and.asm`             | AND perustoiminta: 0xFF00 & 0x0F0F = 0x0F00; myös Z=1 tapaus.        |
| `test_and_flags.asm`       | AND kaikki Z- ja N-lippujen siirtymät (0→0, 0→1, 1→0, 1→1).          |
| `test_and_n_1to1.asm`      | AND pitää N=1 ennallaan (1→1) kun tulos on jälleen negatiivinen.     |
| `test_and_n_explicit.asm`  | AND asettaa N=1 (0→1): 0x8001 & 0xFFFF = 0x8001.                     |
| `test_or.asm`              | OR perustoiminta: 0xFF00 \| 0x00FF = 0xFFFF → N=1; C ja V nollataan. |
| `test_or_flags.asm`        | OR kaikki Z- ja N-lippujen siirtymät.                                |
| `test_or_n_1to1.asm`       | OR pitää N=1 ennallaan (1→1) kun tulos on jälleen negatiivinen.      |
| `test_xor.asm`             | XOR perustoiminta: 0xAAAA ^ 0x5555 = 0xFFFF; X ^ X = 0 → Z=1.        |
| `test_xor_flags.asm`       | XOR kaikki Z- ja N-lippujen siirtymät.                               |
| `test_xor_n_1to1.asm`      | XOR pitää N=1 ennallaan (1→1) kun tulos on jälleen negatiivinen.     |
| `test_xor_n_explicit.asm`  | XOR asettaa N=1 (0→1): 0x0000 ^ 0xFFFF = 0xFFFF.                     |
| `test_not.asm`             | NOT perustoiminta: ~0x0000 = 0xFFFF (N=1), ~0xFFFF = 0x0000 (Z=1).   |
| `test_not_flags.asm`       | NOT kaikki Z- ja N-lippujen siirtymät.                               |
| `test_not_n_explicit.asm`  | NOT asettaa N=1 (0→1): ~0x0000 = 0xFFFF.                             |
| `test_logic_clears_cv.asm` | AND, OR, XOR ja NOT nollaavat aina C- ja V-liput (1→0).              |

---

## 6. Siirto-operaatiot: SHL, SHR

| Tiedosto                    | Kuvaus                                                                                   |
| --------------------------- | ---------------------------------------------------------------------------------------- |
| `test_shl.asm`              | SHL perustoiminta: 1 << 3 = 8; 1 << 8 = 256.                                             |
| `test_shl_carry.asm`        | SHL carry: 0x8001 << 1 → C=1 (bitti 15 siirtyi ulos).                                    |
| `test_shl_clears_carry.asm` | SHL nollaa C-lipun (1→0) kun bitti 15 on nolla.                                          |
| `test_shl_c_1to1.asm`       | SHL pitää C=1 ennallaan (1→1) toistamalla.                                               |
| `test_shl_flags_1to1.asm`   | SHL pitää Z=1, C=1, N=1 ennallaan (1→1).                                                 |
| `test_shl_v_1to0.asm`       | SHL nollaa V-lipun aina (1→0); SHL kutsuu set_carry_overflow(..., False).                |
| `test_shl_z_1to1.asm`       | SHL pitää Z=1 ja C=1 ennallaan (1→1): 0x8000 << 1 = 0.                                   |
| `test_shr.asm`              | SHR perustoiminta: 32 >> 3 = 4; 0x0100 >> 4 = 0x0010.                                    |
| `test_shr_carry.asm`        | SHR carry: 0x0007 >> 1 → C=1 (LSB siirtyi ulos), tulos = 3.                              |
| `test_shr_clears_carry.asm` | SHR nollaa C-lipun (1→0) kun LSB on nolla.                                               |
| `test_shr_flags.asm`        | SHR: Z:1→1, C:1→1; N ja V nollataan aina (1→0).                                          |
| `test_shr_zc_1to1.asm`      | SHR pitää Z=1 ja C=1 ennallaan (1→1): 0x0001 >> 1 = 0 toistettuna.                       |
| `test_shift_edge_cases.asm` | SHL/SHR reunatapaukset: siirto 0:lla (ei muutosta), 16:lla (tulos 0), >16:lla (tulos 0). |

---

## 7. Muistinkäsittely: READ, STORE, STOREI

| Tiedosto                          | Kuvaus                                                                                                    |
| --------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `test_load.asm`                   | READ (välitön): lataa vakioarvo rekisteriin eri formaateilla (desimaali, hex, binääri); ei aseta lippuja. |
| `test_load_fp_sp.asm`             | READ FP:hen ja SP:hen; PUSH/POP toimii uudessa pinosijainnissa oikein.                                    |
| `test_load_preserves_flags.asm`   | READ ei muuta lippuja (1→1).                                                                              |
| `test_read_store.asm`             | READ/STORE (suora osoite): kirjoittaa muistiin ja lukee takaisin.                                         |
| `test_read_ind.asm`               | READ/STORE (epäsuora, [reg]): osoite on rekisterissä.                                                     |
| `test_read_rel.asm`               | READ/STORE (FP-suhteellinen, [FP+n]): siirtymäosoitus FP:n suhteen.                                       |
| `test_read_preserves_flags.asm`   | Kaikki READ-muodot (suora, epäsuora, FP-suhteellinen) säilyttävät liput (1→1).                            |
| `test_store_ind_read_ind.asm`     | STORE [reg] ja READ [reg] eri rekisteripareilla.                                                          |
| `test_store_preserves_flags.asm`  | Kaikki STORE-muodot ([addr], [reg], [FP+n]) eivät muuta lippuja (1→1).                                    |
| `test_storei.asm`                 | STORE [addr], imm: kirjoittaa välittömän vakioarvon suoraan muistiosoitteeseen.                           |
| `test_storei_ind.asm`             | STORE [reg], imm: kirjoittaa välittömän arvon rekisterin osoittamaan paikkaan.                            |
| `test_storei_rel.asm`             | STORE [FP+n], imm: kirjoittaa välittömän arvon FP-suhteelliseen osoitteeseen.                             |
| `test_storei_preserves_flags.asm` | Kaikki STOREI-muodot säilyttävät liput (1→1).                                                             |

---

## 8. Pino: PUSH, POP, SWSP

| Tiedosto                            | Kuvaus                                                                      |
| ----------------------------------- | --------------------------------------------------------------------------- |
| `test_push_pop.asm`                 | PUSH ja POP LIFO-järjestyksessä: [100, 200] → POP tulostaa 200, sitten 100. |
| `test_push_pop_preserves_flags.asm` | PUSH ja POP eivät muuta lippuja (1→1).                                      |
| `test_push_pop_sp.asm`              | Tarkistaa SP:n oikean muutoksen PUSH/POP-operaatioissa.                     |
| `test_swsp.asm`                     | SWSP vaihtaa SP:n atomisesti: R1 = vanha SP, SP = R0.                       |
| `test_swsp_preserves_flags.asm`     | SWSP säilyttää liput (1→1).                                                 |

---

## 9. Ohjausvuo: JUMP, ehdolliset hypyt, CALL, RET, CALLI, JMPI

| Tiedosto                            | Kuvaus                                                                               |
| ----------------------------------- | ------------------------------------------------------------------------------------ |
| `test_jump.asm`                     | JUMP (ehdoton hyppy): ohittaa käskyn, ei aseta lippuja.                              |
| `test_jz_jnz.asm`                   | JZ (hyppy jos Z=1) ja JNZ (hyppy jos Z=0) oikean ehdon mukaan.                       |
| `test_jlt_jgt.asm`                  | JLT (etumerkillinen pienempi) ja JGT (etumerkillinen suurempi).                      |
| `test_jle_jge.asm`                  | JLE (pienempi tai yhtä suuri) ja JGE (suurempi tai yhtä suuri).                      |
| `test_branch_not_taken.asm`         | Ehdolliset hypyt eivät tapahdu kun ehto EI täyty (negatiiviset tapaukset).           |
| `test_branch_preserves_flags.asm`   | Kaikki haarautumiskäskyt (JUMP, JZ, JNZ, JLT, JGT, JLE, JGE) eivät muuta lippuja.    |
| `test_jmpi.asm`                     | JMPI (indeksoitu epäsuora hyppy taulukkoon): indeksit 0, 1 ja 2 testattu.            |
| `test_jmpi_preserves_flags.asm`     | JMPI ei muuta lippuja (1→1).                                                         |
| `test_call_ret.asm`                 | CALL tallentaa paluuosoitteen pinoon, RET palauttaa siitä; aliohjelma asettaa R0=42. |
| `test_call_ret_preserves_flags.asm` | CALL/RET eivät muuta lippuja (1→1).                                                  |
| `test_calli.asm`                    | CALLI (indeksoitu epäsuora aliohjelmakutsu): indeksit 0, 1 ja 2 testattu.            |
| `test_calli_preserves_flags.asm`    | CALLI/RET eivät muuta lippuja (1→1).                                                 |
| `test_nested_calls.asm`             | Kolme sisäkkäistä CALL/RET-tasoa; kukin taso asettaa oman rekisterinsä.              |

---

## 10. FILL-käsky

| Tiedosto                        | Kuvaus                                                                   |
| ------------------------------- | ------------------------------------------------------------------------ |
| `test_fill.asm`                 | FILL perustoiminta: täyttää 8-sanaisen alueen arvolla 0xBEEF.            |
| `test_fill_large.asm`           | FILL suurella alueella (64 sanaa): tarkistaa alun, keskikohdan ja lopun. |
| `test_fill_max_value.asm`       | FILL maksimiarvolla 0xFFFF: alueen ulkopuoliset sanat pysyvät nollana.   |
| `test_fill_single.asm`          | FILL yhden sanan alue (regStart == regEnd): vain yksi sana muuttuu.      |
| `test_fill_zero.asm`            | FILL nolla-arvolla: nollaa ensin kirjoitetun muistialueen.               |
| `test_fill_preserves_flags.asm` | FILL ei muuta lippuja (Z, N, C, V pysyvät ennallaan).                    |

---

## 11. Rekisteri- ja yleiskäskyt: CPY, NOP, R4–R15

| Tiedosto                               | Kuvaus                                                                  |
| -------------------------------------- | ----------------------------------------------------------------------- |
| `test_cpy.asm`                         | CPY kopioi rekisterin arvon toiseen rekisteriin; ei aseta lippuja.      |
| `test_cpy_preserves_flags.asm`         | CPY ei muuta lippuja (1→1).                                             |
| `test_nop.asm`                         | NOP ei muuta rekistereitä eikä lippuja.                                 |
| `test_r4_r15_basic.asm`                | R4–R15 -rekistereihin voi ladata arvon READ:llä ja lukea siitä.         |
| `test_r4_r15_arithmetic.asm`           | ADD, SUB, MUL ja DIV toimivat R4–R15-rekistereillä.                     |
| `test_r4_r15_cpy.asm`                  | CPY toimii vanhojen (R0–R3) ja uusien (R4–R15) rekisterien välillä.     |
| `test_r4_r15_stack.asm`                | PUSH ja POP toimivat R4–R15-rekistereillä.                              |
| `test_register_independence.asm`       | ADD, SUB, CPY ja LOAD eivät korruptoi muita rekistereitä kuin kohdetta. |
| `test_register_independence_logic.asm` | AND, OR, XOR, SHL, SHR ja NOT muuttavat vain kohderekisterin.           |

---

## 12. Liput: erikoistapaukset

| Tiedosto                 | Kuvaus                                                    |
| ------------------------ | --------------------------------------------------------- |
| `test_negative_flag.asm` | N-lippu kaikissa aritmeettisissa ja loogisissa käskyissä. |
| `test_zero_result.asm`   | Z-lippu ADD:lle (0+0=0) ja SUB:lle (42−42=0).             |

---

## 13. Keskeytykset: INT, IRET, ajastin, kello, näppäimistö

| Tiedosto                      | Kuvaus                                                                                                      |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `test_int_iret.asm`           | INT 3 (breakpoint) kutsuu handlerin, IRET palauttaa oikein; PC ja SR tallennetaan pinoon.                   |
| `test_all_interrupts.asm`     | Testaa INT 0, 1, 3, 7, 4 ja 5 peräjälkeen; jokainen handler merkitsee oman rekisterinsä.                    |
| `test_invalid_opcode_int.asm` | Virheellinen opcode (0x0000) laukaisee INT 1; handler asettaa R3=0xFACE ja palaa after_trap:iin.            |
| `test_div_zero_int.asm`       | Nollalla jako laukaisee INT 0; handler ohittaa DIV-käskyn. *(ks. myös ryhmä 3)*                             |
| `test_timer_interrupt.asm`    | STMR asettaa ajastimen (TMR=10); STI sallii keskeytykset; INT 7 laukeaa ja handler asettaa R3=0xBEEF.       |
| `test_clock_interrupt.asm`    | SCTMR asettaa 1 ms välin; INT 9 laukeaa silmukan aikana; handler asettaa R3=0xC10C.                         |
| `test_clock_mmio_range.asm`   | Lukee kellorekisterit MMIO:sta ja tarkistaa että arvot ovat odotetuilla arvoalueilla (kuukausi 1–12, jne.). |
| `test_clock_year.asm`         | CLOCK_YEAR MMIO palauttaa vuosiluvun joka on suurempi kuin 2000.                                            |
| `test_keyboard_interrupt.asm` | `.inject_key` simuloi näppäinpainallusta; INT 6 laukeaa I=1:n aikana; handler lukee KBD_DATA:n.             |
| `test_kbd_multiple_keys.asm`  | Kolme peräkkäistä `.inject_key` -painallusta laukaisevat kolme INT 6:ta; R1 = viimeisin koodi, R2 = 3.      |
| `test_kbd_release_raw.asm`    | KBD_DATA raakaarvo vapautustapahtumassa: KBD_RELEASE_BIT (bit 7) on asetettu, maski palauttaa koodin.       |
| `test_kget_dummy.asm`         | KBD_DATA ja KBD_STATUS MMIO palauttavat 0 kun puskuri on tyhjä.                                             |

---

## 14. Suojaus ja privileged-käskyt

| Tiedosto                           | Kuvaus                                                                                                              |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `test_privilege_violation.asm`     | User-mode HALT laukaisee INT 4 (privilege violation); handler asettaa merkkiarvon ja palaa.                         |
| `test_privilege_all.asm`           | Kaikki privileged-käskyt (HALT, STI, CLI, SMPR, STMR, IRET) user-tilassa laukaisevat INT 4; laskuri R3.             |
| `test_user_kernel_mode.asm`        | IRET siirtää user-tilaan (P=0); INT palauttaa kernel-tilaan (P=1); P-lippu tarkistetaan eri vaiheissa.              |
| `test_memory_protection.asm`       | SMPR asettaa MPR=0x0300; user-mode READ alle MPR:n laukaisee INT 5 (memory access fault).                           |
| `test_memory_protection_store.asm` | User-mode STORE suojattuun muistiin laukaisee INT 5; testataan useampi osoitusmuoto.                                |
| `test_stack_overflow_dummy.asm`    | Dokumentoi miksi pinoylivuoto (INT 2) ei ole testattavissa automaattisesti; testiä ei suoriteta.                    |
| `test_dread_dwrite_priv_dummy.asm` | Dokumentoi miksi DREAD/DWRITE privilege-rikkomus ei ole testattavissa ilman tallennuslaitetta; testiä ei suoriteta. |

---

## 15. Järjestelmärekisterit: SMPR, STMR, STI, CLI, TSL, uptime

| Tiedosto             | Kuvaus                                                                                  |
| -------------------- | --------------------------------------------------------------------------------------- |
| `test_smpr_stmr.asm` | SMPR asettaa MPR-rekisterin; STMR asettaa ajastinrekisterin (TMR).                      |
| `test_sti_cli.asm`   | STI asettaa I-lipun, CLI nollaa sen; vaikuttaa vain I-lippuun.                          |
| `test_tsl.asm`       | TSL (test and set lock): ensimmäinen lukee 0 ja lukitsee, toinen lukee 1.               |
| `test_tsl_flags.asm` | TSL asettaa Z- ja N-liput vanhan arvon mukaan.                                          |
| `test_uptime.asm`    | UPTIME MMIO -rekisterit: W3 ja W2 ovat aina 0; W1:W0 on validi 32-bittinen uptime-arvo. |

---

## 16. Tallennuslaite: DREAD, DWRITE

| Tiedosto                | Kuvaus                                                                             |
| ----------------------- | ---------------------------------------------------------------------------------- |
| `test_dread_dwrite.asm` | DWRITE kirjoittaa tallennuslaitteeseen, DREAD lukee takaisin; kaksi eri osoitetta. |

---

## 17. Satunnaislukugeneraattori: RAND MMIO

| Tiedosto                | Kuvaus                                                            |
| ----------------------- | ----------------------------------------------------------------- |
| `test_rand_nonzero.asm` | RAND MMIO palauttaa nollasta poikkeavan arvon oletussiemenellä.   |
| `test_rand_changes.asm` | Kaksi peräkkäistä lukua RAND MMIO:sta eroavat toisistaan.         |
| `test_rand_seed.asm`    | Sama siemen (0xDEAD) johtaa deterministiseen tulokseen: R0 == R1. |

---

## 18. Assembler-direktiivit ja -ominaisuudet

| Tiedosto                  | Kuvaus                                                                                    |
| ------------------------- | ----------------------------------------------------------------------------------------- |
| `test_directives.asm`     | `.origin`, `.db`, `.dstr` ja `.at` direktiivit; raakadata oikein muistissa.               |
| `test_dw.asm`             | `.dw` ja `.db` direktiivit koko arvoalueelta: 0–65535, negatiiviset, hex.                 |
| `test_number_formats.asm` | Kaikki numeroliteraalimuodot: desimaali, heksadesimaali (0x), binääri (0b), oktaali (0o). |
| `test_include_basic.asm`  | `.include` sisällyttää kirjastotiedoston ja sen funktio on kutsuttavissa.                 |
| `test_include_const.asm`  | `.include`:n vakio (LIB_CONST) näkyy päätiedostossa.                                      |
| `test_include_twice.asm`  | Kaksi eri kirjastotiedostoa voidaan sisällyttää samaan ohjelmaan.                         |

---

## 19. Grafiikkakirjasto

| Tiedosto                          | Kuvaus                                                      |
| --------------------------------- | ----------------------------------------------------------- |
| `test_gfx_scroll_up_b_slow.asm`   | `gfx_scroll_up` toimii 1 px siirrolla tilassa B.            |
| `test_gfx_scroll_up_b_fast.asm`   | `gfx_scroll_up` fastpath toimii 2 px siirrolla tilassa B.   |
| `test_gfx_scroll_up_c_slow.asm`   | `gfx_scroll_up` toimii 1 px siirrolla tilassa C.            |
| `test_gfx_scroll_up_c_fast.asm`   | `gfx_scroll_up` fastpath toimii 4 px siirrolla tilassa C.   |
| `test_gfx_scroll_down_b_slow.asm` | `gfx_scroll_down` toimii 1 px siirrolla tilassa B.          |
| `test_gfx_scroll_down_b_fast.asm` | `gfx_scroll_down` fastpath toimii 2 px siirrolla tilassa B. |
| `test_gfx_scroll_down_c_slow.asm` | `gfx_scroll_down` toimii 1 px siirrolla tilassa C.          |
| `test_gfx_scroll_down_c_fast.asm` | `gfx_scroll_down` fastpath toimii 4 px siirrolla tilassa C. |

---

## 20. Algoritmiesimerkit

| Tiedosto                    | Kuvaus                                                            |
| --------------------------- | ----------------------------------------------------------------- |
| `test_factorial_expect.asm` | Laskee 5! = 120 MUL- ja SUB-käskyillä iteratiivisessa silmukassa. |

---

## Yhteenveto

| Ryhmä                                | Testejä |
| ------------------------------------ | ------- |
| ADD ja ADC                           | 14      |
| SUB                                  | 8       |
| MUL ja DIV                           | 13      |
| CMP                                  | 6       |
| AND, OR, XOR, NOT                    | 15      |
| SHL ja SHR                           | 13      |
| Muistinkäsittely (READ/STORE/STOREI) | 13      |
| Pino (PUSH/POP/SWSP)                 | 5       |
| Ohjausvuo (JUMP/CALL/RET jne.)       | 13      |
| FILL                                 | 6       |
| Rekisteri- ja yleiskäskyt            | 9       |
| Liput (erikoistapaukset)             | 2       |
| Keskeytykset                         | 12      |
| Suojaus ja privileged                | 7       |
| Järjestelmärekisterit                | 5       |
| Tallennuslaite                       | 1       |
| Satunnaislukugeneraattori            | 3       |
| Assembler-direktiivit                | 6       |
| Grafiikkakirjasto                    | 8       |
| Algoritmiesimerkit                   | 1       |
| **Yhteensä**                         | **160** |

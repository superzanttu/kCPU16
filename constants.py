"""
kCPU16 arkkitehtuurin perusvakiot.

Tama tiedosto maarittaa kaikki keskeiset vakiot, joita kaytetaan
prosessorin emuloinnissa. Vakiot on jaettu loogisiin ryhmiin:

1. Sana- ja muistivakiot - perusrajat ja maskit
2. Keskeytysvektorit - virhe- ja laitekes keskeytysten numerot
3. Muistialueet - eri tarkoituksiin varatut osoiteavaruudet
4. Tilalippujen bitti-indeksit - SR-rekisterin rakenne
5. Suoritustilat - kernel vs. user mode
"""

# =============================================================================
# SANA- JA MUISTIVAKIOT
# =============================================================================

# 16-bittinen maski - rajaa kaikki arvot valille 0x0000-0xFFFF
WORD_MASK = 0xFFFF

# Kokonaismuistiavaruus sanoina (2^16 = 65536 sanaa)
MEMORY_WORDS = 0x10000

# =============================================================================
# KESKEYTYSVEKTORIT (INTERRUPT VECTORS)
# Keskeytyksen sattuessa CPU hakee kasittelijan osoitteen vektorista.
# Esim. INT_DIV_ZERO = 0 -> kasittelijaosoite haetaan muistista 0x0000
# =============================================================================

INT_DIV_ZERO = 0  # Jako nollalla (DIV-kasky kun jakaja = 0)
INT_INVALID_OPCODE = 1  # Tuntematon/virheellinen opcode
INT_STACK_OVERFLOW = 2  # Pino ylittaa sallitun rajan
INT_BREAKPOINT = 3  # Debug/breakpoint (ohjelmallinen)
INT_PRIVILEGE_VIOLATION = 4  # User-tila yrittaa ajaa kernel-kaskya
INT_MEMORY_ACCESS_FAULT = 5  # User-tila yrittaa lukea suojattua muistia
INT_KEYBOARD = 6  # Nappaimiston laitteistokeskeytys
INT_TIMER = 7  # Ajastinkeskeytys (TMR-rekisterin maarittama)
INT_PROCESS_EXIT = 8  # Prosessin hallittu lopetus (EXIT-kasky)

# Keskeytysvektorit alkavat muistin alusta
INT_VECTOR_BASE = 0x0000
# Tuettujen keskeytysten maara
INT_VECTOR_COUNT = 9

# =============================================================================
# MUISTIALUEET (MEMORY MAP)
# Muistiavaruus 0x0000-0xFFFF on jaettu eri tarkoituksiin.
# =============================================================================

# Boot-alue: Bootloader kopioidaan tallennuslaitteelta tanne kaynnistyksessa
BOOT_RAM_START = 0x0100  # Ensimmainen bootloaderin osoite RAM:ssa
BOOT_RAM_END = 0x01FF  # Viimeinen bootloaderin osoite RAM:ssa

# Video RAM (nayttomuisti): 80 saraketta x 25 rivia = 2000 sanaa
# Jokainen sana = merkki (bitit 0-7) + attribuutit (bitit 8-15)
# SANAN RAKENNE:
#   Bitit 0-7:   ASCII-merkki
#   Bitit 8-11:  Attribuutit (lihavointi, kursiivi, vilkku, alleviivaus, yliviivaus)
#   Bitit 12-14: Edusta-väri (FG, 0-7, 3 bittiä)
#   Bitit 15:    Tausta-väri (BG, 1-bittinen ensin, sitten laajennetaan)
VRAM_START = 0xF800  # Nayttomuistin alkuosoite (vasen ylanurkka)
VRAM_END = 0xFFCF    # Nayttomuistin loppuosoite (80x25 = 2000 sanaa)
VRAM_WORDS = 2000    # 80 cols x 25 rows

# Nayton mitat merkkeina
SCREEN_COLS = 80  # Sarakkeet (leveys)
SCREEN_ROWS = 25  # Rivit (korkeus)

# =============================================================================
# VÄRIJÄRJESTELMÄ - VRAM:N BITTIKENTÄT
# =============================================================================

# VRAM-sanan ASCII-merkki ja attribuutit
VRAM_CHAR_MASK = 0x00FF  # Bitit 0-7: ASCII-merkki
VRAM_CHAR_SHIFT = 0

# Attribuutit (Bitit 8-12) - lihavointi, kursiivi, vilkku, alleviivaus, yliviivaus
VRAM_ATTR_BOLD = 0x0100       # Bitti 8: Lihavointi
VRAM_ATTR_ITALIC = 0x0200    # Bitti 9: Kursiivi
VRAM_ATTR_BLINK = 0x0400     # Bitti 10: Vilkku
VRAM_ATTR_UNDERLINE = 0x0800  # Bitti 11: Alleviivaus
VRAM_ATTR_STRIKETHROUGH = 0x1000  # Bitti 12: Yliviivaus
VRAM_ATTR_MASK = 0x1F00      # Kaikki attribuutit

# Värit (Bitit 12-15)
VRAM_FG_MASK = 0x7000        # Bitit 12-14: Edusta-väri (FG, 3 bittiä = 0-7)
VRAM_FG_SHIFT = 12
VRAM_BG_MASK = 0x8000        # Bitti 15: Tausta-väri (BG, aluksi 1-bittinen)
VRAM_BG_SHIFT = 15

# Värikoodit (0-7 tai 0-1 taustalle)
COLOR_BLACK = 0
COLOR_RED = 1
COLOR_GREEN = 2
COLOR_YELLOW = 3
COLOR_BLUE = 4
COLOR_MAGENTA = 5
COLOR_CYAN = 6
COLOR_WHITE = 7

# Värien nimet mappaukseen
COLOR_NAMES = {
    0: "musta",
    1: "punainen",
    2: "vihreä",
    3: "keltainen",
    4: "sininen",
    5: "magenta",
    6: "syaani",
    7: "valkoinen",
}

# Kernel-pino: Kayttojarjestelman sisainen pino keskeytyksille yms.
# Sijaitsee muistin lopussa, VRAM:n yläpuolella
KERNEL_STACK_START = 0xFFD0  # Kernelin pino alkaa VRAM:n jälkeen
KERNEL_STACK_END = 0xFFFF    # Muistin loppu

# =============================================================================
# OLETUSARVOT JARJESTELMAREKISTEREILLE
# =============================================================================

# Oletusarvo MPR-rekisterille (Memory Protection Register)
# Maarittaa User-tilan muistirajan - User ei voi lukea/kirjoittaa alle MPR
DEFAULT_MPR = BOOT_RAM_START

# Oletusarvo TMR-rekisterille (Timer Register)
# 0 = ajastin pois paalta, muuten laukaisee keskeytyksen TMR kaskyjen valein
DEFAULT_TIMER_INTERVAL = 0

# =============================================================================
# SUORITUSTILAT (EXECUTION MODES)
# P-lippu (Privilege) maarittaa onko CPU kernel- vai user-tilassa
# =============================================================================

MODE_KERNEL = 1  # Taydellat oikeudet kaikkeen muistiin ja kaikkiin kaskyihin
MODE_USER = 0  # Rajoitetut oikeudet (MPR:n mukainen muistisuojaus)

# =============================================================================
# TILAREKISTERIN (SR) BITTI-INDEKSIT
# SR on 16-bittinen rekisteri, jossa kukin bitti on oma lippunsa.
# Esim. get_flag(SR_FLAG_Z) palauttaa onko Zero-lippu asetettu.
# =============================================================================

SR_FLAG_Z = 0  # Zero: 1 = edellisen operaation tulos oli nolla
SR_FLAG_N = 1  # Negative: 1 = tuloksen ylin bitti on 1 (negatiivinen etumerkkillisena)
SR_FLAG_C = 2  # Carry: 1 = tapahtui etumerkiton ylivuoto (yhteenlasku ylitti 0xFFFF)
SR_FLAG_V = 3  # Overflow: 1 = tapahtui etumerkillinen ylivuoto
SR_FLAG_I = 4  # Interrupt Enable: 1 = laitteistokeskeytykset sallittu
SR_FLAG_P = 5  # Privilege: 1 = Kernel Mode, 0 = User Mode

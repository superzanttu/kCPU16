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

# Video RAM (nayttomuisti): 80 saraketta x 24 rivia = 1920 sanaa
# Jokainen sana = merkki (bitit 0-7) + attribuutit (bitit 8-15)
VRAM_START = 0xF800  # Nayttomuistin alkuosoite (vasen ylanurkka)
VRAM_END = 0xFF7F  # Nayttomuistin loppuosoite
VRAM_WORDS = VRAM_END - VRAM_START + 1  # = 1920 sanaa

# Nayton mitat merkkeina
SCREEN_COLS = 80  # Sarakkeet (leveys)
SCREEN_ROWS = 24  # Rivit (korkeus)

# Kernel-pino: Kayttojarjestelman sisainen pino keskeytyksille yms.
KERNEL_STACK_START = 0xFF80
KERNEL_STACK_END = 0xFFFF

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

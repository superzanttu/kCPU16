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

# Etumerkkilipun bitti (ylin bitti 16-bittisessa sanassa)
WORD_SIGN_BIT = 0x8000

# Sanan bittileveysarvo (SHL/SHR-laskuissa)
WORD_BITS = 16

# 5-bitin rekisteriindeksimaski (kattaa R0-R15=0-15, FP=16, SP=17)
REG_IDX_MASK = 0x1F

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
INT_CLOCK = 9  # Kellokeskeytys (CTMR-rekisterin ms-vali)

# Keskeytysvektorit alkavat muistin alusta
INT_VECTOR_BASE = 0x0000
# Varattu tila vektoritaulukolle (16 paikkaa, $0000-$000F)
# Tällä hetkellä käytössä 9 (0-8), loput 7 varattuna tulevaisuutta varten
INT_VECTOR_COUNT = 16

# =============================================================================
# MUISTIALUEET (MEMORY MAP)
# Muistiavaruus 0x0000-0xFFFF on jaettu eri tarkoituksiin.
# =============================================================================

# =============================================================================
# KELLOKELLO-MMIO (SYSTEM CLOCK MMIO)
# Osoitteet $0010-$001F ovat vain luettavia MMIO-rekisterejä.
# Lukeminen palauttaa reaaliaikaisen järjestelmäkellon arvon.
# Kirjoittaminen $001B:hen (CLOCK_INT_INTERVAL) säätää kellokeskeytyksen välin.
# =============================================================================

CLOCK_MMIO_START = 0x0010  # MMIO-alueen alku
CLOCK_MMIO_END = 0x001F  # MMIO-alueen loppu

CLOCK_YEAR = 0x0010  # Vuosi (esim. 2026)
CLOCK_MONTH = 0x0011  # Kuukausi (1-12)
CLOCK_DAY = 0x0012  # Päivä (1-31)
CLOCK_HOUR = 0x0013  # Tunti (0-23)
CLOCK_MINUTE = 0x0014  # Minuutti (0-59)
CLOCK_SECOND = 0x0015  # Sekunti (0-59)
CLOCK_MILLIS = 0x0016  # Millisekunti (0-999)

# 64-bittinen sekuntilaskuri (nousee yhden kerran sekunnissa, pyörähtää 2^64:ssä)
# Tallennettu neljään 16-bittiseen sanaan, MSW ensin
UPTIME_W3 = 0x0017  # Laskurin bitit 48-63 (korkein)
UPTIME_W2 = 0x0018  # Laskurin bitit 32-47
UPTIME_W1 = 0x0019  # Laskurin bitit 16-31
UPTIME_W0 = 0x001A  # Laskurin bitit  0-15 (matalin)

# Kellokeskeytyksen väli millisekunteina (0 = pois päältä)
# Asetetaan SCTMR-käskyllä; INT_CLOCK (9) laukeaa kun I=1 ja aika täyttynyt
CLOCK_INT_INTERVAL = 0x001B  # CTMR MMIO-osoite (kirjoitus asettaa välin)

# Oletusarvo CTMR:lle (0 = kellokeskeytys pois)
DEFAULT_CLOCK_INT_INTERVAL = 0

# =============================================================================
# NÄPPÄIMISTÖ-MMIO (KEYBOARD MMIO)
# Osoitteet $0020-$0021 ovat näppäimistölaitteen MMIO-rekisterejä.
# Näppäimistö generoi INT 6 -keskeytyksen jokaisesta näppäimen painalluksesta
# ja vapautuksesta. Keskeytysrutiini lukee tapahtuman KBD_DATA-osoitteesta.
#
# SKANNIKOODI-RAKENNE (16 bittiä, alin tavu käytössä):
#   Bitti 7 (KBD_RELEASE_BIT): 0 = painallus, 1 = vapautus
#   Bitit 6-0: näppäimen koodi (ASCII-arvo tai scan code, 0-127)
#
# Esimerkki: 'A' painetaan -> KBD_DATA = 0x41, 'A' vapautetaan -> 0xC1
# =============================================================================

KBD_MMIO_START = 0x0020  # Näppäimistö-MMIO-alueen alku
KBD_MMIO_END = 0x0021  # Näppäimistö-MMIO-alueen loppu

KBD_DATA = 0x0020  # Lue: pops seuraava näppäintapahtuma puskurista (0 jos tyhjä)
KBD_STATUS = 0x0021  # Lue: tapahtumien määrä puskurissa (0 = tyhjä)

# Bitti 7 KBD_DATA:ssa: asetettu = vapautus, nolla = painallus
KBD_RELEASE_BIT = 0x80

# 7-bittinen nappainkoodi maski (bitit 6-0)
KBD_KEY_CODE_MASK = 0x7F

# =============================================================================
# SATUNNAISLUKUGENERAATTORI-MMIO (RANDOM MMIO)
# Osoite $0022: lukeminen palauttaa seuraavan 16-bittisen LFSR-arvon.
# Kirjoittaminen asettaa siemenen (arvo 0 nollataan arvoon 1).
# Toteutus: 16-bittinen Galois LFSR, polynomi x^16+x^15+x^13+x^4+1 (0xB400).
# =============================================================================

RAND_MMIO = 0x0022  # Lue: seuraava pseudosatunnaisluku; kirjoitus: aseta siemen
RAND_LFSR_MASK = 0xB400  # Galois LFSR feedback-maski (max-length, jakso 65535)
RAND_LFSR_SEED = 0xACE1  # Oletussiemen (nollasta poikkeava)

# Boot-alue: Bootloader kopioidaan tallennuslaitteelta tanne kaynnistyksessa
BOOT_RAM_START = 0x0100  # Ensimmainen bootloaderin osoite RAM:ssa
BOOT_RAM_END = 0x01FF  # Viimeinen bootloaderin osoite RAM:ssa

# Video RAM (nayttomuisti): 80 saraketta x 25 rivia = 2000 sanaa
# Jokainen sana = merkki (bitit 0-7) + attribuutit (bitit 8-15)
# SANAN RAKENNE:
#   Bitit 0-7:   ASCII-merkki
#   Bitit 8-10:  Edusta-väri (FG, 3 bittiä = 8 väriä)
#   Bitit 11-13: Tausta-väri (BG, 3 bittiä = 8 väriä)
#   Bitti 14:    Lihavointi
#   Bitti 15:    Varattu (0)
VRAM_START = 0xF800  # Nayttomuistin alkuosoite (vasen ylanurkka)
VRAM_END = 0xFF7F  # Nayttomuistin loppuosoite (80x24 = 1920 sanaa)
VRAM_WORDS = 1920  # 80 cols x 24 rows

# Nayton mitat merkkeina
SCREEN_COLS = 80  # Sarakkeet (leveys)
SCREEN_ROWS = 24  # Rivit (korkeus)

# =============================================================================
# VÄRIJÄRJESTELMÄ - VRAM:N BITTIKENTÄT
# =============================================================================

# VRAM-sanan ASCII-merkki
VRAM_CHAR_MASK = 0x00FF  # Bitit 0-7: ASCII-merkki
VRAM_CHAR_SHIFT = 0

# Värit (Bitit 8-13)
VRAM_FG_MASK = 0x0700  # Bitit 8-10: Edusta-väri (FG, 3 bittiä = 8 väriä)
VRAM_FG_SHIFT = 8
VRAM_BG_MASK = 0x3800  # Bitit 11-13: Tausta-väri (BG, 3 bittiä = 8 väriä)
VRAM_BG_SHIFT = 11

# Attribuutit
VRAM_ATTR_BOLD = 0x4000  # Bitti 14: Lihavointi
# Bitti 15 on varattu — kirjoittaminen sallittu, lukeminen ignorataan

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

# =============================================================================
# GRAFIIKKATILAN REKISTERI (GFX_MODE_REG)
# Sijaitsee muistiosoitteessa 0xFF80 (kernelin pinon alun ensimmäinen sana).
# lib-gfx.asm käyttää tästä osoitteesta nimeä GFX_MODE_REG.
# =============================================================================

GFX_MODE_REG = 0xFF80  # Grafiikkatila-rekisterin muistiosoite
GFX_MODE_A = 0  # Tila A — tekstitila  (80 × 24 merkkiä)
GFX_MODE_B = 1  # Tila B — puoliblokkipikseli  (80 × 48 pikseliä)
GFX_MODE_C = 2  # Tila C — braille          (160 × 96 pikseliä)
# Kaksoisbufferoinnin flip-rekisteri (GFX_FLIP_REG)
# Kirjoittaminen mitä tahansa arvoa tähän osoitteeseen käynnistää bufferif lipin:
# näytön taustapuolelle piirretyt muutokset kopioidaan etupuskuriin ja
# päivitetään näytölle kerralla. Rekisteri nollataan automaattisesti flipin jälkeen.
GFX_FLIP_REG = 0xFF81  # Kaksoisbufferoinnin flip-rekisteri (kirjoitus = flip)
# Näkyvän etupuskurin scroll-komentorekisteri.
# Kirjoita arvo (suunta << 8) | amount, jolloin näkyvä etupuskuri kopioidaan
# VRAMiin siirrettynä ja paljastuneet pikselit nollataan.
GFX_SCROLL_CMD_REG = 0xFF82
# Kernel-pino: Kayttojarjestelman sisainen pino keskeytyksille yms.
# Sijaitsee muistin lopussa, VRAM:n yläpuolella
KERNEL_STACK_START = 0xFF80  # Kernelin pino alkaa VRAM:n jälkeen
KERNEL_STACK_END = 0xFFFF  # Muistin loppu

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
# TALLENNUSLAITTEEN VAKIOT
# =============================================================================

# Blokin koko sanoina (256 sanaa = 512 tavua)
STORAGE_BLOCK_SIZE = 0x0100

# Blokkien maara (256 blokkia)
STORAGE_BLOCK_COUNT = 0x0100

# =============================================================================
# SUORITUKSEN OLETUSSYKLIMAARAT
# =============================================================================

# CLI run-komennon oletussyklit
DEFAULT_RUN_CYCLES = 10000

# CLI examples --run -oletussyklit
DEFAULT_EXAMPLE_CYCLES = 50000

# REPL-tilan oletussyklit (run ilman argumenttia)
DEFAULT_REPL_CYCLES = 1000

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

# =============================================================================
# ASSEMBLER-VAKIOT (ARCH_SYMBOLS)
# Nämä symbolit injektoidaan assemblerin labelitaulukkoon automaattisesti,
# joten assembly-koodissa voi viitata niihin suoraan nimellä ilman #-etuliitettä.
#
# Kaikki arvot ovat viittauksia yllä määriteltyihin vakioihin —
# yksikään arvo ei ole kovakoodattu tänne erikseen.
# =============================================================================

ARCH_SYMBOLS: dict[str, int] = {
    # ---- Muistivakiot ------------------------------------------------
    "MEMORY_WORDS": MEMORY_WORDS,  # Muistiavaruuden koko sanoina (65536)
    "WORD_MASK": WORD_MASK,  # 16-bittinen maski (0xFFFF)
    "WORD_SIGN_BIT": WORD_SIGN_BIT,  # Etumerkkilipun bitti (0x8000)
    "WORD_BITS": WORD_BITS,  # Sanan bittimäärä (16)
    # ---- Boot-alue ---------------------------------------------------
    "BOOT_RAM_START": BOOT_RAM_START,  # Bootloaderin aloitusosoite (0x0100)
    "BOOT_RAM_END": BOOT_RAM_END,  # Bootloaderin loppuosoite  (0x01FF)
    # ---- Video RAM (VRAM) --------------------------------------------
    "VRAM_START": VRAM_START,  # Näyttömuistin alkuosoite  (0xF800)
    "VRAM_END": VRAM_END,  # Näyttömuistin loppuosoite (0xFF7F)
    "VRAM_WORDS": VRAM_WORDS,  # Näyttömuistin koko sanoina (1920)
    # ---- Näytön mitat ------------------------------------------------
    "SCREEN_COLS": SCREEN_COLS,  # Sarakkeiden lukumäärä (80)
    "SCREEN_ROWS": SCREEN_ROWS,  # Rivien lukumäärä (24)
    # ---- VRAM-sanan bittikentät --------------------------------------
    "VRAM_CHAR_MASK": VRAM_CHAR_MASK,  # Merkkikenttä bittimaski (0x00FF)
    "VRAM_CHAR_SHIFT": VRAM_CHAR_SHIFT,  # Merkkikentän shift (0)
    "VRAM_FG_MASK": VRAM_FG_MASK,  # Edusta-värikenttä maski (0x0700)
    "VRAM_FG_SHIFT": VRAM_FG_SHIFT,  # Edusta-värikentän shift (8)
    "VRAM_BG_MASK": VRAM_BG_MASK,  # Tausta-värikenttä maski (0x3800)
    "VRAM_BG_SHIFT": VRAM_BG_SHIFT,  # Tausta-värikentän shift (11)
    "VRAM_ATTR_BOLD": VRAM_ATTR_BOLD,  # Lihavointi-attribuutti (0x4000)
    # ---- Värikoodit --------------------------------------------------
    "COLOR_BLACK": COLOR_BLACK,  # Musta  (0)
    "COLOR_RED": COLOR_RED,  # Punainen (1)
    "COLOR_GREEN": COLOR_GREEN,  # Vihreä   (2)
    "COLOR_YELLOW": COLOR_YELLOW,  # Keltainen (3)
    "COLOR_BLUE": COLOR_BLUE,  # Sininen   (4)
    "COLOR_MAGENTA": COLOR_MAGENTA,  # Magenta   (5)
    "COLOR_CYAN": COLOR_CYAN,  # Syaani    (6)
    "COLOR_WHITE": COLOR_WHITE,  # Valkoinen (7)
    # ---- Kernel-pino -------------------------------------------------
    "KERNEL_STACK_START": KERNEL_STACK_START,  # Kernelin pinon alku (0xFF80)
    "KERNEL_STACK_END": KERNEL_STACK_END,  # Kernelin pinon loppu (0xFFFF)
    # ---- Keskeytysvektorit -------------------------------------------
    "INT_VECTOR_BASE": INT_VECTOR_BASE,  # Vektorialueen alku (0x0000)
    "INT_VECTOR_COUNT": INT_VECTOR_COUNT,  # Varattu vektoritaulukko (16)
    "INT_DIV_ZERO": INT_DIV_ZERO,  # Jako nollalla (0)
    "INT_INVALID_OPCODE": INT_INVALID_OPCODE,  # Tuntematon opcode (1)
    "INT_STACK_OVERFLOW": INT_STACK_OVERFLOW,  # Pinon ylivuoto (2)
    "INT_BREAKPOINT": INT_BREAKPOINT,  # Debug-breakpoint (3)
    "INT_PRIVILEGE": INT_PRIVILEGE_VIOLATION,  # Oikeusrikkomus (4)
    "INT_MEM_FAULT": INT_MEMORY_ACCESS_FAULT,  # Muistisuojausrikkomus (5)
    "INT_KEYBOARD": INT_KEYBOARD,  # Näppäimistökeskeytys (6)
    "INT_TIMER": INT_TIMER,  # Ajastinkeskeytys (7)
    "INT_PROCESS_EXIT": INT_PROCESS_EXIT,  # Prosessin lopetus (8)
    "INT_CLOCK": INT_CLOCK,  # Kellokeskeytys (9)
    # ---- Kellon MMIO-osoitteet ($0010-$001F) -------------------------
    "CLOCK_MMIO_START": CLOCK_MMIO_START,  # MMIO-alueen alku  (0x0010)
    "CLOCK_MMIO_END": CLOCK_MMIO_END,  # MMIO-alueen loppu (0x001F)
    "CLOCK_YEAR": CLOCK_YEAR,  # Vuosi MMIO   (0x0010)
    "CLOCK_MONTH": CLOCK_MONTH,  # Kuukausi MMIO (0x0011)
    "CLOCK_DAY": CLOCK_DAY,  # Päivä MMIO   (0x0012)
    "CLOCK_HOUR": CLOCK_HOUR,  # Tunti MMIO   (0x0013)
    "CLOCK_MINUTE": CLOCK_MINUTE,  # Minuutti MMIO (0x0014)
    "CLOCK_SECOND": CLOCK_SECOND,  # Sekunti MMIO  (0x0015)
    "CLOCK_MILLIS": CLOCK_MILLIS,  # Millisekunti MMIO (0x0016)
    "UPTIME_W3": UPTIME_W3,  # Uptime bitit 48-63 (0x0017)
    "UPTIME_W2": UPTIME_W2,  # Uptime bitit 32-47 (0x0018)
    "UPTIME_W1": UPTIME_W1,  # Uptime bitit 16-31 (0x0019)
    "UPTIME_W0": UPTIME_W0,  # Uptime bitit  0-15 (0x001A)
    "CLOCK_INT_INTERVAL": CLOCK_INT_INTERVAL,  # CTMR MMIO (0x001B)
    # ---- Näppäimistö-MMIO ($0020-$0021) -----------------------------
    "KBD_MMIO_START": KBD_MMIO_START,  # Näppäimistö-MMIO alku (0x0020)
    "KBD_MMIO_END": KBD_MMIO_END,  # Näppäimistö-MMIO loppu (0x0021)
    "KBD_DATA": KBD_DATA,  # Näppäintapahtuma MMIO (0x0020)
    "KBD_STATUS": KBD_STATUS,  # Puskurin koko MMIO   (0x0021)
    "KBD_RELEASE_BIT": KBD_RELEASE_BIT,  # Vapautusbitti (0x80)
    "KBD_KEY_CODE_MASK": KBD_KEY_CODE_MASK,  # Nappainkoodi maski (0x7F)
    # ---- Satunnaislukugeneraattori MMIO ($0022) ----------------------
    "RAND_MMIO": RAND_MMIO,  # Satunnaisluku MMIO (0x0022)
    "RAND_LFSR_SEED": RAND_LFSR_SEED,  # LFSR-oletussiemen (0xACE1)
    # ---- Tallennuslaite ----------------------------------------------
    "STORAGE_BLOCK_SIZE": STORAGE_BLOCK_SIZE,  # Blokin koko sanoina (256)
    "STORAGE_BLOCK_COUNT": STORAGE_BLOCK_COUNT,  # Blokkien lukumäärä (256)
    # ---- Tilarekisterin (SR) bitti-indeksit --------------------------
    "SR_FLAG_Z": SR_FLAG_Z,  # Zero-lippu, bitti-indeksi (0)
    "SR_FLAG_N": SR_FLAG_N,  # Negative-lippu (1)
    "SR_FLAG_C": SR_FLAG_C,  # Carry-lippu (2)
    "SR_FLAG_V": SR_FLAG_V,  # Overflow-lippu (3)
    "SR_FLAG_I": SR_FLAG_I,  # Interrupt Enable -lippu (4)
    "SR_FLAG_P": SR_FLAG_P,  # Privilege-lippu (5)
    # ---- Grafiikkarekisterit ($FF80-$FF82) ----------------------------
    "GFX_MODE_REG": GFX_MODE_REG,  # Grafiikkatila-rekisteri (0xFF80)
    "GFX_MODE_A": GFX_MODE_A,  # Tekstitila (0)
    "GFX_MODE_B": GFX_MODE_B,  # Puoliblokkipikseli (1)
    "GFX_MODE_C": GFX_MODE_C,  # Braille (2)
    "GFX_FLIP_REG": GFX_FLIP_REG,  # Kaksoisbufferoinnin flip-rekisteri (0xFF81)
    "GFX_SCROLL_CMD_REG": GFX_SCROLL_CMD_REG,  # Visible->VRAM scroll (0xFF82)
    # ---- Suoritustilat -----------------------------------------------
    "MODE_KERNEL": MODE_KERNEL,  # Kernel-tila (1)
    "MODE_USER": MODE_USER,  # User-tila (0)
    # ---- Oletusarvot järjestelmärekistereille -------------------------
    "DEFAULT_MPR": DEFAULT_MPR,  # MPR:n oletusarvo (== BOOT_RAM_START)
}

"""
Rekisteritiedosto (Register File) kCPU16-prosessorille.

Sisaltaa kaikki prosessorin rekisterit ja niiden kasittelymetodit.

REKISTERIT:
-----------
Yleiskayttoiset (General Purpose Registers, GPR):
    R0, R1, R2, R3  - 16-bittiset datarekisterit laskutoimituksiin

Erikoisrekisterit:
    FP  - Frame Pointer: Aliohjelman pinokehyksen pohja
    SP  - Stack Pointer: Osoittaa pinon huipulle (pino kasvaa alaspain)
    PC  - Program Counter: Seuraavan suoritettavan kaskyn osoite
    SR  - Status Register: Tilaliput (Z, N, C, V, I, P)

Jarjestelmarekisterit:
    MPR - Memory Protection Register: User-muistin alaraja
    TMR - Timer Register: Ajastinkeskeytyksen vali (0 = pois)

TILAREKISTERIN (SR) RAKENNE:
----------------------------
Bitti 0 (Z): Zero      - 1 jos tulos = 0
Bitti 1 (N): Negative  - 1 jos tuloksen ylin bitti = 1
Bitti 2 (C): Carry     - 1 jos etumerkiton ylivuoto
Bitti 3 (V): Overflow  - 1 jos etumerkillinen ylivuoto
Bitti 4 (I): Interrupt - 1 = keskeytykset sallittu
Bitti 5 (P): Privilege - 1 = Kernel Mode, 0 = User Mode
"""

from dataclasses import dataclass, field

from .constants import (
    BOOT_RAM_START,
    DEFAULT_MPR,
    DEFAULT_TIMER_INTERVAL,
    KERNEL_STACK_END,
    MODE_KERNEL,
    SR_FLAG_C,
    SR_FLAG_I,
    SR_FLAG_N,
    SR_FLAG_P,
    SR_FLAG_V,
    SR_FLAG_Z,
    WORD_MASK,
)


@dataclass
class RegisterFile:
    """
    Prosessorin rekisteritiedosto.

    Sisaltaa kaikki rekisterit ja metodit niiden kasittelyyn.
    Kaynnistyksen yhteydessa reset()-metodi asettaa oletusarvot.

    Attributes:
        r0, r1, r2, r3: Yleiskayttoiset datarekisterit (0-0xFFFF)
        fp: Frame Pointer - alijohjelmakutsun pinokehyksen pohja
        sp: Stack Pointer - pinon huipun osoite (alkaa 0xFFFF, kasvaa alas)
        pc: Program Counter - seuraavan kaskyn osoite (oletus: 0x0100)
        sr: Status Register - tilaliput bittikentassa
        mpr: Memory Protection Register - User-muistin alaraja
        tmr: Timer Register - ajastinkeskeytyksen vali kaskyina
    """

    # Yleiskayttoiset rekisterit (alustetaan nollaksi)
    r0: int = 0
    r1: int = 0
    r2: int = 0
    r3: int = 0

    # Erikoisrekisterit
    fp: int = 0  # Frame Pointer (ei kaytos kaynnistyksessa)
    sp: int = KERNEL_STACK_END  # Stack Pointer alkaa muistin lopusta
    pc: int = BOOT_RAM_START  # Program Counter alkaa bootloader-alueelta
    sr: int = 0  # Status Register (liput nollaa)

    # Jarjestelmarekisterit
    mpr: int = DEFAULT_MPR  # Memory Protection Register
    tmr: int = DEFAULT_TIMER_INTERVAL  # Timer Register

    # Sisainen: rekisterinimien lista (ei alusteta ulkoisesti)
    _gpr_names: tuple[str, ...] = field(default=("R0", "R1", "R2", "R3"), init=False)

    def reset(self) -> None:
        """
        Nollaa kaikki rekisterit kaynnistysarvoihin.

        Tama simuloi kylmakaynnistysta (cold boot):
        - Kaikki GPR:t nollataan
        - SP -> 0xFFFF (pinon pohja)
        - PC -> 0x0100 (bootloaderin alku)
        - Kernel Mode paalle (P=1), keskeytykset pois (I=0)
        """
        self.r0 = 0
        self.r1 = 0
        self.r2 = 0
        self.r3 = 0
        self.fp = 0
        self.sp = KERNEL_STACK_END
        self.pc = BOOT_RAM_START
        self.sr = 0
        self.mpr = DEFAULT_MPR
        self.tmr = DEFAULT_TIMER_INTERVAL
        # Aseta Kernel Mode (P=1) ja deaktivoi keskeytykset (I=0)
        self.set_flag(SR_FLAG_P, MODE_KERNEL)
        self.set_flag(SR_FLAG_I, 0)

    def get_flag(self, bit: int) -> int:
        """
        Lue yksittaisen lipun arvo SR-rekisterista.

        Args:
            bit: Lipun bitti-indeksi (0-5, ks. SR_FLAG_* vakiot)

        Returns:
            1 jos lippu on asetettu, 0 muuten

        Example:
            >>> regs.get_flag(SR_FLAG_Z)  # Onko Zero-lippu paalla?
            0
        """
        return 1 if (self.sr & (1 << bit)) else 0

    def set_flag(self, bit: int, value: int) -> None:
        """
        Aseta yksittaisen lipun arvo SR-rekisteriin.

        Args:
            bit: Lipun bitti-indeksi (0-5)
            value: 0 = nollaa lippu, ei-0 = aseta lippu

        Example:
            >>> regs.set_flag(SR_FLAG_Z, 1)  # Aseta Zero-lippu
        """
        if value:
            # Aseta bitti: OR lipun maskin kanssa
            self.sr |= 1 << bit
        else:
            # Nollaa bitti: AND kaanteismaskin kanssa
            self.sr &= ~(1 << bit)
        # Varmista etta SR pysyy 16-bittisena
        self.sr &= WORD_MASK

    @property
    def in_kernel_mode(self) -> bool:
        """
        Tarkista onko CPU Kernel-tilassa.

        Returns:
            True jos P-lippu = 1 (Kernel Mode)
            False jos P-lippu = 0 (User Mode)
        """
        return bool(self.get_flag(SR_FLAG_P))

    def set_zn_flags(self, value: int) -> None:
        """
        Paivita Zero- ja Negative-liput arvon perusteella.

        Kutsutaan useimpien aritmeettisten operaatioiden jalkeen.

        Args:
            value: Operaation tulos (maskataan 16-bittiseksi)

        Toiminta:
            Z = 1 jos value == 0
            N = 1 jos value:n ylin bitti (bitti 15) = 1
        """
        value &= WORD_MASK  # Varmista 16-bittisyys
        # Zero: onko arvo nolla?
        self.set_flag(SR_FLAG_Z, 1 if value == 0 else 0)
        # Negative: onko ylin bitti 1? (bitti 15 = 0x8000)
        self.set_flag(SR_FLAG_N, 1 if (value & 0x8000) else 0)

    def set_carry_overflow(self, carry: bool, overflow: bool) -> None:
        """
        Paivita Carry ja Overflow -liput.

        Args:
            carry: True jos tapahtui etumerkiton ylivuoto
                   (summa ylitti 0xFFFF tai vahennys meni negatiiviseksi)
            overflow: True jos tapahtui etumerkillinen ylivuoto
                   (positiivinen + positiivinen = negatiivinen jne.)
        """
        self.set_flag(SR_FLAG_C, 1 if carry else 0)
        self.set_flag(SR_FLAG_V, 1 if overflow else 0)

"""
Assembler kCPU16-prosessorille.

Muuntaa assembly-lahdekoodin konekieleksi (lista 16-bittisia sanoja).

KAKSIPASSINEN TOIMINTA:
-----------------------
Pass 0: Makrojen ekspansointi ja .origin direktiivin käsittely
Pass 1: Kerataan labelit ja lasketaan niiden osoitteet
Pass 2: Luodaan konekieli korvaamalla labelit osoitteilla

SYNTAKSI:
---------
- Yksi kasky per rivi
- Labelit omalla rivillaan, paattyvat kaksoispisteeseen: "loop:"
- Tokenit erotetaan valilyonnilla/pilkulla
- Rekisterit: R0, R1, R2, R3, FP, SP (case-insensitive)
- Numerot: 42, 0xFF, #42, #0xFF, $F800
- Label-viittaukset suoraan operandina: "JUMP loop"
- Kommentit alkavat puolipisteella: "; tama on kommentti"
- Direktiivit:
  - .origin OSOITE (esim. .origin 0x0200)
  - .macro NIMI ... .endmacro (esim. .macro LOAD_MANY ... .endmacro)

ESIMERKKI:
----------
    .origin 0x0200       ; Koodi alkaa osoitteesta 0x0200

    .macro LOAD_MANY
        LOAD  R0, 10
        LOAD  R1, 20
        LOAD  R2, 30
    .endmacro

    START:
        LOAD_MANY        ; Ekspandoi makroksi
        JUMP  START
        HALT

Tuottaa konekielen osoitteesta 0x0200 eteenpäin.
"""

from __future__ import annotations

from .constants import BOOT_RAM_START, WORD_MASK
from .instruction import OPCODE_TABLE


# =============================================================================
# REKISTERIEN KOODAUS
# Rekisterinimet -> numeerinen indeksi (kayta operandeissa)
# =============================================================================

REGISTER_TO_ID: dict[str, int] = {
    "R0": 0,  # Yleiskayttoinen rekisteri 0
    "R1": 1,  # Yleiskayttoinen rekisteri 1
    "R2": 2,  # Yleiskayttoinen rekisteri 2
    "R3": 3,  # Yleiskayttoinen rekisteri 3
    "FP": 4,  # Frame Pointer (aliohjelmien pinokehys)
    "SP": 5,  # Stack Pointer (pinon osoitin)
}

# Kaanteinen hakutaulukko: mnemonic -> opcode
# Luodaan OPCODE_TABLE:sta kaantamalla avain-arvot
MNEMONIC_TO_OPCODE: dict[str, int] = {v[0]: k for k, v in OPCODE_TABLE.items()}


class Assembler:
    """
    kCPU16 Assembler - muuntaa assembly-koodin konekieleksi.

    Toimii kolmessa passissa:
    0. Makrojen ekspansointi ja .origin käsittely
    1. Kerataan labelit ja lasketaan niiden muistiosoitteet
    2. Tuotetaan lopullinen konekieli

    Example:
        >>> asm = Assembler()
        >>> code = '''
        ...     LOAD R0, 42
        ...     HALT
        ... '''
        >>> words = asm.assemble(code)
        >>> words
        [1, 0, 42, 68]  # LOAD opcode, R0 index, 42, HALT opcode
    """

    def assemble(self, source: str, start_addr: int = BOOT_RAM_START) -> list[int]:
        """
        Assembloi lahdekoodi konekieleksi.

        Args:
            source: Assembly-lahdekoodi merkkijonona
            start_addr: Ohjelman aloitusosoite muistissa (oletus: 0x0100)

        Returns:
            Lista 16-bittisia sanoja (konekieli)

        Raises:
            ValueError: Jos mnemonic on tuntematon tai label on duplikaatti

        Example:
            >>> asm.assemble("LOAD R0, 10\\nHALT", start_addr=0x0200)
            [1, 0, 10, 68]
        """
        # Pass 0: Makrojen ekspansointi ja .origin käsittely
        expanded_source, start_addr = self._pass0_expand_macros_and_origin(
            source, start_addr
        )
        # Pass 1: Kerataan labelit
        labels = self._pass1_collect_labels(expanded_source, start_addr)
        # Pass 2: Tuotetaan konekieli
        return self._pass2_emit(expanded_source, labels)

    def _pass0_expand_macros_and_origin(
        self, source: str, start_addr: int
    ) -> tuple[str, int]:
        """
        Pass 0: Makrojen ekspansointi ja .origin direktiivin käsittely.

        Ensin käsitellään .origin direktiivit, sitten makrot.

        Args:
            source: Assembly-lahdekoodi
            start_addr: Oletusarvoinen aloitusosoite

        Returns:
            Tuple: (laajennettu_lähdekoodi, käytetty_aloitusosoite)
        """
        lines = source.splitlines()

        # 1. Etsi .origin direktiivi
        for line in lines:
            stripped = line.split(";", 1)[0].strip()
            if stripped.lower().startswith(".origin") or stripped.lower().startswith(
                ".org"
            ):
                # Parse: ".origin 0x0200" -> 0x0200
                parts = stripped.split()
                if len(parts) > 1:
                    try:
                        start_addr = int(parts[1], 0) & WORD_MASK
                    except ValueError:
                        raise ValueError(f"Invalid .origin value: {parts[1]}")

        # 2. Kerää makrot
        macros: dict[str, list[str]] = {}
        expanded_lines = []
        i = 0
        while i < len(lines):
            line = lines[i]
            stripped = line.split(";", 1)[0].strip()

            # Makron alkaminen
            if stripped.lower().startswith(".macro"):
                parts = stripped.split()
                if len(parts) < 2:
                    raise ValueError(f"Invalid .macro syntax: {line}")
                macro_name = parts[1].upper()

                # Kerää makron sisältö
                macro_lines = []
                i += 1
                while i < len(lines):
                    macro_line = lines[i]
                    macro_stripped = macro_line.split(";", 1)[0].strip()

                    if macro_stripped.lower().startswith(".endmacro"):
                        macros[macro_name] = macro_lines
                        break

                    macro_lines.append(macro_line)
                    i += 1
                i += 1
                continue

            # Ohita .origin ja .macro rivit tulosteesta
            if (
                stripped.lower().startswith(".origin")
                or stripped.lower().startswith(".org")
                or stripped.lower().startswith(".macro")
                or stripped.lower().startswith(".endmacro")
            ):
                i += 1
                continue

            # Korvaa makrokutsut
            mnemonic = stripped.split()[0].upper() if stripped else ""
            if mnemonic in macros:
                # Ekspandoi makro
                expanded_lines.extend(macros[mnemonic])
            else:
                expanded_lines.append(line)

            i += 1

        expanded_source = "\n".join(expanded_lines)
        return expanded_source, start_addr

    def _pass1_collect_labels(self, source: str, start_addr: int) -> dict[str, int]:
        """
        Pass 1: Kerataan labelit ja lasketaan niiden muistiosoitteet.

        Kaydaan lahdekoodi lapi ja kirjataan jokaisen labelin
        kohdalle tuleva osoite. Samalla lasketaan kaskyjen koot
        jotta osoitteet ovat oikein.

        Args:
            source: Assembly-lahdekoodi
            start_addr: Aloitusosoite

        Returns:
            Sanakirja: label-nimi -> muistiosoite

        Raises:
            ValueError: Jos sama label maaritellaan kahdesti
        """
        labels: dict[str, int] = {}
        addr = start_addr  # Nykyinen osoite (kasvaa kaskyjen mukana)

        for raw_line in source.splitlines():
            # Poista kommentit (puolipiste ja kaikki sen jalkeen)
            line = raw_line.split(";", 1)[0].strip()
            if not line:
                continue  # Tyhja rivi -> ohita

            # Onko tama label? (paattyy kaksoispisteeseen)
            if line.endswith(":"):
                # "loop:" -> "LOOP"
                label_name = line[:-1].strip().upper()
                if label_name in labels:
                    raise ValueError(f"Duplicate label: {label_name}")
                # Tallenna labelin osoite
                labels[label_name] = addr
                continue  # Label ei kuluta muistia

            # Muuten tama on kasky - laske sen koko
            # "ADD R0, R1" -> ["ADD", "R0", "R1"]
            mnemonic = line.replace(",", " ").split()[0].upper()

            # Hae opcode ja operandien maara
            opcode = MNEMONIC_TO_OPCODE.get(mnemonic)
            if opcode is None:
                raise ValueError(f"Unknown mnemonic: {mnemonic}")

            _, operand_count, _ = OPCODE_TABLE[opcode]
            # Kaskyn koko = 1 (opcode) + operandien maara
            addr += 1 + operand_count

        return labels

    def _pass2_emit(self, source: str, labels: dict[str, int]) -> list[int]:
        """
        Pass 2: Tuota lopullinen konekieli.

        Kaydaan lahdekoodi uudelleen lapi ja tuotetaan jokainen
        kasky: opcode + operandit. Labelit korvataan osoitteilla.

        Args:
            source: Assembly-lahdekoodi
            labels: Pass 1:ssa keratyt labelit ja osoitteet

        Returns:
            Lista 16-bittisia sanoja
        """
        words: list[int] = []

        for raw_line in source.splitlines():
            # Poista kommentit
            line = raw_line.split(";", 1)[0].strip()

            # Ohita tyhjat rivit ja labelit
            if not line or line.endswith(":"):
                continue

            # Parsi kasky: "ADD R0, R1" -> ["ADD", "R0", "R1"]
            parts = line.replace(",", " ").split()
            mnemonic = parts[0].upper()

            # Hae opcode
            opcode = MNEMONIC_TO_OPCODE.get(mnemonic)
            if opcode is None:
                raise ValueError(f"Unknown mnemonic: {mnemonic}")

            # Lisaa opcode tulosteeseen
            words.append(opcode)

            # Parsi ja lisaa operandit
            for token in parts[1:]:
                words.append(self._parse_operand(token, labels))

        # Varmista etta kaikki arvot ovat 16-bittisia
        return [w & WORD_MASK for w in words]

    def _parse_operand(self, token: str, labels: dict[str, int]) -> int:
        """
        Parsi yksittainen operandi.

        Tunnistetaan:
        - Rekisterinimet: R0, R1, R2, R3, FP, SP
        - Labelit: loop, DONE, jne.
        - Numeroliteraalit: 42, 0xFF, #42, #0xFF, $F800

        Args:
            token: Operandin teksti (esim. "R0", "loop", "42")
            labels: Tunnetut labelit ja niiden osoitteet

        Returns:
            Numeerinen arvo operandille

        Example:
            >>> asm._parse_operand("R0", {})
            0
            >>> asm._parse_operand("loop", {"LOOP": 0x0100})
            256
            >>> asm._parse_operand("#0xFF", {})
            255
            >>> asm._parse_operand("$F800", {})
            63488
        """
        upper = token.upper()

        # Onko rekisteri?
        if upper in REGISTER_TO_ID:
            return REGISTER_TO_ID[upper]

        # Onko label?
        if upper in labels:
            return labels[upper]

        # Poista mahdollinen #-etuliite (immediate-merkki)
        if upper.startswith("#"):
            upper = upper[1:]

        # Muunna $-etuliitteinen heksadesimaaliliteraali (esim. $F800 -> 0xF800)
        if upper.startswith("$"):
            upper = "0x" + upper[1:]

        # Muunna numeroksi (tue 0x, 0b, ja desimaali)
        # int(x, 0) tunnistaa formaatin automaattisesti
        return int(upper, 0)

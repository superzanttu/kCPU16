"""
Assembler kCPU16-prosessorille.

Muuntaa assembly-lahdekoodin konekieleksi (lista 16-bittisia sanoja).

KAKSIPASSINEN TOIMINTA:
-----------------------
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

ESIMERKKI:
----------
    ; Laske 10 + 5
    LOAD  R0, 10      ; R0 = 10
    LOAD  R1, 5       ; R1 = 5
    ADD   R0, R1      ; R0 = R0 + R1 = 15
    HALT

Tuottaa konekielen:
    [0x0001, 0x0000, 0x000A,   ; LOAD R0, 10
     0x0001, 0x0001, 0x0005,   ; LOAD R1, 5
     0x0010, 0x0000, 0x0001,   ; ADD R0, R1
     0x0044]                   ; HALT
"""

from __future__ import annotations

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

    Toimii kahdessa passissa:
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

    def assemble(self, source: str, start_addr: int = 0x0100) -> list[int]:
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
        # Pass 1: Kerataan labelit
        labels = self._pass1_collect_labels(source, start_addr)
        # Pass 2: Tuotetaan konekieli
        return self._pass2_emit(source, labels)

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
        return [w & 0xFFFF for w in words]

    def _parse_operand(self, token: str, labels: dict[str, int]) -> int:
        """
        Parsi yksittainen operandi.

        Tunnistetaan:
        - Rekisterinimet: R0, R1, R2, R3, FP, SP
        - Labelit: loop, DONE, jne.
        - Numeroliteraalit: 42, 0xFF, #42, #0xFF

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

        # Muunna numeroksi (tue 0x, 0b, ja desimaali)
        # int(x, 0) tunnistaa formaatin automaattisesti
        return int(upper, 0)

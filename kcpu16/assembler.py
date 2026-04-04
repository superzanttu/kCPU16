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
  - .db TAVU, TAVU, ... (esim. .db 0x41, 0x42, 255)
  - .dstr "TEKSTI" (esim. .dstr "Hello!", automaattinen null-terminaattori)
  - .at OSOITE (esim. .at 0xF800, siirtyy uuteen muistiosoitteeseen)
  - .expect_reg REK, ARVO (esim. .expect_reg R0, 120, testaukseen)
  - .expect_flag LIPPU, ARVO (esim. .expect_flag Z, 0, testaukseen)
  - .expect_mem OSOITE, ARVO (esim. .expect_mem 0x0300, 0xFF, testaukseen)
  - .expect_storage OSOITE, ARVO (tallennuslaiteen testaus)

ESIMERKKI:
----------
    .origin 0x0200       ; Koodi alkaa osoitteesta 0x0200

    .macro LOAD_MANY
        LOAD  R0, 10
        LOAD  R1, 20
        LOAD  R2, 30
    .endmacro

    MSG:
        .dstr "Hello!"  ; 7 sanaa: H,e,l,l,o,!,0x00
    NUMS:
        .db 0x01, 0x02   ; 2 sanaa: 0x01, 0x02

    START:
        LOAD_MANY        ; Ekspandoi makroksi
        LOAD  R0, MSG    ; R0 = datan aloitusosoite
        JUMP  START
        HALT

    .at 0xF800           ; Seuraava data kirjoitetaan VRAMiin
    VRAM_DATA:
        .dstr "kCPU16"  ; Alustudata suoraan VRAMiin

Tuottaa konekielen osoitteesta 0x0200 eteenpäin.
VRAM_DATA-symboli osoittaa 0xF800.
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
        >>> segments = asm.assemble(code)
        >>> segments
        [(256, [1, 0, 42, 68])]  # [(start_addr, [LOAD, R0=0, 42, HALT])]
    """

    def assemble(
        self, source: str, start_addr: int = BOOT_RAM_START
    ) -> list[tuple[int, list[int]]]:
        """
        Assembloi lahdekoodi konekieleksi segmentteina.

        Args:
            source: Assembly-lahdekoodi merkkijonona
            start_addr: Ohjelman aloitusosoite muistissa (oletus: 0x0100)

        Returns:
            Lista (aloitusosoite, sanat) -pareista. Yleensa yksi segmentti,
            mutta .at-direktiivilla voi olla useampia.

        Raises:
            ValueError: Jos mnemonic on tuntematon tai label on duplikaatti

        Example:
            >>> asm.assemble("LOAD R0, 10\\nHALT", start_addr=0x0200)
            [(512, [1, 0, 10, 68])]
        """
        # Pass 0: Makrojen ekspansointi ja .origin käsittely
        expanded_source, start_addr = self._pass0_expand_macros_and_origin(
            source, start_addr
        )
        # Pass 1: Kerataan labelit
        labels = self._pass1_collect_labels(expanded_source, start_addr)
        # Pass 2: Tuotetaan konekieli segmentteina
        return self._pass2_emit(expanded_source, labels, start_addr)

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

            # .at direktiivi: siirry uuteen muistiosoitteeseen (uusi segmentti)
            if line.lower().startswith(".at ") or line.lower() == ".at":
                parts = line.split()
                if len(parts) < 2:
                    raise ValueError(f"Invalid .at syntax: {line}")
                addr = int(parts[1], 0) & WORD_MASK
                continue

            # .db direktiivi: tallenna raakoja tavuja muistiin
            if line.lower().startswith(".db"):
                addr += len(self._parse_db_values(line))
                continue

            # .dstr direktiivi: tallenna null-terminoitu merkkijono muistiin
            if line.lower().startswith(".dstr"):
                addr += len(self._parse_dstr_values(line))
                continue

            # .expect_*-direktiivit: ainoastaan testaukseen, ei tuota koodia
            if line.lower().startswith(".expect_"):
                continue

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

    def _pass2_emit(
        self, source: str, labels: dict[str, int], start_addr: int
    ) -> list[tuple[int, list[int]]]:
        """
        Pass 2: Tuota lopullinen konekieli segmentteina.

        Kaydaan lahdekoodi uudelleen lapi ja tuotetaan jokainen
        kasky: opcode + operandit. Labelit korvataan osoitteilla.
        .at-direktiivi aloittaa uuden segmentin uudessa muistiosoitteessa.

        Args:
            source: Assembly-lahdekoodi
            labels: Pass 1:ssa keratyt labelit ja osoitteet
            start_addr: Ensimmaisen segmentin aloitusosoite

        Returns:
            Lista (aloitusosoite, sanat) -pareista.
        """
        segments: list[tuple[int, list[int]]] = []
        current_start = start_addr
        current_words: list[int] = []

        for raw_line in source.splitlines():
            # Poista kommentit
            line = raw_line.split(";", 1)[0].strip()

            # Ohita tyhjat rivit ja labelit
            if not line or line.endswith(":"):
                continue

            # .at direktiivi: tallenna nykyinen segmentti, aloita uusi
            if line.lower().startswith(".at ") or line.lower() == ".at":
                if current_words:
                    segments.append(
                        (current_start, [w & WORD_MASK for w in current_words])
                    )
                parts = line.split()
                if len(parts) < 2:
                    raise ValueError(f"Invalid .at syntax: {line}")
                current_start = int(parts[1], 0) & WORD_MASK
                current_words = []
                continue

            # .db direktiivi: emittoi raakoja tavuja
            if line.lower().startswith(".db"):
                current_words.extend(self._parse_db_values(line))
                continue

            # .dstr direktiivi: emittoi null-terminoitu merkkijono
            if line.lower().startswith(".dstr"):
                current_words.extend(self._parse_dstr_values(line))
                continue

            # .expect_*-direktiivit: testaukseen, ei tuota koodia
            if line.lower().startswith(".expect_"):
                continue

            # Parsi kasky: "ADD R0, R1" -> ["ADD", "R0", "R1"]
            parts = line.replace(",", " ").split()
            mnemonic = parts[0].upper()

            # Hae opcode
            opcode = MNEMONIC_TO_OPCODE.get(mnemonic)
            if opcode is None:
                raise ValueError(f"Unknown mnemonic: {mnemonic}")

            # Lisaa opcode tulosteeseen
            current_words.append(opcode)

            # Parsi ja lisaa operandit
            for token in parts[1:]:
                current_words.append(self._parse_operand(token, labels))

        # Tallenna viimeinen segmentti
        if current_words:
            segments.append((current_start, [w & WORD_MASK for w in current_words]))

        return segments

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

    def _parse_db_values(self, line: str) -> list[int]:
        """
        Parsi .db-direktiivin arvot.

        Hyväksyy pilkulla erotetun listan numeroita (desimaali tai hex).
        Jokainen arvo maskataan 8 bittiin (0x00–0xFF).

        Args:
            line: Direktiiviriivi, esim. ".db 0x41, 66, 0b01000011"

        Returns:
            Lista kokonaislukuja, kukin väliltä 0–255.

        Example:
            >>> asm._parse_db_values(".db 0x41, 0x42")
            [65, 66]
        """
        # Poista ".db" etuliite
        rest = line[3:].strip()
        if not rest:
            return []
        values = []
        for token in rest.split(","):
            token = token.strip()
            if token:
                values.append(int(token, 0) & 0xFF)
        return values

    def _parse_dstr_values(self, line: str) -> list[int]:
        """
        Parsi .dstr-direktiivin merkkijono.

        Poimii lainausmerkkien välisen tekstin, muuntaa jokaisen merkin
        sen ASCII-arvoksi (bitit 0–7) ja lisää automaattisesti
        null-terminaattorin (0x00) loppuun.

        Args:
            line: Direktiiviriivi, esim. '.dstr "Hello!"'

        Returns:
            Lista kokonaislukuja (ASCII-arvot + 0), kukin väliltä 0–255.

        Raises:
            ValueError: Jos lainausmerkkejä ei löydy.

        Example:
            >>> asm._parse_dstr_values('.dstr "Hi"')
            [72, 105, 0]
        """
        # Poista ".dstr" etuliite
        rest = line[5:].strip()
        # Etsi lainausmerkkien välinen teksti
        start = rest.find('"')
        end = rest.rfind('"')
        if start == -1 or start == end:
            raise ValueError(f"Invalid .dstr syntax (missing quotes): {line}")
        text = rest[start + 1 : end]
        return [ord(c) & 0xFF for c in text] + [0x00]

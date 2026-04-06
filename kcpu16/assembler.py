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
- Yksi käsky per rivi
- Labelit omalla rivillaan, päättyvät kaksoispisteeseen: "loop:"
- Operandit erotetaan välilyönnillä tai pilkulla
- Rekisterit: R0, R1, R2, R3, FP, SP (ei merkkisensitiiviä)
- Numeroliteraalit:
    - Desimaali:       42, 255, 65535
    - Heksadesimaali:  0xFF, 0xF800
    - Binääri:         0b1010, 0b11001100
    - Oktaali:         0o52
- Label-viittaukset suoraan operandina: "JUMP loop"
- Arkkitehtuurivakiot suoraan operandina: "LOAD R0, VRAM_START"
- Kommentit alkavat puolipisteella: "; tama on kommentti"
- Direktiivit:
  - .origin OSOITE (esim. .origin 0x0200)
  - .const NIMI, ARVO (esim. .const MAX_VAL, 100 — käyttäjän vakio)
  - .macro NIMI ... .endmacro (esim. .macro LOAD_MANY ... .endmacro)
  - .db TAVU, TAVU, ... (esim. .db 0x41, 0x42, 255)
  - .dstr "TEKSTI" tai .dstr 'TEKSTI' (esim. .dstr "Hello!", null-terminoitu;
              escape-sekvenssit: \\\\ \\" \\' \\n \\t \\0)
  - .at OSOITE (esim. .at 0xF800, siirtyy uuteen muistiosoitteeseen)
  - .expect_reg REK, ARVO (esim. .expect_reg R0, 120, testaukseen)
  - .expect_flag LIPPU, ARVO (esim. .expect_flag Z, 0, testaukseen)
  - .expect_mem OSOITE, ARVO (esim. .expect_mem 0x0300, 0xFF, testaukseen)
  - .expect_storage OSOITE, ARVO (tallennuslaiteen testaus)
  - .diskblock N (esim. .diskblock 0, tallenna konekieli levyblokkiin N)

SYMBOLINIMIEN YKSILÖLLISYYS:
-----------------------------
Labelien, käyttäjän vakioiden (.const) ja arkkitehtuurivakioiden nimet ovat
globaalisti uniikkeja. Kaikki kolme nimiavaruutta ovat yhteisessä kielessä,
joten sama nimi ei voi esiintyä missään kahdessa roolissa.
  - Label ei voi olla sama kuin arkkitehtuurivakio tai .const-vakio
  - .const-vakio ei voi olla sama kuin arkkitehtuurivakio tai label
  - Rekisterinimet (R0-R3, FP, SP) ovat aina varattuja

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

from .constants import ARCH_SYMBOLS, BOOT_RAM_START, STORAGE_BLOCK_SIZE, WORD_MASK
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

# Mnemoniikat jotka on korvattu [..] syntaksilla — suorat viittaukset hylätään
_DEPRECATED_MNEMONICS: frozenset[str] = frozenset(
    {
        "READ",
        "READ_IND",
        "READ_REL",
        "STORE_IND",
        "STORE_REL",
        "STOREI",
        "STOREI_IND",
        "STOREI_REL",
    }
)


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

    @property
    def disk_block(self) -> int | None:
        """Palattaa .diskblock-direktiivin blokkiindeksin tai None."""
        return self._disk_block

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
        self._disk_block: int | None = None
        # Pass 0: Makrojen ekspansointi, .origin ja .diskblock käsittely
        expanded_source, start_addr, user_constants = (
            self._pass0_expand_macros_and_origin(source, start_addr)
        )
        # Pass 1: Kerätään labelit (arkkitehtuurivakiot ja käyttäjän vakiot esitäytettynä)
        labels = self._pass1_collect_labels(expanded_source, start_addr, user_constants)
        # Pass 2: Tuotetaan konekieli segmentteina
        segments = self._pass2_emit(expanded_source, labels, start_addr)
        # Validoi koko jos .diskblock on maaratty
        if self._disk_block is not None:
            total = sum(len(w) for _, w in segments)
            if total > STORAGE_BLOCK_SIZE:
                raise ValueError(
                    f".diskblock: koodi on liian suuri blokkiin "
                    f"({total} sanaa, max {STORAGE_BLOCK_SIZE})"
                )
        return segments

    def _pass0_expand_macros_and_origin(
        self, source: str, start_addr: int
    ) -> tuple[str, int, dict[str, int]]:
        """
        Pass 0: Makrojen ekspansointi, .origin ja .const direktiivien käsittely.

        Ensin käsitellään .origin ja .const direktiivit, sitten makrot.
        .const-vakioista tarkistetaan syntaksi ja duplikaatit jo tässä.
        Törmäykset arkkitehtuurivakioihin ja labeleihin tarkistetaan pass 1:ssä.

        Args:
            source: Assembly-lahdekoodi
            start_addr: Oletusarvoinen aloitusosoite

        Returns:
            Tuple: (laajennettu_lähdekoodi, käytetty_aloitusosoite, käyttäjän_vakiot)
        """
        lines = source.splitlines()

        # 1. Etsi .origin direktiivi
        for line in lines:
            stripped = line.split(";", 1)[0].strip()
            sl = stripped.lower()
            # Täsmällinen tarkistus: direktiivi on joko yksin tai sen jälkeen tulee välilyönti
            # (estää .orgin-tyyppiset kirjoitusvirheet menemästä läpi hiljaa)
            is_origin = sl == ".origin" or sl.startswith(".origin ")
            is_org = sl == ".org" or sl.startswith(".org ")
            if is_origin or is_org:
                # Parse: ".origin 0x0200" -> 0x0200
                parts = stripped.split()
                if len(parts) > 1:
                    try:
                        start_addr = int(parts[1], 0) & WORD_MASK
                    except ValueError:
                        raise ValueError(f"Invalid .origin value: {parts[1]}")

        # 2. Kerää makrot ja .const-vakiot
        macros: dict[str, list[str]] = {}
        user_constants: dict[str, int] = {}
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

            # .const direktiivi: käyttäjän nimetty vakio
            if stripped.lower().startswith(".const"):
                rest = stripped[len(".const") :].strip().replace(",", " ")
                parts = rest.split()
                if len(parts) < 2:
                    raise ValueError(
                        f"Invalid .const syntax: {stripped!r}  "
                        f"(käyttö: .const NIMI, ARVO)"
                    )
                name = parts[0].upper()
                try:
                    value = int(parts[1], 0) & WORD_MASK
                except ValueError:
                    raise ValueError(f".const '{name}': virheellinen arvo {parts[1]!r}")
                if name in user_constants:
                    raise ValueError(f".const '{name}' on jo määritelty")
                user_constants[name] = value
                i += 1
                continue  # Ei lisata expanded_lines:iin

            # Etsi .diskblock direktiivi
            if stripped.lower().startswith(".diskblock"):
                parts = stripped.split()
                if len(parts) < 2:
                    raise ValueError(f"Invalid .diskblock syntax: {stripped}")
                try:
                    self._disk_block = int(parts[1], 0)
                except ValueError:
                    raise ValueError(f"Invalid .diskblock block number: {parts[1]}")
                i += 1
                continue  # Ei lisata expanded_lines:iin

            # Ohita .origin, .org, .macro ja .endmacro rivit tulosteesta
            sl = stripped.lower()
            if (
                sl == ".origin"
                or sl.startswith(".origin ")
                or sl == ".org"
                or sl.startswith(".org ")
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
        return expanded_source, start_addr, user_constants

    def _pass1_collect_labels(
        self, source: str, start_addr: int, user_constants: dict[str, int]
    ) -> dict[str, int]:
        """
        Pass 1: Kerataan labelit ja lasketaan niiden muistiosoitteet.

        Kaydaan lahdekoodi lapi ja kirjataan jokaisen labelin
        kohdalle tuleva osoite. Samalla lasketaan kaskyjen koot
        jotta osoitteet ovat oikein.

        Symboliavaruus on yhteinen kaikille kolmelle symboliteholле:
        arkkitehtuurivakiot (ARCH_SYMBOLS), käyttäjän vakiot (.const)
        ja labelit. Nimet ovat uniikkeja koko ohjelman laajuisesti.

        Args:
            source: Assembly-lahdekoodi
            start_addr: Aloitusosoite
            user_constants: Käyttäjän .const-vakiot nimeltä -> arvoksi

        Returns:
            Sanakirja: symbolin nimi -> arvo/osoite (kaikki kolme tyyppiä)

        Raises:
            ValueError: Jos nimi törmää toiseen symboliin tai rekisteriin
        """
        # Arkkitehtuurivakiot (vain luku, ei voi ylikirjoittaa)
        arch_sym: dict[str, int] = {
            name.upper(): val for name, val in ARCH_SYMBOLS.items()
        }
        # Rekisterinimet ovat aina varattuja
        reserved_reg: set[str] = set(REGISTER_TO_ID.keys())

        # Validoi käyttäjän vakiot: ei törmäyksiä arkkitehtuurivakioihin tai rekisterinimiin
        for name in user_constants:
            if name in arch_sym:
                raise ValueError(
                    f".const '{name}': nimi on jo arkkitehtuurivakio — "
                    f"valitse toinen nimi"
                )
            if name in reserved_reg:
                raise ValueError(
                    f".const '{name}': nimi on rekisterin nimi — "
                    f"valitse toinen nimi"
                )

        # Rakennetaan yhteinen symbolitaulukko: arch_sym + user_constants
        # (järjestyksellä ei ole väliä, koska nimet on jo validoitu unikeiksi)
        symbols: dict[str, int] = {}
        symbols.update(arch_sym)
        symbols.update(user_constants)

        addr = start_addr  # Nykyinen osoite (kasvaa kaskyjen mukana)

        for raw_line in source.splitlines():
            # Poista kommentit (puolipiste ja kaikki sen jalkeen)
            line = raw_line.split(";", 1)[0].strip()
            if not line:
                continue  # Tyhja rivi -> ohita

            # Onko tama label? (paattyy kaksoispisteeseen)
            if line.endswith(":"):
                label_name = line[:-1].strip().upper()
                # Tarkista ettei törmää mihinkään olemassa olevaan symboliin tai rekisteriin
                if label_name in arch_sym:
                    raise ValueError(
                        f"Label '{label_name}': nimi on jo arkkitehtuurivakio — "
                        f"valitse toinen nimi"
                    )
                if label_name in user_constants:
                    raise ValueError(
                        f"Label '{label_name}': nimi on jo .const-vakio — "
                        f"valitse toinen nimi"
                    )
                if label_name in reserved_reg:
                    raise ValueError(
                        f"Label '{label_name}': nimi on rekisterin nimi — "
                        f"valitse toinen nimi"
                    )
                if label_name in symbols:
                    raise ValueError(f"Label '{label_name}' on jo määritelty")
                # Tallenna labelin osoite yhdistettyyn symbolitaulukkoon
                symbols[label_name] = addr
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
            parts = line.replace(",", " ").split()
            mnemonic = parts[0].upper()

            if mnemonic in _DEPRECATED_MNEMONICS:
                raise ValueError(
                    f"Vanhentunut mnemoniikka '{mnemonic}' — käytä [..] syntaksia: "
                    f"LOAD reg, [osoite]  tai  STORE [osoite], reg/arvo"
                )
            if mnemonic == "STORE" and len(parts) >= 2 and not parts[1].startswith("["):
                raise ValueError(
                    f"STORE vaatii [..] osoitussyntaksin: STORE [osoite], reg/arvo"
                )

            # Hae opcode ja operandien maara
            opcode = MNEMONIC_TO_OPCODE.get(mnemonic)
            if opcode is None:
                raise ValueError(f"Unknown mnemonic: {mnemonic}")

            _, operand_count, _ = OPCODE_TABLE[opcode]
            # Kaskyn koko = 1 (opcode) + operandien maara
            addr += 1 + operand_count

        return symbols

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

            # .const direktiivit on jo käsitelty pass 0:ssa — ohita
            if line.lower().startswith(".const"):
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

            # ---------------------------------------------------------------
            # [..] syntaksi: LOAD reg, [expr]  ja  STORE [expr], src
            # ---------------------------------------------------------------

            # LOAD reg, [expr]  → READ / READ_IND / READ_REL
            if mnemonic == "LOAD" and len(parts) >= 3 and parts[2].startswith("["):
                reg_dst = self._parse_operand(parts[1], labels)
                mode = self._parse_bracket_expr(parts[2], labels)
                if mode[0] == "abs":
                    current_words += [MNEMONIC_TO_OPCODE["READ"], reg_dst, mode[1]]
                elif mode[0] == "ind":
                    current_words += [MNEMONIC_TO_OPCODE["READ_IND"], reg_dst, mode[1]]
                elif mode[0] == "rel":
                    current_words += [MNEMONIC_TO_OPCODE["READ_REL"], reg_dst, mode[2]]
                continue

            # STORE [expr], src  → STORE / STOREI / STORE_IND / STOREI_IND /
            #                       STORE_REL / STOREI_REL
            if mnemonic == "STORE" and len(parts) >= 3 and parts[1].startswith("["):
                mode = self._parse_bracket_expr(parts[1], labels)
                src_token = parts[2]
                src_is_reg = src_token.upper() in REGISTER_TO_ID
                if mode[0] == "abs":
                    addr = mode[1]
                    if src_is_reg:
                        current_words += [
                            MNEMONIC_TO_OPCODE["STORE"],
                            REGISTER_TO_ID[src_token.upper()],
                            addr,
                        ]
                    else:
                        imm = self._parse_operand(src_token, labels)
                        current_words += [MNEMONIC_TO_OPCODE["STOREI"], imm, addr]
                elif mode[0] == "ind":
                    reg_addr = mode[1]
                    if src_is_reg:
                        current_words += [
                            MNEMONIC_TO_OPCODE["STORE_IND"],
                            reg_addr,
                            REGISTER_TO_ID[src_token.upper()],
                        ]
                    else:
                        imm = self._parse_operand(src_token, labels)
                        current_words += [
                            MNEMONIC_TO_OPCODE["STOREI_IND"],
                            reg_addr,
                            imm,
                        ]
                elif mode[0] == "rel":
                    _base_reg, offset = mode[1], mode[2]
                    if src_is_reg:
                        current_words += [
                            MNEMONIC_TO_OPCODE["STORE_REL"],
                            REGISTER_TO_ID[src_token.upper()],
                            offset,
                        ]
                    else:
                        imm = self._parse_operand(src_token, labels)
                        current_words += [MNEMONIC_TO_OPCODE["STOREI_REL"], imm, offset]
                continue

            # ---------------------------------------------------------------

            if mnemonic in _DEPRECATED_MNEMONICS:
                raise ValueError(
                    f"Vanhentunut mnemoniikka '{mnemonic}' — käytä [..] syntaksia: "
                    f"LOAD reg, [osoite]  tai  STORE [osoite], reg/arvo"
                )
            if mnemonic == "STORE" and len(parts) >= 2 and not parts[1].startswith("["):
                raise ValueError(
                    f"STORE vaatii [..] osoitussyntaksin: STORE [osoite], reg/arvo"
                )

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

    def _parse_bracket_expr(self, token: str, labels: dict[str, int]) -> tuple:
        """Parsi hakasulkuinen [expr] osoitusmuoto.

        Tunnistetaan kolme muotoa:
            [reg]         → ('ind', reg_id)          -- epäsuora rekisteriviittaus
            [reg+offset]  → ('rel', reg_id, offset)  -- suhteellinen osoitus
            [addr]        → ('abs', addr)             -- absoluuttinen osoite

        Args:
            token:  Koko hakasulkuinen token, esim. "[R0]", "[FP+2]", "[0x0300]"
            labels: Tunnetut labelit ja arkkitehtuurivakiot

        Returns:
            Tuple: ('ind', reg_id), ('rel', reg_id, offset) tai ('abs', addr)
        """
        inner = token[1:-1].strip()

        # [reg+offset] muoto
        if "+" in inner:
            base_str, off_str = inner.split("+", 1)
            base_upper = base_str.strip().upper()
            if base_upper in REGISTER_TO_ID:
                reg_id = REGISTER_TO_ID[base_upper]
                offset = self._parse_operand(off_str.strip(), labels)
                return ("rel", reg_id, offset)

        # [reg] muoto
        if inner.upper() in REGISTER_TO_ID:
            return ("ind", REGISTER_TO_ID[inner.upper()])

        # [addr] muoto — absoluuttinen osoite tai label
        return ("abs", self._parse_operand(inner, labels))

    def _parse_operand(self, token: str, labels: dict[str, int]) -> int:
        """
        Parsi yksittainen operandi.

        Tunnistetaan tässä järjestyksessä:
        1. Rekisterinimet: R0, R1, R2, R3, FP, SP (case-insensitive)
        2. Labelit ja arkkitehtuurivakiot: loop, VRAM_START, jne.
        3. Numeroliteraalit:
           - Desimaali:       42, 255, 65535
           - Heksadesimaali:  0xFF, 0xF800
           - Binääri:         0b1010, 0b11001100
           - Oktaali:         0o52

        Args:
            token: Operandin teksti (esim. "R0", "loop", "42", "0xFF")
            labels: Tunnetut labelit ja osoitteet

        Returns:
            Numeerinen arvo operandille

        Raises:
            ValueError: Jos token ei ole rekisteri, label eikä tunnistettu luku

        Example:
            >>> asm._parse_operand("R0", {})
            0
            >>> asm._parse_operand("loop", {"LOOP": 0x0100})
            256
            >>> asm._parse_operand("0xFF", {})
            255
        """
        upper = token.upper()

        # Onko rekisteri?
        if upper in REGISTER_TO_ID:
            return REGISTER_TO_ID[upper]

        # Onko label tai arkkitehtuurivakio?
        if upper in labels:
            return labels[upper]

        # Numeroliteraali: tue 0x, 0b, 0o ja desimaali
        try:
            return int(upper, 0)
        except ValueError:
            raise ValueError(
                f"Tuntematon operandi: '{token}' " f"(ei rekisteri, label eikä luku)"
            )

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

        Tuetut lainausmerkit: "..." ja '...'
        Tuetut escape-sekvenssit:
            \\  → kenoviiva
            \"  → lainausmerkki (")
            \'  → heittomerkki (')
            \n  → rivinvaihto (0x0A)
            \t  → tabulaattori (0x09)
            \0  → nollatavu (0x00)

        Args:
            line: Direktiiviriivi, esim. '.dstr "Hello!"' tai ".dstr 'Hi'"

        Returns:
            Lista kokonaislukuja (ASCII-arvot + 0), kukin väliltä 0–255.

        Raises:
            ValueError: Jos lainausmerkkejä ei löydy tai syntaksi on virheellinen.

        Example:
            >>> asm._parse_dstr_values('.dstr "Hi"')
            [72, 105, 0]
            >>> asm._parse_dstr_values(".dstr 'Hi'")
            [72, 105, 0]
            >>> asm._parse_dstr_values('.dstr "say \\"hi\\""')
            [115, 97, 121, 32, 34, 104, 105, 34, 0]
        """
        rest = line[5:].strip()
        if not rest or rest[0] not in ('"', "'"):
            raise ValueError(f"Invalid .dstr syntax (missing quotes): {line}")

        quote_char = rest[0]
        chars: list[int] = []
        i = 1
        closed = False

        _escapes: dict[str, int] = {
            "\\": ord("\\"),
            '"': ord('"'),
            "'": ord("'"),
            "n": 0x0A,
            "t": 0x09,
            "0": 0x00,
        }

        while i < len(rest):
            c = rest[i]
            if c == "\\":
                if i + 1 >= len(rest):
                    raise ValueError(f"Invalid .dstr: unterminated escape in: {line}")
                esc = rest[i + 1]
                if esc not in _escapes:
                    raise ValueError(f"Unknown .dstr escape '\\{esc}' in: {line}")
                chars.append(_escapes[esc])
                i += 2
            elif c == quote_char:
                closed = True
                break
            else:
                chars.append(ord(c) & 0xFF)
                i += 1

        if not closed:
            raise ValueError(f"Invalid .dstr syntax (unterminated string): {line}")

        return chars + [0x00]

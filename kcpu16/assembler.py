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
- Arkkitehtuurivakiot suoraan operandina: "READ R0, VRAM_START"
- Kommentit alkavat puolipisteella: "; tama on kommentti"
- Direktiivit:
  - .origin OSOITE (esim. .origin 0x0200)
  - .const NIMI, ARVO (esim. .const MAX_VAL, 100 — käyttäjän vakio)
  - .macro NIMI ... .endmacro (esim. .macro LOAD_MANY ... .endmacro)
  - .db TAVU, TAVU, ... (esim. .db 0x41, 0x42, 255)
  - .dw SANA, SANA, ... (esim. .dw 100, -50, 0x1234 — kokonaiset 16-bittiset sanat)
  - .dstr "TEKSTI" tai .dstr 'TEKSTI' (esim. .dstr "Hello!", null-terminoitu;
              escape-sekvenssit: \\\\ \\" \\' \\n \\t \\0)
  - .at OSOITE (esim. .at 0xF800, siirtyy uuteen muistiosoitteeseen)
  - .expect_reg REK, ARVO (esim. .expect_reg R0, 120, testaukseen)
  - .expect_flag LIPPU, ARVO (esim. .expect_flag Z, 0, testaukseen)
  - .expect_mem OSOITE, ARVO (esim. .expect_mem 0x0300, 0xFF, testaukseen)
  - .expect_storage OSOITE, ARVO (tallennuslaiteen testaus)
  - .inject_key KOODI (esim. .inject_key 0x41, simuloi A-painallus; testaukseen)
  - .inject_key_release KOODI (esim. .inject_key_release 0x41, simuloi A-vapautus; testaukseen)
    - .diskblock N (esim. .diskblock 0, tallenna konekieli levyblokkiin N)
        - .state_text N, "TEKSTI" (liita tilaviestiteksti STATE N -kaskylle)
        - .state_text N, DELAY_SECS, "TEKSTI" (tilaviestin lisaksi suoritusviive)
    - .bootblock "LEVYKUVA", overwrite=0|1, boot=0|1 (bootsektoriksi kirjoitettava osuus)
    - .endbootblock (paattaa .bootblock-osuuden)
  - .include "TIEDOSTO" tai .include 'TIEDOSTO' (liitä toinen asm-tiedosto tähän
              kohtaan; polku suhteessa nykyiseen tiedostoon; silmukkasuojaus)

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
        READ  R0, 10
        READ  R1, 20
        READ  R2, 30
    .endmacro

    MSG:
        .dstr "Hello!"  ; 7 sanaa: H,e,l,l,o,!,0x00
    NUMS:
        .db 0x01, 0x02   ; 2 sanaa: 0x01, 0x02

    START:
        LOAD_MANY        ; Ekspandoi makroksi
        READ  R0, MSG    ; R0 = datan aloitusosoite
        JUMP  START
        HALT

    .at 0xF800           ; Seuraava data kirjoitetaan VRAMiin
    VRAM_DATA:
        .dstr "kCPU16"  ; Alustudata suoraan VRAMiin

Tuottaa konekielen osoitteesta 0x0200 eteenpäin.
VRAM_DATA-symboli osoittaa 0xF800.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .constants import ARCH_SYMBOLS, BOOT_RAM_START, STORAGE_BLOCK_SIZE, WORD_MASK
from .instruction import (
    OPCODE_TABLE,
    STATE_ID_COUNT,
    STATE_ID_MAX,
    STATE_OPCODE_BASE,
    is_deprecated_assembler_mnemonic,
    is_variable_length_mnemonic,
)


# =============================================================================
# REKISTERIEN KOODAUS
# Rekisterinimet -> numeerinen indeksi (kayta operandeissa)
# =============================================================================

REGISTER_TO_ID: dict[str, int] = {
    "R0": 0,  # Yleiskayttoinen rekisteri 0
    "R1": 1,  # Yleiskayttoinen rekisteri 1
    "R2": 2,  # Yleiskayttoinen rekisteri 2
    "R3": 3,  # Yleiskayttoinen rekisteri 3
    "R4": 4,  # Yleiskayttoinen rekisteri 4
    "R5": 5,  # Yleiskayttoinen rekisteri 5
    "R6": 6,  # Yleiskayttoinen rekisteri 6
    "R7": 7,  # Yleiskayttoinen rekisteri 7
    "R8": 8,  # Yleiskayttoinen rekisteri 8
    "R9": 9,  # Yleiskayttoinen rekisteri 9
    "R10": 10,  # Yleiskayttoinen rekisteri 10
    "R11": 11,  # Yleiskayttoinen rekisteri 11
    "R12": 12,  # Yleiskayttoinen rekisteri 12
    "R13": 13,  # Yleiskayttoinen rekisteri 13
    "R14": 14,  # Yleiskayttoinen rekisteri 14
    "R15": 15,  # Yleiskayttoinen rekisteri 15
    "FP": 16,  # Frame Pointer (indeksi 16)
    "SP": 17,  # Stack Pointer (indeksi 17)
}

# Kaanteinen hakutaulukko: mnemonic -> opcode
# Luodaan OPCODE_TABLE:sta kaantamalla avain-arvot
MNEMONIC_TO_OPCODE: dict[str, int] = {v[0]: k for k, v in OPCODE_TABLE.items()}


def _strip_comment_outside_quotes(raw: str) -> str:
    """Poista ';' kommentti vain, jos se on lainausmerkkien ulkopuolella."""
    in_quote: str | None = None
    escaped = False
    for idx, ch in enumerate(raw):
        if escaped:
            escaped = False
            continue
        if ch == "\\":
            escaped = True
            continue
        if in_quote is None:
            if ch in ('"', "'"):
                in_quote = ch
                continue
            if ch == ";":
                return raw[:idx]
            continue
        if ch == in_quote:
            in_quote = None
    return raw


@dataclass(slots=True, frozen=True)
class _ParsedLine:
    """Esiparsittu lähderivi - vältä redundanttia split/strip/lower toimintoa."""

    raw: str  # Alkuperäinen rivi
    stripped: str  # Kommentit poistettu, välilyönnit trimmattu
    lower: str  # stripped.lower()

    @staticmethod
    def parse(raw: str) -> "_ParsedLine":
        """Parsii lähdekoodi-rivin yksinkertaisesti."""
        stripped = _strip_comment_outside_quotes(raw).strip()
        return _ParsedLine(raw=raw, stripped=stripped, lower=stripped.lower())


def _parse_all_lines(source: str) -> list[_ParsedLine]:
    """Rakenna kaikki rivit ParsedLine-muotoon kerralla.Tämä vähentää moninkertaista split/strip/lower kutsua pass-metodeissa."""
    return [_ParsedLine.parse(line) for line in source.splitlines()]


@dataclass(slots=True, frozen=True)
class BootBlockDirective:
    """Bootblock-osuuden levykuva-asetukset."""

    disk_path: Path
    allow_overwrite: bool
    boot_after_write: bool


def _parse_bool_option(value: str, option_name: str) -> bool:
    """Parsi direktiivin totuusarvo-optio merkkijonosta."""
    normalized = value.strip().lower()
    truthy = {"1", "true", "yes", "on"}
    falsy = {"0", "false", "no", "off"}
    if normalized in truthy:
        return True
    if normalized in falsy:
        return False
    raise ValueError(
        f".bootblock: option '{option_name}' must be one of "
        f"{sorted(truthy | falsy)}, got {value!r}"
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
        ...     READ R0, 42
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

    @property
    def source_map(self) -> list[tuple[str, int]]:
        """Palattaa listauksen (lahderivi, abs_osoite) assemble()-kutsun jalkeen."""
        return self._source_map

    @property
    def labels(self) -> dict[str, int]:
        """Palattaa label -> osoite -hakutaulukon assemble()-kutsun jalkeen."""
        return self._labels

    @property
    def included_files(self) -> tuple[Path, ...]:
        """Palauttaa assemble()-kutsussa laajennetut .include-tiedostot."""
        return tuple(self._included_files)

    @property
    def bootblock_directive(self) -> BootBlockDirective | None:
        """Palauttaa .bootblock-direktiivin asetukset tai None."""
        return self._bootblock_directive

    @property
    def state_texts(self) -> dict[int, str]:
        """Palauta .state_text-direktiiveilla määritetty tilaviestikartta."""
        return dict(self._state_texts)

    @property
    def state_delays(self) -> dict[int, int]:
        """Palauta .state_text-direktiiveilla määritetty tilaviivekartta (sekunteina)."""
        return dict(self._state_delays)

    @property
    def has_bootblock(self) -> bool:
        """Kertoo onko lähteessä .bootblock-osuus."""
        return self._bootblock_directive is not None and bool(self._bootblock_source)

    def assemble(
        self,
        source: str,
        start_addr: int = BOOT_RAM_START,
        source_path: Path | None = None,
    ) -> list[tuple[int, list[int]]]:
        """
        Assembloi lahdekoodi konekieleksi segmentteina.

        Args:
            source: Assembly-lahdekoodi merkkijonona
            start_addr: Ohjelman aloitusosoite muistissa (oletus: 0x0100)
            source_path: Lahdetiedoston polku (tarvitaan .include-direktiiville)

        Returns:
            Lista (aloitusosoite, sanat) -pareista. Yleensa yksi segmentti,
            mutta .at-direktiivilla voi olla useampia.

        Raises:
            ValueError: Jos mnemonic on tuntematon tai label on duplikaatti

        Example:
            >>> asm.assemble("READ R0, 10\\nHALT", start_addr=0x0200)
            [(512, [1, 0, 10, 68])]
        """
        self._disk_block: int | None = None
        self._bootblock_directive: BootBlockDirective | None = None
        self._bootblock_source: str | None = None
        self._state_texts: dict[int, str] = {}
        self._state_delays: dict[int, int] = {}
        self._source_map: list[tuple[str, int]] = []  # (lahderivi, abs_osoite)
        self._labels: dict[str, int] = {}
        self._included_files: list[Path] = []
        self._current_lineno: int = 0  # Nykyinen rivinumero virheilmoituksia varten
        self._current_line: str = ""  # Nykyinen lähderivi virheilmoituksia varten
        source = self._extract_bootblock_section(source, source_path)
        # Esikäsittely: laajenna .include-direktiivit rekursiivisesti
        base_dir = source_path.parent if source_path is not None else None
        source = self._expand_includes(
            source,
            base_dir,
            frozenset(),
            included_paths=self._included_files,
        )
        try:
            # Pass 0: Makrojen ekspansointi, .origin ja .diskblock käsittely
            expanded_source, start_addr, user_constants = (
                self._pass0_expand_macros_and_origin(source, start_addr)
            )
            # Pass 1: Kerätään labelit (arkkitehtuurivakiot ja käyttäjän vakiot esitäytettynä)
            labels = self._pass1_collect_labels(
                expanded_source, start_addr, user_constants
            )
            self._labels = labels
            # Pass 2: Tuotetaan konekieli segmentteina
            segments = self._pass2_emit(expanded_source, labels, start_addr)
        except ValueError as e:
            msg = str(e)
            if self._current_lineno > 0 and not msg.startswith("Rivi "):
                raise ValueError(
                    f"Rivi {self._current_lineno}: {self._current_line.strip()!r}\n  {msg}"
                ) from e
            raise
        # Validoi koko jos .diskblock on maaratty
        if self._disk_block is not None:
            total = sum(len(w) for _, w in segments)
            if total > STORAGE_BLOCK_SIZE:
                raise ValueError(
                    f".diskblock: koodi on liian suuri blokkiin "
                    f"({total} sanaa, max {STORAGE_BLOCK_SIZE})"
                )
        # Tarkista ettei segmentit mene päällekkäin
        self._check_segment_overlaps(segments)
        return segments

    def build_boot_block_words(
        self, source_path: Path | None = None
    ) -> tuple[list[int], int]:
        """Assembloi .bootblock-osuuden levykuvan bootsektoriksi.

        Returns:
            (boot_block_words, used_word_count)
        """
        if self._bootblock_directive is None or not self._bootblock_source:
            raise ValueError(".bootblock: no bootblock section defined")

        boot_asm = Assembler()
        segments = boot_asm.assemble(
            self._bootblock_source,
            start_addr=BOOT_RAM_START,
            source_path=source_path,
        )

        boot_words = [0] * STORAGE_BLOCK_SIZE
        used_words = 0
        boot_end = BOOT_RAM_START + STORAGE_BLOCK_SIZE - 1

        for seg_start, words in segments:
            if not words:
                continue
            seg_end = seg_start + len(words) - 1
            if seg_start < BOOT_RAM_START or seg_end > boot_end:
                raise ValueError(
                    ".bootblock: section must assemble entirely into boot area "
                    f"0x{BOOT_RAM_START:04X}-0x{boot_end:04X}, got "
                    f"0x{seg_start:04X}-0x{seg_end:04X}"
                )
            offset = seg_start - BOOT_RAM_START
            boot_words[offset : offset + len(words)] = [w & WORD_MASK for w in words]
            used_words += len(words)

        return boot_words, used_words

    def _extract_bootblock_section(self, source: str, source_path: Path | None) -> str:
        """Irrota .bootblock-osuuden metatiedot normaalista ohjelmasta.

        .bootblock-osuus assembloidaan erikseen levykuvan bootsektoriksi eikä sitä
        sisällytetä tavalliseen RAM-ohjelmaan. Tällöin bootloader voi hypätä
        suoraan varsinaisen ohjelman entrypointiin ilman, että sama bootkoodi
        on myös RAM-ohjelman alussa.
        """
        lines = source.splitlines()
        output_lines: list[str] = []
        boot_lines: list[str] = []
        in_bootblock = False

        for lineno, line in enumerate(lines, start=1):
            self._current_lineno = lineno
            self._current_line = line
            stripped = _strip_comment_outside_quotes(line).strip()
            lower = stripped.lower()

            if lower == ".endbootblock" or lower.startswith(".endbootblock "):
                if not in_bootblock:
                    raise ValueError(".endbootblock without matching .bootblock")
                in_bootblock = False
                continue

            if lower == ".bootblock" or lower.startswith(".bootblock "):
                if self._bootblock_directive is not None:
                    raise ValueError("Only one .bootblock section is allowed")
                self._bootblock_directive = self._parse_bootblock_directive(
                    stripped, source_path
                )
                in_bootblock = True
                continue

            if in_bootblock:
                boot_lines.append(line)
                continue
            output_lines.append(line)

        if in_bootblock:
            raise ValueError(".bootblock section is missing matching .endbootblock")
        if self._bootblock_directive is not None:
            boot_source = "\n".join(boot_lines).strip()
            if not boot_source:
                raise ValueError(".bootblock section is empty")
            self._bootblock_source = boot_source

        return "\n".join(output_lines)

    def _parse_bootblock_directive(
        self, directive_line: str, source_path: Path | None
    ) -> BootBlockDirective:
        """Parsi .bootblock-direktiivin asetukset."""
        rest = directive_line[len(".bootblock") :].strip()
        if len(rest) < 2 or rest[0] not in ('"', "'"):
            raise ValueError(
                ".bootblock: disk image path must be quoted, for example "
                '.bootblock "storage/boot.dsk", overwrite=1, boot=0'
            )

        quote = rest[0]
        end = rest.find(quote, 1)
        if end == -1:
            raise ValueError(".bootblock: missing closing quote for disk image path")

        filename = rest[1:end].strip()
        if not filename:
            raise ValueError(".bootblock: disk image path cannot be empty")

        option_text = rest[end + 1 :].strip()
        if option_text.startswith(","):
            option_text = option_text[1:].strip()

        allow_overwrite = False
        boot_after_write = False
        if option_text:
            normalized = option_text.replace(",", " ")
            for token in normalized.split():
                if "=" not in token:
                    raise ValueError(
                        f".bootblock: options must use key=value syntax (got {token!r})"
                    )
                key, value = token.split("=", 1)
                key = key.strip().lower()
                value = value.strip()
                if key == "overwrite":
                    allow_overwrite = _parse_bool_option(value, key)
                elif key == "boot":
                    boot_after_write = _parse_bool_option(value, key)
                else:
                    raise ValueError(f".bootblock: unknown option {key!r}")

        disk_path = Path(filename)
        if not disk_path.is_absolute() and source_path is not None:
            disk_path = source_path.parent / disk_path
        disk_path = disk_path.resolve()

        return BootBlockDirective(
            disk_path=disk_path,
            allow_overwrite=allow_overwrite,
            boot_after_write=boot_after_write,
        )

    @staticmethod
    def _collect_defined_symbols(source: str) -> set[str]:
        """
        Kerää lähdekoodi-merkkijonosta kaikki siinä määritellyt symbolit:
        makrojen nimet (.macro), käyttäjän vakioiden nimet (.const) ja labelit.

        Tätä käytetään .include-konfliktien ennakotarkistukseen: ennen kuin
        liitettävä tiedosto lisätään, tarkistetaan etteivät sen symbolit
        törmää jo tiedettyihin symboleihin.

        Args:
            source: Assembly-lähdekoodi merkkijonona

        Returns:
            Joukko (set) symboleita isokirjaimisina merkkijonoina
        """
        symbols: set[str] = set()
        for raw_line in source.splitlines():
            line = _strip_comment_outside_quotes(raw_line).strip()
            if not line:
                continue
            sl = line.lower()
            # Makron nimi
            if sl.startswith(".macro"):
                parts = line.split()
                if len(parts) >= 2:
                    symbols.add(parts[1].upper())
            # .const-vakion nimi
            elif sl.startswith(".const"):
                rest = line[len(".const") :].strip().replace(",", " ")
                parts = rest.split()
                if parts:
                    symbols.add(parts[0].upper())
            # Label (päättyy kaksoispisteeseen)
            elif line.endswith(":"):
                label = line[:-1].strip()
                if label:
                    symbols.add(label.upper())
        return symbols

    @staticmethod
    def _expand_includes(
        source: str,
        base_dir: Path | None,
        include_stack: frozenset[Path],
        known_symbols: set[str] | None = None,
        included_paths: list[Path] | None = None,
    ) -> str:
        """
        Laajenna .include-direktiivit rekursiivisesti ennen kaantamista.

        Korvaa jokaisen '.include "tiedosto.asm"' -rivin tiedoston sisallolla.
        Silmukkasuojaus: jos sama tiedosto on jo includeketjussa, heitetaan virhe.
        Symbolikonfliktisuojaus: jos liitettava tiedosto maarittaa jo tunnetun
        symbolin (label, .const tai .macro), heitetaan virhe ja lopetetaan kaantaminen.

        Args:
            source: Assembly-lahdekoodi
            base_dir: Hakemisto josta includet haetaan (tai None jos ei tiedostopolkua)
            include_stack: Nykyinen include-ketju (silmukoiden havaitsemiseen)
            known_symbols: Yhteinen mutaabeli joukko jo maaritellyista symboleista
                           (None = luodaan tama kutsuvaiheessa)

        Returns:
            Laajennettu lahdekoodi merkkijonona

        Raises:
            ValueError: Syklistä includea, puuttuvaa tiedostoa tai symbolitormaysta havaitessa
        """
        if known_symbols is None:
            # Juuri-taso: keraa ensin paatiedoston omat symbolit
            known_symbols = Assembler._collect_defined_symbols(source)

        result_lines: list[str] = []
        for raw_line in source.splitlines():
            stripped = _strip_comment_outside_quotes(raw_line).strip()
            sl = stripped.lower()
            if sl.startswith(".include"):
                # Parsi tiedostonimi: .include "nimi.asm" tai .include 'nimi.asm'
                rest = stripped[len(".include") :].strip()
                if len(rest) < 2 or rest[0] not in ('"', "'"):
                    raise ValueError(
                        f".include: puuttuvat lainausmerkit tai nimi: {stripped!r}"
                    )
                quote = rest[0]
                end = rest.find(quote, 1)
                if end == -1:
                    raise ValueError(
                        f".include: sulkematon lainausmerkki: {stripped!r}"
                    )
                filename = rest[1:end]
                if not filename:
                    raise ValueError(f".include: tiedostonimi on tyhjä: {stripped!r}")

                # Muodosta absoluuttinen polku
                if base_dir is not None:
                    inc_path = (base_dir / filename).resolve()
                else:
                    inc_path = Path(filename).resolve()

                # Silmukkasuojaus
                if inc_path in include_stack:
                    raise ValueError(
                        f".include: syklinen include havaittu: '{inc_path}' "
                        f"on jo includeketjussa"
                    )

                # Lue tiedosto
                if not inc_path.exists():
                    raise ValueError(f".include: tiedostoa ei löydy: '{inc_path}'")
                inc_source = inc_path.read_text(encoding="utf-8")
                if included_paths is not None and inc_path not in included_paths:
                    included_paths.append(inc_path)

                # Rekursiivinen laajennus liitettavaan tiedostoon (kayttaa samaa
                # known_symbols-joukkoa, joten myos sen alaincludet tarkistetaan)
                new_stack = include_stack | {inc_path}
                # Tarkista symbolitormays ennen laajennusta
                # (laajennetaan ensin rekursiivisesti, jotta saadaan myos
                # alaincludejen symbolit tarkistettua)
                inc_expanded = Assembler._expand_includes(
                    inc_source,
                    inc_path.parent,
                    new_stack,
                    known_symbols=None,
                    included_paths=included_paths,
                )
                # Keraa kaikki symbolit laajennetusta sisallosta (sis. alaincludet)
                inc_symbols = Assembler._collect_defined_symbols(inc_expanded)
                conflicts = inc_symbols & known_symbols
                if conflicts:
                    names = ", ".join(sorted(conflicts))
                    raise ValueError(
                        f".include '{inc_path.name}': tiedosto maarittaa jo "
                        f"tunnetun symbolin: {names}"
                    )
                # Lisaa liitettavan tiedoston symbolit tunnettuihin
                known_symbols.update(inc_symbols)

                result_lines.extend(inc_expanded.splitlines())
            else:
                result_lines.append(raw_line)
        return "\n".join(result_lines)

    @staticmethod
    def _check_segment_overlaps(segments: list[tuple[int, list[int]]]) -> None:
        """
        Tarkista ettei segmentit mene päällekkäin muistissa (optimoitu O(n log n)).

        Algoritmi: lajittele segmentit alkuosoitteen mukaan, tarkista lineaarisesti
        että jokaisen segmentin loppu ei ylety seuraavan segmentin alkuun.

        Args:
            segments: Lista (aloitusosoite, sanat) -pareista

        Raises:
            ValueError: Jos kaksi segmenttia kayttaa samaa muistiosoitetta
        """
        ranges: list[tuple[int, int, int]] = [
            (start, start + len(words) - 1, idx)
            for idx, (start, words) in enumerate(segments)
            if words
        ]
        # Lajittele segmentit alkuosoitteen perusteella (O(n log n))
        ranges.sort(key=lambda x: x[0])
        # Tarkista lineaarisesti: jos a_end >= b_start, osuma löytyi (O(n))
        for i in range(len(ranges) - 1):
            a_start, a_end, a_idx = ranges[i]
            b_start, b_end, b_idx = ranges[i + 1]
            if a_end >= b_start:
                raise ValueError(
                    f"Segmentit {a_idx} ja {b_idx} menevät päällekkäin muistissa: "
                    f"0x{a_start:04X}–0x{a_end:04X} ja "
                    f"0x{b_start:04X}–0x{b_end:04X}"
                )

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
        for lineno, line in enumerate(lines, start=1):
            self._current_lineno = lineno
            self._current_line = line
            stripped = _strip_comment_outside_quotes(line).strip()
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
            self._current_lineno = i + 1
            self._current_line = line
            stripped = _strip_comment_outside_quotes(line).strip()

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
                    macro_stripped = _strip_comment_outside_quotes(macro_line).strip()

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

            # .state_text-direktiivi (UI-tilaviestit)
            if self._is_state_text_directive(stripped):
                state_id, delay_secs, message = self._parse_state_text_directive(stripped)
                if state_id not in self._state_texts and len(self._state_texts) >= STATE_ID_COUNT:
                    raise ValueError(
                        f".state_text supports at most {STATE_ID_COUNT} vaihtoehtoa "
                        f"(id 0..{STATE_ID_MAX})"
                    )
                self._state_texts[state_id] = message
                self._state_delays[state_id] = delay_secs
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
                    f".const '{name}': nimi on rekisterin nimi — valitse toinen nimi"
                )

        # Rakennetaan yhteinen symbolitaulukko: arch_sym + user_constants
        # (järjestyksellä ei ole väliä, koska nimet on jo validoitu unikeiksi)
        symbols: dict[str, int] = {}
        symbols.update(arch_sym)
        symbols.update(user_constants)

        addr = start_addr  # Nykyinen osoite (kasvaa kaskyjen mukana)

        for lineno, raw_line in enumerate(source.splitlines(), start=1):
            self._current_lineno = lineno
            self._current_line = raw_line
            # Poista kommentit (puolipiste ja kaikki sen jalkeen)
            line = _strip_comment_outside_quotes(raw_line).strip()
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

            # .dw direktiivi: tallenna kokonaisia 16-bittisiä sanoja muistiin
            if line.lower().startswith(".dw"):
                addr += len(self._parse_dw_values(line))
                continue

            # .db direktiivi: tallenna raakoja tavuja muistiin
            if line.lower().startswith(".db"):
                addr += len(self._parse_db_values(line))
                continue

            # .dstr direktiivi: tallenna null-terminoitu merkkijono muistiin
            if line.lower().startswith(".dstr"):
                addr += len(self._parse_dstr_values(line))
                continue

            # .state_text-direktiivi: pass0 käsittelee, ei tuota koodia
            if self._is_state_text_directive(line):
                continue

            # .expect_*-direktiivit: ainoastaan testaukseen, ei tuota koodia
            if line.lower().startswith(".expect_"):
                continue

            # .inject_key*-direktiivit: testaukseen, ei tuota koodia
            if line.lower().startswith(".inject_key"):
                continue

            # Muuten tama on kasky - laske sen koko
            # "ADD R0, R1" -> ["ADD", "R0", "R1"]
            parts = line.replace(",", " ").split()
            mnemonic = parts[0].upper()

            if is_deprecated_assembler_mnemonic(mnemonic):
                raise ValueError(
                    f"Vanhentunut mnemoniikka '{mnemonic}' — käytä [..] syntaksia: "
                    f"READ reg, [osoite]  tai  STORE [osoite], reg/arvo"
                )
            if mnemonic == "LOAD":
                raise ValueError(
                    "Mnemoniikka 'LOAD' ei ole sallittu assembler-koodissa — "
                    "käytä 'READ' sen sijaan: READ reg, arvo  tai  READ reg, [osoite]"
                )
            if mnemonic == "STORE" and len(parts) >= 2 and not parts[1].startswith("["):
                raise ValueError(
                    "STORE vaatii [..] osoitussyntaksin: STORE [osoite], reg/arvo"
                )

            if mnemonic == "STATE":
                if len(parts) != 2:
                    raise ValueError(
                        f"STATE vaatii yhden operandin: STATE <0..{STATE_ID_MAX}>"
                    )
                state_id = self._parse_operand(parts[1], symbols)
                if state_id < 0 or state_id > STATE_ID_MAX:
                    raise ValueError(
                        f"STATE-id:n on oltava valilla 0..{STATE_ID_MAX}"
                    )
                addr += 1
                continue

            # Hae opcode ja operandien maara
            opcode = MNEMONIC_TO_OPCODE.get(mnemonic)
            if opcode is None:
                raise ValueError(f"Unknown mnemonic: {mnemonic}")

            _, operand_count, _ = OPCODE_TABLE[opcode]
            # Erityiskasky: JMPI/CALLI — muuttuvanmittainen
            # Rakenne: opcode + reg + count + kohteet
            if is_variable_length_mnemonic(mnemonic):
                n_targets = (
                    len(parts) - 2
                )  # kaikki osat paitsi mnemoniikka ja rekisteri
                addr += 3 + n_targets
            else:
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
        self._source_map = []

        for lineno, raw_line in enumerate(source.splitlines(), start=1):
            self._current_lineno = lineno
            self._current_line = raw_line
            # Poista kommentit
            line = _strip_comment_outside_quotes(raw_line).strip()

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

            # .dw direktiivi: emittoi kokonaisia 16-bittisiä sanoja
            if line.lower().startswith(".dw"):
                self._source_map.append(
                    (raw_line.strip(), current_start + len(current_words))
                )
                current_words.extend(self._parse_dw_values(line))
                continue

            # .db direktiivi: emittoi raakoja tavuja
            if line.lower().startswith(".db"):
                self._source_map.append(
                    (raw_line.strip(), current_start + len(current_words))
                )
                current_words.extend(self._parse_db_values(line))
                continue

            # .dstr direktiivi: emittoi null-terminoitu merkkijono
            if line.lower().startswith(".dstr"):
                self._source_map.append(
                    (raw_line.strip(), current_start + len(current_words))
                )
                current_words.extend(self._parse_dstr_values(line))
                continue

            # .state_text-direktiivi: pass0 käsittelee, ei tuota koodia
            if self._is_state_text_directive(line):
                continue

            # .expect_*-direktiivit: testaukseen, ei tuota koodia
            if line.lower().startswith(".expect_"):
                continue

            # .inject_key*-direktiivit: testaukseen, ei tuota koodia
            if line.lower().startswith(".inject_key"):
                continue

            # Parsi kasky: "ADD R0, R1" -> ["ADD", "R0", "R1"]
            parts = line.replace(",", " ").split()
            mnemonic = parts[0].upper()

            # ---------------------------------------------------------------
            # [..] syntaksi: LOAD reg, [expr]  ja  STORE [expr], src
            # ---------------------------------------------------------------

            # READ reg, [expr]  → READ / READ_IND / READ_REL
            if mnemonic == "READ" and len(parts) >= 3 and parts[2].startswith("["):
                self._source_map.append(
                    (raw_line.strip(), current_start + len(current_words))
                )
                reg_dst = self._parse_operand(parts[1], labels)
                mode = self._parse_bracket_expr(parts[2], labels)
                if mode[0] == "abs":
                    current_words += [MNEMONIC_TO_OPCODE["READ"], reg_dst, mode[1]]
                elif mode[0] == "ind":
                    current_words += [MNEMONIC_TO_OPCODE["READ_IND"], reg_dst, mode[1]]
                elif mode[0] == "rel":
                    current_words += [MNEMONIC_TO_OPCODE["READ_REL"], reg_dst, mode[2]]
                continue

            # READ reg, arvo  → LOAD machine instruction (immediate/label load)
            if mnemonic == "READ":
                if len(parts) < 3:
                    raise ValueError(
                        "READ vaatii kaksi operandia: READ reg, arvo  tai  READ reg, [osoite]"
                    )
                self._source_map.append(
                    (raw_line.strip(), current_start + len(current_words))
                )
                reg_dst = self._parse_operand(parts[1], labels)
                imm = self._parse_operand(parts[2], labels)
                current_words += [MNEMONIC_TO_OPCODE["LOAD"], reg_dst, imm]
                continue

            # STORE [expr], src  → STORE / STOREI / STORE_IND / STOREI_IND /
            #                       STORE_REL / STOREI_REL
            if mnemonic == "STORE" and len(parts) >= 3 and parts[1].startswith("["):
                self._source_map.append(
                    (raw_line.strip(), current_start + len(current_words))
                )
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

            if is_deprecated_assembler_mnemonic(mnemonic):
                raise ValueError(
                    f"Vanhentunut mnemoniikka '{mnemonic}' — käytä [..] syntaksia: "
                    f"READ reg, [osoite]  tai  STORE [osoite], reg/arvo"
                )
            if mnemonic == "LOAD":
                raise ValueError(
                    "Mnemoniikka 'LOAD' ei ole sallittu assembler-koodissa — "
                    "käytä 'READ' sen sijaan: READ reg, arvo  tai  READ reg, [osoite]"
                )
            if mnemonic == "STORE" and len(parts) >= 2 and not parts[1].startswith("["):
                raise ValueError(
                    "STORE vaatii [..] osoitussyntaksin: STORE [osoite], reg/arvo"
                )

            # 1-sanan STATE-käsky: STATE <id>, missä id on 0..63.
            if mnemonic == "STATE":
                if len(parts) != 2:
                    raise ValueError(
                        f"STATE vaatii yhden operandin: STATE <0..{STATE_ID_MAX}>"
                    )
                state_id = self._parse_operand(parts[1], labels)
                if state_id < 0 or state_id > STATE_ID_MAX:
                    raise ValueError(
                        f"STATE-id:n on oltava valilla 0..{STATE_ID_MAX}"
                    )
                self._source_map.append(
                    (raw_line.strip(), current_start + len(current_words))
                )
                current_words.append((STATE_OPCODE_BASE | state_id) & WORD_MASK)
                continue

            # Hae opcode
            opcode = MNEMONIC_TO_OPCODE.get(mnemonic)
            if opcode is None:
                raise ValueError(f"Unknown mnemonic: {mnemonic}")

            # Erityiskasky: JMPI/CALLI — muuttuvanmittainen indeksoitu hyppy/kutsu
            # Syntaksi:  JMPI reg, kohde0, kohde1, ...
            # Koodaus:   opcode | reg_id | count | addr[0] | ... | addr[count-1]
            if is_variable_length_mnemonic(mnemonic):
                self._source_map.append(
                    (raw_line.strip(), current_start + len(current_words))
                )
                reg_id = self._parse_operand(parts[1], labels)
                targets = [self._parse_operand(t, labels) for t in parts[2:]]
                current_words.append(opcode)
                current_words.append(reg_id)
                current_words.append(len(targets))
                current_words.extend(targets)
                continue

            # Lisaa opcode tulosteeseen
            self._source_map.append(
                (raw_line.strip(), current_start + len(current_words))
            )
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
                f"Tuntematon operandi: '{token}' (ei rekisteri, label eikä luku)"
            )

    def _parse_dw_values(self, line: str) -> list[int]:
        """
        Parsi .dw-direktiivin arvot.

        Hyväksyy pilkulla erotetun listan 16-bittisiä sanoja (desimaali, hex tai binääri).
        Negatiiviset arvot muunnetaan 2-komplementiksi (& 0xFFFF).

        Args:
            line: Direktiiviriivi, esim. ".dw 100, -50, 0x1234"

        Returns:
            Lista kokonaislukuja, kukin väliltä 0–65535.

        Example:
            >>> asm._parse_dw_values(".dw 100, -50")
            [100, 65486]
        """
        # Poista ".dw" etuliite
        rest = line[3:].strip()
        if not rest:
            return []
        values = []
        for token in rest.split(","):
            token = token.strip()
            if token:
                values.append(int(token, 0) & 0xFFFF)
        return values

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
        chars = self._parse_quoted_text_bytes(rest, ".dstr")
        return chars + [0x00]

    @staticmethod
    def _is_state_text_directive(line: str) -> bool:
        """Tunnista .state_text-direktiivi."""
        ll = line.lower().lstrip()
        return ll.startswith(".state_text")

    def _parse_state_text_directive(self, line: str) -> tuple[int, int, str]:
        """Parsi .state_text-direktiivi.

        Sallitut muodot:
          - .state_text N, "teksti"
          - .state_text N, DELAY_SECS, "teksti"
        """
        stripped = line.strip()
        lower = stripped.lower()
        if not lower.startswith(".state_text"):
            raise ValueError(f"Invalid state text directive: {line!r}")
        rest = stripped[len(".state_text") :].strip()

        if not rest:
            raise ValueError("Invalid .state_text syntax: missing id and text")

        comma = rest.find(",")
        if comma < 0:
            raise ValueError("Invalid .state_text syntax: expected comma")

        id_token = rest[:comma].strip()
        after_id = rest[comma + 1 :].strip()
        if not id_token:
            raise ValueError("Invalid .state_text syntax: missing state id")
        if not after_id:
            raise ValueError("Invalid .state_text syntax: missing text")

        try:
            state_id = int(id_token, 0)
        except ValueError:
            raise ValueError(f"Invalid .state_text state id: {id_token!r}")
        if state_id < 0 or state_id > STATE_ID_MAX:
            raise ValueError(
                f".state_text id must be in range 0..{STATE_ID_MAX}"
            )

        delay_secs = 0
        text_token = after_id
        if after_id and after_id[0] not in ('"', "'"):
            comma2 = after_id.find(",")
            if comma2 < 0:
                raise ValueError(
                    "Invalid .state_text syntax: expected '.state_text N, \"TEXT\"' "
                    "or '.state_text N, DELAY, \"TEXT\"'"
                )
            delay_token = after_id[:comma2].strip()
            text_token = after_id[comma2 + 1 :].strip()
            if not delay_token:
                raise ValueError("Invalid .state_text syntax: missing delay")
            try:
                delay_secs = int(delay_token, 0)
            except ValueError:
                raise ValueError(f"Invalid .state_text delay: {delay_token!r}")
            if delay_secs < 0:
                raise ValueError(".state_text delay must be >= 0")

        text_bytes = self._parse_quoted_text_bytes(text_token, ".state_text")
        return state_id, delay_secs, "".join(chr(b) for b in text_bytes)

    def _parse_quoted_text_bytes(self, text: str, directive_name: str) -> list[int]:
        """Parsi lainausmerkkien sisältö tavuiksi (escape-tuella)."""
        if not text or text[0] not in ('"', "'"):
            raise ValueError(f"Invalid {directive_name} syntax (missing quotes): {text}")

        quote_char = text[0]
        chars: list[int] = []
        i = 1
        closed = False

        escapes: dict[str, int] = {
            "\\": ord("\\"),
            '"': ord('"'),
            "'": ord("'"),
            "n": 0x0A,
            "t": 0x09,
            "0": 0x00,
        }

        while i < len(text):
            c = text[i]
            if c == "\\":
                if i + 1 >= len(text):
                    raise ValueError(
                        f"Invalid {directive_name}: unterminated escape in: {text}"
                    )
                esc = text[i + 1]
                if esc not in escapes:
                    raise ValueError(
                        f"Unknown {directive_name} escape '\\{esc}' in: {text}"
                    )
                chars.append(escapes[esc])
                i += 2
                continue

            if c == quote_char:
                closed = True
                i += 1
                break

            chars.append(ord(c) & 0xFF)
            i += 1

        if not closed:
            raise ValueError(f"Invalid {directive_name} syntax (unterminated string): {text}")

        if text[i:].strip():
            raise ValueError(f"Invalid {directive_name} syntax (trailing tokens): {text}")

        return chars

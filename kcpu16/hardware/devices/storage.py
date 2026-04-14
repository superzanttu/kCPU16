"""
Blokkipohjainen tallennuslaite kCPU16-emulaattorille.

Simuloi yksinkertaista levylaitetta (kuten kovalevy tai flash-muisti).
Kaytossa DREAD/DWRITE-kaskyilla ja boot-prosessissa.

LAITERAKENNE:
--------------
Tallennuslaite koostuu blokeista (sektoreita):
- Blokin koko: 256 sanaa (oletus)
- Blokkien maara: 256 (oletus)
- Kokonaiskapasiteetti: 65536 sanaa = 128 KB

OSOITUSTAVAT:
--------------
1. Sanaosoitus (word addressing):
   - DREAD/DWRITE kayttaa sanaosoitetta 0x0000-0xFFFF
   - Sisaisesti muunnetaan blokki-indeksiksi + offset

2. Blokkiosoitus (block addressing):
   - read_block() ja write_block() lukevat/kirjoittavat kokonaisia sektoreita
   - Kaytetaan boot-prosessissa (lue sektori 0)

BOOT-PROSESSI:
--------------
Kaynnistyksessa CPU lukee tallennuslaitteen sektorin 0 (256 sanaa)
ja kopioi sen RAM-osoitteisiin $0100-$01FF. Tama on "bootloader".

Tallennuslaitteen rakenne:
    0x0000 - 0x00FF: Master Boot Record / Bootloader
    0x0100 - 0xFFFF: Vapaa tallennustila
"""

import json
import struct
import zlib
from dataclasses import dataclass, field
from pathlib import Path

from ...constants import STORAGE_BLOCK_COUNT, STORAGE_BLOCK_SIZE, WORD_MASK


@dataclass
class BlockStorageDevice:
    """
    Blokkipohjainen tallennuslaite.

    Simuloi levylaitetta, joka koostuu kiinteankokoisista blokeista.
    Tukee seka sanaosoitusta (DREAD/DWRITE) etta blokkiosoitusta (boot).

    Attributes:
        block_size_words: Yhden blokin koko sanoina (oletus: 256)
        block_count: Blokkien kokonaismaara (oletus: 256)
        blocks: Sisainen datarakenne - lista blokeista,
                kukin blokki on lista sanoja

    Example:
        >>> storage = BlockStorageDevice()
        >>> storage.write_word(0x0000, 0x1234)  # Kirjoita bootloader-alueelle
        >>> storage.read_word(0x0000)
        4660  # 0x1234
        >>> storage.total_words
        65536
    """

    # Blokin koko: 256 sanaa = 512 tavua (16-bittisia sanoja)
    block_size_words: int = STORAGE_BLOCK_SIZE

    # Blokkien maara: 256 blokkia
    block_count: int = STORAGE_BLOCK_COUNT

    # Sisainen tallennus: lista blokeista
    # Jokainen blokki on lista 16-bittisia sanoja
    blocks: list[list[int]] = field(default_factory=list)

    def __post_init__(self) -> None:
        """
        Alustus dataclassin luonnin jalkeen.

        Luo tyhjat blokit jos niita ei annettu konstruktorissa.
        Tarkistaa etta block_size_words ja block_count ovat jarkevia.

        Raises:
            ValueError: Jos block_size tai count on <= 0
        """
        # Tarkista parametrien jarkevyys
        if self.block_size_words <= 0 or self.block_count <= 0:
            raise ValueError("Block size and block count must be positive")

        # Luo tyhjat blokit jos ei annettu
        if not self.blocks:
            # Luo block_count blokkia, joissa kussakin block_size_words nollaa
            self.blocks = [[0] * self.block_size_words for _ in range(self.block_count)]

        # Esikäännetty struct-formaatti CRC-laskentaa varten (big-endian unsigned short)
        self._block_pack_fmt: str = f">{self.block_size_words}H"

    @property
    def total_words(self) -> int:
        """
        Laske kokonaiskapasiteetti sanoina.

        Returns:
            block_size_words * block_count
        """
        return self.block_size_words * self.block_count

    # =========================================================================
    # SANAOSOITETUT OPERAATIOT (DREAD/DWRITE)
    # =========================================================================

    def read_word(self, word_addr: int) -> int:
        """
        Lue yksittainen sana tallennuslaitteelta.

        DREAD-kasky kayttaa tata syotteena regS:n arvon (osoite).

        Args:
            word_addr: Sanaosoite (0x0000 - 0xFFFF)

        Returns:
            16-bittinen sana kyseisesta osoitteesta

        Raises:
            ValueError: Jos osoite on laitteen kapasiteetin ulkopuolella
        """
        block_idx, offset = self._decode_word_address(word_addr)
        return self.blocks[block_idx][offset]

    def write_word(self, word_addr: int, value: int) -> None:
        """
        Kirjoita yksittainen sana tallennuslaitteelle.

        DWRITE-kasky kayttaa tata parametreina regS (arvo) ja regD (osoite).

        Args:
            word_addr: Sanaosoite (0x0000 - 0xFFFF)
            value: Kirjoitettava arvo (maskataan 16-bittiseksi)

        Raises:
            ValueError: Jos osoite on laitteen kapasiteetin ulkopuolella
        """
        block_idx, offset = self._decode_word_address(word_addr)
        self.blocks[block_idx][offset] = value & WORD_MASK

    # =========================================================================
    # BLOKKIOSOITETUT OPERAATIOT (Boot, Levyjarjestelma)
    # =========================================================================

    def read_block(self, block_idx: int) -> list[int]:
        """
        Lue kokonainen blokki (sektori).

        Boot-prosessi kayttaa tata lukemaan sektorin 0.

        Args:
            block_idx: Blokin indeksi (0 - block_count-1)

        Returns:
            Kopio blokin sisallosta (lista sanoja)

        Raises:
            ValueError: Jos blokki-indeksi on rajojen ulkopuolella
        """
        block_idx = self._normalize_block_index(block_idx)
        # Palauta kopio, ei viittaus alkuperaiseen
        return list(self.blocks[block_idx])

    def write_block(self, block_idx: int, data: list[int]) -> None:
        """
        Kirjoita kokonainen blokki.

        Kayttojarjestelma voi kayttaa tata sektorien kirjoittamiseen.

        Args:
            block_idx: Blokin indeksi (0 - block_count-1)
            data: Kirjoitettava data (pitaa olla tasmilleen block_size_words sanaa)

        Raises:
            ValueError: Jos blokki-indeksi tai datan koko on vaara
        """
        block_idx = self._normalize_block_index(block_idx)

        # Tarkista datan koko
        if len(data) != self.block_size_words:
            raise ValueError(
                f"Block write size must be {self.block_size_words} words, got {len(data)}"
            )

        # Kirjoita ja maskaa kaikki arvot 16-bittisiksi
        self.blocks[block_idx] = [word & WORD_MASK for word in data]

    # =========================================================================
    # ALUEOSOITETUT OPERAATIOT (Helpompi kaytto)
    # =========================================================================

    def read_range(self, start_addr: int, count: int) -> list[int]:
        """
        Lue perakkaiset sanat alkaen annetusta osoitteesta.

        Kaytannollinen kun pitaa lukea useita sanoja kerralla.

        Args:
            start_addr: Aloitusosoite
            count: Luettavien sanojen maara

        Returns:
            Lista luettuja sanoja
        """
        return [self.read_word(start_addr + i) for i in range(count)]

    def write_range(self, start_addr: int, data: list[int]) -> None:
        """
        Kirjoita perakkaiset sanat alkaen annetusta osoitteesta.

        Kaytannollinen bootloaderin tai ohjelman kirjoittamiseen.

        Args:
            start_addr: Aloitusosoite
            data: Kirjoitettavat sanat
        """
        for i, word in enumerate(data):
            self.write_word(start_addr + i, word)

    # =========================================================================
    # TIEDOSTO-OPERAATIOT JA RESET
    # =========================================================================

    def save_to_file(self, path: Path) -> None:
        """Tallenna tallennuslaitteen sisalto .dsk-tiedostoon JSON-muodossa.

        Pakkaus: pelkasta samasta arvosta koostuvat blokit tallennetaan
        kompaktisti fill-arvona. Kaikki nollaa sisaltavat blokit jätetaan
        kokonaan pois tiedostosta (implisiittisesti nolla latauksessa).

        Args:
            path: Kohdetiedoston polku (.dsk-paate lisataan tarvittaessa)
        """
        if path.suffix.lower() != ".dsk":
            path = path.with_suffix(".dsk")
        device_crc = 0
        blocks_data: list[dict] = []
        pack_fmt = self._block_pack_fmt
        for i, block in enumerate(self.blocks):
            words = [w & WORD_MASK for w in block]
            raw = struct.pack(pack_fmt, *words)
            block_crc = zlib.crc32(raw) & 0xFFFFFFFF
            device_crc = zlib.crc32(raw, device_crc) & 0xFFFFFFFF
            first = words[0]
            if all(w == first for w in words):
                if first == 0:
                    # Pelkka nolla: jata kokonaan pois
                    continue
                # Yhtenäinen ei-nolla arvo: kompakti fill-muoto
                blocks_data.append(
                    {
                        "index": i,
                        "checksum": f"0x{block_crc:08X}",
                        "fill": first,
                    }
                )
            else:
                blocks_data.append(
                    {
                        "index": i,
                        "checksum": f"0x{block_crc:08X}",
                        "data": words,
                    }
                )
        doc = {
            "format": "kCPU16-disk",
            "version": 1,
            "block_size_words": self.block_size_words,
            "block_count": self.block_count,
            "device_checksum": f"0x{device_crc:08X}",
            "blocks": blocks_data,
        }
        path.write_text(json.dumps(doc, indent=2), encoding="utf-8")

    def load_from_file(self, path: Path) -> None:
        """Lataa tallennuslaitteen sisalto .dsk-tiedostosta.

        Tarkistaa jokaisen blokin ja koko laitteen CRC32-tarkistussumman.
        Puuttuvat blokit tulkitaan nollatäytteisiksi.

        Args:
            path: Lahdetiedoston polku

        Raises:
            FileNotFoundError: Jos tiedostoa ei loydy
            ValueError: Jos formaatti on vaara tai tarkistussumma ei tasmaa
        """
        if path.suffix.lower() != ".dsk":
            path = path.with_suffix(".dsk")
        doc = json.loads(path.read_text(encoding="utf-8"))
        if doc.get("format") != "kCPU16-disk":
            raise ValueError("Tuntematon tiedostoformaatti")
        if doc.get("block_count", 0) != self.block_count:
            raise ValueError(
                f"Blokkien maara {doc.get('block_count')}, odotettu {self.block_count}"
            )
        if doc.get("block_size_words", 0) != self.block_size_words:
            raise ValueError(
                f"Blokin koko {doc.get('block_size_words')}, odotettu {self.block_size_words}"
            )
        # Rakenna hakemisto tallennetuista blokeista
        stored: dict[int, dict] = {entry["index"]: entry for entry in doc["blocks"]}
        zero_raw = b"\x00\x00" * self.block_size_words
        device_crc = 0
        for i in range(self.block_count):
            if i not in stored:
                # Puuttuva blokki = implisiittinen nollatäyte
                device_crc = zlib.crc32(zero_raw, device_crc) & 0xFFFFFFFF
                self.blocks[i] = [0] * self.block_size_words
                continue
            entry = stored[i]
            if "fill" in entry:
                words = [entry["fill"] & WORD_MASK] * self.block_size_words
            else:
                words = entry["data"]
                if len(words) != self.block_size_words:
                    raise ValueError(
                        f"Blokki {i}: {len(words)} sanaa, odotettu {self.block_size_words}"
                    )
            raw = struct.pack(self._block_pack_fmt, *(w & WORD_MASK for w in words))
            block_crc = zlib.crc32(raw) & 0xFFFFFFFF
            expected_block = int(entry["checksum"], 16)
            if block_crc != expected_block:
                raise ValueError(
                    f"Blokki {i} tarkistussummavirhe: "
                    f"laskettu 0x{block_crc:08X}, odotettu 0x{expected_block:08X}"
                )
            device_crc = zlib.crc32(raw, device_crc) & 0xFFFFFFFF
            self.blocks[i] = [w & WORD_MASK for w in words]
        expected_dev = int(doc["device_checksum"], 16)
        if device_crc != expected_dev:
            raise ValueError(
                f"Levyn tarkistussummavirhe: "
                f"laskettu 0x{device_crc:08X}, odotettu 0x{expected_dev:08X}"
            )

    def reset(self) -> None:
        """Nollaa tallennuslaitteen sisalto (kaikki sanat = 0)."""
        for block in self.blocks:
            for i in range(len(block)):
                block[i] = 0

    # =========================================================================
    # SISAISET APUMETODIT
    # =========================================================================

    def _decode_word_address(self, word_addr: int) -> tuple[int, int]:
        """
        Muunna sanaosoite blokki-indeksiksi ja offsetiksi.

        Args:
            word_addr: Sanaosoite (0-total_words)

        Returns:
            (blokki_indeksi, offset_blokissa)

        Raises:
            ValueError: Jos osoite ylittaa kapasiteetin
        """
        word_addr &= WORD_MASK

        # Tarkista rajojen sisalla
        if word_addr >= self.total_words:
            raise ValueError(
                f"Word address out of range: 0x{word_addr:04X} (capacity {self.total_words} words)"
            )

        # Laske blokki ja offset jakamalla
        # Esim. osoite 0x0150 blokilla 0x100:
        # block_idx = 0x0150 // 0x0100 = 1
        # offset = 0x0150 % 0x0100 = 0x50
        return divmod(word_addr, self.block_size_words)

    def _normalize_block_index(self, block_idx: int) -> int:
        """
        Tarkista ja normalisoi blokki-indeksi.

        Args:
            block_idx: Blokin indeksi

        Returns:
            Sama indeksi, jos kelvollinen

        Raises:
            ValueError: Jos indeksi on rajojen ulkopuolella
        """
        if block_idx < 0 or block_idx >= self.block_count:
            raise ValueError(f"Block index out of range: {block_idx}")
        return block_idx

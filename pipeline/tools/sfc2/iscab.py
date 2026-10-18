"""Read-only extractor for InstallShield 5 cabinets (data1.hdr + data1.cab), after the layout
documented by the open-source unshield project. Usage:
  python iscab.py list  <disc>               list every file with its folder and size
  python iscab.py get   <disc> <out> <glob>  extract files whose path matches the glob
"""
import fnmatch
import struct
import sys
import zlib
from pathlib import Path

FLAG_SPLIT, FLAG_OBFUSCATED, FLAG_COMPRESSED, FLAG_INVALID = 1, 2, 4, 8


def cstr(buf, off):
    end = buf.index(b"\0", off)
    return buf[off:end].decode("latin-1")


class Cabinet:
    def __init__(self, disc: Path):
        self.disc = disc
        h = (disc / "data1.hdr").read_bytes()
        sig, ver, _vol, cdo, _cds = struct.unpack_from("<5I", h, 0)
        assert sig == 0x28635349, "not an InstallShield cabinet"
        d = cdo
        ft_off = struct.unpack_from("<I", h, d + 0x0C)[0]
        dir_count = struct.unpack_from("<I", h, d + 0x1C)[0]
        file_count = struct.unpack_from("<I", h, d + 0x28)[0]
        base = d + ft_off
        table = struct.unpack_from(f"<{dir_count + file_count}I", h, base)
        self.dirs = [cstr(h, base + table[i]) for i in range(dir_count)]
        self.files = []
        for i in range(file_count):
            fd = base + table[dir_count + i]
            name_off, dir_index, flags, expanded, compressed = struct.unpack_from("<IIHII", h, fd)
            data_off = struct.unpack_from("<I", h, fd + 0x12 + 0x14)[0]
            if flags & FLAG_INVALID or name_off == 0:
                continue
            name = cstr(h, base + name_off)
            folder = self.dirs[dir_index] if dir_index < len(self.dirs) else ""
            self.files.append({"path": f"{folder}\\{name}".strip("\\"), "flags": flags,
                               "size": expanded, "csize": compressed, "offset": data_off})

    def read(self, f) -> bytes:
        with open(self.disc / "data1.cab", "rb") as cab:
            cab.seek(f["offset"])
            raw = cab.read(f["csize"])
        if len(raw) < f["csize"]:
            raise EOFError("file continues on the next disc")
        if f["flags"] & FLAG_OBFUSCATED:
            raise NotImplementedError("obfuscated file")
        if not f["flags"] & FLAG_COMPRESSED:
            return raw
        out, pos = bytearray(), 0
        while pos < len(raw) and len(out) < f["size"]:
            n = struct.unpack_from("<H", raw, pos)[0]
            pos += 2
            block = raw[pos:pos + n]
            pos += n
            out += zlib.decompressobj(-15).decompress(block)
        return bytes(out[:f["size"]])


def main():
    mode, disc = sys.argv[1], Path(sys.argv[2])
    cab = Cabinet(disc)
    if mode == "list":
        for f in cab.files:
            print(f"{f['size']:>10}  {f['path']}")
        print(f"{len(cab.files)} files in {len(cab.dirs)} folders")
    else:
        out, pattern = Path(sys.argv[3]), sys.argv[4].lower()
        n = 0
        for f in cab.files:
            if fnmatch.fnmatch(f["path"].lower(), pattern):
                try:
                    data = cab.read(f)
                except Exception as e:
                    print("skip", f["path"], e)
                    continue
                dest = out / f["path"].replace("\\", "/")
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(data)
                n += 1
        print(f"extracted {n} files to {out}")


if __name__ == "__main__":
    main()

"""Read a .ship file without running it.

Every .ship file in the mod is plain data: NewShipType.<field> = <literal> assignments and calls
such as addAbility(...) and StartShipWeaponConfig(...), with no control flow (checked across all
596 files for #411). So a small reader for Lua literals is enough: no Lua interpreter needed.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

_SCALAR = re.compile(r"^\s*New(?:Ship|SubSystem)Type\.(\w+)\s*=\s*(.+?)\s*$")  # .ship and .subs files
_CALL_START = re.compile(r"\b([A-Za-z_]\w*)\s*\(")


@dataclass
class LuaTable:
    """A Lua table literal: positional items plus named fields."""
    items: list = field(default_factory=list)
    fields: dict = field(default_factory=dict)


@dataclass
class ShipFile:
    path: Path
    scalars: dict = field(default_factory=dict)
    calls: list = field(default_factory=list)  # (function name, [args]) in file order

    def calls_named(self, name: str) -> list[list]:
        return [args for fn, args in self.calls if fn == name]


def strip_comments(text: str) -> str:
    """Remove Lua line comments (--) that aren't inside strings."""
    out_lines = []
    for line in text.splitlines():
        in_str = None
        cut = len(line)
        i = 0
        while i < len(line):
            ch = line[i]
            if in_str:
                if ch == "\\":
                    i += 1
                elif ch == in_str:
                    in_str = None
            elif ch in "\"'":
                in_str = ch
            elif line.startswith("--", i):
                cut = i
                break
            i += 1
        out_lines.append(line[:cut])
    return "\n".join(out_lines)


class _Reader:
    """Tokenises a Lua literal expression: strings, numbers, booleans/nil, names, tables."""

    def __init__(self, text: str, pos: int = 0):
        self.text, self.pos = text, pos

    def _skip_space(self):
        self.pos = self._after_space()

    def _after_space(self) -> int:
        pos = self.pos
        while pos < len(self.text) and self.text[pos] in " \t\r\n":
            pos += 1
        return pos

    def peek(self) -> str:
        self._skip_space()
        return self.text[self.pos] if self.pos < len(self.text) else ""

    def value(self):
        ch = self.peek()
        if ch in "\"'":
            text = self._string()
            while self.text.startswith("..", self._after_space()):  # "a" .. "b" string joins
                self.pos = self._after_space() + 2
                text += str(self.value())
            return text
        if ch == "{":
            return self._table()
        m = re.compile(r"-?(\d+(\.\d*)?|\.\d+)([eE][-+]?\d+)?").match(self.text, self.pos)
        if m and m.group(0) not in ("", "-"):
            self.pos = m.end()
            num = m.group(0)
            return float(num) if any(c in num for c in ".eE") else int(num)
        m = re.compile(r"[A-Za-z_][\w.]*").match(self.text, self.pos)
        if m:
            self.pos = m.end()
            word = m.group(0)
            if self.peek() == "(":  # a nested call, e.g. getShipNum(...): keep its source text
                start = m.start()
                self._balanced("(", ")")
                return {"call": self.text[start:self.pos]}
            return {"true": True, "false": False, "nil": None}.get(word, {"name": word})
        raise ValueError(f"unexpected {self.text[self.pos:self.pos + 20]!r}")

    def _string(self) -> str:
        quote = self.text[self.pos]
        self.pos += 1
        out = []
        while self.text[self.pos] != quote:
            ch = self.text[self.pos]
            if ch == "\\":
                self.pos += 1
                ch = {"n": "\n", "t": "\t"}.get(self.text[self.pos], self.text[self.pos])
            out.append(ch)
            self.pos += 1
        self.pos += 1
        return "".join(out)

    def _table(self) -> LuaTable:
        self.pos += 1
        table = LuaTable()
        while self.peek() != "}":
            m = re.compile(r"\s*([A-Za-z_]\w*)\s*=(?!=)").match(self.text, self.pos)
            if m:
                self.pos = m.end()
                table.fields[m.group(1)] = self.value()
            else:
                table.items.append(self.value())
            if self.peek() in ",;":
                self.pos += 1
        self.pos += 1
        return table

    def _balanced(self, open_ch: str, close_ch: str):
        depth = 0
        while self.pos < len(self.text):
            ch = self.text[self.pos]
            if ch in "\"'":
                self._string()
                continue
            if ch == open_ch:
                depth += 1
            elif ch == close_ch:
                depth -= 1
                if depth == 0:
                    self.pos += 1
                    return
            self.pos += 1
        raise ValueError("unbalanced brackets")

    def arguments(self) -> list:
        """Read '(' arg, arg ... ')' starting at the opening bracket."""
        self._skip_space()
        assert self.text[self.pos] == "("
        self.pos += 1
        args = []
        while self.peek() != ")":
            args.append(self.value())
            if self.peek() == ",":
                self.pos += 1
        self.pos += 1
        return args


def parse_ship_text(text: str, path: Path | None = None) -> ShipFile:
    code = strip_comments(text)
    ship = ShipFile(path=path or Path("<text>"))

    for line in code.splitlines():
        m = _SCALAR.match(line)
        if m:
            try:
                ship.scalars[m.group(1)] = _Reader(m.group(2)).value()
            except (ValueError, IndexError):
                ship.scalars[m.group(1)] = {"unparsed": m.group(2)}

    # Calls at the start of a statement; arguments may span several lines.
    pos = 0
    while True:
        m = _CALL_START.search(code, pos)
        if not m:
            break
        line_start = code.rfind("\n", 0, m.start()) + 1
        if code[line_start:m.start()].strip():  # not at the start of a statement
            pos = m.end()
            continue
        reader = _Reader(code, m.end() - 1)
        try:
            args = reader.arguments()
        except (ValueError, IndexError, AssertionError) as exc:
            raise ValueError(f"{path}: can't read {m.group(1)}(...) near line {code.count(chr(10), 0, m.start()) + 1}: {exc}") from exc
        ship.calls.append((m.group(1), args))
        pos = reader.pos
    return ship


def parse_ship_file(path: Path) -> ShipFile:
    return parse_ship_text(path.read_text(encoding="utf-8", errors="replace"), path)


def read_assigned_table(text: str, name: str | None = None):
    """The table literal assigned to `name` (or to the first `X = {`) in a Lua data file."""
    code = strip_comments(text)
    pattern = rf"\b{re.escape(name)}\s*=\s*\{{" if name else r"\b\w+\s*=\s*\{"
    m = re.search(pattern, code)
    if not m:
        return None
    return _Reader(code, m.end() - 1).value()


def plain(value):
    """Convert reader output to plain Python: tables become lists or dicts, names become strings."""
    if isinstance(value, LuaTable):
        if value.fields and not value.items:
            return {k: plain(v) for k, v in value.fields.items()}
        if value.items and not value.fields:
            return [plain(v) for v in value.items]
        return {"items": [plain(v) for v in value.items], **{k: plain(v) for k, v in value.fields.items()}}
    if isinstance(value, dict) and set(value) == {"name"}:
        return value["name"]
    return value

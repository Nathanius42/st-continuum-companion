"""What each model state shows, hides and animates (#919, #926).

A ship's ship/<hull>/<hull>.madstate is Lua: one function per state,
<HULL>_<State>_OnSet, calling setJointVisible(ship, "<joint>", 0 or 1) and
startAnim(ship, "<animation>"), and sometimes <HULL>_<State>_OnPause, which runs when
the animation reaches its held last frame (the T'Garim swaps its turret for the
deployed one there). The Normal state is the ship as built; a subsystem's state (from
EraSpecificShipCode.lua, see subsystems.py) shows its module; CodeRed is battle
stations (a Bird-of-Prey's wings down). Rendering a state means hiding the meshes under
the joints it ends with set to 0, posed at the end of the animations it starts.
"""
from __future__ import annotations

import re
from functools import lru_cache

from .ships import ERA_FOLDERS, HWRM

# A function ends at an unindented "end"; the indented ones close its if blocks.
_FUNCTION = re.compile(r"\b(\w+)_(OnSet|OnPause)\s*=\s*function\s*\([^)]*\)(.*?)\nend\b", re.S)
_JOINT = re.compile(r'setJointVisible\s*\(\s*\w+\s*,\s*"([^"]+)"\s*,\s*([01])\s*\)')
_ANIM = re.compile(r'startAnim\s*\(\s*\w+\s*,\s*"([^"]+)"')
# Effects every ship has, not poses: hyperspace and shield flashes.
_NOT_POSES = re.compile(r"^(warp_(in|out)|shield_(on|off))$", re.I)


@lru_cache(maxsize=None)
def _states(era: str, hull: str) -> dict[str, dict]:
    """State -> {"joints": {joint: visible}, "anims": [animation names]}."""
    path = HWRM / ERA_FOLDERS[era] / "ship" / hull / f"{hull}.madstate"
    if not path.exists():
        return {}
    text = re.sub(r"--[^\n]*", "", path.read_text(encoding="utf-8", errors="replace"))
    prefix = hull.upper() + "_"
    out: dict[str, dict] = {}
    # OnSet first, then OnPause: the paused state is what's left on screen.
    found = sorted(_FUNCTION.finditer(text), key=lambda m: m.group(2) != "OnSet")
    for m in found:
        name, kind, body = m.group(1), m.group(2), m.group(3)
        state = name[len(prefix):] if name.upper().startswith(prefix) else name.split("_")[-1]
        entry = out.setdefault(state, {"joints": {}, "anims": []})
        entry["joints"].update({j: v == "1" for j, v in _JOINT.findall(body)})
        if kind == "OnSet":
            entry["anims"] += [a for a in _ANIM.findall(body) if not _NOT_POSES.match(a) and a not in entry["anims"]]
    return out


def joint_states(era: str, hull: str) -> dict[str, dict[str, bool]]:
    """State name -> {joint: visible} for the hull, from its .madstate file."""
    return {s: v["joints"] for s, v in _states(era, hull).items() if v["joints"]}


def hidden_joints(era: str, hull: str, state: str = "Normal") -> list[str]:
    """Joints a state hides; nothing when the hull has no such state."""
    return sorted(j for j, shown in _states(era, hull).get(state, {}).get("joints", {}).items() if not shown)


def state_poses(era: str, hull: str, state: str = "Normal") -> list[str]:
    """Animations a state starts and holds on their last frame."""
    return list(_states(era, hull).get(state, {}).get("anims", []))


def has_state(era: str, hull: str, state: str) -> bool:
    return state in _states(era, hull)


def combined(era: str, hull: str, states) -> tuple[list[str], list[str]]:
    """(hidden joints, poses) after applying states in order, e.g. ["Normal", "ResourceStart"]:
    each state's joint settings override the earlier ones, and their animations add up."""
    joints: dict[str, bool] = {}
    poses: list[str] = []
    for state in states:
        info = _states(era, hull).get(state, {})
        joints.update(info.get("joints", {}))
        poses += [a for a in info.get("anims", []) if a not in poses]
    return sorted(j for j, shown in joints.items() if not shown), poses

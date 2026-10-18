"""Check that model-switching subsystems become refit or subsystem toggles on their ship's page."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))

from dexpipe.assemble import _subsystem_stats  # noqa: E402
from dexpipe.subsystems import ship_subsystems  # noqa: E402


def test_one_madstate_subsystem_is_a_refit_and_several_are_subsystems():
    tmp = ship_subsystems("TMP")
    assert [(t["kind"], t["subsystemId"]) for t in tmp["fed_TMP_excelsior"]] == [("refit", "fed_TMP_excelsior_refit")]
    assert [(t["kind"], t["label"]) for t in tmp["fed_TMP_miranda"]] == [
        ("subsystem", "Sensor Suite"), ("subsystem", "Phaser Cannons"), ("subsystem", "Torpedo Roll-bar")]
    assert [t["kind"] for t in ship_subsystems("TNG")["fed_TNG_nebula"]] == ["subsystem"] * 3
    assert [(t["kind"], t["label"]) for t in ship_subsystems("TNG")["brg_TNG_cube"]] == [("refit", "Tactical Armour")]


def test_subsystem_stats_apply_multipliers_and_add_cost():
    parent = {"maxHealth": 10800, "maxSpeed": 169, "buildCost": 2400, "buildTime": 62}
    refit = {"multipliers": {"maxSpeed": 1.2, "maxHealth": 1.2}, "buildCost": 370, "buildTime": 35}
    assert _subsystem_stats(parent, refit) == {"maxSpeed": 202.8, "maxHealth": 12960, "buildCost": 2770, "buildTime": 97}


def test_model_states_hide_unfitted_modules():
    """The Nebula is built without pods; each subsystem's state shows only its own."""
    from dexpipe.madstates import hidden_joints
    from dexpipe.subsystems import subsystem_madstates

    states = subsystem_madstates("TNG")["fed_TNG_nebula"]
    assert states == {"fed_TNG_nebula_sensordish": "ResourceStart",
                      "fed_TNG_nebula_torpbattery": "ResourceEnd",
                      "fed_TNG_nebula_nacelles": "ResourceDo"}
    assert hidden_joints("TNG", "fed_TNG_nebula") == ["NacellePylons", "Nacelles", "SensorPylons", "Sensors", "Torp"]
    assert hidden_joints("TNG", "fed_TNG_nebula", "ResourceStart") == ["NacellePylons", "Nacelles", "Torp"]
    # The TMP Excelsior's refit swaps one hull section for another.
    assert hidden_joints("TMP", "fed_TMP_excelsior") == ["Mesh_Lakota"]
    assert hidden_joints("TMP", "fed_TMP_excelsior", "ResourceStart") == ["Mesh_Excelsior"]
    # A hull with no .madstate hides nothing.
    assert hidden_joints("TNG", "not_a_hull") == []


def test_states_pose_animations_and_research_upgrades():
    """Deploys, wings and research upgrades come from the model states (#926)."""
    from dexpipe.madstates import combined, state_poses
    from dexpipe.subsystems import ship_subsystems

    # A Bird-of-Prey's battle stations hold the wings-down animation.
    assert state_poses("ENT", "kng_ENT_bop", "CodeRed") == ["WingsDown"]
    # Functions with if blocks are read to their own end, not the first inner one.
    assert state_poses("TNG", "rom_TNG_probe", "Open") == ["Open"]
    # OnPause wins over OnSet: the T'Garim swaps its turret once deployed.
    hidden, poses = combined("ENT", "fed_ENT_TEL_tgarim", ["Normal", "ResourceStart"])
    assert poses == ["deploy"] and "turret" in hidden and "cannons" not in hidden
    toggles = {t["key"]: t for t in ship_subsystems("TNG")["kng_TNG_neghvar"]}
    assert toggles["PulseAnim"]["kind"] == "upgrade"
    assert toggles["PulseAnim"]["label"] == "Heavy Pulse Cannons"
    assert [t["kind"] for t in ship_subsystems("ENT")["kng_ENT_bop"]] == ["mode"]

"""Generates the DriveTech Bus parts for both bus families.

    python tools/gen_bus.py

The stock Wentward DT40L uses `citybus_*` slots, the buses of the Wentward Pack
(DT35L, DT45L, ...) share `citybus_ai_*` slots from vehicles/common. Both get the
same drivetrain, so the parts come from one source here instead of two hand-kept copies.
Output is plain JSON, which jbeam accepts.
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(ROOT, "mod_bus")
AUTHORS = "BeamNG, jx-grxf"

PSI = 6894.757293178
# BeamNG turbocharger.lua: torque coef = 1 + 0.0000087 * boost[Pa] * efficiency(rpm)
TURBO_COEF = 0.0000087

# Both the stock Gavril 8.9 l and the Wentward Pack CNG engine use friction 30 + 0.3 * AV.
FRICTION, DYNAMIC_FRICTION = 30, 0.3

DIESEL_BASE = {0: 0, 200: 210, 400: 350, 600: 430, 800: 515, 1000: 576, 1200: 598, 1400: 588, 1500: 577,
               1600: 566, 1800: 545, 2000: 520, 2200: 450, 2400: 405, 2600: 305, 2800: 230, 3000: 140}
CNG_BASE = {0: 0, 200: 250, 400: 441, 600: 526, 800: 578, 1000: 609, 1200: 652, 1400: 670, 1500: 683,
            1600: 692, 1800: 690, 2000: 687, 2200: 641, 2400: 595, 2600: 495, 2800: 420, 3000: 330}

# Turbo hardware of the stock T350, shared by all calibrations. Only boost and efficiency change.
PRESSURE_CURVE = [[0, 0], [30000, 10], [60000, 20], [90000, 36], [120000, 46], [150000, 52],
                  [200000, 58], [250000, 63], [300000, 66]]
EXHAUST_FACTOR = {0: 0, 200: 0.1, 400: 0.3, 600: 0.54, 800: 0.75, 1000: 0.87, 1200: 0.9, 1400: 0.87,
                  1500: 0.81, 1600: 0.75, 1800: 0.67, 2000: 0.59, 2200: 0.51, 2400: 0.43, 2600: 0.35,
                  2800: 0.26, 3000: 0.18}
# Below full boost the efficiency only shapes spool-up, kept from the hand-tuned Cursor 9 calibration.
SPOOL_EFFICIENCY = {0: 0, 200: 0.37, 400: 0.51, 600: 0.64, 800: 0.76}

ENGINES = {
    # Iveco Cursor 9 diesel, FPT data sheet / busplaner bus test
    "cursor9_360": {"base": DIESEL_BASE, "boost": 39.5, "torque": 1650, "power_kw": 265, "plateau": 1100,
                    "rated": 2200, "name": "Cursor 9 Turbo (360 PS / 1650 Nm)", "value": 7200},
    "cursor9_400": {"base": DIESEL_BASE, "boost": 41.5, "torque": 1700, "power_kw": 294, "plateau": 1100,
                    "rated": 2200, "name": "Cursor 9 Turbo (400 PS / 1700 Nm)", "value": 7800},
    # Cursor 9 Natural Gas in the Urbanway 12 m: 310 PS / 1300 Nm (Iveco Bus Urbanway brochure 2022).
    # The brochure gives no speed band, 2000 rpm rated speed is the FPT figure for the Cursor 9 NG.
    "cursor9ng_310": {"base": CNG_BASE, "boost": 22.5, "torque": 1300, "power_kw": 228, "plateau": 1100,
                      "rated": 2000, "name": "Cursor 9 NG Turbo (310 PS / 1300 Nm)", "value": 6900, "cng": True},
}


def friction(rpm):
    return FRICTION + DYNAMIC_FRICTION * rpm * math.pi / 30


def target_torque(e, rpm):
    av = rpm * math.pi / 30
    if rpm <= e["rated"]:
        return min(e["torque"], e["power_kw"] * 1000 / av)
    # past rated speed the governor pulls power down steeply
    return e["power_kw"] * 1000 / av * max(0.0, 1 - (rpm - e["rated"]) / 400)


def calibrate(e):
    """Efficiency per rpm so that net torque at full boost hits the Iveco curve."""
    # the wastegate settles between start and limit, half a psi above the start
    pressure = (e["boost"] + 0.5) * PSI
    rows = []
    for rpm in sorted(e["base"]):
        if rpm in SPOOL_EFFICIENCY:
            eff = SPOOL_EFFICIENCY[rpm]
        else:
            torque = target_torque(e, rpm)
            if rpm < e["plateau"]:
                torque *= 0.92
            gross = torque + friction(rpm)
            eff = max(0.0, (gross / e["base"][rpm] - 1) / (TURBO_COEF * pressure))
        rows.append([rpm, round(eff, 3), EXHAUST_FACTOR[rpm]])
    return rows


def net_torque(e, rpm, eff):
    return e["base"][rpm] * (1 + TURBO_COEF * (e["boost"] + 0.5) * PSI * eff) - friction(rpm)


FAMILIES = {
    "stock": {
        "prefix": "citybus_",
        "file": "vehicles/citybus/driveTechBus_parts.jbeam",
        "transmission_mesh": ["citybus_transmission", ["citybus_transmission", "citybus_engine_L", "citybus_engine_R"]],
        "transmission_group": "citybus_transmission",
        "shocks": [
            {"slot": "citybus_shock_F", "mesh": ["citybus_shock_F", ["citybus_shock_F"]], "axle": "F",
             "break": "airbag_F_break", "beams": [["fax8l", "fs17l"], ["fax8l", "fs18l"], ["fax8r", "fs17r"], ["fax8r", "fs18r"]]},
            {"slot": "citybus_shock_R", "mesh": ["citybus_shocks_R", ["citybus_airbags_R"]], "axle": "R",
             "break": "airbag_R_break", "mesh_break": "airbag_R1_break",
             "beams": [["ab1l", "ab3l"], ["ab1r", "ab3r"], ["ab2l", "ab4l"], ["ab2r", "ab4r"]]},
        ],
        "driveshaft": {"slot": "citybus_driveshaft", "mesh": "citybus_driveshaft"},
        "loads": [{"name": "citybus_drivetech_load", "rows": [5, 6, 8, 9],
                   "y": {4: -4.09, 5: -3.4, 6: -2.32, 7: -1.52, 8: -0.66, 9: 0.38, 11: 1.6}}],
    },
    "wentward": {
        "prefix": "citybus_ai_",
        "file": "vehicles/common/driveTechBus/driveTechBus_wentward_parts.jbeam",
        "transmission_mesh": ["citybus_ai_transmission", ["citybus_ai_transmission", "citybus_ai_engine_L", "citybus_ai_engine_R"]],
        "transmission_group": "citybus_ai_transmission",
        "shocks": [
            {"slot": "citybus_ai_shock_F", "mesh": ["citybus_ai_shock_F", ["citybus_ai_shock_F"]], "axle": "F",
             "break": "airbag_F_break", "beams": [["fax8l", "fs17l"], ["fax8l", "fs18l"], ["fax8r", "fs17r"], ["fax8r", "fs18r"]]},
            {"slot": "citybus_ai_35_shock_R", "mesh": ["citybus_ai_35_shocks_R", ["citybus_ai_35_airbags_R"]], "axle": "R",
             "break": "airbag_R_break", "mesh_break": "airbag_R1_break",
             "beams": [["ab1l", "ab3l"], ["ab1r", "ab3r"], ["ab2l", "ab4l"], ["ab2r", "ab4r"]]},
            {"slot": "citybus_ai_45_shock_R", "mesh": ["citybus_ai_45_shocks_R", ["citybus_airbags_R"]], "axle": "R",
             "break": "airbag_R_break", "mesh_break": "airbag_R1_break",
             "beams": [["ab1l", "ab3l"], ["ab1r", "ab3r"], ["ab2l", "ab4l"], ["ab2r", "ab4r"]]},
            # DT45L steered tag axle, valved like the front axle
            {"slot": "citybus_ai_45_shock_RR", "mesh": ["citybus_ai_45_shock_RR", ["citybus_ai_45_shock_RR"]], "axle": "RR",
             "break": "airbag_RR_break", "beams": [["2rax8l", "2fs17l"], ["2rax8l", "2fs18l"], ["2rax8r", "2fs17r"], ["2rax8r", "2fs18r"]]},
        ],
        # Wentward Pack driveshafts already take their input from a device called "retarder"
        "driveshaft": None,
        "loads": [
            {"name": "citybus_ai_drivetech_load_40", "rows": [5, 6, 8, 9],
             "y": {4: -4.09, 5: -3.4, 6: -2.32, 7: -1.52, 8: -0.66, 9: 0.38, 11: 1.6}, "title": "DT40L / DT45L floor"},
            {"name": "citybus_ai_drivetech_load_35", "rows": [5, 6, 9, 11],
             "y": {4: -4.09, 5: -3.4, 6: -2.32, 9: -1.272, 11: -0.052, 13: 0.758}, "title": "DT35L floor"},
        ],
    },
}

# Valving of the stock bus dampers, scaled by the DriveTech damping variable.
DAMPING = {"F": (18000, 36000, 9000, 18000), "R": (22000, 44000, 11000, 22000), "RR": (18000, 36000, 9000, 18000)}
DAMPING_DEFAULT = {"F": 1.4, "R": 1.3, "RR": 1.3}

# ZF EcoLife output retarder at the gearbox output shaft. About 1150 shaft rpm at 50 km/h and
# 2300 rpm at 100 km/h on the 4.63 axle. 3000 Nm plateau, then a 400 kW limit; it fades out
# below walking pace like a real retarder.
RETARDER_TORQUE = [[0, 0], [100, 60], [200, 250], [300, 550], [400, 950], [500, 1450], [600, 2000],
                   [700, 2500], [800, 2900], [900, 3000], [1270, 3000]] + \
                  [[rpm, round(400000 / (rpm * math.pi / 30))] for rpm in (1500, 1800, 2100, 2400, 2800, 3200, 4000)]


def info(name, value, authors=AUTHORS):
    return {"authors": authors, "name": "DriveTech " + name, "value": value}


def variable(name, unit, default, lo, hi, title, desc, step):
    return [name, "range", unit, "DriveTech", default, lo, hi, title, desc, {"stepDis": step}]


VAR_HEADER = ["name", "type", "unit", "category", "default", "min", "max", "title", "description"]


def turbo_part(fam, key):
    e = ENGINES[key]
    boost_var = "$dt_bus_boost_" + key.split("_")[-1] + ("ng" if e.get("cng") else "")
    slot = fam["prefix"] + ("turbo_cng" if e.get("cng") else "turbo")
    return {
        "information": info(e["name"], e["value"]),
        "slotType": slot,
        "variables": [VAR_HEADER, variable(boost_var, "psi", e["boost"], e["boost"] - 10, e["boost"] + 10,
                                           "Boost (wastegate)", "Stock calibration %.1f psi. Higher = more power" % e["boost"], 0.5)],
        "turbocharger": {
            "hissLoopEvent": "event:>Vehicle>Forced_Induction>turbo_bus_01>turbo_hiss",
            "whineLoopEvent": "event:>Vehicle>Forced_Induction>turbo_bus_01>turbo_spin",
            "bovEnabled": False, "bovSoundVolumeCoef": 0.0, "hissVolumePerPSI": 0.0,
            "whineVolumePer10kRPM": 0.06, "whinePitchPer10kRPM": 0.074,
            "wastegateStart": boost_var, "wastegateLimit": "$=%s+1" % boost_var,
            "maxExhaustPower": 16000, "backPressureCoef": 0.00005, "frictionCoef": 12, "inertia": 15,
            "damageThresholdTemperature": 750,
            "pressurePSI": PRESSURE_CURVE,
            "engineDef": calibrate(e),
        },
        "mainEngine": {"turbocharger": "turbocharger",
                       "deformGroups_turbo": ["mainEngine_turbo", "mainEngine_intercooler", "mainEngine_piping"]},
    }


def ecu_part(fam):
    p = fam["prefix"]
    return {
        "information": info("Cursor 9 Engine Management", 900, "jx-grxf"),
        "slotType": p + "engine_ecu",
        "slots2": [["name", "allowTypes", "denyTypes", "default", "description"],
                   [p + "drivetech_load", [p + "drivetech_load"], [], "", "Standing Passengers"]],
        "variables": [VAR_HEADER,
                      variable("$dt_bus_revlimit", "rpm", 2300, 2100, 2600, "Rev limiter", "Cursor 9 rated speed is 2200 rpm (gas: 2000 rpm)", 50),
                      variable("$dt_bus_vmax", "km/h", 100, 50, 140, "Speed limiter", "EU buses are limited to 100 km/h", 1)],
        # the stock 2200 rpm would cap automatic upshifts at about 2100 rpm, below rated speed
        "mainEngine": {"maxRPM": 2300, "revLimiterRPM": "$dt_bus_revlimit", "revLimiterType": "soft",
                       # Euro VI with particulate filter: hardly any visible smoke
                       "particulates": 0.02},
        "vehicleController": {"topSpeedLimit": "$=$dt_bus_vmax/3.6"},
    }


def finaldrive_part(fam):
    return {
        "information": info("Rear Final Drive (adjustable)", 150, "jx-grxf"),
        "slotType": fam["prefix"] + "finaldrive_R",
        "variables": [VAR_HEADER, variable("$dt_bus_finaldrive", ":1", 4.63, 3.0, 6.5, "Final drive ratio",
                                           "Crossway LE with EcoLife: 4.63. Higher = more pull, lower top speed", 0.01)],
        "differential_R": {"gearRatio": "$dt_bus_finaldrive"},
    }


def converter_part(fam):
    return {
        "information": info("EcoLife Torque Converter", 650),
        "slotType": fam["prefix"] + "converter",
        "torqueConverter": {"uiName": "Torque Converter", "converterDiameter": 0.44, "converterStiffness": 12,
                            "couplingAVRatio": 0.88, "stallTorqueRatio": 2.02,
                            # the stock 1500 Nm lockup clutch would slip behind a Cursor 9
                            "lockupClutchTorque": 2800, "additionalEngineInertia": 1.1},
        # locking up at 600 rpm coupled the engine hard at walking pace and the driveline shunted
        "vehicleController": {"torqueConverterLockupRPM": 1000, "torqueConverterLockupMinGear": 2,
                              "partialLockupTipInThreshold": 1.0},
    }


def transmission_part(fam):
    p = fam["prefix"]
    g = fam["transmission_group"]
    return {
        "information": info("6-Speed Automatic (ZF EcoLife, retarder)", 11800),
        "slotType": p + "transmission",
        "slots2": [["name", "allowTypes", "denyTypes", "default", "description"],
                   [p + "converter", [p + "converter"], [], p + "converter_drivetech_ecolife", "Torque Converter", {"coreSlot": True}]],
        "variables": [VAR_HEADER, variable("$dt_bus_kickdown", "rpm", 2150, 1800, 2200, "Kickdown shift speed",
                                           "Upshift speed at full throttle. Part throttle shifts at about 1500 rpm", 50)],
        "powertrain": [
            ["type", "name", "inputName", "inputIndex"],
            ["torqueConverter", "torqueConverter", "mainEngine", 1],
            ["automaticGearbox", "gearbox", "torqueConverter", 1],
            # output shaft with the retarder on its second output, the layout of the Percheron.
            # It is named "retarder" because the Wentward Pack driveshafts connect to that name.
            ["differential", "retarder", "gearbox", 1, {"diffType": "locked", "lockTorque": 50000, "friction": 0.44,
                                                        "dynamicFriction": 0.00048, "torqueLossCoef": 0.004,
                                                        "uiName": "Transmission Output Shaft", "defaultVirtualInertia": 0.1}],
            ["hydrodynamicRetarder", "dtRetarder", "retarder", 2],
        ],
        "gearbox": {
            "uiName": "Gearbox",
            # EcoLife 6AP forward ratios, reverse kept from the stock gearbox
            "gearRatios": [-5.03, 0, 3.364, 1.909, 1.421, 1.0, 0.72, 0.615],
            "friction": 4.69, "dynamicFriction": 0.0047, "torqueLossCoef": 0.016, "parkLockTorque": 50000,
            "oneWayViscousCoef": 100, "gearboxNode:": ["tra1"],
            "gearWhineCoefsInput": [0.64, 0.00, 0.64, 0.62, 0.60, 0.58, 0.56, 0.54, 0.52, 0.50, 0.48, 0.46],
            "gearWhineCoefsOutput": [0.00, 0.00, 0.64, 0.66, 0.68, 0.70, 0.72, 0.74, 0.76, 0.78, 0.80, 0.82],
            "gearWhineInputEvent": "event:>Vehicle>Transmission>bus_01>transaxle_in",
            "gearWhineOutputEvent": "event:>Vehicle>Transmission>bus_01>transaxle_out",
        },
        "dtRetarder": {"brakeTorque": [["rpm", "torque"]] + RETARDER_TORQUE, "strengthSmoothing": 6},
        "controller": [
            ["fileName"],
            ["braking/retarderControl", {"name": "retarderControl"}],
            ["driveTechBus/retarderDefault", {"name": "driveTechBusRetarderDefault"}],
        ],
        "retarderControl": {
            "controlledRetarder": "dtRetarder", "retarderManualLevels": [0.2, 0.4, 0.6, 0.8, 1.0], "hasAutoMode": True,
            "electricsNameSetting": "retarder", "electricsNameActual": "retarder_actual",
            "electricsNameIsEnabled": "retarder_isEnabled", "electricsNameLevelIndex": "retarder_levelIndex",
            "disableWhenThrottleApplied": True, "throttleDisableElectricsName": "throttle", "throttleDisableThreshold": 0.001,
        },
        "driveTechBusRetarderDefault": {"defaultMode": "auto"},
        "actionsEnabled": [["id"], ["increaseRetarderLevel"], ["decreaseRetarderLevel"]],
        "vehicleController": {
            "automaticModes": "PRNDM", "useSmartAggressionCalculation": False, "calculateOptimalLoadShiftPoints": False,
            "transmissionGearChangeDelay": 0.8, "gearboxDecisionSmoothingDown": 2, "gearboxDecisionSmoothingUp": 2,
            # the EcoLife asks the engine to cut torque during upshifts; full torque through a locked
            # converter made every shift kick the bus into pitching on its air springs
            "throttleCoefWhileShifting": 0.35,
            # gentle driving shifts early like a real city bus, kickdown runs up to rated speed
            "highShiftUpRPM": "$dt_bus_kickdown", "highShiftDownRPM": 1400, "lowShiftUpRPM": 1500, "lowShiftDownRPM": 800,
        },
        "flexbodies": [["mesh", "[group]:"], fam["transmission_mesh"]],
        "nodes": [
            ["id", "posX", "posY", "posZ"],
            {"selfCollision": True}, {"collision": True}, {"nodeWeight": 80}, {"frictionCoef": 0.5},
            {"nodeMaterial": "|NM_METAL"}, {"group": g},
            ["tra2r", -0.22, 4.15, 0.28], ["tra2l", 0.22, 4.15, 0.28], ["tra1", -0.05, 4.28, 0.562],
            ["tra3r", -0.15, 4.4, 0.73], ["tra3l", 0.15, 4.4, 0.73],
            {"group": ""},
        ],
        "beams": [
            ["id1:", "id2:"],
            {"beamPrecompression": 1, "beamType": "|NORMAL", "beamLongBound": 1, "beamShortBound": 1},
            {"beamSpring": 20001000, "beamDamp": 5000}, {"beamDeform": 250000, "beamStrength": "FLT_MAX"},
            ["tra1", "tra2r"], ["tra1", "tra2l"], ["tra1", "tra3r"], ["tra1", "tra3l"], ["tra2r", "tra2l"],
            ["tra3r", "tra3l"], ["tra2r", "tra3r"], ["tra2l", "tra3l"], ["tra2r", "tra3l"], ["tra2l", "tra3r"],
            ["tra1", "en2r"], ["tra1", "en2l"], ["tra3l", "en1l"], ["tra3r", "en1r"],
            ["tra2r", "en2r"], ["tra2r", "en2l"], ["tra2r", "en4r"], ["tra2r", "en4l"],
            ["tra2l", "en2r"], ["tra2l", "en2l"], ["tra2l", "en4r"], ["tra2l", "en4l"],
            ["tra3r", "en2r"], ["tra3r", "en2l"], ["tra3r", "en4r"], ["tra3r", "en4l"],
            ["tra3l", "en2r"], ["tra3l", "en2l"], ["tra3l", "en4r"], ["tra3l", "en4l"],
            {"beamPrecompression": 1, "beamType": "|NORMAL", "beamLongBound": 1, "beamShortBound": 1},
            {"beamSpring": 4001000, "beamDamp": 2500}, {"beamDeform": 50000, "beamStrength": 295000},
            ["tra2l", "fs15l"], ["tra2r", "fs15r"], ["tra1", "fs15l"], ["tra1", "fs15r"], ["tra2l", "fs15r"], ["tra2r", "fs15l"],
            {"beamPrecompression": 1, "beamType": "|NORMAL", "beamLongBound": 1, "beamShortBound": 1},
        ],
    }


def driveshaft_part(fam):
    d = fam["driveshaft"]
    return {
        "information": info("Rear Driveshaft (retarder output)", 450),
        "slotType": d["slot"],
        "powertrain": [
            ["type", "name", "inputName", "inputIndex"],
            ["torsionReactor", "torsionReactorR", "retarder", 1, {}],
            ["shaft", "driveshaft", "torsionReactorR", 1, {"breakTriggerBeam": "driveshaft", "uiName": "Rear Driveshaft",
                                                           "electricsName": "driveshaft", "friction": 1}],
        ],
        "torsionReactorR": {"torqueReactionNodes:": ["en4l", "en3l", "en1r"]},
        "props": [
            ["func", "mesh", "idRef:", "idX:", "idY:", "baseRotation", "rotation", "translation", "min", "max", "offset", "multiplier"],
            ["driveshaft", d["mesh"], "ax2r", "ax2l", "tra1", {"x": 90, "y": 0, "z": 0}, {"x": 0, "y": 1, "z": 0},
             {"x": 0, "y": 0, "z": 0}, -360, 360, 0, 1, {"breakGroup": "driveshaft", "deformGroup": "driveshaft", "optional": True}],
        ],
        "beams": [
            ["id1:", "id2:"],
            {"beamPrecompression": 1, "beamType": "|BOUNDED", "beamLongBound": 0.05, "beamShortBound": 0.05},
            {"beamDeform": 4000, "beamStrength": 6000}, {"beamSpring": 0, "beamDamp": 0},
            {"beamLimitSpring": 5001000, "beamLimitDamp": 500},
            ["ax2", "tra1", {"name": "driveshaft", "optional": True, "breakGroup": "driveshaft", "deformGroup": "driveshaft"}],
            {"beamType": "|NORMAL", "beamLongBound": 1.0, "beamShortBound": 1.0},
        ],
    }


def shock_part(s):
    axle = s["axle"]
    var = "$dt_bus_damp_" + axle
    d, r, df, rf = DAMPING[axle]
    label = {"F": "Front", "R": "Rear", "RR": "Tag Axle"}[axle]
    mesh_break = s.get("mesh_break", s["break"])
    return {
        "information": info("%s Shocks (adjustable)" % label, 1400),
        "slotType": s["slot"],
        "variables": [VAR_HEADER, variable(var, "x", DAMPING_DEFAULT[axle], 0.8, 2.2, "%s damping" % label,
                                           "1.0 = stock. Higher = less pitching, harsher over bumps", 0.05)],
        "flexbodies": [
            ["mesh", "[group]:", "nonFlexMaterials"],
            {"deformGroup": mesh_break, "deformMaterialBase": "citybus", "deformMaterialDamaged": "invis"},
            s["mesh"],
            {"deformGroup": "", "deformMaterialBase": "", "deformMaterialDamaged": ""},
        ],
        "beams": [
            ["id1:", "id2:"],
            {"beamPrecompression": 1, "beamType": "|BOUNDED", "beamLongBound": 1, "beamShortBound": 1},
            {"beamSpring": 0, "beamDeform": 50000, "beamStrength": 150000},
            {"beamLimitSpring": 0, "beamLimitDamp": 0},
            {"breakGroup": s["break"]},
            {"deformGroup": s["break"], "deformationTriggerRatio": 0.1},
            {"breakGroupType": 1},
            {"beamDamp": "$=%d*%s" % (d, var), "beamDampRebound": "$=%d*%s" % (r, var),
             "beamDampFast": "$=%d*%s" % (df, var), "beamDampReboundFast": "$=%d*%s" % (rf, var),
             "beamDampVelocitySplit": 0.1, "dampCutoffHz": 500},
        ] + [list(b) for b in s["beams"]] + [
            {"breakGroupType": 0},
            {"deformGroup": "", "deformationTriggerRatio": ""},
            {"breakGroup": ""},
            {"beamPrecompression": 1, "beamType": "|NORMAL", "beamLongBound": 1, "beamShortBound": 1},
        ],
    }


def load_part(fam, load):
    """Standing passengers as ballast on the low floor. Seated ones come from the seat occupant slots."""
    rows = load["rows"]
    all_rows = sorted(load["y"])
    nodes = [["id", "posX", "posY", "posZ"], {"collision": False}, {"selfCollision": False},
             {"nodeMaterial": "|NM_METAL"}, {"frictionCoef": 0.5},
             {"nodeWeight": "$=1+$dt_bus_standees*75/%d" % (len(rows) * 2)}, {"group": ""}]
    beams = [["id1:", "id2:"], {"beamPrecompression": 1, "beamType": "|NORMAL", "beamLongBound": 1, "beamShortBound": 1},
             {"beamSpring": 6001000, "beamDamp": 600}, {"beamDeform": "FLT_MAX", "beamStrength": "FLT_MAX"}]
    for i, row in enumerate(rows, 1):
        k = all_rows.index(row)
        before, after = all_rows[k - 1], all_rows[k + 1]
        for side, x, outer, other in (("r", -0.46, "rr", "l"), ("l", 0.46, "ll", "r")):
            node = "dtpl%d%s" % (i, side)
            nodes.append([node, x, load["y"][row], 0.55])
            for target in ("fm%d%s" % (row, side), "fm%d%s" % (row, outer), "fm%d%s" % (row, other),
                           "fm%d%s" % (before, side), "fm%d%s" % (after, side)):
                beams.append([node, target])
    nodes += [{"collision": True}, {"selfCollision": True}]
    title = load.get("title")
    return {
        "information": info("Standing Passengers" + (" (%s)" % title if title else ""), 0, "jx-grxf"),
        "slotType": fam["prefix"] + "drivetech_load",
        "variables": [VAR_HEADER, variable("$dt_bus_standees", "", 0, 0, 70, "Standing passengers",
                                           "75 kg each, spread over the low floor between the axles", 1)],
        "nodes": nodes,
        "beams": beams,
    }


def family_parts(fam):
    p = fam["prefix"]
    parts = {}
    for key in ENGINES:
        parts["%sturbo_drivetech_%s" % (p, key)] = turbo_part(fam, key)
    parts[p + "engine_ecu_drivetech_cursor9"] = ecu_part(fam)
    parts[p + "finaldrive_R_drivetech"] = finaldrive_part(fam)
    parts[p + "transmission_drivetech_ecolife"] = transmission_part(fam)
    parts[p + "converter_drivetech_ecolife"] = converter_part(fam)
    if fam["driveshaft"]:
        parts[fam["driveshaft"]["slot"] + "_drivetech_retarder"] = driveshaft_part(fam)
    for s in fam["shocks"]:
        parts[s["slot"] + "_drivetech"] = shock_part(s)
    for load in fam["loads"]:
        parts[load["name"]] = load_part(fam, load)
    return parts


def report():
    for key, e in ENGINES.items():
        rows = calibrate(e)
        curve = ", ".join("%d:%d" % (r[0], net_torque(e, r[0], r[1])) for r in rows if 1000 <= r[0] <= 2400)
        peak = max(net_torque(e, r[0], r[1]) * r[0] * math.pi / 30 for r in rows) / 1000
        print("%-14s %s  | peak %.0f kW (%.0f PS)" % (key, curve, peak, peak * 1.3596))


def main():
    for fam in FAMILIES.values():
        path = os.path.join(MOD, fam["file"])
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(family_parts(fam), f, indent=1)
            f.write("\n")
        print("wrote", os.path.relpath(path, ROOT))
    report()


if __name__ == "__main__":
    main()

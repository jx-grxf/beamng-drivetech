<div align="center">

# DriveTech

**BMW-style driving electronics for BeamNG.drive**

Driving experience control · DSC / DTC / DSC OFF · xDrive · realistic automatic shift logic · launch control · auto start-stop · auto hold · ECO PRO coasting · 0-100 timer

![BeamNG.drive](https://img.shields.io/badge/BeamNG.drive-0.39-orange)
![Lua](https://img.shields.io/badge/Lua-LuaJIT%202.1-blue)
![Tests](https://img.shields.io/badge/tests-29%20passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

</div>

---

DriveTech loads into **every** vehicle automatically. Each feature checks whether the car has the hardware it needs and simply stays off otherwise. For the **ETK 800** it also ships ready-made BMW setups (330d xDrive and 320d Touring) with realistic engine, gearbox and chassis data.

## Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Which cars?](#which-cars)
- [ETK 800 as a BMW 3 Series](#etk-800-as-a-bmw-3-series)
- [Settings](#settings)
- [What DriveTech never does](#what-drivetech-never-does)
- [Development](#development)

## Features

| Feature | What it does |
|---|---|
| **Driving experience control** | ECO PRO, COMFORT, SPORT, SPORT+. Also switches the vehicle's own drive modes (dampers, steering, ...). |
| **Throttle map per profile** | ECO PRO soft and progressive, SPORT+ sharp. Pedal to the floor (kickdown) is always 100 %. |
| **Automatic shift logic** | Upshifts promptly after lifting off in D instead of hanging in gear at high rpm. SPORT holds the gear, downshifts when braking hard and never upshifts mid-corner. |
| **DSC / DTC / DSC OFF** | DSC = the car's stock tuning. DTC allows a lot more slip and still catches you. DSC OFF disables traction and stability control (ABS stays on). |
| **xDrive** | Rear-biased preload of the AWD clutch per DSC mode, fully locked when pulling away below 20 km/h. |
| **Launch control** | Automatic/DCT: brake + full throttle, release the brake. Manual: clutch + full throttle, drop the clutch. On torque converter automatics the converter is unloaded so the engine can actually reach launch rpm. Like BMW, only in SPORT+ or with DTC / DSC OFF (configurable). |
| **Auto start-stop** | Engine switches off at a standstill on the brake in D and restarts when you release the brake. ECO PRO and COMFORT only. |
| **Auto hold** | Holds the car after stopping, throttle releases it. Off by default. |
| **ECO PRO coasting** | Between 50 and 160 km/h the engine is decoupled when you lift off and idles while the car rolls. |
| **0-100 timer (UI app)** | 0-100, 0-200, 100-200 km/h and the 1/4 mile. Starts automatically when you pull away. |
| **ETK 800 BMW parts** | 330d and 320d ECUs, adjustable final drive, adaptive chassis with sliders for springs, dampers and anti-roll bars. |

## Installation

1. Download `DriveTech.zip` from [Releases](../../releases).
2. Put the zip **as is** (do not extract) into your mods folder:
   `Documents\BeamNG.drive\current\mods` (or `<your BeamNG user folder>\current\mods`).
3. Start BeamNG (or enable it in the mod manager) and spawn a vehicle.

On the first vehicle DriveTech creates `settings/driveTech.json` with all default values.

## Usage

**Radial menu:** Vehicle features → **DriveTech**. Profile, DSC mode and every feature on/off.

**Key bindings:** Options → Controls → category *Vehicle* → bind the `DriveTech:` actions:

| Action | Suggestion |
|---|---|
| DriveTech: Cycle drive profile | button next to the shifter / wheel button |
| DriveTech: DSC / DTC / DSC OFF | free wheel button |
| DriveTech: Toggle launch control | optional |
| DriveTech: Toggle auto start-stop | optional |
| DriveTech: Toggle auto hold | optional |
| DriveTech: Reload settings | after editing the JSON |

**Adding the 0-100 app (0.39):** `Esc` → **UI Apps** (UI edit mode) → **Add App** in the middle of the screen → pick *DriveTech 0-100 Timer* → place it. To move it later, click the app once to select it, then drag.

## Which cars?

DriveTech works with any car but only uses what the car has:

| Hardware in the car | Features |
|---|---|
| Torque converter automatic | shift logic, throttle map, launch control (with converter unloading), start-stop, auto hold, coasting |
| Dual clutch (DCT) | shift logic, throttle map, launch control, start-stop, auto hold |
| Manual | throttle map, launch control (clutch), auto hold |
| Modern driving electronics (DSE / drivingDynamics) | DSC / DTC / DSC OFF, drive mode linking |
| Electronically clutched AWD | xDrive |

**Recommended stock vehicles**

| Vehicle | Support |
|---|---|
| **ETK 800-Series** | ★★★ everything, plus the BMW setups and chassis parts |
| **ETK K-Series** | ★★★ everything (except the 800 chassis parts) |
| **Cherrier FCV Vivace** | ★★★ DSC/DTC, DCT, AWD |
| **Civetta Scintilla** | ★★★ DSC/DTC, DCT, AWD |
| **Hirochi SBR4** | ★★★ DSC/DTC, DCT, AWD |
| **Bruckell Bastion** | ★★☆ DSC/DTC, torque converter, AWD |
| **Hirochi Sunburst** | ★★☆ DSC/DTC, torque converter / DCT |
| Gavril Grand Marshal, Bruckell LeGran, Soliad Lansdale, ETK I-Series, Ibishu Pessima/Covet, ... | ★☆☆ automatic features (shift logic, throttle map, launch, start-stop, coasting) |

Modded vehicles work the same way as long as they use the same BeamNG components.

## ETK 800 as a BMW 3 Series

The ETK 800 is BeamNG's take on the BMW 3 Series (F30/F31). Its 8-speed automatic even has the exact ratios of the ZF 8HP in the real car. DriveTech adds two ready-made configurations (vehicle selector → ETK 800):

| | DriveTech 330d xDrive Touring | BMW 330d xDrive Touring (F31) |
|---|---|---|
| Power / torque | approx. 265 hp / 570 Nm | 258 PS / 560 Nm (1500-3000 rpm) |
| 0-100 km/h | approx. 5.5 s | 5.4 s |
| Gear ratios | 4.714 / 3.143 / 2.106 / 1.667 / 1.285 / 1.000 / 0.839 / 0.667 | identical |
| Final drive | 2.563 (adjustable) | 2.563 |
| Top speed | 250 km/h limited | 250 km/h limited |

| | DriveTech 320d Touring | BMW 320d Touring (F31 LCI) |
|---|---|---|
| Power / torque | approx. 192 hp / 405 Nm | 190 PS / 400 Nm (1750-2500 rpm) |
| 0-100 km/h | approx. 7.1 s | approx. 7.4 s |
| Gearbox | 8-speed automatic | 8-speed Steptronic |
| Top speed | 230 km/h limited | approx. 230 km/h |

Sources: BMW press kit *330d xDrive Touring* (03/2013), ADAC car catalogue *320d Touring Steptronic* (07/15-02/18). The ETK figures come from BeamNG's own measurements of the stock calibrations the DriveTech ECUs are based on.

**New parts in the parts / tuning menu** (category *DriveTech*):

| Part | Slot | Sliders |
|---|---|---|
| DriveTech 330d ECU | i6 diesel ECU | boost, rev limiter |
| DriveTech 320d ECU | i4 diesel ECU | boost, rev limiter |
| DriveTech front / rear final drive | final drive | ratio 2.2 to 4.1 |
| DriveTech Adaptive Front Struts | front struts | spring rate, bump / rebound |
| DriveTech Rear Springs / Adaptive Rear Shocks | rear springs, rear shocks | spring rate, bump / rebound |
| DriveTech Sway Bars | front / rear sway bar | stiffness (with mm reference) |

The chassis defaults match the ETK ttSport+ adaptive suspension, which is already close to the wheel rates of an F3x with Adaptive M suspension (approx. 26 N/mm front). The drive modes still switch the dampers between soft, regular and hard.

## Settings

Everything can be changed in `<BeamNG user folder>/current/settings/driveTech.json`. After saving, press *DriveTech: Reload settings* in game.

Values for a single vehicle model go under `vehicles.<model>`:

```json
{
  "launch": { "rpm": "auto", "requireSportPlusOrDtc": true },
  "vehicles": {
    "etk800": {
      "launch": { "rpm": 2800 },
      "autoHold": { "enabled": true },
      "profiles": { "default": "sport" }
    }
  }
}
```

<details>
<summary><b>All options</b></summary>

| Section | Option | Default | Meaning |
|---|---|---|---|
| | `enabled` | `true` | DriveTech on/off |
| | `showMessages` | `true` | messages in the top left |
| `profiles` | `default` | `comfort` | profile when you get in |
| | `linkVehicleDriveModes` | `true` | switch the vehicle's drive modes too |
| | `vehicleDriveModeMap` | see file | which vehicle mode belongs to which profile |
| `stability` | `default` | `dsc` | `dsc`, `dtc` or `off` |
| | `dtc.tcSlipThreshold` | `0.3` | allowed wheel slip in DTC |
| | `dtc.yawSlipAngleThreshold` | `0.2` | allowed slip angle in DTC |
| `xdrive` | `dsc/dtc/off.minimumLock` | `0.4/0.3/0.2` | AWD clutch preload (0-1) |
| | `launchLockBelowKmh` | `20` | full lock when pulling away up to this speed |
| `shiftLogic` | `profiles.<p>.holdTime` | `0.2-6 s` | how long the gear is held after lifting off |
| | `profiles.<p>.decay` | `2.5-0.15` | how quickly it upshifts afterwards |
| | `profiles.<p>.floor` | `0-0.55` | minimum sportiness (higher = later shift points) |
| | `cornerHoldLateralAccel` | `3.5` | no upshifts above this lateral acceleration (m/s²) |
| `pedalMap` | `profiles.<p>.exponent` | `1.6-0.75` | curve (>1 soft, <1 sharp) |
| | `profiles.<p>.riseRate` | `1.5-20` | how fast the throttle opens |
| `launch` | `rpm` | `auto` | `auto` or a fixed rpm |
| | `requireSportPlusOrDtc` | `true` | BMW rule: only in SPORT+ or DTC / DSC OFF |
| | `converterHoldCoef` | `0.2` | converter unloading while armed (lower = revs more freely) |
| `startStop` | `profiles` | ECO PRO, COMFORT | profiles where it is active |
| | `stopDelay` | `1.0` | seconds at a standstill before the engine stops |
| `autoHold` | `enabled` | `false` | auto hold |
| | `holdBrake` | `0.6` | brake pressure while holding |
| `coasting` | `minKmh` / `maxKmh` | `50` / `160` | speed range for coasting |

</details>

## What DriveTech never does

- **Nothing on AI and traffic cars.** Features only run while a player sits in the car. Getting out resets everything.
- **Nothing on cars without the hardware.** A car without a torque converter gets no converter features, a car without driving electronics keeps its stock ESC.
- **No overwritten stock files.** DriveTech only adds its own files and parts.
- **No crash because of one feature.** Every feature runs isolated. On an error it is logged, switched off and its changes are undone, everything else keeps running.
- **Cruise control and friends win.** The throttle map steps aside as soon as something else controls the throttle.

## Development

```
mod/                       contents of DriveTech.zip
  lua/vehicle/extensions/auto/driveTech.lua   entry point, loaded for every vehicle
  lua/vehicle/driveTech/config.lua            defaults, JSON load/save
  lua/vehicle/driveTech/features/*.lua        one file per feature
  lua/ge/extensions/core/input/actions/       key bindings
  ui/modules/apps/DriveTechLaunchTimer/       0-100 app
  vehicles/                                   ETK parts and configurations
tests/                     scenario tests with BeamNG mocks (LuaJIT 2.1)
tools/build.py             validates every jbeam/json file and builds dist/DriveTech.zip
```

```bash
pip install lupa
python tests/run_tests.py          # 29 scenarios: launch, shift logic, start-stop, DSC, xDrive, AI safety, ...
python tools/build.py              # validate + build the zip
python tools/build.py --install    # also copy it into the BeamNG mods folder
```

---

DriveTech is a fan project and is not affiliated with BMW AG or BeamNG GmbH. License: [MIT](LICENSE)

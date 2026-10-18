<div align="center">

# DriveTech

**BMW-style driving electronics for BeamNG.drive**

Driving experience control · DSC / DTC / DSC OFF · xDrive · realistic automatic shift logic · launch control · auto start-stop · auto hold · ECO PRO coasting · 0-100 timer

![BeamNG.drive](https://img.shields.io/badge/BeamNG.drive-0.39-orange)
![Lua](https://img.shields.io/badge/Lua-LuaJIT%202.1-blue)
![Tests](https://img.shields.io/badge/tests-34%20passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

</div>

---

DriveTech loads into **every** vehicle automatically. Each feature checks whether the car has the hardware it needs and simply stays off otherwise. For the **ETK 800** it also ships ready-made BMW setups (320d, 330d, 340d and 340i Touring, each with rear-wheel drive or xDrive) with realistic engine, gearbox and chassis data.

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

Everything DriveTech has at a glance:

| Feature | What it does | Where |
|---|---|---|
| **Driving experience control** | ECO PRO, COMFORT, SPORT, SPORT+. Also switches the vehicle's own drive modes (dampers, steering, ...). | radial menu, key binding |
| **Throttle map per profile** | ECO PRO soft and progressive, SPORT+ sharp. Pedal to the floor (kickdown) is always 100 %. | automatic |
| **Automatic shift logic** | Upshifts promptly after lifting off in D instead of hanging in gear at high rpm. SPORT holds the gear, downshifts when braking hard and never upshifts mid-corner. | automatic |
| **DSC / DTC / DSC OFF** | DSC = the car's stock tuning. DTC allows a lot more slip and still catches you. DSC OFF disables traction and stability control (ABS stays on). | radial menu, key binding |
| **xDrive** | Rear-biased preload of the AWD clutch per DSC mode, fully locked when pulling away below 20 km/h. | automatic |
| **Launch control** | Automatic/DCT: brake + full throttle, release the brake. Manual: clutch + full throttle, drop the clutch. On torque converter automatics the converter is unloaded so the engine can actually reach launch rpm. Like BMW, only in SPORT+ or with DTC / DSC OFF (configurable). | radial menu, key binding |
| **Auto start-stop** | Engine switches off at a standstill on the brake in D and restarts when you release the brake. ECO PRO and COMFORT only. | radial menu, key binding |
| **Auto hold** | Holds the car after stopping, throttle releases it. Off by default. | radial menu, key binding |
| **ECO PRO coasting** | Between 50 and 160 km/h the engine is decoupled when you lift off and idles while the car rolls. | automatic in ECO PRO |
| **0-100 timer** | 0-100, 0-200, 100-200 km/h and the 1/4 mile. Starts automatically when you pull away. | UI app *DriveTech 0-100 Timer* |
| **Rain** | Rain with wet roads on any map, light / medium / heavy. Paved surfaces get about 25 % less grip (stock wet asphalt only loses about 6 %). | UI app *DriveTech Rain*, key binding |
| **Aquaplaning** | Optional, only while it rains. Water builds up on the road over time; each tyre floats on its own depending on speed, water depth, tread depth (8 / 5 / 3 / 1.6 mm), tyre pressure and width. Puddles and ruts hold more water, so one side can float before the other. New tyres in 8 mm water float at about 85-90 km/h, tyres at 1.6 mm already at about 60-65 km/h. | UI app *DriveTech Rain*, key binding |
| **ETK 800 BMW setups** | 320d, 330d, 340d and 340i Touring, each as rear-wheel drive and xDrive (8 configurations), with real engine, gearbox and chassis data. | vehicle selector → ETK 800 |
| **ETK 800 BMW parts** | 320d, 330d, 340d and 340i ECUs, ZF 8HP50 gearbox, adjustable final drive, adaptive chassis with sliders for springs, dampers and anti-roll bars. | parts menu, category *DriveTech* |
| **F31 instrument cluster** (beta) | BMW F31-style cluster in orange or white, drawn live: needles, warning lamps, DriveTech profile, DSC mode, auto-stop and launch control. Needs the *ETK 800 Improved Interior* mod by Milendur. | parts menu, slot *gauges* |

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
| DriveTech: Toggle rain | category *Gameplay*, optional |
| DriveTech: Toggle aquaplaning | category *Gameplay*, optional |

**Adding the 0-100 app (0.39):** `Esc` → **UI Apps** (UI edit mode) → **Add App** in the middle of the screen → pick *DriveTech 0-100 Timer* → place it. To move it later, click the app once to select it, then drag. The *DriveTech Rain* app is added the same way.

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

The ETK 800 is BeamNG's take on the BMW 3 Series (F30/F31). Its stock 8-speed automatic has the exact ratios of the ZF 8HP70 used in the 330d and 335d. DriveTech adds eight ready-made F31 LCI Touring configurations (vehicle selector → ETK 800), every engine as rear-wheel drive and as xDrive:

| Configuration | Engine | Power / torque (BMW) | Gearbox | Final drive | 0-100 km/h (BMW) |
|---|---|---|---|---|---|
| DriveTech 320d Touring | i4 diesel | 190 PS / 400 Nm | ZF 8HP50 | 2.813 | 7.5 s |
| DriveTech 320d xDrive Touring | i4 diesel | 190 PS / 400 Nm | ZF 8HP50 | 2.813 | 7.7 s |
| DriveTech 330d Touring | i6 diesel | 258 PS / 560 Nm | ZF 8HP70 | 2.563 | 5.6 s |
| DriveTech 330d xDrive Touring | i6 diesel | 258 PS / 560 Nm | ZF 8HP70 | 2.563 | 5.4 s |
| DriveTech 340d Touring | i6 diesel | 313 PS / 630 Nm | ZF 8HP70 | 2.563 | – (no real RWD car) |
| DriveTech 340d xDrive Touring | i6 diesel | 313 PS / 630 Nm | ZF 8HP70 | 2.563 | 4.9 s |
| DriveTech 340i Touring | i6 petrol (B58) | 326 PS / 450 Nm | ZF 8HP50 | 2.813 | 5.1 s |
| DriveTech 340i xDrive Touring | i6 petrol (B58) | 326 PS / 450 Nm | ZF 8HP50 | 2.813 | approx. 5.0 s |

- **ZF 8HP50** (320d, 340i): 5.000 / 3.200 / 2.143 / 1.720 / 1.314 / 1.000 / 0.822 / 0.640, reverse 3.456
- **ZF 8HP70** (330d, 340d): 4.714 / 3.143 / 2.106 / 1.667 / 1.285 / 1.000 / 0.839 / 0.667 (stock ETK gearbox)
- **340d:** the F31 never had a 340d. The diesel top model was the 335d xDrive (N57 twin turbo, 313 PS at 4400 rpm, 630 Nm from 1500 to 2500 rpm), and the 340d uses exactly its data. A rear-wheel drive version did not exist in the F31 LCI either, so the 340d Touring is a what-if car.
- **340i:** B58 with 326 PS from 5500 to 6500 rpm and 450 Nm from 1380 to 5000 rpm. It runs on staggered 19" wheels (245/35 front, 265/35 rear).
- 330d, 340d and 340i are limited to 250 km/h, the 320d to 230 km/h.

The DriveTech ECUs are tuned so the in-game torque curve matches BMW's: 340i approx. 328 PS / 452 Nm (flat from 2000 to 5000 rpm), 340d approx. 315 PS / 636 Nm. 320d and 330d come from BeamNG's own measurements of the stock calibrations the DriveTech ECUs are based on (approx. 192 hp / 405 Nm and 265 hp / 570 Nm).

Sources: BMW Group technical data *BMW 3 Series Touring LCI (F31)* (edition 11/2018: gear ratios, final drives, power, torque, 0-100 km/h), BMW press kit *330d xDrive Touring* (03/2013), ADAC car catalogue *340i Touring xDrive Steptronic* (07/15-06/18), auto-data.net (340i xDrive Touring 0-100 km/h).

**New parts in the parts / tuning menu** (category *DriveTech*):

| Part | Slot | Sliders |
|---|---|---|
| DriveTech 340i ECU | i6 petrol ECU | boost, rev limiter |
| DriveTech 340d ECU | i6 diesel ECU | boost, rev limiter |
| DriveTech 330d ECU | i6 diesel ECU | boost, rev limiter |
| DriveTech 320d ECU | i4 diesel ECU | boost, rev limiter |
| DriveTech 8-Speed Automatic (ZF 8HP50) | transmission | – (petrol and diesel version) |
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
  lua/ge/extensions/driveTechRain.lua         rain, wet grip, water film, loaded by scripts/driveTech/modScript.lua
  lua/vehicle/extensions/auto/driveTechAquaplaning.lua   aquaplaning per tyre
  lua/vehicle/driveTech/aquaplaning.lua       aquaplaning model (critical speed, puddles)
  ui/modules/apps/DriveTechLaunchTimer/       0-100 app
  ui/modules/apps/DriveTechRain/              rain + aquaplaning app
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

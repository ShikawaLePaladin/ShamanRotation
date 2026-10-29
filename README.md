# ShamanRotation

One-key **Elemental Shaman** rotation for WoW 1.12 (Turtle WoW / OctoWoW), with mono / AoE switching, totem combos, a burst button, relic swapping and an on-screen HUD.
Uses **Nampower**, **SuperWoW** and **UnitXP** when present (all optional, everything is wrapped in `pcall` and falls back cleanly).

The priorities come from the **real parses of the best Elementals on OctoWoW** (Chronicle raid logs) and from the **server's own spell data** (Spell.dbc / spell_template), not from guesswork.
See [DESIGN.md](DESIGN.md) for every proven fact, every estimate and what is still unverified.

## Install
Copy the `ShamanRotation` folder into `Interface\AddOns`, restart the game, then `/shamrot menu` > **Touches** tab: click a button and press the key you want (keyboard, mouse buttons 3/4/5, wheel, with Shift / Ctrl / Alt). You can also bind them in *Key Bindings > Shaman Rotation*.

## What it does
| | |
|---|---|
| **Rotation** | Flame Shock kept up (15 s DoT, refreshed near 4 s left) > Chain Lightning on every cooldown > Lightning Bolt filler. Earth Shock is used to **interrupt** (the top players only cast it ~2 times a minute). |
| **AoE** | Automatic from N enemies within 10 m **of the target** (nameplates + UnitXP), or forced on/off. Earthquake (hits the target and 10 m around it) then Chain Lightning. |
| **Immunities** | Learned from the game's "X is immune" message and remembered per mob. `/shamrot immune fire|nature|frost` to set by hand. No hard-coded list. |
| **Burst** | Elemental Mastery + Blood Fury (instant, no GCD), optional trinkets. Arms itself if they are on cooldown. |
| **Totems** | Combos: caster, melee, AoE (Magma), Nova, anti-fear (Tremor), poison / disease cleansing. One totem per press **or all four with a single press, in the same frame** (each element has its own GCD category on the server: fire 105, earth 106, water 107, air 108), timers, optional fire-totem upkeep in combat that costs no rotation press. |
| **Shield** | Water Shield (default) or Earth Shield re-applied automatically when it is gone (out of combat, and in combat for one GCD), not while you drink or ride. |
| **Relics** | `main` (one relic, equipped out of combat) or `spell` (one relic per spell). **Wait mode only**: equipping in combat costs a 1.5 s GCD (proven in the server source), so the swap takes one press and the spell leaves on the next. |
| **Totem range** | A buff totem (30 m aura radius) that is too far from you, or destroyed, is re-dropped automatically (out of combat, optionally in combat). Needs UnitXP + friendly nameplates to find your totem; otherwise only the timer decides. |
| **HUD** | GCD bar, Flame Shock timer, shock / Chain Lightning / Earthquake / Elemental Mastery / Blood Fury cooldowns, the four totem slots. |
| **Menu** | Fixed-size window with scrolling tabs, tooltips with the default value on every option, minimap button. |

## Commands
`/shamrot` (or `/shaman`): `menu`, `hud`, `status`, `aoe [auto|on|off]`, `burst`, `totems [preset]`, `relic [mode off|main|spell]`, `immune fire|nature|frost [clear]`, `set <key> <value>`, `debug`, `trace`, `reset`.

## Things worth knowing (verified on the server data)
* Flame Shock, Earth Shock and Frost Shock **share one 6 s cooldown and each has a 1.5 s GCD**: an Earth Shock cannot be slipped between GCDs.
* Earthquake (talent): 2.5 s cast, 16 s cooldown, cast on the target, no ground cursor. Chain Lightning: 2.5 s cast, 6 s cooldown. Molten Blast refreshes Flame Shock (210 mana) and is off by default: its place in the rotation is a deduction.
* Totem of Crackling Thunder: 10 % on Lightning Bolt for +8 % attack **and casting** speed for 8 s.

* Totem GCDs are **per element** (categories 105-108), so all four totems of a combo go out in one press; Windfury Totem rank 3 and Fire Nova use the normal GCD (133).
* Credit: the per-element GCD was spotted thanks to shaga's CallOfElements (GPL-3.0) on the OctoWoW git.

## Not verified / limits
* Totem tracking is a **timer** (the 1.12 client cannot tell whether a totem was destroyed).
* Not tested in the live client yet: the in-game rendering of the menu and HUD. The logic is covered by simulation tests.
* Set / cape procs mentioned by players (+95 spell power set proc, +150 mana cape proc) could not be found in the server data.

## Tests
`sh run_tests.sh` (needs Node.js with `fengari`): Lua 5.0 lint + three simulated suites (rotation, menu / HUD, relics) on a strict 1.12 API mock with GCD, shared shock cooldown, cast times and mana.

Author: Shikiwa. Credits: spell and item data from the OctoWoW server; combat statistics from octo.chronicleclassic.com.

# VeltoKit — Godot demo

Sample Godot 4 project with the **VeltoKit** plugin for Triki BLE motion.

## Run demos (desktop — simulator)

1. Install [Godot 4.2+](https://godotengine.org/)
2. Open this folder as project (`project.godot`)
3. Enable plugin **VeltoKit** if prompted
4. **Play** (F5) — domyślnie **`demos/triki_pong/triki_pong.tscn`** (Pong / brick-breaker, żyro X → paletka)
5. Alternatywnie: `demos/gyro_cube/gyro_cube.tscn` — obracający się sześcian 3D

Na desktopie dane pochodzą z **symulatora** VeltoKit (`sim=true` w konsoli). Na Androidzie + natywny plugin BLE — prawdziwe Triki.

**Sterowanie Triki Pong:** pochyl czapkę w lewo/prawo (oś X żyro). Fallback: strzałki / A D. Po wygranej lub przegranej: **Enter** — nowa gra.

## Use in your game

Copy `addons/veltokit_plugin/` into your project. See `addons/veltokit_plugin/README.md`.

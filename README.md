![GitHub last commit](https://img.shields.io/github/last-commit/Ma-Ko-dev/Turn-Based-Prototype?style=flat-square)
![GitHub issues](https://img.shields.io/github/issues/Ma-Ko-dev/Turn-Based-Prototype?style=flat-square)
![GitHub stars](https://img.shields.io/github/stars/Ma-Ko-dev/Turn-Based-Prototype?style=flat-square)
![License](https://img.shields.io/github/license/Ma-Ko-dev/Turn-Based-Prototype?style=flat-square)
![Godot](https://img.shields.io/badge/Godot-4.6-blue?logo=godot-engine&logoColor=white&style=flat-square)
![Language](https://img.shields.io/badge/Language-GDScript-478cbf?style=flat-square)


# Turn-Based-Prototype

A tactical 2D turn-based prototype built with **Godot 4.6**. This project is the foundation for a grid-based RPG, focusing on clean mechanics and scalable combat systems.

## 🚀 Core Features

* **Grid-Based Movement**: Precision movement using `AStarGrid2D`.
* **Tactical AI**: Enemies evaluate the grid to find the best position to engage the player, including basic bodyblocking logic.
* **Dynamic Initiative System**: Combat order determined by an initiative roll (d20 + bonus), easily managed via a central `TurnManager`.
* **Resource-Driven Units**: Unit stats (HP, Movement, Initiative) are stored in `.tres` files, allowing for quick creation of new enemy types.
* **Pathfinding with Costs**: Different tiles can have different movement costs, integrated directly into the AStar logic.
* **Inherited Level System:** A base level scene that allows for rapid creation of new maps while keeping core layers and logic intact.
* **Automatic Spawning:** Units (Player & Enemies) are placed automatically via Marker2D nodes during level initialization.

## 🛠️ Technical Overview

* **Languages**: 100% GDScript.
* **Architecture**: Signal-driven UI and state management for decoupled systems.
* **Assets**: Compatible with 16x16 tilesets (optimized for Kenney's 1-Bit asset).

## ⚖️ License

This project uses a dual-license model:

- Source code is licensed under the MIT License.
- Game mechanics and rules are licensed as Open Game Content
  under the Open Game License v1.0a.

See NOTICE.md for details.

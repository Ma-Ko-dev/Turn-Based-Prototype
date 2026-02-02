# Turn-Based-Prototype

A tactical 2D turn-based prototype built with **Godot 4.6**. This project is the foundation for a grid-based RPG, focusing on clean mechanics and scalable combat systems.

## 🚀 Core Features

* **Grid-Based Movement**: Precision movement using `AStarGrid2D`.
* **Tactical AI**: Enemies evaluate the grid to find the best position to engage the player, including basic bodyblocking logic.
* **Dynamic Initiative System**: Combat order determined by an initiative roll (d20 + bonus), easily managed via a central `TurnManager`.
* **Resource-Driven Units**: Unit stats (HP, Movement, Initiative) are stored in `.tres` files, allowing for quick creation of new enemy types.
* **Pathfinding with Costs**: Different tiles can have different movement costs, integrated directly into the AStar logic.

## 🛠️ Technical Overview

* **Languages**: 100% GDScript.
* **Architecture**: Signal-driven UI and state management for decoupled systems.
* **Assets**: Compatible with 32x32 tilesets (optimized for Kenney's assets).

## 📖 How to Use

1. Clone the repository.
2. Open the project in Godot 4.x.
3. Check the `Resources/` folder to modify unit stats.
4. Press `Enter` in Exploration mode to cycle turns or `Tab` to force-start combat.

## 📺 Development Progress
<details>
  <summary>Click to view clips from early development</summary>
  
  ### Early Prototypes (Grid & Movement)
  
  
  ### Current Version (AI Movement)
  
</details>

## ⚖️ License

This project is licensed under the MIT License - see the `LICENSE` file for details.

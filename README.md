# 🐦 Flappy Bird (8086 Assembly)

![Assembly](https://img.shields.io/badge/Language-8086%20Assembly-blue)
![Platform](https://img.shields.io/badge/Platform-DOS%20%7C%20DOSBox-green)
![Graphics](https://img.shields.io/badge/Graphics-VGA%20Mode%2013h-orange)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)
![License](https://img.shields.io/badge/License-Educational-lightgrey)

A fully playable **Flappy Bird-style game** built entirely in **8086 Assembly Language** using **real-mode DOS** and **VGA graphics (Mode 13h)**.

This project showcases how low-level systems can be used to create a complete game — including **graphics rendering, physics, input handling, sound, and game logic** — without any external libraries.

---

## 🎮 Features

- 🐤 Smooth bird movement with gravity and flap mechanics  
- 🚧 Moving pipes with randomized gaps  
- 📈 Dynamic difficulty scaling  
- 🔢 Score tracking + High Score system  
- ⏸️ Pause / Resume functionality  
- 💥 Collision detection system  
- 🔊 Sound effects using PC Speaker:
  - Flap sound  
  - Score sound  
  - Crash sound  
- 🎨 Custom pixel rendering (no sprites, pure framebuffer drawing)  
- 🧾 Text rendering (GAME OVER, SCORE, BEST, etc.)

---

## 🖼️ Screenshots

> *(Add your screenshots in a `/screenshots` folder and update paths below)*

### 🎮 Gameplay
![Gameplay](screenshots/gameplay.png)

### ⏸️ Pause Screen
![Pause](screenshots/pause.png)

### 💀 Game Over Screen
![Game Over](screenshots/gameover.png)

---

## 🎮 Controls

| Key        | Action          |
|------------|----------------|
| `Space`    | Flap (jump)    |
| `P` / `ESC`| Pause / Resume |
| `Enter`    | Restart game   |
| `ESC`      | Exit game      |

---

## 🛠️ Technologies Used

- **8086 Assembly Language**
- **BIOS & DOS Interrupts**
  - `INT 10h` → Graphics
  - `INT 16h` → Keyboard Input
  - `INT 21h` → Program Exit
  - `INT 1Ah` → Timer (Randomness)
- **VGA Mode 13h**
  - Resolution: 320x200
  - 256 Colors
- **PC Speaker** for sound effects

---

## 🧠 Concepts Demonstrated

- Game loop design  
- Real-time input handling  
- Memory-mapped graphics (`A000h`)  
- Collision detection  
- Basic physics (gravity, velocity)  
- Procedural random generation  
- Low-level sound programming  
- Double buffering (manual redraw)

---
  
  ## 🚀 How to Run
  
  ### 🔧 Requirements
  - DOSBox (or any DOS emulator)
  - TASM / MASM assembler
  
  ### ▶️ Steps
  
  ```bash
  tasm game.asm
  tlink game.obj
  game.exe

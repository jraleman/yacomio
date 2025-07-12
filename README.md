# YaComio!

## Overview:

This incremental/idle game will simulate evolutionary progress, beginning from microbial life and advancing through photosynthesis, complex multicellular organisms, up to human civilization. Gameplay revolves around accumulation of evolutionary points (EP), unlocking milestones, and progressively complex lifeforms and technologies.

---

## Game Progression Structure:

### Stage 1: Microbial Beginnings

* **Starting Point**: Player starts with basic microbial life.
* **Core Resource**: Evolution Points (EP) gained passively.
* **Actions & Upgrades**:

  * Increase EP generation rate.
  * Unlock RNA, DNA replication, simple membranes.
  * First idle interactions: "tap" microbes to boost EP briefly.

### Stage 2: Photosynthesis

* **Milestone**: Unlock photosynthesis by accumulating enough EP.
* **Resource Addition**: Light Energy (passive generation during daytime cycles).
* **Actions & Upgrades**:

  * Improve chloroplast efficiency.
  * Create simple aquatic plants and algae.
  * Photosynthesis boosts EP generation exponentially.

### Stage 3: Complex Lifeforms

* **Milestone**: Develop multicellularity by combining microbial upgrades.
* **Resource Addition**: Biological Complexity Points (BCP).
* **Actions & Upgrades**:

  * Unlock marine life (e.g., sponges, jellyfish, fish).
  * Land colonization (amphibians, insects, plants).
  * Complex biological systems (nervous systems, organs, sensory upgrades).
* Special events (e.g., Cambrian Explosion) offer rapid progress.

### Stage 4: Terrestrial Dominance

* **Milestone**: Accumulate sufficient BCP to support terrestrial ecosystems.
* **Resource Addition**: Biodiversity Points (BP).
* **Actions & Upgrades**:

  * Dinosaur age, mammals, flowering plants.
  * Unlock environmental adaptations (e.g., warm-bloodedness, feathers).
  * Survive extinction events for temporary challenges and rewards.

### Stage 5: Human Evolution

* **Milestone**: Mammals evolve towards primates and eventually humans.
* **Resource Addition**: Intelligence Points (IP).
* **Actions & Upgrades**:

  * Cognitive and social upgrades (language, tools, agriculture).
  * Develop civilizations, unlock cultural, scientific, technological advancements.
  * Special idle mechanics: culture production, population growth.

---

## Game Mechanics:

### Incremental Progression:

* Automatic generation of resources (EP, BCP, BP, IP).
* Upgrades and unlockables increase passive income rates.

### Idle Features:

* Offline progress calculation.
* Periodic in-game boosts or "Golden Ages" triggered by milestones.
* Special taps/actions providing short-term resource bursts.

### Prestige System:

* Allow players to restart from microbial life but retain bonuses.
* "Evolutionary leaps" offer permanent percentage increases in resource generation.

---

## Tech Stack Recommendation:

* **Frontend**: React or Vue.js for interactive UI.
* **Backend** (optional for more complexity): Node.js + FastAPI (Python) for API management.
* **Local Simulation Engine**: Python for complex calculation simulations (can be mocked in development).
* **Data Storage**: IndexedDB or localStorage for lightweight, persistent player progress.

---

## Development Steps:

### 1. Initial Project Setup:

* Set up React frontend scaffolding.
* Integrate local storage for saving/loading player data.

### 2. Resource Generation Logic:

* Establish base incremental logic (EP generation, upgrades).
* Create a clear UI displaying resources and upgrade options.

### 3. Unlockable Content & Milestones:

* Design a progression tree clearly visualized in the UI.
* Implement upgrade paths and dependencies.

### 4. Idle Mechanics:

* Integrate offline calculation and catch-up logic.
* Create passive boost mechanics activated by milestones or player actions.

### 5. Prestige and Leaps:

* Develop a prestige system, allowing resets for faster progression.
* Ensure meaningful and engaging player rewards.

---

## AI-Driven Design Assistance:

* Leverage ChatGPT to:

  * Generate realistic scientific descriptions and fun facts for upgrades.
  * Provide balanced numerical progressions for incremental mechanics.
  * Suggest engaging UI/UX enhancements and thematic consistency.

---

## Suggested Milestone Roadmap:

* **MVP (Initial Release)**:

  * Basic microbial to photosynthesis stages.
  * Fundamental resource generation and idle mechanics.

* **Version 1.1**:

  * Complex organisms and terrestrial lifeforms.
  * Enhanced visual representation and animations.

* **Version 1.2**:

  * Human evolution and civilization features.
  * Prestige mechanics for replayability.

* **Future Expansions**:

  * Space exploration, planetary colonization.
  * Multiverse or alternative evolution paths.

---

## Example Interaction Prompts (ChatGPT Assistance):

* *"Suggest an incremental upgrade pathway from microbes to multicellularity."*
* *"Provide balanced resource generation formulas for idle gameplay."*
* *"Generate concise and entertaining upgrade descriptions related to early Earth lifeforms."*

# Hanabi Web App (Flutter) — spec.md

Goal: Build a web app to play **Hanabi** (co-op fireworks card game) with the **basic rules** implemented faithfully.

---

## 1) Game overview

Hanabi is a **cooperative** game where players see **everyone else’s cards but not their own**.  
As a team, players build **5 fireworks piles** (one per color) in **ascending order 1 → 5**, aiming for a perfect score of **25**.

Key constraints:
- Communication is limited via **clue (information) tokens**.
- Mistakes cost **fuse (error) tokens**; too many ends the game immediately.

---

## 2) Components and terminology

### 2.1 Suits / colors
Basic game uses **5 colors** (commonly: Red, Yellow, Green, Blue, White).

### 2.2 Card distribution (per color)
For each color suit, the card counts are:
- 1 ×3
- 2 ×2
- 3 ×2
- 4 ×2
- 5 ×1

Total: 10 cards per color × 5 colors = **50 cards**.

### 2.3 Tokens
- **Clue tokens**: start at **8**, range **0..8**
- **Fuse tokens**: start at **3**, range **0..3**

---

## 3) Setup

1. Create and shuffle the **50-card deck** (exclude any optional/variant suits).  
2. Place:
   - Clue tokens = **8**
   - Fuse tokens = **3**
3. Deal hands (cards are held **facing outward**, so *other players can see them*):
   - **2–3 players:** 5 cards each
   - **4–5 players:** 4 cards each
4. Create:
   - **Discard pile** (empty)
   - **Fireworks area**: 5 piles, initially empty

---

## 4) Turn structure

Play proceeds clockwise. On your turn, you must take **exactly one** action:

### Action A — Give a clue (costs 1 clue token)
- Choose **one other player**.
- Choose **either** a **color** *or* a **number**.
- Point out **all** cards in that player’s hand that match the chosen color/number.
- The clue must be **complete and correct**.

Rules:
- If clue tokens are **0**, you cannot give a clue.
- The UI should visually mark the indicated cards and store the received information as “known possibilities” for that player’s own cards.

### Action B — Discard a card (gains 1 clue token)
- Choose 1 card from your hand → move it to the discard pile.
- Increase clue tokens by **+1** (up to max 8).
- Draw 1 card from the deck to refill your hand (if the deck is not empty).

### Action C — Play a card
- Choose 1 card from your hand → attempt to add it to the fireworks area.
- A play is **successful** if:
  - It is a **1** of a color whose pile is empty, OR
  - It is the **next number** on that color pile (e.g., play 3 on top of a 2).
- If successful:
  - Add to that color pile.
  - If the card is a **5**, gain **+1 clue token** (up to max 8).
- If **not** successful:
  - Move the card to the discard pile.
  - Decrease fuse tokens by **-1**.
- Draw 1 card from the deck to refill your hand (if deck not empty).

---

## 5) End of the game

The game ends in one of these ways:

1. **Immediate loss:** fuse tokens reach **0** (the team “explodes”).  
2. **Immediate win:** all five color piles are completed up to **5** (score 25).  
3. **Deck exhausted:** when the **last card is drawn**, each player (including the one who drew it) takes **one final turn**.  
   - During this final round, no new cards are drawn.

---

## 6) Scoring

Score = sum of the **highest number** in each color pile at game end.  
- Each completed pile contributes 5 points, max total **25**.
- If the game ended by explosion, you may still display the score, but mark the result as **Loss**.

---

## 7) App requirements (Flutter Web)

### 7.1 Platforms
- Flutter Web (single-page app)
- Responsive: desktop-first, but usable on tablet

### 7.2 Game modes (MVP)
- **Local pass-and-play** (same device) OR
- **Online multiplayer** (recommended if you have time): real-time sync

> Choose one for MVP. If online, implement a room code flow.

### 7.3 Screens
1. **Home**
   - Create room / Join room (if online)
   - New local game (if local)
2. **Lobby**
   - Player list, ready toggle, start game
3. **Game Table**
   - Fireworks piles (5 columns)
   - Token trackers (clue/fuse)
   - Deck count + “final round” indicator
   - Discard pile viewer (by color/number counts + latest discards)
   - Turn indicator + action log
   - Player hands:
     - **Other players:** show card faces
     - **Current player:** show card backs + knowledge overlays
4. **Game Over**
   - Win/Loss + score + breakdown by pile
   - Timeline/action log export (optional)

### 7.4 Core UX details
- **Clue UI:**  
  - Tap a player → choose “Color” or “Number” → select value → UI highlights all matching cards automatically → confirm.
- **Discard/Play UI:**  
  - Tap one of your card slots → choose “Play” or “Discard” → resolve.
- **Knowledge overlay for self-hand:**  
  - Each card slot stores: knownColor?, knownNumber?, and/or candidate sets.
  - Render small badges like “R?” “?3” and strikethrough candidates.

### 7.5 Data model (suggested)
```ts
// conceptual types (implement in Dart)
enum ColorSuit { red, yellow, green, blue, white }

class Card {
  final ColorSuit color;
  final int number; // 1..5
}

class PlayerState {
  final String id;
  final String name;
  List<Card> hand; // actual cards (hidden to the player client if online)
  List<CardKnowledge> knowledge; // parallel to hand slots
}

class CardKnowledge {
  ColorSuit? knownColor;
  int? knownNumber;
  Set<ColorSuit> possibleColors;
  Set<int> possibleNumbers;
}

class GameState {
  int clueTokens; // 0..8
  int fuseTokens; // 0..3
  List<Card> deck; // face-down
  List<Card> discard;
  Map<ColorSuit, List<Card>> piles; // ascending
  List<PlayerState> players;
  int currentPlayerIndex;
  bool finalRound;
  int finalTurnsRemaining; // if finalRound true
  List<String> actionLog;
}
```

### 7.6 Rule enforcement checklist
- [ ] Hand size based on player count (5 for 2–3, 4 for 4–5)
- [ ] Clues must target exactly one player and be complete for that value
- [ ] No clue action when clueTokens == 0
- [ ] Discard restores exactly +1 clue token (cap 8)
- [ ] Misplay consumes fuse and discards card
- [ ] Successful play of a 5 restores +1 clue token (cap 8)
- [ ] Deck exhaustion triggers final round logic
- [ ] End conditions: explosion / perfect completion / post-final-round

---

## 8) Non-goals (for MVP)
- Variant suits (rainbow/multicolor) and advanced conventions
- AI bots
- Replay analysis / hinting assistants

---

## 9) References (rules)
- Public rules summary and setup/action descriptions: Wikipedia “Hanabi (card game)”  
- Rules PDF versions commonly mirror the standard token counts, actions, and endgame timing.
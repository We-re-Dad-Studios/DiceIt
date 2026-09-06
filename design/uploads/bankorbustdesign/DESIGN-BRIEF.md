# Bank or Bust — visual design brief

Paste this to Claude Design along with the screenshots in this folder.

---

## The prompt

I need a visual design pass on **Bank or Bust**, a multiplayer push-your-luck
dice game that runs in the browser. The game is fully functional — everything in
the attached screenshots works — but it's using Godot's default theme and looks
like an unstyled prototype. I want it to look like a real game.

**What I need from you:** a cohesive visual direction (colour palette,
typography, panel/button styling, dice treatment, spacing and hierarchy) applied
across all four screens, delivered as concrete specs I can implement in Godot 4
— exact hex colours, font sizes/weights, corner radii, border widths, padding
values, and a description of any state changes (hover/pressed/disabled).

### The game in one paragraph

Players join a room with a 4-character code and take turns. On your turn you
roll five dice. Any die showing a 1 "busts" and is set aside. You choose which
of the surviving dice to lock in (their values add to your round pot), then
decide: roll the remaining live dice again for more, or bank the pot into your
permanent score and pass the turn. If every die still in play busts on a single
roll, you lose the entire round pot. First to 4000 points wins. It's a game
about greed and nerve — the tension is "one more roll?"

### The screens (attached)

1. **`01-title.png`** — Enter a username, then either Create Room or type a
   4-character code and Join Room.
2. **`02-lobby.png`** — Room code displayed large (players read it aloud/paste
   it to friends), list of players with assigned colour swatches, host-only
   Start Game button, and a chat panel on the right.
3. **`03-game-turn-start.png`** — The main game. Left: scoreboard with per-player
   colour swatch, score, and a marker for whose turn it is. Centre: whose turn,
   live dice count, round pot, the dice row, and Roll/Bank buttons. Right: chat.
   Here the five dice are blank (not yet rolled this roll).
4. **`04-game-after-roll.png`** — After rolling: white dice with pips are
   selectable, red dice with an X have busted. The button becomes "Lock Selected".
5. **`06-game-dice-locked.png`** — Locked dice turn gold and stay on screen; the
   round pot reflects their total; remaining live dice show as blank slots.
6. **`07-turn-handover.png`** — After banking: the turn passes, a result message
   shows ("alice banked 6 points."), and a dimmed "Last turn" row shows what the
   previous player finished with.

### Dice states to design (this is the centrepiece)

The dice are drawn in code, not sprites, so you can specify anything drawable
with rounded rectangles, circles, and lines:

- **Blank** — a live die that hasn't been rolled yet this roll
- **Normal** — rolled, not busted, selectable (shows 1–6 pips)
- **Selected** — the player has picked this one to lock in
- **Locked** — banked into the round pot, safe
- **Busted** — showed a 1, dead for the round

These five states must be distinguishable *at a glance* — that reading is the
core of the game's decision-making. Currently: blank = dark grey, normal =
off-white, selected = green border, locked = gold, busted = dark red with an X.
Keep or replace that logic as you see fit, but preserve instant legibility.

### Constraints

- **Engine:** Godot 4.7, `Control` nodes. Deliverables should be things I can
  set via theme overrides and `_draw()` calls — colours, fonts, radii, borders,
  spacing. No CSS, no external image assets.
- **Dice are procedurally drawn.** Pips are circles; the die body is a rounded
  rect with optional border. I can draw lines/shapes but not import art.
- **Fonts:** free/open licence only (Google Fonts is fine). Name specific
  families and give me a fallback if the family isn't loaded.
- **Layout:** the three-column game layout (scoreboard / play area / chat) works
  and should stay, but proportions, panel styling, and spacing are all open.
- **Reference resolution** is 1280×720, scaled canvas. It should still read well
  at smaller window sizes.
- **Tone:** tense and a bit greedy — a felt-table / casino-adjacent feel, or a
  clean modern board-game look. Not childish, not grimdark. Pick a direction and
  commit to it rather than hedging.

### What I'd like back

1. A named visual direction with a one-paragraph rationale.
2. A palette: background, panel, panel border, primary text, secondary text,
   accent/CTA, danger/bust, success/locked, plus the 8 player colours (they must
   be mutually distinguishable and readable on the panel background).
3. Typography scale: family, size, and weight for screen titles, room code,
   player names, scores, body/status text, and buttons.
4. Component specs: panels, primary/secondary/disabled buttons, text inputs,
   chat lines, scoreboard rows.
5. Dice specs for all five states above, including pip colour/size and the
   busted marker treatment.
6. Anything you'd restructure in the layout, with a rough sketch or description.

Focus on hierarchy and legibility first: at a glance a player should know whose
turn it is, what their pot is worth, and which dice are safe versus dead.

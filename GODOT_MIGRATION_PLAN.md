# Godot Frontend Migration Plan

## Overview

Migrate the battle frontend from React to Godot while preserving the existing React app for Discord SDK integration, authentication, and navigation. This creates a hybrid architecture where React handles the "shell" and Godot handles the intensive battle rendering.

## Architecture

### Current Architecture
- **React SPA**: Handles all UI (home, matchmaking, battle)
- **Discord SDK**: Integrated in React for auth and activity status
- **Socket.io**: Real-time battle communication
- **Zustand**: State management for both UI and battle state

### Target Architecture
- **React App**: Home screen, matchmaking, Discord SDK auth, lobby, post-battle results
- **Godot Battle View**: Battle-only frontend that takes over when battle starts
- **Socket.io Backend**: Unchanged, serves both React and Godot clients
- **Shared Auth**: Auth tokens passed from React to Godot

## Integration Strategy

### Approach: Pre-Downloaded Godot Build with Canvas Swap

**Why This Approach:**
- Avoids nested iframe issues in Discord Activities
- Better performance (no iframe overhead)
- Simpler communication (direct JS function calls vs `postMessage`)
- Full screen control for Godot
- Faster perceived load time (files cached during initial load)

**User Flow:**
1. User opens Discord Activity → React app loads with Discord SDK
2. **Background**: While on home screen, Godot WASM/PCK files download and cache
3. User enters matchmaking → React UI
4. Battle starts → React hides, Godot canvas appears and takes over
5. Battle ends → Godot cleans up, React returns for results screen

### File Loading Strategy

**Initial Load (React App):**
```typescript
// In AuthProvider.tsx or App.tsx after Discord auth
useEffect(() => {
  if (auth.user) {
    // Start downloading Godot files in background
    cacheGodotBuild();
  }
}, [auth.user]);

async function cacheGodotBuild() {
  const files = [
    '/godot-build/index.wasm',
    '/godot-build/index.pck',
    '/godot-build/godot.js'
  ];

  await Promise.all(
    files.map(url =>
      fetch(url).then(r => r.blob()).then(blob => {
        return caches.open('godot-v1').then(cache =>
          cache.put(url, new Response(blob))
        );
      })
    )
  );
}
```

**Battle Start (Canvas Swap):**
```typescript
// In your battle navigation code
async function navigateToBattle(gameId: string) {
  // Hide React
  const root = document.getElementById('root');
  root.style.display = 'none';

  // Create/show Godot canvas
  const canvas = document.createElement('canvas');
  canvas.id = 'godot-canvas';
  document.body.appendChild(canvas);

  // Load pre-cached Godot engine
  const engine = await Godot.load({ canvas });

  // Pass data to Godot
  engine.setEnvironment({
    gameId,
    userId: authStore.getState().user.id,
    token: authStore.getState().accessToken
  });
}

// On battle end, Godot calls this
window.returnToReact = (battleResult) => {
  document.getElementById('godot-canvas')?.remove();
  document.getElementById('root').style.display = 'block';
  // Navigate to results screen with battleResult data
};
```

**Estimated Build Size:**
- WASM: 10-30 MB (depends on features used)
- PCK: Card sprites, animations, UI assets
- JS loader: ~500 KB
- **Total: ~15-50 MB** (downloads in 2-10 seconds on decent connections)

## Socket.io Communication

### Recommended Approach: JavaScript Bridge with Socket.io Client

Use the actual Socket.io client library in the HTML wrapper and communicate via JavaScriptBridge.

**HTML Wrapper:**
```html
<!DOCTYPE html>
<html>
<head>
    <script src="https://cdn.socket.io/4.5.4/socket.io.min.js"></script>
    <script>
        let socket;

        // Called from Godot
        window.initSocket = function(userId, gameId, token) {
            socket = io('http://localhost:3000', {
                auth: { userId, gameId, token }
            });

            // Forward all events to Godot
            socket.onAny((eventName, ...args) => {
                if (window.godotReceiveEvent) {
                    window.godotReceiveEvent(eventName, JSON.stringify(args[0]));
                }
            });

            socket.on('connect', () => {
                console.log('Connected to backend');
            });

            socket.on('disconnect', () => {
                console.log('Disconnected from backend');
            });
        };

        // Called from Godot to emit events
        window.emitToBackend = function(eventName, dataJson) {
            const data = JSON.parse(dataJson);
            socket.emit(eventName, data);
        };
    </script>
</head>
<body>
    <canvas id="canvas"></canvas>
    <script src="godot.js"></script>
</body>
</html>
```

**Godot GDScript:**
```gdscript
extends Node

var js_bridge
var game_id: String
var user_id: String

func _ready():
    if OS.has_feature("web"):
        js_bridge = JavaScriptBridge

        # Create callback for receiving events
        js_bridge.create_callback(_on_socket_event, "godotReceiveEvent")

        # Initialize Socket.io connection
        js_bridge.eval("initSocket('%s', '%s', '%s')" % [user_id, game_id, auth_token])

func emit_to_backend(event_name: String, data: Dictionary):
    var data_json = JSON.stringify(data)
    js_bridge.eval("emitToBackend('%s', '%s')" % [event_name, data_json])

func _on_socket_event(args):
    var event_name = args[0]
    var data_json = args[1]

    var json = JSON.new()
    json.parse(data_json)
    var data = json.get_data()

    match event_name:
        "battle-state-update":
            update_battle_state(data)
        "selectionPromptRequired":
            show_selection_prompt(data)
        "gameMessage":
            show_game_message(data)
        "battleEnded":
            handle_battle_end(data)
```

**Why JavaScript Bridge:**
- ✅ Full Socket.io features (automatic reconnection, rooms, acknowledgments)
- ✅ Backend expects Socket.io protocol nuances
- ✅ Less code to maintain than manual WebSocket protocol
- ✅ Easy debugging in browser console
- ✅ Handles edge cases automatically

## Development Phases

### Phase 1: Setup & Proof of Concept (1 week)
**Goal:** Establish basic Godot → Backend communication

- [ ] Create minimal Godot project with Socket.io bridge
- [ ] Implement JavaScript wrapper with Socket.io client
- [ ] Test connecting to existing backend
- [ ] Verify event emission (`execute-attack`, `play_trainer_card`)
- [ ] Verify event reception (`battle-state-update`, `selectionPromptRequired`)
- [ ] Create simple card scene that can emit click events

**Deliverable:** Godot app that can join a game, receive state, and send one action

### Phase 2: Card Rendering System (1-2 weeks)
**Goal:** Display Pokemon cards with proper layouts

- [ ] Create reusable Card scene (PokemonCard, TrainerCard, EnergyCard)
- [ ] Implement card data → visual properties mapping
- [ ] Add card text rendering (name, HP, attacks, effects)
- [ ] Implement click/hover detection
- [ ] Create card preview/zoom system
- [ ] Add energy attachment indicators
- [ ] Implement status condition overlays (paralyzed, poisoned, etc.)

**Key Scenes:**
- `PokemonCard.tscn` - Active/Bench Pokemon display
- `HandCard.tscn` - Cards in player's hand
- `TrainerCard.tscn` - Trainer card display
- `EnergyCard.tscn` - Energy card display

### Phase 3: Battle Board Layout (1 week)
**Goal:** Position all game elements correctly

- [ ] Create BattleBoard scene with proper zones
- [ ] Implement active Pokemon positioning (player/opponent)
- [ ] Implement bench Pokemon grid (up to 5 per side)
- [ ] Create hand display with card spacing
- [ ] Add prize cards display (face-down cards)
- [ ] Implement deck/discard pile counters
- [ ] Add turn indicator UI
- [ ] Create turn timer display

**Layout Structure:**
```
BattleBoard
├── OpponentZone
│   ├── ActivePokemon
│   ├── BenchPokemon (Container with 5 slots)
│   ├── PrizeCards
│   └── DeckDiscardCounters
├── PlayerZone (same structure)
└── HandZone
```

### Phase 4: Animation System (1-2 weeks)
**Goal:** Smooth visual feedback for game actions

- [ ] Create animation queue system (similar to React `animationQueue`)
- [ ] Implement attack animations
  - Damage number pop-ups
  - HP bar reduction
  - Card shake/flash effects
- [ ] Card movement animations
  - Draw from deck
  - Play from hand
  - Move to discard
  - Knockout/prize taken
- [ ] Energy attachment animations
- [ ] Status condition application effects
- [ ] Turn transition effects

**Animation Manager:**
```gdscript
# Singleton pattern like TimerRegistry
extends Node

var animation_queue: Array = []
var is_playing: bool = false

func queue_animation(anim_data: Dictionary):
    animation_queue.append(anim_data)
    if not is_playing:
        play_next()

func play_next():
    if animation_queue.is_empty():
        is_playing = false
        emit_signal("queue_complete")
        return

    is_playing = true
    var anim = animation_queue.pop_front()
    play_animation(anim)
```

### Phase 5: Selection Prompt System (1 week)
**Goal:** Handle mid-action user selections (e.g., Gust of Wind)

- [ ] Create modal dialog system
- [ ] Implement card selection UI with validation
- [ ] Handle `selectionPromptRequired` events
- [ ] Emit `user-selection-from-prompt` responses
- [ ] Add selection timeout countdown display
- [ ] Implement "waiting for opponent" overlay

**Selection Prompt Types:**
- Choose Pokemon from bench
- Choose energy to discard
- Choose cards from deck (search effects)
- Choose prize card to take

### Phase 6: State Synchronization (1 week)
**Goal:** Keep Godot UI in sync with backend state

- [ ] Implement state diffing to minimize updates
- [ ] Handle full state updates on reconnection
- [ ] Process `battle-state-update` events efficiently
- [ ] Update only changed elements (not full re-render)
- [ ] Handle event log to prevent duplicate animations
- [ ] Implement `processedEventIds` tracking

**State Management Pattern:**
```gdscript
# Store current state
var current_battle_state: Dictionary = {}

func update_battle_state(new_state: Dictionary):
    # Diff and update only what changed
    if new_state.player1.activePokemon != current_battle_state.player1.activePokemon:
        update_active_pokemon(new_state.player1.activePokemon)

    if new_state.player1.hand != current_battle_state.player1.hand:
        update_hand(new_state.player1.hand)

    # Store new state
    current_battle_state = new_state
```

### Phase 7: React Integration (1 week)
**Goal:** Seamless transition between React and Godot

- [ ] Implement pre-download caching in React app
- [ ] Create canvas swap navigation logic
- [ ] Pass auth tokens from React to Godot
- [ ] Implement `returnToReact()` callback
- [ ] Handle battle result data passing
- [ ] Test Discord Activity embedding
- [ ] Verify no CSP policy violations

**React Changes:**
```typescript
// New files:
// - src/services/godotLoader.ts (caching + initialization)
// - src/components/GodotBattleView.tsx (canvas management)

// Modified files:
// - src/App.tsx (add cache download on auth)
// - src/pages/Game.tsx (replace battle view with Godot)
```

### Phase 8: Testing & Polish (1-2 weeks)
**Goal:** Production-ready quality

- [ ] Test all card types (Pokemon, Trainer, Energy)
- [ ] Test all trainer card effects with selection prompts
- [ ] Test reconnection scenarios
- [ ] Test timer systems (turn timer, prompt timer)
- [ ] Performance optimization (reduce texture sizes, optimize animations)
- [ ] Add loading states and error handling
- [ ] Visual polish (particles, transitions, sound effects)
- [ ] Cross-browser testing (Chrome, Firefox, Safari)
- [ ] Mobile responsiveness testing

**Critical Test Scenarios:**
- Player disconnects mid-battle (with new DisconnectManager)
- Selection prompt timeout
- Turn timer escalation
- Multiple animations queued
- Large hand size (10+ cards)
- All status conditions
- All prize card scenarios

## Technical Considerations

### Backend Changes Required
**Minimal to None** - The backend is frontend-agnostic:
- Socket.io events remain unchanged
- BattleState structure stays the same
- All game logic is already server-side
- Only difference: Godot client instead of React client

### State Management in Godot

Unlike React with Zustand, Godot uses signals and direct property updates:

**React Pattern:**
```typescript
const game = gameStore();
game.battleState // triggers re-render on change
```

**Godot Pattern:**
```gdscript
signal battle_state_changed(new_state)

func update_battle_state(new_state: Dictionary):
    current_state = new_state
    emit_signal("battle_state_changed", new_state)

# Components listen to signal
func _ready():
    BattleManager.connect("battle_state_changed", _on_state_changed)
```

### Frontend State Not in Backend

These React `gameStore` properties need Godot equivalents:

| React State | Godot Equivalent | Notes |
|-------------|------------------|-------|
| `cardSelectionPrompt` | Modal scene instance | Active prompt UI |
| `animationQueue` | AnimationManager queue | Pending animations |
| `pendingBattleState` | Cached Dictionary | State waiting for animations |
| `preventGameBoardActions` | Boolean flag | Disable input during animations |
| `isAnimationPlaying` | AnimationManager.is_playing | Global lock |
| `turnTimeRemaining` | Timer node | Countdown display |
| `processedEventIds` | Array of Strings | Prevent duplicate animations |

### Asset Pipeline

**Card Images:**
- Current: Served from `/public/cards/` in React
- Godot: Import to `res://assets/cards/` or load via HTTP

**Recommendation:** Keep images on server, load via HTTPRequest in Godot
- Smaller Godot build size
- Easier to update cards without rebuilding
- Cache in Godot's resource cache

```gdscript
func load_card_image(card_id: String):
    var url = "http://localhost:3000/cards/%s.png" % card_id
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_image_loaded)
    http.request(url)
```

## Risks & Mitigations

### Risk 1: Discord Activity CSP Restrictions
**Impact:** Godot WASM might be blocked by Content Security Policy

**Mitigation:**
- Test early in Discord's embedded environment
- Ensure WASM is served from same origin
- Add proper CSP headers on server

### Risk 2: Large Download Size
**Impact:** 15-50 MB download might be slow on poor connections

**Mitigation:**
- Optimize Godot export (disable unused modules)
- Use aggressive compression (gzip/brotli)
- Show detailed loading progress
- Consider lazy-loading card assets

### Risk 3: Reconnection Complexity
**Impact:** Godot needs to handle same reconnection logic as React

**Mitigation:**
- Implement DisconnectManager (per notepad notes)
- Socket.io auto-reconnection handles most cases
- Grace period gives time for page refresh
- Store selection prompt data on backend temporarily

### Risk 4: Animation State Desync
**Impact:** Animations might play out of order or duplicate

**Mitigation:**
- Use event IDs to track processed events
- Queue system ensures sequential playback
- Backend event log as source of truth

### Risk 5: Development Time Underestimated
**Impact:** 6-week estimate might be optimistic

**Mitigation:**
- Build vertical slice first (one full battle flow)
- Can ship MVP with basic animations
- Polish incrementally post-launch
- Keep React version as fallback

## Success Metrics

**Functional:**
- [ ] All existing battle functionality works in Godot
- [ ] Socket.io events match React client behavior
- [ ] Selection prompts work correctly
- [ ] Animations play smoothly
- [ ] Reconnection handled gracefully

**Performance:**
- [ ] Initial Godot load < 5 seconds (cached)
- [ ] 60 FPS during battles
- [ ] Animations complete within expected timeframes
- [ ] Memory usage < 200 MB

**UX:**
- [ ] Transition from React to Godot feels seamless
- [ ] Battle feels more responsive than React version
- [ ] Visual quality improved over CSS animations

## Rollout Strategy

### Phase 1: Internal Testing
- Deploy Godot version behind feature flag
- Test with development team
- Collect feedback on performance and UX

### Phase 2: Beta Testing
- Enable for small subset of users
- Monitor error rates and performance metrics
- A/B test against React version

### Phase 3: Full Launch
- Gradual rollout (10% → 50% → 100%)
- Keep React version available as fallback
- Monitor Discord Activity stability

## Future Enhancements (Post-Migration)

Once Godot frontend is stable:
- [ ] Advanced particle effects for attacks
- [ ] 3D card flipping animations
- [ ] Background music and sound effects
- [ ] Card hover preview with smooth zoom
- [ ] Deck builder UI in Godot
- [ ] Replay system using event log
- [ ] Native desktop/mobile versions

## Conclusion

This migration preserves all existing functionality while enabling better visual effects and performance. The hybrid approach keeps Discord integration simple while giving Godot full control over the battle experience. Estimated total development time: **6-10 weeks** for a single developer familiar with both React and Godot.

---

# Appendix: BattleState Type Definitions

This section contains all TypeScript interfaces needed to understand the BattleState structure for Godot implementation.

## Core BattleState Interface

```typescript
interface BattleState {
  id: string;
  players: {
    [playerId: string]: PlayerState;
  };
  cards: BattleCardState[];
  turn: TurnState;
  timerHistory: {
    [playerId: string]: TurnTimerState;
  };
  eventLog: GameEvent[];  // Omit for initial Godot prototype
  createdAt: Date;
  updatedAt: Date;
  victoryResult?: VictoryResult;
  testState?: TestState;
}
```

## PlayerState

```typescript
interface PlayerState {
  playerId: string;
  username: string;
  avatarHash?: string;
  playerNumber: 1 | 2;
  hasAttacked: boolean;
  mulliganCount: number;
  setupComplete: boolean;
}
```

## TurnState

```typescript
type TurnPhase = 'setup' | 'main' | 'attack' | 'end' | 'selectActivePokemon';

interface TurnState {
  playerId: string;              // ID of player whose turn it is
  turnNumber: number;
  phase: TurnPhase;
  energyPlayed: boolean;         // Has player attached energy this turn?
  supporterPlayed: boolean;      // Has player played supporter card this turn?
  retreatUsed: boolean;          // Has player retreated this turn?
  retreatingPokemonId?: string;  // Pokemon that is currently retreating
  abilitiesUsedThisTurn: string[]; // IDs of abilities used this turn
}
```

## BattleCardState

This is the core card representation in battle state:

```typescript
interface BattleCardState {
  id: string;                    // Unique instance ID for this card in battle
  cardStoreData: CardStoreData;  // Reference to card template
  owner: string;                 // Player ID who owns this card
  location: CardLocation;        // Where this card is located
  damage?: number;               // Damage on Pokemon (only for Pokemon cards)
  specialConditions?: SpecialConditionData[];  // Status effects
  attachedEnergy?: { instanceId: string; templateId: string }[];
  attachedTrainers?: { instanceId: string; templateId: string }[];
  turnPlayed: number;            // Turn this card was played
  effects?: EffectData[];        // Active effects on this Pokemon
  miscData?: MiscData;           // Card-specific data (e.g., Electrode's Buzzap)
}
```

## CardStoreData

Reference to the card template:

```typescript
interface CardStoreData {
  id: string;          // Template ID (e.g., "Pikachu_BS_58")
  userId: string;      // Owner's user ID
  name: string;        // Card name (e.g., "Pikachu")
  set: string;         // Set code (e.g., "BS" for Base Set)
  setNumber: number;   // Card number in set
}
```

## CardLocation

Describes where a card is located:

```typescript
type CardLocation = {
  type: 'hand' | 'deck' | 'discard' | 'prize' | 'active' | 'bench' | 'attached' | 'board';
  index?: number;        // Position in hand/bench/deck
  attachedTo?: string;   // If attached, the ID of the Pokemon
};
```

## SpecialConditionData

```typescript
interface SpecialConditionData {
  type: "Confusion" | "Burn" | "Paralyze" | "Sleep" | "Poison" | "Toxic";
  turnApplied: number;
  data?: {
    confusionCheckedThisTurn?: boolean;
  };
}
```

## EffectData

```typescript
type EffectType =
  | 'prevent_all_damage'
  | 'coin_flip_to_use_attack'
  | 'prevent_all'
  | 'destiny_bond'
  | 'harden'
  | 'make_move_unusable'
  | 'pokemon_type_change'
  | 'pokemon_weakness_change'
  | 'pokemon_resistance_change'
  | 'mirror_move';

interface EffectData {
  moveName: string;
  effectType: EffectType;
  description?: string;
  turnApplied?: number;
  source?: string;  // ID of card that applied this effect
  duration?: number;
  data?: {
    pokemonTypeChange?: PokemonType[];
    pokemonWeaknessChange?: PokemonType[];
    pokemonResistanceChange?: PokemonType[];
    mirrorMoveAttack?: {
      moveName?: string;
      damage?: number;
      specialConditions?: SpecialConditionData[];
      effects?: EffectData[];
    };
  };
}
```

## Pokemon Types & Energy Types

```typescript
type PokemonType = "Fire" | "Water" | "Colorless" | "Lightning" | "Grass"
  | "Fighting" | "Psychic" | "Metal" | "Darkness" | "Dragon";

type EnergyType = "Colorless" | "Fire" | "Water" | "Lightning" | "Fighting"
  | "Grass" | "Psychic" | "Metal" | "Darkness" | "Rainbow";
```

## Timer & Victory

```typescript
type TurnTimerMode = '3min' | '1min';

interface TurnTimerState {
  lastTurnTimedOut: boolean;
  currentTimerMode: TurnTimerMode;
}

interface VictoryResult {
  winnerId: string;
  reason: 'no_pokemon' | 'prizes_depleted' | 'deck_out' | 'forfeit' | 'disconnect' | 'timeout';
}
```

## MiscData

```typescript
interface MiscData {
  leekSlapUsed?: boolean;
  buzzapSelectedEnergyType?: EnergyType;
}
```

---

# Hardcoded BattleState Example for Godot Testing

Below is a complete, valid BattleState JSON that can be used to test Godot rendering without needing a backend connection.

```json
{
  "id": "test-battle-001",
  "players": {
    "player1": {
      "playerId": "player1",
      "username": "Ash",
      "playerNumber": 1,
      "hasAttacked": false,
      "mulliganCount": 0,
      "setupComplete": true
    },
    "player2": {
      "playerId": "player2",
      "username": "Gary",
      "playerNumber": 2,
      "hasAttacked": false,
      "mulliganCount": 0,
      "setupComplete": true
    }
  },
  "cards": [
    {
      "id": "card-active-p1",
      "cardStoreData": {
        "id": "Pikachu_BS_58",
        "userId": "player1",
        "name": "Pikachu",
        "set": "BS",
        "setNumber": 58
      },
      "owner": "player1",
      "location": { "type": "active" },
      "damage": 20,
      "specialConditions": [],
      "attachedEnergy": [
        {
          "instanceId": "energy-1",
          "templateId": "Lightning_Energy_BS_100"
        },
        {
          "instanceId": "energy-2",
          "templateId": "Lightning_Energy_BS_100"
        }
      ],
      "attachedTrainers": [],
      "turnPlayed": 1,
      "effects": []
    },
    {
      "id": "card-bench-p1-0",
      "cardStoreData": {
        "id": "Charmander_BS_46",
        "userId": "player1",
        "name": "Charmander",
        "set": "BS",
        "setNumber": 46
      },
      "owner": "player1",
      "location": { "type": "bench", "index": 0 },
      "damage": 0,
      "specialConditions": [],
      "attachedEnergy": [
        {
          "instanceId": "energy-3",
          "templateId": "Fire_Energy_BS_98"
        }
      ],
      "attachedTrainers": [],
      "turnPlayed": 1,
      "effects": []
    },
    {
      "id": "card-bench-p1-1",
      "cardStoreData": {
        "id": "Squirtle_BS_63",
        "userId": "player1",
        "name": "Squirtle",
        "set": "BS",
        "setNumber": 63
      },
      "owner": "player1",
      "location": { "type": "bench", "index": 1 },
      "damage": 10,
      "specialConditions": [],
      "attachedEnergy": [],
      "attachedTrainers": [],
      "turnPlayed": 2,
      "effects": []
    },
    {
      "id": "card-hand-p1-0",
      "cardStoreData": {
        "id": "Professor_Oak_BS_88",
        "userId": "player1",
        "name": "Professor Oak",
        "set": "BS",
        "setNumber": 88
      },
      "owner": "player1",
      "location": { "type": "hand", "index": 0 },
      "turnPlayed": 0,
      "effects": []
    },
    {
      "id": "card-hand-p1-1",
      "cardStoreData": {
        "id": "Potion_BS_94",
        "userId": "player1",
        "name": "Potion",
        "set": "BS",
        "setNumber": 94
      },
      "owner": "player1",
      "location": { "type": "hand", "index": 1 },
      "turnPlayed": 0,
      "effects": []
    },
    {
      "id": "card-hand-p1-2",
      "cardStoreData": {
        "id": "Fire_Energy_BS_98",
        "userId": "player1",
        "name": "Fire Energy",
        "set": "BS",
        "setNumber": 98
      },
      "owner": "player1",
      "location": { "type": "hand", "index": 2 },
      "turnPlayed": 0,
      "effects": []
    },
    {
      "id": "card-prize-p1-0",
      "cardStoreData": {
        "id": "Bulbasaur_BS_44",
        "userId": "player1",
        "name": "Bulbasaur",
        "set": "BS",
        "setNumber": 44
      },
      "owner": "player1",
      "location": { "type": "prize", "index": 0 },
      "turnPlayed": 0,
      "effects": []
    },
    {
      "id": "card-prize-p1-1",
      "cardStoreData": {
        "id": "Grass_Energy_BS_99",
        "userId": "player1",
        "name": "Grass Energy",
        "set": "BS",
        "setNumber": 99
      },
      "owner": "player1",
      "location": { "type": "prize", "index": 1 },
      "turnPlayed": 0,
      "effects": []
    },
    {
      "id": "card-discard-p1-0",
      "cardStoreData": {
        "id": "Energy_Removal_BS_92",
        "userId": "player1",
        "name": "Energy Removal",
        "set": "BS",
        "setNumber": 92
      },
      "owner": "player1",
      "location": { "type": "discard", "index": 0 },
      "turnPlayed": 0,
      "effects": []
    },
    {
      "id": "card-active-p2",
      "cardStoreData": {
        "id": "Machop_BS_52",
        "userId": "player2",
        "name": "Machop",
        "set": "BS",
        "setNumber": 52
      },
      "owner": "player2",
      "location": { "type": "active" },
      "damage": 30,
      "specialConditions": [
        {
          "type": "Poison",
          "turnApplied": 3
        }
      ],
      "attachedEnergy": [
        {
          "instanceId": "energy-p2-1",
          "templateId": "Fighting_Energy_BS_97"
        },
        {
          "instanceId": "energy-p2-2",
          "templateId": "Fighting_Energy_BS_97"
        }
      ],
      "attachedTrainers": [],
      "turnPlayed": 1,
      "effects": []
    },
    {
      "id": "card-bench-p2-0",
      "cardStoreData": {
        "id": "Geodude_BS_47",
        "userId": "player2",
        "name": "Geodude",
        "set": "BS",
        "setNumber": 47
      },
      "owner": "player2",
      "location": { "type": "bench", "index": 0 },
      "damage": 0,
      "specialConditions": [],
      "attachedEnergy": [],
      "attachedTrainers": [],
      "turnPlayed": 2,
      "effects": []
    },
    {
      "id": "card-hand-p2-0",
      "cardStoreData": {
        "id": "Gust_of_Wind_BS_93",
        "userId": "player2",
        "name": "Gust of Wind",
        "set": "BS",
        "setNumber": 93
      },
      "owner": "player2",
      "location": { "type": "hand", "index": 0 },
      "turnPlayed": 0,
      "effects": []
    },
    {
      "id": "card-hand-p2-1",
      "cardStoreData": {
        "id": "Fighting_Energy_BS_97",
        "userId": "player2",
        "name": "Fighting Energy",
        "set": "BS",
        "setNumber": 97
      },
      "owner": "player2",
      "location": { "type": "hand", "index": 1 },
      "turnPlayed": 0,
      "effects": []
    },
    {
      "id": "card-prize-p2-0",
      "cardStoreData": {
        "id": "Onix_BS_56",
        "userId": "player2",
        "name": "Onix",
        "set": "BS",
        "setNumber": 56
      },
      "owner": "player2",
      "location": { "type": "prize", "index": 0 },
      "turnPlayed": 0,
      "effects": []
    },
    {
      "id": "card-prize-p2-1",
      "cardStoreData": {
        "id": "Diglett_BS_47",
        "userId": "player2",
        "name": "Diglett",
        "set": "BS",
        "setNumber": 47
      },
      "owner": "player2",
      "location": { "type": "prize", "index": 1 },
      "turnPlayed": 0,
      "effects": []
    }
  ],
  "turn": {
    "playerId": "player1",
    "turnNumber": 3,
    "phase": "main",
    "energyPlayed": false,
    "supporterPlayed": false,
    "retreatUsed": false,
    "abilitiesUsedThisTurn": []
  },
  "timerHistory": {
    "player1": {
      "lastTurnTimedOut": false,
      "currentTimerMode": "3min"
    },
    "player2": {
      "lastTurnTimedOut": false,
      "currentTimerMode": "3min"
    }
  },
  "eventLog": [],
  "createdAt": "2025-01-15T10:30:00.000Z",
  "updatedAt": "2025-01-15T10:35:00.000Z"
}
```

## Using This Test Data in Godot

**GDScript Example:**

```gdscript
extends Node

var battle_state: Dictionary

func _ready():
    # Load hardcoded battle state
    var json_string = """
    {
      "id": "test-battle-001",
      "players": { ... }
    }
    """

    var json = JSON.new()
    var error = json.parse(json_string)

    if error == OK:
        battle_state = json.get_data()
        render_battle_state(battle_state)
    else:
        print("JSON Parse Error: ", json.get_error_message())

func render_battle_state(state: Dictionary):
    # Render player 1's active Pokemon
    var player1_cards = get_cards_for_player(state.cards, "player1")
    var active_card = player1_cards.filter(func(c): return c.location.type == "active")[0]

    print("Player 1 Active Pokemon: ", active_card.cardStoreData.name)
    print("Damage: ", active_card.damage)
    print("Attached Energy: ", active_card.attachedEnergy.size())

    # Render bench
    var bench_cards = player1_cards.filter(func(c): return c.location.type == "bench")
    for card in bench_cards:
        print("Bench [", card.location.index, "]: ", card.cardStoreData.name)

    # Render hand
    var hand_cards = player1_cards.filter(func(c): return c.location.type == "hand")
    print("Hand size: ", hand_cards.size())

func get_cards_for_player(cards: Array, player_id: String) -> Array:
    return cards.filter(func(c): return c.owner == player_id)
```

## Key Insights for Godot Development

1. **Cards are flat array**: All cards (in hand, deck, discard, active, bench, attached) are in `state.cards[]`
2. **Location determines position**: Use `card.location.type` to filter cards by zone
3. **Attached cards reference parent**: `card.location.attachedTo` points to Pokemon ID
4. **Player data is minimal**: Most data is in the cards array, not player objects
5. **Template ID lookup**: Use `card.cardStoreData.id` to look up card art/stats from card database

This structure makes it easy to:
- Filter cards by location type: `cards.filter(c => c.location.type === 'active')`
- Find specific Pokemon: `cards.find(c => c.id === 'card-active-p1')`
- Group by owner: `cards.filter(c => c.owner === 'player1')`
- Render zones independently without complex nesting

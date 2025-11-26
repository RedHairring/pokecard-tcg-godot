# EventLog Recreation Guide for Godot

This guide explains how to recreate the EventLog.tsx React component in Godot. The EventLog is a draggable, resizable, collapsible window that displays game events in real-time with animations.

## Overview

The EventLog is a floating UI panel that:
- Displays a scrollable list of game events
- Can be dragged around the screen
- Can be resized (width and height)
- Can be collapsed/expanded
- Auto-scrolls to new events
- Shows player-specific colors
- Animates new events sliding in
- Allows clicking events to view details
- Persists user preferences (position, size, collapsed state)

## Core Architecture

### 1. Node Structure

```
EventLogPanel (Control or Panel)
├── DragHandle (Panel)
│   ├── TitleLabel (Label)
│   └── ToggleButton (Button)
├── ScrollContainer (ScrollContainer)
│   └── EventList (VBoxContainer)
│       └── EventItem1, EventItem2... (Panel or MarginContainer)
├── HorizontalResizeHandle (Control)
│   └── ResizeIndicator (ColorRect)
└── VerticalResizeHandle (Control)
    └── ResizeIndicator (ColorRect)
```

### 2. Data Structures

#### GameEvent Structure
```gdscript
class_name GameEvent
extends Resource

var type: String  # Event type identifier
var active_turn_player_id: String
var turn: int
var text: String
var hidden: bool = false

# Optional fields (depending on event type)
var source_pokemon_id: String
var target_pokemon_id: String
var special_condition: String
var card_name: String
var move_name: String
var results: Array  # For coin flips
var pokemon_id: String
var evolution_card_name: String
var previous_card_name: String
var owner_id: String
var pokemon_name: String
var target_slot: String  # 'active' or bench index
var effect_type: String
var effect_name: String
var amount: int  # For healing
var player_id: String
var card_count: int
var card_ids: Array
var template_ids: Array
var remaining_prize_cards: int
var trainer_card_id: String
var template_id: String
var mulligan_count: int
var opponent_draws_extra: bool
var cards_in_hand: Array
```

#### EventLogPreferences
```gdscript
class_name EventLogPreferences
extends Resource

var position: Vector2 = Vector2(0, 0)
var width: float = 300.0
var height: float = 400.0
var is_expanded: bool = true
```

## Implementation Guide

### 3. Main EventLog Script

```gdscript
extends Control
class_name EventLog

# Configuration
@export var max_events: int = 15
@export var initial_position: Vector2 = Vector2(0, 0)
@export var initial_width: float = 300.0
@export var initial_height: float = 400.0
@export var initial_opened: bool = true
@export var min_width: float = 250.0
@export var min_height: float = 200.0
@export var collapsed_height: float = 60.0
@export var animation_duration: float = 0.6
@export var auto_scroll_threshold: float = 10.0

# Node references
@onready var drag_handle: Panel = $DragHandle
@onready var title_label: Label = $DragHandle/TitleLabel
@onready var toggle_button: Button = $DragHandle/ToggleButton
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var event_list: VBoxContainer = $ScrollContainer/EventList
@onready var h_resize_handle: Control = $HorizontalResizeHandle
@onready var v_resize_handle: Control = $VerticalResizeHandle

# State
var events: Array[GameEvent] = []
var battle_state: Dictionary = {}
var current_player_id: String = ""
var is_expanded: bool = true
var animated_events: Dictionary = {}  # event_key -> Timer
var previous_event_count: int = 0

# Dragging state
var is_dragging: bool = false
var drag_start_position: Vector2
var drag_offset: Vector2

# Resizing state
var is_resizing_horizontal: bool = false
var is_resizing_vertical: bool = false
var resize_start_mouse: Vector2
var resize_start_size: Vector2

# Auto-scroll state
var should_auto_scroll: bool = true

# Signals
signal preferences_changed(preferences: EventLogPreferences)
signal event_clicked(event_index: int)

func _ready():
    # Set initial size and position
    size = Vector2(initial_width, initial_height if initial_opened else collapsed_height)
    position = initial_position
    is_expanded = initial_opened

    # Connect signals
    drag_handle.gui_input.connect(_on_drag_handle_input)
    toggle_button.pressed.connect(_on_toggle_pressed)
    h_resize_handle.gui_input.connect(_on_h_resize_input)
    v_resize_handle.gui_input.connect(_on_v_resize_input)
    scroll_container.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)

    # Setup UI
    _update_layout()

func set_events(new_events: Array[GameEvent], new_battle_state: Dictionary, player_id: String):
    """Update the event log with new events"""
    var visible_events = _filter_visible_events(new_events)

    # Check for new events
    if visible_events.size() > previous_event_count:
        var new_event_count = visible_events.size() - previous_event_count
        _animate_new_events(visible_events, new_event_count)

    events = visible_events
    battle_state = new_battle_state
    current_player_id = player_id
    previous_event_count = visible_events.size()

    _rebuild_event_list()

    # Auto-scroll to bottom if enabled
    if should_auto_scroll and is_expanded:
        await get_tree().process_frame
        scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func _filter_visible_events(all_events: Array[GameEvent]) -> Array[GameEvent]:
    """Filter out hidden events and limit to max_events"""
    var visible = []
    for event in all_events:
        if not event.hidden:
            visible.append(event)

    # Get only the most recent events
    var start_index = max(0, visible.size() - max_events)
    return visible.slice(start_index)

func _animate_new_events(visible_events: Array[GameEvent], new_event_count: int):
    """Animate new events sliding in"""
    var start_index = visible_events.size() - new_event_count

    for i in range(start_index, visible_events.size()):
        var event = visible_events[i]
        var event_key = "%d-%d" % [event.turn, i]

        # Create animation timer
        var timer = Timer.new()
        timer.wait_time = animation_duration
        timer.one_shot = true
        add_child(timer)

        animated_events[event_key] = timer
        timer.timeout.connect(func():
            animated_events.erase(event_key)
            timer.queue_free()
        )
        timer.start()

func _rebuild_event_list():
    """Rebuild the event list UI"""
    # Clear existing items
    for child in event_list.get_children():
        child.queue_free()

    if events.is_empty():
        _show_empty_state()
        return

    # Create event items
    for i in range(events.size()):
        var event = events[i]
        var event_key = "%d-%d" % [event.turn, i]
        var is_animated = animated_events.has(event_key)

        var event_item = _create_event_item(event, i, is_animated)
        event_list.add_child(event_item)

func _create_event_item(event: GameEvent, index: int, is_animated: bool) -> Control:
    """Create a single event item"""
    var item = Panel.new()
    item.custom_minimum_size = Vector2(0, 60)

    # Apply styling based on active player
    var style = _get_event_style(event.active_turn_player_id)
    item.add_theme_stylebox_override("panel", style)

    # Add animation if this is a new event
    if is_animated:
        item.modulate.a = 0
        var tween = create_tween()
        tween.set_ease(Tween.EASE_OUT)
        tween.set_trans(Tween.TRANS_CUBIC)
        tween.tween_property(item, "modulate:a", 1.0, animation_duration)
        tween.parallel().tween_property(item, "position:x", 0, animation_duration).from(-100)

    # Create layout container
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    item.add_child(vbox)

    # Header (turn number and player info)
    var header = HBoxContainer.new()
    header.add_theme_constant_override("separation", 6)

    var turn_label = Label.new()
    turn_label.text = "Turn %d" % event.turn
    turn_label.add_theme_font_size_override("font_size", 10)
    turn_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
    header.add_child(turn_label)

    # Add player avatar and name if available
    if battle_state.has("players") and battle_state.players.has(event.active_turn_player_id):
        var player_data = battle_state.players[event.active_turn_player_id]

        var separator = Label.new()
        separator.text = "•"
        separator.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
        header.add_child(separator)

        # Avatar (TextureRect)
        var avatar = TextureRect.new()
        avatar.custom_minimum_size = Vector2(16, 16)
        avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
        avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        # Load avatar from Discord CDN or default
        var avatar_url = _get_discord_avatar_url(event.active_turn_player_id, player_data)
        _load_texture_from_url(avatar, avatar_url)
        header.add_child(avatar)

        var username = Label.new()
        username.text = player_data.get("username", "Unknown")
        username.add_theme_font_size_override("font_size", 10)
        username.add_theme_color_override("font_color", Color(0.33, 0.33, 0.33))
        header.add_child(username)

    vbox.add_child(header)

    # Event text
    var text_label = Label.new()
    text_label.text = event.text
    text_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
    text_label.add_theme_font_size_override("font_size", 13)
    text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vbox.add_child(text_label)

    # Event-specific indicators
    var indicator = _create_event_indicator(event)
    if indicator:
        vbox.add_child(indicator)

    # Make clickable
    item.gui_input.connect(func(input_event: InputEvent):
        if input_event is InputEventMouseButton:
            if input_event.pressed and input_event.button_index == MOUSE_BUTTON_LEFT:
                event_clicked.emit(index)
    )

    # Hover effects
    item.mouse_entered.connect(func():
        var tween = create_tween()
        tween.tween_property(item, "position:x", 4, 0.2)
    )
    item.mouse_exited.connect(func():
        var tween = create_tween()
        tween.tween_property(item, "position:x", 0, 0.2)
    )

    return item

func _create_event_indicator(event: GameEvent) -> Control:
    """Create visual indicators for specific event types"""
    var container = HBoxContainer.new()
    container.add_theme_constant_override("separation", 4)

    var icon = Label.new()
    var label = Label.new()
    label.add_theme_font_size_override("font_size", 12)

    match event.type:
        "coinFlip":
            if event.results and event.results.size() > 0:
                icon.text = "🪙"
                var result_text = "HEADS" if event.results[0] else "TAILS"
                var result_color = Color.GREEN if event.results[0] else Color.ORANGE
                label.text = result_text
                label.add_theme_color_override("font_color", result_color)

        "pokemonEvolved":
            icon.text = "🔄"
            label.text = "EVOLVED!"
            label.add_theme_color_override("font_color", Color(0.18, 0.8, 0.44))

        "effectApplied":
            icon.text = "✨"
            label.text = "EFFECT APPLIED"
            label.add_theme_color_override("font_color", Color(0.56, 0.27, 0.68))

        "effectRemoved":
            icon.text = "⏱️"
            label.text = "EFFECT EXPIRED"
            label.add_theme_color_override("font_color", Color(0.58, 0.65, 0.65))

        "healing":
            icon.text = "❤️"
            label.text = "HEALED %d HP" % event.amount
            label.add_theme_color_override("font_color", Color(0.15, 0.68, 0.38))

        "prizeCardGiven":
            icon.text = "🏆"
            var plural = "S" if event.card_count > 1 else ""
            label.text = "PRIZE CARD%s TAKEN" % plural
            label.add_theme_color_override("font_color", Color(0.95, 0.61, 0.07))

        "cardDraw":
            icon.text = "🃏"
            label.text = "CARD DRAWN"
            label.add_theme_color_override("font_color", Color(0.09, 0.63, 0.52))

        "trainerCardPlayed":
            icon.text = "🎯"
            label.text = "TRAINER CARD PLAYED"
            label.add_theme_color_override("font_color", Color(0.9, 0.49, 0.13))

        "pokemonPlayed":
            var is_active = event.target_slot == "active"
            icon.text = "⚡" if is_active else "🎒"
            label.text = "ACTIVE POKEMON" if is_active else "BENCH POKEMON"
            label.add_theme_color_override("font_color", Color(0.09, 0.64, 0.72))

        "mulligan":
            icon.text = "🔀"
            label.text = "MULLIGAN #%d" % event.mulligan_count
            label.add_theme_color_override("font_color", Color(0.61, 0.35, 0.71))

        "showCards":
            icon.text = "👁️"
            var plural = "S" if event.card_ids and event.card_ids.size() > 1 else ""
            label.text = "CARD%s REVEALED" % plural
            label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.86))

        "text":
            if event.text and "prevented" in event.text:
                icon.text = "🛡️"
                label.text = "BLOCKED"
                label.add_theme_color_override("font_color", Color(0.2, 0.29, 0.37))

        _:
            return null

    if icon.text and label.text:
        container.add_child(icon)
        container.add_child(label)
        return container

    return null

func _get_event_style(active_player_id: String) -> StyleBoxFlat:
    """Get the StyleBox for an event based on the active player"""
    var style = StyleBoxFlat.new()
    style.set_corner_radius_all(6)
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    style.border_width_left = 4

    # Get player IDs and sort them to determine player 1 and 2
    var player_ids = battle_state.get("players", {}).keys()
    player_ids.sort()

    if player_ids.size() >= 2:
        if active_player_id == player_ids[0]:
            # Player 1 - Blue
            style.bg_color = Color(0.92, 0.95, 0.99)
            style.border_color = Color(0.2, 0.6, 0.86)
        elif active_player_id == player_ids[1]:
            # Player 2 - Red
            style.bg_color = Color(0.99, 0.95, 0.95)
            style.border_color = Color(0.91, 0.3, 0.24)
        else:
            # Default
            style.bg_color = Color(0.97, 0.97, 0.98)
            style.border_color = Color(0.87, 0.87, 0.87)
    else:
        # Default
        style.bg_color = Color(0.97, 0.97, 0.98)
        style.border_color = Color(0.87, 0.87, 0.87)

    return style

func _show_empty_state():
    """Show empty state when no events"""
    var label = Label.new()
    label.text = "Battle events will appear here..."
    label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    event_list.add_child(label)

func _update_layout():
    """Update the panel layout based on expanded state"""
    var target_height = initial_height if is_expanded else collapsed_height

    var tween = create_tween()
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.set_trans(Tween.TRANS_CUBIC)
    tween.tween_property(self, "size:y", target_height, 0.3)

    scroll_container.visible = is_expanded
    v_resize_handle.visible = is_expanded

# Dragging logic
func _on_drag_handle_input(event: InputEvent):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                is_dragging = true
                drag_start_position = get_global_mouse_position()
                drag_offset = position
            else:
                is_dragging = false
                _save_preferences()

func _process(delta):
    if is_dragging:
        var mouse_pos = get_global_mouse_position()
        position = drag_offset + (mouse_pos - drag_start_position)

# Resizing logic
func _on_h_resize_input(event: InputEvent):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                is_resizing_horizontal = true
                resize_start_mouse = get_global_mouse_position()
                resize_start_size = size
            else:
                is_resizing_horizontal = false
                _save_preferences()

func _on_v_resize_input(event: InputEvent):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                is_resizing_vertical = true
                resize_start_mouse = get_global_mouse_position()
                resize_start_size = size
            else:
                is_resizing_vertical = false
                _save_preferences()

func _physics_process(delta):
    if is_resizing_horizontal:
        var mouse_pos = get_global_mouse_position()
        var delta_x = mouse_pos.x - resize_start_mouse.x
        size.x = max(min_width, resize_start_size.x + delta_x)

    if is_resizing_vertical:
        var mouse_pos = get_global_mouse_position()
        var delta_y = mouse_pos.y - resize_start_mouse.y
        size.y = max(min_height, resize_start_size.y + delta_y)

# Toggle expand/collapse
func _on_toggle_pressed():
    is_expanded = !is_expanded
    _update_layout()
    _save_preferences()

# Scroll handling
func _on_scroll_changed(value: float):
    var scrollbar = scroll_container.get_v_scroll_bar()
    var is_at_bottom = scrollbar.max_value - value < auto_scroll_threshold
    should_auto_scroll = is_at_bottom

# Preferences
func _save_preferences():
    var prefs = EventLogPreferences.new()
    prefs.position = position
    prefs.width = size.x
    prefs.height = size.y if is_expanded else initial_height
    prefs.is_expanded = is_expanded
    preferences_changed.emit(prefs)

# Utility functions
func _get_discord_avatar_url(player_id: String, player_data: Dictionary) -> String:
    var avatar_hash = player_data.get("avatarHash", "")
    if avatar_hash:
        return "https://cdn.discordapp.com/avatars/%s/%s.png?size=64" % [player_data.get("playerId", ""), avatar_hash]
    else:
        var discriminator = player_data.get("discriminator", "0")
        var default_avatar = int(discriminator) % 5
        return "https://cdn.discordapp.com/embed/avatars/%d.png" % default_avatar

func _load_texture_from_url(texture_rect: TextureRect, url: String):
    # Use HTTPRequest to load texture from URL
    var http_request = HTTPRequest.new()
    add_child(http_request)

    http_request.request_completed.connect(func(result, response_code, headers, body):
        if response_code == 200:
            var image = Image.new()
            var error = image.load_png_from_buffer(body)
            if error == OK:
                texture_rect.texture = ImageTexture.create_from_image(image)
        http_request.queue_free()
    )

    http_request.request(url)
```

### 4. Styling and Theming

#### Panel StyleBox
Create a custom theme with StyleBoxFlat for the main panel:

```gdscript
var panel_style = StyleBoxFlat.new()
panel_style.bg_color = Color(1, 1, 1, 0.95)
panel_style.border_width_left = 2
panel_style.border_width_right = 2
panel_style.border_width_top = 2
panel_style.border_width_bottom = 2
panel_style.border_color = Color(0.2, 0.2, 0.2)
panel_style.corner_radius_top_left = 12
panel_style.corner_radius_top_right = 12
panel_style.corner_radius_bottom_left = 12
panel_style.corner_radius_bottom_right = 12
panel_style.shadow_size = 4
panel_style.shadow_color = Color(0, 0, 0, 0.2)
```

#### Drag Handle Gradient
```gdscript
var gradient = Gradient.new()
gradient.add_point(0.0, Color(0.4, 0.49, 0.92))  # #667eea
gradient.add_point(1.0, Color(0.46, 0.29, 0.64))  # #764ba2

var gradient_texture = GradientTexture2D.new()
gradient_texture.gradient = gradient
gradient_texture.fill_from = Vector2(0, 0)
gradient_texture.fill_to = Vector2(1, 1)

var drag_handle_style = StyleBoxTexture.new()
drag_handle_style.texture = gradient_texture
```

### 5. Key Features Implementation

#### Auto-Scroll Behavior
- Track scroll position via `ScrollContainer.get_v_scroll_bar()`
- Set `should_auto_scroll = true` when user is within 10 pixels of bottom
- Set `should_auto_scroll = false` when user scrolls up manually
- Only auto-scroll if `should_auto_scroll` is true when new events arrive

#### Animation System
- Use `Timer` nodes to track animation duration (0.6 seconds)
- Store timers in dictionary with event key: `"%d-%d" % [turn, index]`
- Use `Tween` for slide-in animation (translateX from -100% to 0)
- Use `Tween` for fade-in animation (opacity from 0 to 1)
- Clean up timers when they expire

#### Drag and Drop
- Track `is_dragging` state
- On mouse down on drag handle: record start position and offset
- During `_process()`: update position based on mouse delta
- On mouse up: save preferences

#### Resizing
- Create invisible resize handles on edges (6px wide)
- Visual indicator (3px ColorRect) shows on hover
- Track `is_resizing_horizontal` and `is_resizing_vertical` states
- Enforce minimum sizes (250px width, 200px height)
- Update size during `_physics_process()`

#### Event Filtering
- Filter out events where `hidden == true`
- Limit to most recent `max_events` (default 15)
- Slice array: `visible.slice(max(0, visible.size() - max_events))`

### 6. Integration Points

#### Receiving Events from Server
```gdscript
func _on_socket_event_received(event_data: Dictionary):
    var game_event = GameEvent.new()
    game_event.type = event_data.get("type", "")
    game_event.active_turn_player_id = event_data.get("activeTurnPlayerId", "")
    game_event.turn = event_data.get("turn", 0)
    game_event.text = event_data.get("text", "")
    game_event.hidden = event_data.get("hidden", false)
    # ... set other fields

    events.append(game_event)
    set_events(events, battle_state, current_player_id)
```

#### Persisting Preferences
```gdscript
func _save_preferences():
    var config = ConfigFile.new()
    config.set_value("event_log", "position_x", position.x)
    config.set_value("event_log", "position_y", position.y)
    config.set_value("event_log", "width", size.x)
    config.set_value("event_log", "height", size.y)
    config.set_value("event_log", "is_expanded", is_expanded)
    config.save("user://event_log_preferences.cfg")

func _load_preferences():
    var config = ConfigFile.new()
    var err = config.load("user://event_log_preferences.cfg")
    if err == OK:
        initial_position.x = config.get_value("event_log", "position_x", 0)
        initial_position.y = config.get_value("event_log", "position_y", 0)
        initial_width = config.get_value("event_log", "width", 300)
        initial_height = config.get_value("event_log", "height", 400)
        initial_opened = config.get_value("event_log", "is_expanded", true)
```

### 7. Event Detail Modal

The original React component opens a modal when clicking an event. In Godot, create a separate `EventDetailModal` scene with:

```
EventDetailModal (Panel)
├── CloseButton (Button)
├── PreviousButton (Button)
├── NextButton (Button)
├── EventDetailsContainer (VBoxContainer)
│   ├── TurnLabel (Label)
│   ├── PlayerInfo (HBoxContainer)
│   ├── EventTypeLabel (Label)
│   └── DetailsLabel (RichTextLabel)
```

Connect to the `event_clicked` signal:
```gdscript
event_log.event_clicked.connect(_on_event_clicked)

func _on_event_clicked(event_index: int):
    var modal = preload("res://EventDetailModal.tscn").instantiate()
    modal.set_event(events[event_index], battle_state, current_player_id)
    add_child(modal)
```

### 8. Performance Considerations

- **Limit visible events**: Only show `max_events` (15) to avoid lag
- **Reuse nodes**: Consider using a node pool for event items
- **Lazy loading**: Only create visible items in ScrollContainer viewport
- **Texture caching**: Cache Discord avatars to avoid repeated downloads
- **Debounce saves**: Wait 500ms after drag/resize before saving preferences

### 9. Visual Polish

#### Hover Effects
```gdscript
item.mouse_entered.connect(func():
    var tween = create_tween()
    tween.tween_property(item, "position:x", 4, 0.2)
    # Add shadow effect
    item.material = preload("res://shaders/glow.gdshader")
)

item.mouse_exited.connect(func():
    var tween = create_tween()
    tween.tween_property(item, "position:x", 0, 0.2)
    item.material = null
)
```

#### Resize Handle Indicators
- 30px wide × 3px tall colored bars
- Positioned at center of edges
- Change color on hover (0.3 → 0.6 alpha)
- Rounded corners (2px border radius)

### 10. Testing Checklist

- [ ] Events appear in correct order (oldest to newest)
- [ ] New events slide in from left with fade animation
- [ ] Hidden events are filtered out
- [ ] Panel can be dragged anywhere on screen
- [ ] Panel can be resized horizontally and vertically
- [ ] Minimum size constraints are enforced
- [ ] Panel can be collapsed and expanded
- [ ] Auto-scroll works when at bottom
- [ ] Auto-scroll stops when user scrolls up
- [ ] Auto-scroll resumes when user scrolls to bottom
- [ ] Player 1 events show blue border
- [ ] Player 2 events show red border
- [ ] Discord avatars load correctly
- [ ] Event icons and indicators display correctly
- [ ] Clicking events emits signal
- [ ] Preferences persist across sessions
- [ ] Hover effects work on event items
- [ ] Resize handles visible and functional

### 11. Common Pitfalls

1. **ScrollContainer not scrolling**: Ensure `VBoxContainer` inside has proper sizing
2. **Dragging doesn't work**: Check that `gui_input` signals are connected properly
3. **Animations don't play**: Verify `Tween` is not being overwritten before completing
4. **Textures not loading**: Use `HTTPRequest` for async loading, handle errors
5. **Performance lag**: Limit visible events and use node pooling
6. **Position resets**: Save preferences in debounced manner, not on every frame
7. **Resize handles invisible**: Ensure z-index is higher than panel content

## Conclusion

This guide provides a complete blueprint for recreating the EventLog component in Godot. The key differences from React are:

- **State management**: Use Godot's built-in properties instead of React hooks
- **Animation**: Use `Tween` nodes instead of CSS animations
- **Events**: Use Godot signals instead of React callbacks
- **Styling**: Use `StyleBox` resources instead of inline CSS
- **Async operations**: Use `HTTPRequest` and `await` instead of fetch/promises

The core functionality remains the same: a draggable, resizable, collapsible event log with auto-scrolling and smooth animations.

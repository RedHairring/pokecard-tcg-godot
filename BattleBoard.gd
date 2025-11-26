extends Node

@export var card_scene: PackedScene

  # Position constants for card placement
const PLAYER_ACTIVE_POS = Vector2(658, 420)
const PLAYER_BENCH_Y = 570
const PLAYER_BENCH_START_X = 392

const OPPONENT_ACTIVE_POS = Vector2(658, 250)
const OPPONENT_BENCH_Y = 90
const OPPONENT_BENCH_START_X = 392

const BENCH_SPACING = 136

# Hand position constants
const PLAYER_HAND_START_X = 200
const PLAYER_HAND_START_Y = 700
const OPPONENT_HAND_START_X = 200
const OPPONENT_HAND_START_Y = -10

const HAND_CARD_SPACING_X = 120
const HAND_CARD_SPACING_Y = 100
const HAND_CARDS_PER_ROW = 8

# Discard pile position constants
const PLAYER_DISCARD_POS = Vector2(1150, 620)
const OPPONENT_DISCARD_POS = Vector2(166, 50)

# Deck pile position constants (next to discard piles)
const PLAYER_DECK_POS = Vector2(1030, 620)
const OPPONENT_DECK_POS = Vector2(286, 50)

var spawned_cards: Array = []

func _ready():
	# Connect to SignalManager to receive battle state
	SignalManager.battle_state_loaded.connect(_on_battle_state_loaded)
	if not BattleStateManager.battle_state.is_empty():
		print("[BattleBoard] State already loaded, rendering now!")
		_on_battle_state_loaded(BattleStateManager.battle_state)
	
	
func _on_battle_state_loaded(state: Dictionary):
	print("[BattleBoard] Battle state loaded!")
	render_battle_state(state)


func render_battle_state(state: Dictionary):
	#clear_all_cards()
	var all_cards = state.cards
	
	spawn_cards(all_cards)
	pass
	
func spawn_cards(all_cards):
	# First pass: count cards in each hand, discard, and deck; find top discard cards
	var player_hand_count = 0
	var opponent_hand_count = 0
	var player_discard_count = 0
	var opponent_discard_count = 0
	var player_deck_count = 0
	var opponent_deck_count = 0
	var player_top_discard = null
	var opponent_top_discard = null

	for card in all_cards:
		if card.location.type == "hand":
			if card.owner == BattleStateManager.current_player_id:
				player_hand_count += 1
			else:
				opponent_hand_count += 1
		elif card.location.type == "discard":
			var index = int(card.location.index)
			if card.owner == BattleStateManager.current_player_id:
				player_discard_count += 1
				if player_top_discard == null or index > int(player_top_discard.location.index):
					player_top_discard = card
			else:
				opponent_discard_count += 1
				if opponent_top_discard == null or index > int(opponent_top_discard.location.index):
					opponent_top_discard = card
		elif card.location.type == "deck":
			if card.owner == BattleStateManager.current_player_id:
				player_deck_count += 1
			else:
				opponent_deck_count += 1

	# Second pass: render cards
	for card in all_cards:
		# Only render cards in active, bench, or hand locations
		if card.location.type not in ["active", "bench", "hand"]:
			continue

		var position: Vector2

		if card.location.type == "active":
			if (card.owner == BattleStateManager.current_player_id):
				position = PLAYER_ACTIVE_POS
			else:
				position = OPPONENT_ACTIVE_POS
			render_card(card, position)

		elif card.location.type == "bench":
			if (card.owner == BattleStateManager.current_player_id):
				position = Vector2(PLAYER_BENCH_START_X + (card.location.index * BENCH_SPACING), PLAYER_BENCH_Y)
			else:
				position = Vector2(OPPONENT_BENCH_START_X + (card.location.index * BENCH_SPACING), OPPONENT_BENCH_Y)

			render_card(card, position)

		elif card.location.type == "hand":
			var index = int(card.location.index)
			var row = index / HAND_CARDS_PER_ROW
			var col = index % HAND_CARDS_PER_ROW

			var is_player = card.owner == BattleStateManager.current_player_id
			var hand_count = player_hand_count if is_player else opponent_hand_count

			# Calculate how many cards are in this specific row
			var cards_in_this_row = min(HAND_CARDS_PER_ROW, hand_count - (row * HAND_CARDS_PER_ROW))

			# Calculate centering offset for this row
			var row_width = (cards_in_this_row - 1) * HAND_CARD_SPACING_X
			var screen_center_x = 658 # Based on active card position
			var row_start_x = screen_center_x - (row_width / 2.0)

			if is_player:
				position = Vector2(
					row_start_x + (col * HAND_CARD_SPACING_X),
					PLAYER_HAND_START_Y + (row * HAND_CARD_SPACING_Y)
				)
			else:
				position = Vector2(
					row_start_x + (col * HAND_CARD_SPACING_X),
					OPPONENT_HAND_START_Y + (row * HAND_CARD_SPACING_Y)
				)

			render_card(card, position)

	# Render top discard cards with counts
	if player_top_discard != null:
		render_card(player_top_discard, PLAYER_DISCARD_POS)
		create_discard_count_label(PLAYER_DISCARD_POS, player_discard_count)
	if opponent_top_discard != null:
		render_card(opponent_top_discard, OPPONENT_DISCARD_POS)
		create_discard_count_label(OPPONENT_DISCARD_POS, opponent_discard_count)

	# Render deck piles with counts
	if player_deck_count > 0:
		render_deck_card(PLAYER_DECK_POS)
		create_discard_count_label(PLAYER_DECK_POS, player_deck_count)
	if opponent_deck_count > 0:
		render_deck_card(OPPONENT_DECK_POS)
		create_discard_count_label(OPPONENT_DECK_POS, opponent_deck_count)

func render_card(card, position):
	var card_instance = card_scene.instantiate()
	card_instance.position = position
	add_child(card_instance)
	card_instance.set_card_data(card)

func render_deck_card(position: Vector2):
	# Create a Sprite2D to display the card back
	print("POSITION", position)
	var sprite = Sprite2D.new()

	# Load the card back texture
	var card_back_texture = load("res://assets/defaultCardBack.png")

	if card_back_texture:
		sprite.texture = card_back_texture

		# Scale the sprite to match card size (similar to bench/active cards)
		# Using the same scale as other cards on the field
		var scale_factor = Global.get_scale_from_size("bench")
		sprite.scale = scale_factor

		# Set position
		sprite.position = position

		# Add to scene
		add_child(sprite)
	else:
		print("[BattleBoard] ERROR: Failed to load card back texture")

func create_discard_count_label(card_position: Vector2, count: int):
	var label = Label.new()
	label.text = str(count)

	# Style the label - make it bigger and more visible
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)

	# Make sure label has proper size
	label.size = Vector2(40, 40)

	# Position at bottom right corner of the card
	# Using smaller offset to keep label on screen
	label.position = card_position + Vector2(30, 40)

	# Ensure label is on top
	label.z_index = 100

	add_child(label)

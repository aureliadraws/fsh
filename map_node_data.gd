extends Resource
class_name MapNodeData

enum NodeType {
	COMBAT,
	ELITE,
	SALVAGE,
	REST,
	MYSTERY,
	MERCHANT,
	BOSS,
	WORKSTATION  # New: combine cards
}

@export var type: NodeType = NodeType.COMBAT
@export var node_id: int = 0
@export var row: int = 0  # Vertical position (0 = start, higher = closer to boss)
@export var column: int = 0  # Horizontal position
@export var connections: Array[int] = []  # IDs of nodes this connects to
@export var completed: bool = false
@export var available: bool = false  # Can player travel here?

# Combat specific
@export var fish_pool: Array[FishData] = []
@export var is_elite: bool = false

# For mystery/events
@export var event_id: String = ""


func get_type_name() -> String:
	match type:
		NodeType.COMBAT: return "Combat"
		NodeType.ELITE: return "Elite"
		NodeType.SALVAGE: return "Salvage"
		NodeType.REST: return "Rest"
		NodeType.MYSTERY: return "Mystery"
		NodeType.MERCHANT: return "Merchant"
		NodeType.BOSS: return "Boss"
		NodeType.WORKSTATION: return "Workstation"
	return "Unknown"


func get_type_icon() -> String:
	match type:
		NodeType.COMBAT: return "⚔️"
		NodeType.ELITE: return "💀"
		NodeType.SALVAGE: return "📦"
		NodeType.REST: return "⚓"
		NodeType.MYSTERY: return "❓"
		NodeType.MERCHANT: return "💰"
		NodeType.BOSS: return "👑"
		NodeType.WORKSTATION: return "🔧"
	return "•"

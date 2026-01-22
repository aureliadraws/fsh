extends RefCounted
class_name MapGenerator

## Generates a procedural node map like Slay the Spire
## STRUCTURE:
## Row 0: Always SALVAGE (starting salvage site with 3 options)
## Row 1-2: Easy combats (1 fish each)
## Row 3-4: Medium encounters
## Row 5-6: Harder encounters  
## Row 7: BOSS

const NUM_ROWS: int = 8  # Including starting salvage row
const MIN_COLUMNS: int = 2
const MAX_COLUMNS: int = 4

# Node type weights per stage - updated with WORKSTATION
const EARLY_WEIGHTS := {
	MapNodeData.NodeType.COMBAT: 65,  # Easy 1-fish fights
	MapNodeData.NodeType.MYSTERY: 20,
	MapNodeData.NodeType.SALVAGE: 15,
}

const MID_WEIGHTS := {
	MapNodeData.NodeType.COMBAT: 40,
	MapNodeData.NodeType.ELITE: 10,
	MapNodeData.NodeType.MYSTERY: 12,
	MapNodeData.NodeType.SALVAGE: 15,
	MapNodeData.NodeType.REST: 8,
	MapNodeData.NodeType.MERCHANT: 8,
	MapNodeData.NodeType.WORKSTATION: 7,  # New
}

const LATE_WEIGHTS := {
	MapNodeData.NodeType.COMBAT: 25,
	MapNodeData.NodeType.ELITE: 25,
	MapNodeData.NodeType.REST: 18,
	MapNodeData.NodeType.SALVAGE: 10,
	MapNodeData.NodeType.MERCHANT: 12,
	MapNodeData.NodeType.WORKSTATION: 10,  # New
}


static func generate_map() -> Array:
	var nodes: Array = []
	var node_id: int = 0
	var rows: Array = []  # Array of arrays, each containing node IDs in that row
	var prev_row_types: Array = []  # Track types from previous row
	
	# ROW 0: Always a single SALVAGE node (starting point)
	var start_salvage := MapNodeData.new()
	start_salvage.node_id = node_id
	start_salvage.row = 0
	start_salvage.column = 1  # Center-ish
	start_salvage.type = MapNodeData.NodeType.SALVAGE
	start_salvage.available = true  # Start here
	nodes.append(start_salvage)
	rows.append([node_id])
	prev_row_types = [MapNodeData.NodeType.SALVAGE]
	node_id += 1
	
	# Generate remaining rows
	for row in range(1, NUM_ROWS):
		var num_nodes: int = randi_range(MIN_COLUMNS, MAX_COLUMNS)
		
		# Boss row is always single node
		if row == NUM_ROWS - 1:
			num_nodes = 1
		
		var row_nodes: Array = []
		var current_row_types: Array = []
		
		for col in num_nodes:
			var node := MapNodeData.new()
			node.node_id = node_id
			node.row = row
			node.column = col
			
			# Boss row
			if row == NUM_ROWS - 1:
				node.type = MapNodeData.NodeType.BOSS
			else:
				# Pick type avoiding duplicates from previous row (except COMBAT)
				node.type = _pick_node_type_avoiding_duplicates(row, prev_row_types, current_row_types)
			
			current_row_types.append(node.type)
			nodes.append(node)
			row_nodes.append(node_id)
			node_id += 1
		
		rows.append(row_nodes)
		prev_row_types = current_row_types
	
	# Generate connections between rows
	_generate_connections(nodes, rows)
	
	return nodes


static func _pick_node_type_avoiding_duplicates(row: int, prev_types: Array, current_types: Array) -> MapNodeData.NodeType:
	var weights: Dictionary
	
	# Row 1-2: Early game (easy fights)
	if row <= 2:
		weights = EARLY_WEIGHTS.duplicate()
	# Row 3-4: Mid game
	elif row <= 4:
		weights = MID_WEIGHTS.duplicate()
	# Row 5-6: Late game (before boss)
	else:
		weights = LATE_WEIGHTS.duplicate()
	
	# Force a REST before boss (row 6)
	if row == NUM_ROWS - 2:
		if randi() % 100 < 40:  # 40% chance of rest before boss
			return MapNodeData.NodeType.REST
	
	# Remove types that appeared in previous row (except COMBAT and ELITE which can repeat)
	for prev_type in prev_types:
		if prev_type != MapNodeData.NodeType.COMBAT and prev_type != MapNodeData.NodeType.ELITE:
			if weights.has(prev_type):
				weights.erase(prev_type)
	
	# Also avoid duplicating types within the same row (more variety)
	for curr_type in current_types:
		if curr_type != MapNodeData.NodeType.COMBAT:
			if weights.has(curr_type):
				# Reduce weight instead of removing completely
				weights[curr_type] = maxi(1, weights[curr_type] / 3)
	
	# Fallback: if all non-combat options removed, allow combat
	if weights.is_empty():
		return MapNodeData.NodeType.COMBAT
	
	var total: int = 0
	for w in weights.values():
		total += w
	
	if total == 0:
		return MapNodeData.NodeType.COMBAT
	
	var roll: int = randi() % total
	var cumulative: int = 0
	
	for type in weights:
		cumulative += weights[type]
		if roll < cumulative:
			return type
	
	return MapNodeData.NodeType.COMBAT


static func _generate_connections(nodes: Array, rows: Array) -> void:
	# Connect each row to the next
	for row_idx in rows.size() - 1:
		var current_row: Array = rows[row_idx]
		var next_row: Array = rows[row_idx + 1]
		
		# Ensure every node has at least one connection forward
		for nid in current_row:
			var node: MapNodeData = nodes[nid]
			var possible_targets: Array = []
			
			# Find valid targets (nearby columns in next row)
			for target_nid in next_row:
				var target: MapNodeData = nodes[target_nid]
				var col_diff: int = absi(node.column - target.column)
				# Allow connection if column difference is 0 or 1
				if col_diff <= 1:
					possible_targets.append(target_nid)
			
			# If no nearby targets, connect to closest
			if possible_targets.is_empty():
				var closest: int = next_row[0]
				var closest_dist: int = 999
				for target_nid in next_row:
					var target: MapNodeData = nodes[target_nid]
					var dist: int = absi(node.column - target.column)
					if dist < closest_dist:
						closest_dist = dist
						closest = target_nid
				possible_targets.append(closest)
			
			# Add 1-2 connections
			var num_connections: int = mini(randi_range(1, 2), possible_targets.size())
			possible_targets.shuffle()
			
			for i in num_connections:
				if not node.connections.has(possible_targets[i]):
					node.connections.append(possible_targets[i])
		
		# Ensure every node in next row has at least one incoming connection
		for target_nid in next_row:
			var has_incoming: bool = false
			for nid in current_row:
				var check_node: MapNodeData = nodes[nid]
				if check_node.connections.has(target_nid):
					has_incoming = true
					break
			
			if not has_incoming:
				# Connect from nearest node in current row
				var closest: int = current_row[0]
				var closest_dist: int = 999
				for nid in current_row:
					var src_node: MapNodeData = nodes[nid]
					var tgt_node: MapNodeData = nodes[target_nid]
					var dist: int = absi(src_node.column - tgt_node.column)
					if dist < closest_dist:
						closest_dist = dist
						closest = nid
				var final_node: MapNodeData = nodes[closest]
				final_node.connections.append(target_nid)

class_name BlastReach
extends RefCounted

## Static helpers for "does a round blast reach this enemy?" measured to the
## enemy's EDGE (its collision shapes), not its center. Used by the pollen
## puff burst (bullets/bullet_pollen_puff.gd). Same geometry as the bubble
## pop's check in bullets/bubble.gd.
##
## Plain geometry, no physics query - blasts often go off inside collision
## callbacks, where the physics space is locked.


static func enemies_in_blast(center: Vector2, radius: float, tree: SceneTree) -> Array:
	"""Every live node in the "enemies" group that the blast reaches."""
	var out: Array = []
	for enemy in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and reaches(center, radius, enemy):
			out.append(enemy)
	return out


static func reaches(center: Vector2, radius: float, enemy: Node) -> bool:
	if not (enemy is Node2D):
		return false
	if center.distance_to(enemy.global_position) <= radius:
		return true
	for shape_node in hitbox_nodes(enemy):
		var closest = closest_point_on_hitbox(shape_node, center)
		if closest != null and center.distance_to(closest) <= radius:
			return true
	return false


static func hitbox_nodes(enemy: Node) -> Array:
	"""The enemy's own CollisionShape2D / CollisionPolygon2D nodes - direct
	children first; if none, deeper, but never inside child nodes that are
	enemies themselves (boss parts are checked on their own)."""
	var out: Array = []
	for c in enemy.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			out.append(c)
	if out.is_empty():
		_collect(enemy, out)
	return out


static func _collect(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c.is_in_group("enemies"):
			continue
		if c is CollisionShape2D or c is CollisionPolygon2D:
			out.append(c)
		_collect(c, out)


static func closest_point_on_hitbox(shape_node: Node2D, point: Vector2):
	"""Closest point (global) of the shape to `point`, `point` itself if
	it's inside, or null for an unhandled shape type."""
	var xf: Transform2D = shape_node.global_transform
	var p: Vector2 = xf.affine_inverse() * point
	var local = null
	if shape_node is CollisionPolygon2D:
		local = _closest_on_polygon(shape_node.polygon, p)
	else:
		var shape: Shape2D = shape_node.shape
		if shape is CircleShape2D:
			var r: float = shape.radius
			local = p if p.length() <= r else p.normalized() * r
		elif shape is RectangleShape2D:
			var h: Vector2 = shape.size * 0.5
			local = Vector2(clampf(p.x, -h.x, h.x), clampf(p.y, -h.y, h.y))
		elif shape is CapsuleShape2D:
			var cr: float = shape.radius
			var half: float = maxf(shape.height * 0.5 - cr, 0.0)
			var on_axis := Vector2(0.0, clampf(p.y, -half, half))
			var d: Vector2 = p - on_axis
			local = p if d.length() <= cr else on_axis + d.normalized() * cr
		elif shape is ConvexPolygonShape2D:
			local = _closest_on_polygon(shape.points, p)
	if local == null:
		return null
	return xf * local


static func _closest_on_polygon(poly: PackedVector2Array, p: Vector2):
	if poly.size() < 3:
		return null
	if Geometry2D.is_point_in_polygon(p, poly):
		return p
	var best := Vector2.ZERO
	var best_d := INF
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best

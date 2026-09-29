# Echoes of BIC — Week 1-2 Code Setup

This covers wiring `player_controller.gd` and `interactable.gd` into a fresh Godot 4 project. Everything below is editor setup — no more code needed to get movement and interaction working.

## 1. Input Map (Project Settings → Input Map)

Add these actions:

| Action name     | Suggested binding      |
|------------------|------------------------|
| `move_forward`   | W |
| `move_back`       | S |
| `move_left`       | A |
| `move_right`      | D |
| `interact`         | E |
| `ui_cancel`        | Esc (usually exists by default) |

## 2. Player scene node tree

Create a new scene, root node type `CharacterBody3D`, and build this hierarchy:

```
Player (CharacterBody3D)  <- attach player_controller.gd here
├── CollisionShape3D        (capsule shape, ~1.8m tall)
├── Head (Node3D)
│   └── Camera3D
│       └── InteractRay (RayCast3D)
```

- `CollisionShape3D`: standard capsule, radius ~0.35, height ~1.8, positioned so the bottom sits at the body's origin.
- `Head`: position at roughly eye height (around Y = 1.6 relative to the body's feet). This is what pitches up/down when looking.
- `Camera3D`: sits under Head with no extra offset.
- `InteractRay`: a `RayCast3D` under the Camera, pointing forward (this is set automatically by the script via `target_position`, so no manual aiming needed — just make sure `Enabled` is on and it exists as a child at that path).

Save this as `player.tscn` and drop it into your BIC desk scene.

## 3. Making desk objects interactable

Any object the player should be able to use (stamp, rejection slip, radio, doors, the printer) needs to be a `StaticBody3D` with:
- A `CollisionShape3D` child matching its clickable area
- A script that `extends Interactable` (see `examples/stamp_action.gd` for the pattern)

The player's raycast will pick these up automatically — no manual registration needed.

## 4. Hooking up the on-screen prompt (optional but recommended immediately)

The player controller emits `focus_changed(interactable)` every time what you're looking at changes (and `null` when looking at nothing interactable). Connect this from your HUD script:

```gdscript
func _on_player_focus_changed(interactable: Node) -> void:
    if interactable:
        prompt_label.text = interactable.get_prompt()
        prompt_label.visible = true
    else:
        prompt_label.visible = false
```

## 5. What this unlocks for the rest of Week 1-2

With this in place you can:
- Walk around the gray-boxed building from entrance to the meeting room dead end
- Look around with the mouse, cleanly clamped so you can't flip the camera over
- Look at any object, see a prompt, and press E to trigger its `interact()` — ready for the stamp, rejection slip, radio/flag, and every door in the building

Next real code milestone (Weeks 3-5) is the desk loop itself: the document viewer, ID drag-compare, and dialogue system, which will build on top of this same Interactable pattern.

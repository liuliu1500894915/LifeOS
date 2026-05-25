# Pet Animation Assets

This directory holds Rive (.riv) animation files for the pet character.

## Required Files

| File | Purpose | Duration |
|------|---------|----------|
| `pet_idle.riv` | Idle breathing loop | ~3s loop |
| `pet_happy.riv` | Happy / satisfied reaction | ~2s |
| `pet_tired.riv` | Tired / low energy animation | ~2s |
| `pet_hungry.riv` | Hungry / thirsty animation | ~2s |
| `pet_sick.riv` | Sick / critical state | ~2s |
| `pet_excited.riv` | Excited / celebration reaction | ~2s |
| `pet_sleeping.riv` | Sleeping loop (eyes closed, Zzz) | ~5s loop |

## State Machine Structure

Each .riv file MUST contain a state machine named `pet_state` with:

### Triggers
- `transition_out` — fires before the animation ends to signal the controller

### Number Inputs (for visual blending)
- `energy_level` (0-100) — drives posture brightness / movement speed
- `mood_level` (0-100) — drives facial expression / color saturation
- `hydration_level` (0-100) — drives water-related visual effects

## Growth Stage Visuals

The pet has 5 growth stages. Each .riv file should include all 5 as nested
artboards or as conditions within the state machine:

1. EGG — small oval, wobble movement
2. BABY — tiny creature, fast movements
3. TEEN — adolescent proportions, energetic
4. ADULT — full-size, calm confidence
5. LEGEND — glowing aura, majestic pose

## Integration

The Flutter code in `lib/features/home/presentation/widgets/pet_character.dart`
handles the Rive animation loading and state machine control.
When .riv files are placed here, uncomment the RiveAnimation.asset() code
and remove the placeholder widget.

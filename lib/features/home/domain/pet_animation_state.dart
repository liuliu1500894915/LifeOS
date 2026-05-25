import 'vital_calculator.dart';

/// Pet animation states mapped to Rive state machine inputs.
enum PetAnimationState {
  idle,
  happy,
  tired,
  hungry,
  thirsty,
  sick,
  excited,
  sleeping,
}

/// Maps the pet's computed overall status to animation states.
class PetAnimationMapper {
  const PetAnimationMapper._();

  static PetAnimationState fromVitals(PetVitals vitals) {
    return vitals.dominantAnimation;
  }

  /// Maps a status level (from pet_status_core.overall_status_level)
  /// and a growth stage to the appropriate animation state.
  static PetAnimationState fromStatus({
    required String overallStatus,
    required String growthStage,
  }) {
    switch (overallStatus) {
      case 'CRITICAL':
        return PetAnimationState.sick;
      case 'LOW':
        if (growthStage == 'EGG' || growthStage == 'BABY') {
          return PetAnimationState.hungry;
        }
        return PetAnimationState.tired;
      case 'GOOD':
        return PetAnimationState.happy;
      case 'EXCELLENT':
        return PetAnimationState.excited;
      case 'NORMAL':
      default:
        return PetAnimationState.idle;
    }
  }
}

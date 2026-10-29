import 'package:smart_fridge_app/features/family/domain/family_info.dart';

class FamilyWorkspaceState {
  const FamilyWorkspaceState({
    required this.families,
    required this.selectedFamilyId,
  });

  final List<FamilyInfo> families;
  final int? selectedFamilyId;

  FamilyInfo? get selectedFamily {
    for (final family in families) {
      if (family.id == selectedFamilyId) {
        return family;
      }
    }
    return null;
  }

  FamilyWorkspaceState withSelectedFamily(int familyId) {
    return FamilyWorkspaceState(families: families, selectedFamilyId: familyId);
  }
}

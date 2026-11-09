package com.smartfridge.auth.workspace;

import com.smartfridge.auth.family.FamilyView;

public record WorkspaceView(FamilyView family, long fridgeId) {
}

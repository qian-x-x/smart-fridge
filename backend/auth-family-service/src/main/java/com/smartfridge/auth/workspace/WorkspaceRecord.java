package com.smartfridge.auth.workspace;

record WorkspaceRecord(long userId, String requestId, String familyName, long familyId,
                       Long fridgeId, String xid, boolean completed) {
}

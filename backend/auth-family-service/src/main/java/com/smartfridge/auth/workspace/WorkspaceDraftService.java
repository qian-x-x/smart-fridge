/*
 * 这个文件：工作区分两步落库：先登记请求并创建家庭，等冰箱建好后再回填冰箱 id。
 */

package com.smartfridge.auth.workspace;

import com.smartfridge.auth.family.FamilyService;
import com.smartfridge.auth.family.FamilyView;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Each call commits one AT branch before the next service is invoked. */
@Service
public class WorkspaceDraftService {
    private final WorkspaceRepository repository;
    private final FamilyService families;
    private final WorkspaceTransactionStatus transactions;

    public WorkspaceDraftService(WorkspaceRepository repository, FamilyService families,
                                 WorkspaceTransactionStatus transactions) {
        this.repository = repository;
        this.families = families;
        this.transactions = transactions;
    }

    @Transactional
    public FamilyView prepare(long userId, CreateWorkspaceRequest request) {
        repository.claim(userId, request, transactions.currentXid());
        FamilyView family = families.create(userId, request.normalizedName());
        repository.attachFamily(userId, request.requestId(), family.id());
        return family;
    }

    @Transactional
    public void finish(long userId, String requestId, long fridgeId) {
        repository.finish(userId, requestId, fridgeId);
    }
}

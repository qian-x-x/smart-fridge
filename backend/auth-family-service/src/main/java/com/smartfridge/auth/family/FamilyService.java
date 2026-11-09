package com.smartfridge.auth.family;

import com.smartfridge.common.error.BusinessException;
import com.smartfridge.auth.workspace.FamilyWorkspaceVisibility;
import java.security.SecureRandom;
import java.util.List;
import java.util.Locale;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class FamilyService {

    private static final char[] INVITE_ALPHABET =
        "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".toCharArray();

    private final FamilyRepository familyRepository;
    private final FamilyWorkspaceVisibility workspaceVisibility;
    private final SecureRandom secureRandom = new SecureRandom();

    public FamilyService(FamilyRepository familyRepository, FamilyWorkspaceVisibility workspaceVisibility) {
        this.familyRepository = familyRepository;
        this.workspaceVisibility = workspaceVisibility;
    }

    @Transactional
    public FamilyView create(long userId, String name) {
        String inviteCode = generateInviteCode();
        FamilyView family = familyRepository.create(name.trim(), inviteCode, userId);
        familyRepository.addMember(family.id(), userId, "OWNER");
        return new FamilyView(
            family.id(),
            family.name(),
            family.inviteCode(),
            family.ownerUserId(),
            "OWNER",
            family.createdAt()
        );
    }

    public List<FamilyView> list(long userId) {
        return familyRepository.findAllByUserId(userId).stream()
            .filter(family -> workspaceVisibility.visible(family.id())).toList();
    }

    public FamilyView requireMember(long userId, long familyId) {
        return familyRepository.findAllByUserId(userId).stream()
            .filter(family -> family.id() == familyId)
            .filter(family -> workspaceVisibility.visible(family.id()))
            .findFirst()
            .orElseThrow(() -> BusinessException.notFound("家庭不存在或无权访问"));
    }

    private String generateInviteCode() {
        char[] code = new char[8];
        for (int index = 0; index < code.length; index++) {
            code[index] = INVITE_ALPHABET[secureRandom.nextInt(INVITE_ALPHABET.length)];
        }
        return new String(code);
    }
    @Transactional
    public FamilyView join(long userId, String inviteCode) {
        String normalizedCode = inviteCode.trim().toUpperCase(Locale.ROOT);
        FamilyRecord family = familyRepository.findByInviteCode(normalizedCode)
            .orElseThrow(() -> BusinessException.notFound("邀请码无效"));
        if (!workspaceVisibility.visible(family.id())) {
            throw BusinessException.notFound("邀请码无效或家庭尚未初始化");
        }

        String existingRole = familyRepository.findRole(family.id(), userId);
        if (existingRole != null) {
            return family.viewFor(existingRole);
        }

        try {
            familyRepository.addMember(family.id(), userId, "VIEWER");
        } catch (DuplicateKeyException ignored) {
            String roleAfterRace = familyRepository.findRole(family.id(), userId);
            if (roleAfterRace != null) {
                return family.viewFor(roleAfterRace);
            }
            throw ignored;
        }
        return family.viewFor("VIEWER");
    }

    public List<FamilyMemberView> listMembers(long userId, long familyId) {
        requireMember(userId, familyId);
        return familyRepository.findMembers(familyId, userId);
    }

    @Transactional
    public FamilyMemberView updateMemberRole(
        long actorId,
        long familyId,
        long targetUserId,
        String requestedRole
    ) {
        FamilyRecord family = lockAndRequireOwner(actorId, familyId);
        FamilyMemberView target = familyRepository.findMember(familyId, targetUserId, actorId)
            .orElseThrow(() -> BusinessException.notFound("家庭成员不存在"));
        if (target.userId() == family.ownerUserId()) {
            throw BusinessException.conflict("不能通过成员接口调整拥有者，请使用所有权转交");
        }
        if (!"EDITOR".equals(requestedRole) && !"VIEWER".equals(requestedRole)) {
            throw BusinessException.conflict("成员角色只能是 EDITOR 或 VIEWER");
        }
        familyRepository.updateMemberRole(familyId, targetUserId, requestedRole);
        return new FamilyMemberView(
            target.userId(),
            target.username(),
            target.displayName(),
            requestedRole,
            target.joinedAt(),
            target.currentUser()
        );
    }

    @Transactional
    public void removeMember(long actorId, long familyId, long targetUserId) {
        FamilyRecord family = lockAndRequireOwner(actorId, familyId);
        FamilyMemberView target = familyRepository.findMember(familyId, targetUserId, actorId)
            .orElseThrow(() -> BusinessException.notFound("家庭成员不存在"));
        if (target.userId() == family.ownerUserId()) {
            throw BusinessException.conflict("不能移除家庭拥有者");
        }
        familyRepository.removeMember(familyId, targetUserId);
    }

    private FamilyRecord lockAndRequireOwner(long actorId, long familyId) {
        FamilyRecord family = familyRepository.lockById(familyId)
            .orElseThrow(() -> BusinessException.notFound("家庭不存在或无权访问"));
        requireOwner(actorId, family);
        return family;
    }

    private void requireOwner(long actorId, FamilyRecord family) {
        if (!workspaceVisibility.visible(family.id())) {
            throw BusinessException.notFound("家庭不存在或尚未初始化");
        }
        if (family.ownerUserId() == actorId) {
            return;
        }
        String actorRole = familyRepository.findRole(family.id(), actorId);
        if (actorRole == null) {
            throw BusinessException.notFound("家庭不存在或无权访问");
        }
        throw BusinessException.forbidden("只有家庭拥有者可以管理成员");
    }

    @Transactional
    public FamilyView transferOwner(long actorId, long familyId, long targetUserId) {
        FamilyRecord observed = familyRepository.findById(familyId)
            .orElseThrow(() -> BusinessException.notFound("家庭不存在或无权访问"));
        requireOwner(actorId, observed);

        FamilyRecord locked = familyRepository.lockById(familyId)
            .orElseThrow(() -> BusinessException.notFound("家庭不存在或无权访问"));
        if (locked.ownerUserId() != actorId) {
            throw BusinessException.conflict("家庭所有权已变更，请刷新后重试");
        }

        FamilyMemberView target = familyRepository.findMember(familyId, targetUserId, actorId)
            .orElseThrow(() -> BusinessException.notFound("目标成员不存在"));
        if (!"EDITOR".equals(target.role())) {
            throw BusinessException.conflict("所有权只能转交给 EDITOR");
        }

        familyRepository.transferOwner(familyId, actorId, targetUserId);
        return new FamilyView(
            locked.id(),
            locked.name(),
            locked.inviteCode(),
            targetUserId,
            "EDITOR",
            locked.createdAt()
        );
    }

}

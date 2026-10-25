package com.smartfridge.auth.family;

import com.smartfridge.common.error.BusinessException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.util.List;

@Service
public class FamilyService {

    private static final char[] INVITE_ALPHABET =
        "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".toCharArray();

    private final FamilyRepository familyRepository;
    private final SecureRandom secureRandom = new SecureRandom();

    public FamilyService(FamilyRepository familyRepository) {
        this.familyRepository = familyRepository;
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
        return familyRepository.findAllByUserId(userId);
    }

    public FamilyView requireMember(long userId, long familyId) {
        return familyRepository.findAllByUserId(userId).stream()
            .filter(family -> family.id() == familyId)
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
}

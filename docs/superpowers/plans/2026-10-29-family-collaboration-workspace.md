# Family Collaboration Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add invite-code joining, member governance, ownership transfer, and persistent multi-family selection across the Spring Boot family service and Flutter client.

**Architecture:** Extend the existing `auth-family-service` without adding a service or database table. Family and member state remain the permission source of truth, ownership changes run in transactions with row locks, and Flutter separates family selection from fridge loading so every workspace follows the selected family.

**Tech Stack:** Java 17, Spring Boot 3.2, Spring JDBC, Flyway/H2/MySQL, JUnit 5, MockMvc, Flutter 3.47, Riverpod 3, Dio, shared_preferences, OpenAPI 3.

---

## Execution record — 2026-10-30

Tasks 1–12 are implemented. Backend integration tests cover invite joining, member governance and concurrent owner transfer. Flutter tests cover repositories, persisted account-specific selection, member actions, and fridge/recipe changes on family selection. Full backend and Flutter suites and static analysis pass. Task 13 automated verification passed: Maven package (29 tests), Flutter tests (37), dart analysis, Flutter Web release, OpenAPI reference checks and 390px family-page widget tests. Real Gateway browser smoke remains pending. Historical per-step checkboxes below describe the original plan rather than individual execution evidence.

## Execution Rules

- Run commands from `C:\Users\Lenovo\Desktop\软件开发实践` with PowerShell.
- Use `dart analyze lib test`, not `flutter analyze`, because the current Chinese path breaks the Flutter Analysis Server JSON transport.
- Do not add database migrations: the approved schema already contains `family.invite_code`, `family.owner_user_id`, and `family_member.role`.
- Keep each task independently committed.
- When a test command is expected to fail during RED, confirm the failure is caused by the missing behavior rather than a syntax or environment error.

## File Map

### Backend

- Create: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyRecord.java`
- Create: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyMemberView.java`
- Create: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/JoinFamilyRequest.java`
- Create: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/UpdateFamilyRoleRequest.java`
- Create: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/TransferFamilyOwnerRequest.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyController.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyRepository.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyService.java`
- Create: `backend/auth-family-service/src/test/java/com/smartfridge/auth/FamilyCollaborationIntegrationTest.java`

### Flutter

- Create: `apps/fridge-app/lib/features/family/domain/family_member.dart`
- Create: `apps/fridge-app/lib/features/family/domain/family_workspace_state.dart`
- Create: `apps/fridge-app/lib/features/family/data/family_selection_store.dart`
- Create: `apps/fridge-app/lib/features/family/application/family_members_controller.dart`
- Create: `apps/fridge-app/lib/features/family/presentation/family_workspace_section.dart`
- Create: `apps/fridge-app/lib/features/family/presentation/family_member_management_sheet.dart`
- Modify: `apps/fridge-app/lib/core/network/api_client.dart`
- Modify: `apps/fridge-app/lib/features/family/data/family_repository.dart`
- Modify: `apps/fridge-app/lib/features/family/application/family_controller.dart`
- Modify: `apps/fridge-app/lib/features/fridge/data/api_fridge_repository.dart`
- Modify: `apps/fridge-app/lib/features/fridge/application/fridge_workspace_controller.dart`
- Modify: `apps/fridge-app/lib/features/fridge/domain/fridge_workspace_data.dart`
- Modify: `apps/fridge-app/lib/features/profile/presentation/profile_page.dart`
- Create: `apps/fridge-app/test/api_client_test.dart`
- Create: `apps/fridge-app/test/family_collaboration_repository_test.dart`
- Create: `apps/fridge-app/test/family_workspace_controller_test.dart`
- Create: `apps/fridge-app/test/family_members_controller_test.dart`
- Modify: `apps/fridge-app/test/family_repository_test.dart`
- Modify: `apps/fridge-app/test/family_page_test.dart`
- Modify: `apps/fridge-app/test/api_fridge_repository_test.dart`
- Modify: `apps/fridge-app/test/fridge_workspace_controller_test.dart`
- Modify: `apps/fridge-app/test/fridge_home_test.dart`
- Modify: `apps/fridge-app/test/recipes_page_test.dart`
- Create: `apps/fridge-app/test/recipe_family_selection_test.dart`

### Contracts and Documentation

- Modify: `contracts/openapi/smart-fridge-v1.yaml`
- Modify: `README.md`
- Modify: `docs/开发状态.md`
- Modify: `docs/S2-冰箱领域实现.md`
- Modify: `docs/开发运行手册.md`
- Modify: `docs/superpowers/specs/2026-10-29-family-collaboration-workspace-design.md`

---

### Task 1: Invite-Code Join

**Files:**
- Create: `backend/auth-family-service/src/test/java/com/smartfridge/auth/FamilyCollaborationIntegrationTest.java`
- Create: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyRecord.java`
- Create: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/JoinFamilyRequest.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyRepository.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyService.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyController.java`

- [ ] **Step 1: Write the failing join test and reusable registration helpers**

Create `FamilyCollaborationIntegrationTest.java` with this initial content:

```java
package com.smartfridge.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.smartfridge.auth.session.TokenRevocationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.nio.charset.StandardCharsets;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class FamilyCollaborationIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @org.springframework.boot.test.mock.mockito.SpyBean
    private com.smartfridge.auth.family.FamilyRepository familyRepository;

    @MockBean
    private TokenRevocationService tokenRevocationService;

    @BeforeEach
    void resetDatabase() {
        jdbcTemplate.update("DELETE FROM refresh_session");
        jdbcTemplate.update("DELETE FROM family_member");
        jdbcTemplate.update("DELETE FROM family");
        jdbcTemplate.update("DELETE FROM app_user");
    }

    @Test
    void joinsByInviteCodeIdempotentlyAsViewer() throws Exception {
        Session owner = register("family_owner", "家庭主理人");
        FamilyFixture family = createFamily(owner, "小满的家");
        Session guest = register("family_guest", "家庭访客");

        String joinBody = objectMapper.writeValueAsString(
            new InviteBody(family.inviteCode().toLowerCase())
        );

        mockMvc.perform(post("/api/v1/families/join")
                .header("Authorization", bearer(guest))
                .contentType(MediaType.APPLICATION_JSON)
                .content(joinBody))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.code").value("OK"))
            .andExpect(jsonPath("$.data.id").value(family.id()))
            .andExpect(jsonPath("$.data.name").value("小满的家"))
            .andExpect(jsonPath("$.data.currentUserRole").value("VIEWER"));

        mockMvc.perform(post("/api/v1/families/join")
                .header("Authorization", bearer(guest))
                .contentType(MediaType.APPLICATION_JSON)
                .content(joinBody))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.currentUserRole").value("VIEWER"));

        mockMvc.perform(get("/api/v1/families")
                .header("Authorization", bearer(guest)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.length()").value(1))
            .andExpect(jsonPath("$.data[0].currentUserRole").value("VIEWER"));
    }

    @Test
    void rejectsAnUnknownInviteCode() throws Exception {
        Session guest = register("unknown_invite_guest", "外部访客");

        mockMvc.perform(post("/api/v1/families/join")
                .header("Authorization", bearer(guest))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"inviteCode\":\"AAAA2345\"}"))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.code").value("NOT_FOUND"))
            .andExpect(jsonPath("$.message").value("邀请码无效"));
    }

    private Session register(String username, String displayName) throws Exception {
        String body = objectMapper.writeValueAsString(
            new RegisterBody(username, displayName, "Password123")
        );
        String response = mockMvc.perform(post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
            .andExpect(status().isCreated())
            .andReturn()
            .getResponse()
            .getContentAsString(StandardCharsets.UTF_8);
        JsonNode json = objectMapper.readTree(response);
        return new Session(
            json.at("/data/user/id").asLong(),
            json.at("/data/accessToken").asText()
        );
    }

    private FamilyFixture createFamily(Session owner, String name) throws Exception {
        String body = objectMapper.writeValueAsString(new CreateFamilyBody(name));
        String response = mockMvc.perform(post("/api/v1/families")
                .header("Authorization", bearer(owner))
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
            .andExpect(status().isCreated())
            .andReturn()
            .getResponse()
            .getContentAsString(StandardCharsets.UTF_8);
        JsonNode json = objectMapper.readTree(response).path("data");
        return new FamilyFixture(
            json.path("id").asLong(),
            json.path("inviteCode").asText()
        );
    }

    private String bearer(Session session) {
        return "Bearer " + session.accessToken();
    }

    private record RegisterBody(String username, String displayName, String password) {
    }

    private record CreateFamilyBody(String name) {
    }

    private record InviteBody(String inviteCode) {
    }

    private record Session(long userId, String accessToken) {
    }

    private record FamilyFixture(long id, String inviteCode) {
    }
}
```

- [ ] **Step 2: Run the join test and confirm RED**

```powershell
mvn --batch-mode -pl auth-family-service -am -Dtest=FamilyCollaborationIntegrationTest -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: `joinsByInviteCodeIdempotentlyAsViewer` fails because `POST /api/v1/families/join` returns `404`.

- [ ] **Step 3: Add the join DTO and family record**

Create `JoinFamilyRequest.java`:

```java
package com.smartfridge.auth.family;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record JoinFamilyRequest(
    @NotBlank(message = "邀请码不能为空")
    @Pattern(regexp = "^[A-Za-z0-9]{8}$", message = "邀请码应为 8 位字母或数字")
    String inviteCode
) {
}
```

Create `FamilyRecord.java`:

```java
package com.smartfridge.auth.family;

import java.time.Instant;

record FamilyRecord(
    long id,
    String name,
    String inviteCode,
    long ownerUserId,
    Instant createdAt
) {
    FamilyView viewFor(String role) {
        return new FamilyView(id, name, inviteCode, ownerUserId, role, createdAt);
    }
}
```

- [ ] **Step 4: Add repository lookups**

In `FamilyRepository.java`, add these imports:

```java
import java.util.Optional;
```

Add this row mapper beside `ROW_MAPPER`:

```java
private static final RowMapper<FamilyRecord> FAMILY_RECORD_MAPPER =
    (resultSet, rowNum) -> new FamilyRecord(
        resultSet.getLong("id"),
        resultSet.getString("name"),
        resultSet.getString("invite_code"),
        resultSet.getLong("owner_user_id"),
        resultSet.getTimestamp("created_at").toInstant()
    );
```

Add these methods before `addMember`:

```java
public Optional<FamilyRecord> findById(long familyId) {
    return jdbcTemplate.query(
        """
            SELECT id, name, invite_code, owner_user_id, created_at
            FROM family
            WHERE id = ?
            """,
        FAMILY_RECORD_MAPPER,
        familyId
    ).stream().findFirst();
}

public Optional<FamilyRecord> findByInviteCode(String inviteCode) {
    return jdbcTemplate.query(
        """
            SELECT id, name, invite_code, owner_user_id, created_at
            FROM family
            WHERE invite_code = ?
            """,
        FAMILY_RECORD_MAPPER,
        inviteCode
    ).stream().findFirst();
}
```

- [ ] **Step 5: Implement idempotent join behavior**

In `FamilyService.java`, add these imports:

```java
import org.springframework.dao.DuplicateKeyException;

import java.util.Locale;
```

Add this method after `create`:

```java
@Transactional
public FamilyView join(long userId, String inviteCode) {
    String normalizedCode = inviteCode.trim().toUpperCase(Locale.ROOT);
    FamilyRecord family = familyRepository.findByInviteCode(normalizedCode)
        .orElseThrow(() -> BusinessException.notFound("邀请码无效"));

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
```

- [ ] **Step 6: Expose the join endpoint**

In `FamilyController.java`, add this method before `list`:

```java
@PostMapping("/join")
public ApiResponse<FamilyView> join(
    @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
    @Valid @RequestBody JoinFamilyRequest request
) {
    return ApiResponse.success(familyService.join(user.id(), request.inviteCode()));
}
```

- [ ] **Step 7: Verify join tests pass**

```powershell
mvn --batch-mode -pl auth-family-service -am -Dtest=FamilyCollaborationIntegrationTest -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: `BUILD SUCCESS`; the idempotent join test passes.

- [ ] **Step 8: Commit**

```powershell
git add backend/auth-family-service/src/main/java/com/smartfridge/auth/family backend/auth-family-service/src/test/java/com/smartfridge/auth/FamilyCollaborationIntegrationTest.java
git commit -m "feat(family): join households by invite code"
```

### Task 2: Member Listing

**Files:**
- Create: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyMemberView.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyRepository.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyService.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyController.java`
- Test: `backend/auth-family-service/src/test/java/com/smartfridge/auth/FamilyCollaborationIntegrationTest.java`

- [ ] **Step 1: Add failing member-list tests**

Add these test methods before `register`:

```java
@Test
void listsMembersForFamilyMembersOnly() throws Exception {
    Session owner = register("member_owner", "拥有者");
    FamilyFixture family = createFamily(owner, "成员家庭");
    Session viewer = register("member_viewer", "只读成员");
    join(viewer, family.inviteCode());
    Session outsider = register("member_outsider", "外部用户");

    mockMvc.perform(get("/api/v1/families/{familyId}/members", family.id())
            .header("Authorization", bearer(viewer)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.length()").value(2))
        .andExpect(jsonPath("$.data[0].role").value("OWNER"))
        .andExpect(jsonPath("$.data[0].displayName").value("拥有者"))
        .andExpect(jsonPath("$.data[1].role").value("VIEWER"))
        .andExpect(jsonPath("$.data[1].currentUser").value(true));

    mockMvc.perform(get("/api/v1/families/{familyId}/members", family.id())
            .header("Authorization", bearer(outsider)))
        .andExpect(status().isNotFound());
}
```

Add this helper before `bearer`:

```java
private void join(Session session, String inviteCode) throws Exception {
    mockMvc.perform(post("/api/v1/families/join")
            .header("Authorization", bearer(session))
            .contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(new InviteBody(inviteCode))))
        .andExpect(status().isOk());
}
```

- [ ] **Step 2: Run the member-list test and confirm RED**

```powershell
mvn --batch-mode -pl auth-family-service -am -Dtest=FamilyCollaborationIntegrationTest#listsMembersForFamilyMembersOnly -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: `GET /api/v1/families/{familyId}/members` returns `404`.

- [ ] **Step 3: Add the member view**

Create `FamilyMemberView.java`:

```java
package com.smartfridge.auth.family;

import java.time.Instant;

public record FamilyMemberView(
    long userId,
    String username,
    String displayName,
    String role,
    Instant joinedAt,
    boolean currentUser
) {
}
```

- [ ] **Step 4: Add member queries**

In `FamilyRepository.java`, add this mapper:

```java
private static final RowMapper<FamilyMemberView> MEMBER_MAPPER =
    (resultSet, rowNum) -> new FamilyMemberView(
        resultSet.getLong("user_id"),
        resultSet.getString("username"),
        resultSet.getString("display_name"),
        resultSet.getString("role"),
        resultSet.getTimestamp("joined_at").toInstant(),
        resultSet.getBoolean("current_user")
    );
```

Add these methods after `findAllByUserId`:

```java
public List<FamilyMemberView> findMembers(long familyId, long currentUserId) {
    return jdbcTemplate.query(
        """
            SELECT fm.user_id, u.username, u.display_name, fm.role, fm.joined_at,
                   CASE WHEN fm.user_id = ? THEN TRUE ELSE FALSE END AS current_user
            FROM family_member fm
            JOIN app_user u ON u.id = fm.user_id
            WHERE fm.family_id = ?
            ORDER BY CASE fm.role
                         WHEN 'OWNER' THEN 0
                         WHEN 'EDITOR' THEN 1
                         ELSE 2
                     END,
                     fm.joined_at,
                     fm.id
            """,
        MEMBER_MAPPER,
        currentUserId,
        familyId
    );
}

public java.util.Optional<FamilyMemberView> findMember(
    long familyId,
    long userId,
    long currentUserId
) {
    return jdbcTemplate.query(
        """
            SELECT fm.user_id, u.username, u.display_name, fm.role, fm.joined_at,
                   CASE WHEN fm.user_id = ? THEN TRUE ELSE FALSE END AS current_user
            FROM family_member fm
            JOIN app_user u ON u.id = fm.user_id
            WHERE fm.family_id = ? AND fm.user_id = ?
            """,
        MEMBER_MAPPER,
        currentUserId,
        familyId,
        userId
    ).stream().findFirst();
}
```

- [ ] **Step 5: Add service and controller methods**

Add to `FamilyService.java` after `list`:

```java
public List<FamilyMemberView> listMembers(long userId, long familyId) {
    requireMember(userId, familyId);
    return familyRepository.findMembers(familyId, userId);
}
```

Add to `FamilyController.java` after the existing `get` method:

```java
@GetMapping("/{familyId}/members")
public ApiResponse<List<FamilyMemberView>> members(
    @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
    @PathVariable long familyId
) {
    return ApiResponse.success(familyService.listMembers(user.id(), familyId));
}
```

- [ ] **Step 6: Verify member listing passes**

```powershell
mvn --batch-mode -pl auth-family-service -am -Dtest=FamilyCollaborationIntegrationTest -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: all current collaboration tests pass.

- [ ] **Step 7: Commit**

```powershell
git add backend/auth-family-service/src/main/java/com/smartfridge/auth/family backend/auth-family-service/src/test/java/com/smartfridge/auth/FamilyCollaborationIntegrationTest.java
git commit -m "feat(family): list household members"
```

### Task 3: Role Updates and Member Removal

**Files:**
- Create: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/UpdateFamilyRoleRequest.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyRepository.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyService.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyController.java`
- Test: `backend/auth-family-service/src/test/java/com/smartfridge/auth/FamilyCollaborationIntegrationTest.java`

- [ ] **Step 1: Write failing role and removal tests**

Add these tests before `register`:

```java
@Test
void ownerCanChangeAndRemoveOrdinaryMembers() throws Exception {
    Session owner = register("role_owner", "拥有者");
    FamilyFixture family = createFamily(owner, "角色家庭");
    Session member = register("role_member", "普通成员");
    join(member, family.inviteCode());

    mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
            .patch("/api/v1/families/{familyId}/members/{userId}", family.id(), member.userId())
            .header("Authorization", bearer(owner))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"role\":\"EDITOR\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.role").value("EDITOR"));

    mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
            .patch("/api/v1/families/{familyId}/members/{userId}", family.id(), member.userId())
            .header("Authorization", bearer(owner))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"role\":\"VIEWER\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.role").value("VIEWER"));

    mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
            .delete("/api/v1/families/{familyId}/members/{userId}", family.id(), member.userId())
            .header("Authorization", bearer(owner)))
        .andExpect(status().isNoContent());
}

@Test
void protectsOwnerRoleAndRejectsOrdinaryMemberGovernance() throws Exception {
    Session owner = register("guard_owner", "拥有者");
    FamilyFixture family = createFamily(owner, "权限家庭");
    Session viewer = register("guard_viewer", "只读成员");
    Session other = register("guard_other", "另一成员");
    join(viewer, family.inviteCode());
    join(other, family.inviteCode());

    mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
            .patch("/api/v1/families/{familyId}/members/{userId}", family.id(), owner.userId())
            .header("Authorization", bearer(owner))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"role\":\"VIEWER\"}"))
        .andExpect(status().isConflict());

    mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
            .patch("/api/v1/families/{familyId}/members/{userId}", family.id(), other.userId())
            .header("Authorization", bearer(viewer))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"role\":\"EDITOR\"}"))
        .andExpect(status().isForbidden());

    mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
            .patch("/api/v1/families/{familyId}/members/{userId}", family.id(), other.userId())
            .header("Authorization", bearer(owner))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"role\":\"OWNER\"}"))
        .andExpect(status().isConflict());

    mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
            .delete("/api/v1/families/{familyId}/members/{userId}", family.id(), owner.userId())
            .header("Authorization", bearer(owner)))
        .andExpect(status().isConflict());
}
```

- [ ] **Step 2: Run the new tests and confirm RED**

```powershell
mvn --batch-mode -pl auth-family-service -am -Dtest=FamilyCollaborationIntegrationTest#ownerCanChangeAndRemoveOrdinaryMembers+protectsOwnerRoleAndRejectsOrdinaryMemberGovernance -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: both methods return `404` for the unimplemented routes.

- [ ] **Step 3: Add role request, locks, and update methods**

Create `UpdateFamilyRoleRequest.java`:

```java
package com.smartfridge.auth.family;

import jakarta.validation.constraints.NotBlank;

public record UpdateFamilyRoleRequest(
    @NotBlank(message = "成员角色不能为空")
    String role
) {
}
```

Add this repository method after `findByInviteCode`:

```java
public java.util.Optional<FamilyRecord> lockById(long familyId) {
    return jdbcTemplate.query(
        """
            SELECT id, name, invite_code, owner_user_id, created_at
            FROM family
            WHERE id = ?
            FOR UPDATE
            """,
        FAMILY_RECORD_MAPPER,
        familyId
    ).stream().findFirst();
}
```

Add mutation methods after `findRole`:

```java
public void updateMemberRole(long familyId, long userId, String role) {
    jdbcTemplate.update(
        """
            UPDATE family_member
            SET role = ?
            WHERE family_id = ? AND user_id = ?
            """,
        role,
        familyId,
        userId
    );
}

public void removeMember(long familyId, long userId) {
    jdbcTemplate.update(
        "DELETE FROM family_member WHERE family_id = ? AND user_id = ?",
        familyId,
        userId
    );
}
```

- [ ] **Step 4: Add service authorization and mutations**

Add these methods to `FamilyService.java` after `listMembers`:

```java
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
    if (family.ownerUserId() == actorId) {
        return;
    }
    String actorRole = familyRepository.findRole(family.id(), actorId);
    if (actorRole == null) {
        throw BusinessException.notFound("家庭不存在或无权访问");
    }
    throw BusinessException.forbidden("只有家庭拥有者可以管理成员");
}
```

- [ ] **Step 5: Expose PATCH and DELETE routes**

Add these imports to `FamilyController.java`:

```java
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PatchMapping;
```

Add these methods after `members`:

```java
@PatchMapping("/{familyId}/members/{userId}")
public ApiResponse<FamilyMemberView> updateMemberRole(
    @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
    @PathVariable long familyId,
    @PathVariable long userId,
    @Valid @RequestBody UpdateFamilyRoleRequest request
) {
    return ApiResponse.success(
        familyService.updateMemberRole(user.id(), familyId, userId, request.role())
    );
}

@DeleteMapping("/{familyId}/members/{userId}")
public ResponseEntity<Void> removeMember(
    @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
    @PathVariable long familyId,
    @PathVariable long userId
) {
    familyService.removeMember(user.id(), familyId, userId);
    return ResponseEntity.noContent().build();
}
```

- [ ] **Step 6: Verify role and removal behavior**

```powershell
mvn --batch-mode -pl auth-family-service -am -Dtest=FamilyCollaborationIntegrationTest -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: all collaboration tests pass.

- [ ] **Step 7: Commit**

```powershell
git add backend/auth-family-service/src/main/java/com/smartfridge/auth/family backend/auth-family-service/src/test/java/com/smartfridge/auth/FamilyCollaborationIntegrationTest.java
git commit -m "feat(family): govern household member roles"
```

### Task 4: Ownership Transfer

**Files:**
- Create: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/TransferFamilyOwnerRequest.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyRepository.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyService.java`
- Modify: `backend/auth-family-service/src/main/java/com/smartfridge/auth/family/FamilyController.java`
- Test: `backend/auth-family-service/src/test/java/com/smartfridge/auth/FamilyCollaborationIntegrationTest.java`

- [ ] **Step 1: Add failing ownership-transfer tests**

Add these test methods before `register`:

```java
@Test
void transfersOwnershipToEditorAndDemotesOriginalOwner() throws Exception {
    Session originalOwner = register("transfer_owner", "原拥有者");
    FamilyFixture family = createFamily(originalOwner, "转交家庭");
    Session target = register("transfer_target", "新拥有者");
    join(target, family.inviteCode());
    changeRole(originalOwner, family, target, "EDITOR");

    mockMvc.perform(post(
            "/api/v1/families/{familyId}/transfer-owner",
            family.id()
        )
            .header("Authorization", bearer(originalOwner))
            .contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(
                new TransferBody(target.userId())
            )))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.ownerUserId").value(target.userId()))
        .andExpect(jsonPath("$.data.currentUserRole").value("EDITOR"));

    mockMvc.perform(get("/api/v1/families")
            .header("Authorization", bearer(target)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data[0].currentUserRole").value("OWNER"));

    mockMvc.perform(post(
            "/api/v1/families/{familyId}/transfer-owner",
            family.id()
        )
            .header("Authorization", bearer(originalOwner))
            .contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(
                new TransferBody(target.userId())
            )))
        .andExpect(status().isForbidden());
}

@Test
void rejectsOwnershipTransferToNonEditor() throws Exception {
    Session owner = register("invalid_transfer_owner", "拥有者");
    FamilyFixture family = createFamily(owner, "无效转交家庭");
    Session viewer = register("invalid_transfer_viewer", "只读成员");
    join(viewer, family.inviteCode());

    mockMvc.perform(post(
            "/api/v1/families/{familyId}/transfer-owner",
            family.id()
        )
            .header("Authorization", bearer(owner))
            .contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(
                new TransferBody(viewer.userId())
            )))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.message").value("所有权只能转交给 EDITOR"));
}

@Test
void concurrentTransfersLeaveExactlyOneOwner() throws Exception {
    Session owner = register("concurrent_owner", "拥有者");
    FamilyFixture family = createFamily(owner, "并发家庭");
    Session first = register("concurrent_first", "候选一");
    Session second = register("concurrent_second", "候选二");
    join(first, family.inviteCode());
    join(second, family.inviteCode());
    changeRole(owner, family, first, "EDITOR");
    changeRole(owner, family, second, "EDITOR");

    var barrier = new java.util.concurrent.CountDownLatch(2);
    org.mockito.Mockito.doAnswer(invocation -> {
        Object result = invocation.callRealMethod();
        barrier.countDown();
        if (!barrier.await(5, java.util.concurrent.TimeUnit.SECONDS)) {
            throw new IllegalStateException("transfer race barrier timed out");
        }
        return result;
    }).when(familyRepository).findById(family.id());

    var pool = java.util.concurrent.Executors.newFixedThreadPool(2);
    try {
        java.util.concurrent.Callable<Integer> firstTransfer = () -> {
            return mockMvc.perform(post(
                    "/api/v1/families/{familyId}/transfer-owner",
                    family.id()
                )
                    .header("Authorization", bearer(owner))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(
                        new TransferBody(first.userId())
                    )))
                .andReturn().getResponse().getStatus();
        };
        java.util.concurrent.Callable<Integer> secondTransfer = () -> {
            return mockMvc.perform(post(
                    "/api/v1/families/{familyId}/transfer-owner",
                    family.id()
                )
                    .header("Authorization", bearer(owner))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(
                        new TransferBody(second.userId())
                    )))
                .andReturn().getResponse().getStatus();
        };

        var firstFuture = pool.submit(firstTransfer);
        var secondFuture = pool.submit(secondTransfer);

        int firstStatus = firstFuture.get(15, java.util.concurrent.TimeUnit.SECONDS);
        int secondStatus = secondFuture.get(15, java.util.concurrent.TimeUnit.SECONDS);
        assertThat(java.util.List.of(firstStatus, secondStatus))
            .containsExactlyInAnyOrder(200, 409);
    } finally {
        pool.shutdownNow();
    }

    Integer ownerCount = jdbcTemplate.queryForObject(
        "SELECT COUNT(*) FROM family_member WHERE family_id = ? AND role = 'OWNER'",
        Integer.class,
        family.id()
    );
    assertThat(ownerCount).isEqualTo(1);
}
```

Add these imports:

```java
import static org.assertj.core.api.Assertions.assertThat;
```

Add these helpers before `bearer`:

```java
private void changeRole(
    Session actor,
    FamilyFixture family,
    Session target,
    String role
) throws Exception {
    mockMvc.perform(
            org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch(
                "/api/v1/families/{familyId}/members/{userId}",
                family.id(),
                target.userId()
            )
                .header("Authorization", bearer(actor))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new RoleBody(role))))
        .andExpect(status().isOk());
}
```

Add these records:

```java
private record RoleBody(String role) {
}

private record TransferBody(long targetUserId) {
}
```

- [ ] **Step 2: Run the transfer tests and confirm RED**

```powershell
mvn --batch-mode -pl auth-family-service -am -Dtest=FamilyCollaborationIntegrationTest#transfersOwnershipToEditorAndDemotesOriginalOwner+rejectsOwnershipTransferToNonEditor+concurrentTransfersLeaveExactlyOneOwner -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: transfer requests return `404`.

- [ ] **Step 3: Add the transfer request and repository update**

Create `TransferFamilyOwnerRequest.java`:

```java
package com.smartfridge.auth.family;

import jakarta.validation.constraints.Positive;

public record TransferFamilyOwnerRequest(
    @Positive(message = "目标用户 ID 必须为正数")
    long targetUserId
) {
}
```

Add this repository method after `removeMember`:

```java
public void transferOwner(long familyId, long currentOwnerId, long newOwnerId) {
    jdbcTemplate.update(
        """
            UPDATE family
            SET owner_user_id = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ? AND owner_user_id = ?
            """,
        newOwnerId,
        familyId,
        currentOwnerId
    );
    jdbcTemplate.update(
        "UPDATE family_member SET role = 'OWNER' WHERE family_id = ? AND user_id = ?",
        familyId,
        newOwnerId
    );
    jdbcTemplate.update(
        "UPDATE family_member SET role = 'EDITOR' WHERE family_id = ? AND user_id = ?",
        familyId,
        currentOwnerId
    );
}
```

- [ ] **Step 4: Implement transactional transfer**

Add this method to `FamilyService.java` after `removeMember`:

```java
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
```

- [ ] **Step 5: Expose the transfer endpoint**

Add this method to `FamilyController.java` after `removeMember`:

```java
@PostMapping("/{familyId}/transfer-owner")
public ApiResponse<FamilyView> transferOwner(
    @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
    @PathVariable long familyId,
    @Valid @RequestBody TransferFamilyOwnerRequest request
) {
    return ApiResponse.success(
        familyService.transferOwner(user.id(), familyId, request.targetUserId())
    );
}
```

- [ ] **Step 6: Verify all backend collaboration tests**

```powershell
mvn --batch-mode -pl auth-family-service -am -Dtest=FamilyCollaborationIntegrationTest -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: all tests pass, including exactly one `200` in the concurrent transfer test.

- [ ] **Step 7: Commit**

```powershell
git add backend/auth-family-service/src/main/java/com/smartfridge/auth/family backend/auth-family-service/src/test/java/com/smartfridge/auth/FamilyCollaborationIntegrationTest.java
git commit -m "feat(family): transfer household ownership transactionally"
```

### Task 5: Flutter PATCH Support

**Files:**
- Modify: `apps/fridge-app/lib/core/network/api_client.dart`
- Create: `apps/fridge-app/test/api_client_test.dart`

- [ ] **Step 1: Write the failing PATCH test**

Create `api_client_test.dart`:

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';

void main() {
  test('sends PATCH JSON and unwraps the API response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
    final adapter = _RecordingAdapter();
    dio.httpClientAdapter = adapter;
    final client = ApiClient(dio);

    final response = await client.patch(
      '/api/v1/families/4/members/7',
      {'role': 'EDITOR'},
      accessToken: 'access',
    );

    expect(adapter.method, 'PATCH');
    expect(adapter.path, '/api/v1/families/4/members/7');
    expect(adapter.authorization, 'Bearer access');
    expect(adapter.body, {'role': 'EDITOR'});
    expect(response['code'], 'OK');
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  String? method;
  String? path;
  String? authorization;
  Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    method = options.method;
    path = options.uri.path;
    authorization = options.headers['Authorization'] as String?;
    body = options.data;
    return ResponseBody.fromString(
      '{"code":"OK","message":"success","data":{},"traceId":"test"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
```

- [ ] **Step 2: Run the PATCH test and confirm RED**

```powershell
flutter test test/api_client_test.dart --reporter compact
```

Expected: compile failure because `ApiClient.patch` does not exist.

- [ ] **Step 3: Add the PATCH method**

Insert after `post` in `ApiClient`:

```dart
Future<Map<String, dynamic>> patch(
  String path,
  Map<String, dynamic> body, {
  String? accessToken,
}) {
  return _request(
    () => _dio.patch<Map<String, dynamic>>(
      path,
      data: body,
      options: _options(accessToken),
    ),
  );
}
```

- [ ] **Step 4: Verify GREEN**

```powershell
flutter test test/api_client_test.dart --reporter compact
dart analyze lib/core/network/api_client.dart test/api_client_test.dart
```

Expected: one test passes and analysis reports `No issues found`.

- [ ] **Step 5: Commit**

```powershell
git add apps/fridge-app/lib/core/network/api_client.dart apps/fridge-app/test/api_client_test.dart
git commit -m "feat(app): support authenticated patch requests"
```

### Task 6: Flutter Family Collaboration Models and Repository

**Files:**
- Create: `apps/fridge-app/lib/features/family/domain/family_member.dart`
- Modify: `apps/fridge-app/lib/features/family/data/family_repository.dart`
- Create: `apps/fridge-app/test/family_collaboration_repository_test.dart`
- Modify: `apps/fridge-app/test/family_page_test.dart`

- [ ] **Step 1: Write failing repository collaboration tests**

Create `family_collaboration_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';

void main() {
  const session = AuthSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresIn: 900,
    user: UserProfile(
      id: 7,
      displayName: '小满',
      username: 'manman',
      role: 'USER',
    ),
  );

  test('joins a family with a normalized invite code', () async {
    final api = _CollaborationApiClient();
    final repository = ApiFamilyRepository(api);

    final family = await repository.join(session, ' test2026 ');

    expect(family.name, '新加入家庭');
    expect(family.role, 'VIEWER');
    expect(api.postPath, '/api/v1/families/join');
    expect(api.postBody, {'inviteCode': 'TEST2026'});
  });

  test('loads and manages family members', () async {
    final api = _CollaborationApiClient();
    final repository = ApiFamilyRepository(api);

    final members = await repository.listMembers(session, 4);
    final updated = await repository.updateMemberRole(
      session,
      4,
      9,
      'EDITOR',
    );
    await repository.removeMember(session, 4, 9);
    final family = await repository.transferOwner(session, 4, 9);

    expect(members.single.displayName, '家庭成员');
    expect(members.single.currentUser, isFalse);
    expect(updated.role, 'EDITOR');
    expect(api.getPath, '/api/v1/families/4/members');
    expect(api.patchPath, '/api/v1/families/4/members/9');
    expect(api.patchBody, {'role': 'EDITOR'});
    expect(api.deletePath, '/api/v1/families/4/members/9');
    expect(api.postPath, '/api/v1/families/4/transfer-owner');
    expect(api.postBody, {'targetUserId': 9});
    expect(family.role, 'EDITOR');
  });
}

class _CollaborationApiClient extends ApiClient {
  _CollaborationApiClient() : super(Dio());

  String? getPath;
  String? postPath;
  String? patchPath;
  String? deletePath;
  Map<String, dynamic>? postBody;
  Map<String, dynamic>? patchBody;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? accessToken,
  }) async {
    getPath = path;
    return {
      'code': 'OK',
      'data': [
        {
          'userId': 9,
          'username': 'family_member',
          'displayName': '家庭成员',
          'role': 'VIEWER',
          'joinedAt': '2026-10-29T00:00:00Z',
          'currentUser': false,
        },
      ],
      'traceId': 'test',
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    postPath = path;
    postBody = body;
    if (path.endsWith('/transfer-owner')) {
      return _familyResponse(role: 'EDITOR', ownerUserId: 9);
    }
    return _familyResponse(role: 'VIEWER', ownerUserId: 1);
  }

  @override
  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    patchPath = path;
    patchBody = body;
    return {
      'code': 'OK',
      'data': {
        'userId': 9,
        'username': 'family_member',
        'displayName': '家庭成员',
        'role': body['role'],
        'joinedAt': '2026-10-29T00:00:00Z',
        'currentUser': false,
      },
      'traceId': 'test',
    };
  }

  @override
  Future<void> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? accessToken,
  }) async {
    deletePath = path;
  }

  Map<String, dynamic> _familyResponse({
    required String role,
    required int ownerUserId,
  }) {
    return {
      'code': 'OK',
      'data': {
        'id': 4,
        'name': '新加入家庭',
        'inviteCode': 'TEST2026',
        'ownerUserId': ownerUserId,
        'currentUserRole': role,
        'createdAt': '2026-10-29T00:00:00Z',
      },
      'traceId': 'test',
    };
  }
}
```

- [ ] **Step 2: Run the tests and confirm RED**

```powershell
flutter test test/family_collaboration_repository_test.dart --reporter compact
```

Expected: compile failure because `FamilyDataSource.join`, `listMembers`, `updateMemberRole`, `removeMember`, and `transferOwner` do not exist.

- [ ] **Step 3: Add the member model**

Create `family_member.dart`:

```dart
class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    required this.currentUser,
  });

  final int userId;
  final String? username;
  final String displayName;
  final String role;
  final DateTime joinedAt;
  final bool currentUser;

  bool get isOwner => role == 'OWNER';
  bool get isEditor => role == 'EDITOR';

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String?,
      displayName: json['displayName'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      currentUser: json['currentUser'] as bool? ?? false,
    );
  }
}
```

- [ ] **Step 4: Extend the repository contract and implementation**

In `family_repository.dart`, add this import:

```dart
import 'package:smart_fridge_app/features/family/domain/family_member.dart';
```

Add these methods to `FamilyDataSource`:

```dart
Future<FamilyInfo> join(AuthSession session, String inviteCode);

Future<List<FamilyMember>> listMembers(
  AuthSession session,
  int familyId,
);

Future<FamilyMember> updateMemberRole(
  AuthSession session,
  int familyId,
  int userId,
  String role,
);

Future<void> removeMember(
  AuthSession session,
  int familyId,
  int userId,
);

Future<FamilyInfo> transferOwner(
  AuthSession session,
  int familyId,
  int targetUserId,
);
```

Add these implementations before `_map`:

```dart
@override
Future<FamilyInfo> join(AuthSession session, String inviteCode) async {
  final body = await _api.post(
    '/api/v1/families/join',
    {'inviteCode': inviteCode.trim().toUpperCase()},
    accessToken: session.accessToken,
  );
  return FamilyInfo.fromJson(_map(body['data']));
}

@override
Future<List<FamilyMember>> listMembers(
  AuthSession session,
  int familyId,
) async {
  final body = await _api.get(
    '/api/v1/families/$familyId/members',
    accessToken: session.accessToken,
  );
  final data = body['data'];
  if (data is! List) {
    throw const ApiFailure('家庭成员列表格式不正确');
  }
  return data
      .map((value) => FamilyMember.fromJson(_map(value)))
      .toList(growable: false);
}

@override
Future<FamilyMember> updateMemberRole(
  AuthSession session,
  int familyId,
  int userId,
  String role,
) async {
  final body = await _api.patch(
    '/api/v1/families/$familyId/members/$userId',
    {'role': role},
    accessToken: session.accessToken,
  );
  return FamilyMember.fromJson(_map(body['data']));
}

@override
Future<void> removeMember(
  AuthSession session,
  int familyId,
  int userId,
) {
  return _api.delete(
    '/api/v1/families/$familyId/members/$userId',
    accessToken: session.accessToken,
  );
}

@override
Future<FamilyInfo> transferOwner(
  AuthSession session,
  int familyId,
  int targetUserId,
) async {
  final body = await _api.post(
    '/api/v1/families/$familyId/transfer-owner',
    {'targetUserId': targetUserId},
    accessToken: session.accessToken,
  );
  return FamilyInfo.fromJson(_map(body['data']));
}
```

- [ ] **Step 5: Update existing test implementations of `FamilyDataSource`**

In `family_page_test.dart`, add this import:

```dart
import 'package:smart_fridge_app/features/family/domain/family_member.dart';
```

Add these methods to both `_FamilySource` and `_EmptyFamilySource`:

```dart
@override
Future<FamilyInfo> join(AuthSession session, String inviteCode) async {
  throw UnimplementedError();
}

@override
Future<List<FamilyMember>> listMembers(
  AuthSession session,
  int familyId,
) async {
  return const [];
}

@override
Future<FamilyMember> updateMemberRole(
  AuthSession session,
  int familyId,
  int userId,
  String role,
) {
  throw UnimplementedError();
}

@override
Future<void> removeMember(
  AuthSession session,
  int familyId,
  int userId,
) async {}

@override
Future<FamilyInfo> transferOwner(
  AuthSession session,
  int familyId,
  int targetUserId,
) {
  throw UnimplementedError();
}
```

- [ ] **Step 6: Verify repository tests and existing family tests**

```powershell
flutter test test/family_collaboration_repository_test.dart test/family_repository_test.dart test/family_page_test.dart --reporter compact
dart analyze lib/features/family test/family_collaboration_repository_test.dart test/family_repository_test.dart test/family_page_test.dart
```

Expected: all tests pass and analysis reports `No issues found`.

- [ ] **Step 7: Commit**

```powershell
git add apps/fridge-app/lib/features/family apps/fridge-app/test/family_collaboration_repository_test.dart apps/fridge-app/test/family_page_test.dart
git commit -m "feat(app): add family collaboration repository"
```

### Task 7: Persistent Family Selection

**Files:**
- Create: `apps/fridge-app/lib/features/family/domain/family_workspace_state.dart`
- Create: `apps/fridge-app/lib/features/family/data/family_selection_store.dart`
- Modify: `apps/fridge-app/lib/features/family/application/family_controller.dart`
- Modify: `apps/fridge-app/lib/features/profile/presentation/profile_page.dart`
- Create: `apps/fridge-app/test/family_workspace_controller_test.dart`
- Modify: `apps/fridge-app/test/family_page_test.dart`

- [ ] **Step 1: Write failing family-selection tests**

Create `family_workspace_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';

void main() {
  test('restores a valid persisted family selection', () async {
    final source = _WorkspaceFamilySource();
    final selection = _MemorySelectionStore(selectedFamilyId: 5);
    final container = _container(source, selection);
    addTearDown(container.dispose);

    final workspace = await container.read(familyControllerProvider.future);

    expect(workspace.families.length, 2);
    expect(workspace.selectedFamily?.id, 5);
    expect(workspace.selectedFamily?.name, '父母的厨房');
  });

  test('falls back to first family when persisted id is invalid', () async {
    final source = _WorkspaceFamilySource();
    final selection = _MemorySelectionStore(selectedFamilyId: 999);
    final container = _container(source, selection);
    addTearDown(container.dispose);

    final workspace = await container.read(familyControllerProvider.future);

    expect(workspace.selectedFamily?.id, 4);
    expect(selection.selectedFamilyId, 4);
  });

  test('switches and persists the selected family', () async {
    final source = _WorkspaceFamilySource();
    final selection = _MemorySelectionStore(selectedFamilyId: 4);
    final container = _container(source, selection);
    addTearDown(container.dispose);

    await container.read(familyControllerProvider.future);
    await container
        .read(familyControllerProvider.notifier)
        .selectFamily(5);

    expect(
      container.read(familyControllerProvider).requireValue.selectedFamily?.id,
      5,
    );
    expect(selection.selectedFamilyId, 5);
  });

  test('joining a family selects and persists it', () async {
    final source = _WorkspaceFamilySource();
    final selection = _MemorySelectionStore(selectedFamilyId: 4);
    final container = _container(source, selection);
    addTearDown(container.dispose);

    await container.read(familyControllerProvider.future);
    final joined = await container
        .read(familyControllerProvider.notifier)
        .join('join2026');

    expect(joined.role, 'VIEWER');
    expect(source.joinedCode, 'JOIN2026');
    expect(
      container.read(familyControllerProvider).requireValue.selectedFamily?.id,
      6,
    );
    expect(selection.selectedFamilyId, 6);
  });
}

ProviderContainer _container(
  _WorkspaceFamilySource source,
  _MemorySelectionStore selection,
) {
  return ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(_WorkspaceSessionStore()),
      familyDataSourceProvider.overrideWithValue(source),
      familySelectionStoreProvider.overrideWithValue(selection),
    ],
  );
}

class _WorkspaceFamilySource implements FamilyDataSource {
  String? joinedCode;
  final List<FamilyInfo> families = [
    const FamilyInfo(
      id: 4,
      name: 'S2 接口测试家庭',
      inviteCode: 'TEST2026',
      ownerUserId: 7,
      role: 'OWNER',
    ),
    const FamilyInfo(
      id: 5,
      name: '父母的厨房',
      inviteCode: 'PARENT26',
      ownerUserId: 9,
      role: 'EDITOR',
    ),
  ];

  @override
  Future<List<FamilyInfo>> list(AuthSession session) async => families;

  @override
  Future<FamilyInfo> create(AuthSession session, String name) async {
    final family = FamilyInfo(
      id: 7,
      name: name,
      inviteCode: 'CREATED7',
      ownerUserId: session.user.id,
      role: 'OWNER',
    );
    families.add(family);
    return family;
  }

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) async {
    joinedCode = inviteCode.toUpperCase();
    const family = FamilyInfo(
      id: 6,
      name: '朋友的家',
      inviteCode: 'JOIN2026',
      ownerUserId: 11,
      role: 'VIEWER',
    );
    families.add(family);
    return family;
  }

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async => const [];

  @override
  Future<FamilyMember> updateMemberRole(
    AuthSession session,
    int familyId,
    int userId,
    String role,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeMember(
    AuthSession session,
    int familyId,
    int userId,
  ) async {}

  @override
  Future<FamilyInfo> transferOwner(
    AuthSession session,
    int familyId,
    int targetUserId,
  ) {
    throw UnimplementedError();
  }
}

class _MemorySelectionStore implements FamilySelectionStore {
  _MemorySelectionStore({this.selectedFamilyId});

  int? selectedFamilyId;

  @override
  Future<int?> read(int userId) async => selectedFamilyId;

  @override
  Future<void> write(int userId, int familyId) async {
    selectedFamilyId = familyId;
  }

  @override
  Future<void> clear(int userId) async {
    selectedFamilyId = null;
  }
}

class _WorkspaceSessionStore implements SessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async {
    return AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
      issuedAt: DateTime.now().toUtc(),
      user: const UserProfile(
        id: 7,
        displayName: '小满',
        username: 'manman',
        role: 'USER',
      ),
    );
  }

  @override
  Future<void> write(AuthSession session) async {}
}
```

- [ ] **Step 2: Run the selection tests and confirm RED**

```powershell
flutter test test/family_workspace_controller_test.dart --reporter compact
```

Expected: compile failure because `FamilyWorkspaceState` and `FamilySelectionStore` do not exist.

- [ ] **Step 3: Add workspace state and selection persistence**

Create `family_workspace_state.dart`:

```dart
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
    return FamilyWorkspaceState(
      families: families,
      selectedFamilyId: familyId,
    );
  }
}
```

Create `family_selection_store.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final familySelectionStoreProvider = Provider<FamilySelectionStore>((ref) {
  return SharedPreferencesFamilySelectionStore();
});

abstract interface class FamilySelectionStore {
  Future<int?> read(int userId);

  Future<void> write(int userId, int familyId);

  Future<void> clear(int userId);
}

class SharedPreferencesFamilySelectionStore implements FamilySelectionStore {
  String _key(int userId) => 'smart_fridge.selected_family.$userId';

  @override
  Future<int?> read(int userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_key(userId));
  }

  @override
  Future<void> write(int userId, int familyId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_key(userId), familyId);
  }

  @override
  Future<void> clear(int userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(userId));
  }
}
```

- [ ] **Step 4: Replace the family controller state**

Replace `family_controller.dart` with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_workspace_state.dart';

final familyControllerProvider =
    AsyncNotifierProvider<FamilyController, FamilyWorkspaceState>(
      FamilyController.new,
    );

class FamilyController extends AsyncNotifier<FamilyWorkspaceState> {
  FamilyDataSource get _source => ref.read(familyDataSourceProvider);
  FamilySelectionStore get _selectionStore =>
      ref.read(familySelectionStoreProvider);

  @override
  Future<FamilyWorkspaceState> build() async {
    final session = await ref.watch(authControllerProvider.future);
    if (session == null) {
      throw StateError('当前没有登录会话');
    }
    final freshSession = await _freshSession(session);
    final families = await _source.list(freshSession);
    if (families.isEmpty) {
      await _selectionStore.clear(freshSession.user.id);
      return const FamilyWorkspaceState(
        families: [],
        selectedFamilyId: null,
      );
    }

    final storedId = await _selectionStore.read(freshSession.user.id);
    final selectedId = families.any((family) => family.id == storedId)
        ? storedId!
        : families.first.id;
    await _selectionStore.write(freshSession.user.id, selectedId);
    return FamilyWorkspaceState(
      families: families,
      selectedFamilyId: selectedId,
    );
  }

  Future<FamilyInfo> create(String name) async {
    final session = await _session();
    final family = await _source.create(session, name);
    await _replaceFamiliesAndSelect(session, family);
    return family;
  }

  Future<FamilyInfo> join(String inviteCode) async {
    final session = await _session();
    final family = await _source.join(session, inviteCode);
    await _replaceFamiliesAndSelect(session, family);
    return family;
  }

  Future<void> selectFamily(int familyId) async {
    final session = await _session();
    final current = state.requireValue;
    if (!current.families.any((family) => family.id == familyId)) {
      throw StateError('家庭不存在或无权访问');
    }
    await _selectionStore.write(session.user.id, familyId);
    state = AsyncData(current.withSelectedFamily(familyId));
  }

  Future<void> refresh() async {
    final session = await _session();
    final previousId = state.value?.selectedFamilyId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final families = await _source.list(session);
      if (families.isEmpty) {
        await _selectionStore.clear(session.user.id);
        return const FamilyWorkspaceState(
          families: [],
          selectedFamilyId: null,
        );
      }
      final selectedId =
          families.any((family) => family.id == previousId)
          ? previousId!
          : families.first.id;
      await _selectionStore.write(session.user.id, selectedId);
      return FamilyWorkspaceState(
        families: families,
        selectedFamilyId: selectedId,
      );
    });
  }

  Future<void> _replaceFamiliesAndSelect(
    AuthSession session,
    FamilyInfo selected,
  ) async {
    final families = await _source.list(session);
    await _selectionStore.write(session.user.id, selected.id);
    state = AsyncData(
      FamilyWorkspaceState(
        families: families,
        selectedFamilyId: selected.id,
      ),
    );
  }

  FamilyInfo? get selectedFamily {
    return state.value?.selectedFamily;
  }

  Future<AuthSession> _session() async {
    final session = await ref.read(authControllerProvider.future);
    if (session == null) {
      throw StateError('当前没有登录会话');
    }
    return _freshSession(session);
  }

  Future<AuthSession> _freshSession(AuthSession session) async {
    if (!session.isAccessTokenExpiring) {
      return session;
    }
    return ref
        .read(authControllerProvider.notifier)
        .refreshAccessToken();
  }
}
```

- [ ] **Step 5: Adapt the existing profile page to the workspace state**

In `profile_page.dart`, replace:

```dart
final family = familyState.value?.firstOrNull;
```

with:

```dart
final family = familyState.value?.selectedFamily;
```

Pass families to the existing section by replacing the `_FamilySection` call with:

```dart
_FamilySection(
  state: familyState.whenData((workspace) => workspace.families),
  onCreate: () => _createFamily(context, ref),
  onRetry: () =>
      ref.read(familyControllerProvider.notifier).refresh(),
),
```

This keeps the current profile layout compiling until Task 9 replaces it with the collaboration UI.

- [ ] **Step 6: Override selection persistence in widget tests**

In `family_page_test.dart`, add this import:

```dart
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
```

Add this override to both `ProviderScope` override lists:

```dart
familySelectionStoreProvider.overrideWithValue(
  _MemoryFamilySelectionStore(),
),
```

Add this class at the end:

```dart
class _MemoryFamilySelectionStore implements FamilySelectionStore {
  int? selectedFamilyId;

  @override
  Future<int?> read(int userId) async => selectedFamilyId;

  @override
  Future<void> write(int userId, int familyId) async {
    selectedFamilyId = familyId;
  }

  @override
  Future<void> clear(int userId) async {
    selectedFamilyId = null;
  }
}
```

Change the assertion:

```dart
container.read(familyControllerProvider).value?.single.name
```

to:

```dart
container.read(familyControllerProvider).value?.selectedFamily?.name
```

- [ ] **Step 7: Verify selection behavior**

```powershell
flutter test test/family_workspace_controller_test.dart test/family_page_test.dart test/family_collaboration_repository_test.dart --reporter compact
dart analyze lib/features/family lib/features/profile test/family_workspace_controller_test.dart test/family_page_test.dart
```

Expected: all tests pass and analysis reports `No issues found`.

- [ ] **Step 8: Commit**

```powershell
git add apps/fridge-app/lib/features/family apps/fridge-app/lib/features/profile/presentation/profile_page.dart apps/fridge-app/test/family_workspace_controller_test.dart apps/fridge-app/test/family_page_test.dart
git commit -m "feat(app): persist and restore selected family"
```

### Task 8: Family Members Controller

**Files:**
- Create: `apps/fridge-app/lib/features/family/application/family_members_controller.dart`
- Create: `apps/fridge-app/test/family_members_controller_test.dart`

- [ ] **Step 1: Write failing controller tests**

Create `family_members_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_members_controller.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';

void main() {
  test('loads members for the selected family', () async {
    final source = _MemberFamilySource();
    final container = _memberContainer(source);
    addTearDown(container.dispose);

    final members = await container.read(familyMembersProvider.future);

    expect(members.length, 2);
    expect(members.first.role, 'OWNER');
    expect(source.memberFamilyId, 4);
  });

  test('owner updates and removes ordinary members', () async {
    final source = _MemberFamilySource();
    final container = _memberContainer(source);
    addTearDown(container.dispose);

    await container.read(familyMembersProvider.future);
    await container
        .read(familyMembersProvider.notifier)
        .updateRole(9, 'EDITOR');
    expect(source.updatedRole, 'EDITOR');
    expect(
      container.read(familyMembersProvider).requireValue.last.role,
      'EDITOR',
    );

    await container.read(familyMembersProvider.notifier).remove(9);
    expect(source.removedUserId, 9);
    expect(container.read(familyMembersProvider).requireValue.length, 1);
  });

  test('ownership transfer refreshes family and member state', () async {
    final source = _MemberFamilySource();
    final container = _memberContainer(source);
    addTearDown(container.dispose);

    await container.read(familyMembersProvider.future);
    await container.read(familyMembersProvider.notifier).transfer(9);

    expect(source.transferredUserId, 9);
    expect(source.ownerUserId, 9);
    expect(source.currentRole, 'EDITOR');
    expect(
      container.read(familyMembersProvider).requireValue.first.role,
      'OWNER',
    );
  });

  test('keeps member state when a governance request is rejected', () async {
    final source = _MemberFamilySource()..rejectMutation = true;
    final container = _memberContainer(source);
    addTearDown(container.dispose);

    final initial = await container.read(familyMembersProvider.future);
    await expectLater(
      container
          .read(familyMembersProvider.notifier)
          .updateRole(9, 'EDITOR'),
      throwsA(
        isA<ApiFailure>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );

    expect(
      container.read(familyMembersProvider).requireValue
          .map((member) => member.role),
      initial.map((member) => member.role),
    );
  });
}

ProviderContainer _memberContainer(_MemberFamilySource source) {
  return ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(_MemberSessionStore()),
      familyDataSourceProvider.overrideWithValue(source),
      familySelectionStoreProvider.overrideWithValue(
        _MemberSelectionStore(),
      ),
    ],
  );
}

class _MemberFamilySource implements FamilyDataSource {
  int ownerUserId = 7;
  String currentRole = 'OWNER';
  int? memberFamilyId;
  String? updatedRole;
  int? removedUserId;
  int? transferredUserId;
  bool rejectMutation = false;
  final List<FamilyMember> members = [
    FamilyMember(
      userId: 7,
      username: 'manman',
      displayName: '小满',
      role: 'OWNER',
      joinedAt: DateTime.utc(2026, 10, 29),
      currentUser: true,
    ),
    FamilyMember(
      userId: 9,
      username: 'family_member',
      displayName: '家庭成员',
      role: 'VIEWER',
      joinedAt: DateTime.utc(2026, 10, 29),
      currentUser: false,
    ),
  ];

  @override
  Future<List<FamilyInfo>> list(AuthSession session) async {
    return [
      FamilyInfo(
        id: 4,
        name: '小满的家',
        inviteCode: 'TEST2026',
        ownerUserId: ownerUserId,
        role: currentRole,
      ),
    ];
  }

  @override
  Future<FamilyInfo> create(AuthSession session, String name) {
    throw UnimplementedError();
  }

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) {
    throw UnimplementedError();
  }

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async {
    memberFamilyId = familyId;
    return List.unmodifiable(members);
  }

  @override
  Future<FamilyMember> updateMemberRole(
    AuthSession session,
    int familyId,
    int userId,
    String role,
  ) async {
    if (rejectMutation) {
      throw const ApiFailure(
        '只有家庭拥有者可以管理成员',
        statusCode: 403,
        code: 'FORBIDDEN',
      );
    }
    updatedRole = role;
    final index = members.indexWhere((member) => member.userId == userId);
    final current = members[index];
    final updated = FamilyMember(
      userId: current.userId,
      username: current.username,
      displayName: current.displayName,
      role: role,
      joinedAt: current.joinedAt,
      currentUser: current.currentUser,
    );
    members[index] = updated;
    return updated;
  }

  @override
  Future<void> removeMember(
    AuthSession session,
    int familyId,
    int userId,
  ) async {
    removedUserId = userId;
    members.removeWhere((member) => member.userId == userId);
  }

  @override
  Future<FamilyInfo> transferOwner(
    AuthSession session,
    int familyId,
    int targetUserId,
  ) async {
    transferredUserId = targetUserId;
    ownerUserId = targetUserId;
    currentRole = 'EDITOR';
    final targetIndex = members.indexWhere(
      (member) => member.userId == targetUserId,
    );
    final oldOwnerIndex = members.indexWhere(
      (member) => member.role == 'OWNER',
    );
    members[oldOwnerIndex] = FamilyMember(
      userId: members[oldOwnerIndex].userId,
      username: members[oldOwnerIndex].username,
      displayName: members[oldOwnerIndex].displayName,
      role: 'EDITOR',
      joinedAt: members[oldOwnerIndex].joinedAt,
      currentUser: members[oldOwnerIndex].currentUser,
    );
    members[targetIndex] = FamilyMember(
      userId: members[targetIndex].userId,
      username: members[targetIndex].username,
      displayName: members[targetIndex].displayName,
      role: 'OWNER',
      joinedAt: members[targetIndex].joinedAt,
      currentUser: members[targetIndex].currentUser,
    );
    return FamilyInfo(
      id: 4,
      name: '小满的家',
      inviteCode: 'TEST2026',
      ownerUserId: targetUserId,
      role: 'EDITOR',
    );
  }
}

class _MemberSelectionStore implements FamilySelectionStore {
  @override
  Future<int?> read(int userId) async => 4;

  @override
  Future<void> write(int userId, int familyId) async {}

  @override
  Future<void> clear(int userId) async {}
}

class _MemberSessionStore implements SessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async {
    return AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
      issuedAt: DateTime.now().toUtc(),
      user: const UserProfile(
        id: 7,
        displayName: '小满',
        username: 'manman',
        role: 'USER',
      ),
    );
  }

  @override
  Future<void> write(AuthSession session) async {}
}
```

- [ ] **Step 2: Run the tests and confirm RED**

```powershell
flutter test test/family_members_controller_test.dart --reporter compact
```

Expected: compile failure because `familyMembersProvider` does not exist.

- [ ] **Step 3: Implement the controller**

Create `family_members_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';

final familyMembersProvider =
    AsyncNotifierProvider<FamilyMembersController, List<FamilyMember>>(
      FamilyMembersController.new,
    );

class FamilyMembersController extends AsyncNotifier<List<FamilyMember>> {
  FamilyDataSource get _source => ref.read(familyDataSourceProvider);

  @override
  Future<List<FamilyMember>> build() async {
    final workspace = await ref.watch(familyControllerProvider.future);
    final family = workspace.selectedFamily;
    if (family == null) {
      return const [];
    }
    final session = await _session();
    return _source.listMembers(session, family.id);
  }

  Future<void> updateRole(int userId, String role) async {
    final session = await _session();
    final family = await _selectedFamily();
    await _mutate(
      () async {
        await _source.updateMemberRole(
        session,
        family.id,
        userId,
        role,
        );
      },
    );
  }

  Future<void> remove(int userId) async {
    final session = await _session();
    final family = await _selectedFamily();
    await _mutate(() => _source.removeMember(session, family.id, userId));
  }

  Future<void> transfer(int targetUserId) async {
    final session = await _session();
    final family = await _selectedFamily();
    final previous = state;
    try {
      await _source.transferOwner(session, family.id, targetUserId);
      await ref.read(familyControllerProvider.notifier).refresh();
      state = AsyncData(await _source.listMembers(session, family.id));
    } on Object catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    final session = await _session();
    final family = await _selectedFamily();
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _source.listMembers(session, family.id),
    );
  }

  Future<void> _mutate(Future<void> Function() action) async {
    final session = await _session();
    final family = await _selectedFamily();
    final previous = state;
    try {
      await action();
      state = AsyncData(await _source.listMembers(session, family.id));
    } on Object catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<({int id})> _selectedFamily() async {
    final workspace = await ref.read(familyControllerProvider.future);
    final family = workspace.selectedFamily;
    if (family == null) {
      throw StateError('当前没有可用的家庭');
    }
    return (id: family.id);
  }

  Future<AuthSession> _session() async {
    var session = await ref.read(authControllerProvider.future);
    if (session == null) {
      throw StateError('当前没有登录会话');
    }
    if (session.isAccessTokenExpiring) {
      session = await ref
          .read(authControllerProvider.notifier)
          .refreshAccessToken();
    }
    return session;
  }
}
```

- [ ] **Step 4: Verify controller tests**

```powershell
flutter test test/family_members_controller_test.dart test/family_workspace_controller_test.dart --reporter compact
dart analyze lib/features/family test/family_members_controller_test.dart
```

Expected: all tests pass and analysis reports `No issues found`.

- [ ] **Step 5: Commit**

```powershell
git add apps/fridge-app/lib/features/family/application/family_members_controller.dart apps/fridge-app/test/family_members_controller_test.dart
git commit -m "feat(app): coordinate selected-family member management"
```

### Task 9: Family Selection, Join, and Create UI

**Files:**
- Create: `apps/fridge-app/lib/features/family/presentation/family_workspace_section.dart`
- Modify: `apps/fridge-app/lib/features/profile/presentation/profile_page.dart`
- Modify: `apps/fridge-app/test/family_page_test.dart`

- [ ] **Step 1: Write the failing join-and-select widget test**

Add this test to `family_page_test.dart`:

```dart
testWidgets('joins a family and makes it the selected workspace', (
  tester,
) async {
  final source = _JoinFamilySource();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(_FamilySessionStore()),
        familyDataSourceProvider.overrideWithValue(source),
        familySelectionStoreProvider.overrideWithValue(
          _MemoryFamilySelectionStore(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ProfilePage()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('join-family-button')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('invite-code-input')),
    'friend26',
  );
  await tester.tap(find.byKey(const ValueKey('join-family-submit')));
  await tester.pumpAndSettle();

  expect(source.joinedCode, 'FRIEND26');
  expect(find.text('朋友的家'), findsOneWidget);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ProfilePage)),
  );
  expect(
    container.read(familyControllerProvider).value?.selectedFamily?.id,
    6,
  );
});
```

Add this fake after `_EmptyFamilySource`:

```dart
class _JoinFamilySource extends _FamilySource {
  String? joinedCode;

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) async {
    joinedCode = inviteCode;
    return const FamilyInfo(
      id: 6,
      name: '朋友的家',
      inviteCode: 'FRIEND26',
      ownerUserId: 11,
      role: 'VIEWER',
    );
  }

  @override
  Future<List<FamilyInfo>> list(AuthSession session) async {
    return [
      ...await super.list(session),
      const FamilyInfo(
        id: 6,
        name: '朋友的家',
        inviteCode: 'FRIEND26',
        ownerUserId: 11,
        role: 'VIEWER',
      ),
    ];
  }
}
```

- [ ] **Step 2: Run the widget test and confirm RED**

```powershell
flutter test test/family_page_test.dart --plain-name "joins a family and makes it the selected workspace" --reporter compact
```

Expected: `join-family-button` is not found.

- [ ] **Step 3: Add the family workspace section**

Create `family_workspace_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_workspace_state.dart';

class FamilyWorkspaceSection extends ConsumerWidget {
  const FamilyWorkspaceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(familyControllerProvider);
    return state.when(
      loading: () => const _StateCard(
        icon: Icons.sync_rounded,
        title: '正在同步家庭',
        subtitle: '从 Gateway 读取家庭权限和邀请码',
      ),
      error: (error, stackTrace) => _StateCard(
        icon: Icons.cloud_off_rounded,
        title: '家庭信息加载失败',
        subtitle: error.toString(),
        action: TextButton(
          onPressed: () =>
              ref.read(familyControllerProvider.notifier).refresh(),
          child: const Text('重试'),
        ),
      ),
      data: (workspace) => _FamilyList(
        workspace: workspace,
        onCreate: () => _createFamily(context, ref),
        onJoin: () => _joinFamily(context, ref),
        onSelect: (familyId) =>
            _selectFamily(context, ref, familyId),
      ),
    );
  }

  Future<void> _selectFamily(
    BuildContext context,
    WidgetRef ref,
    int familyId,
  ) async {
    try {
      await ref
          .read(familyControllerProvider.notifier)
          .selectFamily(familyId);
    } on Object catch (error) {
      _showError(context, error);
    }
  }

  Future<void> _joinFamily(BuildContext context, WidgetRef ref) async {
    var inviteCode = '';
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text('加入家庭'),
        content: TextField(
          key: const ValueKey('invite-code-input'),
          autofocus: true,
          maxLength: 8,
          textCapitalization: TextCapitalization.characters,
          onChanged: (text) => inviteCode = text,
          decoration: const InputDecoration(labelText: '8 位邀请码'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('join-family-submit'),
            onPressed: () {
              final code = inviteCode.trim();
              if (code.length == 8) {
                Navigator.of(dialogContext).pop(code);
              }
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
    if (value == null || !context.mounted) {
      return;
    }
    try {
      await ref.read(familyControllerProvider.notifier).join(value);
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _createFamily(BuildContext context, WidgetRef ref) async {
    var familyName = '';
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text('创建新家庭'),
        content: TextField(
          key: const ValueKey('family-name-input'),
          autofocus: true,
          onChanged: (text) => familyName = text,
          decoration: const InputDecoration(labelText: '家庭名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('create-family-submit'),
            onPressed: () {
              final name = familyName.trim();
              if (name.isNotEmpty) {
                Navigator.of(dialogContext).pop(name);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (value == null || !context.mounted) {
      return;
    }
    try {
      await ref.read(familyControllerProvider.notifier).create(value);
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

class _FamilyList extends StatelessWidget {
  const _FamilyList({
    required this.workspace,
    required this.onCreate,
    required this.onJoin,
    required this.onSelect,
  });

  final FamilyWorkspaceState workspace;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '我的家庭',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              key: const ValueKey('join-family-button'),
              onPressed: onJoin,
              icon: const Icon(Icons.login_rounded, size: 17),
              label: const Text('加入家庭'),
            ),
            TextButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('创建家庭'),
            ),
          ],
        ),
        if (workspace.families.isEmpty)
          _StateCard(
            icon: Icons.family_restroom_rounded,
            title: '还没有家庭',
            subtitle: '创建家庭或使用邀请码加入一个家庭',
            action: FilledButton(
              onPressed: onCreate,
              child: const Text('创建第一个家庭'),
            ),
          )
        else
          for (final family in workspace.families)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FamilyCard(
                family: family,
                selected: family.id == workspace.selectedFamilyId,
                onTap: () => onSelect(family.id),
              ),
            ),
      ],
    );
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    required this.family,
    required this.selected,
    required this.onTap,
  });

  final FamilyInfo family;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE1EBDD) : AppColors.paper,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: ValueKey('family-card-${family.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: selected
                    ? AppColors.sage
                    : AppColors.terracotta,
                foregroundColor: Colors.white,
                child: Text(family.name.characters.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '邀请码 ${family.inviteCode} · '
                      '${_roleLabel(family.role)}',
                      style: TextStyle(
                        color: AppColors.cocoa.withValues(alpha: 0.58),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: selected ? AppColors.sage : AppColors.sand,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    return switch (role) {
      'OWNER' => '拥有者',
      'EDITOR' => '编辑者',
      _ => '只读者',
    };
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(subtitle),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Replace the inline family section in ProfilePage**

Add this import to `profile_page.dart`:

```dart
import 'package:smart_fridge_app/features/family/presentation/family_workspace_section.dart';
```

Replace the `_FamilySection(...)` call with:

```dart
const FamilyWorkspaceSection(),
```

Delete the private classes `_FamilySection`, `_FamilyCard`, `_FamilyStateCard`, `_MemberAvatar`, and the `_createFamily` method from `profile_page.dart`; their behavior now lives in `family_workspace_section.dart`.

- [ ] **Step 5: Verify family UI tests**

```powershell
flutter test test/family_page_test.dart test/family_workspace_controller_test.dart --reporter compact
dart analyze lib/features/family/presentation lib/features/profile test/family_page_test.dart
```

Expected: join, create, selected-family, and existing profile tests pass.

- [ ] **Step 6: Commit**

```powershell
git add apps/fridge-app/lib/features/family/presentation/family_workspace_section.dart apps/fridge-app/lib/features/profile/presentation/profile_page.dart apps/fridge-app/test/family_page_test.dart
git commit -m "feat(app): join switch and create households"
```

### Task 10: Member Management Sheet

**Files:**
- Create: `apps/fridge-app/lib/features/family/presentation/family_member_management_sheet.dart`
- Modify: `apps/fridge-app/lib/features/family/presentation/family_workspace_section.dart`
- Modify: `apps/fridge-app/test/family_page_test.dart`

- [ ] **Step 1: Write the failing member-management widget test**

Add this test to `family_page_test.dart`:

```dart
testWidgets('owner opens member management with role actions', (tester) async {
  final source = _MemberManagementFamilySource();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(_FamilySessionStore()),
        familyDataSourceProvider.overrideWithValue(source),
        familySelectionStoreProvider.overrideWithValue(
          _MemoryFamilySelectionStore(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ProfilePage()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('manage-members-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('member-actions-9')));
  await tester.pumpAndSettle();

  expect(find.text('成员管理'), findsOneWidget);
  expect(find.text('家庭成员'), findsOneWidget);
  expect(find.text('设为编辑者'), findsOneWidget);
  expect(find.text('设为只读者'), findsOneWidget);
  expect(find.text('转交所有权'), findsOneWidget);
  expect(find.text('移除成员'), findsOneWidget);
});
```

Add this fake after `_JoinFamilySource`:

```dart
class _MemberManagementFamilySource extends _FamilySource {
  final List<FamilyMember> members = [
    FamilyMember(
      userId: 7,
      username: 'manman',
      displayName: '小满',
      role: 'OWNER',
      joinedAt: DateTime.utc(2026, 10, 29),
      currentUser: true,
    ),
    FamilyMember(
      userId: 9,
      username: 'family_member',
      displayName: '家庭成员',
      role: 'EDITOR',
      joinedAt: DateTime.utc(2026, 10, 29),
      currentUser: false,
    ),
  ];

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async {
    return List.unmodifiable(members);
  }
}
```

- [ ] **Step 2: Run the widget test and confirm RED**

```powershell
flutter test test/family_page_test.dart --plain-name "owner opens member management with role actions" --reporter compact
```

Expected: `manage-members-button` is not found.

- [ ] **Step 3: Implement the member-management sheet**

Create `family_member_management_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/theme/app_theme.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/application/family_members_controller.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';

Future<void> showFamilyMemberManagementSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    builder: (context) => const FamilyMemberManagementSheet(),
  );
}

class FamilyMemberManagementSheet extends ConsumerWidget {
  const FamilyMemberManagementSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(familyMembersProvider);
    final workspace = ref.watch(familyControllerProvider).value;
    final canManage = workspace?.selectedFamily?.role == 'OWNER';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return members.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error.toString()),
            ),
          ),
          data: (items) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '成员管理',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${items.length} 位成员',
                    style: const TextStyle(color: AppColors.sage),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Text('当前家庭还没有成员')
              else
                for (final member in items)
                  _MemberTile(
                    member: member,
                    canManage: canManage,
                    onRoleChanged: (role) =>
                        _changeRole(context, ref, member.userId, role),
                    onRemove: () =>
                        _confirmRemove(context, ref, member),
                    onTransfer: () =>
                        _confirmTransfer(context, ref, member),
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    int userId,
    String role,
  ) async {
    try {
      await ref
          .read(familyMembersProvider.notifier)
          .updateRole(userId, role);
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    FamilyMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定将 ${member.displayName} 移出家庭吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(familyMembersProvider.notifier).remove(member.userId);
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _confirmTransfer(
    BuildContext context,
    WidgetRef ref,
    FamilyMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('转交家庭所有权'),
        content: Text(
          '转交后 ${member.displayName} 成为拥有者，你将变为编辑者。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认转交'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref
          .read(familyMembersProvider.notifier)
          .transfer(member.userId);
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canManage,
    required this.onRoleChanged,
    required this.onRemove,
    required this.onTransfer,
  });

  final FamilyMember member;
  final bool canManage;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onRemove;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final ordinaryMember = !member.isOwner;
    return Card(
      key: ValueKey('member-${member.userId}'),
      color: AppColors.paper,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.isOwner
              ? AppColors.cocoa
              : AppColors.terracotta,
          foregroundColor: Colors.white,
          child: Text(member.displayName.characters.first),
        ),
        title: Text(
          member.currentUser
              ? '${member.displayName}（我）'
              : member.displayName,
        ),
        subtitle: Text(_roleLabel(member.role)),
        trailing: canManage && ordinaryMember
            ? PopupMenuButton<_MemberAction>(
                key: ValueKey('member-actions-${member.userId}'),
                tooltip: '成员操作',
                onSelected: (action) {
                  switch (action) {
                    case _MemberAction.makeEditor:
                      onRoleChanged('EDITOR');
                      break;
                    case _MemberAction.makeViewer:
                      onRoleChanged('VIEWER');
                      break;
                    case _MemberAction.transferOwner:
                      onTransfer();
                      break;
                    case _MemberAction.remove:
                      onRemove();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _MemberAction.makeEditor,
                    child: Text('设为编辑者'),
                  ),
                  const PopupMenuItem(
                    value: _MemberAction.makeViewer,
                    child: Text('设为只读者'),
                  ),
                  if (member.isEditor)
                    const PopupMenuItem(
                      value: _MemberAction.transferOwner,
                      child: Text('转交所有权'),
                    ),
                  const PopupMenuItem(
                    value: _MemberAction.remove,
                    child: Text('移除成员'),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  String _roleLabel(String role) {
    return switch (role) {
      'OWNER' => '家庭拥有者',
      'EDITOR' => '编辑者',
      _ => '只读者',
    };
  }
}

enum _MemberAction {
  makeEditor,
  makeViewer,
  transferOwner,
  remove,
}
```

- [ ] **Step 4: Add the owner-only management entry**

In `family_workspace_section.dart`, add this import:

```dart
import 'package:smart_fridge_app/features/family/presentation/family_member_management_sheet.dart';
```

Inside `_FamilyList`, after the family cards, add:

```dart
if (workspace.selectedFamily?.role == 'OWNER')
  Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      key: const ValueKey('manage-members-button'),
      onPressed: () => showFamilyMemberManagementSheet(context),
      icon: const Icon(Icons.manage_accounts_rounded, size: 18),
      label: const Text('成员管理'),
    ),
  ),
```

- [ ] **Step 5: Verify member-management UI**

```powershell
flutter test test/family_page_test.dart test/family_members_controller_test.dart --reporter compact
dart analyze lib/features/family/presentation test/family_page_test.dart
```

Expected: the owner management test, member controller tests, and existing profile tests pass.

- [ ] **Step 6: Commit**

```powershell
git add apps/fridge-app/lib/features/family/presentation apps/fridge-app/test/family_page_test.dart
git commit -m "feat(app): manage household members and ownership"
```

### Task 11: Load Fridges From the Selected Family

**Files:**
- Modify: `apps/fridge-app/lib/features/family/application/family_controller.dart`
- Modify: `apps/fridge-app/lib/features/fridge/data/api_fridge_repository.dart`
- Modify: `apps/fridge-app/lib/features/fridge/application/fridge_workspace_controller.dart`
- Modify: `apps/fridge-app/test/api_fridge_repository_test.dart`
- Modify: `apps/fridge-app/test/fridge_workspace_controller_test.dart`
- Modify: `apps/fridge-app/test/fridge_home_test.dart`
- Modify: `apps/fridge-app/test/recipes_page_test.dart`

- [ ] **Step 1: Write the failing selected-family fridge test**

Replace `fridge_workspace_controller_test.dart` with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';
import 'package:smart_fridge_app/features/fridge/application/fridge_workspace_controller.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';

void main() {
  test('loads the selected family and reloads after switching', () async {
    final fridgeSource = _FakeFridgeDataSource();
    final familySource = _FridgeFamilySource();
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(_RealSessionStore()),
        familyDataSourceProvider.overrideWithValue(familySource),
        familySelectionStoreProvider.overrideWithValue(
          _FridgeSelectionStore(),
        ),
        fridgeDataSourceProvider.overrideWithValue(fridgeSource),
      ],
    );
    addTearDown(container.dispose);

    final first = await container.read(fridgeWorkspaceProvider.future);
    expect(first.familyId, 4);
    expect(first.familyName, '小满的家');
    expect(fridgeSource.lastFamilyId, 4);

    await container
        .read(familyControllerProvider.notifier)
        .selectFamily(5);
    final second = await container.read(fridgeWorkspaceProvider.future);

    expect(second.familyId, 5);
    expect(second.familyName, '父母的厨房');
    expect(fridgeSource.lastFamilyId, 5);
  });
}

class _FakeFridgeDataSource implements FridgeDataSource {
  int? lastFamilyId;

  @override
  Future<FridgeWorkspaceData> load(
    AuthSession session,
    int familyId,
  ) async {
    lastFamilyId = familyId;
    return FridgeWorkspaceData(
      familyId: familyId,
      familyName: familyId == 4 ? '小满的家' : '父母的厨房',
      role: familyId == 4 ? 'OWNER' : 'EDITOR',
      fridgeId: familyId,
      fridgeName: '厨房冰箱',
      timezone: 'Asia/Shanghai',
      zones: const [
        FridgeZone(
          id: FridgeZoneId.fresh,
          serverId: 11,
          name: '冷藏',
          description: '蔬果 · 饮品 · 熟食',
          temperature: '4°C',
          emoji: '🥬',
        ),
      ],
      foods: const [
        FridgeFood(
          id: '31',
          serverId: 31,
          name: '测试牛奶',
          emoji: '🥛',
          quantity: 2,
          unit: '盒',
          expiresInDays: 5,
          zone: FridgeZoneId.fresh,
          category: '蛋奶',
          owner: '小满',
          tilt: 0,
        ),
      ],
    );
  }

  @override
  Future<void> addFood(
    AuthSession session,
    FridgeWorkspaceData workspace,
    NewFoodInput input,
  ) async {}

  @override
  Future<void> consume(
    AuthSession session,
    FridgeFood food,
    double quantity,
  ) async {}

  @override
  Future<void> discardFood(AuthSession session, FridgeFood food) async {}

  @override
  Future<void> moveFood(
    AuthSession session,
    FridgeFood food,
    FridgeZone targetZone,
  ) async {}
}

class _FridgeFamilySource implements FamilyDataSource {
  @override
  Future<List<FamilyInfo>> list(AuthSession session) async => const [
    FamilyInfo(
      id: 4,
      name: '小满的家',
      inviteCode: 'TEST2026',
      ownerUserId: 7,
      role: 'OWNER',
    ),
    FamilyInfo(
      id: 5,
      name: '父母的厨房',
      inviteCode: 'PARENT26',
      ownerUserId: 9,
      role: 'EDITOR',
    ),
  ];

  @override
  Future<FamilyInfo> create(AuthSession session, String name) {
    throw UnimplementedError();
  }

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) {
    throw UnimplementedError();
  }

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async => const [];

  @override
  Future<FamilyMember> updateMemberRole(
    AuthSession session,
    int familyId,
    int userId,
    String role,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeMember(
    AuthSession session,
    int familyId,
    int userId,
  ) async {}

  @override
  Future<FamilyInfo> transferOwner(
    AuthSession session,
    int familyId,
    int targetUserId,
  ) {
    throw UnimplementedError();
  }
}

class _FridgeSelectionStore implements FamilySelectionStore {
  int? selectedFamilyId = 4;

  @override
  Future<int?> read(int userId) async => selectedFamilyId;

  @override
  Future<void> write(int userId, int familyId) async {
    selectedFamilyId = familyId;
  }

  @override
  Future<void> clear(int userId) async {
    selectedFamilyId = null;
  }
}

class _RealSessionStore implements SessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async {
    return AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
      issuedAt: DateTime.now().toUtc(),
      user: const UserProfile(
        id: 7,
        displayName: '小满',
        username: 'manman',
        role: 'USER',
      ),
    );
  }

  @override
  Future<void> write(AuthSession session) async {}
}
```

Also add this test to `api_fridge_repository_test.dart`:

```dart
test('explains when the selected family has no fridge', () async {
  final repository = ApiFridgeRepository(_MissingFridgeApiClient());

  await expectLater(
    repository.load(session, 5),
    throwsA(
      isA<ApiFailure>().having(
        (error) => error.message,
        'message',
        '当前家庭没有冰箱，请切换其他家庭',
      ),
    ),
  );
});

class _MissingFridgeApiClient extends ApiClient {
  _MissingFridgeApiClient() : super(Dio());

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? accessToken,
  }) async {
    if (path == '/api/v1/fridges') {
      throw const ApiFailure('冰箱不存在', statusCode: 404);
    }
    throw StateError('Unexpected GET $path');
  }
}
```

Create `recipe_family_selection_test.dart` to prove recipe matches follow family changes:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';
import 'package:smart_fridge_app/features/recipe/application/recipe_controller.dart';
import 'package:smart_fridge_app/features/recipe/data/recipe_repository.dart';
import 'package:smart_fridge_app/features/recipe/domain/recipe.dart';

void main() {
  test('recipe matching reloads after switching family', () async {
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(_RecipeFamilySessionStore()),
        familyDataSourceProvider.overrideWithValue(_RecipeFamilySource()),
        familySelectionStoreProvider.overrideWithValue(
          _RecipeFamilySelectionStore(),
        ),
        fridgeDataSourceProvider.overrideWithValue(_RecipeFamilyFridgeSource()),
        recipeDataSourceProvider.overrideWithValue(_ToFuRecipeSource()),
      ],
    );
    addTearDown(container.dispose);

    final first = await container.read(recipeBrowserProvider.future);
    await container
        .read(familyControllerProvider.notifier)
        .selectFamily(5);
    final second = await container.read(recipeBrowserProvider.future);

    expect(first.single.score, 100);
    expect(second.single.score, 0);
  });
}

class _RecipeFamilyFridgeSource implements FridgeDataSource {
  @override
  Future<FridgeWorkspaceData> load(
    AuthSession session,
    int familyId,
  ) async {
    return FridgeWorkspaceData(
      familyId: familyId,
      familyName: familyId == 4 ? '小满的家' : '父母的厨房',
      role: 'OWNER',
      fridgeId: familyId,
      fridgeName: '厨房冰箱',
      timezone: 'Asia/Shanghai',
      zones: const [
        FridgeZone(
          id: FridgeZoneId.fresh,
          serverId: 11,
          name: '冷藏',
          description: '冷藏',
          temperature: '4°C',
          emoji: '🥬',
        ),
      ],
      foods: familyId == 4
          ? const [
              FridgeFood(
                id: '10',
                name: '嫩豆腐',
                emoji: '🥣',
                quantity: 1,
                unit: '盒',
                expiresInDays: 2,
                zone: FridgeZoneId.fresh,
                category: '豆制品',
                owner: '小满',
                tilt: 0,
              ),
            ]
          : const [],
    );
  }

  @override
  Future<void> addFood(
    AuthSession session,
    FridgeWorkspaceData workspace,
    NewFoodInput input,
  ) async {}

  @override
  Future<void> consume(
    AuthSession session,
    FridgeFood food,
    double quantity,
  ) async {}

  @override
  Future<void> discardFood(AuthSession session, FridgeFood food) async {}

  @override
  Future<void> moveFood(
    AuthSession session,
    FridgeFood food,
    FridgeZone targetZone,
  ) async {}
}

class _ToFuRecipeSource implements RecipeDataSource {
  @override
  Future<List<Recipe>> load(AuthSession session) async {
    return const [
      Recipe(
        id: 99,
        name: '香煎测试豆腐',
        summary: '接口菜谱',
        category: '测试菜',
        durationMinutes: 12,
        calories: 180,
        difficulty: '简单',
        servings: 2,
        coverEmoji: '🍳',
        steps: ['切豆腐', '煎熟'],
        featured: true,
        ingredients: [
          RecipeIngredient(name: '嫩豆腐', quantity: 1, unit: '盒'),
        ],
      ),
    ];
  }
}

class _RecipeFamilySource implements FamilyDataSource {
  @override
  Future<List<FamilyInfo>> list(AuthSession session) async => const [
    FamilyInfo(
      id: 4,
      name: '小满的家',
      inviteCode: 'TEST2026',
      ownerUserId: 7,
      role: 'OWNER',
    ),
    FamilyInfo(
      id: 5,
      name: '父母的厨房',
      inviteCode: 'PARENT26',
      ownerUserId: 9,
      role: 'EDITOR',
    ),
  ];

  @override
  Future<FamilyInfo> create(AuthSession session, String name) {
    throw UnimplementedError();
  }

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) {
    throw UnimplementedError();
  }

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async => const [];

  @override
  Future<FamilyMember> updateMemberRole(
    AuthSession session,
    int familyId,
    int userId,
    String role,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeMember(
    AuthSession session,
    int familyId,
    int userId,
  ) async {}

  @override
  Future<FamilyInfo> transferOwner(
    AuthSession session,
    int familyId,
    int targetUserId,
  ) {
    throw UnimplementedError();
  }
}

class _RecipeFamilySelectionStore implements FamilySelectionStore {
  int? selectedFamilyId = 4;

  @override
  Future<int?> read(int userId) async => selectedFamilyId;

  @override
  Future<void> write(int userId, int familyId) async {
    selectedFamilyId = familyId;
  }

  @override
  Future<void> clear(int userId) async {
    selectedFamilyId = null;
  }
}

class _RecipeFamilySessionStore implements SessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async {
    return AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
      issuedAt: DateTime.now().toUtc(),
      user: const UserProfile(
        id: 7,
        displayName: '小满',
        username: 'manman',
        role: 'USER',
      ),
    );
  }

  @override
  Future<void> write(AuthSession session) async {}
}
```

- [ ] **Step 2: Run the test and confirm RED**

```powershell
flutter test test/fridge_workspace_controller_test.dart test/recipe_family_selection_test.dart --reporter compact
```

Expected: compile failure because `FridgeDataSource.load` receives no `familyId` and the controller still calls the old signature.

- [ ] **Step 3: Preserve demo behavior in FamilyController**

In `FamilyController.build`, immediately after loading `families`, add:

```dart
if (freshSession.isDemo) {
  return FamilyWorkspaceState(
    families: families,
    selectedFamilyId: families.firstOrNull?.id,
  );
}
```

Keep the existing empty-list handling after this block. Demo sessions never touch `shared_preferences`.

- [ ] **Step 4: Change the fridge data contract**

In `api_fridge_repository.dart`, replace the interface method:

```dart
Future<FridgeWorkspaceData> load(AuthSession session, int familyId);
```

Replace `ApiFridgeRepository.load` with:

```dart
@override
Future<FridgeWorkspaceData> load(AuthSession session, int familyId) async {
  if (session.isDemo) {
    return FridgeWorkspaceData.demo(session.user);
  }

  late final Map<String, dynamic> fridgeBody;
  try {
    fridgeBody = await _api.get(
      '/api/v1/fridges',
      queryParameters: {'familyId': familyId},
      accessToken: session.accessToken,
    );
  } on ApiFailure catch (error) {
    if (error.statusCode == 404) {
      throw const ApiFailure('当前家庭没有冰箱，请切换其他家庭');
    }
    rethrow;
  }
  final fridge = _map(fridgeBody['data']);
  final fridgeId = (fridge['id'] as num).toInt();

  final foodsBody = await _api.get(
    '/api/v1/foods',
    queryParameters: {'fridgeId': fridgeId},
    accessToken: session.accessToken,
  );
  return FridgeWorkspaceData.fromApi(
    familyData: {
      'id': familyId,
      'name': '当前家庭',
      'currentUserRole': 'VIEWER',
    },
    fridgeData: fridge,
    foodsData: _list(foodsBody['data']),
    currentUser: session.user,
  );
}
```

The family name and role are not part of the fridge response. Override them from the selected `FamilyInfo` in the controller after loading, using `workspace.selectedFamily`; do not label every family as `OWNER` on screen.

Update `FridgeWorkspaceData` with:

```dart
FridgeWorkspaceData withFamilyIdentity({
  required int familyId,
  required String familyName,
  required String role,
}) {
  return FridgeWorkspaceData(
    familyId: familyId,
    familyName: familyName,
    role: role,
    fridgeId: fridgeId,
    fridgeName: fridgeName,
    timezone: timezone,
    zones: zones,
    foods: foods,
  );
}
```

- [ ] **Step 5: Make the controller follow family selection**

Replace `fridge_workspace_controller.dart` with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/features/auth/application/auth_controller.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';
import 'package:smart_fridge_app/features/family/application/family_controller.dart';
import 'package:smart_fridge_app/features/family/domain/family_workspace_state.dart';
import 'package:smart_fridge_app/features/fridge/data/api_fridge_repository.dart';
import 'package:smart_fridge_app/features/fridge/domain/fridge_workspace_data.dart';

final fridgeWorkspaceProvider =
    AsyncNotifierProvider<FridgeWorkspaceController, FridgeWorkspaceData>(
      FridgeWorkspaceController.new,
    );

class FridgeWorkspaceController extends AsyncNotifier<FridgeWorkspaceData> {
  FridgeDataSource get _source => ref.read(fridgeDataSourceProvider);

  @override
  Future<FridgeWorkspaceData> build() async {
    final session = await ref.watch(authControllerProvider.future);
    if (session == null) {
      throw StateError('当前没有登录会话');
    }
    final workspace = await ref.watch(familyControllerProvider.future);
    return _load(session, workspace);
  }

  Future<void> refresh() async {
    final session = await _session();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final workspace = await ref.read(familyControllerProvider.future);
      return _load(session, workspace);
    });
  }

  Future<void> addFood(NewFoodInput input) async {
    final session = await _requireEditableSession();
    final workspace = state.requireValue;
    await _mutate(
      () => _source.addFood(session, workspace, input),
    );
  }

  Future<void> moveFood(FridgeFood food, FridgeZone targetZone) async {
    final session = await _requireEditableSession();
    await _mutate(() => _source.moveFood(session, food, targetZone));
  }

  Future<void> consume(FridgeFood food, double quantity) async {
    final session = await _requireEditableSession();
    await _mutate(() => _source.consume(session, food, quantity));
  }

  Future<void> discard(FridgeFood food) async {
    final session = await _requireEditableSession();
    await _mutate(() => _source.discardFood(session, food));
  }

  Future<FridgeWorkspaceData> _load(
    AuthSession session,
    FamilyWorkspaceState families,
  ) async {
    if (session.isDemo) {
      return _source.load(session, 0);
    }
    final family = families.selectedFamily;
    if (family == null) {
      throw StateError('当前账号尚未加入家庭');
    }
    final loaded = await _source.load(session, family.id);
    return loaded.withFamilyIdentity(
      familyId: family.id,
      familyName: family.name,
      role: family.role,
    );
  }

  Future<void> _mutate(Future<void> Function() action) async {
    final session = await _session();
    final previous = state;
    try {
      await action();
      final workspace = await ref.read(familyControllerProvider.future);
      state = AsyncData(await _load(session, workspace));
    } on Object catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<AuthSession> _session() async {
    var session = await ref.read(authControllerProvider.future);
    if (session == null) {
      throw StateError('当前没有登录会话');
    }
    if (session.isAccessTokenExpiring) {
      session = await ref
          .read(authControllerProvider.notifier)
          .refreshAccessToken();
    }
    return session;
  }

  Future<AuthSession> _requireEditableSession() async {
    final session = await _session();
    if (session.isDemo) {
      throw StateError('演示模式不能修改真实冰箱');
    }
    if (!state.requireValue.canEdit) {
      throw StateError('当前家庭成员没有编辑权限');
    }
    return session;
  }
}
```

- [ ] **Step 6: Update all `FridgeDataSource` test implementations**

Replace every load signature:

```dart
Future<FridgeWorkspaceData> load(AuthSession session)
```

with:

```dart
Future<FridgeWorkspaceData> load(AuthSession session, int familyId)
```

Do this in:

- `api_fridge_repository_test.dart`
- `fridge_workspace_controller_test.dart`
- `fridge_home_test.dart`
- `recipes_page_test.dart`

In `api_fridge_repository_test.dart`, change the call and assertions:

```dart
final workspace = await repository.load(session, 4);

expect(api.getCalls.map((call) => call.$1), [
  '/api/v1/fridges',
  '/api/v1/foods',
]);
expect(api.getCalls[0].$2?['familyId'], 4);
```

Delete the `'/api/v1/families'` branch from `_FakeApiClient.get`.

For real-session widget tests in `fridge_home_test.dart` and `recipes_page_test.dart`, add these imports:

```dart
import 'package:smart_fridge_app/features/family/data/family_repository.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';
import 'package:smart_fridge_app/features/family/domain/family_info.dart';
import 'package:smart_fridge_app/features/family/domain/family_member.dart';
```

Add these overrides beside `fridgeDataSourceProvider`:

```dart
familyDataSourceProvider.overrideWithValue(_FridgeFixtureFamilySource()),
familySelectionStoreProvider.overrideWithValue(
  _FridgeFixtureSelectionStore(),
),
```

Add these classes to each test file:

```dart
class _FridgeFixtureFamilySource implements FamilyDataSource {
  @override
  Future<List<FamilyInfo>> list(AuthSession session) async => const [
    FamilyInfo(
      id: 4,
      name: '小满的家',
      inviteCode: 'TEST2026',
      ownerUserId: 7,
      role: 'OWNER',
    ),
  ];

  @override
  Future<FamilyInfo> create(AuthSession session, String name) {
    throw UnimplementedError();
  }

  @override
  Future<FamilyInfo> join(AuthSession session, String inviteCode) {
    throw UnimplementedError();
  }

  @override
  Future<List<FamilyMember>> listMembers(
    AuthSession session,
    int familyId,
  ) async => const [];

  @override
  Future<FamilyMember> updateMemberRole(
    AuthSession session,
    int familyId,
    int userId,
    String role,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeMember(
    AuthSession session,
    int familyId,
    int userId,
  ) async {}

  @override
  Future<FamilyInfo> transferOwner(
    AuthSession session,
    int familyId,
    int targetUserId,
  ) {
    throw UnimplementedError();
  }
}

class _FridgeFixtureSelectionStore implements FamilySelectionStore {
  @override
  Future<int?> read(int userId) async => 4;

  @override
  Future<void> write(int userId, int familyId) async {}

  @override
  Future<void> clear(int userId) async {}
}
```

- [ ] **Step 7: Verify all fridge and recipe tests**

```powershell
flutter test test/api_fridge_repository_test.dart test/fridge_workspace_controller_test.dart test/fridge_home_test.dart test/recipes_page_test.dart test/recipe_family_selection_test.dart --reporter compact
dart analyze lib/features/fridge lib/features/family lib/features/recipe test/api_fridge_repository_test.dart test/fridge_workspace_controller_test.dart test/fridge_home_test.dart test/recipes_page_test.dart test/recipe_family_selection_test.dart
```

Expected: all tests pass; switching from family `4` to `5` causes a second fridge load with `familyId=5`.

- [ ] **Step 8: Commit**

```powershell
git add apps/fridge-app/lib/features/family/application/family_controller.dart apps/fridge-app/lib/features/fridge apps/fridge-app/test/api_fridge_repository_test.dart apps/fridge-app/test/fridge_workspace_controller_test.dart apps/fridge-app/test/fridge_home_test.dart apps/fridge-app/test/recipes_page_test.dart
git commit -m "feat(app): load fridge from the selected family"
```

### Task 12: OpenAPI Contract and Documentation

**Files:**
- Modify: `contracts/openapi/smart-fridge-v1.yaml`
- Modify: `README.md`
- Modify: `docs/开发状态.md`
- Modify: `docs/S2-冰箱领域实现.md`
- Modify: `docs/开发运行手册.md`
- Modify: `docs/superpowers/specs/2026-10-29-family-collaboration-workspace-design.md`

- [ ] **Step 1: Update the API version and description**

In `contracts/openapi/smart-fridge-v1.yaml`, change:

```yaml
version: 1.2.0
description: |
  可视化冰箱客户端与运营后台的统一 API 契约。
  当前版本实现认证家庭、冰箱结构、食材 CRUD 和食材操作日志。
```

to:

```yaml
version: 1.3.0
description: |
  可视化冰箱客户端与运营后台的统一 API 契约。
  当前版本实现认证家庭、邀请码加入、成员治理、冰箱结构、食材 CRUD 和食材操作日志。
```

- [ ] **Step 2: Document the join endpoint**

Insert this path after the existing `/api/v1/families/{familyId}` path:

```yaml
  /api/v1/families/join:
    post:
      tags: [Family]
      summary: 通过邀请码加入家庭
      description: 已加入同一家庭时幂等返回当前成员角色。
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/JoinFamilyRequest'
      responses:
        '200':
          description: 已加入家庭
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/FamilyResponse'
        '400':
          $ref: '#/components/responses/ValidationError'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '404':
          $ref: '#/components/responses/NotFound'
```

- [ ] **Step 3: Document member and ownership endpoints**

Insert these paths after the join path:

```yaml
  /api/v1/families/{familyId}/members:
    get:
      tags: [Family]
      summary: 查询家庭成员
      security:
        - bearerAuth: []
      parameters:
        - name: familyId
          in: path
          required: true
          schema:
            type: integer
            format: int64
      responses:
        '200':
          description: 家庭成员列表
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/FamilyMemberListResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '404':
          $ref: '#/components/responses/NotFound'
  /api/v1/families/{familyId}/members/{userId}:
    patch:
      tags: [Family]
      summary: 调整普通成员角色
      description: 仅家庭 OWNER 可调用；只接受 EDITOR 和 VIEWER。
      security:
        - bearerAuth: []
      parameters:
        - name: familyId
          in: path
          required: true
          schema:
            type: integer
            format: int64
        - name: userId
          in: path
          required: true
          schema:
            type: integer
            format: int64
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UpdateFamilyRoleRequest'
      responses:
        '200':
          description: 更新后的成员
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/FamilyMemberResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/Forbidden'
        '404':
          $ref: '#/components/responses/NotFound'
        '409':
          $ref: '#/components/responses/Conflict'
    delete:
      tags: [Family]
      summary: 移除普通成员
      description: 仅家庭 OWNER 可调用，不能移除拥有者。
      security:
        - bearerAuth: []
      parameters:
        - name: familyId
          in: path
          required: true
          schema:
            type: integer
            format: int64
        - name: userId
          in: path
          required: true
          schema:
            type: integer
            format: int64
      responses:
        '204':
          description: 成员已移除
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/Forbidden'
        '404':
          $ref: '#/components/responses/NotFound'
        '409':
          $ref: '#/components/responses/Conflict'
  /api/v1/families/{familyId}/transfer-owner:
    post:
      tags: [Family]
      summary: 转交家庭所有权
      description: 目标必须是 EDITOR；成功后原拥有者变为 EDITOR。
      security:
        - bearerAuth: []
      parameters:
        - name: familyId
          in: path
          required: true
          schema:
            type: integer
            format: int64
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TransferFamilyOwnerRequest'
      responses:
        '200':
          description: 更新后的家庭和当前用户角色
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/FamilyResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/Forbidden'
        '404':
          $ref: '#/components/responses/NotFound'
        '409':
          $ref: '#/components/responses/Conflict'
```

- [ ] **Step 4: Add family schemas and validation response**

Add this response beside `NotFound`:

```yaml
    ValidationError:
      description: 请求字段校验失败
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'
```

Add these schemas before `CreateFridgeRequest`:

```yaml
    JoinFamilyRequest:
      type: object
      required: [inviteCode]
      properties:
        inviteCode:
          type: string
          minLength: 8
          maxLength: 8
          pattern: '^[A-Za-z0-9]{8}$'
          example: ABCD2345
    UpdateFamilyRoleRequest:
      type: object
      required: [role]
      properties:
        role:
          type: string
          example: EDITOR
    TransferFamilyOwnerRequest:
      type: object
      required: [targetUserId]
      properties:
        targetUserId:
          type: integer
          format: int64
    FamilyMember:
      type: object
      properties:
        userId:
          type: integer
          format: int64
        username:
          type: string
          nullable: true
        displayName:
          type: string
        role:
          type: string
          enum: [OWNER, EDITOR, VIEWER]
        joinedAt:
          type: string
          format: date-time
        currentUser:
          type: boolean
    FamilyResponse:
      type: object
      properties:
        code:
          type: string
          example: OK
        message:
          type: string
        data:
          $ref: '#/components/schemas/Family'
        traceId:
          type: string
    FamilyMemberResponse:
      type: object
      properties:
        code:
          type: string
          example: OK
        message:
          type: string
        data:
          $ref: '#/components/schemas/FamilyMember'
        traceId:
          type: string
    FamilyMemberListResponse:
      type: object
      properties:
        code:
          type: string
          example: OK
        message:
          type: string
        data:
          type: array
          items:
            $ref: '#/components/schemas/FamilyMember'
        traceId:
          type: string
```

- [ ] **Step 5: Update README and status documents**

Update `README.md` current-status paragraph to state:

```markdown
当前已完成 S0、S1、WebGL 真 3D 首页和 S2 核心纵切。家庭页支持创建、邀请码加入、多家庭切换、成员角色管理和所有权转交；认证家庭服务、冰箱服务与菜谱服务已通过真实 Gateway 联调。
```

Add these API entries to the README list:

```markdown
- `POST /api/v1/families/join`
- `GET /api/v1/families/{familyId}/members`
- `PATCH /api/v1/families/{familyId}/members/{userId}`
- `DELETE /api/v1/families/{familyId}/members/{userId}`
- `POST /api/v1/families/{familyId}/transfer-owner`
```

In `docs/开发状态.md`, change the update date to `2026-10-29` and add a completed subsection:

```markdown
### S2 家庭协作与多家庭工作区

- 支持 8 位邀请码加入家庭，新成员默认 VIEWER，重复加入幂等。
- 家庭 OWNER 可查看成员、调整 EDITOR/VIEWER、移除成员并转交所有权。
- 所有权转交在事务中同步更新 `family.owner_user_id` 和成员角色，原 OWNER 变为 EDITOR。
- Flutter 按用户持久化当前家庭，切换家庭后冰箱和菜谱重新加载。
- 家庭页提供创建、加入、切换、成员列表和成员操作面板。
```

Add a row to the acceptance table:

```markdown
| 家庭协作接口 | 通过 | 邀请加入、成员治理、所有权转交和权限测试 |
```

In `docs/S2-冰箱领域实现.md`, add:

```markdown
## 家庭协作纵切

- 邀请码加入默认 VIEWER，当前家庭由客户端按用户持久化保存。
- 认证家庭服务提供成员列表、角色调整、成员移除和事务化所有权转交。
- 冰箱服务仍通过 Gateway 访问；Flutter 冰箱首页依赖当前选中家庭，不再自动选择列表第一项。
```

In `docs/开发运行手册.md`, add a smoke-test subsection under verification:

```markdown
家庭协作冒烟：

1. 用家庭 OWNER 登录并创建家庭。
2. 用第二个账号调用 `POST /api/v1/families/join` 输入邀请码。
3. 打开家庭页，确认第二个家庭显示加入成功并可被选中。
4. OWNER 打开成员管理，将成员调整为 EDITOR。
5. 将该 EDITOR 设为所有权接收者，确认双方角色分别为 EDITOR 和 OWNER。
```

- [ ] **Step 6: Mark the design spec approved**

Change the spec line:

```markdown
- 状态：已确认，待用户审阅
```

to:

```markdown
- 状态：已批准
```

- [ ] **Step 7: Validate OpenAPI YAML**

```powershell
python -c "import yaml; yaml.safe_load(open('contracts/openapi/smart-fridge-v1.yaml', encoding='utf-8')); print('openapi yaml ok')"
mvn --batch-mode -q -f backend/pom.xml -DskipTests package
```

Expected: `openapi yaml ok` and Maven exits with code `0`.

- [ ] **Step 8: Commit**

```powershell
git add contracts/openapi/smart-fridge-v1.yaml README.md docs/开发状态.md docs/S2-冰箱领域实现.md docs/开发运行手册.md docs/superpowers/specs/2026-10-29-family-collaboration-workspace-design.md
git commit -m "docs: document family collaboration APIs"
```

### Task 13: Full Verification and Regression Pass

**Files:**
- Verify only; only modify code if a failing test identifies a defect.

- [ ] **Step 1: Run the full backend suite**

```powershell
cd backend
mvn --batch-mode test
```

Expected: all backend tests pass. Re-run with `-q` only when the default output is too large; preserve the exit code.

- [ ] **Step 2: Run the full Flutter suite and analysis**

```powershell
cd ..\apps\fridge-app
flutter test --reporter compact
dart analyze lib test
```

Expected: all Flutter tests pass and analysis prints `No issues found!`.

- [ ] **Step 3: Build both clients**

```powershell
cd ..\fridge-app
flutter build web --release
cd ..\admin-web
npm run build
```

Expected: Flutter release build and Vue production build both exit with code `0`.

- [ ] **Step 4: Restart the changed backend service and smoke the Gateway flow**

```powershell
cd C:\Users\Lenovo\Desktop\软件开发实践
mvn --batch-mode -pl backend/auth-family-service -am package -DskipTests
```

Stop only the existing `auth-family-service` Java process, start its new JAR with the same cloud environment used by the current runbook, then verify:

```powershell
Invoke-RestMethod http://127.0.0.1:8081/actuator/health
```

Expected: `status = UP`. Do not stop MySQL, Redis, Nacos, MinIO, or unrelated services.

- [ ] **Step 5: Check repository hygiene**

```powershell
git diff --check
git status --short
git log --oneline -5
```

Expected: no whitespace errors; only the planned committed changes remain; the branch history contains all planned task commits.

- [ ] **Step 6: Final commit if verification required follow-up**

```powershell
git add backend apps contracts docs README.md
git commit -m "test: verify family collaboration workspace"
```

Only create this commit if the previous verification changed files. If no files changed, leave the final task commit as the last docs commit.

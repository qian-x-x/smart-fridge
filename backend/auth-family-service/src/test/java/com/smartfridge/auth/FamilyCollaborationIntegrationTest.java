/*
 * 这个文件：测试家庭协作：创建家庭、邀请加入、改角色、移除成员、转交所有权这些规则是否按预期工作。
 */

package com.smartfridge.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.smartfridge.auth.session.TokenRevocationService;
import java.nio.charset.StandardCharsets;
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
import static org.assertj.core.api.Assertions.assertThat;
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
            new InviteBody("  " + family.inviteCode().toLowerCase() + "  ")
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

    private void join(Session session, String inviteCode) throws Exception {
        mockMvc.perform(post("/api/v1/families/join")
                .header("Authorization", bearer(session))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new InviteBody(inviteCode))))
            .andExpect(status().isOk());
    }

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

    private record RoleBody(String role) {
    }

    private record TransferBody(long targetUserId) {
    }

}

/*
 * 这个文件：测试「一次创建家庭 + 默认冰箱」这个接口：成功、重复请求（幂等）、以及失败时会不会留下半成品数据。
 */

package com.smartfridge.auth.workspace;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.smartfridge.auth.session.TokenRevocationService;
import com.smartfridge.auth.family.FamilyService;
import com.smartfridge.common.error.BusinessException;
import io.seata.core.context.RootContext;
import com.smartfridge.common.api.ApiResponse;
import com.alibaba.csp.sentinel.slots.block.flow.FlowRule;
import com.alibaba.csp.sentinel.slots.block.flow.FlowRuleManager;
import com.alibaba.csp.sentinel.slots.block.RuleConstant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** HTTP/auth/idempotency tests; distributed rollback is verified on MySQL + TC. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class WorkspaceApiIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired JdbcTemplate jdbc;
    @Autowired WorkspaceProtection protection;
    @Autowired FamilyService families;
    @Autowired PlatformTransactionManager transactionManager;
    @MockBean TokenRevocationService revocations;
    @MockBean WorkspaceFridgeClient fridges;
    @MockBean WorkspaceTransactionStatus transactions;
    String token;
    long userId;

    @BeforeEach void setup() throws Exception {
        jdbc.update("DELETE FROM family_workspace_request");
        jdbc.update("DELETE FROM family_member");
        jdbc.update("DELETE FROM family");
        jdbc.update("DELETE FROM refresh_session");
        jdbc.update("DELETE FROM app_user");
        protection.rules();
        when(transactions.currentXid()).thenReturn("unit-test-xid");
        when(transactions.committed(anyString())).thenReturn(true);
        when(fridges.create(anyString(), anyString(), any())).thenAnswer(call -> {
            WorkspaceFridgeClient.NewFridge request = call.getArgument(2);
            return ApiResponse.success(new WorkspaceFridgeClient.CreatedFridge(
                request.familyId() + 10000, request.familyId()));
        });
        var session = register("workspace_owner");
        token = session.path("accessToken").asText();
        userId = session.path("user").path("id").asLong();
    }

    @AfterEach void cleanup() {
        RootContext.unbind();
        protection.rules();
        jdbc.update("DELETE FROM family_workspace_request");
    }

    @Test void createsFamilyOwnerAndInitializesFridgeWithVerifiedIdentity() throws Exception {
        var result = submit(token, "request-0001", " 家庭甲 ").andExpect(status().isCreated())
            .andExpect(jsonPath("$.data.family.name").value("家庭甲"))
            .andExpect(jsonPath("$.data.family.currentUserRole").value("OWNER"))
            .andReturn();
        var data = json.readTree(result.getResponse().getContentAsString()).path("data");
        long familyId = data.path("family").path("id").asLong();
        assertThat(data.path("fridgeId").asLong()).isEqualTo(familyId + 10000);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM family_member WHERE family_id = ? AND user_id = ? AND role = 'OWNER'",
            Integer.class, familyId, userId)).isEqualTo(1);
        verify(fridges).create(eq("Bearer " + token), eq(Long.toString(userId)),
            eq(new WorkspaceFridgeClient.NewFridge(familyId, "家庭冰箱")));
    }

    @Test void replayReturnsSameWorkspaceWithoutInitializingTwice() throws Exception {
        var first = submit(token, "request-0002", "家庭乙").andExpect(status().isCreated()).andReturn();
        var replay = submit(token, "request-0002", "家庭乙").andExpect(status().isOk()).andReturn();
        assertThat(json.readTree(replay.getResponse().getContentAsString()).path("data"))
            .isEqualTo(json.readTree(first.getResponse().getContentAsString()).path("data"));
        verify(fridges, times(1)).create(anyString(), anyString(), any());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM family", Integer.class)).isEqualTo(1);
    }

    @Test void requestIdCannotBeReusedForDifferentInput() throws Exception {
        submit(token, "request-0003", "家庭丙").andExpect(status().isCreated());
        submit(token, "request-0003", "另一个家庭").andExpect(status().isConflict());
        verify(fridges, times(1)).create(anyString(), anyString(), any());
    }

    @Test void sameRequestIdIsIsolatedBetweenUsers() throws Exception {
        var other = register("workspace_other").path("accessToken").asText();
        submit(token, "shared-request", "家庭丁").andExpect(status().isCreated());
        submit(other, "shared-request", "家庭戊").andExpect(status().isCreated());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM family", Integer.class)).isEqualTo(2);
        verify(fridges, times(2)).create(anyString(), anyString(), any());
    }

    @Test void doesNotReportPhaseOneDataAsCommittedSuccess() throws Exception {
        submit(token, "request-0004", "家庭己").andExpect(status().isCreated());
        jdbc.update("UPDATE family_workspace_request SET completed = FALSE");
        when(transactions.committed(anyString())).thenReturn(false);
        submit(token, "request-0004", "家庭己").andExpect(status().isConflict())
            .andExpect(jsonPath("$.message").value("家庭正在初始化，请稍后使用原请求重试"));
        verify(fridges, times(1)).create(anyString(), anyString(), any());
    }

    @Test void finishedRollbackCannotBeMistakenForCommitFromAnOlderRepeatableReadSnapshot() throws Exception {
        var response = submit(token, "request-snapshot", "快照家庭").andExpect(status().isCreated()).andReturn();
        long familyId = json.readTree(response.getResponse().getContentAsString()).path("data").path("family").path("id").asLong();
        jdbc.update("UPDATE family_workspace_request SET completed = FALSE");
        jdbc.update("UPDATE family SET workspace_pending = TRUE");
        when(transactions.committed(anyString())).thenAnswer(invocation -> {
            // TC has forgotten a completed rollback. Its phase-one records
            // disappear while this public caller still holds an older snapshot.
            var rollback = new TransactionTemplate(transactionManager);
            rollback.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
            rollback.executeWithoutResult(tx -> {
                jdbc.update("DELETE FROM family_member WHERE family_id = ?", familyId);
                jdbc.update("DELETE FROM family_workspace_request WHERE family_id = ?", familyId);
                jdbc.update("DELETE FROM family WHERE id = ?", familyId);
            });
            return true;
        });
        var caller = new TransactionTemplate(transactionManager);
        caller.setIsolationLevel(TransactionDefinition.ISOLATION_REPEATABLE_READ);
        caller.executeWithoutResult(tx -> {
            jdbc.queryForObject("SELECT name FROM family WHERE id = ?", String.class, familyId);
            assertThat(families.list(userId)).isEmpty();
        });
    }

    @Test void rejectsUnauthenticatedAndInvalidRequestsBeforeWriting() throws Exception {
        mvc.perform(post("/api/v1/families/workspaces").contentType(MediaType.APPLICATION_JSON)
            .content("{\"name\":\"家庭\",\"requestId\":\"request-0005\"}"))
            .andExpect(status().isUnauthorized());
        submit(token, "bad", "家庭").andExpect(status().isBadRequest());
        submit(token, "request-0005", "   ").andExpect(status().isBadRequest());
        verifyNoInteractions(fridges);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM family", Integer.class)).isZero();
    }

    @Test void rateLimitRejectsBeforeCreatingAnyRows() throws Exception {
        var rule = new FlowRule("family-workspace-create");
        rule.setGrade(RuleConstant.FLOW_GRADE_QPS);
        rule.setCount(0);
        FlowRuleManager.loadRules(List.of(rule));
        submit(token, "request-0006", "家庭庚").andExpect(status().isTooManyRequests());
        verifyNoInteractions(fridges);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM family", Integer.class)).isZero();
    }

    @Test void malformedDependencyResponseCannotBecomeSuccess() throws Exception {
        doReturn(ApiResponse.success(new WorkspaceFridgeClient.CreatedFridge(9, -1)))
            .when(fridges).create(anyString(), anyString(), any());
        submit(token, "request-0007", "家庭辛").andExpect(status().isServiceUnavailable());
    }

    @Test void pendingFamilyIsHiddenExceptFromItsOwnCoordinator() throws Exception {
        doAnswer(call -> {
            WorkspaceFridgeClient.NewFridge request = call.getArgument(2);
            long familyId = request.familyId();
            String invite = jdbc.queryForObject("SELECT invite_code FROM family WHERE id = ?", String.class, familyId);
            assertThat(families.list(userId)).isEmpty();
            assertThatThrownBy(() -> families.requireMember(userId, familyId)).isInstanceOf(BusinessException.class);
            assertThatThrownBy(() -> families.join(userId, invite)).isInstanceOf(BusinessException.class);
            RootContext.bind("unit-test-xid");
            try {
                assertThat(families.requireMember(userId, familyId).id()).isEqualTo(familyId);
            } finally { RootContext.unbind(); }
            return ApiResponse.success(new WorkspaceFridgeClient.CreatedFridge(familyId + 10000, familyId));
        }).when(fridges).create(anyString(), anyString(), any());
        submit(token, "request-visibility", "初始化中家庭").andExpect(status().isCreated());
        assertThat(families.list(userId)).hasSize(1);
    }

    @Test void missingWorkspaceMarkerCannotMakeAPendingFamilyLookLikeLegacyData() {
        long familyId = families.create(userId, "待初始化家庭").id();
        jdbc.update("UPDATE family SET workspace_pending = TRUE WHERE id = ?", familyId);
        assertThat(families.list(userId)).isEmpty();
        assertThatThrownBy(() -> families.requireMember(userId, familyId)).isInstanceOf(BusinessException.class);
    }

    @Test void publicCreationCannotJoinAnExternalTransaction() throws Exception {
        RootContext.bind("forged-external-xid");
        try {
            submit(token, "request-forged", "外部事务家庭").andExpect(status().isBadRequest());
        } finally { RootContext.unbind(); }
        verifyNoInteractions(fridges);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM family", Integer.class)).isZero();
    }

    private ResultActions submit(String access, String requestId, String name) throws Exception {
        return mvc.perform(post("/api/v1/families/workspaces")
            .header("Authorization", "Bearer " + access)
            .header("X-User-Id", "999999")
            .contentType(MediaType.APPLICATION_JSON)
            .content(json.writeValueAsString(Map.of("name", name, "requestId", requestId))));
    }

    private JsonNode register(String name) throws Exception {
        var response = mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
            .content(json.writeValueAsString(Map.of("username", name, "displayName", name,
                "password", "Workspace2026!")))).andExpect(status().isCreated()).andReturn();
        return json.readTree(response.getResponse().getContentAsString()).path("data");
    }
}

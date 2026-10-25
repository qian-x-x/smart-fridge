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

import java.time.Duration;
import java.util.HashSet;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthFlowIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockBean
    private TokenRevocationService tokenRevocationService;

    private final Set<String> revokedTokenIds = new HashSet<>();

    @BeforeEach
    void resetDatabaseAndRevocations() {
        jdbcTemplate.update("DELETE FROM family_member");
        jdbcTemplate.update("DELETE FROM refresh_session");
        jdbcTemplate.update("DELETE FROM family");
        jdbcTemplate.update("DELETE FROM app_user");
        revokedTokenIds.clear();

        doAnswer(invocation -> {
            revokedTokenIds.add(invocation.getArgument(0));
            return null;
        }).when(tokenRevocationService).revoke(anyString(), any(Duration.class));
        when(tokenRevocationService.isRevoked(anyString()))
            .thenAnswer(invocation -> revokedTokenIds.contains(invocation.getArgument(0)));
    }

    @Test
    void supportsRegistrationFamilyCreationRefreshAndLogout() throws Exception {
        String registrationBody = """
            {
              "username": "fridge_master",
              "phone": "",
              "displayName": "冰箱主理人",
              "password": "SmartFridge2026"
            }
            """;

        String registrationJson = mockMvc.perform(post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(registrationBody))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.code").value("OK"))
            .andExpect(jsonPath("$.traceId").isNotEmpty())
            .andExpect(jsonPath("$.data.user.displayName").value("冰箱主理人"))
            .andReturn()
            .getResponse()
            .getContentAsString();

        JsonNode registration = objectMapper.readTree(registrationJson);
        String accessToken = registration.at("/data/accessToken").asText();
        String refreshToken = registration.at("/data/refreshToken").asText();
        assertThat(accessToken).isNotBlank();
        assertThat(refreshToken).isNotBlank();

        String passwordHash = jdbcTemplate.queryForObject(
            "SELECT password_hash FROM app_user WHERE username = ?",
            String.class,
            "fridge_master"
        );
        assertThat(passwordHash).startsWith("$2");
        assertThat(passwordHash).isNotEqualTo("SmartFridge2026");

        mockMvc.perform(post("/api/v1/families")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"name": "小满的家"}
                    """))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.data.name").value("小满的家"))
            .andExpect(jsonPath("$.data.currentUserRole").value("OWNER"))
            .andExpect(jsonPath("$.data.inviteCode").isNotEmpty());

        mockMvc.perform(get("/api/v1/families")
                .header("Authorization", "Bearer " + accessToken))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data[0].name").value("小满的家"));

        String refreshJson = mockMvc.perform(post("/api/v1/auth/refresh")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new RefreshBody(refreshToken))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.accessToken").isNotEmpty())
            .andReturn()
            .getResponse()
            .getContentAsString();
        String rotatedRefresh = objectMapper.readTree(refreshJson).at("/data/refreshToken").asText();

        mockMvc.perform(post("/api/v1/auth/logout")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new LogoutBody(rotatedRefresh))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.code").value("OK"));

        mockMvc.perform(get("/api/v1/families")
                .header("Authorization", "Bearer " + accessToken))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    void rejectsWrongPasswordWithStableErrorShape() throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"username":"wrong_pass_user","displayName":"测试","password":"Password123"}
                    """))
            .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"identifier":"wrong_pass_user","password":"not-the-password"}
                    """))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
            .andExpect(jsonPath("$.message").value("账号或密码错误"))
            .andExpect(jsonPath("$.data").doesNotExist());
    }

    private record RefreshBody(String refreshToken) {
    }

    private record LogoutBody(String refreshToken) {
    }
}

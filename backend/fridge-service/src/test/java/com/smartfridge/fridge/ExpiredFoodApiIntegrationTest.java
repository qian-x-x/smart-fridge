package com.smartfridge.fridge;

import com.jayway.jsonpath.JsonPath;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.ZoneId;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ExpiredFoodApiIntegrationTest {

    private static final HttpServer AUTH_SERVER = startAuthServer();
    private static final ZoneId FRIDGE_ZONE = ZoneId.of("Asia/Shanghai");
    private static volatile String currentFamilyRole = "OWNER";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @DynamicPropertySource
    static void authServiceProperties(DynamicPropertyRegistry registry) {
        registry.add(
            "smart-fridge.auth-service-url",
            () -> "http://127.0.0.1:" + AUTH_SERVER.getAddress().getPort()
        );
    }

    @Test
    void discardsOnlyExpiredItemsAndKeepsOneRecordPerItem() throws Exception {
        FridgeFixture fridge = createFridge(960, "480");
        long expiredMilk = addFood(fridge, "过期牛奶", "奶制品", 2.0, daysFromToday(-3), "481");
        addFood(fridge, "今日到期鸡蛋", "蛋类", 6.0, daysFromToday(0), "481");
        long freshBroccoli = addFood(fridge, "新鲜西兰花", "蔬菜", 1.0, daysFromToday(5), "481");

        discardExpired(fridge.fridgeId(), "481")
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.count").value(1))
            .andExpect(jsonPath("$.data.skipped").value(0))
            .andExpect(jsonPath("$.data.foods[0].id").value(expiredMilk))
            .andExpect(jsonPath("$.data.foods[0].name").value("过期牛奶"))
            .andExpect(jsonPath("$.data.foods[0].quantity").value(2.0));

        mockMvc.perform(get("/api/v1/foods")
                .param("fridgeId", String.valueOf(fridge.fridgeId()))
                .header("X-User-Id", "481")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.length()").value(2))
            .andExpect(jsonPath("$.data[?(@.id == " + freshBroccoli + ")]").exists());

        mockMvc.perform(get("/api/v1/fridges/" + fridge.fridgeId() + "/operations")
                .header("X-User-Id", "481")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data[0].action").value("DISCARD"))
            .andExpect(jsonPath("$.data[0].foodName").value("过期牛奶"))
            .andExpect(jsonPath("$.data[0].note").value("过期清理"))
            .andExpect(jsonPath("$.data[0].newQuantity").value(0.0));

        Integer discardedRows = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM food_item WHERE id = ? AND status = 'DISCARDED' AND quantity = 0",
            Integer.class,
            expiredMilk
        );
        assertEquals(1, discardedRows);
    }

    @Test
    void reportsZeroWhenNothingHasExpired() throws Exception {
        FridgeFixture fridge = createFridge(961, "482");
        addFood(fridge, "尚未过期酸奶", "奶制品", 3.0, daysFromToday(2), "482");

        discardExpired(fridge.fridgeId(), "482")
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.count").value(0))
            .andExpect(jsonPath("$.data.skipped").value(0))
            .andExpect(jsonPath("$.data.foods.length()").value(0));
    }

    @Test
    void viewerCannotCleanExpiredStock() throws Exception {
        FridgeFixture fridge = createFridge(962, "483");
        long expiredMilk = addFood(fridge, "只读过期牛奶", "奶制品", 2.0, daysFromToday(-1), "483");

        currentFamilyRole = "VIEWER";
        discardExpired(fridge.fridgeId(), "483")
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.code").value("FORBIDDEN"));

        Integer stillActive = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM food_item WHERE id = ? AND status = 'ACTIVE'",
            Integer.class,
            expiredMilk
        );
        assertEquals(1, stillActive);
    }

    @Test
    void rejectsCleanupForUnknownFridge() throws Exception {
        discardExpired(999_999, "484").andExpect(status().isNotFound());
    }

    @Test
    void updatesCategoryInPlaceSoAWrongCategoryCanBeFixed() throws Exception {
        FridgeFixture fridge = createFridge(963, "485");
        long foodId = addFood(fridge, "西兰花", "水果", 1.0, daysFromToday(4), "485");

        mockMvc.perform(put("/api/v1/foods/" + foodId)
                .header("X-User-Id", "485")
                .header("Authorization", "Bearer editor-token")
                .contentType("application/json")
                .content("""
                    {
                      "zoneId": %d,
                      "containerId": %d,
                      "name": "西兰花",
                      "category": "蔬菜",
                      "quantity": 1,
                      "unit": "颗",
                      "productionDate": "%s",
                      "expiresOn": "%s",
                      "tags": ["清淡"],
                      "version": 0
                    }
                    """.formatted(
                        fridge.zoneId(),
                        fridge.containerId(),
                        daysFromToday(-2),
                        daysFromToday(4)
                    )))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.category").value("蔬菜"))
            .andExpect(jsonPath("$.data.unit").value("颗"))
            .andExpect(jsonPath("$.data.version").value(1));

        mockMvc.perform(get("/api/v1/foods/" + foodId)
                .header("X-User-Id", "485")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.category").value("蔬菜"));
    }

    @Test
    void rejectsStaleVersionWhenEditing() throws Exception {
        FridgeFixture fridge = createFridge(964, "486");
        long foodId = addFood(fridge, "待改分类苹果", "水果", 2.0, daysFromToday(6), "486");

        mockMvc.perform(put("/api/v1/foods/" + foodId)
                .header("X-User-Id", "486")
                .header("Authorization", "Bearer editor-token")
                .contentType("application/json")
                .content("""
                    {
                      "zoneId": %d,
                      "containerId": %d,
                      "name": "待改分类苹果",
                      "category": "蔬菜",
                      "quantity": 2,
                      "unit": "个",
                      "productionDate": "%s",
                      "expiresOn": "%s",
                      "version": 7
                    }
                    """.formatted(
                        fridge.zoneId(),
                        fridge.containerId(),
                        daysFromToday(-1),
                        daysFromToday(6)
                    )))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.code").value("CONFLICT"));
    }

    private ResultActions discardExpired(long fridgeId, String userId) throws Exception {
        return mockMvc.perform(post("/api/v1/fridges/" + fridgeId + "/discard-expired")
            .header("X-User-Id", userId)
            .header("Authorization", "Bearer editor-token"));
    }

    private String daysFromToday(int offset) {
        return LocalDate.now(FRIDGE_ZONE).plusDays(offset).toString();
    }

    private long addFood(
        FridgeFixture fridge,
        String name,
        String category,
        double quantity,
        String expiresOn,
        String userId
    ) throws Exception {
        currentFamilyRole = "EDITOR";
        String body = mockMvc.perform(post("/api/v1/foods")
                .header("X-User-Id", userId)
                .header("Authorization", "Bearer editor-token")
                .contentType("application/json")
                .content("""
                    {
                      "fridgeId": %d,
                      "zoneId": %d,
                      "containerId": %d,
                      "name": "%s",
                      "category": "%s",
                      "quantity": %s,
                      "unit": "份",
                      "productionDate": "%s",
                      "expiresOn": "%s"
                    }
                    """.formatted(
                        fridge.fridgeId(),
                        fridge.zoneId(),
                        fridge.containerId(),
                        name,
                        category,
                        quantity,
                        LocalDate.now(FRIDGE_ZONE).minusDays(10),
                        expiresOn
                    )))
            .andExpect(status().isCreated())
            .andReturn().getResponse().getContentAsString();
        return ((Number) JsonPath.read(body, "$.data.id")).longValue();
    }

    private FridgeFixture createFridge(long familyId, String ownerUserId) throws Exception {
        currentFamilyRole = "OWNER";
        String body = mockMvc.perform(post("/api/v1/fridges")
                .header("X-User-Id", ownerUserId)
                .header("Authorization", "Bearer owner-token")
                .contentType("application/json")
                .content("""
                    {"familyId": %d, "name": "过期清理测试冰箱"}
                    """.formatted(familyId)))
            .andExpect(status().isCreated())
            .andReturn().getResponse().getContentAsString();
        return new FridgeFixture(
            ((Number) JsonPath.read(body, "$.data.id")).longValue(),
            ((Number) JsonPath.read(body, "$.data.zones[0].id")).longValue(),
            ((Number) JsonPath.read(body, "$.data.zones[0].containers[0].id")).longValue()
        );
    }

    private static HttpServer startAuthServer() {
        try {
            HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
            server.createContext("/api/v1/families/", exchange -> {
                String body = """
                    {
                      "code": "OK",
                      "message": "success",
                      "data": {
                        "id": 960,
                        "name": "过期清理家庭",
                        "inviteCode": "EXPD1234",
                        "ownerUserId": 480,
                        "currentUserRole": "%s",
                        "createdAt": "2026-11-01T00:00:00Z"
                      },
                      "traceId": "auth-test"
                    }
                    """.formatted(currentFamilyRole);
                byte[] response = body.getBytes(StandardCharsets.UTF_8);
                exchange.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
                exchange.sendResponseHeaders(200, response.length);
                exchange.getResponseBody().write(response);
                exchange.close();
            });
            server.start();
            return server;
        } catch (IOException exception) {
            throw new IllegalStateException("Unable to start auth test server", exception);
        }
    }

    private record FridgeFixture(long fridgeId, long zoneId, long containerId) {
    }
}

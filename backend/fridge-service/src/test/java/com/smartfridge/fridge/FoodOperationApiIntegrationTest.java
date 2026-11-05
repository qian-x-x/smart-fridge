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

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.ZoneId;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class FoodOperationApiIntegrationTest {

    private static final HttpServer AUTH_SERVER = startAuthServer();
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
    void listsTimelineNewestFirstAndMarksOnlyRevertibleActions() throws Exception {
        FridgeFixture fridge = createFridge(900, "401");
        long foodId = addFood(fridge, "时间线牛奶", 4.0, "402");
        consume(foodId, 1.5, 0, "402").andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/fridges/" + fridge.fridgeId() + "/operations")
                .header("X-User-Id", "403")
                .header("Authorization", "Bearer viewer-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data[0].action").value("CONSUME"))
            .andExpect(jsonPath("$.data[0].foodName").value("时间线牛奶"))
            .andExpect(jsonPath("$.data[0].oldQuantity").value(4.0))
            .andExpect(jsonPath("$.data[0].newQuantity").value(2.5))
            .andExpect(jsonPath("$.data[0].undoable").value(true))
            .andExpect(jsonPath("$.data[0].undone").value(false))
            .andExpect(jsonPath("$.data[1].action").value("ADD"))
            .andExpect(jsonPath("$.data[1].undoable").value(false));
    }

    @Test
    void undoConsumeRestoresQuantityAndCreatesUndoRecord() throws Exception {
        FridgeFixture fridge = createFridge(901, "411");
        long foodId = addFood(fridge, "可撤销酸奶", 4.0, "412");
        long operationId = latestOperationIdAfterConsume(fridge, foodId, 2.0, "412");

        mockMvc.perform(post("/api/v1/foods/" + foodId + "/operations/" + operationId + "/undo")
                .header("X-User-Id", "412")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.quantity").value(4.0))
            .andExpect(jsonPath("$.data.name").value("可撤销酸奶"));

        mockMvc.perform(get("/api/v1/foods/" + foodId)
                .header("X-User-Id", "412")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.quantity").value(4.0));

        mockMvc.perform(get("/api/v1/fridges/" + fridge.fridgeId() + "/operations")
                .header("X-User-Id", "412")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data[0].action").value("UNDO"))
            .andExpect(jsonPath("$.data[0].originalOperationId").value(operationId))
            .andExpect(jsonPath("$.data[1].undone").value(true))
            .andExpect(jsonPath("$.data[1].undoable").value(false))
            .andExpect(jsonPath("$.data[1].revertedByOperationId").isNumber());
    }

    @Test
    void undoTwiceReturnsConflictAndRestoreReappliesTheDeduction() throws Exception {
        FridgeFixture fridge = createFridge(902, "421");
        long foodId = addFood(fridge, "可恢复鸡蛋", 6.0, "422");
        long operationId = latestOperationIdAfterConsume(fridge, foodId, 2.0, "422");

        mockMvc.perform(post("/api/v1/foods/" + foodId + "/operations/" + operationId + "/undo")
                .header("X-User-Id", "422")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/foods/" + foodId + "/operations/" + operationId + "/undo")
                .header("X-User-Id", "422")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.code").value("CONFLICT"));

        mockMvc.perform(post("/api/v1/foods/" + foodId + "/operations/" + operationId + "/restore")
                .header("X-User-Id", "422")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.quantity").value(4.0));

        mockMvc.perform(post("/api/v1/foods/" + foodId + "/operations/" + operationId + "/restore")
                .header("X-User-Id", "422")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isConflict());
    }

    @Test
    void undoDiscardBringsTheFoodBackToTheActiveList() throws Exception {
        FridgeFixture fridge = createFridge(903, "431");
        long foodId = addFood(fridge, "被丢弃的生菜", 3.0, "432");
        String food = mockMvc.perform(get("/api/v1/foods/" + foodId)
                .header("X-User-Id", "432")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();
        int version = JsonPath.read(food, "$.data.version");

        mockMvc.perform(delete("/api/v1/foods/" + foodId)
                .param("version", String.valueOf(version))
                .header("X-User-Id", "432")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/foods/" + foodId)
                .header("X-User-Id", "432")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isNotFound());

        long discardOperationId = latestOperationId(fridge.fridgeId(), "DISCARD");
        mockMvc.perform(post("/api/v1/foods/" + foodId + "/operations/" + discardOperationId + "/undo")
                .header("X-User-Id", "432")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.quantity").value(3.0));

        mockMvc.perform(get("/api/v1/foods/" + foodId)
                .header("X-User-Id", "432")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.quantity").value(3.0));
    }

    @Test
    void undoMoveRestoresThePreviousZone() throws Exception {
        FridgeFixture fridge = createFridge(904, "441");
        long foodId = addFood(fridge, "需要挪回去的番茄", 2.0, "442");

        mockMvc.perform(post("/api/v1/foods/" + foodId + "/move")
                .header("X-User-Id", "442")
                .header("Authorization", "Bearer editor-token")
                .contentType("application/json")
                .content("""
                    {"zoneId": %d, "containerId": %d, "version": 0}
                    """.formatted(fridge.variableZoneId(), fridge.variableContainerId())))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.zoneId").value((int) fridge.variableZoneId()));

        long moveOperationId = latestOperationId(fridge.fridgeId(), "MOVE");
        mockMvc.perform(post("/api/v1/foods/" + foodId + "/operations/" + moveOperationId + "/undo")
                .header("X-User-Id", "442")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.zoneId").value((int) fridge.zoneId()))
            .andExpect(jsonPath("$.data.containerId").value((int) fridge.containerId()));
    }

    @Test
    void rejectsUndoForAddRecordsUnknownOperationsAndStaleVersions() throws Exception {
        FridgeFixture fridge = createFridge(905, "451");
        long foodId = addFood(fridge, "规则校验牛奶", 2.0, "452");
        long addOperationId = latestOperationId(fridge.fridgeId(), "ADD");

        mockMvc.perform(post("/api/v1/foods/" + foodId + "/operations/" + addOperationId + "/undo")
                .header("X-User-Id", "452")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.code").value("CONFLICT"));

        mockMvc.perform(post("/api/v1/foods/" + foodId + "/operations/999999/undo")
                .header("X-User-Id", "452")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isNotFound());

        long consumeOperationId = latestOperationIdAfterConsume(fridge, foodId, 0.5, "452");
        mockMvc.perform(post("/api/v1/foods/" + foodId + "/operations/" + consumeOperationId + "/undo")
                .param("version", "999")
                .header("X-User-Id", "452")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isConflict());
    }

    @Test
    void viewerCannotUndoButCanReadTheTimeline() throws Exception {
        FridgeFixture fridge = createFridge(906, "461");
        long foodId = addFood(fridge, "只读时间线牛奶", 3.0, "462");
        long operationId = latestOperationIdAfterConsume(fridge, foodId, 1.0, "462");

        currentFamilyRole = "VIEWER";
        mockMvc.perform(post("/api/v1/foods/" + foodId + "/operations/" + operationId + "/undo")
                .header("X-User-Id", "463")
                .header("Authorization", "Bearer viewer-token"))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.code").value("FORBIDDEN"));

        mockMvc.perform(get("/api/v1/fridges/" + fridge.fridgeId() + "/operations")
                .header("X-User-Id", "463")
                .header("Authorization", "Bearer viewer-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data[0].action").value("CONSUME"));
    }

    @Test
    void timelineFiltersByFoodAndRejectsUnknownFridge() throws Exception {
        FridgeFixture fridge = createFridge(907, "471");
        long milkId = addFood(fridge, "筛选牛奶", 2.0, "472");
        long eggId = addFood(fridge, "筛选鸡蛋", 2.0, "472");

        mockMvc.perform(get("/api/v1/fridges/" + fridge.fridgeId() + "/operations")
                .param("foodId", String.valueOf(milkId))
                .param("limit", "10")
                .header("X-User-Id", "472")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.length()").value(1))
            .andExpect(jsonPath("$.data[0].foodItemId").value((int) milkId))
            .andExpect(jsonPath("$.data[0].foodName").value("筛选牛奶"));

        mockMvc.perform(get("/api/v1/fridges/" + fridge.fridgeId() + "/operations")
                .param("foodId", String.valueOf(eggId))
                .header("X-User-Id", "472")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data[0].foodItemId").value((int) eggId));

        mockMvc.perform(get("/api/v1/fridges/999999/operations")
                .header("X-User-Id", "472")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isNotFound());
    }

    @Test
    void rejectsUndoWithoutGatewayIdentity() throws Exception {
        mockMvc.perform(post("/api/v1/foods/1/operations/1/undo"))
            .andExpect(status().isUnauthorized());
    }

    private long latestOperationIdAfterConsume(
        FridgeFixture fridge,
        long foodId,
        double quantity,
        String userId
    ) throws Exception {
        int version = currentVersion(foodId, userId);
        consume(foodId, quantity, version, userId).andExpect(status().isOk());
        return latestOperationId(fridge.fridgeId(), "CONSUME");
    }

    private org.springframework.test.web.servlet.ResultActions consume(
        long foodId,
        double quantity,
        int version,
        String userId
    ) throws Exception {
        currentFamilyRole = "EDITOR";
        return mockMvc.perform(post("/api/v1/foods/" + foodId + "/consume")
            .header("X-User-Id", userId)
            .header("Authorization", "Bearer editor-token")
            .contentType("application/json")
            .content("""
                {"quantity": %s, "version": %d}
                """.formatted(quantity, version)));
    }

    private int currentVersion(long foodId, String userId) throws Exception {
        String body = mockMvc.perform(get("/api/v1/foods/" + foodId)
                .header("X-User-Id", userId)
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.data.version");
    }

    private long latestOperationId(long fridgeId, String action) {
        Long id = jdbcTemplate.queryForObject(
            "SELECT MAX(id) FROM food_operation WHERE fridge_id = ? AND action = ?",
            Long.class,
            fridgeId,
            action
        );
        if (id == null) {
            throw new IllegalStateException("No operation recorded for " + action);
        }
        return id;
    }

    private long addFood(FridgeFixture fridge, String name, double quantity, String userId)
        throws Exception {
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
                      "category": "奶制品",
                      "quantity": %s,
                      "unit": "盒",
                      "productionDate": "2026-10-20",
                      "expiresOn": "%s",
                      "tags": ["早餐"],
                      "modelKey": "milk"
                    }
                    """.formatted(
                        fridge.fridgeId(),
                        fridge.zoneId(),
                        fridge.containerId(),
                        name,
                        quantity,
                        LocalDate.now(ZoneId.of("Asia/Shanghai")).plusDays(5)
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
                    {"familyId": %d, "name": "时间线测试冰箱"}
                    """.formatted(familyId)))
            .andExpect(status().isCreated())
            .andReturn().getResponse().getContentAsString();
        return new FridgeFixture(
            ((Number) JsonPath.read(body, "$.data.id")).longValue(),
            ((Number) JsonPath.read(body, "$.data.zones[0].id")).longValue(),
            ((Number) JsonPath.read(body, "$.data.zones[0].containers[0].id")).longValue(),
            ((Number) JsonPath.read(body, "$.data.zones[1].id")).longValue(),
            ((Number) JsonPath.read(body, "$.data.zones[1].containers[0].id")).longValue()
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
                        "id": 900,
                        "name": "时间线家庭",
                        "inviteCode": "TMLN1234",
                        "ownerUserId": 401,
                        "currentUserRole": "%s",
                        "createdAt": "2026-10-26T00:00:00Z"
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

    private record FridgeFixture(
        long fridgeId,
        long zoneId,
        long containerId,
        long variableZoneId,
        long variableContainerId
    ) {
    }
}

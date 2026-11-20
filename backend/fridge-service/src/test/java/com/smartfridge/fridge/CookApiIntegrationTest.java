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

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class CookApiIntegrationTest {

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
    void confirmsCookingAndDeductsEachItemInOneTransaction() throws Exception {
        FridgeFixture fridge = createFridge(950, "601");
        long tomatoId = addFood(fridge, "番茄", 4.0, "602");
        long eggId = addFood(fridge, "鸡蛋", 6.0, "602");

        String body = cook(fridge, "cook-confirm-0001", 1, "番茄滑蛋",
            """
                [{"foodItemId": %d, "quantity": 2, "version": 0},
                 {"foodItemId": %d, "quantity": 3, "version": 0}]
                """.formatted(tomatoId, eggId), "602")
            .andExpect(status().isCreated())
            .andExpect(header().exists("Location"))
            .andExpect(jsonPath("$.data.recipeName").value("番茄滑蛋"))
            .andExpect(jsonPath("$.data.servings").value(2))
            .andExpect(jsonPath("$.data.items.length()").value(2))
            .andExpect(jsonPath("$.data.items[0].foodName").value("番茄"))
            .andExpect(jsonPath("$.data.items[0].quantity").value(2.0))
            .andReturn().getResponse().getContentAsString();
        Number cookRecordId = JsonPath.read(body, "$.data.id");

        assertEquals(2.0, quantityOf(tomatoId));
        assertEquals(3.0, quantityOf(eggId));

        mockMvc.perform(get("/api/v1/foods/" + tomatoId)
                .header("X-User-Id", "602")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.quantity").value(2.0));

        Integer cookOperations = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM food_operation WHERE fridge_id = ? AND action = 'COOK'",
            Integer.class,
            fridge.fridgeId()
        );
        assertEquals(2, cookOperations);

        mockMvc.perform(get("/api/v1/fridges/" + fridge.fridgeId() + "/operations")
                .header("X-User-Id", "602")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data[0].action").value("COOK"))
            .andExpect(jsonPath("$.data[0].note").value("做饭：番茄滑蛋"))
            .andExpect(jsonPath("$.data[0].undoable").value(true));

        mockMvc.perform(get("/api/v1/fridges/" + fridge.fridgeId() + "/cook-records")
                .header("X-User-Id", "603")
                .header("Authorization", "Bearer viewer-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.length()").value(1))
            .andExpect(jsonPath("$.data[0].id").value(cookRecordId.intValue()))
            .andExpect(jsonPath("$.data[0].items.length()").value(2));
    }

    @Test
    void replaysTheSameRequestIdWithoutDeductingTwice() throws Exception {
        FridgeFixture fridge = createFridge(951, "611");
        long milkId = addFood(fridge, "做饭牛奶", 5.0, "612");
        String items = """
            [{"foodItemId": %d, "quantity": 2, "version": 0}]
            """.formatted(milkId);

        String first = cook(fridge, "cook-replay-0001", 1, "牛奶燕麦", items, "612")
            .andExpect(status().isCreated())
            .andReturn().getResponse().getContentAsString();
        Number firstId = JsonPath.read(first, "$.data.id");
        assertEquals(3.0, quantityOf(milkId));

        String second = cook(fridge, "cook-replay-0001", 1, "牛奶燕麦", items, "612")
            .andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();
        Number secondId = JsonPath.read(second, "$.data.id");

        assertEquals(firstId.longValue(), secondId.longValue());
        cook(fridge, "cook-replay-0001", 1, "牛奶燕麦", items, "613")
            .andExpect(status().isConflict());
        cook(fridge, "cook-replay-0001", 1, "牛奶燕麦", items.replace("quantity\": 2", "quantity\": 1"), "612")
            .andExpect(status().isConflict());
        assertEquals(3.0, quantityOf(milkId));

        Integer records = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM cook_record WHERE fridge_id = ?",
            Integer.class,
            fridge.fridgeId()
        );
        assertEquals(1, records);
    }

    @Test
    void freshPortionStockUsesOnePortionPerDishAndRollsBackAnExpiredBatch() throws Exception {
        FridgeFixture fridge = createFridge(957, "671");
        long pumpkin = addFood(fridge, "南瓜", 2, "672");
        long other = addFood(fridge, "南瓜", 2, "672");
        jdbcTemplate.update("UPDATE food_item SET model_key = 'sticker:南瓜' WHERE id IN (?, ?)", pumpkin, other);
        String item = """
            [{"foodItemId": %d, "quantity": %s, "version": 0}]
            """;
        cook(fridge, "cook-portions-0001", 18, "清蒸南瓜", item.formatted(pumpkin, "0.5"), "672")
            .andExpect(status().isBadRequest());
        cook(fridge, "cook-portions-0001", 18, "清蒸南瓜", item.formatted(pumpkin, "2"), "672")
            .andExpect(status().isBadRequest());
        cook(fridge, "cook-portions-0001", 18, "清蒸南瓜",
            """
                [{"foodItemId": %d, "quantity": 1}, {"foodItemId": %d, "quantity": 1}]
                """.formatted(pumpkin, other), "672")
            .andExpect(status().isBadRequest());

        jdbcTemplate.update("UPDATE food_item SET expires_on = '2025-10-26' WHERE id = ?", pumpkin);
        cook(fridge, "cook-portions-0001", 18, "清蒸南瓜", item.formatted(pumpkin, "1"), "672")
            .andExpect(status().isConflict());
        assertEquals(2.0, quantityOf(pumpkin));
        cook(fridge, "cook-portions-0001", 18, "清蒸南瓜", item.formatted(other, "1"), "672")
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.data.items[0].unit").value("份"));
        assertEquals(1.0, quantityOf(other));
    }

    @Test
    void concurrentReplaysOfTheLastPortionReturnOneRecord() throws Exception {
        FridgeFixture fridge = createFridge(958, "681");
        long pumpkin = addFood(fridge, "并发南瓜", 1, "682");
        jdbcTemplate.update("UPDATE food_item SET model_key = 'sticker:并发南瓜' WHERE id = ?", pumpkin);
        var executor = java.util.concurrent.Executors.newFixedThreadPool(2);
        var start = new java.util.concurrent.CyclicBarrier(2);
        java.util.concurrent.Callable<Integer> submit = () -> {
            start.await(10, java.util.concurrent.TimeUnit.SECONDS);
            return cook(fridge, "cook-portions-race", 18, "清蒸南瓜",
                "[{\"foodItemId\":" + pumpkin + ",\"quantity\":1,\"version\":0}]", "682")
                .andReturn().getResponse().getStatus();
        };
        try {
            var first = executor.submit(submit);
            var second = executor.submit(submit);
            assertEquals(java.util.Set.of(200, 201), java.util.Set.of(
                first.get(12, java.util.concurrent.TimeUnit.SECONDS),
                second.get(12, java.util.concurrent.TimeUnit.SECONDS)));
            assertEquals(0.0, quantityOf(pumpkin));
        } finally {
            executor.shutdownNow();
        }
    }

    @Test
    void rejectsTheWholeBatchWhenAnyItemIsShortAndWritesNothing() throws Exception {
        FridgeFixture fridge = createFridge(952, "621");
        long tomatoId = addFood(fridge, "批量番茄", 4.0, "622");
        long eggId = addFood(fridge, "批量鸡蛋", 1.0, "622");

        cook(fridge, "cook-short-0001", 1, "番茄滑蛋",
            """
                [{"foodItemId": %d, "quantity": 1},
                 {"foodItemId": %d, "quantity": 9}]
                """.formatted(tomatoId, eggId), "622")
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.code").value("CONFLICT"));

        assertEquals(4.0, quantityOf(tomatoId));
        assertEquals(1.0, quantityOf(eggId));

        Integer records = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM cook_record WHERE fridge_id = ?",
            Integer.class,
            fridge.fridgeId()
        );
        assertEquals(0, records);
        Integer cookOperations = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM food_operation WHERE fridge_id = ? AND action = 'COOK'",
            Integer.class,
            fridge.fridgeId()
        );
        assertEquals(0, cookOperations);
    }

    @Test
    void rejectsStaleVersionAndForeignFood() throws Exception {
        FridgeFixture fridge = createFridge(953, "631");
        FridgeFixture otherFridge = createFridge(954, "631");
        long milkId = addFood(fridge, "版本牛奶", 3.0, "632");
        long foreignFoodId = addFood(otherFridge, "别人家的牛奶", 3.0, "632");

        cook(fridge, "cook-stale-0001", 1, "牛奶燕麦",
            """
                [{"foodItemId": %d, "quantity": 1, "version": 7}]
                """.formatted(milkId), "632")
            .andExpect(status().isConflict());

        cook(fridge, "cook-foreign-0001", 1, "牛奶燕麦",
            """
                [{"foodItemId": %d, "quantity": 1}]
                """.formatted(foreignFoodId), "632")
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.code").value("NOT_FOUND"));

        assertEquals(3.0, quantityOf(milkId));
        assertEquals(3.0, quantityOf(foreignFoodId));
    }

    @Test
    void rejectsDuplicateItemsAndInvalidRequestId() throws Exception {
        FridgeFixture fridge = createFridge(955, "641");
        long milkId = addFood(fridge, "重复牛奶", 4.0, "642");

        cook(fridge, "cook-dup-0001", 1, "牛奶燕麦",
            """
                [{"foodItemId": %d, "quantity": 1}, {"foodItemId": %d, "quantity": 1}]
                """.formatted(milkId, milkId), "642")
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        cook(fridge, "short", 1, "牛奶燕麦",
            """
                [{"foodItemId": %d, "quantity": 1}]
                """.formatted(milkId), "642")
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        assertEquals(4.0, quantityOf(milkId));
    }

    @Test
    void viewerCannotConfirmCooking() throws Exception {
        FridgeFixture fridge = createFridge(956, "651");
        long milkId = addFood(fridge, "只读牛奶", 2.0, "652");

        currentFamilyRole = "VIEWER";
        mockMvc.perform(post("/api/v1/fridges/" + fridge.fridgeId() + "/cook-records")
                .header("X-User-Id", "653")
                .header("Authorization", "Bearer viewer-token")
                .contentType("application/json")
                .content("""
                    {
                      "recipeId": 1,
                      "recipeName": "牛奶燕麦",
                      "servings": 2,
                      "requestId": "cook-viewer-0001",
                      "items": [{"foodItemId": %d, "quantity": 1}]
                    }
                    """.formatted(milkId)))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.code").value("FORBIDDEN"));
        assertEquals(2.0, quantityOf(milkId));
    }

    @Test
    void rejectsCookingWithoutGatewayIdentity() throws Exception {
        mockMvc.perform(post("/api/v1/fridges/1/cook-records")
                .contentType("application/json")
                .content("{}"))
            .andExpect(status().isUnauthorized());
    }

    private org.springframework.test.web.servlet.ResultActions cook(
        FridgeFixture fridge,
        String requestId,
        long recipeId,
        String recipeName,
        String items,
        String userId
    ) throws Exception {
        currentFamilyRole = "EDITOR";
        return mockMvc.perform(post("/api/v1/fridges/" + fridge.fridgeId() + "/cook-records")
            .header("X-User-Id", userId)
            .header("Authorization", "Bearer editor-token")
            .contentType("application/json")
            .content("""
                {
                  "recipeId": %d,
                  "recipeName": "%s",
                  "servings": 2,
                  "requestId": "%s",
                  "note": "晚餐",
                  "items": %s
                }
                """.formatted(recipeId, recipeName, requestId, items)));
    }

    private double quantityOf(long foodId) {
        return jdbcTemplate.queryForObject(
            "SELECT quantity FROM food_item WHERE id = ?",
            java.math.BigDecimal.class,
            foodId
        ).doubleValue();
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
                      "category": "蔬菜",
                      "quantity": %s,
                      "unit": "份",
                      "productionDate": "2026-10-20",
                      "expiresOn": "%s",
                      "tags": []
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
                    {"familyId": %d, "name": "做饭测试冰箱"}
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
                        "id": 950,
                        "name": "做饭家庭",
                        "inviteCode": "COOK1234",
                        "ownerUserId": 601,
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

    private record FridgeFixture(long fridgeId, long zoneId, long containerId) {
    }
}

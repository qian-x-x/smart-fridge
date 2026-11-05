package com.smartfridge.fridge;

import com.sun.net.httpserver.HttpServer;
import com.jayway.jsonpath.JsonPath;
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

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class FridgeApiIntegrationTest {

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
    void rejectsRequestsWithoutGatewayUserIdentity() throws Exception {
        mockMvc.perform(post("/api/v1/fridges")
                .contentType("application/json")
                .content("{}"))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    void createsFridgeWithDefaultZonesForOwner() throws Exception {
        currentFamilyRole = "OWNER";

        mockMvc.perform(post("/api/v1/fridges")
                .header("X-User-Id", "7")
                .header("X-User-Name", "owner")
                .header("Authorization", "Bearer owner-token")
                .contentType("application/json")
                .content("""
                    {
                      "familyId": 42,
                      "name": "主冰箱"
                    }
                    """))
            .andExpect(status().isCreated())
            .andExpect(header().exists("Location"))
            .andExpect(jsonPath("$.code").value("OK"))
            .andExpect(jsonPath("$.data.familyId").value(42))
            .andExpect(jsonPath("$.data.name").value("主冰箱"))
            .andExpect(jsonPath("$.data.zones.length()").value(4))
            .andExpect(jsonPath("$.data.zones[0].code").value("FRESH"))
            .andExpect(jsonPath("$.data.zones[0].containers.length()").value(2));
    }

    @Test
    void rejectsFridgeCreationByViewer() throws Exception {
        currentFamilyRole = "VIEWER";

        mockMvc.perform(post("/api/v1/fridges")
                .header("X-User-Id", "9")
                .header("X-User-Name", "viewer")
                .header("Authorization", "Bearer viewer-token")
                .contentType("application/json")
                .content("""
                    {
                      "familyId": 43,
                      "name": "只读家庭的冰箱"
                    }
                    """))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    void allowsFamilyViewerToReadFridge() throws Exception {
        long familyId = 44;
        currentFamilyRole = "OWNER";
        String created = mockMvc.perform(post("/api/v1/fridges")
                .header("X-User-Id", "11")
                .header("Authorization", "Bearer owner-token")
                .contentType("application/json")
                .content("""
                    {
                      "familyId": %d,
                      "name": "共享冰箱"
                    }
                    """.formatted(familyId)))
            .andExpect(status().isCreated())
            .andReturn()
            .getResponse()
            .getContentAsString();
        Number fridgeId = JsonPath.read(created, "$.data.id");

        currentFamilyRole = "VIEWER";
        mockMvc.perform(get("/api/v1/fridges/" + fridgeId)
                .header("X-User-Id", "12")
                .header("Authorization", "Bearer viewer-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.familyId").value(familyId))
            .andExpect(jsonPath("$.data.zones.length()").value(4));
    }

    @Test
    void editorAddsFoodAndOperationIsRecorded() throws Exception {
        long familyId = 45;
        currentFamilyRole = "OWNER";
        String fridgeJson = mockMvc.perform(post("/api/v1/fridges")
                .header("X-User-Id", "21")
                .header("Authorization", "Bearer owner-token")
                .contentType("application/json")
                .content("""
                    {
                      "familyId": %d,
                      "name": "食材测试冰箱"
                    }
                    """.formatted(familyId)))
            .andExpect(status().isCreated())
            .andReturn()
            .getResponse()
            .getContentAsString();
        Number fridgeId = JsonPath.read(fridgeJson, "$.data.id");
        Number zoneId = JsonPath.read(fridgeJson, "$.data.zones[0].id");
        Number containerId = JsonPath.read(fridgeJson, "$.data.zones[0].containers[0].id");
        String expiresOn = LocalDate.now(ZoneId.of("Asia/Shanghai")).plusDays(2).toString();

        currentFamilyRole = "EDITOR";
        String createdFood = mockMvc.perform(post("/api/v1/foods")
                .header("X-User-Id", "22")
                .header("X-User-Name", "editor")
                .header("Authorization", "Bearer editor-token")
                .contentType("application/json")
                .content("""
                    {
                      "fridgeId": %d,
                      "zoneId": %d,
                      "containerId": %d,
                      "name": "番茄",
                      "category": "蔬菜",
                      "quantity": 4,
                      "unit": "个",
                      "productionDate": "2026-10-20",
                      "expiresOn": "%s",
                      "tags": ["早餐", "火锅"],
                      "modelKey": "tomato"
                    }
                    """.formatted(fridgeId, zoneId, containerId, expiresOn)))
            .andExpect(status().isCreated())
            .andExpect(header().exists("Location"))
            .andExpect(jsonPath("$.data.name").value("番茄"))
            .andExpect(jsonPath("$.data.quantity").value(4.0))
            .andExpect(jsonPath("$.data.remainingDays").value(2))
            .andExpect(jsonPath("$.data.expiring").value(true))
            .andExpect(jsonPath("$.data.tags[0]").value("早餐"))
            .andExpect(jsonPath("$.data.createdBy").value(22))
            .andReturn()
            .getResponse()
            .getContentAsString();
        Number foodId = JsonPath.read(createdFood, "$.data.id");

        Integer operationCount = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM food_operation WHERE food_item_id = ? AND action = 'ADD'",
            Integer.class,
            foodId.longValue()
        );
        org.junit.jupiter.api.Assertions.assertEquals(1, operationCount);
    }

    @Test
    void rejectsFoodCreationByViewer() throws Exception {
        FridgeFixture fridge = createFridge(46, "30");
        currentFamilyRole = "VIEWER";

        mockMvc.perform(post("/api/v1/foods")
                .header("X-User-Id", "31")
                .header("Authorization", "Bearer viewer-token")
                .contentType("application/json")
                .content(foodJson(fridge, "牛奶", 1)))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    void viewerReadsFoodDetail() throws Exception {
        FridgeFixture fridge = createFridge(47, "40");
        String food = addFood(fridge, "酸奶", 2, "41");
        Number foodId = JsonPath.read(food, "$.data.id");

        currentFamilyRole = "VIEWER";
        mockMvc.perform(get("/api/v1/foods/" + foodId)
                .header("X-User-Id", "42")
                .header("Authorization", "Bearer viewer-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.name").value("酸奶"))
            .andExpect(jsonPath("$.data.quantity").value(2.0));
    }

    @Test
    void searchesFoodByNameForFamilyViewer() throws Exception {
        FridgeFixture fridge = createFridge(48, "50");
        addFood(fridge, "牛奶", 1, "51");
        addFood(fridge, "番茄", 4, "51");

        currentFamilyRole = "VIEWER";
        mockMvc.perform(get("/api/v1/foods")
                .param("fridgeId", Long.toString(fridge.fridgeId()))
                .param("query", "牛奶")
                .header("X-User-Id", "52")
                .header("Authorization", "Bearer viewer-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.length()").value(1))
            .andExpect(jsonPath("$.data[0].name").value("牛奶"));
    }

    @Test
    void movesFoodAndRecordsPreviousAndNewLocation() throws Exception {
        FridgeFixture fridge = createFridge(49, "60");
        String food = addFood(fridge, "鸡胸肉", 2, "61");
        Number foodId = JsonPath.read(food, "$.data.id");

        mockMvc.perform(post("/api/v1/foods/" + foodId + "/move")
                .header("X-User-Id", "61")
                .header("Authorization", "Bearer editor-token")
                .contentType("application/json")
                .content("""
                    {
                      "zoneId": %d,
                      "containerId": %d,
                      "version": 0
                    }
                    """.formatted(fridge.variableZoneId(), fridge.variableContainerId())))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.zoneId").value(fridge.variableZoneId()))
            .andExpect(jsonPath("$.data.containerId").value(fridge.variableContainerId()))
            .andExpect(jsonPath("$.data.version").value(1));

        Integer operationCount = jdbcTemplate.queryForObject(
            """
                SELECT COUNT(*)
                FROM food_operation
                WHERE food_item_id = ?
                  AND action = 'MOVE'
                  AND old_zone_id = ?
                  AND new_zone_id = ?
                """,
            Integer.class,
            foodId.longValue(),
            fridge.zoneId(),
            fridge.variableZoneId()
        );
        org.junit.jupiter.api.Assertions.assertEquals(1, operationCount);
    }

    @Test
    void consumesFoodAndRecordsQuantityChange() throws Exception {
        FridgeFixture fridge = createFridge(50, "70");
        String food = addFood(fridge, "牛奶", 4, "71");
        Number foodId = JsonPath.read(food, "$.data.id");

        mockMvc.perform(post("/api/v1/foods/" + foodId + "/consume")
                .header("X-User-Id", "71")
                .header("Authorization", "Bearer editor-token")
                .contentType("application/json")
                .content("""
                    {
                      "quantity": 1.5,
                      "version": 0
                    }
                    """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.quantity").value(2.5))
            .andExpect(jsonPath("$.data.version").value(1));

        Integer operationCount = jdbcTemplate.queryForObject(
            """
                SELECT COUNT(*)
                FROM food_operation
                WHERE food_item_id = ?
                  AND action = 'CONSUME'
                  AND old_quantity = 4
                  AND new_quantity = 2.5
                """,
            Integer.class,
            foodId.longValue()
        );
        org.junit.jupiter.api.Assertions.assertEquals(1, operationCount);
    }

    @Test
    void rejectsConsumingMoreThanRemainingQuantity() throws Exception {
        FridgeFixture fridge = createFridge(51, "80");
        String food = addFood(fridge, "鸡蛋", 2, "81");
        Number foodId = JsonPath.read(food, "$.data.id");

        mockMvc.perform(post("/api/v1/foods/" + foodId + "/consume")
                .header("X-User-Id", "81")
                .header("Authorization", "Bearer editor-token")
                .contentType("application/json")
                .content("""
                    {
                      "quantity": 3,
                      "version": 0
                    }
                    """))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.code").value("CONFLICT"));

        Integer operationCount = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM food_operation WHERE food_item_id = ? AND action = 'CONSUME'",
            Integer.class,
            foodId.longValue()
        );
        org.junit.jupiter.api.Assertions.assertEquals(0, operationCount);
    }

    @Test
    void updatesFoodDetailsAndIncrementsVersion() throws Exception {
        FridgeFixture fridge = createFridge(52, "90");
        String food = addFood(fridge, "牛奶", 2, "91");
        Number foodId = JsonPath.read(food, "$.data.id");
        String expiresOn = LocalDate.now(ZoneId.of("Asia/Shanghai")).plusDays(8).toString();

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .put("/api/v1/foods/" + foodId)
                .header("X-User-Id", "91")
                .header("Authorization", "Bearer editor-token")
                .contentType("application/json")
                .content("""
                    {
                      "zoneId": %d,
                      "containerId": %d,
                      "name": "低脂牛奶",
                      "category": "蛋奶",
                      "quantity": 3,
                      "unit": "盒",
                      "productionDate": "2026-10-21",
                      "expiresOn": "%s",
                      "tags": ["早餐", "健身"],
                      "modelKey": "milk-low-fat",
                      "version": 0
                    }
                    """.formatted(fridge.zoneId(), fridge.containerId(), expiresOn)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.name").value("低脂牛奶"))
            .andExpect(jsonPath("$.data.quantity").value(3.0))
            .andExpect(jsonPath("$.data.version").value(1));

        Integer operationCount = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM food_operation WHERE food_item_id = ? AND action = 'UPDATE'",
            Integer.class,
            foodId.longValue()
        );
        org.junit.jupiter.api.Assertions.assertEquals(1, operationCount);
    }

    @Test
    void discardsFoodWithoutDeletingOperationHistory() throws Exception {
        FridgeFixture fridge = createFridge(53, "100");
        String food = addFood(fridge, "生菜", 1, "101");
        Number foodId = JsonPath.read(food, "$.data.id");

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .delete("/api/v1/foods/" + foodId)
                .param("version", "0")
                .header("X-User-Id", "101")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/foods/" + foodId)
                .header("X-User-Id", "101")
                .header("Authorization", "Bearer editor-token"))
            .andExpect(status().isNotFound());

        Integer operationCount = jdbcTemplate.queryForObject(
            """
                SELECT COUNT(*)
                FROM food_operation
                WHERE food_item_id = ?
                  AND action IN ('ADD', 'DISCARD')
                """,
            Integer.class,
            foodId.longValue()
        );
        org.junit.jupiter.api.Assertions.assertEquals(2, operationCount);
    }

    @Test
    void viewerFindsFridgeByFamily() throws Exception {
        FridgeFixture fridge = createFridge(54, "110");
        currentFamilyRole = "VIEWER";

        mockMvc.perform(get("/api/v1/fridges")
                .param("familyId", "54")
                .header("X-User-Id", "111")
                .header("Authorization", "Bearer viewer-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.id").value(fridge.fridgeId()))
            .andExpect(jsonPath("$.data.familyId").value(54))
            .andExpect(jsonPath("$.data.zones.length()").value(4));
    }

    @Test
    void combinesFoodFiltersWithAllTagsAndInclusiveDates() throws Exception {
        FridgeFixture fridge = createFridge(70, "7");
        long milk = seedSearchFood(fridge, "牛奶", 2, "早餐,高蛋白");
        seedSearchFood(fridge, "酸奶", 2, "早餐");
        seedSearchFood(fridge, "牛奶饮品", 5, "早餐,高蛋白");
        currentFamilyRole = "VIEWER";
        String day = LocalDate.now(ZoneId.of("Asia/Shanghai")).plusDays(2).toString();
        mockMvc.perform(searchRequest(fridge)
                .param("query", "奶").param("category", "蛋奶")
                .param("tags", "早餐", "高蛋白").param("zoneId", "" + fridge.zoneId())
                .param("expiryState", "EXPIRING").param("expiresFrom", day).param("expiresTo", day))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.length()").value(1))
            .andExpect(jsonPath("$.data[0].id").value(milk));
        mockMvc.perform(searchRequest(fridge).param("tags", "蛋白"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(0));
        mockMvc.perform(searchRequest(fridge).param("zoneId", "" + fridge.variableZoneId()))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(0));
    }

    @Test
    void expiryStatesPartitionTodayAndThreeDayBoundaryInFridgeTimezone() throws Exception {
        FridgeFixture fridge = createFridge(71, "7");
        // Use a zone with a different calendar day from Shanghai at this instant.
        String tz = LocalDate.now(ZoneId.of("Pacific/Kiritimati"))
            .equals(LocalDate.now(ZoneId.of("Asia/Shanghai"))) ? "Pacific/Honolulu" : "Pacific/Kiritimati";
        jdbcTemplate.update("UPDATE fridge SET timezone = ? WHERE id = ?", tz, fridge.fridgeId());
        LocalDate today = LocalDate.now(ZoneId.of(tz));
        for (int days : new int[]{-1, 0, 3, 4}) {
            long id = seedSearchFood(fridge, "边界" + days, 10, "");
            jdbcTemplate.update("UPDATE food_item SET expires_on = ? WHERE id = ?", java.sql.Date.valueOf(today.plusDays(days)), id);
        }
        mockMvc.perform(searchRequest(fridge).param("expiryState", "EXPIRED"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(1))
            .andExpect(jsonPath("$.data[0].remainingDays").value(-1));
        mockMvc.perform(searchRequest(fridge).param("expiryState", "EXPIRING"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(2))
            .andExpect(jsonPath("$.data[0].remainingDays").value(0))
            .andExpect(jsonPath("$.data[1].remainingDays").value(3));
        mockMvc.perform(searchRequest(fridge).param("expiryState", "FRESH"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(1))
            .andExpect(jsonPath("$.data[0].remainingDays").value(4));
    }

    @Test
    void searchEscapesWildcardsSortsStablyAndScopesActiveFoodsToFridge() throws Exception {
        FridgeFixture fridge = createFridge(72, "7");
        long literal = seedSearchFood(fridge, "A%_!牛奶", 2, "100%_!");
        long second = seedSearchFood(fridge, "B牛奶", 2, "100percent");
        seedSearchFood(fridge, "C牛奶", 5, "");
        long removed = seedSearchFood(fridge, "A%_!丢弃", 1, "100%_!");
        jdbcTemplate.update("UPDATE food_item SET status = 'DISCARDED' WHERE id = ?", removed);
        seedSearchFood(createFridge(73, "7"), "A%_!其他家庭", 2, "100%_!");
        mockMvc.perform(searchRequest(fridge).param("query", "%_!").param("tags", "100%_!"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(1))
            .andExpect(jsonPath("$.data[0].id").value(literal));
        mockMvc.perform(searchRequest(fridge).param("sort", "EXPIRES_ASC"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.length()").value(3))
            .andExpect(jsonPath("$.data[0].id").value(literal))
            .andExpect(jsonPath("$.data[1].id").value(second));
        mockMvc.perform(searchRequest(fridge).param("sort", "EXPIRES_DESC"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data[0].name").value("C牛奶"));
        mockMvc.perform(searchRequest(fridge).param("sort", "NAME_ASC"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data[0].id").value(literal));
        jdbcTemplate.update("UPDATE food_item SET created_at = '2030-01-01 00:00:00' WHERE id = ?", second);
        mockMvc.perform(searchRequest(fridge).param("sort", "CREATED_DESC"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data[0].id").value(second));
    }

    @Test
    void invalidFoodFiltersReturnValidationErrors() throws Exception {
        FridgeFixture fridge = createFridge(74, "7");
        for (String[] invalid : new String[][]{
            {"sort", "id desc;DROP TABLE food_item"}, {"expiryState", "UNKNOWN"},
            {"zoneId", "0"}, {"expiresFrom", "2026-02-30"}, {"query", "x".repeat(81)}, {"tags", " "}
        }) {
            mockMvc.perform(searchRequest(fridge).param(invalid[0], invalid[1]))
                .andExpect(status().isBadRequest());
        }
        mockMvc.perform(searchRequest(fridge).param("expiresFrom", "2026-11-02").param("expiresTo", "2026-11-01"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void malformedInputsReturnClientErrorsInsteadOfInternalFailures() throws Exception {
        for (String path : java.util.List.of("/api/v1/fridges", "/api/v1/fridges?familyId=abc", "/api/v1/foods/abc")) {
            mockMvc.perform(get(path).header("X-User-Id", "7").header("Authorization", "Bearer owner-token"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        }
        mockMvc.perform(post("/api/v1/foods").header("X-User-Id", "7")
                .header("Authorization", "Bearer owner-token").contentType("application/json").content("{"))
            .andExpect(status().isBadRequest());
        mockMvc.perform(get("/api/v1/foods/1/unknown").header("X-User-Id", "7")
                .header("Authorization", "Bearer owner-token"))
            .andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("NOT_FOUND"));
    }

    @Test
    void rejectsQuantityPrecisionAndStorageOverflowWithoutWriting() throws Exception {
        currentFamilyRole = "OWNER";
        FridgeFixture fridge = createFridge(801, "7");
        for (double quantity : new double[]{0.0001, 1.2345, 1000000000}) {
            mockMvc.perform(post("/api/v1/foods").header("X-User-Id", "7")
                    .header("Authorization", "Bearer owner-token").contentType("application/json")
                    .content(foodJson(fridge, "invalid precision", quantity)))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        }
        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM food_item WHERE fridge_id = ?",
            Integer.class, fridge.fridgeId());
        org.assertj.core.api.Assertions.assertThat(count).isZero();
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder searchRequest(FridgeFixture fridge) {
        return get("/api/v1/foods").param("fridgeId", "" + fridge.fridgeId())
            .header("X-User-Id", "7").header("Authorization", "Bearer search-token");
    }

    private long seedSearchFood(FridgeFixture fridge, String name, int days, String tags) throws Exception {
        long id = ((Number) JsonPath.read(addFood(fridge, name, 2, "7"), "$.data.id")).longValue();
        jdbcTemplate.update("UPDATE food_item SET expires_on = ?, tags = ? WHERE id = ?",
            java.sql.Date.valueOf(LocalDate.now(ZoneId.of("Asia/Shanghai")).plusDays(days)), tags, id);
        return id;
    }

    private String addFood(
        FridgeFixture fridge,
        String name,
        double quantity,
        String actorUserId
    ) throws Exception {
        currentFamilyRole = "EDITOR";
        return mockMvc.perform(post("/api/v1/foods")
                .header("X-User-Id", actorUserId)
                .header("Authorization", "Bearer editor-token")
                .contentType("application/json")
                .content(foodJson(fridge, name, quantity)))
            .andExpect(status().isCreated())
            .andReturn()
            .getResponse()
            .getContentAsString();
    }

    private FridgeFixture createFridge(long familyId, String ownerUserId) throws Exception {
        currentFamilyRole = "OWNER";
        String fridgeJson = mockMvc.perform(post("/api/v1/fridges")
                .header("X-User-Id", ownerUserId)
                .header("Authorization", "Bearer owner-token")
                .contentType("application/json")
                .content("""
                    {
                      "familyId": %d,
                      "name": "测试冰箱"
                    }
                    """.formatted(familyId)))
            .andExpect(status().isCreated())
            .andReturn()
            .getResponse()
            .getContentAsString();
        return new FridgeFixture(
            ((Number) JsonPath.read(fridgeJson, "$.data.id")).longValue(),
            ((Number) JsonPath.read(fridgeJson, "$.data.zones[0].id")).longValue(),
            ((Number) JsonPath.read(fridgeJson, "$.data.zones[0].containers[0].id")).longValue(),
            ((Number) JsonPath.read(fridgeJson, "$.data.zones[1].id")).longValue(),
            ((Number) JsonPath.read(fridgeJson, "$.data.zones[1].containers[0].id")).longValue()
        );
    }

    private String foodJson(FridgeFixture fridge, String name, double quantity) {
        String expiresOn = LocalDate.now(ZoneId.of("Asia/Shanghai")).plusDays(5).toString();
        return """
            {
              "fridgeId": %d,
              "zoneId": %d,
              "containerId": %d,
              "name": "%s",
              "category": "蛋奶",
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
                expiresOn
            );
    }

    private record FridgeFixture(
        long fridgeId,
        long zoneId,
        long containerId,
        long variableZoneId,
        long variableContainerId
    ) {
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
                        "id": 42,
                        "name": "测试家庭",
                        "inviteCode": "TEST1234",
                        "ownerUserId": 7,
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
}

# 小满冰箱运营后台

Vue 3 + TypeScript + Vite + Element Plus + ECharts 管理端。

## 启动

```powershell
npm install
npm run dev
```

开发地址为 `http://localhost:5173`。登录页可选择“直接进入演示后台”；运营管理员真实登录会在运营角色接口完成后切换。

## 配置

复制 `.env.example` 为 `.env.local`，按需覆盖：

```text
VITE_API_BASE_URL=http://localhost:8080
```

开发服务器默认把 `/api` 代理到 Gateway `localhost:8080`。

## 页面

- `/login`：运营登录与演示入口。
- `/dashboard`：关键指标、趋势图、订单状态和关注事项。
- `/recipes`：菜谱筛选、上下架状态与内容热度。
- `/products`：商品、SKU、安全库存和库存预警。
- `/orders`：补货订单、优惠券、金额和状态查询。

## 构建

```powershell
npm run build
```

当前页面使用明确标识的演示数据。接入业务后，应由 Gateway 提供运营角色鉴权，并将 API 模块拆分到 `src/api`。

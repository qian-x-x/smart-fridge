<script setup lang="ts">
import { ElMessage } from 'element-plus'
import { ref } from 'vue'

interface OrderRow {
  orderNo: string
  user: string
  items: number
  amount: number
  status: string
  createdAt: string
  coupon: string
}

const orders: OrderRow[] = [
  {
    orderNo: 'SF202610260017',
    user: '阿满的家',
    items: 4,
    amount: 56.7,
    status: '已支付',
    createdAt: '2026-10-26 08:24',
    coupon: '-¥8.00',
  },
  {
    orderNo: 'SF202610260016',
    user: '林小满',
    items: 2,
    amount: 26.8,
    status: '待支付',
    createdAt: '2026-10-26 08:12',
    coupon: '未使用',
  },
  {
    orderNo: 'SF202610260015',
    user: '何日安',
    items: 6,
    amount: 88.4,
    status: '配送中',
    createdAt: '2026-10-26 07:58',
    coupon: '-¥12.00',
  },
  {
    orderNo: 'SF202610260014',
    user: '周末食堂',
    items: 3,
    amount: 43.2,
    status: '已完成',
    createdAt: '2026-10-26 07:36',
    coupon: '-¥5.00',
  },
  {
    orderNo: 'SF202610260013',
    user: '阿成',
    items: 1,
    amount: 19.9,
    status: '已取消',
    createdAt: '2026-10-26 07:11',
    coupon: '未使用',
  },
]

const status = ref('全部状态')

function tone(value: string) {
  if (value === '已支付' || value === '已完成') return 'success'
  if (value === '待支付' || value === '配送中') return 'warning'
  return 'danger'
}

function openDetail(orderNo: string) {
  ElMessage.info(`${orderNo} 详情将在订单服务 API 接入后展开`)
}
</script>

<template>
  <div class="page-shell">
    <div class="page-heading">
      <div>
        <p class="page-kicker">TRANSACTION DESK</p>
        <h1 class="page-title">补货订单</h1>
        <p class="page-description">
          查询订单、优惠券和模拟支付状态。取消只允许发生在未支付或可取消状态。
        </p>
      </div>
      <el-button>导出订单</el-button>
    </div>

    <section class="order-metrics">
      <article>
        <span class="metric-icon coral">◫</span>
        <div>
          <small>今日订单</small>
          <strong>186</strong>
          <em>+8.6%</em>
        </div>
      </article>
      <article>
        <span class="metric-icon sage">✓</span>
        <div>
          <small>支付成功率</small>
          <strong>92.4%</strong>
          <em>+1.8%</em>
        </div>
      </article>
      <article>
        <span class="metric-icon amber">⌛</span>
        <div>
          <small>待处理</small>
          <strong>26</strong>
          <em class="neutral">需关注</em>
        </div>
      </article>
      <article>
        <span class="metric-icon cocoa">¥</span>
        <div>
          <small>客单价</small>
          <strong>¥ 56.8</strong>
          <em>+3.1%</em>
        </div>
      </article>
    </section>

    <section class="panel">
      <div class="filter-bar">
        <el-input
          clearable
          placeholder="搜索订单号或用户"
          class="search-input"
        >
          <template #prefix>⌕</template>
        </el-input>
        <el-select v-model="status" class="filter-select">
          <el-option
            v-for="item in [
              '全部状态',
              '待支付',
              '已支付',
              '配送中',
              '已完成',
              '已取消',
            ]"
            :key="item"
            :label="item"
            :value="item"
          />
        </el-select>
        <el-date-picker
          type="daterange"
          range-separator="至"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
        />
        <span class="result-count">最近更新于 09:48</span>
      </div>

      <el-table :data="orders" style="width: 100%">
        <el-table-column label="订单号" min-width="155">
          <template #default="{ row }">
            <button class="order-link" @click="openDetail(row.orderNo)">
              {{ row.orderNo }}
            </button>
          </template>
        </el-table-column>
        <el-table-column prop="user" label="用户 / 家庭" width="130" />
        <el-table-column label="商品" width="85">
          <template #default="{ row }">{{ row.items }} 件</template>
        </el-table-column>
        <el-table-column label="优惠" width="100">
          <template #default="{ row }">
            <span :class="row.coupon === '未使用' ? 'no-coupon' : 'coupon'">
              {{ row.coupon }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="实付金额" width="100">
          <template #default="{ row }">
            <strong class="amount">¥{{ row.amount.toFixed(2) }}</strong>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag size="small" :type="tone(row.status)" effect="light">
              {{ row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="创建时间" width="150" />
        <el-table-column label="操作" width="90" fixed="right">
          <template #default="{ row }">
            <button class="table-link" @click="openDetail(row.orderNo)">详情</button>
          </template>
        </el-table-column>
      </el-table>
    </section>
  </div>
</template>

<style scoped>
.order-metrics {
  display: grid;
  gap: 12px;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.order-metrics article {
  display: flex;
  padding: 17px;
  align-items: center;
  gap: 12px;
  border: 1px solid rgba(91, 67, 54, 0.07);
  border-radius: 18px;
  background: #fffdf9;
  box-shadow: 0 12px 32px rgba(70, 52, 40, 0.045);
}

.metric-icon {
  display: grid;
  width: 37px;
  height: 37px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: 12px;
  font-weight: 800;
}

.metric-icon.coral {
  color: #a55340;
  background: #f5dfd7;
}

.metric-icon.sage {
  color: #64785e;
  background: #e5ede1;
}

.metric-icon.amber {
  color: #9c6c31;
  background: #f7ead4;
}

.metric-icon.cocoa {
  color: #5b4336;
  background: #eee5da;
}

.order-metrics small,
.order-metrics strong,
.order-metrics em {
  display: block;
}

.order-metrics small {
  color: #97887c;
  font-size: 8px;
}

.order-metrics strong {
  margin-top: 4px;
  color: #40352e;
  font-family: 'Songti SC', serif;
  font-size: 20px;
}

.order-metrics em {
  margin-top: 3px;
  color: #71836b;
  font-size: 8px;
  font-style: normal;
  font-weight: 700;
}

.order-metrics em.neutral {
  color: #9c6c31;
}

.filter-bar {
  display: flex;
  margin-bottom: 16px;
  align-items: center;
  gap: 9px;
  flex-wrap: wrap;
}

.search-input {
  width: 260px;
}

.filter-select {
  width: 120px;
}

.result-count {
  margin-left: auto;
  color: #a09489;
  font-size: 9px;
}

.order-link {
  padding: 0;
  border: 0;
  color: #5b4336;
  background: transparent;
  font-size: 10px;
  font-weight: 700;
  cursor: pointer;
}

.coupon {
  color: #a55340;
  font-size: 9px;
  font-weight: 700;
}

.no-coupon {
  color: #ada198;
  font-size: 9px;
}

.amount {
  color: #4e4139;
  font-size: 11px;
}

.table-link {
  padding: 0;
  border: 0;
  color: #b85c45;
  background: transparent;
  font-size: 9px;
  cursor: pointer;
}

@media (max-width: 1100px) {
  .order-metrics {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 600px) {
  .order-metrics {
    grid-template-columns: 1fr;
  }

  .search-input,
  .filter-select {
    width: 100%;
  }
}
</style>

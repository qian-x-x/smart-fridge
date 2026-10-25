<script setup lang="ts">
import { ElMessage } from 'element-plus'
import { computed, ref } from 'vue'

interface ProductRow {
  sku: string
  name: string
  category: string
  price: number
  stock: number
  safeStock: number
  sales: number
  emoji: string
}

const products: ProductRow[] = [
  {
    sku: 'SKU-TM-001',
    name: '云南小番茄 500g',
    category: '蔬菜',
    price: 8.8,
    stock: 124,
    safeStock: 80,
    sales: 628,
    emoji: '🍅',
  },
  {
    sku: 'SKU-EG-012',
    name: '谷物鲜鸡蛋 10 枚',
    category: '蛋奶',
    price: 16.9,
    stock: 42,
    safeStock: 60,
    sales: 512,
    emoji: '🥚',
  },
  {
    sku: 'SKU-MK-023',
    name: '低温鲜牛奶 950ml',
    category: '饮品',
    price: 19.9,
    stock: 18,
    safeStock: 40,
    sales: 487,
    emoji: '🥛',
  },
  {
    sku: 'SKU-BF-006',
    name: '谷饲牛里脊 300g',
    category: '肉类',
    price: 39.9,
    stock: 76,
    safeStock: 35,
    sales: 364,
    emoji: '🥩',
  },
  {
    sku: 'SKU-LT-031',
    name: '奶油生菜 300g',
    category: '蔬菜',
    price: 6.5,
    stock: 0,
    safeStock: 50,
    sales: 331,
    emoji: '🥬',
  },
]

const keyword = ref('')
const stockFilter = ref('全部库存')
const visibleProducts = computed(() =>
  products.filter((product) => {
    const keywordMatch =
      product.name.includes(keyword.value.trim()) ||
      product.sku.toLowerCase().includes(keyword.value.trim().toLowerCase())
    const stockMatch =
      stockFilter.value === '全部库存' ||
      (stockFilter.value === '库存预警' && product.stock < product.safeStock) ||
      (stockFilter.value === '已售罄' && product.stock === 0)
    return keywordMatch && stockMatch
  }),
)

function stockStatus(product: ProductRow) {
  if (product.stock === 0) return { label: '已售罄', tone: 'danger' }
  if (product.stock < product.safeStock) return { label: '库存预警', tone: 'warning' }
  return { label: '库存健康', tone: 'success' }
}

function action(label: string) {
  ElMessage.info(`${label}能力将在 stock-service 接入后启用`)
}
</script>

<template>
  <div class="page-shell">
    <div class="page-heading">
      <div>
        <p class="page-kicker">INVENTORY & CATALOG</p>
        <h1 class="page-title">商品与库存</h1>
        <p class="page-description">
          监控补货 SKU、安全库存和价格。库存修改必须保留操作人、时间和变更原因。
        </p>
      </div>
      <el-button type="primary" @click="action('新增商品')">+ 新增商品</el-button>
    </div>

    <section class="inventory-hero">
      <div class="hero-copy">
        <span>库存健康度</span>
        <strong>84.6</strong>
        <small>30 个初始化商品中，25 个处于健康区间</small>
      </div>
      <div class="health-bar">
        <span class="healthy" />
        <span class="warning" />
        <span class="danger" />
      </div>
      <div class="health-legend">
        <span><i class="healthy" />充足 25</span>
        <span><i class="warning" />预警 4</span>
        <span><i class="danger" />售罄 1</span>
      </div>
      <div class="restock-note">
        <span>补货提醒</span>
        <strong>5 个 SKU 建议在本周补货</strong>
        <button @click="action('生成补货建议')">生成建议 →</button>
      </div>
    </section>

    <section class="panel">
      <div class="filter-bar">
        <el-input
          v-model="keyword"
          clearable
          placeholder="搜索商品名称或 SKU"
          class="search-input"
        >
          <template #prefix>⌕</template>
        </el-input>
        <el-select v-model="stockFilter" class="filter-select">
          <el-option
            v-for="item in ['全部库存', '库存预警', '已售罄']"
            :key="item"
            :label="item"
            :value="item"
          />
        </el-select>
        <span class="result-count">{{ visibleProducts.length }} 个 SKU</span>
      </div>

      <el-table :data="visibleProducts" style="width: 100%">
        <el-table-column label="商品" min-width="220">
          <template #default="{ row }">
            <div class="product-cell">
              <span>{{ row.emoji }}</span>
              <div>
                <strong>{{ row.name }}</strong>
                <small>{{ row.sku }} · {{ row.category }}</small>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="售价" width="100">
          <template #default="{ row }">
            <strong class="price">¥{{ row.price.toFixed(2) }}</strong>
          </template>
        </el-table-column>
        <el-table-column label="当前库存" width="120">
          <template #default="{ row }">
            <div class="stock-cell">
              <strong>{{ row.stock }}</strong>
              <small>/ 安全线 {{ row.safeStock }}</small>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="sales" label="近 30 日销量" width="120" />
        <el-table-column label="状态" width="105">
          <template #default="{ row }">
            <span class="stock-status" :class="stockStatus(row).tone">
              {{ stockStatus(row).label }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="128" fixed="right">
          <template #default="{ row }">
            <button class="table-link" @click="action(`调整 ${row.sku} 库存`)">
              调整库存
            </button>
            <button class="table-link muted" @click="action('编辑商品')">编辑</button>
          </template>
        </el-table-column>
      </el-table>
    </section>
  </div>
</template>

<style scoped>
.inventory-hero {
  display: grid;
  padding: 22px 24px;
  align-items: center;
  gap: 25px;
  border-radius: 23px;
  background:
    linear-gradient(90deg, rgba(113, 131, 107, 0.08), transparent 45%),
    #fffdf9;
  box-shadow: var(--shadow);
  grid-template-columns: 170px 1fr 230px;
}

.hero-copy span,
.hero-copy strong,
.hero-copy small {
  display: block;
}

.hero-copy span {
  color: #8d7e72;
  font-size: 9px;
}

.hero-copy strong {
  margin: 5px 0;
  color: #4b5e47;
  font-family: 'Songti SC', serif;
  font-size: 35px;
}

.hero-copy small {
  color: #aca096;
  font-size: 8px;
}

.health-bar {
  display: flex;
  overflow: hidden;
  height: 9px;
  border-radius: 99px;
  gap: 3px;
}

.health-bar span {
  height: 100%;
}

.healthy {
  background: #8ca383;
}

.warning {
  background: #e0b476;
}

.danger {
  background: #c36b6f;
}

.health-bar .healthy {
  width: 83%;
}

.health-bar .warning {
  width: 12%;
}

.health-bar .danger {
  width: 5%;
}

.health-legend {
  display: none;
}

.restock-note {
  padding: 14px 16px;
  border-left: 1px solid #eee4d9;
}

.restock-note span,
.restock-note strong {
  display: block;
}

.restock-note span {
  color: #a69181;
  font-size: 8px;
}

.restock-note strong {
  margin: 5px 0 8px;
  color: #57493f;
  font-size: 11px;
}

.restock-note button {
  padding: 0;
  border: 0;
  color: #b85c45;
  background: transparent;
  font-size: 8px;
  cursor: pointer;
}

.filter-bar {
  display: flex;
  margin-bottom: 16px;
  align-items: center;
  gap: 9px;
}

.search-input {
  width: 290px;
}

.filter-select {
  width: 128px;
}

.result-count {
  margin-left: auto;
  color: #a09489;
  font-size: 9px;
}

.product-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}

.product-cell > span {
  display: grid;
  width: 39px;
  height: 39px;
  place-items: center;
  border-radius: 12px;
  background: #f4eee6;
  font-size: 22px;
}

.product-cell strong,
.product-cell small {
  display: block;
}

.product-cell strong {
  color: #4e4139;
  font-size: 11px;
}

.product-cell small {
  margin-top: 3px;
  color: #aea197;
  font-size: 8px;
}

.price {
  color: #4e4139;
  font-size: 11px;
}

.stock-cell strong {
  color: #4e4139;
  font-size: 12px;
}

.stock-cell small {
  color: #aaa095;
  font-size: 8px;
}

.stock-status {
  display: inline-flex;
  padding: 4px 8px;
  border-radius: 99px;
  font-size: 8px;
  font-weight: 700;
}

.stock-status.success {
  color: #5f775a;
  background: #e8f0e5;
}

.stock-status.warning {
  color: #9c6c31;
  background: #f8ead9;
}

.stock-status.danger {
  color: #a34b55;
  background: #f8e4e3;
}

.table-link {
  margin-right: 8px;
  padding: 0;
  border: 0;
  color: #b85c45;
  background: transparent;
  font-size: 9px;
  cursor: pointer;
}

.table-link.muted {
  color: #9c8d82;
}

@media (max-width: 900px) {
  .inventory-hero {
    grid-template-columns: 1fr;
  }

  .restock-note {
    padding: 12px 0 0;
    border-top: 1px solid #eee4d9;
    border-left: 0;
  }

  .search-input {
    width: 100%;
  }
}
</style>

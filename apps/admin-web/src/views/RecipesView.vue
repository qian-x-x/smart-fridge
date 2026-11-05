<script setup lang="ts">
import { ElMessage } from 'element-plus'
import { computed, ref } from 'vue'

interface RecipeRow {
  id: number
  name: string
  category: string
  ingredients: number
  duration: number
  usage: number
  status: '已上架' | '草稿' | '已下架'
  emoji: string
}

const recipes: RecipeRow[] = [
  {
    id: 1,
    name: '番茄滑蛋',
    category: '家常菜',
    ingredients: 4,
    duration: 15,
    usage: 1284,
    status: '已上架',
    emoji: '🍅',
  },
  {
    id: 2,
    name: '蒜蓉生菜',
    category: '快手菜',
    ingredients: 3,
    duration: 8,
    usage: 986,
    status: '已上架',
    emoji: '🥬',
  },
  {
    id: 3,
    name: '黑椒牛肉粒',
    category: '家常菜',
    ingredients: 6,
    duration: 22,
    usage: 841,
    status: '已上架',
    emoji: '🥩',
  },
  {
    id: 4,
    name: '家常煎饺',
    category: '主食',
    ingredients: 3,
    duration: 15,
    usage: 743,
    status: '草稿',
    emoji: '🥟',
  },
  {
    id: 5,
    name: '南瓜小米粥',
    category: '早餐',
    ingredients: 5,
    duration: 35,
    usage: 528,
    status: '已下架',
    emoji: '🎃',
  },
]

const keyword = ref('')
const category = ref('全部分类')
const status = ref('全部状态')

const filteredRecipes = computed(() =>
  recipes.filter((recipe) => {
    const matchesKeyword = recipe.name.includes(keyword.value.trim())
    const matchesCategory =
      category.value === '全部分类' || recipe.category === category.value
    const matchesStatus =
      status.value === '全部状态' || recipe.status === status.value
    return matchesKeyword && matchesCategory && matchesStatus
  }),
)

function tagTone(value: RecipeRow['status']) {
  if (value === '已上架') return 'success'
  if (value === '草稿') return 'warning'
  return 'info'
}

function comingSoon(action: string) {
  ElMessage.info(`${action}操作将在运营接口接入后启用`)
}
</script>

<template>
  <div class="page-shell">
    <div class="page-heading">
      <div>
        <p class="page-kicker">CONTENT LIBRARY</p>
        <h1 class="page-title">菜谱与分类</h1>
        <p class="page-description">
          整理菜谱内容、食材结构与制作步骤，让每一份灵感清楚易读。
        </p>
      </div>
      <el-button type="primary" @click="comingSoon('新增菜谱')">
        + 新增菜谱
      </el-button>
    </div>

    <section class="recipe-summary">
      <div>
        <span>菜谱总数</span>
        <strong>{{ recipes.length }}</strong>
        <small>当前演示目录</small>
      </div>
      <div>
        <span>已上架</span>
        <strong>{{ recipes.filter(recipe => recipe.status === '已上架').length }}</strong>
        <small>示例发布状态</small>
      </div>
      <div>
        <span>草稿</span>
        <strong>{{ recipes.filter(recipe => recipe.status === '草稿').length }}</strong>
        <small>尚未发布的示例</small>
      </div>
      <div class="featured">
        <span class="featured-emoji">🍅</span>
        <div>
          <small>本周推荐</small>
          <strong>番茄滑蛋</strong>
        </div>
        <span class="soft-tag warning">1,284 次</span>
      </div>
    </section>

    <section class="panel">
      <div class="filter-bar">
        <el-input
          v-model="keyword"
          clearable
          placeholder="搜索菜谱名称"
          class="search-input"
        >
          <template #prefix>⌕</template>
        </el-input>
        <el-select v-model="category" class="filter-select">
          <el-option
            v-for="item in ['全部分类', '家常菜', '快手菜', '早餐', '主食']"
            :key="item"
            :label="item"
            :value="item"
          />
        </el-select>
        <el-select v-model="status" class="filter-select">
          <el-option
            v-for="item in ['全部状态', '已上架', '草稿', '已下架']"
            :key="item"
            :label="item"
            :value="item"
          />
        </el-select>
        <span class="result-count">共 {{ filteredRecipes.length }} 条</span>
      </div>

      <el-table :data="filteredRecipes" style="width: 100%">
        <el-table-column label="菜谱" min-width="190">
          <template #default="{ row }">
            <div class="recipe-cell">
              <span class="recipe-cover">{{ row.emoji }}</span>
              <div>
                <strong>{{ row.name }}</strong>
                <small>#R{{ String(row.id).padStart(4, '0') }}</small>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="category" label="分类" width="100" />
        <el-table-column label="原料" width="90">
          <template #default="{ row }">{{ row.ingredients }} 种</template>
        </el-table-column>
        <el-table-column label="耗时" width="90">
          <template #default="{ row }">{{ row.duration }} 分钟</template>
        </el-table-column>
        <el-table-column label="使用热度" width="110">
          <template #default="{ row }">
            <span class="usage-value">{{ row.usage.toLocaleString() }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="95">
          <template #default="{ row }">
            <el-tag size="small" :type="tagTone(row.status)" effect="light">
              {{ row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="120" fixed="right">
          <template #default>
            <button class="table-link" @click="comingSoon('编辑菜谱')">编辑</button>
            <button class="table-link muted" @click="comingSoon('上下架')">
              更多
            </button>
          </template>
        </el-table-column>
      </el-table>
    </section>
  </div>
</template>

<style scoped>
.recipe-summary {
  display: grid;
  overflow: hidden;
  border: 1px solid rgba(91, 67, 54, 0.08);
  border-radius: 21px;
  background: #ffffff;
  box-shadow: var(--shadow);
  grid-template-columns: repeat(3, 1fr) 1.2fr;
}

.recipe-summary > div {
  padding: 18px 21px;
  border-right: 1px solid #eee6dc;
}

.recipe-summary > div:last-child {
  border-right: 0;
}

.recipe-summary span,
.recipe-summary strong,
.recipe-summary small {
  display: block;
}

.recipe-summary span {
  color: #928377;
  font-size: 12px;
}

.recipe-summary strong {
  margin: 8px 0 4px;
  color: #3f342d;
  font-family: 'Songti SC', serif;
  font-size: 24px;
}

.recipe-summary small {
  color: #b0a398;
  font-size: 12px;
}

.recipe-summary .featured {
  display: flex;
  align-items: center;
  gap: 11px;
  background: #f4eee6;
}

.featured-emoji {
  display: grid !important;
  width: 42px;
  height: 42px;
  place-items: center;
  border-radius: 13px;
  background: #fffaf3;
  font-size: 24px !important;
}

.featured > div {
  flex: 1;
}

.featured > div strong {
  margin: 4px 0 0;
  font-size: 14px;
}

.filter-bar {
  display: flex;
  margin-bottom: 16px;
  align-items: center;
  gap: 9px;
}

.search-input {
  width: 270px;
}

.filter-select {
  width: 130px;
}

.result-count {
  margin-left: auto;
  color: #a09489;
  font-size: 12px;
}

.recipe-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}

.recipe-cover {
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border-radius: 12px;
  background: #f4eee6;
  font-size: 21px;
}

.recipe-cell strong,
.recipe-cell small {
  display: block;
}

.recipe-cell strong {
  color: #4e4139;
  font-size: 11px;
}

.recipe-cell small {
  margin-top: 3px;
  color: #aea197;
  font-size: 12px;
}

.usage-value {
  color: #6c5c51;
  font-weight: 700;
}

.table-link {
  margin-right: 8px;
  padding: 0;
  border: 0;
  color: #bc4d30;
  background: transparent;
  font-size: 12px;
  cursor: pointer;
}

.table-link.muted {
  color: #9c8d82;
}

@media (max-width: 900px) {
  .recipe-summary {
    grid-template-columns: 1fr 1fr;
  }

  .filter-bar {
    align-items: stretch;
    flex-wrap: wrap;
  }

  .search-input {
    width: 100%;
  }
}
</style>

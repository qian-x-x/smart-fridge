<script setup lang="ts">
import { computed, ref } from 'vue'
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const mobileOpen = ref(false)

const navItems = [
  { path: '/dashboard', glyph: '◫', label: '数据看板', note: '经营全景' },
  { path: '/recipes', glyph: '◒', label: '菜谱管理', note: '内容与推荐' },
  { path: '/products', glyph: '▣', label: '商品库存', note: 'SKU 与补货' },
  { path: '/orders', glyph: '⌁', label: '订单管理', note: '交易与优惠' },
]

const currentTitle = computed(() => String(route.meta.title ?? '运营工作台'))

function navigate() {
  mobileOpen.value = false
}

function logout() {
  auth.logout()
  router.push('/login')
}
</script>

<template>
  <div class="admin-frame">
    <button
      v-if="mobileOpen"
      class="sidebar-backdrop"
      aria-label="关闭导航"
      @click="mobileOpen = false"
    />
    <aside class="sidebar" :class="{ open: mobileOpen }">
      <div class="brand">
        <div class="brand-mark">满</div>
        <div>
          <strong>小满冰箱</strong>
          <span>SMART FRIDGE</span>
        </div>
      </div>

      <div class="workspace-card">
        <span class="workspace-dot" />
        <div>
          <small>当前空间</small>
          <strong>运营与内容中心</strong>
        </div>
      </div>

      <nav class="nav-list" aria-label="运营后台主导航">
        <RouterLink
          v-for="item in navItems"
          :key="item.path"
          :to="item.path"
          class="nav-item"
          :class="{ active: route.path === item.path }"
          @click="navigate"
        >
          <span class="nav-glyph">{{ item.glyph }}</span>
          <span class="nav-copy">
            <strong>{{ item.label }}</strong>
            <small>{{ item.note }}</small>
          </span>
          <span class="nav-arrow">›</span>
        </RouterLink>
      </nav>

      <div class="sidebar-footer">
        <div class="system-health">
          <span class="health-pulse" />
          <div>
            <strong>课程环境运行中</strong>
            <small>7 个服务 · 演示模式</small>
          </div>
        </div>
        <div class="operator">
          <div class="operator-avatar">运</div>
          <div class="operator-copy">
            <strong>{{ auth.displayName || '运营管理员' }}</strong>
            <span>平台运营角色</span>
          </div>
          <button class="logout-link" title="退出登录" @click="logout">↗</button>
        </div>
      </div>
    </aside>

    <section class="main-area">
      <header class="topbar">
        <button
          class="menu-button"
          aria-label="打开导航"
          @click="mobileOpen = true"
        >
          ☰
        </button>
        <div class="breadcrumb">
          <span>小满冰箱</span>
          <i>/</i>
          <strong>{{ currentTitle }}</strong>
        </div>
        <div class="top-actions">
          <div class="env-chip">
            <span />
            DEMO
          </div>
          <button class="circle-action" title="站内通知">◌</button>
          <div class="date-block">
            <small>数据更新</small>
            <strong>刚刚</strong>
          </div>
        </div>
      </header>
      <main class="content">
        <RouterView />
      </main>
    </section>
  </div>
</template>

<style scoped>
.admin-frame {
  display: flex;
  min-height: 100vh;
}

.sidebar {
  position: fixed;
  z-index: 30;
  inset: 0 auto 0 0;
  display: flex;
  width: 250px;
  padding: 24px 16px 18px;
  flex-direction: column;
  color: #f7f2ea;
  background:
    radial-gradient(circle at 10% 0%, rgba(184, 92, 69, 0.2), transparent 28%),
    #332a24;
}

.brand {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 0 8px;
}

.brand-mark {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  border-radius: 13px;
  color: #332a24;
  background: #e8c9a7;
  font-family: 'Songti SC', serif;
  font-size: 20px;
  font-weight: 900;
}

.brand strong,
.brand span {
  display: block;
}

.brand strong {
  font-size: 16px;
  letter-spacing: 0.03em;
}

.brand span {
  margin-top: 2px;
  color: rgba(247, 242, 234, 0.38);
  font-size: 8px;
  font-weight: 700;
  letter-spacing: 0.18em;
}

.workspace-card {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 28px 5px 18px;
  padding: 12px;
  border: 1px solid rgba(255, 255, 255, 0.07);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.035);
}

.workspace-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #d6a784;
  box-shadow: 0 0 0 4px rgba(214, 167, 132, 0.1);
}

.workspace-card small,
.workspace-card strong {
  display: block;
}

.workspace-card small {
  color: rgba(247, 242, 234, 0.38);
  font-size: 8px;
}

.workspace-card strong {
  margin-top: 3px;
  font-size: 11px;
}

.nav-list {
  display: flex;
  flex-direction: column;
  gap: 5px;
}

.nav-item {
  display: flex;
  min-height: 56px;
  padding: 9px 10px;
  align-items: center;
  gap: 11px;
  border-radius: 14px;
  color: rgba(247, 242, 234, 0.62);
  transition: 180ms ease;
}

.nav-item:hover {
  color: #fff9f2;
  background: rgba(255, 255, 255, 0.05);
}

.nav-item.active {
  color: #fff9f2;
  background: #b85c45;
  box-shadow: 0 12px 26px rgba(0, 0, 0, 0.16);
}

.nav-glyph {
  display: grid;
  width: 31px;
  height: 31px;
  place-items: center;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.08);
  font-size: 16px;
}

.nav-copy {
  flex: 1;
}

.nav-copy strong,
.nav-copy small {
  display: block;
}

.nav-copy strong {
  font-size: 12px;
}

.nav-copy small {
  margin-top: 2px;
  color: inherit;
  font-size: 8px;
  opacity: 0.55;
}

.nav-arrow {
  opacity: 0.4;
}

.sidebar-footer {
  margin-top: auto;
}

.system-health {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 12px;
  border-radius: 13px;
  background: rgba(255, 255, 255, 0.035);
}

.health-pulse {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #9fbe94;
  box-shadow: 0 0 0 4px rgba(159, 190, 148, 0.09);
}

.system-health strong,
.system-health small {
  display: block;
}

.system-health strong {
  font-size: 9px;
}

.system-health small {
  margin-top: 3px;
  color: rgba(247, 242, 234, 0.35);
  font-size: 8px;
}

.operator {
  display: flex;
  align-items: center;
  gap: 9px;
  margin-top: 15px;
  padding: 12px 7px 0;
  border-top: 1px solid rgba(255, 255, 255, 0.07);
}

.operator-avatar {
  display: grid;
  width: 31px;
  height: 31px;
  place-items: center;
  border-radius: 10px;
  background: #e2c3a4;
  color: #332a24;
  font-size: 11px;
  font-weight: 800;
}

.operator-copy {
  flex: 1;
}

.operator-copy strong,
.operator-copy span {
  display: block;
}

.operator-copy strong {
  font-size: 10px;
}

.operator-copy span {
  margin-top: 2px;
  color: rgba(247, 242, 234, 0.35);
  font-size: 8px;
}

.logout-link,
.menu-button,
.circle-action {
  border: 0;
  cursor: pointer;
}

.logout-link {
  color: rgba(247, 242, 234, 0.45);
  background: transparent;
  font-size: 16px;
}

.main-area {
  width: calc(100% - 250px);
  min-width: 0;
  margin-left: 250px;
}

.topbar {
  display: flex;
  height: 72px;
  padding: 0 32px;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid rgba(91, 67, 54, 0.07);
  background: rgba(247, 243, 235, 0.72);
  backdrop-filter: blur(16px);
}

.breadcrumb {
  display: flex;
  align-items: center;
  gap: 9px;
  color: #9b8f85;
  font-size: 11px;
}

.breadcrumb i {
  color: #c9bdb2;
  font-style: normal;
}

.breadcrumb strong {
  color: #4a4038;
}

.top-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.env-chip {
  display: flex;
  padding: 7px 10px;
  align-items: center;
  gap: 6px;
  border: 1px solid #ded4c8;
  border-radius: 99px;
  color: #7b6e63;
  font-size: 8px;
  font-weight: 800;
  letter-spacing: 0.08em;
}

.env-chip span {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #84a47b;
}

.circle-action {
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border: 1px solid #ded4c8;
  border-radius: 50%;
  color: #6c5d53;
  background: rgba(255, 255, 255, 0.5);
}

.date-block {
  min-width: 62px;
  padding-left: 4px;
}

.date-block small,
.date-block strong {
  display: block;
}

.date-block small {
  color: #a69a8f;
  font-size: 8px;
}

.date-block strong {
  margin-top: 2px;
  color: #5b4336;
  font-size: 10px;
}

.menu-button {
  display: none;
  color: #5b4336;
  background: transparent;
  font-size: 20px;
}

.content {
  padding: 28px 32px 38px;
}

.sidebar-backdrop {
  display: none;
}

@media (max-width: 900px) {
  .sidebar {
    transform: translateX(-105%);
    transition: transform 220ms ease;
  }

  .sidebar.open {
    transform: translateX(0);
  }

  .sidebar-backdrop {
    position: fixed;
    z-index: 25;
    inset: 0;
    display: block;
    border: 0;
    background: rgba(35, 28, 23, 0.42);
  }

  .main-area {
    width: 100%;
    margin-left: 0;
  }

  .menu-button {
    display: block;
  }

  .breadcrumb {
    display: none;
  }
}

@media (max-width: 600px) {
  .topbar {
    height: 62px;
    padding: 0 18px;
  }

  .content {
    padding: 21px 16px 30px;
  }

  .date-block,
  .circle-action {
    display: none;
  }
}
</style>

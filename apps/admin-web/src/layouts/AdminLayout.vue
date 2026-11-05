<script setup lang="ts">
import { computed, ref } from 'vue'
import { ElMessageBox } from 'element-plus'
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { brand } from '../brand'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const mobileOpen = ref(false)
const navItems = [
  { path: '/dashboard', glyph: '◫', label: '数据看板' },
  { path: '/recipes', glyph: '▤', label: '菜谱管理' },
  { path: '/products', glyph: '▣', label: '商品库存' },
  { path: '/orders', glyph: '▥', label: '补货订单' },
]
const currentTitle = computed(() => String(route.meta.title ?? '运营工作台'))
async function logout() {
  try {
    await ElMessageBox.confirm('退出后将清除本次运营演示会话，可随时重新进入。', '退出运营工作台？', { confirmButtonText: '退出', cancelButtonText: '留下', type: 'warning' })
    auth.logout()
    await router.replace('/login')
  } catch { /* Closing or cancelling keeps the session. */ }
}
</script>

<template>
  <div class="admin-frame" @keydown.esc="mobileOpen = false">
    <button v-if="mobileOpen" class="sidebar-backdrop" type="button" aria-label="关闭导航" @click="mobileOpen = false" />
    <aside class="sidebar" :class="{ open: mobileOpen }" aria-label="运营导航">
      <RouterLink class="rail-brand" to="/dashboard" :title="brand.name" @click="mobileOpen = false">
        <img src="/favicon.svg" :alt="brand.name" width="38" height="38" />
        <strong>{{ brand.name }}</strong>
      </RouterLink>
      <nav class="nav-list" aria-label="运营后台主导航">
        <RouterLink v-for="item in navItems" :key="item.path" :to="item.path" class="nav-item" :class="{ active: route.path === item.path }" @click="mobileOpen = false">
          <span class="nav-glyph" aria-hidden="true">{{ item.glyph }}</span>
          <span>{{ item.label }}</span>
        </RouterLink>
      </nav>
      <div class="sidebar-footer"><span class="operator-avatar" :title="auth.displayName || '运营管理员'">运</span><button class="logout-link" type="button" aria-label="退出登录" @click="logout">退出</button></div>
    </aside>
    <section class="main-area">
      <header class="topbar">
        <button class="menu-button" type="button" :aria-expanded="mobileOpen" aria-label="打开导航" @click="mobileOpen = true">☰</button>
        <div class="breadcrumb"><strong>{{ brand.name }}</strong><span>/ {{ currentTitle }}</span></div>
        <span class="brand-tagline">{{ brand.tagline }}</span>
        <span class="demo-label">演示模式</span>
        <span class="operator-avatar" :title="auth.displayName || '运营管理员'">运</span>
      </header>
      <main class="content">
        <div class="demo-notice" role="note">演示工作区 · 本页为示例数据；编辑、交易与导出能力待真实服务接入。</div>
        <RouterView v-slot="{ Component, route: viewRoute }">
          <Transition name="page" mode="out-in">
            <KeepAlive :max="4"><component :is="Component" :key="String(viewRoute.name)" /></KeepAlive>
          </Transition>
        </RouterView>
      </main>
    </section>
  </div>
</template>

<style scoped>
.admin-frame{min-height:100vh;display:flex}.sidebar{position:fixed;inset:0 auto 0 0;z-index:30;width:98px;display:flex;flex-direction:column;align-items:center;padding:26px 12px 22px;background:var(--paper);border-right:1px solid var(--line)}.rail-brand{display:flex;align-items:center;gap:12px;margin-bottom:30px}.rail-brand strong{display:none}.nav-list{display:grid;gap:12px;width:100%}.nav-item{display:flex;align-items:center;flex-direction:column;gap:8px;padding:14px 3px;border-radius:18px;font-size:11px;color:var(--muted);transition:background 180ms,color 180ms,transform 120ms}.nav-item.active{background:var(--linen);color:var(--terracotta);font-weight:600}.nav-item:hover{background:var(--linen)}.nav-item:active{transform:scale(.97)}.nav-glyph{font-size:25px;line-height:1}.sidebar-footer{display:flex;align-items:center;flex-direction:column;gap:12px;margin-top:auto;padding-top:20px;border-top:1px solid var(--line);width:100%}.operator-avatar{width:38px;height:38px;display:grid;place-items:center;border-radius:50%;background:var(--linen);color:var(--terracotta);font-size:14px;flex:none}.logout-link{border:0;background:transparent;color:var(--muted);padding:10px;font-size:12px}.main-area{min-width:0;width:calc(100% - 98px);margin-left:98px}.topbar{height:82px;margin:0 32px;display:flex;align-items:center;gap:18px;border-bottom:1px solid var(--line)}.breadcrumb{display:flex;align-items:center;gap:16px}.breadcrumb strong{font-size:20px;font-weight:600}.breadcrumb span{font-size:12px;color:var(--muted)}.brand-tagline{margin-left:auto;font-size:12px;color:var(--muted)}.demo-label{font-size:11px;color:var(--terracotta);background:var(--linen);padding:6px 11px;border-radius:8px;white-space:nowrap}.content{padding:24px 32px 38px}.demo-notice{margin-bottom:22px;color:var(--muted);font-size:12px;padding:10px 14px;border-left:3px solid var(--peach);line-height:1.7}.menu-button{display:none;border:0;background:transparent;font-size:22px;min-width:44px;min-height:44px;color:var(--cocoa)}.sidebar-backdrop{display:none}
@media(max-width:900px){.sidebar{width:250px;align-items:stretch;transform:translateX(-100%);transition:transform 220ms ease}.sidebar.open{transform:translateX(0)}.rail-brand strong{display:block;font-size:20px}.nav-item{flex-direction:row;gap:15px;padding:16px;font-size:14px}.sidebar-footer{flex-direction:row;justify-content:space-between}.main-area{width:100%;margin-left:0}.menu-button{display:block}.sidebar-backdrop{display:block;position:fixed;inset:0;z-index:25;border:0;background:#442b2255}.brand-tagline{display:none}.breadcrumb{margin-right:auto}.topbar{margin:0 20px;gap:12px}.content{padding:22px 20px}.breadcrumb strong{font-size:18px}}
@media(max-width:550px){.topbar{margin:0 12px;height:70px;gap:8px}.breadcrumb span,.topbar>.operator-avatar{display:none}.content{padding:20px 14px}.demo-notice{font-size:11px}}
@media(prefers-reduced-motion:reduce){.sidebar,.nav-item{transition:none}}
</style>

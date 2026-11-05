<script setup lang="ts">
import { ElMessage } from 'element-plus'
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { brand } from '../brand'
import kitchenImage from '../assets/kitchen-harvest.jpg'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()
const credentials = reactive({ account: '', password: '' })
const submitting = ref(false)
async function enterDemo(requireFields = false) {
  if (submitting.value) return
  if (requireFields && (!credentials.account.trim() || !credentials.password.trim())) {
    ElMessage.warning('请填写演示账号与密码，或直接浏览演示')
    return
  }
  submitting.value = true
  try {
    auth.enterDemo()
    const next = String(route.query.redirect ?? '/dashboard')
    const destination = ['/dashboard', '/recipes', '/products', '/orders'].includes(next.split('?')[0] ?? '') ? next : '/dashboard'
    await router.replace(destination)
  } finally { submitting.value = false }
}
</script>

<template>
  <main class="login-page">
    <section class="login-panel">
      <div class="login-card">
        <div class="login-brand"><img src="/favicon.svg" alt="" width="40" height="40" /><div><strong>{{ brand.name }}</strong><small>{{ brand.englishName }} OPS</small></div></div>
        <p class="brand-motto">{{ brand.tagline }}</p>
        <p class="form-kicker">OPERATIONS WORKSPACE</p>
        <h1>让运营，也更容易。</h1>
        <p class="form-description">管理菜谱、商品库存和补货订单。当前提供本地演示入口，运营账号认证尚未接入。</p>
        <form @submit.prevent="enterDemo(true)">
          <label class="field-label" for="account">演示账号</label>
          <el-input id="account" v-model="credentials.account" size="large" :disabled="submitting" autocomplete="username" placeholder="请输入演示账号" />
          <label class="field-label" for="password">演示密码</label>
          <el-input id="password" v-model="credentials.password" size="large" :disabled="submitting" type="password" show-password autocomplete="off" placeholder="演示内容，不会提交真实账号" />
          <el-button type="primary" size="large" class="login-button" native-type="submit" :loading="submitting">进入演示工作台</el-button>
          <el-button size="large" class="demo-button" :disabled="submitting" @click="enterDemo()">直接浏览演示</el-button>
        </form>
        <p class="security-note">演示数据 · 不会向后端提交账号或密码</p>
      </div>
    </section>
    <section class="story-panel"><img :src="kitchenImage" alt="暖橙厨房外观概念图" /><div class="story-copy"><p>EVERYDAY HARVEST</p><h2>一日三餐，<br />都可以从容一点。</h2><span>食材有去处，三餐有灵感。</span></div></section>
  </main>
</template>

<style scoped>
.login-page{min-height:100vh;display:grid;grid-template-columns:1fr 1.1fr;gap:30px;padding:40px;background:var(--cream)}.login-panel{display:flex;align-items:center;justify-content:center;background:var(--paper);border:1px solid var(--line);border-radius:28px;padding:44px}.login-card{max-width:380px;width:100%}.login-brand{display:flex;align-items:center;gap:12px}.login-brand strong{font-size:23px;font-weight:650;display:block}.login-brand small{font-size:9px;letter-spacing:1.8px;color:var(--muted);display:block;margin-top:4px}.brand-motto{font-size:12px;color:var(--muted);margin:12px 0 34px}.form-kicker{font-size:10px;letter-spacing:2px;color:var(--muted);margin-bottom:10px}h1{font-size:29px;line-height:1.4;letter-spacing:-1px;font-family:Georgia,'STSong',serif;margin-bottom:12px}.form-description{font-size:13px;line-height:1.8;color:var(--muted);margin-bottom:25px}.field-label{display:block;font-size:12px;margin:18px 0 8px}.login-button,.demo-button{width:100%;margin:24px 0 0!important;min-height:48px}.demo-button{margin-top:12px!important}.security-note{font-size:11px;color:var(--muted);text-align:center;margin:22px 0 0}.story-panel{position:relative;min-height:650px;border-radius:28px;overflow:hidden}.story-panel>img{width:100%;height:100%;object-fit:cover;position:absolute;inset:0}.story-copy{position:absolute;left:30px;right:30px;bottom:30px;background:#fffdf4f2;padding:24px;border-radius:20px}.story-copy p{font-size:10px;letter-spacing:2px;color:var(--terracotta);margin-bottom:10px}.story-copy h2{font-family:Georgia,'STSong',serif;font-size:27px;line-height:1.4;margin-bottom:12px}.story-copy span{font-size:12px;color:var(--muted)}
@media(max-width:900px){.login-page{padding:0;display:flex;flex-direction:column-reverse;gap:0}.story-panel{min-height:220px;border-radius:0}.story-copy{display:none}.login-panel{padding:30px 24px;border:0;border-radius:26px 26px 0 0;margin-top:-24px;z-index:1;background:var(--cream)}.login-card{max-width:460px}.brand-motto{margin-bottom:26px}}
</style>

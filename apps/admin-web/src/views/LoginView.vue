<script setup lang="ts">
import { ElMessage } from 'element-plus'
import { reactive } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()
const credentials = reactive({
  account: '',
  password: '',
})

function enterDashboard() {
  if (!credentials.account.trim() || !credentials.password.trim()) {
    ElMessage.warning('请填写运营账号和密码')
    return
  }
  auth.enterDemo()
  const redirect = String(route.query.redirect ?? '/dashboard')
  router.replace(redirect)
}

function enterDemo() {
  auth.enterDemo()
  router.replace('/dashboard')
}
</script>

<template>
  <main class="login-page">
    <section class="story-panel">
      <div class="story-brand">
        <div class="story-mark">满</div>
        <div>
          <strong>小满冰箱</strong>
          <span>SMART FRIDGE OPS</span>
        </div>
      </div>

      <div class="story-copy">
        <p class="eyebrow">OPERATIONS, MADE WARM</p>
        <h1>把每一条数据，<br />都放回生活里。</h1>
        <p class="lead">
          从菜谱内容、临期趋势到补货订单，在同一个温暖的工作台里看见家庭的真实使用节奏。
        </p>
      </div>

      <div class="fridge-stage" aria-hidden="true">
        <div class="fridge-shadow" />
        <div class="fridge-body">
          <div class="fridge-handle" />
          <div class="fridge-divider" />
          <div class="fridge-shelf top">
            <span>🍅</span>
            <span>🥬</span>
            <span>🥛</span>
          </div>
          <div class="fridge-shelf bottom">
            <span>🥚</span>
            <span>🫐</span>
          </div>
        </div>
        <div class="floating-note">
          <span>今日临期</span>
          <strong>3 份食材</strong>
          <small>已自动生成优先菜谱</small>
        </div>
        <div class="floating-metric">
          <small>家庭活跃</small>
          <strong>+18.4%</strong>
        </div>
      </div>

      <div class="story-footer">
        <span>Flutter</span>
        <i />
        <span>Vue 3</span>
        <i />
        <span>Spring Cloud Alibaba</span>
      </div>
    </section>

    <section class="login-panel">
      <div class="login-card">
        <div class="mobile-brand">
          <div class="story-mark">满</div>
          <strong>小满冰箱</strong>
        </div>
        <p class="form-kicker">WELCOME BACK</p>
        <h2>进入运营工作台</h2>
        <p class="form-description">
          管理菜谱、商品、优惠券和补货订单。当前工程阶段提供演示入口，待运营角色接口完成后切换真实登录。
        </p>

        <label class="field-label" for="account">运营账号</label>
        <el-input
          id="account"
          v-model="credentials.account"
          size="large"
          placeholder="请输入管理员账号"
        >
          <template #prefix>
            <span class="field-icon">◎</span>
          </template>
        </el-input>

        <label class="field-label" for="password">密码</label>
        <el-input
          id="password"
          v-model="credentials.password"
          size="large"
          type="password"
          show-password
          placeholder="请输入密码"
          @keyup.enter="enterDashboard"
        >
          <template #prefix>
            <span class="field-icon">⌾</span>
          </template>
        </el-input>

        <div class="form-options">
          <el-checkbox checked disabled>保持当前会话</el-checkbox>
          <button type="button" class="text-link">忘记密码</button>
        </div>

        <el-button type="primary" size="large" class="login-button" @click="enterDashboard">
          登录工作台
        </el-button>
        <el-button size="large" class="demo-button" @click="enterDemo">
          直接进入演示后台
        </el-button>

        <div class="security-note">
          <span>✓</span>
          当前为本地演示环境，不会提交真实账号数据
        </div>
      </div>
      <p class="copyright">Smart Fridge Engineering Preview · 0.1.0</p>
    </section>
  </main>
</template>

<style scoped>
.login-page {
  display: grid;
  min-height: 100vh;
  grid-template-columns: minmax(430px, 1.15fr) minmax(420px, 0.85fr);
  background: #f3efe6;
}

.story-panel {
  position: relative;
  display: flex;
  overflow: hidden;
  min-height: 100vh;
  padding: 42px clamp(38px, 6vw, 84px);
  flex-direction: column;
  color: #f7f2ea;
  background:
    radial-gradient(circle at 85% 4%, rgba(185, 105, 78, 0.34), transparent 29%),
    radial-gradient(circle at 6% 92%, rgba(126, 153, 116, 0.18), transparent 26%),
    #352c26;
}

.story-panel::after {
  position: absolute;
  inset: 0;
  pointer-events: none;
  content: '';
  background-image: linear-gradient(rgba(255, 255, 255, 0.025) 1px, transparent 1px);
  background-size: 100% 54px;
}

.story-brand {
  position: relative;
  z-index: 2;
  display: flex;
  align-items: center;
  gap: 12px;
}

.story-mark {
  display: grid;
  width: 43px;
  height: 43px;
  place-items: center;
  border-radius: 14px;
  color: #352c26;
  background: #e5c5a3;
  font-family: 'Songti SC', serif;
  font-size: 21px;
  font-weight: 900;
}

.story-brand strong,
.story-brand span {
  display: block;
}

.story-brand strong {
  font-size: 17px;
}

.story-brand span {
  margin-top: 2px;
  color: rgba(247, 242, 234, 0.35);
  font-size: 8px;
  font-weight: 700;
  letter-spacing: 0.18em;
}

.story-copy {
  position: relative;
  z-index: 2;
  max-width: 570px;
  margin-top: clamp(54px, 10vh, 105px);
}

.eyebrow,
.form-kicker {
  margin: 0 0 14px;
  color: #d29777;
  font-size: 9px;
  font-weight: 850;
  letter-spacing: 0.2em;
}

.story-copy h1 {
  margin: 0;
  font-family: 'Songti SC', 'STSong', serif;
  font-size: clamp(44px, 5.3vw, 72px);
  font-weight: 900;
  line-height: 1.08;
  letter-spacing: -0.065em;
}

.lead {
  max-width: 470px;
  margin: 24px 0 0;
  color: rgba(247, 242, 234, 0.58);
  font-size: 13px;
  line-height: 1.9;
}

.fridge-stage {
  position: relative;
  z-index: 2;
  width: min(530px, 92%);
  height: 235px;
  margin-top: 24px;
}

.fridge-shadow {
  position: absolute;
  left: 32px;
  bottom: 8px;
  width: 240px;
  height: 22px;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.26);
  filter: blur(10px);
}

.fridge-body {
  position: absolute;
  left: 54px;
  bottom: 20px;
  width: 176px;
  height: 206px;
  border: 4px solid rgba(255, 255, 255, 0.16);
  border-radius: 24px 24px 17px 17px;
  background: linear-gradient(145deg, #ddc7ae, #bfa58c);
  box-shadow:
    20px 18px 0 -2px #977f6c,
    28px 30px 36px rgba(0, 0, 0, 0.25);
}

.fridge-handle {
  position: absolute;
  top: 26px;
  right: 18px;
  width: 5px;
  height: 47px;
  border-radius: 10px;
  background: #5b4336;
}

.fridge-divider {
  position: absolute;
  top: 92px;
  right: 12px;
  left: 12px;
  height: 2px;
  background: rgba(91, 67, 54, 0.28);
}

.fridge-shelf {
  position: absolute;
  display: flex;
  right: 13px;
  left: 13px;
  align-items: flex-end;
  justify-content: space-evenly;
  border-radius: 12px;
  background: rgba(255, 252, 247, 0.72);
}

.fridge-shelf.top {
  top: 52px;
  height: 38px;
  font-size: 25px;
}

.fridge-shelf.bottom {
  bottom: 14px;
  height: 75px;
  font-size: 33px;
}

.floating-note,
.floating-metric {
  position: absolute;
  border: 1px solid rgba(255, 255, 255, 0.13);
  background: rgba(255, 253, 249, 0.92);
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2);
}

.floating-note {
  top: 37px;
  left: 268px;
  width: 184px;
  padding: 16px;
  border-radius: 18px;
  color: #4d4037;
}

.floating-note span,
.floating-note strong,
.floating-note small,
.floating-metric small,
.floating-metric strong {
  display: block;
}

.floating-note span {
  color: #a78e7e;
  font-size: 9px;
}

.floating-note strong {
  margin-top: 6px;
  font-size: 17px;
}

.floating-note small {
  margin-top: 9px;
  color: #8b786a;
  font-size: 8px;
}

.floating-metric {
  right: 10px;
  bottom: 14px;
  padding: 12px 16px;
  border-radius: 15px;
  color: #4d4037;
}

.floating-metric small {
  color: #9f8d7f;
  font-size: 8px;
}

.floating-metric strong {
  margin-top: 3px;
  color: #71836b;
  font-size: 14px;
}

.story-footer {
  position: relative;
  z-index: 2;
  display: flex;
  margin-top: auto;
  align-items: center;
  gap: 11px;
  color: rgba(247, 242, 234, 0.33);
  font-size: 8px;
  font-weight: 700;
  letter-spacing: 0.06em;
}

.story-footer i {
  width: 3px;
  height: 3px;
  border-radius: 50%;
  background: rgba(247, 242, 234, 0.22);
}

.login-panel {
  display: flex;
  min-height: 100vh;
  padding: 42px 28px 24px;
  align-items: center;
  flex-direction: column;
  justify-content: center;
}

.login-card {
  width: min(394px, 100%);
}

.mobile-brand {
  display: none;
}

.form-kicker {
  color: #b85c45;
}

.login-card h2 {
  margin: 0;
  color: #352c26;
  font-family: 'Songti SC', 'STSong', serif;
  font-size: 34px;
  letter-spacing: -0.05em;
}

.form-description {
  margin: 12px 0 28px;
  color: #8a7b70;
  font-size: 11px;
  line-height: 1.8;
}

.field-label {
  display: block;
  margin: 15px 0 7px;
  color: #5b4336;
  font-size: 10px;
  font-weight: 750;
}

.field-icon {
  color: #a69588;
}

.form-options {
  display: flex;
  margin: 13px 0 19px;
  align-items: center;
  justify-content: space-between;
}

.form-options :deep(.el-checkbox__label) {
  color: #8a7b70;
  font-size: 9px;
}

.text-link {
  border: 0;
  color: #b85c45;
  background: transparent;
  font-size: 9px;
  cursor: pointer;
}

.login-button,
.demo-button {
  width: 100%;
  margin-left: 0 !important;
}

.login-button {
  height: 48px;
  border-radius: 14px;
}

.demo-button {
  height: 44px;
  margin-top: 9px !important;
  border-color: #ded3c6;
  border-radius: 14px;
  color: #6d5c50;
  background: transparent;
}

.security-note {
  display: flex;
  margin-top: 18px;
  align-items: center;
  gap: 7px;
  justify-content: center;
  color: #a19286;
  font-size: 8px;
}

.security-note span {
  display: grid;
  width: 16px;
  height: 16px;
  place-items: center;
  border-radius: 50%;
  background: #e8f0e5;
  color: #71836b;
  font-size: 8px;
}

.copyright {
  margin: 42px 0 0;
  color: #b5a99f;
  font-size: 8px;
}

@media (max-width: 900px) {
  .login-page {
    display: block;
  }

  .story-panel {
    display: none;
  }

  .login-panel {
    padding: 30px 22px;
    background:
      radial-gradient(circle at 100% 0%, rgba(220, 179, 144, 0.28), transparent 28%),
      #f3efe6;
  }

  .mobile-brand {
    display: flex;
    margin-bottom: 46px;
    align-items: center;
    gap: 10px;
    color: #4e3e34;
  }
}
</style>

<script setup lang="ts">
import type { EChartsCoreOption } from 'echarts/core'
import { computed } from 'vue'
import ChartPanel from '../components/ChartPanel.vue'

const metrics = [
  {
    label: '注册用户',
    value: '12,840',
    trend: '+18.4%',
    note: '较上周',
    glyph: '◎',
    tone: 'coral',
  },
  {
    label: '活跃家庭',
    value: '3,286',
    trend: '+12.1%',
    note: '近 7 日活跃',
    glyph: '⌂',
    tone: 'sage',
  },
  {
    label: '临期食材',
    value: '6,921',
    trend: '28.7%',
    note: '占在库食材',
    glyph: '◷',
    tone: 'amber',
  },
  {
    label: '今日交易额',
    value: '¥ 24,580',
    trend: '+8.6%',
    note: '补货订单',
    glyph: '◫',
    tone: 'cocoa',
  },
]

const alerts = [
  {
    level: '临期',
    content: '番茄 · 冷藏区 · 剩余 2 天',
    family: '小满的家',
    time: '09:42',
    tone: 'danger',
  },
  {
    level: '库存',
    content: '云南小番茄库存低于安全线',
    family: '平台库存',
    time: '09:16',
    tone: 'warning',
  },
  {
    level: '内容',
    content: '新菜谱《蒜蓉生菜》等待审核',
    family: '内容中心',
    time: '08:51',
    tone: 'success',
  },
  {
    level: '订单',
    content: '补货订单 SF202610260017 已支付',
    family: '阿满的家',
    time: '08:24',
    tone: 'success',
  },
]

const userTrendOption = computed<EChartsCoreOption>(() => ({
  animationDuration: 700,
  tooltip: {
    trigger: 'axis',
    backgroundColor: 'rgba(53, 44, 38, 0.92)',
    borderWidth: 0,
    textStyle: { color: '#fffaf3', fontSize: 11 },
  },
  grid: { left: 12, right: 12, top: 22, bottom: 8, containLabel: true },
  xAxis: {
    type: 'category',
    boundaryGap: false,
    data: ['10/20', '10/21', '10/22', '10/23', '10/24', '10/25', '今天'],
    axisLine: { lineStyle: { color: '#e9e0d5' } },
    axisTick: { show: false },
    axisLabel: { color: '#9b8c80', fontSize: 9 },
  },
  yAxis: {
    type: 'value',
    splitLine: { lineStyle: { color: '#f0e9df' } },
    axisLabel: { color: '#a7988c', fontSize: 9 },
  },
  series: [
    {
      name: '用户',
      type: 'line',
      smooth: true,
      symbol: 'circle',
      symbolSize: 5,
      data: [820, 1040, 980, 1320, 1460, 1580, 1710],
      lineStyle: { width: 3, color: '#b85c45' },
      itemStyle: { color: '#b85c45', borderColor: '#fffdf9', borderWidth: 2 },
      areaStyle: {
        color: {
          type: 'linear',
          x: 0,
          y: 0,
          x2: 0,
          y2: 1,
          colorStops: [
            { offset: 0, color: 'rgba(184, 92, 69, 0.24)' },
            { offset: 1, color: 'rgba(184, 92, 69, 0.01)' },
          ],
        },
      },
    },
    {
      name: '家庭',
      type: 'line',
      smooth: true,
      symbol: 'none',
      data: [320, 390, 420, 510, 560, 610, 680],
      lineStyle: { width: 2, color: '#71836b', type: 'dashed' },
    },
  ],
}))

const orderOption = computed<EChartsCoreOption>(() => ({
  tooltip: {
    trigger: 'item',
    backgroundColor: 'rgba(53, 44, 38, 0.92)',
    borderWidth: 0,
    textStyle: { color: '#fffaf3', fontSize: 11 },
  },
  legend: {
    orient: 'vertical',
    right: 8,
    top: 'center',
    icon: 'circle',
    itemWidth: 7,
    itemHeight: 7,
    textStyle: { color: '#7f7065', fontSize: 10 },
  },
  series: [
    {
      type: 'pie',
      radius: ['51%', '72%'],
      center: ['36%', '50%'],
      avoidLabelOverlap: true,
      itemStyle: { borderColor: '#fffdf9', borderWidth: 4 },
      label: { show: false },
      emphasis: { scale: true, scaleSize: 4 },
      data: [
        { value: 48, name: '已支付', itemStyle: { color: '#71836b' } },
        { value: 26, name: '待支付', itemStyle: { color: '#e0b476' } },
        { value: 16, name: '配送中', itemStyle: { color: '#b85c45' } },
        { value: 10, name: '已取消', itemStyle: { color: '#d7cbc0' } },
      ],
    },
  ],
}))
</script>

<template>
  <div class="page-shell dashboard">
    <div class="page-heading">
      <div>
        <p class="page-kicker">TODAY'S OVERVIEW</p>
        <h1 class="page-title">早上好，运营同学</h1>
        <p class="page-description">
          家庭的每一顿饭都在产生新数据。这里是今天的经营与内容动态。
        </p>
      </div>
      <div class="heading-actions">
        <el-button>导出报表</el-button>
        <el-button type="primary">生成运营简报</el-button>
      </div>
    </div>

    <section class="insight-hero">
      <div>
        <span class="hero-kicker">SMART INSIGHT</span>
        <h2>临期食材正在被更好地使用</h2>
        <p>
          今天有 62.8% 的临期食材被加入推荐菜谱，家庭补货转化率较上周提升 4.2%。
          “番茄滑蛋”成为本时段最受欢迎的推荐。
        </p>
      </div>
      <div class="hero-number">
        <strong>62.8%</strong>
        <span>临期优先使用率</span>
      </div>
      <div class="hero-orbit orbit-one" />
      <div class="hero-orbit orbit-two" />
    </section>

    <section class="metric-grid">
      <article v-for="metric in metrics" :key="metric.label" class="metric-card">
        <div class="metric-topline">
          <span class="metric-glyph" :class="metric.tone">{{ metric.glyph }}</span>
          <span class="metric-trend">{{ metric.trend }}</span>
        </div>
        <strong class="metric-value">{{ metric.value }}</strong>
        <div class="metric-footer">
          <span>{{ metric.label }}</span>
          <small>{{ metric.note }}</small>
        </div>
      </article>
    </section>

    <section class="chart-grid">
      <article class="panel">
        <div class="panel-heading">
          <div>
            <h2 class="panel-title">家庭增长趋势</h2>
            <p class="panel-subtitle">近 7 日新增用户与活跃家庭</p>
          </div>
          <span class="soft-tag success">↗ 稳定增长</span>
        </div>
        <ChartPanel :option="userTrendOption" />
      </article>
      <article class="panel">
        <div class="panel-heading">
          <div>
            <h2 class="panel-title">补货订单状态</h2>
            <p class="panel-subtitle">今日共 186 笔订单</p>
          </div>
          <span class="soft-tag">实时</span>
        </div>
        <ChartPanel :option="orderOption" />
      </article>
    </section>

    <section class="bottom-grid">
      <article class="panel alerts-panel">
        <div class="panel-heading">
          <div>
            <h2 class="panel-title">需要关注</h2>
            <p class="panel-subtitle">临期、库存、内容与订单的实时提醒</p>
          </div>
          <button class="quiet-link">查看全部 →</button>
        </div>
        <div class="alert-list">
          <div v-for="alert in alerts" :key="alert.content" class="alert-row">
            <span class="alert-level" :class="alert.tone">{{ alert.level }}</span>
            <div class="alert-copy">
              <strong>{{ alert.content }}</strong>
              <small>{{ alert.family }}</small>
            </div>
            <time>{{ alert.time }}</time>
          </div>
        </div>
      </article>

      <article class="panel recipe-rank">
        <div class="panel-heading">
          <div>
            <h2 class="panel-title">内容热度</h2>
            <p class="panel-subtitle">本周推荐菜谱</p>
          </div>
          <span class="soft-tag warning">TOP 3</span>
        </div>
        <div class="rank-item">
          <span class="rank-number">01</span>
          <span class="rank-emoji">🍅</span>
          <div>
            <strong>番茄滑蛋</strong>
            <small>1,284 次加入做饭计划</small>
          </div>
        </div>
        <div class="rank-item">
          <span class="rank-number">02</span>
          <span class="rank-emoji">🥬</span>
          <div>
            <strong>蒜蓉生菜</strong>
            <small>986 次加入做饭计划</small>
          </div>
        </div>
        <div class="rank-item">
          <span class="rank-number">03</span>
          <span class="rank-emoji">🥟</span>
          <div>
            <strong>家常煎饺</strong>
            <small>743 次加入做饭计划</small>
          </div>
        </div>
      </article>
    </section>
  </div>
</template>

<style scoped>
.heading-actions {
  display: flex;
  gap: 9px;
}

.insight-hero {
  position: relative;
  display: flex;
  overflow: hidden;
  min-height: 174px;
  padding: 26px 30px;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
  border-radius: 25px;
  color: #f7f2ea;
  background:
    radial-gradient(circle at 88% 15%, rgba(185, 105, 78, 0.3), transparent 30%),
    #352c26;
  box-shadow: 0 22px 48px rgba(53, 44, 38, 0.14);
}

.insight-hero > div:first-child {
  position: relative;
  z-index: 2;
  max-width: 650px;
}

.hero-kicker {
  color: #d59b7a;
  font-size: 8px;
  font-weight: 800;
  letter-spacing: 0.18em;
}

.insight-hero h2 {
  margin: 9px 0 8px;
  font-family: 'Songti SC', serif;
  font-size: clamp(20px, 2vw, 28px);
}

.insight-hero p {
  margin: 0;
  color: rgba(247, 242, 234, 0.56);
  font-size: 10px;
  line-height: 1.75;
}

.hero-number {
  position: relative;
  z-index: 2;
  min-width: 130px;
  text-align: right;
}

.hero-number strong,
.hero-number span {
  display: block;
}

.hero-number strong {
  color: #e9c9a8;
  font-family: 'Songti SC', serif;
  font-size: 36px;
}

.hero-number span {
  margin-top: 4px;
  color: rgba(247, 242, 234, 0.45);
  font-size: 8px;
}

.hero-orbit {
  position: absolute;
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 50%;
}

.orbit-one {
  right: -70px;
  width: 320px;
  height: 320px;
}

.orbit-two {
  right: 30px;
  width: 190px;
  height: 190px;
}

.metric-grid {
  display: grid;
  gap: 13px;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.metric-card {
  padding: 17px;
  border: 1px solid rgba(91, 67, 54, 0.07);
  border-radius: 19px;
  background: rgba(255, 253, 249, 0.86);
  box-shadow: 0 12px 32px rgba(70, 52, 40, 0.045);
}

.metric-topline {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.metric-glyph {
  display: grid;
  width: 30px;
  height: 30px;
  place-items: center;
  border-radius: 10px;
  font-weight: 800;
}

.metric-glyph.coral {
  color: #a55340;
  background: #f5dfd7;
}

.metric-glyph.sage {
  color: #64785e;
  background: #e5ede1;
}

.metric-glyph.amber {
  color: #9c6c31;
  background: #f7ead4;
}

.metric-glyph.cocoa {
  color: #5b4336;
  background: #eee5da;
}

.metric-trend {
  color: #71836b;
  font-size: 9px;
  font-weight: 750;
}

.metric-value {
  display: block;
  margin: 17px 0 8px;
  color: #352c26;
  font-family: 'Songti SC', serif;
  font-size: 25px;
}

.metric-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  color: #7b6c61;
  font-size: 9px;
}

.metric-footer small {
  color: #b0a298;
  font-size: 8px;
}

.chart-grid {
  display: grid;
  gap: 15px;
  grid-template-columns: minmax(0, 1.5fr) minmax(270px, 0.85fr);
}

.bottom-grid {
  display: grid;
  gap: 15px;
  grid-template-columns: minmax(0, 1.35fr) minmax(280px, 0.65fr);
}

.quiet-link {
  border: 0;
  color: #8d7b6e;
  background: transparent;
  font-size: 9px;
  cursor: pointer;
}

.alert-list {
  display: flex;
  flex-direction: column;
}

.alert-row {
  display: flex;
  padding: 11px 2px;
  align-items: center;
  gap: 11px;
  border-bottom: 1px solid #f0e9df;
}

.alert-row:last-child {
  border-bottom: 0;
}

.alert-level {
  min-width: 38px;
  padding: 4px 7px;
  border-radius: 99px;
  text-align: center;
  font-size: 8px;
  font-weight: 750;
}

.alert-level.danger {
  color: #a34b55;
  background: #f8e4e3;
}

.alert-level.warning {
  color: #9c6c31;
  background: #f8ead9;
}

.alert-level.success {
  color: #5f775a;
  background: #e8f0e5;
}

.alert-copy {
  min-width: 0;
  flex: 1;
}

.alert-copy strong,
.alert-copy small {
  display: block;
}

.alert-copy strong {
  overflow: hidden;
  color: #51453d;
  font-size: 10px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.alert-copy small {
  margin-top: 3px;
  color: #a6998f;
  font-size: 8px;
}

.alert-row time {
  color: #b3a69c;
  font-size: 8px;
}

.rank-item {
  display: flex;
  padding: 13px 0;
  align-items: center;
  gap: 10px;
  border-bottom: 1px solid #f0e9df;
}

.rank-item:last-child {
  border-bottom: 0;
}

.rank-number {
  color: #c3b5aa;
  font-family: Georgia, serif;
  font-size: 10px;
}

.rank-emoji {
  display: grid;
  width: 39px;
  height: 39px;
  place-items: center;
  border-radius: 12px;
  background: #f4eee5;
  font-size: 21px;
}

.rank-item strong,
.rank-item small {
  display: block;
}

.rank-item strong {
  color: #51453d;
  font-size: 10px;
}

.rank-item small {
  margin-top: 3px;
  color: #a6998f;
  font-size: 8px;
}

@media (max-width: 1200px) {
  .metric-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .chart-grid,
  .bottom-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 600px) {
  .heading-actions {
    width: 100%;
  }

  .heading-actions :deep(.el-button) {
    flex: 1;
  }

  .insight-hero {
    align-items: flex-start;
    flex-direction: column;
  }

  .hero-number {
    text-align: left;
  }

  .metric-grid {
    grid-template-columns: 1fr 1fr;
  }
}
</style>

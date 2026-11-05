<script setup lang="ts">
import { LineChart, PieChart } from 'echarts/charts'
import {
  GridComponent,
  LegendComponent,
  TooltipComponent,
} from 'echarts/components'
import {
  init,
  use,
  type ECharts,
  type EChartsCoreOption,
} from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { onActivated, onBeforeUnmount, onMounted, ref, watch } from 'vue'

use([
  LineChart,
  PieChart,
  GridComponent,
  LegendComponent,
  TooltipComponent,
  CanvasRenderer,
])

const props = defineProps<{
  option: EChartsCoreOption
}>()

const chartElement = ref<HTMLDivElement>()
let chart: ECharts | undefined
let observer: ResizeObserver | undefined
const motion = window.matchMedia('(prefers-reduced-motion: reduce)')
const applyOption = () => chart?.setOption({ ...props.option, animation: !motion.matches }, true)

onMounted(() => {
  if (!chartElement.value) return
  chart = init(chartElement.value, undefined, { renderer: 'canvas' })
  applyOption()
  motion.addEventListener('change', applyOption)
  observer = new ResizeObserver(() => { if (chartElement.value?.clientWidth) chart?.resize() })
  observer.observe(chartElement.value)
})

watch(
  () => props.option,
  applyOption,
  { deep: true },
)

onBeforeUnmount(() => {
  motion.removeEventListener('change', applyOption)
  observer?.disconnect()
  chart?.dispose()
})

onActivated(() => { if (chartElement.value?.clientWidth) chart?.resize() })
</script>

<template>
  <div ref="chartElement" class="chart-panel" />
</template>

<style scoped>
.chart-panel {
  width: 100%;
  height: 270px;
}
</style>

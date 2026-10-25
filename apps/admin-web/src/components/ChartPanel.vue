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
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'

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

onMounted(() => {
  if (!chartElement.value) return
  chart = init(chartElement.value, undefined, { renderer: 'canvas' })
  chart.setOption(props.option)
  observer = new ResizeObserver(() => chart?.resize())
  observer.observe(chartElement.value)
})

watch(
  () => props.option,
  (option) => chart?.setOption(option, true),
  { deep: true },
)

onBeforeUnmount(() => {
  observer?.disconnect()
  chart?.dispose()
})
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

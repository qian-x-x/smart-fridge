import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

export const useAuthStore = defineStore('admin-auth', () => {
  const token = ref(sessionStorage.getItem('smart-fridge-admin-token') ?? '')
  const displayName = ref(
    sessionStorage.getItem('smart-fridge-admin-name') ?? '',
  )
  const isAuthenticated = computed(() => token.value.length > 0)

  function enterDemo() {
    token.value = 'admin-demo-session'
    displayName.value = '运营管理员'
    sessionStorage.setItem('smart-fridge-admin-token', token.value)
    sessionStorage.setItem('smart-fridge-admin-name', displayName.value)
  }

  function logout() {
    token.value = ''
    displayName.value = ''
    sessionStorage.removeItem('smart-fridge-admin-token')
    sessionStorage.removeItem('smart-fridge-admin-name')
  }

  return { token, displayName, isAuthenticated, enterDemo, logout }
})

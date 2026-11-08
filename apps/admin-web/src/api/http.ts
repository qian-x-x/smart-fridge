import axios from 'axios'

/**
 * Gateway address used by the console.
 *
 * The gateway is published on port 8080 of the same machine that serves this
 * page, so deriving it from `window.location` keeps the console working over
 * the LAN instead of always calling the viewer's own localhost. Set
 * `VITE_API_BASE_URL` to pin an explicit gateway (different host, https, ...).
 */
const configuredBaseUrl = import.meta.env.VITE_API_BASE_URL?.trim()

export const apiBaseUrl =
  configuredBaseUrl && configuredBaseUrl.length > 0
    ? configuredBaseUrl
    : `${window.location.protocol}//${window.location.hostname}:8080`

export const http = axios.create({
  baseURL: apiBaseUrl,
  timeout: 12_000,
  headers: {
    Accept: 'application/json',
  },
})

http.interceptors.request.use((config) => {
  const token = sessionStorage.getItem('smart-fridge-admin-token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

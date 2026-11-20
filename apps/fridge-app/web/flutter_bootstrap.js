{{flutter_js}}
{{flutter_build_config}}

// Keep the entrypoint and bootstrap from the same build after a browser refresh.
const appBuild = {{flutter_service_worker_version}};
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) build.mainJsPath += `?v=${appBuild}`;
}

// Load the renderer bundled with this build, including on networks without CDN access.
const config = { canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href };

function reportStartupError(error) {
  console.error('Flutter startup failed', error);
  window.dispatchEvent(new Event('xiaoyi-startup-error'));
}

_flutter.loader.load({
  config,
  serviceWorkerSettings: window.isSecureContext ? { serviceWorkerVersion: appBuild } : undefined,
  onEntrypointLoaded: async (initializer) => {
    try {
      const app = await initializer.initializeEngine(config);
      await app.runApp();
    } catch (error) {
      reportStartupError(error);
    }
  },
}).catch(reportStartupError);

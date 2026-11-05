{{flutter_js}}
{{flutter_build_config}}

// Keep the entrypoint and bootstrap from the same build after a browser refresh.
const appBuild = {{flutter_service_worker_version}};
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) build.mainJsPath += `?v=${appBuild}`;
}
_flutter.loader.load({
  serviceWorkerSettings: { serviceWorkerVersion: appBuild }
});

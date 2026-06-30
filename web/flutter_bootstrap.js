{{flutter_js}}
{{flutter_build_config}}

// 国内网络无法访问 gstatic.com，强制从本地 canvaskit/ 加载 WASM/JS。
// 开发/打包均需加 --no-web-resources-cdn，否则本地无 canvaskit 文件。
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      // 禁止引擎向 fonts.gstatic.com 拉取 Roboto 等 fallback 字体
      fontFallbackBaseUrl: '',
    });
    await appRunner.runApp();
  },
});

# Published game verification

Game source: `5760467`. Publishing run: https://github.com/trippletee20/INSIDELASU/actions/runs/39770349957 (successful build and deployment).

Live link: https://trippletee20.github.io/INSIDELASU/play/index.html?v=5760467

The actual public site passed the touch Chromium journey at device pixel ratio 3, desktop Chromium profile/wallet/receipt/save/menu tests, and the advertising preview journey. Captured runtime errors: zero. HTTPS certificate verification remained enabled.

The desktop launcher override uses the system HTTPS proxy and verified CA through urllib in this environment; Node route.fetch could not resolve the public hostname directly. This is a test-harness change, not a gameplay change.

Mobile browser emulation does not establish performance on physical Android hardware. Advertising checkout is disabled; no real payment was made.

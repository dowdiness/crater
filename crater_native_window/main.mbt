///|
/// Crater Native Window - Full browser window with crater rendering
///
/// Uses justjavac/webview to display crater-rendered content
/// in a native desktop window.

///|
fn main {
  let html = #|<!DOCTYPE html>
  #|<html lang="en">
  #|<head>
  #|  <meta charset="UTF-8">
  #|  <title>Crater Browser</title>
  #|  <style>
  #|    * { margin: 0; padding: 0; box-sizing: border-box; }
  #|    body {
  #|      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  #|      background: #1a1a2e;
  #|      color: #e0e0e0;
  #|      padding: 40px;
  #|    }
  #|    .header {
  #|      text-align: center;
  #|      padding: 40px;
  #|      background: linear-gradient(135deg, #16213e, #0f3460);
  #|      border-radius: 16px;
  #|      margin-bottom: 24px;
  #|    }
  #|    h1 { font-size: 2.5em; color: #e94560; margin-bottom: 8px; }
  #|    .subtitle { color: #8899aa; font-size: 1.1em; }
  #|    .info-grid {
  #|      display: grid;
  #|      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  #|      gap: 16px;
  #|      margin-top: 24px;
  #|    }
  #|    .card {
  #|      background: #16213e;
  #|      border-radius: 12px;
  #|      padding: 20px;
  #|      border: 1px solid #0f3460;
  #|    }
  #|    .card h3 { color: #e94560; margin-bottom: 8px; font-size: 0.9em;
  #|               text-transform: uppercase; letter-spacing: 1px; }
  #|    .card .value { font-size: 1.2em; }
  #|    .badge {
  #|      display: inline-block;
  #|      background: #e94560;
  #|      color: white;
  #|      padding: 4px 12px;
  #|      border-radius: 20px;
  #|      font-size: 0.8em;
  #|      margin-top: 8px;
  #|    }
  #|    .status {
  #|      margin-top: 24px;
  #|      padding: 16px;
  #|      background: #0f3460;
  #|      border-radius: 12px;
  #|      text-align: center;
  #|    }
  #|    .status .check { color: #4ecca3; }
  #|  </style>
  #|</head>
  #|<body>
  #|  <div class="header">
  #|    <h1>Crater Browser</h1>
  #|    <p class="subtitle">Pure MoonBit browser engine</p>
  #|  </div>
  #|  <div class="info-grid">
  #|    <div class="card">
  #|      <h3>JS Engine</h3>
  #|      <div class="value">dowdiness/js_engine</div>
  #|      <div class="badge">MoonBit Native</div>
  #|    </div>
  #|    <div class="card">
  #|      <h3>Layout</h3>
  #|      <div class="value">crater-layout (Taffy)</div>
  #|      <div class="badge">94% WPT CSS</div>
  #|    </div>
  #|    <div class="card">
  #|      <h3>Window</h3>
  #|      <div class="value">justjavac/webview</div>
  #|      <div class="badge">Cross-platform</div>
  #|    </div>
  #|    <div class="card">
  #|      <h3>Runtime</h3>
  #|      <div class="value">MoonBit Native</div>
  #|      <div class="badge">C → binary</div>
  #|    </div>
  #|  </div>
  #|  <div class="status">
  #|    <p><span class="check">OK</span> MoonBit native window</p>
  #|  </div>
  #|</body>
  #|</html>

  let wv = @webview.Webview::new(debug=1)
  wv.set_title("Crater Browser")
  wv.set_size(1024, 768, @webview.SizeHint::None)
  wv.set_html(html)
  wv.run()
}

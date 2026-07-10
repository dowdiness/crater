///|
/// Crater Native Window - Web page browser
///
/// Usage: moon run crater_native_window --target native [url]

///|
fn main {
  // デフォルトURL
  let default_url = "https://example.com"

  // コマンドライン引数からURLを取得
  // MoonBitの @env.args() で引数が取れる
  let args = @env.args()
  let url = if args.length() > 1 {
    args[1]
  } else {
    default_url
  }

  let wv = @webview.Webview::new(debug=0)
  wv.set_title("Crater Browser — " + url)
  wv.set_size(1024, 768, @webview.SizeHint::None)
  wv.navigate(url)
  wv.run()
}

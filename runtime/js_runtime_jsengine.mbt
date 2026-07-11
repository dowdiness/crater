///| Native JS runtime options:
///|
///|   Default: NativeStubRuntime   (NotSupported) — Browser::new() uses this
///|   Opt-in:  JsEngineRuntime     (this file)   — jsengine_runtime_ref()
///|   Ext.:    V8JsRuntime         (native FFI)  — mizchi/crater-browser-native/js_v8
///|
///| Usage:
///|   let browser = Browser::new(1024, 768)
///|   browser.set_js_runtime(jsengine_runtime_ref())
///|
/// Property key used to store NodeId on JS Element wrapper objects.
const CRATER_NODE_ID_KEY : String = "__crater_nid"

///|
priv struct JsEngineRuntime {
  _unused : Int
}

///|
let jsengine_runtime : JsEngineRuntime = { _unused: 0 }

///|
/// Get a reference to the js_engine runtime for opt-in use.
pub fn jsengine_runtime_ref() -> &JsRuntime {
  jsengine_runtime as &JsRuntime
}

///|
impl JsRuntime for JsEngineRuntime with fn init(self : JsEngineRuntime) -> Unit {
  let _ = self
}

///|
impl JsRuntime for JsEngineRuntime with fn execute(
  self : JsEngineRuntime,
  context_id : Int,
  dom : @dom.DomTree,
  code : String,
  async_mode : AsyncExecutionMode,
) -> JsResult raise JsError {
  let _ = (self, context_id, async_mode)
  try {
    let interp = @interpreter.new_interpreter()
    inject_dom_bindings(interp.global, interp.realm_state, dom)
    let prog = @parser.parse(code)
    let result = interp.run(prog.stmts)
    interp.run_microtasks()
    interp.run_timers()
    JsResult::new(result.to_string(), interp.host.output, true)
  } catch {
    e => raise JsError::ExecutionError(describe_js_engine_error(e))
  }
}

// ═══════════════════════════════════════════════
// JsRuntime trait — remaining methods
// ═══════════════════════════════════════════════

///|
impl JsRuntime for JsEngineRuntime with fn tick(
  self : JsEngineRuntime,
  context_id : Int,
  dom : @dom.DomTree,
) -> JsResult raise JsError {
  let _ = (self, context_id, dom)
  JsResult::new("false", [], true)
}

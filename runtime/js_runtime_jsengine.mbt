///|
/// JavaScript Runtime - js_engine implementation
///
/// Uses dowdiness/js_engine (pure MoonBit JavaScript interpreter)
/// for JavaScript execution on the native target.
///
/// For now, executes plain JavaScript without DOM bindings.
/// console.log output is captured and returned as JsResult logs.
/// The return value is serialized to a string.
///
/// Future phases will:
/// 1. Register console.log, document.createElement etc. as native
///    MoonBit functions in the js_engine interpreter global scope
/// 2. Use the existing dom_serializer.mbt to initialize the DOM state
/// 3. Send DOM operations back as JSON and apply them via apply_dom_ops

///|
priv struct JsEngineRuntime {
  _unused : Int
}

///|
let jsengine_runtime : JsEngineRuntime = { _unused: 0 }

///|
fn allocate_runtime_context_id() -> Int {
  0
}

///|
fn default_js_runtime() -> &JsRuntime {
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
  let _ = (self, context_id, dom, async_mode)
  try {
    let (output, result_str) = @js_engine.run(code)
    JsResult::new(result_str, output, true)
  } catch {
    e => raise JsError::ExecutionError(describe_js_engine_error(e))
  }
}

///|
/// Format a js_engine error for Crater's JsError type.
/// Extracts the error name and message when possible.
fn describe_js_engine_error(err : Error) -> String {
  @js_errors.name_message_if_js_error(err).map_or(err.to_string(), fn(pair) {
    let (name, msg) = pair
    name + ": " + msg
  })
}

///|
impl JsRuntime for JsEngineRuntime with fn tick(
  self : JsEngineRuntime,
  context_id : Int,
  dom : @dom.DomTree,
) -> JsResult raise JsError {
  let _ = (self, context_id, dom)
  JsResult::new("false", [], true)
}

///|
pub fn init_js_runtime() -> Unit {
  jsengine_runtime.init()
}

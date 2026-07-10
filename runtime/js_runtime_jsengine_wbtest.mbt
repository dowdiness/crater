///|
/// Test: JsEngine Runtime Integration
///
/// Verifies that the js_engine-based JsRuntime implementation
/// can execute basic JavaScript code on the native target.

///|
test "jsengine executes basic arithmetic" {
  let dom = @dom.DomTree::new()
  let result = JsContext::new(dom).execute("1 + 2")
  guard result.value == "3" else { fail("expected 3, got " + result.value) }
  guard result.success else { fail("expected success") }
}

///|
test "jsengine executes string operations" {
  let dom = @dom.DomTree::new()
  let result = JsContext::new(dom).execute("\"hello\".toUpperCase()")
  guard result.success else { fail("expected success: " + result.value) }
  guard result.value == "HELLO" else {
    fail("expected HELLO, got " + result.value)
  }
}

///|
test "jsengine captures console output" {
  let dom = @dom.DomTree::new()
  let result = JsContext::new(dom).execute("console.log(42)")
  guard result.success else { fail("expected success, got: " + result.value) }
  guard result.logs.length() > 0 else { fail("expected console output") }
  guard result.logs[0] == "42" else {
    fail("expected '42', got " + result.logs[0])
  }
}

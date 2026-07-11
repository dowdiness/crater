///|
/// Test: JsEngine Runtime Integration + DOM Bindings
///
/// Verifies that the js_engine-based JsRuntime implementation
/// can execute JavaScript with DOM bindings (querySelector, textContent).

///|
test "jsengine executes basic arithmetic" {
  let dom = @dom.DomTree::new()
  let result = JsContext::new(dom).execute("1 + 2")
  guard result.value == "3" else {
    fail("expected 3, got " + result.value)
  }
  guard result.success else {
    fail("expected success")
  }
}

///|
test "jsengine executes string operations" {
  let dom = @dom.DomTree::new()
  let result = JsContext::new(dom).execute("\"hello\".toUpperCase()")
  guard result.success else {
    fail("expected success: " + result.value)
  }
  guard result.value == "HELLO" else {
    fail("expected HELLO, got " + result.value)
  }
}

///|
test "jsengine captures console output" {
  let dom = @dom.DomTree::new()
  let result = JsContext::new(dom).execute("console.log(42)")
  guard result.success else {
    fail("expected success, got: " + result.value)
  }
  guard result.logs.length() > 0 else {
    fail("expected console output")
  }
  guard result.logs[0] == "42" else {
    fail("expected '42', got " + result.logs[0])
  }
}

///|
test "jsengine document.querySelector on simple DOM" {
  let dom = @dom.DomTree::new()
  // Create a simple DOM with an element
  let doc_id = dom.get_document()
  let html = dom.create_element("html")
  let _ = dom.append_child(doc_id, html)
  let body = dom.create_element("body")
  let _ = dom.append_child(html, body)
  let h1 = dom.create_element("h1")
  let _ = dom.set_attribute(h1, "id", "title")
  let _ = dom.append_child(body, h1)
  let text = dom.create_text("Hello World")
  let _ = dom.append_child(h1, text)

  // JS code that uses document.querySelector and textContent
  let js_code = #|var el = document.querySelector("#title");
  #|console.log(el.textContent);

  let result = JsContext::new(dom).execute(js_code)
  guard result.success else {
    fail("expected success: " + result.value)
  }
  guard result.logs.length() > 0 else {
    fail("expected console output")
  }
  guard result.logs[0] == "Hello World" else {
    fail("expected 'Hello World', got: " + result.logs[0])
  }
}

///|
test "jsengine document.getElementById on simple DOM" {
  let dom = @dom.DomTree::new()
  let doc_id = dom.get_document()
  let html = dom.create_element("html")
  let _ = dom.append_child(doc_id, html)
  let body = dom.create_element("body")
  let _ = dom.append_child(html, body)
  let p = dom.create_element("p")
  let _ = dom.set_attribute(p, "id", "desc")
  let _ = dom.append_child(body, p)
  let text = dom.create_text("Paragraph text")
  let _ = dom.append_child(p, text)

  let js_code = #|var el = document.getElementById("desc");
  #|console.log(el.textContent);

  let result = JsContext::new(dom).execute(js_code)
  guard result.success else {
    fail("expected success: " + result.value)
  }
  guard result.logs.length() > 0 else {
    fail("expected console output")
  }
  guard result.logs[0] == "Paragraph text" else {
    fail("expected 'Paragraph text', got: " + result.logs[0])
  }
}

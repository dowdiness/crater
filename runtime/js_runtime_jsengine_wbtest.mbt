///|
/// Test: JsEngine Runtime Integration + Full DOM Bindings.
/// Uses html() test helper for DOM setup where possible.

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

// ── Core DOM helpers ──

///|
fn make_simple_dom() -> (@dom.DomTree, @dom.NodeId) {
  let dom = @dom.DomTree::new()
  let d = dom.get_document()
  let h = dom.create_element("html")
  let _ = dom.append_child(d, h)
  let b = dom.create_element("body")
  let _ = dom.append_child(h, b)
  let dv = dom.create_element("div")
  let _ = dom.append_child(b, dv)
  let _ = dom.set_attribute(dv, "id", "root")
  (dom, dv)
}

///|
fn run_js(dom : @dom.DomTree, code : String) -> JsResult raise {
  JsContext::new(dom).execute(code)
}

// ── Query tests ──

///|
test "document.querySelector + textContent" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var el=document.querySelector('#root');console.log(el.textContent);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "getElementById + textContent" {
  let (dom, dv) = make_simple_dom()
  let _ = dom.append_child(dv, dom.create_text("hello"))
  let r = run_js(
    dom, "console.log(document.getElementById('root').textContent);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "hello" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "querySelector returns null for non-existent" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "console.log(document.querySelector('nonexistent')===null);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "true" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "getAttribute returns null for non-existent" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "console.log(document.querySelector('#root').getAttribute('missing')===null);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "true" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

// ── Property tests ──

///|
test "textContent getter and setter" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.textContent='after';console.log(e.textContent);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "after" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "tagName getter" {
  let (dom, _) = make_simple_dom()
  let r = run_js(dom, "console.log(document.querySelector('#root').tagName);")
  guard r.logs.length() > 0 && r.logs[0] == "DIV" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "className getter and setter" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');console.log(e.className);e.className='foo bar';console.log(e.className);",
  )
  guard r.logs.length() == 2 && r.logs[0] == "" && r.logs[1] == "foo bar" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "classList add and contains" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.classList.add('active');console.log(e.classList.contains('active'));console.log(e.classList.contains('nope'));",
  )
  guard r.logs.length() == 2 && r.logs[0] == "true" && r.logs[1] == "false" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "classList remove" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.className='a b c';e.classList.remove('b');console.log(e.className);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "a c" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "classList add deduplicates" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.classList.add('x');e.classList.add('x');console.log(e.className);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "x" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "style getter" {
  let (dom, dv) = make_simple_dom()
  let _ = dom.set_attribute(dv, "style", "color:red")
  let r = run_js(dom, "console.log(document.querySelector('#root').style);")
  guard r.logs.length() > 0 && r.logs[0] == "color:red" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

// ── innerHTML tests ──

///|
test "innerHTML getter" {
  let ctx = html("<div id=root><span>hi</span></div>")
  let r = ctx.eval("console.log(document.querySelector('#root').innerHTML);")
  guard r.logs.length() > 0 && r.logs[0] == "<span>hi</span>" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "innerHTML setter" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.innerHTML='<span class=x>hi</span>';console.log(e.innerHTML);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "<span class=\"x\">hi</span>" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "innerHTML setter with style attribute" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.innerHTML='<span style=color:red>hi</span>';console.log(document.querySelector('span').getAttribute('style'));",
  )
  guard r.logs.length() > 0 && r.logs[0] == "color:red" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "empty innerHTML setter" {
  let ctx = html("<div id=root><span>content</span></div>")
  let r = ctx.eval(
    "var e=document.querySelector('#root');e.innerHTML='';console.log(e.innerHTML);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "nested innerHTML" {
  let ctx = html("<ul><li>A</li><li>B</li></ul>")
  let r = ctx.eval("console.log(document.querySelector('ul').innerHTML);")
  guard r.logs.length() > 0 && r.logs[0] == "<li>A</li><li>B</li>" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

// ── DOM manipulation tests ──

///|
test "setAttribute and getAttribute" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var e=document.querySelector('#root');e.setAttribute('data-x','42');console.log(e.getAttribute('data-x'));",
  )
  guard r.logs.length() > 0 && r.logs[0] == "42" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "createElement + appendChild + textContent setter" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "var p=document.querySelector('#root');var c=document.createElement('span');c.textContent='new';p.appendChild(c);console.log(p.innerHTML);",
  )
  guard r.logs.length() > 0 && r.logs[0] == "<span>new</span>" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

// ── Global object tests ──

///|
test "window and self globals" {
  let (dom, _) = make_simple_dom()
  let r = run_js(
    dom, "console.log(typeof window);console.log(typeof self);console.log(window.document===document);",
  )
  guard r.logs.length() == 3 &&
    r.logs[0] == "object" &&
    r.logs[1] == "object" &&
    r.logs[2] == "true" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "document.body" {
  let (dom, _) = make_simple_dom()
  let r = run_js(dom, "console.log(document.body.tagName);")
  guard r.logs.length() > 0 && r.logs[0] == "BODY" else {
    fail("unexpected: " + r.logs.join(","))
  }
}

///|
test "document.title" {
  let ctx = html(
    "<html><head><title>My Page</title></head><body></body></html>",
  )
  let r = ctx.eval("console.log(document.title);")
  guard r.logs.length() > 0 && r.logs[0] == "My Page" else {
    fail("unexpected: " + r.logs.join(","))
  }
}


// ── Edge case tests ──

///|
test "multiple appendChild on same parent" {
  let (dom, _) = make_simple_dom()
  let js = "var p=document.querySelector('#root');p.appendChild(document.createElement('a'));p.appendChild(document.createElement('b'));console.log(p.innerHTML);"
  let r = run_js(dom, js)
  guard r.logs.length() > 0 && r.logs[0] == "<a></a><b></b>" else { fail("unexpected: " + r.logs.join(",")) }
}

///|
test "classList operations are idempotent" {
  let (dom, _) = make_simple_dom()
  let js = "var e=document.querySelector('#root');e.classList.add('a');e.classList.add('b');e.classList.remove('a');e.classList.add('a');console.log(e.className);"
  let r = run_js(dom, js)
  guard r.logs.length() > 0 && r.logs[0] == "b a" else { fail("unexpected: " + r.logs.join(",")) }
}

///|
test "textContent setter with empty string clears children" {
  let (dom, dv) = make_simple_dom()
  let _ = dom.append_child(dv, dom.create_text("content"))
  let r = run_js(dom, "var e=document.querySelector('#root');e.textContent='';console.log(e.textContent);")
  guard r.logs.length() > 0 && r.logs[0] == "" else { fail("unexpected: " + r.logs.join(",")) }
}

///|
test "innerHTML with deeply nested structure" {
  let ctx = html("<div id=x><ul><li><span>deep</span></li></ul></div>")
  let r = ctx.eval("console.log(document.querySelector('#x span').textContent);")
  guard r.logs.length() > 0 && r.logs[0] == "deep" else { fail("unexpected: " + r.logs.join(",")) }
}

///|
test "setAttribute with special characters in value" {
  let (dom, _) = make_simple_dom()
  let js = "var e=document.querySelector('#root');e.setAttribute('data-val','<>&');console.log(e.getAttribute('data-val'));"
  let r = run_js(dom, js)
  guard r.logs.length() > 0 && r.logs[0] == "<>&" else { fail("unexpected: " + r.logs.join(",")) }
}
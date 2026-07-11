fn main {
  try {
    // Test 1: basic arithmetic
    let dom = @dom.DomTree::new()
    let r1 = @rt.JsContext::new(dom).execute("1 + 2")
    println("Test 1: 1+2 = " + r1.value + " (" + r1.success.to_string() + ")")
    guard r1.value == "3" else { abort("FAIL test 1") }

    // Test 2: string ops
    let dom2 = @dom.DomTree::new()
    let r2 = @rt.JsContext::new(dom2).execute("\"hello\".toUpperCase()")
    println("Test 2: " + r2.value + " (" + r2.success.to_string() + ")")
    guard r2.value == "HELLO" else { abort("FAIL test 2") }

    // Test 3: console.log
    let dom3 = @dom.DomTree::new()
    let r3 = @rt.JsContext::new(dom3).execute("console.log(42)")
    let logs3 = r3.logs.join(",")
    println("Test 3: console = " + logs3 + " (" + r3.success.to_string() + ")")
    guard r3.logs.length() > 0 && r3.logs[0] == "42" else { abort("FAIL test 3") }

    // Test 4: document.querySelector + textContent
    let dom4 = @dom.DomTree::new()
    let doc_id = dom4.get_document()
    let html = dom4.create_element("html")
    let _ = dom4.append_child(doc_id, html)
    let body = dom4.create_element("body")
    let _ = dom4.append_child(html, body)
    let h1 = dom4.create_element("h1")
    let _ = dom4.set_attribute(h1, "id", "title")
    let _ = dom4.append_child(body, h1)
    let text = dom4.create_text("Hello World")
    let _ = dom4.append_child(h1, text)
    let js4 = "var el = document.querySelector(\"#title\"); console.log(el.textContent);"
    let r4 = @rt.JsContext::new(dom4).execute(js4)
    println("Test 4: querySelector = " + r4.logs.join(",") + " (" + r4.success.to_string() + ")")
    guard r4.logs.length() > 0 && r4.logs[0] == "Hello World" else { abort("FAIL test 4") }

    // Test 5: document.getElementById + textContent
    let dom5 = @dom.DomTree::new()
    let doc_id5 = dom5.get_document()
    let html5 = dom5.create_element("html")
    let _ = dom5.append_child(doc_id5, html5)
    let body5 = dom5.create_element("body")
    let _ = dom5.append_child(html5, body5)
    let p = dom5.create_element("p")
    let _ = dom5.set_attribute(p, "id", "desc")
    let _ = dom5.append_child(body5, p)
    let t5 = dom5.create_text("Para text")
    let _ = dom5.append_child(p, t5)
    let js5 = "var el = document.getElementById(\"desc\"); console.log(el.textContent);"
    let r5 = @rt.JsContext::new(dom5).execute(js5)
    println("Test 5: getElementById = " + r5.logs.join(",") + " (" + r5.success.to_string() + ")")
    guard r5.logs.length() > 0 && r5.logs[0] == "Para text" else { abort("FAIL test 5") }

    // Test 6: document.title
    let dom6 = @dom.DomTree::new()
    let doc6 = dom6.get_document()
    let html6 = dom6.create_element("html")
    let _ = dom6.append_child(doc6, html6)
    let head6 = dom6.create_element("head")
    let _ = dom6.append_child(html6, head6)
    let title6 = dom6.create_element("title")
    let _ = dom6.append_child(head6, title6)
    let tt6 = dom6.create_text("My Page")
    let _ = dom6.append_child(title6, tt6)
    let js6 = "console.log(document.title);"
    let r6 = @rt.JsContext::new(dom6).execute(js6)
    println("Test 6: title = " + r6.logs.join(",") + " (" + r6.success.to_string() + ")")
    guard r6.logs.length() > 0 && r6.logs[0] == "My Page" else { abort("FAIL test 6") }

    println("ALL TESTS PASSED")
  } catch {
    e => println("ERROR: " + e.to_string())
  }
}

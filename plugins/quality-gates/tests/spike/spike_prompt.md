You are a code reviewer. Review the following synthetic diff for any issues.

<diff>
--- a/example.py
+++ b/example.py
@@ -1,5 +1,8 @@
 def divide(a, b):
-    return a / b
+    if b == 0:
+        return None
+    return a / b

+def lookup(items, idx):
+    return items[idx]
</diff>

Output your findings in this exact format (fenced JSON code block):
```json
{
  "findings": [
    {
      "file": "example.py",
      "line": 8,
      "severity": "IMPORTANT",
      "confidence": 8,
      "summary": "lookup() does not validate idx is within range.",
      "proposed_fix": "Add bounds check or catch IndexError."
    }
  ]
}
```

The JSON code block is REQUIRED. Wrap your findings array in ```json ... ``` exactly as shown.

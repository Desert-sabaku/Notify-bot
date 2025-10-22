---
applyTo: "**"
---

- テキストメッセージは `MessageConstants` モジュールに集約しています。新規に定義する際は`MessageConstants`に追加し、これを参照してください。
- 関数を定義する際は、YARD用のコメントを併記してください。また、`rbs`(`signature`)を`sig/syodosima.rbs`に追加してください。

以下は、YARDコメントの例です。

```rb
# メインの処理を実行します。
#
# @param arg1 [String] 最初の引数の説明
# @param arg2 [Integer] 二番目の引数の説明
# @return [Boolean] 処理が成功したかどうか
def main(arg1, arg2)
    # メソッドの実装
end
```

以下は、rbsの例です。

```rb
module Syodosima
  def main: (String arg1, Integer arg2) -> Boolean
end
```

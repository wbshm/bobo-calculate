# App Store 重新提审材料（1.0 Build 4）

## App 描述中必须添加

将下面一行添加到简体中文 App 描述末尾：

```text
使用条款（Apple 标准 EULA）：https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

将下面一行添加到英文 App 描述末尾：

```text
Terms of Use (Apple Standard EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

同时确认 App Store Connect 的“隐私政策 URL”字段中已有可公开访问的 HTTPS 地址。仓库内的 `PRIVACY_POLICY.md` 不是公开网址，不能直接填写成本地文件路径。

## 订阅商品提交检查

产品 ID：`bobo_monthly`

- 完成订阅商品的中文和英文本地化、价格、销售范围等必填信息。
- 为该订阅上传“App 审核截图”。建议截图完整展示订阅名称、1 个月周期、每月价格、购买按钮、恢复购买、隐私政策和使用条款入口。
- 在 1.0 版本的“App 内购买项目和订阅”区域添加 `bobo_monthly`。
- 上传并选择 Build 4，让应用版本、`bobo_vip` 订阅群组和 `bobo_monthly` 订阅商品出现在同一个草稿提交中，再一起提交审核。

## App Review Information - Notes

```text
Hello App Review Team,

We have submitted the auto-renewable subscription product (product ID: bobo_monthly) and its subscription group together with this app version, and uploaded a new binary (version 1.0, build 4).

The subscription screen clearly displays the subscription title, one-month subscription length, localized monthly price, auto-renewal information, Restore Purchases, Privacy Policy, and Terms of Use. A Terms of Use entry is also available from the More screen.

We use Apple's Standard EULA. Its functional link has been added to the App Store description:
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

A screen recording demonstrating the subscription screen and the functional legal links is attached for review.

Thank you.
```

## 建议录屏路径

1. 打开 App，进入“更多”。
2. 打开“啵啵会员”，停留几秒，确保订阅名称、期限和价格清晰可见。
3. 点击“使用条款”，展示链接可以正常打开。
4. 返回 App，打开“隐私政策”，展示页面可以正常打开。
5. 返回订阅页，展示“恢复购买”按钮。

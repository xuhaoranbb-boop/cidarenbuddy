# 词伴 CiDarenBuddy

词伴是一个面向 iPhone 的实时英语学习原型：通过 iOS 系统屏幕共享读取当前屏幕，用 Apple Vision 识别中英文，再用 Apple Translation 翻译；你可以点选识别到的英文词查释义、加入生词本并练习拼写。

> 当前版本要求 iOS 27 或更新版本。项目已在 GitHub Actions 的 Xcode 27 环境完成编译和 IPA 打包；尚未完成 iPhone 真机运行验证。IPA 是未签名测试包，安装前需要自行签名侧载。

## 下载

从 [Releases](https://github.com/xuhaoranbb-boop/cidarenbuddy/releases/latest) 下载 `CiDarenBuddy-unsigned.ipa`。Windows 安装步骤、功能说明和故障排查见[完整中文使用手册](docs/使用说明.md)。

## 功能

- 使用 iOS ScreenCaptureKit 系统屏幕共享持续读取屏幕帧。
- 使用 Apple Vision 在设备本地识别英文和中文。
- 使用 Apple Translation 在设备本地进行中英互译。
- 通过画中画显示最近识别的原文和译文，方便切换到微信词达人时查看。
- 点选英文单词查看中文释义，保存至本地生词本并进行拼写练习。
- 拼写练习支持大小写不敏感判定；拼错时显示系统提供的英文拼写建议。

## 快速开始

1. 在 iPhone 上安装签名后的 IPA，并启动“词伴”。
2. 打开“实时识词”，选择翻译方向，点“开始实时读屏”。
3. 在系统屏幕共享选择器中选择整个屏幕并确认。
4. 点“开启译文小窗”，切换到微信词达人。
5. 返回“词伴”点英文词可查词并加入拼写练习；“拼写”页根据释义输入英文。

屏幕采集由 iOS 系统调度。应用不会固定以 20 ms 周期采帧，也不保证端到端翻译延迟为 20 ms。页面状态显示帧到 OCR 完成的耗时；它不包含等待下一帧和翻译耗时。画中画显示最近一条识别内容，不会逐行覆盖微信界面。

## 构建

需要 Xcode 27 / iOS 27 SDK 与 XcodeGen。Windows 用户可以使用仓库 Actions 的 **Build unsigned iOS IPA** 工作流，或直接使用 Releases 中的 IPA。

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project CiDarenBuddy.xcodeproj \
  -scheme CiDarenBuddy \
  -sdk iphoneos \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO build
```

要生成 IPA，可将构建得到的 `CiDarenBuddy.app` 放入 `Payload/` 后压缩为 `.ipa`。GitHub Actions 工作流已自动完成该步骤并上传构建产物。

## 隐私与数据

- 屏幕帧仅在应用运行时的内存中处理，不保存为截图或录屏文件。
- 生词、释义和答错次数保存于本机应用偏好存储中。
- 本项目源码没有实现向开发者服务器上传屏幕内容或生词的功能。
- 屏幕共享由 iOS 系统选择器启动，用户可随时返回应用停止共享或使用系统控制结束共享。

## 许可证

本项目采用 MIT License，见 [LICENSE](LICENSE)。

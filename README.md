# 词伴（CiDarenBuddy）

面向微信“词达人”的 iPhone 实时伴学原型。启动系统屏幕共享后，ScreenCaptureKit 持续接收屏幕帧，Vision 在设备本地识别英文或中文，Apple Translation 在设备本地翻译；译文更新到画中画小窗。画面帧只在内存中处理，不写入照片或视频文件。点识别到的英文词可以查看中文释义并加入拼写练习。

## 使用方式

1. 打开“词伴”，点“开始实时读屏”。
2. 在 iOS 系统屏幕共享选择器中选择整个屏幕并确认开始。
3. 点“开启译文小窗”，再切换到微信词达人；采帧间隔目标为 20 ms，应用只在前一帧 OCR 完成后处理下一帧，避免堆积旧画面。
4. 回到词伴点英文单词查释义并保存到生词本，之后可做拼写练习。

系统会显示屏幕共享状态。停止时回到词伴点“停止屏幕共享”，或使用系统共享控制结束。状态栏显示帧到 OCR 完成耗时；这不包含屏幕刷新等待和 Apple Translation 翻译耗时。20 ms 是采帧目标，不代表译文端到端延迟保证。小窗使用 iOS 画中画显示最新识别行及译文；由于窗口尺寸有限，不会把译文逐行盖在微信原界面上。

## 构建

项目需要 Xcode 27 / iOS 27 SDK 与 XcodeGen。当前工作环境没有 macOS/Xcode，因此还未在 iPhone 真机编译运行。ScreenCaptureKit 的 iOS 全屏捕获接口要求 iOS 27。

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project CiDarenBuddy.xcodeproj -scheme CiDarenBuddy -sdk iphoneos -configuration Debug build
```

没有 Mac 时，可将目录放进 GitHub 仓库并运行 **Actions → Build unsigned iOS IPA**。工作流产出未签名 IPA；安装到 iPhone 前还需用个人 Apple ID 或开发者证书签名侧载。工作流不使用或保存 Apple 凭据。

## 当前范围

- 持续屏幕读取：ScreenCaptureKit iOS 27 全屏共享流
- OCR：Apple Vision 快速模式，本地处理；采帧目标间隔 20 ms，单帧处理，避免积压
- 翻译：Apple Translation，中英方向可切换
- 拼写检查：iOS `UITextChecker` 候选建议与答案匹配
- 生词本：本地保存、可删除
- 不连接词达人账号或内部接口，不自动答题或提交答案

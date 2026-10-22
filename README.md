# fuckxter-app

FuckXter 的 Flutter 客户端，和网页端使用同一个API。

## 🔒 签名

### 对于Android .apk
```text
证书指纹 (SHA-256): 94:CC:94:36:7A:5E:16:5F:8B:86:CF:7F:50:80:07:12:F3:9C:09:54:7C:EF:EF:5B:3B:21:ED:22:76:88:33:66
```

## 🔧 对于开发者

### 初始化

使用 stable Flutter。CI 执行格式检查、静态分析、测试及 Android、Linux、Windows、macOS 和 iOS 模拟器构建。Linux 需要 `libsecret-1-dev`（构建）及运行中的系统钥匙串服务（登录）。

客户端图片统一通过 API 的 `format=webp&width=128|640|1280|2048` 接口加载；请先部署包含此接口的网站 Worker，再发布客户端。客户端不再使用 AVIF 插件或旧图片解码回退，缩略图与全屏查看均由服务端生成 WebP。转换失败会显示加载失败，不回退到原始 AVIF 解码。

登录凭据保存在系统安全存储中。私有图片缓存按会话隔离，图片请求只接受 API 同源地址且禁止重定向。

### 客户端界面

底栏在同一页面内滑动切换，搜索在页头展开，返回首页保留信息流和滚动位置。窄屏用底栏，宽屏用侧栏；折叠、旋转和调整窗口时保留草稿与当前页面。图片按原比例展示，超长图限制信息流占高；全屏预览随手势连续调整高度。

Apple 端在 iOS/macOS 26 及以上使用本地插件调用 SwiftUI `glassEffect`，应用于导航、搜索、账号菜单和回复/预览控制栏。帖子正文不叠加原生玻璃视图。旧系统和其他平台使用 Fx 单色样式；减少动态效果开启时跳过对焦、逐项浮入和滑动动效。

iOS/macOS 共用 `apple/FxAppIcon.icon`，图形沿用网页 favicon 的 Fx 轮廓，F 和 X 分层，包含默认、深色和着色外观。需 Xcode 26 及以上编译；Xcode 同时生成旧系统所需的图标。可以用 Icon Composer 打开继续调整材质。

iOS CI 产物是未签名的模拟器包；安装到真机、TestFlight 或 App Store 仍需 Apple 开发者签名与发布配置。

### 安装包

GitHub Actions 在每次主分支提交后构建并发布：

| 平台 | 格式 | 安装方式 |
| --- | --- | --- |
| Arch Linux | `.pkg.tar.zst` | `sudo pacman -U ./fuckxter-*.pkg.tar.zst` |
| Debian / Ubuntu | `.deb` | `sudo apt install ./fuckxter-*.deb`（或依赖齐全后 `dpkg -i`） |
| Fedora | `.rpm` | `sudo dnf install ./fuckxter-*.rpm` |
| Linux | `.AppImage` | 添加执行权限后直接运行；无 FUSE 时可加 `--appimage-extract-and-run` |
| macOS | `.dmg` | 打开磁盘映像，将 FuckXter 拖入 Applications |
| Windows | `.zip` | 解压后运行程序 |
| Android | `.apk` | 安装 APK |

所有安装包、文件名和发布标签从 `pubspec.yaml` 读取版本，不能单独维护版本号。例如 `0.0.8+3` 对应包版本 `0.0.8-3`、发布标签 `V0.0.8`；macOS 应用版本为 `0.0.8`，构建号为 `3`。提交时补丁位加一，满十向次版本进位，次版本也满十进位。

Linux 包为 x86_64，依赖 GTK 3、libsecret 和系统钥匙串服务（如 GNOME Keyring）。安装包会声明构建环境的最低 glibc 版本；AppImage 也需要不低于构建环境的 glibc。macOS 包使用 GitHub macOS runner 的原生架构，文件名会标明架构；当前没有 Developer ID 签名和公证。

CI 检查 deb/rpm/pacman 包的版本元数据、安装 deb 并检查程序和资源、解包检查 AppImage，以及校验 DMG 和应用内的版本号。

## ⚖️ LICENSE

FuckXter-app licensed under the [MoPL](https://867678.xyz/docs/mopl)

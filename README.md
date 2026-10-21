# fuckxter-app

FuckXter 的 Flutter 客户端，对接 `https://api.fuckxter.site`。

时间线（推荐 / 实时 / 关注）、发帖和图片、点赞、转发、引用、收藏、评论、搜索、用户主页与关注、通知、私信、浏览记录、登录注册（含双重验证和恢复码）以及资料设置，都在这个应用里完成。品牌图放在 `assets/brand/`。

## ⬇️ Init

Make sure you have env of flutter

```bash
flutter run -d [your_os]
```

It will be auto install depend and compile

## ⚖️ LICENSE

FuckXter-app licensed under the [MoPL](https://867678.xyz/docs/mopl)

## 开发与验证

使用 stable Flutter。CI 执行格式检查、静态分析、测试及 Android、Linux、Windows、macOS 构建。Linux 需要 `libsecret-1-dev`（构建）及运行中的系统钥匙串服务（登录）。

客户端图片统一通过 API 的 `format=webp&width=128|640|1280|2048` 接口加载；请先部署包含此接口的网站 Worker，再发布客户端。客户端不再使用 AVIF 插件或旧图片解码回退，缩略图与全屏查看均由服务端生成 WebP。转换失败会显示加载失败，不回退到原始 AVIF 解码。

登录凭据保存到系统安全存储，升级时清除旧版明文会话与账号缓存，需要重新登录。私有图片缓存按会话隔离，图片请求只接受 API 同源地址且禁止重定向。

## 桌面安装包

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

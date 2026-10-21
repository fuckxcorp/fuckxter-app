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

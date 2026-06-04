# LightMD

面向 AI 工具高频用户的 Mac 轻便 Markdown 阅读器。核心目标是：双击 `.md` 文件后，直接看到渲染后的阅读视图。

开发者：Kellan / 许可  
联系邮箱：kenbot818@gmail.com

## 下载

当前版本：v0.1.0

- Release 页面：[LightMD v0.1.0](https://github.com/kellanxu/light-md-reader/releases/tag/v0.1.0)
- 直接下载：[LightMD.dmg](https://github.com/kellanxu/light-md-reader/releases/download/v0.1.0/LightMD.dmg)

下载 DMG 后打开，把 `LightMD` 拖到 `Applications` 即可安装。

## 当前能力

- Swift 原生 Mac App
- 支持打开 `.md`、`.markdown`、`.txt`
- 默认只读，进入编辑模式后可保存修改
- 支持多文件打开和切换
- 支持常见 Markdown 渲染：标题、列表、引用、代码块、链接、表格、分割线
- 支持类 Notion / 飞书的所见即所得 Markdown 编辑
- 支持导出 PNG、PDF、HTML
- 支持 3 套主题：蓝、纸、夜
- 本地优先，不做知识库、Vault、插件、云同步、账号或内置 AI

## 构建

```bash
./scripts/build_app.sh
```

构建完成后，App 位于：

```text
build/LightMD.app
```

## 本机安装并设为 Markdown 默认打开方式

```bash
./scripts/install_local.sh
```

安装完成后，App 位于：

```text
~/Applications/LightMD.app
```

## 生成 DMG 安装包

```bash
./scripts/build_dmg.sh
```

构建完成后，安装包位于：

```text
build/LightMD.dmg
```

DMG 打开后会显示拖拽安装引导：把 `LightMD` 拖到 `Applications`。

## 使用

- 直接运行 App 后点击「打开」选择 Markdown 文件。
- 或将 `.md` 文件拖到 App 上打开。
- 安装脚本会把 `.md` 文件的默认打开方式设置为 LightMD，实现双击即读。
- 默认进入阅读模式，需要修改时手动切换到编辑模式。
- 通过顶部「导出」菜单可导出当前文档为 PNG、PDF 或 HTML。

## 产品边界

第一版专注阅读，不做重型编辑器。后续如果加入编辑能力，也应保持默认只读，只有用户明确进入编辑模式并主动保存时才写入原文件。

## 第三方依赖

- 编辑器核心使用 `@marktext/muya 0.2.5`，MIT License，见 `Assets/Muya/NOTICE.txt`。

## License

MIT License. See [LICENSE](LICENSE).

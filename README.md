# LightMD Reader

面向 AI 工具高频用户的 Mac 轻便 Markdown 阅读器。核心目标是：双击 `.md` 文件后，直接看到渲染后的阅读视图。

## 当前能力

- Swift 原生 Mac App
- 支持打开 `.md`、`.markdown`、`.txt`
- 默认只读，不会修改原文件
- 支持多文件打开和切换
- 支持常见 Markdown 渲染：标题、列表、引用、代码块、链接、表格、分割线
- 不做知识库、Vault、插件、云同步、账号或内置 AI

## 构建

```bash
./scripts/build_app.sh
```

构建完成后，App 位于：

```text
build/LightMD Reader.app
```

## 本机安装并设为 Markdown 默认打开方式

```bash
./scripts/install_local.sh
```

安装完成后，App 位于：

```text
~/Applications/LightMD Reader.app
```

## 使用

- 直接运行 App 后点击「打开」选择 Markdown 文件。
- 或将 `.md` 文件拖到 App 上打开。
- 安装脚本会把 `.md` 文件的默认打开方式设置为 LightMD Reader，实现双击即读。

## 产品边界

第一版专注阅读，不做重型编辑器。后续如果加入编辑能力，也应保持默认只读，只有用户明确进入编辑模式并主动保存时才写入原文件。

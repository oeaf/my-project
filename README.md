# My Project — Pi 粗活外包

> ⭐ **Support This Project**
>
> [![GitHub stars](https://img.shields.io/github/stars/oeaf/my-project?style=social)](https://github.com/oeaf/my-project)
> [![GitHub forks](https://img.shields.io/github/forks/oeaf/my-project?style=social)](https://github.com/oeaf/my-project)
> [![GitHub issues](https://img.shields.io/github/issues/oeaf/my-project)](https://github.com/oeaf/my-project/issues)
>
> 如果这个项目对你有用，欢迎点个 ⭐ Star！你的支持是我持续更新的动力。

用 [Pi coding agent](https://pi.dev) + API key 池，把重复性粗活外包给便宜模型：主力 deepseek-v4-flash-0731，兜底免费模型；key 轮换调用，只存在本地 600 权限文件里。

## 快速上手

```sh
# 1. 把 key 写入本地池（600 权限，不进仓库不进日志）
#    文件：~/.pi/agent/.keys.env
#    格式：KEY_1='sk-...'，KEY_2='sk-...'，有几个写几个

# 2. 一行调用（自动轮换 key）
bin/pi-run.sh "你的任务描述"
```

## 文件结构

```
.
├── SKILL.md                  # 给 AI Agent 的完整说明：分工、调用方式、失败处理
├── bin/
│   └── pi-run.sh             # 轮换 key 池调用 pi 的封装脚本
└── references/
    └── key-rotation.md       # key 池轮换机制说明
```

## 说明

- 分工铁律：简单的自己做、重复粗活甩给 pi、需要判断的自己做；pi 只报硬失败，软失败由人把关。
- key 只存 `~/.pi/agent/.keys.env`（600 权限），绝不进仓库、日志和聊天记录。

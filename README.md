# LifeTrace Assets

LifeTrace Assets 是 LifeTrace 生态中的个人资产全生命周期应用，用于记录“我拥有什么”，并追踪资产从购入、使用、维护、估值到出售/退役的完整过程。

当前阶段：**Flutter Local-first Assets v1 已完成并归档；当前 OpenSpec change 正在实现真实跨应用 EntityLink 关联。**

## 核心能力

- 资产新增、编辑、软删除、状态管理
- 搜索、状态筛选、购买时间/估值/日均成本/更新时间排序
- 生命周期事件：购入、使用、维护、维修、更换配件、借出、归还、闲置、估值、出售、退役、备注
- 成本模型：买入价 + 维护支出 - 已回收金额
- 当前估值、保值率、有效持有天数和日均成本
- Dashboard / Activity / Analytics 全部从 Repository 真数据计算
- 保修、闲置、维修状态提醒中心
- JSON 版本化备份与恢复
- Android/native 持久化存储与 Flutter Web IndexedDB
- Durable Outbox、Snapshot、Push、Pull、cursor、optimistic conflict
- Cloud 冲突显式“采用云端 / 保留本地”解决
- Cloud account binding，避免本地资产误同步到不同账号
- 真实跨应用 EntityLink：稳定目标类型/ID、可选显示名、离线 Outbox、删除级联

## 架构

~~~text
Flutter Screens
    │ commands / state
    ▼
AssetAppState
    │
    ▼
AssetRepository ───────────────► Local Sembast / IndexedDB
    │                                   │
    │                                   ├─ assets
    │                                   ├─ asset_events
    │                                   ├─ entity_links
    │                                   ├─ sync_outbox
    │                                   ├─ sync_state
    │                                   └─ sync_conflicts
    │
    ▼
AssetSyncCoordinator
    │
    ▼
LifeTrace Cloud Sync v1
  snapshot → push → pull
~~~

UI 不直接访问数据库或 HTTP。核心资产能力始终 local-first；Cloud 不可用时 CRUD、生命周期、分析、提醒和备份仍然工作。

更详细的实现见 docs/ARCHITECTURE_V1.md。

## LifeTrace Cloud

客户端同步实体：

- asset.asset
- asset.event
- entity.link

Cloud 端复用既有 typed `entity.link` contract；当前 companion change `add-entity-link-scopes-v1` 增加 `links:read` / `links:write` 最小权限，不授予 Assets `account:write` 或其他产品写权限。

同步顺序：

1. 首次连接或 cursor 不存在时执行 Snapshot。
2. Push 本地 durable Outbox。
3. accepted 后持久化 serverVersion，并 rebase 同实体后续本地 mutation。
4. conflict 持久化本地意图和服务端状态，不静默覆盖。
5. Pull 到最新 cursor。
6. 后续同步从 cursor 增量继续。

## 数据备份

“我的 → 本地数据”支持查看资产/生命周期/待同步数量、复制版本化 JSON 备份、从 JSON 备份恢复和清空本地数据。

备份 v2 包含 assets、events 和 links；仍兼容 v1 备份。恢复会把 serverVersion 重置为 0 并重新创建 Outbox，确保恢复后的实体仍进入正常同步协议，而不是绕过 Cloud 状态。

## 在线预览

https://lifetracemanage.github.io/LifeTrace-assets/

## 开发与验证

~~~bash
flutter create . --platforms=android,web --project-name lifetrace_assets
flutter pub get
flutter analyze
flutter test
flutter build web --release
~~~

CI 同时执行 OpenSpec strict validation：

~~~bash
npx --yes @fission-ai/openspec@1.13.0 validate --all --strict --no-interactive
~~~

Active OpenSpec change:

~~~text
openspec/changes/implement-asset-entity-links-v1/
├── proposal.md
├── design.md
├── tasks.md
└── specs/
    └── asset-entity-links/
~~~

只有 Flutter CI、Cloud CI、OpenSpec strict validation 和 requirements 对照全部通过后，change 才会 archive。

# LifeTrace Assets

LifeTrace Assets 是 LifeTrace 生态中的个人资产全生命周期应用，用于记录“我拥有什么”，并追踪资产从购入、使用、维护、估值到出售/退役的完整过程。

当前阶段：**Flutter Local-first Assets v1 与真实跨应用 EntityLink 已完成；资产照片能力正在通过 `implement-asset-attachments-v1` OpenSpec change 补齐。**

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
- 资产照片：多图选择、本地私有持久化、SHA-256、详情预览、首图缩略图、删除级联
- 独立附件传输队列：当前已持久化 upload/delete 意图，为后续 Cloud Files 同步保留边界

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
    │                                   ├─ asset_attachments
    │                                   ├─ asset_attachment_operations
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

UI 不直接访问数据库或 HTTP。核心资产能力始终 local-first；Cloud 不可用时 CRUD、生命周期、分析、提醒、资产照片、备份以及已绑定账号下的 EntityLink 本地变更仍然工作。照片二进制在 native/Android 使用应用私有目录，在 Web 使用 IndexedDB 持久化。

更详细的实现见 `docs/ARCHITECTURE_V1.md`。

## LifeTrace Cloud

客户端同步实体：

- `asset.asset`
- `asset.event`
- `entity.link`

Cloud `main` 已提供 `entity.link` typed contract 以及独立 `links:read` / `links:write` 权限。Assets 不需要 `account:write`，也不会因为展示关联而读取或伪造其他产品正文。

同步顺序：

1. 首次连接或 cursor 不存在时执行 Snapshot。
2. Push 本地 durable Outbox。
3. accepted 后持久化 serverVersion，并 rebase 同实体后续本地 mutation。
4. conflict 持久化本地意图和服务端状态，不静默覆盖。
5. Pull 到最新 cursor。
6. 后续同步从 cursor 增量继续。

旧 Assets 会话如果尚未拿到 `links:read` / `links:write`，仍会继续同步 `asset.asset` / `asset.event`；EntityLink mutation 保留在 durable outbox，直到重新获得 link scope。

## 数据备份

“我的 → 本地数据”支持查看资产/生命周期/待同步数量、复制版本化 JSON 备份、从 JSON 备份恢复和清空本地数据。

备份已升级为 v3，包含 assets、events、links 和 attachment manifest，并继续兼容 v1/v2。JSON 不嵌入照片二进制：Cloud-backed 附件恢复为 remoteOnly，纯本地附件在缺少二进制时明确标记 unavailable，不会伪造上传任务。

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

当前 live specs 位于：

~~~text
openspec/specs/
├── asset-library/
├── asset-lifecycle/
├── local-persistence/
├── asset-analytics/
├── asset-reminders/
├── asset-cloud-sync/
└── asset-entity-links/

当前未归档 change：`openspec/changes/implement-asset-attachments-v1/`。当前实现完成本地照片闭环；Cloud Files API、远端 reconciliation 和按需下载仍在该 change 的后续任务中。
~~~

历史变更保存在 `openspec/changes/archive/`，其中 EntityLink 变更归档为 `2026-09-17-implement-asset-entity-links-v1`。

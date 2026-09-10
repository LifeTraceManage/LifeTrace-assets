# LifeTrace Assets

LifeTrace Assets 是 LifeTrace 生态中的个人资产记录应用，用于记录“我拥有什么”，并追踪一件资产从购入、使用、维护、估值到出售/退役的完整生命周期。

当前阶段：Flutter 高保真 UI / 交互原型。

## 在线预览

GitHub Pages 预览地址：

https://lifetracemanage.github.io/LifeTrace-assets/

`feature/flutter-ui-v1` 分支通过 Flutter CI 后，会自动触发 `main` 上的 Pages 部署工作流并更新在线预览。

## 产品定位

参考个人资产全生命周期管理产品的核心思路，但不复制界面。LifeTrace Assets 强调：

- 资产总览与数字陈列柜
- 买入价格、当前估值、日均成本
- 使用中 / 闲置 / 借出 / 维修 / 已出售 / 已退役
- 维修、配件、出售等生命周期事件
- 未来与 LifeTrace Finance / Execute / Calendar / Collection 通过 EntityLink 互通

## 运行

```bash
flutter create . --platforms=android,web --project-name lifetrace_assets
flutter pub get
flutter run
```

## 当前页面

- 首页：资产概览、常用设备、分类、即将过保
- 资产：搜索、筛选、完整资产列表
- 资产详情：成本、估值、设备信息、关联内容、生命周期
- 新增/编辑资产：基础信息、购买信息、设备信息、状态
- 记录：生命周期事件时间线
- 分析：资产总值、分类占比、日均成本排行、状态分布
- 我的：Cloud、隐私、数据与备份等入口

> 当前使用 Mock 数据，只用于确认 UI、信息架构和交互。正式数据层与 Cloud Sync 在设计确认后再进入实现。

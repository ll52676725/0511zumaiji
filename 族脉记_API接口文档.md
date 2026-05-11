# 族脉记 API 接口文档

**版本：** V1.1
**日期：** 2026-04-15
**技术栈：** Spring Boot 3.x + MyBatis Plus 3.5 + Redis 7.x + MySQL 8.0
**协议：** RESTful + HTTPS
**认证方式：** JWT Token

---

## 目录

- [概述](#概述)
  - [通用约定](#通用约定)
  - [认证与鉴权](#认证与鉴权)
  - [响应格式](#响应格式)
  - [错误码定义](#错误码定义)
  - [缓存策略](#缓存策略)
- [一、认证模块 Auth](#一认证模块-auth)
- [二、用户模块 User](#二用户模块-user)
- [三、家族模块 Family](#三家族模块-family)
- [四、成员模块 Member](#四成员模块-member)
- [五、关系模块 Relation](#五关系模块-relation)
- [六、动态模块 Post](#六动态模块-post)
- [七、活动模块 Event](#七活动模块-event)
- [八、提醒模块 Reminder](#八提醒模块-reminder)
- [九、通知模块 Notification](#九通知模块-notification)
- [十、搜索模块 Search](#十搜索模块-search)
- [十一、族谱模块 FamilyTree](#十一族谱模块-familytree)
- [十二、文件模块 File](#十二文件模块-file)
- [十三、导出模块 Export](#十三导出模块-export)
- [十四、系统模块 System](#十四系统模块-system)

---

## 概述

### 通用约定

| 项目 | 约定 |
|------|------|
| Base URL | `https://api.zumaiji.com/v1`（测试环境：`https://api-test.zumaiji.com/v1`） |
| 请求格式 | `Content-Type: application/json; charset=utf-8` |
| 日期格式 | `yyyy-MM-dd`（全格式含时间：`yyyy-MM-dd HH:mm:ss`） |
| 时间戳 | Unix 毫秒级时间戳 |
| 分页 | `page`（从1开始，默认1）、`pageSize`（默认20，最大100） |
| 敏感字段 | 联系方式等加密存储，接口返回时默认脱敏 |
| 软删除 | 所有业务接口默认只返回 `status=1`（正常）的数据 |

### 认证与鉴权

```
请求头：Authorization: Bearer <jwt_token>
```

- JWT Token 中包含：`userId`、`openid`、`exp`（过期时间）
- Token 有效期：7天（AccessToken），RefreshToken 有效期：30天
- 敏感操作（删除、解散、转让）需验证 Token + 操作密码或微信支付密码

**角色权限说明：**

| 角色值 | 角色名 | 权限说明 |
|--------|--------|----------|
| 1 | 创建者 | 全部权限 |
| 2 | 管理员 | 管理成员、编辑活动、修改部分设置 |
| 3 | 普通成员 | 发布动态、参与活动、编辑自己的卡片 |
| 4 | 守护人 | 管理所有成员数据、审核申请，不含解散/转让 |
| 5 | 待审核 | 仅可见家族名称，不可浏览内容 |

### 响应格式

**成功响应：**

```json
{
  "code": 0,
  "message": "success",
  "data": { ... },
  "timestamp": 1744621234567,
  "traceId": "a1b2c3d4"
}
```

**分页响应：**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "list": [ ... ],
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "total": 100,
      "totalPages": 5
    }
  },
  "timestamp": 1744621234567
}
```

**失败响应：**

```json
{
  "code": 10001,
  "message": "家族码不存在或已失效",
  "data": null,
  "timestamp": 1744621234567
}
```

### 错误码定义

| 错误码区间 | 类别 | 说明 |
|-----------|------|------|
| 0 | 成功 | 请求成功 |
| 10001-10099 | 认证错误 | Token无效、过期、缺失 |
| 10101-10199 | 权限错误 | 无操作权限、角色不匹配 |
| 10201-10299 | 参数错误 | 必填字段缺失、格式错误、越界 |
| 10301-10399 | 业务错误 | 家族码无效、关系冲突、数据不存在 |
| 10401-10499 | 系统错误 | 数据库异常、Redis异常、文件上传失败 |
| 10501-10599 | 微信错误 | 微信接口调用失败 |

**通用错误码：**

| 错误码 | 说明 | 处理建议 |
|--------|------|----------|
| 0 | 成功 | - |
| 10001 | Token 缺失 | 重新登录 |
| 10002 | Token 无效 | 重新登录 |
| 10003 | Token 已过期 | 使用 RefreshToken 刷新 |
| 10101 | 无访问权限 | 检查角色权限 |
| 10102 | 无家族访问权限 | 检查是否已加入该家族 |
| 10201 | 参数缺失 | 检查必填字段 |
| 10202 | 参数格式错误 | 检查字段格式规范 |
| 10203 | 参数越界 | 检查数值范围 |
| 10301 | 数据不存在 | 检查ID是否正确 |
| 10302 | 家族码无效 | 重新输入或获取新码 |
| 10303 | 关系冲突 | 检查是否已建立关系 |
| 10304 | 成员数量超限 | 清理后重试 |
| 10401 | 系统繁忙 |稍后重试 |
| 10402 | 文件上传失败 | 检查文件大小和格式 |

### 缓存策略

| 缓存场景 | 缓存键（Redis） | TTL | 说明 |
|---------|---------------|-----|------|
| 用户信息 | `user:{userId}` | 30分钟 | 热数据缓存 |
| 家族信息 | `family:{familyId}` | 30分钟 | 热数据缓存 |
| 家族成员树 | `family:{familyId}:tree` | 15分钟 | 族谱结构缓存 |
| 动态列表 | `family:{familyId}:posts:page:{page}` | 5分钟 | 分页缓存 |
| 引导问题 | `guide:question:current` | 1天 | 每日轮换 |
| 家族码 | `family:code:{code}` | 24小时 | 旧码过期过渡 |
| 用户通知数 | `user:{userId}:notification:unread` | 10分钟 | 未读数缓存 |

---

## 一、认证模块 Auth

### 1.1 微信登录

> 微信小程序静默登录，获取/创建用户账号

**请求信息：**

```
POST /auth/login
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| code | String | 是 | wx.login() 获取的临时 code |
| nickName | String | 否 | 用户填写的姓名（拒绝微信授权时） |
| avatarUrl | String | 否 | 头像URL（拒绝微信授权时） |

**请求示例：**

```json
{
  "code": "0611AHaq2LzWr42B0Gaq2Pz5q41AHaqX",
  "nickName": null,
  "avatarUrl": null
}
```

**响应参数：**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| token | String | JWT AccessToken |
| refreshToken | String | 刷新Token |
| expiresIn | Long | Token过期时间（秒，604800=7天） |
| userId | Long | 用户内部ID |
| openid | String | 微信openid |
| hasFamily | Boolean | 是否已加入家族 |
| guideCompleted | Boolean | 是否已完成新手引导 |

**响应示例：**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 604800,
    "userId": 10001,
    "openid": "oABCD12345xxxxxx",
    "hasFamily": true,
    "guideCompleted": false
  }
}
```

---

### 1.2 刷新 Token

> 使用 RefreshToken 获取新的 AccessToken

**请求信息：**

```
POST /auth/refresh
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| refreshToken | String | 是 | 登录时返回的 refreshToken |

**响应参数：** 同 1.1 登录

---

### 1.3 退出登录

**请求信息：**

```
POST /auth/logout
Authorization: Bearer <token>
```

**响应：**

```json
{
  "code": 0,
  "message": "success"
}
```

---

## 二、用户模块 User

### 2.1 获取当前用户信息

**请求信息：**

```
GET /user/me
Authorization: Bearer <token>
```

**响应参数：**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| userId | Long | 用户ID |
| openid | String | 微信openid |
| nickname | String | 昵称 |
| avatarUrl | String | 头像URL |
| gender | Integer | 性别：0-未知 1-男 2-女 |
| phone | String | 手机号（脱敏） |
| easyMode | Boolean | 是否开启简易模式 |
| guideCompleted | Boolean | 是否完成新手引导 |
| notificationSettings | Object | 提醒设置 |
| families | Array | 用户所在家族列表 |
| currentFamilyId | Long | 当前选中家族ID |

**notificationSettings 结构：**

```json
{
  "reminderCycle": "quarterly",  // monthly/quarterly/halfyear/none
  "pushEnabled": true,
  "thatYearEnabled": true,
  "preferTime": "20:00:00"
}
```

---

### 2.2 更新用户资料

**请求信息：**

```
PUT /user/me
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| nickname | String | 否 | 昵称（1-64字） |
| avatarUrl | String | 否 | 头像URL |
| gender | Integer | 否 | 性别：0-未知 1-男 2-女 |
| phone | String | 否 | 手机号 |
| easyMode | Boolean | 否 | 是否开启简易模式 |

---

### 2.3 获取提醒设置

**请求信息：**

```
GET /user/me/notification-settings
Authorization: Bearer <token>
```

**响应：**

```json
{
  "code": 0,
  "data": {
    "reminderCycle": "quarterly",
    "pushEnabled": true,
    "thatYearEnabled": true,
    "preferTime": "20:00:00"
  }
}
```

---

### 2.4 更新提醒设置

**请求信息：**

```
PUT /user/me/notification-settings
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| reminderCycle | String | 是 | 周期：monthly/quarterly/halfyear/none |
| pushEnabled | Boolean | 是 | 是否开启推送 |
| thatYearEnabled | Boolean | 是 | 是否开启那年今日 |
| preferTime | String | 否 | 偏好推送时间（HH:mm:ss，默认20:00:00） |

---

### 2.5 完成新手引导

**请求信息：**

```
POST /user/me/guide-complete
Authorization: Bearer <token>
```

**响应：**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "badge": "记录达人"
  }
}
```

---

### 2.6 获取用户所在家族列表

**请求信息：**

```
GET /user/me/families
Authorization: Bearer <token>
```

**响应参数：**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| familyId | Long | 家族ID |
| familyName | String | 家族名称 |
| familyCode | String | 家族码 |
| role | Integer | 用户角色（1创建者/2管理员/3成员/4守护人/5待审核） |
| memberCount | Integer | 成员数量 |
| coverImage | String | 封面图 |
| isDefault | Boolean | 是否为当前选中家族 |

---

### 2.7 切换当前家族

**请求信息：**

```
PUT /user/me/current-family
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| familyId | Long | 是 | 目标家族ID |

---

## 三、家族模块 Family

### 3.1 创建家族

**请求信息：**

```
POST /families
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| name | String | 是 | 家族名称（2-20字） |
| surname | String | 否 | 家族姓氏 |
| coverImage | String | 否 | 家族封面图URL |

**响应：**

```json
{
  "code": 0,
  "data": {
    "familyId": 1001,
    "name": "李氏家族",
    "familyCode": "AB3C9D",
    "inviteLink": "https://api.zumaiji.com/invite/AB3C9D",
    "creatorId": 10001
  }
}
```

**业务规则：**
- 家族码由后端生成，6位数字+大写字母，不重复
- 创建后自动将当前用户设为创建者（role=1）
- 同时在 `user_family_relation` 中创建关联记录

---

### 3.2 获取家族详情

**请求信息：**

```
GET /families/{familyId}
Authorization: Bearer <token>
```

**路径参数：**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| familyId | Long | 家族ID |

**响应参数：**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| familyId | Long | 家族ID |
| name | String | 家族名称 |
| surname | String | 家族姓氏 |
| familyCode | String | 当前家族码 |
| oldFamilyCode | String | 旧家族码（重置后24小时内存在） |
| oldCodeExpireTime | String | 旧码过期时间 |
| coverImage | String | 封面图 |
| memberCount | Integer | 成员总数 |
| aliveMemberCount | Integer | 在世成员数 |
| deceasedMemberCount | Integer | 已故成员数 |
| creatorId | Long | 创建者ID |
| createTime | String | 创建时间 |
| role | Integer | 当前用户在该家族的角色 |
| guardians | Array | 守护人列表（[{userId, nickname, avatarUrl}]） |
| admins | Array | 管理员列表 |

**缓存：** Redis，键 `family:{familyId}`，TTL 30分钟

---

### 3.3 更新家族信息

**请求信息：**

```
PUT /families/{familyId}
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| name | String | 否 | 家族名称（2-20字） |
| surname | String | 否 | 家族姓氏 |
| coverImage | String | 否 | 封面图URL |

**权限：** 仅创建者和管理员可操作

---

### 3.4 校验家族码

> 加入家族前先查询家族信息

**请求信息：**

```
GET /families/code/{familyCode}
Authorization: Bearer <token>
```

**响应：**

```json
{
  "code": 0,
  "data": {
    "familyId": 1001,
    "name": "李氏家族",
    "memberCount": 12,
    "createTime": "2026-01-01",
    "status": 1
  }
}
```

**说明：** 同时检查 `family_code` 和 `old_family_code`（旧码24小时有效）

---

### 3.5 申请加入家族

**请求信息：**

```
POST /families/{familyId}/apply
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| applyNote | String | 否 | 申请备注（0-200字） |

**业务规则：**
- 同一用户对同一家族不能重复申请（pending状态）
- 如果家族设置为免审，则直接通过并创建 `user_family_relation` 记录
- 如果需要审核，则发送通知给所有管理员

**响应：**

```json
{
  "code": 0,
  "data": {
    "applyId": 20001,
    "status": "pending",  // pending-待审核 passed-已通过 rejected-已拒绝
    "message": "申请已提交，请等待管理员审核"
  }
}
```

---

### 3.6 获取加入申请列表

**请求信息：**

```
GET /families/{familyId}/applications
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| status | Integer | 否 | 筛选状态：1-待审核 2-已通过 3-已拒绝 |
| page | Integer | 否 | 页码（默认1） |
| pageSize | Integer | 否 | 每页数量（默认20） |

**响应参数：**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| list[].applyId | Long | 申请ID |
| list[].userId | Long | 申请人ID |
| list[].nickname | String | 申请人昵称 |
| list[].avatarUrl | String | 申请人头像 |
| list[].applyNote | String | 申请备注 |
| list[].applyTime | String | 申请时间 |
| list[].auditTime | String | 审核时间（已审核时返回） |
| list[].status | Integer | 状态 |

**权限：** 仅创建者和管理员可见

---

### 3.7 审核加入申请

**请求信息：**

```
PUT /families/{familyId}/applications/{applyId}
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| action | String | 是 | 操作：approve（通过）/ reject（拒绝） |
| rejectReason | String | 否 | 拒绝原因（action=reject时填写） |

**业务规则：**
- 审核通过后创建 `user_family_relation`，role=3（普通成员）
- 审核拒绝后更新申请状态，发送通知给申请人

---

### 3.8 重置家族码

**请求信息：**

```
POST /families/{familyId}/reset-code
Authorization: Bearer <token>
```

**业务规则：**
- 仅创建者和管理员可操作
- 重置后旧码保留24小时（存入 `old_family_code` + `old_code_expire_time`）
- 生成新码后通知所有成员

**响应：**

```json
{
  "code": 0,
  "data": {
    "oldFamilyCode": "AB3C9D",
    "oldCodeExpireTime": "2026-04-16 14:30:00",
    "newFamilyCode": "XY7K2M"
  }
}
```

---

### 3.9 退出家族

**请求信息：**

```
POST /families/{familyId}/leave
Authorization: Bearer <token>
```

**业务规则：**
- 创建者不能直接退出，需先转让或解散
- 退出后更新 `user_family_relation.status=0`
- 该用户关联的 `event_participant` 记录标记 `status=0`
- 家族 `member_count` -1，`alive_member_count` -1

---

### 3.10 转让家族

**请求信息：**

```
POST /families/{familyId}/transfer
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| toUserId | Long | 是 | 新创建者用户ID |
| reason | String | 否 | 转让原因 |

**业务规则：**
- 仅创建者可操作
- 转让记录存入 `family_transfer` 表
- 原创建者降级为普通成员（role=3）

---

### 3.11 设置守护人

**请求信息：**

```
PUT /families/{familyId}/guardians
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| guardianIds | Array[Long] | 是 | 守护人用户ID列表（最多2个） |

**业务规则：**
- 仅创建者可操作
- 被设为守护人的用户更新 `user_family_relation.role=4`
- 每个家族最多2位守护人

---

### 3.12 解散家族

**请求信息：**

```
DELETE /families/{familyId}
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| reason | String | 否 | 解散原因 |

**业务规则：**
- 仅创建者可操作
- 执行前需二次确认
- 不可逆操作，记录到 `family_dissolve_log`
- 更新 `family.status=2`
- 软删除所有成员、动态、活动数据

---

### 3.13 获取家族成员列表（分页）

**请求信息：**

```
GET /families/{familyId}/members
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| filter | String | 否 | 筛选：all（全部）/ alive（在世）/ deceased（已故） |
| generation | Integer | 否 | 按辈分筛选 |
| page | Integer | 否 | 页码 |
| pageSize | Integer | 否 | 每页数量 |

---

## 四、成员模块 Member

### 4.1 添加成员

**请求信息：**

```
POST /families/{familyId}/members
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| name | String | 是 | 姓名（1-10字） |
| gender | Integer | 是 | 性别：1-男 2-女 |
| birthDate | String | 条件必填 | 出生日期（yyyy-MM-dd）；在世成员必填，已故成员可为空（未知） |
| deathDate | String | 否 | 逝世日期（已故成员） |
| isDeceased | Boolean | 是 | 是否已故 |
| photos | Array[String] | 是 | 肖像照URL列表（1-3张） |
| profession | String | 否 | 职业（0-30字） |
| contact | String | 否 | 联系方式（加密存储） |
| residence | String | 否 | 常住地 |
| bio | String | 否 | 生平简介（≤500字，仅已故成员） |
| isExternal | Boolean | 是 | 是否为外姓成员（配偶） |
| externalFamilyLink | Long | 否 | 配偶关联的独立家族ID（双向关联时） |
| tombPhoto | String | 否 | 墓碑照片URL（已故成员） |
| tombInscription | String | 否 | 碑文转录 |
| visibility | Integer | 是 | 可见性：1-公开 2-亲属可见 3-仅自己 |

**业务规则：**
- 创建者和管理员可为任意成员，普通成员只能为自己创建记录
- 同时建立和创建者的默认关系（通过前端传递 relationId 或后端自动建立）
- `generation` 在创建关系后由应用层计算更新

---

### 4.2 获取成员详情

**请求信息：**

```
GET /families/{familyId}/members/{memberId}
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| currentUserId | Long | 否 | 当前用户ID（用于权限判断） |

**响应参数：**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| memberId | Long | 成员ID |
| familyId | Long | 所属家族ID |
| name | String | 姓名 |
| gender | Integer | 性别 |
| birthDate | String | 出生日期 |
| deathDate | String | 逝世日期 |
| isDeceased | Boolean | 是否已故 |
| photos | Array[String] | 肖像照列表 |
| profession | String | 职业 |
| contact | String | 联系方式（脱敏） |
| residence | String | 常住地 |
| bio | String | 生平简介 |
| generation | Integer | 辈分 |
| isExternal | Boolean | 是否外姓成员 |
| tombPhoto | String | 墓碑照片 |
| tombInscription | String | 碑文 |
| relations | Array | 该成员的所有关系 |
| userId | Long | 关联用户ID（未注册时为null） |
| wechatNickname | String | 微信昵称（已注册成员） |
| canEdit | Boolean | 当前用户是否有编辑权限 |
| canDelete | Boolean | 当前用户是否有删除权限 |

**可见性控制：**
- `visibility=3`（仅自己）时，非本人和管理员返回脱敏数据

---

### 4.3 更新成员信息

**请求信息：**

```
PUT /families/{familyId}/members/{memberId}
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：** 同 4.1（所有字段均可选，只传需更新的）

**权限：** 创建者/管理员可编辑任意成员，普通成员只能编辑自己

---

### 4.4 删除成员

**请求信息：**

```
DELETE /families/{familyId}/members/{memberId}
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| anonymize | Boolean | 否 | 是否保留记录匿名化（默认true） |

**业务规则：**
- `anonymize=true`：保留动态记录，成员信息匿名化
- `anonymize=false`（管理员/创建者可选）：删除所有关联动态
- 删除后更新家族 `member_count`、`alive/deceased_member_count`
- 守护人被删除时自动取消守护人资格

---

### 4.5 获取成员关系列表

> 获取指定成员的所有关系

**请求信息：**

```
GET /families/{familyId}/members/{memberId}/relations
Authorization: Bearer <token>
```

**响应参数：**

```json
{
  "code": 0,
  "data": [
    {
      "relationId": 30001,
      "targetMemberId": 50002,
      "targetMemberName": "李明",
      "targetMemberAvatar": "https://...",
      "relationType": 1,
      "relationLabel": "father",
      "displayTitle": "父亲",
      "relationNote": null,
      "isBidirectional": true
    }
  ]
}
```

---

## 五、关系模块 Relation

### 5.1 创建关系

**请求信息：**

```
POST /families/{familyId}/relations
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| memberAId | Long | 是 | 成员A的ID |
| memberBId | Long | 是 | 成员B的ID |
| relationType | Integer | 是 | 关系类型：1-血缘 2-配偶 3-结拜 4-认亲 |
| relationLabel | String | 是 | 关系标签：father/mother/son/daughter/sibling/spouse/sworn/adoptive |
| displayTitle | String | 否 | 自定义称谓 |
| relationNote | String | 否 | 关系备注（如结拜年份） |
| isBidirectional | Boolean | 否 | 是否双向（默认血缘/配偶=是，结拜/认亲=否） |

**业务规则：**
- 血缘/配偶关系自动创建双向记录
- 结拜/认亲可选单向或双向
- 不能创建重复关系（唯一约束：`member_a_id + member_b_id + relation_type`）
- 创建血缘关系时自动计算辈分（更新 `member.generation`）

**辈分计算规则：**
- 配偶关系：不改变辈分
- 父母关系：memberB 的 generation = memberA.generation + 1
- 子女关系：memberB 的 generation = memberA.generation - 1
- 结拜/认亲：不改变辈分

---

### 5.2 获取关系详情

**请求信息：**

```
GET /families/{familyId}/relations/{relationId}
Authorization: Bearer <token>
```

---

### 5.3 更新关系

**请求信息：**

```
PUT /families/{familyId}/relations/{relationId}
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| displayTitle | String | 否 | 自定义称谓 |
| relationNote | String | 否 | 关系备注 |
| isBidirectional | Boolean | 否 | 是否双向 |

---

### 5.4 删除关系

**请求信息：**

```
DELETE /families/{familyId}/relations/{relationId}
Authorization: Bearer <token>
```

**业务规则：**
- 删除血缘关系时辈分不变（辈分通过其他关系链计算）
- 删除配偶关系时同步更新 `member.is_external` 和 `family_cross_link`

---

### 5.5 获取称谓建议

> 根据关系类型自动计算可用称谓列表

**请求信息：**

```
GET /families/{familyId}/relations/title-suggestions
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| relationType | Integer | 是 | 关系类型：1-血缘 2-配偶 3-结拜 4-认亲 |
| relationLabel | String | 是 | 关系标签 |
| targetGender | Integer | 是 | 目标成员性别：1-男 2-女 |

**响应：**

```json
{
  "code": 0,
  "data": {
    "suggestions": ["父亲", "爸爸", "爸"],
    "default": "父亲"
  }
}
```

---

## 六、动态模块 Post

### 6.1 发布动态

**请求信息：**

```
POST /families/{familyId}/posts
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| memberId | Long | 是 | 发布成员ID |
| templateType | Integer | 是 | 模板类型：1-工作 2-家庭 3-宝宝 4-健康 5-心情 6-自由 |
| tags | Array[String] | 否 | 标签列表：work/study/family/health/achievement/travel/other |
| content | String | 是 | 文字内容（≤300字） |
| images | Array[String] | 否 | 图片URL列表（最多3张） |
| audio | String | 否 | 音频URL（≤60秒） |
| audioDuration | Integer | 否 | 音频时长（秒） |
| location | String | 否 | 地点文本 |
| weather | String | 否 | 天气状况 |
| temperature | Integer | 否 | 温度（摄氏度） |
| eventDate | String | 是 | 事件发生日期（yyyy-MM-dd） |
| visibility | Integer | 是 | 可见性：1-公开 2-亲属可见 3-仅自己 |

**业务规则：**
- 前端传 memberId，后端通过 userId 鉴权确认操作权限
- 图片上传到云存储后返回 URL
- 发布成功后：
  1. 写入 `post` 表
  2. 写入 `post_tag` 表（多对多）
  3. 更新 `post_search_fts` 全文检索表
  4. 如果是草稿发布，标记草稿 `status=0`
  5. 家族 `post_count++`（如果有此字段）

---

### 6.2 获取动态墙列表

> 家族动态墙，按时间倒序

**请求信息：**

```
GET /families/{familyId}/posts
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| page | Integer | 否 | 页码（默认1） |
| pageSize | Integer | 否 | 每页数量（默认20，最大100） |
| filterType | String | 否 | 筛选类型：all（全部）/ post（仅动态）/ event（仅活动） |
| templateType | Integer | 否 | 按模板类型筛选 |
| tag | String | 否 | 按标签筛选 |
| startDate | String | 否 | 开始日期（yyyy-MM-dd） |
| endDate | String | 否 | 结束日期（yyyy-MM-dd） |
| sort | String | 否 | 排序：time（默认时间倒序） |

**响应参数：**

```json
{
  "code": 0,
  "data": {
    "list": [
      {
        "postId": 40001,
        "memberId": 50001,
        "authorName": "李明",
        "authorAvatar": "https://...",
        "templateType": 2,
        "templateName": "家庭新动态",
        "tags": ["family"],
        "content": "今天带女儿去了植物园...",
        "images": ["https://..."],
        "audio": null,
        "location": "北京",
        "weather": "晴",
        "temperature": 28,
        "eventDate": "2026-04-14",
        "commentCount": 0,
        "likeCount": 0,
        "createTime": "2026-04-14 15:30:00"
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "total": 156,
      "totalPages": 8
    }
  }
}
```

**缓存：** Redis，键 `family:{familyId}:posts:page:{page}:filter:{filterType}`，TTL 5分钟

**查询索引：** `(family_id, event_date DESC, create_time DESC)`

---

### 6.3 获取动态详情

**请求信息：**

```
GET /families/{familyId}/posts/{postId}
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| currentUserId | Long | 否 | 当前用户ID（用于可见性判断） |

**响应：**

```json
{
  "code": 0,
  "data": {
    "postId": 40001,
    "memberId": 50001,
    "authorName": "李明",
    "authorAvatar": "https://...",
    "memberPhotos": ["https://..."],
    "templateType": 2,
    "tags": ["family"],
    "content": "今天带女儿去了植物园...",
    "images": ["https://..."],
    "audio": "https://...",
    "audioDuration": 45,
    "location": "北京",
    "weather": "晴",
    "temperature": 28,
    "eventDate": "2026-04-14",
    "visibility": 1,
    "commentCount": 0,
    "likeCount": 0,
    "createTime": "2026-04-14 15:30:00",
    "updateTime": "2026-04-14 15:30:00",
    "canEdit": true,
    "canDelete": true
  }
}
```

---

### 6.4 更新动态

**请求信息：**

```
PUT /families/{familyId}/posts/{postId}
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：** 同 6.1（所有字段均可选）

**权限：** 仅发布者本人可编辑

---

### 6.5 删除动态

**请求信息：**

```
DELETE /families/{familyId}/posts/{postId}
Authorization: Bearer <token>
```

**业务规则：**
- 软删除：`status=0`，`deleted_at=now()`
- 更新全文检索表 `post_search_fts`（逻辑删除或标记）

---

### 6.6 获取个人时间轴

> 合并「自己发布的动态」和「参与过的活动」，按时间倒序

**请求信息：**

```
GET /families/{familyId}/members/{memberId}/timeline
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| page | Integer | 否 | 页码（默认1） |
| pageSize | Integer | 否 | 每页数量（默认20） |
| contentType | String | 否 | 筛选：all（默认）/ post / event |

**响应参数：**

```json
{
  "code": 0,
  "data": {
    "list": [
      {
        "timelineKey": "post_40001",
        "contentType": "post",
        "contentId": 40001,
        "subType": 2,
        "timelineDate": "2026-04-14",
        "actorName": "李明",
        "actorAvatar": "https://...",
        "content": "今天带女儿去了植物园...",
        "images": ["https://..."],
        "location": "北京"
      },
      {
        "timelineKey": "event_30001",
        "contentType": "event",
        "contentId": 30001,
        "subType": 1,
        "timelineDate": "2026-04-04",
        "actorName": "李明",
        "actorAvatar": "https://...",
        "eventTitle": "2026年清明扫墓",
        "eventId": 30001,
        "participantCount": 8,
        "isCreator": false,
        "images": ["https://..."]
      }
    ],
    "pagination": { ... }
  }
}
```

**说明：** 底层查询 `v_personal_timeline` 视图

---

### 6.7 保存草稿

**请求信息：**

```
POST /families/{familyId}/drafts
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：** 同 6.1（所有字段均可选）

**业务规则：**
- 自动设置 `expire_time = now() + 7天`
- 草稿唯一：以 `user_id + family_id` 为维度，同一用户每个家族最多1份草稿（覆盖更新）

---

### 6.8 获取草稿

**请求信息：**

```
GET /families/{familyId}/drafts/me
Authorization: Bearer <token>
```

**响应：**

```json
{
  "code": 0,
  "data": {
    "draftId": 60001,
    "templateType": 2,
    "content": "今天带女儿...",
    "images": [],
    "audio": null,
    "location": "北京",
    "weather": "晴",
    "temperature": 28,
    "eventDate": "2026-04-14",
    "updateTime": "2026-04-14 16:00:00",
    "expireTime": "2026-04-21 16:00:00"
  }
}
```

---

### 6.9 删除草稿

**请求信息：**

```
DELETE /families/{familyId}/drafts/me
Authorization: Bearer <token>
```

---

### 6.10 获取引导问题

> 获取当日轮换的引导问题

**请求信息：**

```
GET /posts/guide-question
Authorization: Bearer <token>
```

**缓存：** Redis，键 `guide:question:current`，TTL 1天

**响应：**

```json
{
  "code": 0,
  "data": {
    "question": "最近有什么让你开心的小事？",
    "questionId": 1
  }
}
```

**轮换规则：**
- 每日凌晨按 `sort_order` 轮换到下一个问题
- 30条问题循环

---

## 七、活动模块 Event

### 7.1 创建活动

**请求信息：**

```
POST /families/{familyId}/events
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| memberId | Long | 是 | 创建者对应的成员ID |
| eventType | Integer | 是 | 活动类型（V1.0）：1-扫墓 2-家庭聚会 3-节庆 4-婚礼寿宴 5-自定义 |
| title | String | 是 | 活动标题（2-30字） |
| eventDate | String | 是 | 活动时间（yyyy-MM-dd） |
| eventTime | String | 否 | 活动具体时间（HH:mm:ss） |
| location | String | 否 | 活动地点文本 |
| latitude | Double | 否 | 纬度 |
| longitude | Double | 否 | 经度 |
| description | String | 否 | 活动描述（≤200字） |
| atmosphere | String | 否 | 氛围：solemn/tender/lively/sentimental（扫墓） |
| participantIds | Array[Long] | 是 | 参与者成员ID列表 |
| tombObjectIds | Array[Long] | 否 | 祭扫对象成员ID列表（扫墓专用） |
| noteMode | Integer | 否 | 心得撰写方式：1-共同撰写 2-各自填写 |
| images | Array[String] | 否 | 活动照片URL列表（最多9张） |
| notes | Object | 否 | 各参与者心得：`{ "member_id": "content" }`（共同撰写时） |

**业务规则：**
- 同时写入 `event` 表和 `event_participant` 表
- 扫墓活动额外创建 `tomb_offering` 记录
- 发送活动邀请订阅消息给所有参与者

---

### 7.2 获取活动列表

**请求信息：**

```
GET /families/{familyId}/events
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| page | Integer | 否 | 页码（默认1） |
| pageSize | Integer | 否 | 每页数量（默认20） |
| eventType | Integer | 否 | 按类型筛选（V1.0）：1-扫墓 2-聚会 3-节庆 4-婚礼寿宴 5-自定义 |
| status | Integer | 否 | 状态：1-进行中 2-已完成 0-已取消（默认显示1+2） |
| startDate | String | 否 | 开始日期 |
| endDate | String | 否 | 结束日期 |

**响应参数：**

```json
{
  "code": 0,
  "data": {
    "list": [
      {
        "eventId": 30001,
        "eventType": 1,
        "eventTypeName": "扫墓",
        "title": "2026年清明扫墓",
        "eventDate": "2026-04-04",
        "location": "北京八达岭陵园",
        "participantCount": 8,
        "images": ["https://..."],
        "atmosphere": "solemn",
        "status": 2,
        "creatorMemberId": 50001,
        "creatorName": "李明",
        "createTime": "2026-04-01 10:00:00"
      }
    ],
    "pagination": { ... }
  }
}
```

**查询索引：** `(family_id, event_date DESC)`

---

### 7.3 获取活动详情

**请求信息：**

```
GET /families/{familyId}/events/{eventId}
Authorization: Bearer <token>
```

**响应参数：**

```json
{
  "code": 0,
  "data": {
    "eventId": 30001,
    "eventType": 1,
    "title": "2026年清明扫墓",
    "eventDate": "2026-04-04",
    "eventTime": "09:00:00",
    "location": "北京八达岭陵园",
    "latitude": 40.3521,
    "longitude": 116.5623,
    "description": "清明节家族扫墓祭祖",
    "atmosphere": "solemn",
    "images": ["https://..."],
    "creatorMemberId": 50001,
    "creatorName": "李明",
    "creatorAvatar": "https://...",
    "status": 2,
    "participants": [
      {
        "memberId": 50001,
        "memberName": "李明",
        "memberAvatar": "https://...",
        "isTombObject": false,
        "isCreator": true,
        "isCurrentUser": true,
        "noteContent": "清明时节雨纷纷...",
        "noteVisibility": 1
      }
    ],
    "tombObjects": [
      {
        "memberId": 50005,
        "memberName": "李建国",
        "birthDate": "1940-03-01",
        "deathDate": "2020-05-12",
        "tombPhoto": "https://...",
        "tombInscription": "先祖父李公讳建国之墓"
      }
    ],
    "offerings": {
      "offeringList": [
        { "name": "香烛", "count": "3炷", "photo": "https://..." },
        { "name": "鲜花", "count": "1束" }
      ]
    },
    "noteMode": 2,
    "createTime": "2026-04-01 10:00:00",
    "canEdit": true,
    "canDelete": true
  }
}
```

---

### 7.4 更新活动

**请求信息：**

```
PUT /families/{familyId}/events/{eventId}
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：** 同 7.1（所有字段均可选）

**权限：** 仅创建者和管理员可编辑

---

### 7.5 删除活动

**请求信息：**

```
DELETE /families/{familyId}/events/{eventId}
Authorization: Bearer <token>
```

**权限：** 仅创建者可删除

---

### 7.6 添加/更新活动参与者

**请求信息：**

```
POST /families/{familyId}/events/{eventId}/participants
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| memberId | Long | 是 | 成员ID |
| isTombObject | Boolean | 否 | 是否为祭扫对象（扫墓时） |

---

### 7.7 移除活动参与者

**请求信息：**

```
DELETE /families/{familyId}/events/{eventId}/participants/{memberId}
Authorization: Bearer <token>
```

---

### 7.8 记录祭品（扫墓专用）

**请求信息：**

```
POST /families/{familyId}/events/{eventId}/offerings
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| offeringList | Array[Object] | 是 | 祭品列表 |
| offeringList[].name | String | 是 | 祭品名称 |
| offeringList[].count | String | 否 | 数量描述 |
| offeringList[].photo | String | 否 | 祭品照片URL |

**业务规则：** 与 `event.id` 一对一关联，UPSERT 语义

---

### 7.9 记录心得

**请求信息：**

```
POST /families/{familyId}/events/{eventId}/notes
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| memberId | Long | 是 | 心得撰写者成员ID |
| content | String | 是 | 心得内容（≤200字） |
| visibility | Integer | 否 | 心得可见性：1-公开 2-亲属可见 3-仅自己（默认2） |

**业务规则：**
- 各自填写模式：写入 `event_participant.note_content`
- 共同撰写模式：写入 `event.notes` JSON

---

### 7.10 完成活动

**请求信息：**

```
POST /families/{familyId}/events/{eventId}/complete
Authorization: Bearer <token>
```

**业务规则：** 更新 `event.status = 2`（已完成）

---

### 7.11 获取扫墓专项数据

**请求信息：**

```
GET /families/{familyId}/events/tomb-sweeping
Authorization: Bearer <token>
```

**说明：** 获取已故成员列表（用于祭扫对象选择）

**响应：**

```json
{
  "code": 0,
  "data": {
    "deceasedMembers": [
      {
        "memberId": 50005,
        "name": "李建国",
        "birthDate": "1940-03-01",
        "deathDate": "2020-05-12",
        "tombPhoto": "https://...",
        "generation": 1
      }
    ],
    "recentTombEvents": [
      {
        "eventId": 30001,
        "eventDate": "2026-04-04",
        "title": "2026年清明扫墓",
        "participantCount": 8
      }
    ]
  }
}
```

---

## 八、提醒模块 Reminder

### 8.1 创建提醒

**请求信息：**

```
POST /families/{familyId}/reminders
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| memberId | Long | 否 | 关联成员ID（忌日提醒时必填） |
| reminderType | Integer | 是 | 提醒类型：1-忌日 2-周期 3-自定义 |
| lunarDate | String | 否 | 农历日期（如"初一"、"四月十五"） |
| gregorianDate | String | 是 | 公历日期（yyyy-MM-dd） |
| reminderText | String | 是 | 提醒文案（≤200字） |
| advanceDays | Integer | 否 | 提前天数（默认3） |
| isEnabled | Boolean | 否 | 是否启用（默认true） |
| preferTime | String | 否 | 偏好推送时间（HH:mm:ss，默认20:00:00） |
| isLunar | Boolean | 否 | 日期来源：false-公历 true-农历（默认false） |

**业务规则：**
- 忌日提醒（type=1）：每年自动重复，`next_trigger` 自动计算为当年忌日 - advance_days
- 周期提醒（type=2）：按用户设置的周期自动计算下次触发时间
- 自定义（type=3）：单次触发，`next_trigger` = 用户指定日期

---

### 8.2 获取提醒列表

**请求信息：**

```
GET /families/{familyId}/reminders
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| reminderType | Integer | 否 | 按类型筛选 |
| isEnabled | Boolean | 否 | 筛选启用状态 |
| page | Integer | 否 | 页码 |
| pageSize | Integer | 否 | 每页数量 |

---

### 8.3 更新提醒

**请求信息：**

```
PUT /families/{familyId}/reminders/{reminderId}
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：** 同 8.1（所有字段均可选）

---

### 8.4 删除提醒

**请求信息：**

```
DELETE /families/{familyId}/reminders/{reminderId}
Authorization: Bearer <token>
```

---

### 8.5 获取那年今日数据

**请求信息：**

```
GET /families/{familyId}/memories/today
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| page | Integer | 否 | 页码 |
| pageSize | Integer | 否 | 每页数量 |

**响应：**

```json
{
  "code": 0,
  "data": {
    "date": "2026-04-15",
    "list": [
      {
        "sourceType": 1,
        "sourceId": 40001,
        "content": "今天带女儿去了植物园，她第一次看到捕蝇草...",
        "coverImage": "https://...",
        "authorName": "李明",
        "eventDate": "2025-04-15",
        "yearsAgo": 1
      }
    ],
    "pagination": { ... }
  }
}
```

**说明：** 查询 `memory_this_day` 预生成表，返回今日应推送的往年数据

---

## 九、通知模块 Notification

### 9.1 获取通知列表

**请求信息：**

```
GET /notifications
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| isRead | Boolean | 否 | 筛选已读/未读 |
| page | Integer | 否 | 页码 |
| pageSize | Integer | 否 | 每页数量 |

**响应参数：**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| list[].id | Long | 通知ID |
| list[].type | Integer | 通知类型：1-加入申请 2-申请通过 3-申请拒绝 4-活动邀请 5-忌日提醒 6-周期提醒 7-继承提醒 8-那年今日 |
| list[].title | String | 通知标题 |
| list[].content | String | 通知内容 |
| list[].relatedType | String | 关联类型 |
| list[].relatedId | Long | 关联ID |
| list[].actionUrl | String | 点击跳转路径 |
| list[].isRead | Boolean | 是否已读 |
| list[].createTime | String | 创建时间 |

---

### 9.2 标记单条已读

**请求信息：**

```
PUT /notifications/{notificationId}/read
Authorization: Bearer <token>
```

---

### 9.3 标记全部已读

**请求信息：**

```
PUT /notifications/read-all
Authorization: Bearer <token>
```

---

### 9.4 获取未读数

**请求信息：**

```
GET /notifications/unread-count
Authorization: Bearer <token>
```

**缓存：** Redis，键 `user:{userId}:notification:unread`，TTL 10分钟

**响应：**

```json
{
  "code": 0,
  "data": {
    "count": 5
  }
}
```

---

## 十、搜索模块 Search

### 10.1 关键词搜索

**请求信息：**

```
GET /families/{familyId}/search
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| keyword | String | 是 | 搜索关键词（1-50字） |
| type | String | 否 | 搜索类型：all（默认）/ post / member / event |
| page | Integer | 否 | 页码 |
| pageSize | Integer | 否 | 每页数量 |

**业务规则：**
- 使用 MySQL 8.0 FULLTEXT 全文检索（`post_search_fts` 表）
- 支持模糊匹配
- 按相关度排序
- 搜索历史记录存入 `search_history` 表

**响应参数：**

```json
{
  "code": 0,
  "data": {
    "keyword": "植物园",
    "list": [
      {
        "resultType": "post",
        "resultId": 40001,
        "title": null,
        "snippet": "今天带女儿去了植物园，她第一次看到捕蝇草...",
        "highlightSnippet": "今天带女儿去了<span class='highlight'>植物园</span>，她第一次看到捕蝇草...",
        "authorName": "李明",
        "eventDate": "2026-04-14",
        "images": ["https://..."]
      },
      {
        "resultType": "member",
        "resultId": 50002,
        "title": "李明",
        "snippet": "50岁 · 北京",
        "highlightSnippet": "<span class='highlight'>李明</span>",
        "avatar": "https://..."
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "total": 5,
      "totalPages": 1
    }
  }
}
```

---

### 10.2 获取搜索历史

**请求信息：**

```
GET /search/history
Authorization: Bearer <token>
```

**响应：** 最近10条搜索历史（按时间倒序）

---

### 10.3 清除搜索历史

**请求信息：**

```
DELETE /search/history
Authorization: Bearer <token>
```

---

## 十一、家族树模块 FamilyTree

### 11.1 获取家族树结构

> 获取完整的家族树可视化数据

**请求信息：**

```
GET /families/{familyId}/tree
Authorization: Bearer <token>
```

**缓存：** Redis，键 `family:{familyId}:tree`，TTL 15分钟

**响应参数：**

```json
{
  "code": 0,
  "data": {
    "familyId": 1001,
    "familyName": "李氏家族",
    "surname": "李",
    "nodes": [
      {
        "memberId": 50001,
        "name": "李建国",
        "gender": 1,
        "generation": 0,
        "photos": ["https://..."],
        "isDeceased": true,
        "isExternal": false,
        "isHighlighted": false,
        "parentIds": [],
        "childrenIds": [50002, 50003],
        "spouseId": 50004
      }
    ],
    "links": [
      {
        "fromMemberId": 50001,
        "toMemberId": 50002,
        "relationType": 1,
        "relationLabel": "father",
        "lineStyle": "solid"
      }
    ]
  }
}
```

**节点布局规则：**
- `parentIds`：父节点ID列表（血缘/认亲）
- `childrenIds`：子节点ID列表
- `spouseId`：配偶节点ID
- 配偶节点 `isExternal=true`，视觉上用虚线边框

---

### 11.2 获取成员关系图

> 获取指定成员的三代关系网络（用于族谱交互）

**请求信息：**

```
GET /families/{familyId}/members/{memberId}/network
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| depth | Integer | 否 | 关系深度（默认2，最大3） |

---

## 十二、文件模块 File

### 12.1 上传图片

> 通用图片上传接口

**请求信息：**

```
POST /files/upload/image
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

**Form 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| file | File | 是 | 图片文件（支持 jpg/png/webp，最大2MB） |
| bizType | String | 是 | 业务类型：post/member/event/avatar/cover |
| familyId | Long | 否 | 家族ID（部分业务类型需要） |

**响应：**

```json
{
  "code": 0,
  "data": {
    "url": "https://cdn.zumaiji.com/uploads/2026/04/14/abc123.jpg",
    "fileId": "file_abc123",
    "size": 1024000,
    "width": 1920,
    "height": 1080
  }
}
```

**自动处理：**
- 超过2MB时自动压缩至80%质量，长边≤1920px
- 生成缩略图（长边200px）用于列表展示

---

### 12.2 上传音频

**请求信息：**

```
POST /files/upload/audio
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

**Form 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| file | File | 是 | 音频文件（支持 m4a/mp3/aac，最大2MB） |
| duration | Integer | 是 | 音频时长（秒，最大60） |

**响应：**

```json
{
  "code": 0,
  "data": {
    "url": "https://cdn.zumaiji.com/uploads/2026/04/14/audio_xyz.m4a",
    "duration": 45,
    "size": 512000
  }
}
```

**自动处理：**
- 格式统一转为 AAC，码率64kbps

---

### 12.3 删除文件

**请求信息：**

```
DELETE /files/{fileKey}
Authorization: Bearer <token>
```

---

## 十三、导出模块 Export

### 13.1 发起数据导出

**请求信息：**

```
POST /families/{familyId}/export
Authorization: Bearer <token>
Content-Type: application/json
```

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| exportType | String | 是 | 导出类型：pdf（V1.0）/ json |
| scope | String | 否 | 导出范围：all（全部）/ members（仅成员）/ posts（仅动态） |
| memberIds | Array[Long] | 否 | 指定成员ID（scope=members时） |
| startDate | String | 否 | 开始日期 |
| endDate | String | 否 | 结束日期 |

**响应：**

```json
{
  "code": 0,
  "data": {
    "taskId": "export_abc123",
    "status": "processing",
    "estimatedTime": 30,
    "message": "导出任务已创建，预计30秒完成"
  }
}
```

**说明：** PDF导出为异步任务，后端生成后返回下载链接

---

### 13.2 查询导出状态/下载

**请求信息：**

```
GET /families/{familyId}/export/{taskId}
Authorization: Bearer <token>
```

**响应：**

```json
{
  "code": 0,
  "data": {
    "taskId": "export_abc123",
    "status": "completed",
    "downloadUrl": "https://cdn.zumaiji.com/exports/family_1001_20260415.pdf",
    "expireTime": "2026-04-16 14:30:00",
    "fileSize": 10485760
  }
}
```

---

## 十四、系统模块 System

### 14.1 获取系统配置

**请求信息：**

```
GET /system/config
Authorization: Bearer <token>
```

**Query 参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| keys | String | 否 | 配置键列表，逗号分隔（返回全部则不传） |

**响应：**

```json
{
  "code": 0,
  "data": {
    "app_name": "族脉记",
    "version": "1.0.0",
    "family_code_length": "6",
    "max_post_content": "300",
    "max_post_images": "3",
    "max_event_images": "9",
    "max_audio_duration": "60",
    "reminder_advance_days": "3",
    "push_max_daily": "5"
  }
}
```

---

### 14.2 获取枚举值

> 获取系统中所有枚举的可用选项

**请求信息：**

```
GET /system/enums
Authorization: Bearer <token>
```

**响应：**

```json
{
  "code": 0,
  "data": {
    "gender": [
      { "value": 0, "label": "未知" },
      { "value": 1, "label": "男" },
      { "value": 2, "label": "女" }
    ],
    "role": [
      { "value": 1, "label": "创建者" },
      { "value": 2, "label": "管理员" },
      { "value": 3, "label": "普通成员" },
      { "value": 4, "label": "守护人" },
      { "value": 5, "label": "待审核" }
    ],
    "visibility": [
      { "value": 1, "label": "公开" },
      { "value": 2, "label": "亲属可见" },
      { "value": 3, "label": "仅自己" }
    ],
    "relationType": [
      { "value": 1, "label": "血缘" },
      { "value": 2, "label": "配偶" },
      { "value": 3, "label": "结拜" },
      { "value": 4, "label": "认亲" }
    ],
    "templateType": [
      { "value": 1, "label": "工作新变动" },
      { "value": 2, "label": "家庭新动态" },
      { "value": 3, "label": "宝宝成长记" },
      { "value": 4, "label": "健康日记" },
      { "value": 5, "label": "今日心情" },
      { "value": 6, "label": "自由记录" }
    ],
    "eventType": [
      { "value": 1, "label": "扫墓" },
      { "value": 2, "label": "家庭聚会" },
      { "value": 3, "label": "节庆" },
      { "value": 4, "label": "婚礼寿宴" },
      { "value": 5, "label": "自定义" }
    ],
    "reminderType": [
      { "value": 1, "label": "忌日提醒" },
      { "value": 2, "label": "周期提醒" },
      { "value": 3, "label": "自定义" }
    ],
    "atmosphere": [
      { "value": "solemn", "label": "庄重" },
      { "value": "tender", "label": "温情" },
      { "value": "lively", "label": "热闹" },
      { "value": "sentimental", "label": "感慨" }
    ]
  }
}
```

---

## 接口清单汇总

| 编号 | 模块 | 接口路径 | 方法 | 说明 |
|------|------|---------|------|------|
| 1.1 | Auth | `/auth/login` | POST | 微信登录 |
| 1.2 | Auth | `/auth/refresh` | POST | 刷新Token |
| 1.3 | Auth | `/auth/logout` | POST | 退出登录 |
| 2.1 | User | `/user/me` | GET | 获取当前用户信息 |
| 2.2 | User | `/user/me` | PUT | 更新用户资料 |
| 2.3 | User | `/user/me/notification-settings` | GET | 获取提醒设置 |
| 2.4 | User | `/user/me/notification-settings` | PUT | 更新提醒设置 |
| 2.5 | User | `/user/me/guide-complete` | POST | 完成新手引导 |
| 2.6 | User | `/user/me/families` | GET | 获取用户家族列表 |
| 2.7 | User | `/user/me/current-family` | PUT | 切换当前家族 |
| 3.1 | Family | `/families` | POST | 创建家族 |
| 3.2 | Family | `/families/{familyId}` | GET | 获取家族详情 |
| 3.3 | Family | `/families/{familyId}` | PUT | 更新家族信息 |
| 3.4 | Family | `/families/code/{familyCode}` | GET | 校验家族码 |
| 3.5 | Family | `/families/{familyId}/apply` | POST | 申请加入家族 |
| 3.6 | Family | `/families/{familyId}/applications` | GET | 获取加入申请列表 |
| 3.7 | Family | `/families/{familyId}/applications/{applyId}` | PUT | 审核加入申请 |
| 3.8 | Family | `/families/{familyId}/reset-code` | POST | 重置家族码 |
| 3.9 | Family | `/families/{familyId}/leave` | POST | 退出家族 |
| 3.10 | Family | `/families/{familyId}/transfer` | POST | 转让家族 |
| 3.11 | Family | `/families/{familyId}/guardians` | PUT | 设置守护人 |
| 3.12 | Family | `/families/{familyId}` | DELETE | 解散家族 |
| 3.13 | Family | `/families/{familyId}/members` | GET | 获取家族成员列表 |
| 4.1 | Member | `/families/{familyId}/members` | POST | 添加成员 |
| 4.2 | Member | `/families/{familyId}/members/{memberId}` | GET | 获取成员详情 |
| 4.3 | Member | `/families/{familyId}/members/{memberId}` | PUT | 更新成员信息 |
| 4.4 | Member | `/families/{familyId}/members/{memberId}` | DELETE | 删除成员 |
| 4.5 | Member | `/families/{familyId}/members/{memberId}/relations` | GET | 获取成员关系列表 |
| 5.1 | Relation | `/families/{familyId}/relations` | POST | 创建关系 |
| 5.2 | Relation | `/families/{familyId}/relations/{relationId}` | GET | 获取关系详情 |
| 5.3 | Relation | `/families/{familyId}/relations/{relationId}` | PUT | 更新关系 |
| 5.4 | Relation | `/families/{familyId}/relations/{relationId}` | DELETE | 删除关系 |
| 5.5 | Relation | `/families/{familyId}/relations/title-suggestions` | GET | 获取称谓建议 |
| 6.1 | Post | `/families/{familyId}/posts` | POST | 发布动态 |
| 6.2 | Post | `/families/{familyId}/posts` | GET | 获取动态墙列表 |
| 6.3 | Post | `/families/{familyId}/posts/{postId}` | GET | 获取动态详情 |
| 6.4 | Post | `/families/{familyId}/posts/{postId}` | PUT | 更新动态 |
| 6.5 | Post | `/families/{familyId}/posts/{postId}` | DELETE | 删除动态 |
| 6.6 | Post | `/families/{familyId}/members/{memberId}/timeline` | GET | 获取个人时间轴 |
| 6.7 | Post | `/families/{familyId}/drafts` | POST | 保存草稿 |
| 6.8 | Post | `/families/{familyId}/drafts/me` | GET | 获取草稿 |
| 6.9 | Post | `/families/{familyId}/drafts/me` | DELETE | 删除草稿 |
| 6.10 | Post | `/posts/guide-question` | GET | 获取引导问题 |
| 7.1 | Event | `/families/{familyId}/events` | POST | 创建活动 |
| 7.2 | Event | `/families/{familyId}/events` | GET | 获取活动列表 |
| 7.3 | Event | `/families/{familyId}/events/{eventId}` | GET | 获取活动详情 |
| 7.4 | Event | `/families/{familyId}/events/{eventId}` | PUT | 更新活动 |
| 7.5 | Event | `/families/{familyId}/events/{eventId}` | DELETE | 删除活动 |
| 7.6 | Event | `/families/{familyId}/events/{eventId}/participants` | POST | 添加参与者 |
| 7.7 | Event | `/families/{familyId}/events/{eventId}/participants/{memberId}` | DELETE | 移除参与者 |
| 7.8 | Event | `/families/{familyId}/events/{eventId}/offerings` | POST | 记录祭品 |
| 7.9 | Event | `/families/{familyId}/events/{eventId}/notes` | POST | 记录心得 |
| 7.10 | Event | `/families/{familyId}/events/{eventId}/complete` | POST | 完成活动 |
| 7.11 | Event | `/families/{familyId}/events/tomb-sweeping` | GET | 获取扫墓专项数据 |
| 8.1 | Reminder | `/families/{familyId}/reminders` | POST | 创建提醒 |
| 8.2 | Reminder | `/families/{familyId}/reminders` | GET | 获取提醒列表 |
| 8.3 | Reminder | `/families/{familyId}/reminders/{reminderId}` | PUT | 更新提醒 |
| 8.4 | Reminder | `/families/{familyId}/reminders/{reminderId}` | DELETE | 删除提醒 |
| 8.5 | Reminder | `/families/{familyId}/memories/today` | GET | 获取那年今日 |
| 9.1 | Notification | `/notifications` | GET | 获取通知列表 |
| 9.2 | Notification | `/notifications/{notificationId}/read` | PUT | 标记单条已读 |
| 9.3 | Notification | `/notifications/read-all` | PUT | 标记全部已读 |
| 9.4 | Notification | `/notifications/unread-count` | GET | 获取未读数 |
| 10.1 | Search | `/families/{familyId}/search` | GET | 关键词搜索 |
| 10.2 | Search | `/search/history` | GET | 获取搜索历史 |
| 10.3 | Search | `/search/history` | DELETE | 清除搜索历史 |
| 11.1 | FamilyTree | `/families/{familyId}/tree` | GET | 获取家族树结构 |
| 11.2 | FamilyTree | `/families/{familyId}/members/{memberId}/network` | GET | 获取成员关系网络 |
| 12.1 | File | `/files/upload/image` | POST | 上传图片 |
| 12.2 | File | `/files/upload/audio` | POST | 上传音频 |
| 12.3 | File | `/files/{fileKey}` | DELETE | 删除文件 |
| 13.1 | Export | `/families/{familyId}/export` | POST | 发起数据导出 |
| 13.2 | Export | `/families/{familyId}/export/{taskId}` | GET | 查询导出状态/下载 |
| 14.1 | System | `/system/config` | GET | 获取系统配置 |
| 14.2 | System | `/system/enums` | GET | 获取枚举值 |

**接口总数：54个**

---

*文档版本记录：*

| 版本 | 日期 | 修订人 | 修订说明 |
|------|------|--------|----------|
| V1.0 | 2026-04-15 | 元宝 | 初始版本，基于PRD V2.0 + 数据库设计 V1.0 |
| V1.1 | 2026-04-17 | Codex | 以PRD为主收敛V1.0范围：活动类型移除旅行；成员字段约束调整为“出生日期条件必填、肖像照必填” |

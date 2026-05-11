-- ============================================================
-- 族脉记 微信小程序 - MySQL 数据库设计文档
-- 版本：V1.0
-- 日期：2026-04-15
-- 设计者：元宝
-- 数据库版本：MySQL 8.0+
-- 字符集：utf8mb4
-- 排序规则：utf8mb4_unicode_ci
-- ============================================================

-- ----------------------------------------------------------
-- 一、总体设计原则
-- ----------------------------------------------------------
-- 1. 性能优先：小程序查询以家族ID(family_id) + 时间(event_date/create_time) 为核心过滤条件
-- 2. 字段级可见性控制：每张核心数据表都有 visibility 字段，实现「公开/亲属可见/仅自己」三级控制
-- 3. 软删除优先：所有业务表使用 status 字段软删除，不做物理删除，便于数据恢复和审计
-- 4. 冗余设计：动态表冗余 author_name/author_avatar，避免频繁 JOIN 成员表
-- 5. JSON 字段：灵活字段（提醒设置、祭品列表、参与者心得）使用 JSON 类型，减少多表 JOIN
-- 6. 逻辑外键：MySQL 不开外键约束，外键关系在应用层维护，但字段命名保留外键语义
-- 7. 分库分表预留：member_id / post_id / event_id 使用 BIGINT 自增，支持未来分表
-- ----------------------------------------------------------

-- ----------------------------------------------------------
-- 二、配置表
-- ----------------------------------------------------------

-- ----------------------------------------
-- 【配置表1】系统配置表
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `sys_config` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `config_key`    VARCHAR(64)     NOT NULL COMMENT '配置键（唯一）',
    `config_value`  TEXT            NOT NULL COMMENT '配置值（JSON 字符串）',
    `description`   VARCHAR(255)   DEFAULT NULL COMMENT '配置描述',
    `created_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `operator_id`   BIGINT UNSIGNED DEFAULT NULL COMMENT '操作人',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_config_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统配置表';

-- ----------------------------------------
-- 【配置表2】引导问题库（30天轮换）
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `guide_question` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `question`      VARCHAR(200)    NOT NULL COMMENT '引导问题',
    `sort_order`     INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '排序（数字越小优先级越高）',
    `is_active`     TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否启用：0-禁用 1-启用',
    `created_at`    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    KEY `idx_active_sort` (`is_active`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='引导问题库';

-- ----------------------------------------
-- 【配置表3】操作日志表（审计）
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `operation_log` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`       BIGINT UNSIGNED NOT NULL COMMENT '操作用户ID',
    `family_id`     BIGINT UNSIGNED DEFAULT NULL COMMENT '关联家族ID',
    `target_type`    VARCHAR(32)     NOT NULL COMMENT '操作对象类型：user/member/post/event/reminder',
    `target_id`     BIGINT UNSIGNED DEFAULT NULL COMMENT '操作对象ID',
    `action`        VARCHAR(32)     NOT NULL COMMENT '操作类型：create/update/delete/export/permission_change',
    `detail`        JSON            DEFAULT NULL COMMENT '操作详情',
    `ip_address`    VARCHAR(45)      DEFAULT NULL COMMENT 'IP 地址',
    `user_agent`    VARCHAR(255)    DEFAULT NULL COMMENT 'User-Agent',
    `created_at`    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_family_id` (`family_id`),
    KEY `idx_target` (`target_type`, `target_id`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='操作日志表（留存180天）';

-- ----------------------------------------------------------
-- 三、用户与认证
-- ----------------------------------------------------------

-- ----------------------------------------
-- 【核心表1】用户表（User）
-- 说明：每个微信用户在小程序中有且仅有一条记录，openid 唯一
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `user` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键（内部使用）',
    `openid`            VARCHAR(64)     NOT NULL COMMENT '微信 openid（唯一标识）',
    `nickname`          VARCHAR(64)    NOT NULL COMMENT '昵称（微信昵称或手动填写姓名）',
    `avatar_url`        VARCHAR(512)   DEFAULT NULL COMMENT '头像 URL',
    `gender`            TINYINT        NOT NULL DEFAULT 0 COMMENT '性别：0-未知 1-男 2-女',
    `phone`             VARCHAR(20)    DEFAULT NULL COMMENT '手机号（可选，加密存储）',
    `easy_mode`         TINYINT(1)     NOT NULL DEFAULT 0 COMMENT '是否开启简易模式：0-关闭 1-开启',
    `guide_completed`  TINYINT(1)     NOT NULL DEFAULT 0 COMMENT '是否完成新手引导：0-未完成 1-已完成',
    `notification_settings` JSON      DEFAULT NULL COMMENT '提醒设置：{reminder_cycle, push_enabled, that_year_enabled, prefer_time}',_enabled, prefer_time}',
    `create_time`       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '注册时间',
    `last_login_time`   DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最后登录时间',
    `status`            TINYINT        NOT NULL DEFAULT 1 COMMENT '状态：1-正常 0-禁用 2-已注销',
    `deleted_at`        DATETIME       DEFAULT NULL COMMENT '注销时间（软删除）',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_openid` (`openid`),
    KEY `idx_status` (`status`),
    KEY `idx_last_login` (`last_login_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- ----------------------------------------
-- 【核心表2】用户-家族关系表（UserFamilyRelation）
-- 说明：用户与家族的多对多关系，记录用户在每个家族中的角色
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `user_family_relation` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`           BIGINT UNSIGNED NOT NULL COMMENT '用户ID（外键→user.id）',
    `family_id`         BIGINT UNSIGNED NOT NULL COMMENT '家族ID（外键→family.id）',
    `role`              TINYINT         NOT NULL DEFAULT 3 COMMENT '角色：1-创建者 2-管理员 3-普通成员 4-守护人 5-待审核',
    `is_guardian`       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否为守护人：0-否 1-是',
    `join_time`         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '加入时间',
    `audit_time`        DATETIME        DEFAULT NULL COMMENT '审核时间（加入申请通过/拒绝时间）',
    `audit_by`          BIGINT UNSIGNED DEFAULT NULL COMMENT '审核人ID',
    `apply_note`        VARCHAR(200)    DEFAULT NULL COMMENT '申请备注',
    `status`            TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：1-正常 0-已退出 2-已移除',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_family` (`user_id`, `family_id`),
    KEY `idx_family_role` (`family_id`, `role`),
    KEY `idx_user_status` (`user_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户-家族关系表';

-- ----------------------------------------------------------
-- 四、家族核心
-- ----------------------------------------------------------

-- ----------------------------------------
-- 【核心表3】家族表（Family）
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `family` (
    `id`                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `name`                  VARCHAR(40)     NOT NULL COMMENT '家族名称（2-20字）',
    `surname`               VARCHAR(20)     DEFAULT NULL COMMENT '家族姓氏（用于辈分排序）',
    `family_code`           VARCHAR(10)     NOT NULL COMMENT '6位唯一家族码（数字+大写字母）',
    `old_family_code`       VARCHAR(10)     DEFAULT NULL COMMENT '旧家族码（重置后保留24小时）',
    `old_code_expire_time`  DATETIME        DEFAULT NULL COMMENT '旧码过期时间',
    `creator_id`            BIGINT UNSIGNED NOT NULL COMMENT '创建者用户ID（外键→user.id）',
    `cover_image`           VARCHAR(512)    DEFAULT NULL COMMENT '家族封面图 URL',
    `member_count`          INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '成员总数（含已故）',
    `alive_member_count`    INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '在世成员数',
    `deceased_member_count` INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '已故成员数',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `status`                TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：1-正常 2-已解散',
    `deleted_at`           DATETIME         DEFAULT NULL COMMENT '解散时间（软删除）',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_family_code` (`family_code`),
    KEY `idx_creator_id` (`creator_id`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='家族表';

-- ----------------------------------------
-- 【核心表4】成员表（Member）
-- 说明：成员是家族树的节点，每个成员属于一个家族
-- generation：辈分（以创建者为基准代0，向上一代+1，向下一代-1）
-- 配偶/结拜/认亲关系不参与辈分计算
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `member` (
    `id`                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `family_id`             BIGINT UNSIGNED NOT NULL COMMENT '所属家族ID（外键→family.id）',
    `user_id`               BIGINT UNSIGNED DEFAULT NULL COMMENT '关联用户ID（可为空，未注册用户）',
    `name`                  VARCHAR(20)     NOT NULL COMMENT '姓名（1-10字）',
    `gender`                TINYINT         NOT NULL COMMENT '性别：1-男 2-女',
    `birth_date`            DATE            NOT NULL COMMENT '出生日期',
    `death_date`            DATE            DEFAULT NULL COMMENT '逝世日期（仅已故成员）',
    `is_deceased`           TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已故：0-在世 1-已故',
    `photos`                JSON            DEFAULT NULL COMMENT '肖像照URL列表（最多3张，JSON数组）',
    `profession`            VARCHAR(60)     DEFAULT NULL COMMENT '职业（0-30字）',
    `contact`               VARCHAR(100)    DEFAULT NULL COMMENT '联系方式（加密存储）',
    `residence`             VARCHAR(100)    DEFAULT NULL COMMENT '常住地（省市区文本）',
    `bio`                   TEXT            DEFAULT NULL COMMENT '生平简介（已故成员，≤500字）',
    `generation`            INT             DEFAULT 0 COMMENT '辈分（以创建者为代0，祖辈+1，父辈+1，同辈0，子辈-1，孙辈-2）',
    `is_external`           TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否为外姓成员（配偶）：0-否 1-是',
    `external_family_link`  BIGINT UNSIGNED DEFAULT NULL COMMENT '关联的独立家族ID（配偶双向关联时）',
    `tomb_photo`            VARCHAR(512)    DEFAULT NULL COMMENT '墓碑照片URL',
    `tomb_inscription`     TEXT            DEFAULT NULL COMMENT '碑文转录',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `created_by`            BIGINT UNSIGNED NOT NULL COMMENT '创建人用户ID',
    `update_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `visibility`            TINYINT         NOT NULL DEFAULT 1 COMMENT '可见性：1-公开 2-亲属可见 3-仅自己',
    `status`                TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：1-正常 0-已删除',
    `deleted_at`           DATETIME         DEFAULT NULL COMMENT '删除时间（软删除）',
    PRIMARY KEY (`id`),
    KEY `idx_family_id` (`family_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_generation` (`family_id`, `generation`),
    KEY `idx_is_deceased` (`family_id`, `is_deceased`),
    KEY `idx_visibility` (`visibility`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='成员表';

-- ----------------------------------------
-- 【核心表5】关系表（Relation）
-- 说明：记录家族成员之间的亲属关系
-- 血缘/婚姻关系为双向（is_bidirectional=1），结拜/认亲可选双向
-- 辈分根据关系类型和方向自动计算（见触发器/应用层逻辑）
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `relation` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `family_id`         BIGINT UNSIGNED NOT NULL COMMENT '所属家族ID（外键→family.id）',
    `member_a_id`       BIGINT UNSIGNED NOT NULL COMMENT '成员A的ID（外键→member.id）',
    `member_b_id`       BIGINT UNSIGNED NOT NULL COMMENT '成员B的ID（外键→member.id）',
    `relation_type`     TINYINT         NOT NULL COMMENT '关系类型：1-血缘 2-配偶 3-结拜 4-认亲',
    `relation_label`    VARCHAR(32)     NOT NULL COMMENT '关系标签：father/mother/son/daughter/sibling/spouse/sworn/adoptive',
    `display_title`     VARCHAR(20)     DEFAULT NULL COMMENT '自定义称谓（用户手动修改后存储）',
    `relation_note`     VARCHAR(200)    DEFAULT NULL COMMENT '关系备注（如结拜年份、认亲时间）',
    `is_bidirectional`  TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否双向关系：0-单向 1-双向',
    `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `created_by`        BIGINT UNSIGNED NOT NULL COMMENT '创建人用户ID',
    `status`            TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：1-有效 0-已解除',
    PRIMARY KEY (`id`),
    KEY `idx_family_id` (`family_id`),
    KEY `idx_member_a` (`member_a_id`),
    KEY `idx_member_b` (`member_b_id`),
    KEY `idx_relation_type` (`relation_type`),
    -- 防止同一对成员之间重复建立相同类型关系
    UNIQUE KEY `uk_relation_unique` (`member_a_id`, `member_b_id`, `relation_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='关系表（族谱关系）';

-- ----------------------------------------------------------
-- 五、动态记录
-- ----------------------------------------------------------

-- ----------------------------------------
-- 【核心表6】动态表（Post）
-- 说明：核心记录单元，记录个人动态，支持文字+图片+音频
-- author_name/author_avatar：冗余存储，避免频繁 JOIN
-- V1.0 不支持评论/点赞，comment_count/like_count 字段保留但不使用
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `post` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `family_id`         BIGINT UNSIGNED NOT NULL COMMENT '所属家族ID（外键→family.id）',
    `member_id`         BIGINT UNSIGNED NOT NULL COMMENT '发布成员ID（外键→member.id）',
    `author_id`         BIGINT UNSIGNED NOT NULL COMMENT '发布用户ID（外键→user.id）',
    `author_name`       VARCHAR(64)     NOT NULL COMMENT '作者姓名（冗余）',
    `author_avatar`     VARCHAR(512)   DEFAULT NULL COMMENT '作者头像URL（冗余）',
    `template_type`     TINYINT        NOT NULL COMMENT '模板类型：1-工作 2-家庭 3-宝宝 4-健康 5-心情 6-自由',
    `tags`              JSON            DEFAULT NULL COMMENT '标签列表（JSON数组，如 ["family","achievement"]）',
    `content`           TEXT            NOT NULL COMMENT '文字内容（≤300字）',
    `images`            JSON            DEFAULT NULL COMMENT '图片URL列表（最多3张，JSON数组）',
    `audio`             VARCHAR(512)    DEFAULT NULL COMMENT '音频URL（≤60秒）',
    `audio_duration`    SMALLINT        DEFAULT NULL COMMENT '音频时长（秒）',
    `location`          VARCHAR(200)    DEFAULT NULL COMMENT '地点文本',
    `weather`           VARCHAR(20)     DEFAULT NULL COMMENT '天气状况',
    `temperature`       SMALLINT        DEFAULT NULL COMMENT '温度（摄氏度）',
    `event_date`        DATE            NOT NULL COMMENT '事件发生日期',
    `visibility`        TINYINT         NOT NULL DEFAULT 1 COMMENT '可见性：1-公开 2-亲属可见 3-仅自己',
    `comment_count`     INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '评论数（V1.5，V1.0不使用）',
    `like_count`        INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '点赞数（V1.5，V1.0不使用）',
    `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '发布时间',
    `update_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `status`            TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：1-正常 0-已删除 2-已归档',
    `deleted_at`        DATETIME         DEFAULT NULL COMMENT '删除时间',
    PRIMARY KEY (`id`),
    -- 核心查询索引：动态墙（按家族ID + 时间倒序）
    KEY `idx_family_time` (`family_id`, `event_date` DESC, `create_time` DESC),
    -- 个人时间轴（按成员ID + 时间倒序）
    KEY `idx_member_time` (`member_id`, `event_date` DESC, `create_time` DESC),
    -- 按模板类型筛选
    KEY `idx_family_template` (`family_id`, `template_type`, `event_date` DESC),
    -- 搜索索引（标题/内容模糊搜索）
    KEY `idx_visibility_status` (`family_id`, `visibility`, `status`),
    KEY `idx_event_date` (`event_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='动态表';

-- ----------------------------------------
-- 【核心表7】草稿表（Draft）
-- 说明：用户编辑中的动态草稿，网络异常时自动保存
-- 保留7天，超期自动清理
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `draft` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`           BIGINT UNSIGNED NOT NULL COMMENT '用户ID（外键→user.id）',
    `family_id`         BIGINT UNSIGNED NOT NULL COMMENT '所属家族ID',
    `member_id`         BIGINT UNSIGNED DEFAULT NULL COMMENT '关联成员ID',
    `template_type`     TINYINT        DEFAULT NULL COMMENT '模板类型',
    `content`           TEXT            DEFAULT NULL COMMENT '文字内容',
    `images`            JSON            DEFAULT NULL COMMENT '图片URL列表',
    `audio`             VARCHAR(512)    DEFAULT NULL COMMENT '音频URL',
    `audio_duration`    SMALLINT        DEFAULT NULL COMMENT '音频时长（秒）',
    `location`          VARCHAR(200)    DEFAULT NULL COMMENT '地点文本',
    `weather`           VARCHAR(20)     DEFAULT NULL COMMENT '天气',
    `temperature`       SMALLINT        DEFAULT NULL COMMENT '温度',
    `event_date`        DATE            DEFAULT NULL COMMENT '事件发生日期',
    `draft_data`        JSON            DEFAULT NULL COMMENT '完整草稿数据（JSON，保留所有字段状态）',
    `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `expire_time`       DATETIME        NOT NULL COMMENT '过期时间（创建+7天）',
    `status`            TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：1-有效 0-已使用（已发布）',
    PRIMARY KEY (`id`),
    KEY `idx_user_status` (`user_id`, `status`),
    KEY `idx_expire_time` (`expire_time`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='草稿表';

-- ----------------------------------------------------------
-- 六、家族活动
-- ----------------------------------------------------------

-- ----------------------------------------
-- 【核心表8】活动表（Event）
-- 说明：家族集体活动记录，支持扫墓/聚会/节庆/婚礼寿宴/自定义
-- notes 字段存储各参与者的心得：{ "member_id_1": { "content": "...", "create_time": "..." } }
-- atmosphere：氛围标签（solemn/tender/lively/sentimental），扫墓专项
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `event` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `family_id`         BIGINT UNSIGNED NOT NULL COMMENT '所属家族ID（外键→family.id）',
    `event_type`        TINYINT         NOT NULL COMMENT '活动类型：1-扫墓 2-家庭聚会 3-节庆 4-婚礼寿宴 5-旅行 6-自定义',
    `title`             VARCHAR(60)     NOT NULL COMMENT '活动标题（2-30字）',
    `event_date`        DATE            NOT NULL COMMENT '活动时间',
    `event_time`        TIME            DEFAULT NULL COMMENT '活动具体时间',
    `location`          VARCHAR(200)    DEFAULT NULL COMMENT '活动地点文本',
    `latitude`          DECIMAL(10,6)   DEFAULT NULL COMMENT '纬度（地图选址）',
    `longitude`         DECIMAL(11,6)   DEFAULT NULL COMMENT '经度（地图选址）',
    `description`       TEXT            DEFAULT NULL COMMENT '活动描述（≤200字）',
    `atmosphere`        VARCHAR(20)     DEFAULT NULL COMMENT '氛围：solemn-庄重 tender-温情 lively-热闹 sentimental-感慨',
    `images`            JSON            DEFAULT NULL COMMENT '活动照片URL列表（最多9张，JSON数组）',
    `notes`             JSON            DEFAULT NULL COMMENT '各参与者心得：{ member_id: { content, create_time } }',
    `note_mode`         TINYINT         DEFAULT NULL COMMENT '心得撰写方式：1-共同撰写 2-各自填写（null表示未设置）',
    `creator_member_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '创建者对应的成员ID（冗余，用于展示和视图JOIN）',
    `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `created_by`        BIGINT UNSIGNED NOT NULL COMMENT '创建人用户ID（外键→user.id）',
    `update_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `status`            TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：1-进行中 2-已完成 0-已取消',
    PRIMARY KEY (`id`),
    KEY `idx_family_date` (`family_id`, `event_date` DESC),
    KEY `idx_family_type` (`family_id`, `event_type`, `event_date` DESC),
    KEY `idx_creator` (`created_by`),
    KEY `idx_creator_member` (`creator_member_id`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='活动表';

-- ----------------------------------------
-- 【核心表9】活动参与者表（EventParticipant）
-- 说明：活动与参与者的多对多关系（独立表，支持状态跟踪）
-- V1.0 不支持参与者自定义参与状态，此表记录参与关系
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `event_participant` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `event_id`          BIGINT UNSIGNED NOT NULL COMMENT '活动ID（外键→event.id）',
    `member_id`         BIGINT UNSIGNED NOT NULL COMMENT '成员ID（外键→member.id）',
    `user_id`           BIGINT UNSIGNED DEFAULT NULL COMMENT '关联用户ID（外键→user.id，可为空）',
    `is_tomb_object`    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否为祭扫对象（扫墓活动）：0-否 1-是',
    `is_creator`        TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否为活动创建者：0-否 1-是（用于个人时间轴视图判断）',
    `note_content`      TEXT            DEFAULT NULL COMMENT '参与者心得（各自填写模式下）',
    `note_visibility`   TINYINT         NOT NULL DEFAULT 1 COMMENT '心得可见性：1-公开 2-亲属可见 3-仅自己',
    `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `status`            TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：1-正常 0-已退出（成员离开家族时标记）',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_event_member` (`event_id`, `member_id`),
    KEY `idx_member_id` (`member_id`),
    KEY `idx_event_status` (`event_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='活动参与者表';

-- ----------------------------------------
-- 【核心表10】祭品记录表（TombOffering）— 扫墓专用
-- 说明：扫墓活动的祭品记录，与 event.id 一对一关联
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `tomb_offering` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `event_id`          BIGINT UNSIGNED NOT NULL COMMENT '关联活动ID（外键→event.id）',
    `offering_list`     JSON            DEFAULT NULL COMMENT '祭品列表：[{ "name": "香烛", "count": "3炷", "photo": "url" }]',
    `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_event_id` (`event_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='祭品记录表（扫墓专用）';

-- ----------------------------------------------------------
-- 七、提醒系统
-- ----------------------------------------------------------

-- ----------------------------------------
-- 【核心表11】提醒表（Reminder）
-- 说明：忌日提醒和周期记录提醒
-- reminder_type：tomb_anniversary-忌日 periodic-周期 custom-自定义
-- lunar_date：农历日期（如"初一"、"四月十五"），非必填
-- next_trigger：下次触发时间（提前计算好，用于定时任务查询）
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `reminder` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `family_id`         BIGINT UNSIGNED NOT NULL COMMENT '所属家族ID（外键→family.id）',
    `member_id`         BIGINT UNSIGNED DEFAULT NULL COMMENT '关联成员ID（忌日提醒时必填）',
    `reminder_type`     TINYINT         NOT NULL COMMENT '提醒类型：1-忌日 2-周期 3-自定义',
    `lunar_date`        VARCHAR(20)     DEFAULT NULL COMMENT '农历日期（如"初一"）',
    `gregorian_date`    DATE            NOT NULL COMMENT '公历日期',
    `reminder_text`     VARCHAR(200)    NOT NULL COMMENT '提醒文案',
    `advance_days`      TINYINT         NOT NULL DEFAULT 3 COMMENT '提前天数（忌日默认提前3天）',
    `is_enabled`        TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否启用：0-关闭 1-开启',
    `prefer_time`       TIME            DEFAULT '20:00:00' COMMENT '偏好推送时间（默认晚8点）',
    `is_lunar`          TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '日期来源：0-公历 1-农历',
    `last_triggered`     DATETIME        DEFAULT NULL COMMENT '上次触发时间',
    `next_trigger`      DATETIME        NOT NULL COMMENT '下次触发时间（定时任务索引）',
    `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `created_by`        BIGINT UNSIGNED NOT NULL COMMENT '创建人用户ID',
    `status`            TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：1-正常 0-暂停 2-已删除',
    PRIMARY KEY (`id`),
    KEY `idx_family_enabled` (`family_id`, `is_enabled`),
    KEY `idx_next_trigger` (`next_trigger`, `is_enabled`, `status`),
    KEY `idx_member_id` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='提醒表';

-- ----------------------------------------
-- 【核心表12】那年今日表（MemoryThisDay）— V1.5 推送数据预生成
-- 说明：每日凌晨生成当天推送数据（event_date = today - 1 year）
-- 避免实时查询性能问题，定时任务提前一天生成
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `memory_this_day` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `family_id`         BIGINT UNSIGNED NOT NULL COMMENT '所属家族ID',
    `user_id`           BIGINT UNSIGNED NOT NULL COMMENT '目标用户ID',
    `source_type`       TINYINT         NOT NULL COMMENT '来源类型：1-动态 2-活动',
    `source_id`         BIGINT UNSIGNED NOT NULL COMMENT '来源ID（post.id 或 event.id）',
    `target_date`       DATE            NOT NULL COMMENT '目标推送日期（今日）',
    `summary`           VARCHAR(200)    DEFAULT NULL COMMENT '内容摘要（前50字截取）',
    `cover_image`       VARCHAR(512)    DEFAULT NULL COMMENT '封面图（第一张图片）',
    `is_pushed`         TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已推送：0-未推送 1-已推送',
    `pushed_time`       DATETIME        DEFAULT NULL COMMENT '推送时间',
    `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '生成时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_date_source` (`user_id`, `target_date`, `source_type`, `source_id`),
    KEY `idx_target_date` (`target_date`, `is_pushed`),
    KEY `idx_family_id` (`family_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='那年今日表（V1.5）';

-- ----------------------------------------------------------
-- 八、消息通知
-- ----------------------------------------------------------

-- ----------------------------------------
-- 【核心表13】消息通知表（Notification）
-- 说明：应用内消息通知（加入申请、活动邀请、继承提醒等）
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `notification` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`           BIGINT UNSIGNED NOT NULL COMMENT '通知接收用户ID',
    `type`              TINYINT         NOT NULL COMMENT '通知类型：1-加入申请 2-申请通过 3-申请拒绝 4-活动邀请 5-忌日提醒 6-周期提醒 7-继承提醒 8-那年今日',
    `title`             VARCHAR(100)    NOT NULL COMMENT '通知标题',
    `content`           VARCHAR(500)    NOT NULL COMMENT '通知内容',
    `related_type`      VARCHAR(32)     DEFAULT NULL COMMENT '关联对象类型：family/event/member/post',
    `related_id`        BIGINT UNSIGNED DEFAULT NULL COMMENT '关联对象ID',
    `action_url`        VARCHAR(255)    DEFAULT NULL COMMENT '点击跳转路径',
    `is_read`           TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已读：0-未读 1-已读',
    `read_time`         DATETIME        DEFAULT NULL COMMENT '阅读时间',
    `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    KEY `idx_user_unread` (`user_id`, `is_read`),
    KEY `idx_user_time` (`user_id`, `create_time` DESC),
    KEY `idx_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='消息通知表';

-- ----------------------------------------------------------
-- 九、搜索与全文检索
-- ----------------------------------------------------------

-- ----------------------------------------
-- 【辅助表1】搜索历史表
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `search_history` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`           BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    `keyword`           VARCHAR(100)    NOT NULL COMMENT '搜索关键词',
    `search_type`       TINYINT         DEFAULT NULL COMMENT '搜索类型：1-全部 2-动态 3-成员 4-活动',
    `result_count`      INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '搜索结果数',
    `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '搜索时间',
    PRIMARY KEY (`id`),
    KEY `idx_user_time` (`user_id`, `create_time` DESC),
    KEY `idx_keyword` (`keyword`(20))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='搜索历史表';

-- ----------------------------------------
-- 【辅助表2】动态内容全文索引辅助表
-- 说明：MySQL 8.0 原生支持 FULLTEXT，利用中文分词插件（ngram）提升中文搜索效率
-- 独立存储搜索用文本，避免每次查询实时拼接
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `post_search_fts` (
    `post_id`          BIGINT UNSIGNED NOT NULL COMMENT '动态ID（主键兼外键）',
    `family_id`        BIGINT UNSIGNED NOT NULL COMMENT '家族ID（冗余，加速过滤）',
    `author_name`      VARCHAR(64)     DEFAULT NULL COMMENT '作者姓名（冗余搜索）',
    `content_fts`      TEXT            NOT NULL COMMENT '全文检索内容（文字内容 + 标签拼接）',
    `update_time`      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`post_id`),
    KEY `idx_family_id` (`family_id`),
    FULLTEXT KEY `ft_content` (`content_fts`, `author_name`) WITH PARSER ngram
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='动态全文检索辅助表';

-- ----------------------------------------------------------
-- 十（续）、新增功能表
-- ----------------------------------------------------------

-- ----------------------------------------
-- 【补充表1】动态-标签多对多关系表（PostTag）
-- 说明：动态和标签的多对多关系，独立表避免 JSON 查询性能问题
-- 标签类型：work-工作 study-学业 family-家庭 health-健康
--          achievement-成就 travel-旅行 other-其他
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `post_tag` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `post_id`       BIGINT UNSIGNED NOT NULL COMMENT '动态ID（外键→post.id）',
    `tag_type`      VARCHAR(20)     NOT NULL COMMENT '标签类型：work/study/family/health/achievement/travel/other',
    `create_time`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_post_tag` (`post_id`, `tag_type`),
    KEY `idx_post_id` (`post_id`),
    KEY `idx_tag_type` (`tag_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='动态标签关系表';

-- ----------------------------------------
-- 【补充表2】家族转让记录表（FamilyTransfer）
-- 说明：记录家族创建者转让事件（创建者退出场景）
-- 转让完成后，原创建者降级为普通成员或离开家族
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `family_transfer` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `family_id`         BIGINT UNSIGNED NOT NULL COMMENT '家族ID（外键→family.id）',
    `from_user_id`      BIGINT UNSIGNED NOT NULL COMMENT '原创建者用户ID',
    `to_user_id`        BIGINT UNSIGNED NOT NULL COMMENT '新创建者用户ID',
    `transfer_reason`   VARCHAR(200)    DEFAULT NULL COMMENT '转让原因',
    `transfer_time`     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '转让时间',
    `status`            TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：1-成功 0-已撤销',
    PRIMARY KEY (`id`),
    KEY `idx_family_id` (`family_id`),
    KEY `idx_from_user` (`from_user_id`),
    KEY `idx_to_user` (`to_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='家族转让记录表';

-- ----------------------------------------
-- 【补充表3】家族邀请记录表（FamilyInvite）
-- 说明：记录通过邀请链接/二维码加入家族的邀请记录
-- 支持家族码重置过渡期（old_code_expire_time）管理
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `family_invite` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `family_id`     BIGINT UNSIGNED NOT NULL COMMENT '家族ID（外键→family.id）',
    `invite_code`   VARCHAR(10)     NOT NULL COMMENT '邀请码（与 family_code 一致）',
    `invite_type`   TINYINT         NOT NULL DEFAULT 1 COMMENT '邀请方式：1-二维码 2-分享链接 3-家族码',
    `created_by`    BIGINT UNSIGNED NOT NULL COMMENT '创建邀请的用户ID',
    `use_count`     INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '已使用次数',
    `max_use`       INT UNSIGNED    DEFAULT NULL COMMENT '最大使用次数（null表示不限）',
    `expire_time`   DATETIME        DEFAULT NULL COMMENT '过期时间（null表示永不过期）',
    `create_time`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `status`        TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：1-有效 0-已失效',
    PRIMARY KEY (`id`),
    KEY `idx_family_id` (`family_id`),
    KEY `idx_invite_code` (`invite_code`),
    KEY `idx_expire` (`expire_time`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='家族邀请记录表';

-- ----------------------------------------
-- 【补充表4】家族解散记录表（FamilyDissolveLog）
-- 说明：家族解散不可逆操作留存记录
-- 留存家族名称、成员快照、创建者等关键信息
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `family_dissolve_log` (
    `id`                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `family_id`             BIGINT UNSIGNED NOT NULL COMMENT '原家族ID',
    `family_name`           VARCHAR(40)     NOT NULL COMMENT '原家族名称（快照）',
    `family_surname`        VARCHAR(20)     DEFAULT NULL COMMENT '原家族姓氏（快照）',
    `dissolved_by`          BIGINT UNSIGNED NOT NULL COMMENT '解散操作人ID',
    `dissolve_time`         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '解散时间',
    `reason`                VARCHAR(200)    DEFAULT NULL COMMENT '解散原因',
    `member_count_at_dissolve` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '解散时成员数',
    `post_count_at_dissolve`   INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '解散时动态数',
    `event_count_at_dissolve`  INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '解散时活动数',
    PRIMARY KEY (`id`),
    KEY `idx_family_id` (`family_id`),
    KEY `idx_dissolved_by` (`dissolved_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='家族解散记录表';

-- ----------------------------------------
-- 【补充表5】配偶家族双向关联表（FamilyCrossLink）
-- 说明：当配偶在对方家族中有独立族谱时，建立跨家族关联
-- 一对配偶可同时出现在两个家族的族谱中
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `family_cross_link` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `family_a_id`       BIGINT UNSIGNED NOT NULL COMMENT '家族A的ID',
    `member_a_id`       BIGINT UNSIGNED NOT NULL COMMENT '家族A中的成员ID（配偶）',
    `family_b_id`       BIGINT UNSIGNED NOT NULL COMMENT '家族B的ID',
    `member_b_id`       BIGINT UNSIGNED NOT NULL COMMENT '家族B中的成员ID（配偶）',
    `link_type`         TINYINT         NOT NULL DEFAULT 1 COMMENT '关联类型：1-配偶双向',
    `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_link` (`family_a_id`, `member_a_id`, `family_b_id`, `member_b_id`),
    KEY `idx_family_a` (`family_a_id`),
    KEY `idx_family_b` (`family_b_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='配偶家族双向关联表';

-- ----------------------------------------------------------
-- 十（续2）、字段补全：引导问题库轮换控制
-- ----------------------------------------------------------

ALTER TABLE `guide_question`
    ADD COLUMN `rotate_frequency` INT UNSIGNED NOT NULL DEFAULT 30 COMMENT '轮换周期（天，默认30天）' AFTER `is_active`,
    ADD COLUMN `last_use_time`    DATETIME        DEFAULT NULL COMMENT '上次使用时间（定时任务更新）' AFTER `rotate_frequency`,
    ADD COLUMN `use_count`        INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '累计使用次数' AFTER `last_use_time`;

-- 引导问题库初始数据（30条）
INSERT INTO `guide_question` (`question`, `sort_order`) VALUES
    ('最近有什么让你开心的小事？', 1),
    ('孩子学会了什么新技能？', 2),
    ('家人有什么值得记录的变化？', 3),
    ('今天有什么小成就？', 4),
    ('家庭聚会上有什么难忘的瞬间？', 5),
    ('最近有没有带孩子去什么地方玩？', 6),
    ('家里老人身体怎么样？有没有什么好消息？', 7),
    ('今天做了什么好吃的？', 8),
    ('孩子今天说了什么有趣的话？', 9),
    ('有没有收到什么好消息？', 10),
    ('今天陪家人做了什么？', 11),
    ('周末有什么家庭计划？', 12),
    ('孩子最近在学习上有什么进步？', 13),
    ('家里有没有添置什么新东西？', 14),
    ('最近和家人一起看了什么电影/电视？', 15),
    ('有没有拍到什么温馨的家庭照片？', 16),
    ('今天工作/学习顺利吗？', 17),
    ('孩子有什么成长里程碑想记录？', 18),
    ('家里有什么传统/习惯想分享？', 19),
    ('有没有想对家人说的话？', 20),
    ('最近去了哪里旅行/踏青？', 21),
    ('家里有没有什么值得庆祝的事？', 22),
    ('今天吃了什么特别的美食？', 23),
    ('孩子交到了新朋友吗？', 24),
    ('有没有什么想记录的家庭故事？', 25),
    ('今天家里发生了什么温馨的事？', 26),
    ('孩子的身高/体重有变化吗？', 27),
    ('有没有发现孩子的新爱好？', 28),
    ('今天有什么想感谢家人的事？', 29),
    ('家庭氛围最近怎么样？', 30);

-- 系统配置初始数据
INSERT INTO `sys_config` (`config_key`, `config_value`, `description`) VALUES
    ('app_name', '"族脉记"', '应用名称'),
    ('version', '"1.0.0"', '当前版本号'),
    ('family_code_length', '6', '家族码长度'),
    ('max_post_content', '300', '动态文字最大字数'),
    ('max_post_images', '3', '动态最大图片数'),
    ('max_event_images', '9', '活动最大图片数'),
    ('max_audio_duration', '60', '音频最大时长（秒）'),
    ('max_member_photos', '3', '成员最大肖像照数'),
    ('max_bio_length', '500', '生平简介最大字数'),
    ('post_page_size', '20', '动态列表每页数量'),
    ('member_page_size', '20', '成员列表每页数量'),
    ('search_history_limit', '10', '搜索历史保留条数'),
    ('guardian_max_count', '2', '守护人最大数量'),
    ('old_code_expire_hours', '24', '旧家族码有效期（小时）'),
    ('draft_expire_days', '7', '草稿保留天数'),
    ('log_retention_days', '180', '操作日志保留天数'),
    ('push_max_daily', '5', '每日最大推送数'),
    ('reminder_advance_days', '3', '忌日默认提前天数');

-- ----------------------------------------------------------
-- 十一、关键 SQL 查询示例
-- ----------------------------------------------------------

-- 【示例1】动态墙查询（按家族ID + 时间倒序，支持分页）
-- SELECT p.*, m.name as member_name, m.photos as member_photos
-- FROM post p
-- LEFT JOIN member m ON p.member_id = m.id
-- WHERE p.family_id = ? AND p.status = 1
--   AND (p.visibility = 1 OR (p.visibility = 2 AND ?))  -- 亲属可见过滤
--   AND (p.author_id = ? OR p.visibility != 3)           -- 仅自己过滤
-- ================================================
-- 【个人时间轴聚合视图】
-- 说明：个人时间轴需要同时展示「自己发布的内容」和「参与过的活动」
-- 通过 UNION ALL 合并 post 表和 event_participant/event 表
-- content_type = 'post' 表示自己发布的动态
-- content_type = 'event' 表示自己参与的活动（由其他成员创建）
-- ================================================

-- DROP VIEW IF EXISTS v_personal_timeline;
CREATE ALGORITHM = MERGE SQL SECURITY DEFINER
VIEW v_personal_timeline AS
-- ① 自己发布的动态（post 表）
SELECT
    CONCAT('post_', p.id)                          AS timeline_key,
    p.member_id                                    AS member_id,
    p.family_id                                    AS family_id,
    'post'                                         AS content_type,
    p.id                                           AS content_id,
    p.template_type                                AS sub_type,
    p.event_date                                   AS timeline_date,
    p.create_time                                  AS create_time,
    p.author_name                                  AS actor_name,
    p.author_avatar                                AS actor_avatar,
    p.images                                       AS photos,
    p.content                                      AS text_content,
    NULL                                           AS event_id,
    NULL                                           AS event_type,
    NULL                                           AS event_title,
    NULL                                           AS is_creator,
    NULL                                           AS offering_count
FROM   post p
WHERE  p.status = 1

UNION ALL

-- ② 自己参与的活动（event + event_participant 关联）
-- 注意：member 表无 avatar_url，用 photos[0] 或 NULL 代替
SELECT
    CONCAT('event_', ep.event_id)                   AS timeline_key,
    ep.member_id                                    AS member_id,
    e.family_id                                     AS family_id,
    'event'                                        AS content_type,
    e.id                                           AS content_id,
    e.event_type                                   AS sub_type,
    e.event_date                                   AS timeline_date,
    ep.create_time                                  AS create_time,
    m.name                                         AS actor_name,
    -- member 表无 avatar_url，用 JSON_EXTRACT 取 photos 第一张图
    JSON_UNQUOTE(JSON_EXTRACT(m.photos, '$[0]'))   AS actor_avatar,
    e.images                                       AS photos,
    NULL                                           AS text_content,
    e.id                                           AS event_id,
    e.event_type                                   AS event_type,
    e.title                                        AS event_title,
    ep.is_creator                                  AS is_creator,
    (SELECT COUNT(*) FROM event_participant WHERE event_id = e.id AND status = 1) AS offering_count
FROM   event_participant ep
JOIN   event e  ON ep.event_id = e.id
JOIN   member m  ON e.creator_member_id = m.id
WHERE  ep.status = 1 AND e.status = 1;

-- ================================================
-- 【示例1】动态墙查询（按家族ID + 时间倒序）
-- ================================================
-- SELECT p.*, m.name AS author_name, m.avatar_url AS author_avatar
-- FROM   post p
-- JOIN   member m ON p.member_id = m.id
-- WHERE  p.family_id = ? AND p.status = 1
-- ORDER BY p.event_date DESC, p.create_time DESC
-- LIMIT 20 OFFSET 0;

-- ================================================
-- 【示例2】个人时间轴查询（合并自己的内容和参与的活动）
-- ================================================
-- -- 自己发布的所有动态
-- SELECT * FROM post
-- WHERE member_id = ? AND status = 1
-- ORDER BY event_date DESC, create_time DESC;

-- -- 自己参与的所有活动
-- SELECT e.*, ep.join_time AS joined_at
-- FROM   event_participant ep
-- JOIN   event e ON ep.event_id = e.id
-- WHERE  ep.member_id = ? AND ep.status = 1 AND e.status = 1
-- ORDER BY e.event_date DESC;

-- -- 合并时间轴（推荐方式）
-- SELECT * FROM v_personal_timeline
-- WHERE member_id = ?
-- ORDER BY timeline_date DESC, create_time DESC
-- LIMIT 20 OFFSET 0;

-- ================================================
-- 【示例3】查看自己参与过的清明扫墓活动
-- ================================================
-- SELECT e.*, ep.role_in_event, ep.offerings
-- FROM   event_participant ep
-- JOIN   event e ON ep.event_id = e.id
-- WHERE  ep.member_id = ?
--   AND  e.event_type = 'tomb_sweeping'
--   AND  ep.status = 1
--   AND  e.status = 1
-- ORDER BY e.event_date DESC;
-- LIMIT 20 OFFSET 0;

-- 【示例3】那年今日查询（next_trigger = today）
-- SELECT * FROM reminder
-- WHERE is_enabled = 1 AND status = 1
--   AND DATE(next_trigger) = CURDATE();

-- 【示例4】全站搜索（MySQL 8.0 FULLTEXT）
-- SELECT p.id, p.content, p.family_id, p.create_time
-- FROM post_search_fts fts
-- JOIN post p ON fts.post_id = p.id
-- WHERE fts.family_id = ? AND MATCH(fts.content_fts) AGAINST(? IN NATURAL LANGUAGE MODE)
-- ORDER BY p.create_time DESC;

-- 【示例5】成员辈分查询（某成员的所有祖辈）
-- SELECT m.* FROM member m
-- JOIN relation r ON m.id = r.member_a_id
-- WHERE r.member_b_id = ?
--   AND r.family_id = ?
--   AND r.relation_type = 1
--   AND m.generation > (SELECT generation FROM member WHERE id = ?)
--   AND m.status = 1;

-- 【示例6】待推送那年今日数据生成（每日凌晨执行）
-- INSERT INTO memory_this_day (family_id, user_id, source_type, source_id, target_date, summary, cover_image)
-- SELECT p.family_id, p.author_id, 1, p.id, CURDATE(), LEFT(p.content, 50), JSON_UNQUOTE(JSON_EXTRACT(p.images, '$[0]'))
-- FROM post p
-- WHERE p.status = 1 AND DATE(p.event_date) = DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
--   AND NOT EXISTS (
--       SELECT 1 FROM memory_this_day m WHERE m.source_id = p.id AND m.target_date = CURDATE()
--   );

-- ============================================================
-- 文档结束
-- ============================================================

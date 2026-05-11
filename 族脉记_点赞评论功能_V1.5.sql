-- ============================================================
-- 族脉记 点赞评论功能 - V1.5 扩展
-- 日期：2026-05-11
-- ============================================================

-- ----------------------------------------
-- 【V1.5 功能表1】动态点赞表（PostLike）
-- 说明：记录用户对动态的点赞，支持取消点赞
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `post_like` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `family_id`         BIGINT UNSIGNED NOT NULL COMMENT '家族ID（外键→family.id）',
    `post_id`           BIGINT UNSIGNED NOT NULL COMMENT '动态ID（外键→post.id）',
    `user_id`           BIGINT UNSIGNED NOT NULL COMMENT '点赞用户ID（外键→user.id）',
    `member_id`         BIGINT UNSIGNED DEFAULT NULL COMMENT '点赞成员ID（外键→member.id，可为空）',
    `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '点赞时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_post_user` (`post_id`, `user_id`),
    KEY `idx_family_id` (`family_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_post_id` (`post_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='动态点赞表';

-- ----------------------------------------
-- 【V1.5 功能表2】动态评论表（PostComment）
-- 说明：记录用户对动态的评论
-- 支持嵌套回复（reply_to_id）
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS `post_comment` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `family_id`         BIGINT UNSIGNED NOT NULL COMMENT '家族ID（外键→family.id）',
    `post_id`           BIGINT UNSIGNED NOT NULL COMMENT '动态ID（外键→post.id）',
    `user_id`           BIGINT UNSIGNED NOT NULL COMMENT '评论用户ID（外键→user.id）',
    `member_id`         BIGINT UNSIGNED DEFAULT NULL COMMENT '评论成员ID（外键→member.id，可为空）',
    `author_name`       VARCHAR(64)     NOT NULL COMMENT '评论者姓名（冗余）',
    `author_avatar`     VARCHAR(512)   DEFAULT NULL COMMENT '评论者头像URL（冗余）',
    `content`           TEXT            NOT NULL COMMENT '评论内容（≤200字）',
    `reply_to_id`       BIGINT UNSIGNED DEFAULT NULL COMMENT '回复的评论ID（null表示一级评论）',
    `reply_to_user_id`  BIGINT UNSIGNED DEFAULT NULL COMMENT '回复对象用户ID',
    `reply_to_user_name` VARCHAR(64)   DEFAULT NULL COMMENT '回复对象名称（冗余）',
    `visibility`        TINYINT         NOT NULL DEFAULT 1 COMMENT '可见性：1-公开 2-亲属可见 3-仅自己',
    `create_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '评论时间',
    `update_time`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `status`            TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：1-正常 0-已删除',
    `deleted_at`        DATETIME         DEFAULT NULL COMMENT '删除时间',
    PRIMARY KEY (`id`),
    KEY `idx_family_id` (`family_id`),
    KEY `idx_post_id` (`post_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_reply_to` (`reply_to_id`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='动态评论表';

-- ============================================================
-- 更新 post 表的注释，说明 V1.5 已启用
-- ============================================================

-- 可选：如果需要迁移现有的点赞/评论计数（如果有历史数据的话）
-- 首次启用时点赞数和评论数都为 0，无需特殊迁移

-- ============================================================
-- 文档结束
-- ============================================================

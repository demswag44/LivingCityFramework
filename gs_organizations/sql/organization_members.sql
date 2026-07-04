-- -------------------------------------------------------------------
-- GS Organizations
-- Organization Members Persistence Schema
-- -------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `gs_organization_members` (

    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

    `organization_id` INT UNSIGNED NOT NULL,

    `member_id` VARCHAR(64) NOT NULL,

    `rank` VARCHAR(64) NOT NULL DEFAULT 'Member',

    `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),

    UNIQUE KEY `uk_gs_org_members_org_member`
        (`organization_id`, `member_id`),

    INDEX `idx_gs_org_members_organization_id`
        (`organization_id`),

    INDEX `idx_gs_org_members_member_id`
        (`member_id`),

    INDEX `idx_gs_org_members_rank`
        (`rank`),

    INDEX `idx_gs_org_members_joined_at`
        (`joined_at`),

    INDEX `idx_gs_org_members_updated_at`
        (`updated_at`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

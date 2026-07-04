-- -------------------------------------------------------------------
-- GS Organizations
-- Organization History Persistence Schema
-- -------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `gs_organization_history` (

    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

    `organization_id` INT UNSIGNED NOT NULL,

    `action` VARCHAR(100) NOT NULL,

    `actor_id` VARCHAR(64) DEFAULT NULL,

    `target_id` VARCHAR(64) DEFAULT NULL,

    `data_json` JSON DEFAULT NULL,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),

    INDEX `idx_gs_org_history_organization_id`
        (`organization_id`),

    INDEX `idx_gs_org_history_action`
        (`action`),

    INDEX `idx_gs_org_history_actor_id`
        (`actor_id`),

    INDEX `idx_gs_org_history_target_id`
        (`target_id`),

    INDEX `idx_gs_org_history_created_at`
        (`created_at`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

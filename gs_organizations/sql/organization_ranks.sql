-- -------------------------------------------------------------------
-- GS Organizations
-- Organization Ranks Persistence Schema
-- -------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `gs_organization_ranks` (

    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

    `organization_id` INT UNSIGNED NOT NULL,

    `name` VARCHAR(64) NOT NULL,

    `label` VARCHAR(100) NOT NULL,

    `weight` INT NOT NULL DEFAULT 0,

    `permissions_json` JSON DEFAULT NULL,

    `salary` BIGINT NOT NULL DEFAULT 0,

    `color` VARCHAR(7) DEFAULT NULL,

    `icon` VARCHAR(100) DEFAULT NULL,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),

    UNIQUE KEY `uk_gs_org_ranks_org_name`
        (`organization_id`, `name`),

    INDEX `idx_gs_org_ranks_organization_id`
        (`organization_id`),

    INDEX `idx_gs_org_ranks_name`
        (`name`),

    INDEX `idx_gs_org_ranks_weight`
        (`weight`),

    INDEX `idx_gs_org_ranks_created_at`
        (`created_at`),

    INDEX `idx_gs_org_ranks_updated_at`
        (`updated_at`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------------
-- GS Organizations
-- Organization Activity Feed Persistence Schema
-- -------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `organization_activity` (

    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

    `organization_id` INT UNSIGNED NOT NULL,

    `actor_identifier` VARCHAR(64) DEFAULT NULL,

    `actor_name` VARCHAR(100) DEFAULT NULL,

    `type` VARCHAR(32) NOT NULL,

    `title` VARCHAR(150) NOT NULL,

    `description` TEXT DEFAULT NULL,

    `metadata` JSON DEFAULT NULL,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),

    INDEX `idx_org_activity_organization_id`
        (`organization_id`),

    INDEX `idx_org_activity_actor_identifier`
        (`actor_identifier`),

    INDEX `idx_org_activity_type`
        (`type`),

    INDEX `idx_org_activity_created_at`
        (`created_at`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

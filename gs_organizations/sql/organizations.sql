-- -------------------------------------------------------------------
-- GS Organizations
-- Database Schema
-- -------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `gs_organizations` (

    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

    `name` VARCHAR(100) NOT NULL,

    `tag` VARCHAR(10) DEFAULT NULL,

    `type` VARCHAR(50) NOT NULL,

    `description` TEXT DEFAULT NULL,

    `primary_color` VARCHAR(7) NOT NULL DEFAULT '#D4AF37',

    `secondary_color` VARCHAR(7) NOT NULL DEFAULT '#111111',

    `icon` VARCHAR(100) DEFAULT NULL,

    `founder` VARCHAR(64) DEFAULT NULL,

    `leader` VARCHAR(64) DEFAULT NULL,

    `treasury` BIGINT NOT NULL DEFAULT 0,

    `income` BIGINT NOT NULL DEFAULT 0,

    `expenses` BIGINT NOT NULL DEFAULT 0,

    `reputation` INT NOT NULL DEFAULT 0,

    `influence` INT NOT NULL DEFAULT 0,

    `heat` INT NOT NULL DEFAULT 0,

    `ai_controlled` TINYINT(1) NOT NULL DEFAULT 0,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),

    UNIQUE KEY `uk_gs_organizations_name` (`name`),

    INDEX `idx_gs_organizations_type` (`type`),

    INDEX `idx_gs_organizations_leader` (`leader`),

    INDEX `idx_gs_organizations_created_at` (`created_at`),

    INDEX `idx_gs_organizations_updated_at` (`updated_at`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `gs_organizations`
    ADD COLUMN IF NOT EXISTS `primary_color` VARCHAR(7)
        NOT NULL DEFAULT '#D4AF37'
        AFTER `description`,
    ADD COLUMN IF NOT EXISTS `secondary_color` VARCHAR(7)
        NOT NULL DEFAULT '#111111'
        AFTER `primary_color`,
    ADD COLUMN IF NOT EXISTS `icon` VARCHAR(100)
        DEFAULT NULL
        AFTER `secondary_color`;

CREATE INDEX IF NOT EXISTS `idx_gs_organizations_type`
    ON `gs_organizations` (`type`);

CREATE INDEX IF NOT EXISTS `idx_gs_organizations_leader`
    ON `gs_organizations` (`leader`);

CREATE INDEX IF NOT EXISTS `idx_gs_organizations_created_at`
    ON `gs_organizations` (`created_at`);

CREATE INDEX IF NOT EXISTS `idx_gs_organizations_updated_at`
    ON `gs_organizations` (`updated_at`);

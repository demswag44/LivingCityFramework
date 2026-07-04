---------------------------------------------------------------------
-- GS Organizations
-- Database Schema
---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `gs_organizations` (

    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

    `name` VARCHAR(100) NOT NULL,

    `tag` VARCHAR(10) DEFAULT NULL,

    `type` VARCHAR(50) NOT NULL,

    `description` TEXT DEFAULT NULL,

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

    INDEX `idx_gs_organizations_leader` (`leader`)

);
-- -------------------------------------------------------------------
-- GS Organizations
-- Organization Territories Persistence Schema
-- -------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `organization_territories` (

    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

    `name` VARCHAR(100) NOT NULL,

    `description` TEXT DEFAULT NULL,

    `owner_organization_id` INT UNSIGNED DEFAULT NULL,

    `color` VARCHAR(7) DEFAULT NULL,

    `polygon` JSON DEFAULT NULL,

    `center_x` DOUBLE DEFAULT NULL,

    `center_y` DOUBLE DEFAULT NULL,

    `center_z` DOUBLE DEFAULT NULL,

    `influence` INT NOT NULL DEFAULT 0,

    `heat` INT NOT NULL DEFAULT 0,

    `income` BIGINT NOT NULL DEFAULT 0,

    `population` INT NOT NULL DEFAULT 0,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),

    UNIQUE KEY `uk_org_territories_name`
        (`name`),

    INDEX `idx_org_territories_owner_organization_id`
        (`owner_organization_id`),

    INDEX `idx_org_territories_name`
        (`name`),

    INDEX `idx_org_territories_influence`
        (`influence`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

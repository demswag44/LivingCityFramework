CREATE TABLE IF NOT EXISTS `gs_organizations` (

    `id` INT NOT NULL AUTO_INCREMENT,

    `name` VARCHAR(64) NOT NULL,

    `tag` VARCHAR(16),

    `type` VARCHAR(32) NOT NULL,

    `description` TEXT,

    `founder` VARCHAR(64),

    `leader` VARCHAR(64),

    `treasury` BIGINT NOT NULL DEFAULT 0,

    `income` BIGINT NOT NULL DEFAULT 0,

    `expenses` BIGINT NOT NULL DEFAULT 0,

    `reputation` INT NOT NULL DEFAULT 0,

    `influence` INT NOT NULL DEFAULT 0,

    `heat` INT NOT NULL DEFAULT 0,

    `ai_controlled` TINYINT(1) NOT NULL DEFAULT 0,

    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),

    UNIQUE KEY `uk_name` (`name`)

);
-- -------------------------------------------------------------------
-- GS Organizations
-- Organization Treasury Transaction Persistence Schema
-- -------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `gs_organization_transactions` (

    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

    `organization_id` INT UNSIGNED NOT NULL,

    `type` VARCHAR(32) NOT NULL,

    `actor_id` VARCHAR(64) NOT NULL,

    `target_id` VARCHAR(64) DEFAULT NULL,

    `amount` BIGINT NOT NULL,

    `balance_before` BIGINT NOT NULL,

    `balance_after` BIGINT NOT NULL,

    `note` VARCHAR(255) DEFAULT NULL,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),

    INDEX `idx_gs_org_transactions_organization_id`
        (`organization_id`),

    INDEX `idx_gs_org_transactions_type`
        (`type`),

    INDEX `idx_gs_org_transactions_actor_id`
        (`actor_id`),

    INDEX `idx_gs_org_transactions_target_id`
        (`target_id`),

    INDEX `idx_gs_org_transactions_created_at`
        (`created_at`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

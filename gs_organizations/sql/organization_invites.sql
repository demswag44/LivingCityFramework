-- -------------------------------------------------------------------
-- GS Organizations
-- Organization Invites Persistence Schema
-- -------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `gs_organization_invites` (

    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

    `organization_id` INT UNSIGNED NOT NULL,

    `sender_id` VARCHAR(64) DEFAULT NULL,

    `receiver_id` VARCHAR(64) NOT NULL,

    `status` ENUM('pending', 'accepted', 'declined', 'revoked', 'expired')
        NOT NULL DEFAULT 'pending',

    `expires_at` TIMESTAMP NULL DEFAULT NULL,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),

    INDEX `idx_gs_org_invites_organization_id`
        (`organization_id`),

    INDEX `idx_gs_org_invites_sender_id`
        (`sender_id`),

    INDEX `idx_gs_org_invites_receiver_id`
        (`receiver_id`),

    INDEX `idx_gs_org_invites_status`
        (`status`),

    INDEX `idx_gs_org_invites_expires_at`
        (`expires_at`),

    INDEX `idx_gs_org_invites_created_at`
        (`created_at`),

    INDEX `idx_gs_org_invites_updated_at`
        (`updated_at`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

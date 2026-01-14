-- =====================================
-- DPS City Worker Database Schema
-- Supports: QBCore (citizenid), ESX (identifier)
-- =====================================

-- Player progression and stats
CREATE TABLE IF NOT EXISTS `city_worker_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(60) NOT NULL,
  `rank` int(11) DEFAULT 1,
  `xp` int(11) DEFAULT 0,
  `total_repairs` int(11) DEFAULT 0,
  `total_earnings` int(11) DEFAULT 0,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Infrastructure damage persistence
CREATE TABLE IF NOT EXISTS `city_infrastructure` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sector_id` varchar(50) NOT NULL,
  `health` float DEFAULT 100.0,
  `last_decay` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `sector_id` (`sector_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Damage reports (persistent damage locations)
CREATE TABLE IF NOT EXISTS `city_damage_reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sector_id` varchar(50) NOT NULL,
  `damage_type` varchar(50) NOT NULL,
  `coords_x` float NOT NULL,
  `coords_y` float NOT NULL,
  `coords_z` float NOT NULL,
  `severity` int(11) DEFAULT 1,
  `reported_by` varchar(60) DEFAULT NULL,
  `repaired` tinyint(1) DEFAULT 0,
  `repaired_by` varchar(60) DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `repaired_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `sector_id` (`sector_id`),
  KEY `repaired` (`repaired`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Contractor companies (roadmap feature)
CREATE TABLE IF NOT EXISTS `city_contractors` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `owner_identifier` varchar(60) NOT NULL,
  `balance` int(11) DEFAULT 0,
  `reputation` int(11) DEFAULT 0,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Contract bidding (roadmap feature)
CREATE TABLE IF NOT EXISTS `city_contracts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sector_id` varchar(50) NOT NULL,
  `description` text,
  `budget` int(11) NOT NULL,
  `deadline` timestamp NULL DEFAULT NULL,
  `contractor_id` int(11) DEFAULT NULL,
  `status` enum('open','assigned','completed','expired') DEFAULT 'open',
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `status` (`status`),
  KEY `contractor_id` (`contractor_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Initialize default sector health
INSERT IGNORE INTO `city_infrastructure` (`sector_id`, `health`) VALUES
  ('legion', 100.0),
  ('mirror_park', 100.0),
  ('sandy_shores', 100.0);

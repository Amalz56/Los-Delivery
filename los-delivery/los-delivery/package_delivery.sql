-- Package Delivery System Database Table
-- Run this SQL in your database to create the necessary table

CREATE TABLE IF NOT EXISTS `package_delivery_reputation` (
  `identifier` varchar(60) NOT NULL,
  `reputation` int(11) NOT NULL DEFAULT 0,
  `total_deliveries` int(11) NOT NULL DEFAULT 0,
  `successful_deliveries` int(11) NOT NULL DEFAULT 0,
  `total_earned` int(11) NOT NULL DEFAULT 0,
  `last_delivery` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`),
  KEY `reputation` (`reputation`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

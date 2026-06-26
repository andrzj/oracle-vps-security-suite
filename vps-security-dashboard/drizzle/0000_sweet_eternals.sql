CREATE TABLE `audit_logs` (
	`id` int AUTO_INCREMENT NOT NULL,
	`user_id` int NOT NULL,
	`action` varchar(128) NOT NULL,
	`resource` varchar(64),
	`resource_id` varchar(256),
	`status` enum('success','failure') NOT NULL,
	`details` text,
	`ip_address` varchar(64),
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `audit_logs_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `fail2ban_history` (
	`id` int AUTO_INCREMENT NOT NULL,
	`ip_address` varchar(64) NOT NULL,
	`jail` varchar(64) NOT NULL,
	`bannedAt` timestamp NOT NULL DEFAULT (now()),
	`unbannedAt` timestamp,
	`reason` text,
	`ban_count` int DEFAULT 1,
	CONSTRAINT `fail2ban_history_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `firewall_rules` (
	`id` int AUTO_INCREMENT NOT NULL,
	`action` enum('allow','deny') NOT NULL,
	`protocol` enum('tcp','udp','any'),
	`port` varchar(32),
	`source` varchar(128) DEFAULT 'any',
	`direction` enum('in','out') NOT NULL,
	`description` varchar(256),
	`enabled` boolean DEFAULT true,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`created_by` int,
	CONSTRAINT `firewall_rules_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `security_alerts` (
	`id` int AUTO_INCREMENT NOT NULL,
	`alert_type` varchar(64) NOT NULL,
	`severity` enum('critical','high','medium','low') NOT NULL,
	`title` varchar(256) NOT NULL,
	`description` text,
	`source_ip` varchar(64),
	`count` int DEFAULT 1,
	`acknowledged` boolean DEFAULT false,
	`acknowledged_by` int,
	`acknowledgedAt` timestamp,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `security_alerts_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `system_health` (
	`id` int AUTO_INCREMENT NOT NULL,
	`cpu_usage` float,
	`memory_usage` float,
	`disk_usage` float,
	`load_average` varchar(64),
	`uptime` int,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `system_health_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `users` (
	`id` int AUTO_INCREMENT NOT NULL,
	`openId` varchar(64) NOT NULL,
	`name` text,
	`email` varchar(320),
	`loginMethod` varchar(64),
	`role` enum('user','admin') NOT NULL DEFAULT 'user',
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	`lastSignedIn` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `users_id` PRIMARY KEY(`id`),
	CONSTRAINT `users_openId_unique` UNIQUE(`openId`)
);

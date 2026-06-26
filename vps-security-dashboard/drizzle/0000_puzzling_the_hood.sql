CREATE TABLE `audit_logs` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`user_id` integer NOT NULL,
	`action` text NOT NULL,
	`resource` text,
	`resource_id` text,
	`status` text NOT NULL,
	`details` text,
	`ip_address` text,
	`createdAt` text DEFAULT (datetime('now')) NOT NULL
);
--> statement-breakpoint
CREATE TABLE `fail2ban_history` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`ip_address` text NOT NULL,
	`jail` text NOT NULL,
	`bannedAt` text DEFAULT (datetime('now')) NOT NULL,
	`unbannedAt` text,
	`reason` text,
	`ban_count` integer DEFAULT 1
);
--> statement-breakpoint
CREATE TABLE `firewall_rules` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`action` text NOT NULL,
	`protocol` text,
	`port` text,
	`source` text DEFAULT 'any',
	`direction` text NOT NULL,
	`description` text,
	`enabled` integer DEFAULT true,
	`createdAt` text DEFAULT (datetime('now')) NOT NULL,
	`created_by` integer
);
--> statement-breakpoint
CREATE TABLE `security_alerts` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`alert_type` text NOT NULL,
	`severity` text NOT NULL,
	`title` text NOT NULL,
	`description` text,
	`source_ip` text,
	`count` integer DEFAULT 1,
	`acknowledged` integer DEFAULT false,
	`acknowledged_by` integer,
	`acknowledgedAt` text,
	`createdAt` text DEFAULT (datetime('now')) NOT NULL,
	`updatedAt` text DEFAULT (datetime('now')) NOT NULL
);
--> statement-breakpoint
CREATE TABLE `system_health` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`cpu_usage` real,
	`memory_usage` real,
	`disk_usage` real,
	`load_average` text,
	`uptime` integer,
	`createdAt` text DEFAULT (datetime('now')) NOT NULL
);
--> statement-breakpoint
CREATE TABLE `users` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`openId` text NOT NULL,
	`name` text,
	`email` text,
	`loginMethod` text,
	`role` text DEFAULT 'user' NOT NULL,
	`createdAt` text DEFAULT (datetime('now')) NOT NULL,
	`updatedAt` text DEFAULT (datetime('now')) NOT NULL,
	`lastSignedIn` text DEFAULT (datetime('now')) NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `users_openId_unique` ON `users` (`openId`);
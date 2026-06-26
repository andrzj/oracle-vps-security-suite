CREATE TABLE `audit_logs` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`action` text NOT NULL,
	`resource` text,
	`resource_id` text,
	`status` text NOT NULL,
	`details` text,
	`ip_address` text,
	`user_agent` text,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `fail2ban_history` (
	`id` text PRIMARY KEY NOT NULL,
	`ip_address` text NOT NULL,
	`jail` text NOT NULL,
	`banned_at` integer NOT NULL,
	`unbanned_at` integer,
	`reason` text,
	`ban_count` integer DEFAULT 1
);
--> statement-breakpoint
CREATE TABLE `firewall_rules` (
	`id` text PRIMARY KEY NOT NULL,
	`action` text NOT NULL,
	`protocol` text,
	`port` text,
	`source` text,
	`direction` text NOT NULL,
	`description` text,
	`enabled` integer DEFAULT true,
	`created_at` integer NOT NULL,
	`created_by` text,
	FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE TABLE `security_alerts` (
	`id` text PRIMARY KEY NOT NULL,
	`alert_type` text NOT NULL,
	`severity` text NOT NULL,
	`title` text NOT NULL,
	`description` text,
	`source_ip` text,
	`count` integer DEFAULT 1,
	`acknowledged` integer DEFAULT false,
	`acknowledged_by` text,
	`acknowledged_at` integer,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`acknowledged_by`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE TABLE `sessions` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`expires_at` integer NOT NULL,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `settings` (
	`key` text PRIMARY KEY NOT NULL,
	`value` text NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `system_health` (
	`id` text PRIMARY KEY NOT NULL,
	`cpu_usage` real,
	`memory_usage` real,
	`disk_usage` real,
	`load_average` text,
	`uptime` integer,
	`created_at` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `users` (
	`id` text PRIMARY KEY NOT NULL,
	`email` text NOT NULL,
	`name` text,
	`password_hash` text NOT NULL,
	`totp_secret` text,
	`totp_enabled` integer DEFAULT false,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `users_email_unique` ON `users` (`email`);
ALTER TABLE `hopsworks`.`jobs` CHANGE COLUMN `json_config` `json_config` VARCHAR(12500) COLLATE latin1_general_cs NOT NULL;
ALTER TABLE `hopsworks`.`jupyter_settings` CHANGE COLUMN `json_config` `json_config` VARCHAR(11500) COLLATE latin1_general_cs NOT NULL;
ALTER TABLE `hopsworks`.`message` CHANGE COLUMN `content` `content` VARCHAR(11000) COLLATE latin1_general_cs NOT NULL;

ALTER TABLE hopsworks.`jupyter_settings` ADD COLUMN `python_kernel` tinyint(1) DEFAULT 1;
ALTER TABLE hopsworks.`jupyter_settings` ADD COLUMN `docker_config` VARCHAR(1000) COLLATE latin1_general_cs NOT NULL;
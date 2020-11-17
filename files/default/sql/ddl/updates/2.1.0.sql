ALTER TABLE `hopsworks`.`project` ADD COLUMN `python_conflicts` TINYINT(1) NOT NULL DEFAULT '0';

ALTER TABLE `hopsworks`.`jupyter_project` ADD COLUMN `python_conflicts` TINYINT(1) NOT NULL DEFAULT '0';

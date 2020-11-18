ALTER TABLE `hopsworks`.`project` ADD COLUMN `python_env_id` int(11) DEFAULT NULL;

CREATE TABLE IF NOT EXISTS`python_environment` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `project_id` int(11) NOT NULL,
  `python_version` varchar(25) COLLATE latin1_general_cs NOT NULL,
  `python_conflicts` TINYINT(1) NOT NULL DEFAULT '0',
  `jupyter_conflicts` TINYINT(1) NOT NULL DEFAULT '0',
  `conflicts` VARCHAR(10000) COLLATE latin1_general_cs DEFAULT NULL,
  UNIQUE KEY `project_env` (`project_id`,`python_version`),
  PRIMARY KEY (`id`),
  CONSTRAINT `FK_362_312` FOREIGN KEY (`project_id`) REFERENCES `project` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=ndbcluster AUTO_INCREMENT=119 DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

ALTER TABLE `hopsworks`.`project` ADD CONSTRAINT `FK_362_309` FOREIGN KEY (`python_env_id`) REFERENCES `python_environment` (`id`) ON DELETE SET NULL ON UPDATE NO ACTION;

ALTER TABLE `hopsworks`.`project` DROP COLUMN `conda`;

ALTER TABLE `hopsworks`.`project` DROP COLUMN `python_version`;
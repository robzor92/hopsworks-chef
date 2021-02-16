DROP VIEW `hops_users`;

DROP TABLE `address`;
DROP TABLE `organization`;
DROP TABLE `authorized_sshkeys`;
DROP TABLE `ssh_keys`;

ALTER TABLE `users` DROP COLUMN `security_question`, DROP COLUMN `security_answer`, DROP COLUMN `mobile`;

ALTER TABLE `hopsworks`.`feature_store_tag` DROP COLUMN `type`;
ALTER TABLE `hopsworks`.`feature_store_tag` ADD COLUMN `tag_schema` VARCHAR(13000) NOT NULL DEFAULT '{"type":"string"}';
CREATE TABLE IF NOT EXISTS `validation_rule` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(45) COLLATE latin1_general_cs DEFAULT NULL,
  `predicate` varchar(45) COLLATE latin1_general_cs DEFAULT NULL,
  `value_type` varchar(45) COLLATE latin1_general_cs DEFAULT NULL,
  `description` varchar(100) COLLATE latin1_general_cs DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_validation_rule` (`name`,`predicate`,`value_type`)
) ENGINE=ndbcluster AUTO_INCREMENT=3 DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

CREATE TABLE IF NOT EXISTS `feature_store_expectation` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `name` varchar(100) COLLATE latin1_general_cs DEFAULT NULL,
    `description` varchar(1000) COLLATE latin1_general_cs DEFAULT NULL,
    `feature_store_id` int(11) NOT NULL,
    `assertions` varchar(12000) COLLATE latin1_general_cs DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `unique_fs_rules` (`feature_store_id`,`name`),
    CONSTRAINT `fk_fs_expectation_to_fs` FOREIGN KEY (`feature_store_id`) REFERENCES `feature_store` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=ndbcluster DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

CREATE TABLE IF NOT EXISTS `feature_group_expectation` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `feature_group_id` int(11) NOT NULL,
    `feature_store_expectation_id` int(11) NOT NULL,
    `description` varchar(1000) COLLATE latin1_general_cs DEFAULT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_fg_expectation_to_fg` FOREIGN KEY (`feature_group_id`) REFERENCES `feature_group` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT `fk_fg_expectation_to_fs_expectation` FOREIGN KEY (`feature_store_expectation_id`) REFERENCES `feature_store_expectation` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=ndbcluster DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

CREATE TABLE IF NOT EXISTS `feature_store_expectation_rule` (
    `feature_store_expectation_id` int(11) NOT NULL,
    `validation_rule_id` int(11) NOT NULL,
    PRIMARY KEY (`feature_store_expectation_id`, `validation_rule_id`),
    CONSTRAINT `fk_fs_expectation_rule_id` FOREIGN KEY (`feature_store_expectation_id`) REFERENCES `feature_store_expectation` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT `fk_validation_rule_id` FOREIGN KEY (`validation_rule_id`) REFERENCES `validation_rule` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=ndbcluster DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

CREATE TABLE  IF NOT EXISTS `feature_group_validation` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `validation_time` TIMESTAMP(3),
    `inode_pid` BIGINT(20) NOT NULL,
    `inode_name` VARCHAR(255) COLLATE latin1_general_cs NOT NULL,
    `partition_id` BIGINT(20) NOT NULL,
    `feature_group_id` INT(11),
    `status` VARCHAR(20) COLLATE latin1_general_cs NOT NULL,
    PRIMARY KEY (`id`),
    KEY `feature_group_id` (`feature_group_id`),
    CONSTRAINT `fg_fk_fgv` FOREIGN KEY (`feature_group_id`) REFERENCES `feature_group` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT `featuregroupvalidation_inode_fk` FOREIGN KEY (`inode_pid`,`inode_name`,`partition_id`) REFERENCES `hops`.`hdfs_inodes` (`parent_id`,`name`,`partition_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=ndbcluster DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

ALTER TABLE `hopsworks`.`feature_group` ADD COLUMN `validation_type` INT(11) DEFAULT '4' AFTER `corr_method`;
ALTER TABLE `hopsworks`.`feature_group_commit` ADD COLUMN `validation_id` int(11), ADD CONSTRAINT `fgc_fk_fgv` FOREIGN KEY (`validation_id`) REFERENCES `feature_group_validation` (`id`) ON DELETE SET NULL  ON UPDATE NO ACTION;
ALTER TABLE `hopsworks`.`oauth_client` 
ADD COLUMN `end_session_endpoint` VARCHAR(1024) DEFAULT NULL,
ADD COLUMN `logout_redirect_param` VARCHAR(45) DEFAULT NULL;

ALTER TABLE `hopsworks`.`python_dep` CHANGE COLUMN `version` `version` varchar(128) COLLATE latin1_general_cs DEFAULT NULL;
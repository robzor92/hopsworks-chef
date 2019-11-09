ALTER TABLE `hopsworks`.`tensorboard` CHANGE `elastic_id` `ml_id` varchar(100) COLLATE latin1_general_cs NOT NULL;

ALTER TABLE conda_commands ADD COLUMN  `user_id` int(11) NOT NULL;

ALTER TABLE `hopsworks`.`conda_commands` ADD FOREIGN KEY `user_fk` (`user_id`) REFERENCES `users` (`uid`) ON DELETE CASCADE ON UPDATE NO ACTION;

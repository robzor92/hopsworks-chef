ALTER TABLE jupyter_project CHANGE `last_accessed` `expires` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP;

DROP TABLE IF EXISTS `jupyter_interpreter`;

ALTER TABLE `jupyter_settings` DROP COLUMN `num_tf_ps`;
ALTER TABLE `jupyter_settings` DROP COLUMN `num_tf_gpus`;
ALTER TABLE `jupyter_settings` DROP COLUMN `num_mpi_np`;
ALTER TABLE `jupyter_settings` DROP COLUMN `appmaster_cores`;
ALTER TABLE `jupyter_settings` DROP COLUMN `appmaster_memory`;
ALTER TABLE `jupyter_settings` DROP COLUMN `num_executors`;
ALTER TABLE `jupyter_settings` DROP COLUMN `num_executor_cores`;
ALTER TABLE `jupyter_settings` DROP COLUMN `executor_memory`;
ALTER TABLE `jupyter_settings` DROP COLUMN `dynamic_initial_executors`;
ALTER TABLE `jupyter_settings` DROP COLUMN `dynamic_min_executors`;
ALTER TABLE `jupyter_settings` DROP COLUMN `dynamic_max_executors`;
ALTER TABLE `jupyter_settings` DROP COLUMN `mode`;
ALTER TABLE `jupyter_settings` DROP COLUMN `archives`;
ALTER TABLE `jupyter_settings` DROP COLUMN `jars`;
ALTER TABLE `jupyter_settings` DROP COLUMN `files`;
ALTER TABLE `jupyter_settings` DROP COLUMN `py_files`;
ALTER TABLE `jupyter_settings` DROP COLUMN `spark_params`;
ALTER TABLE `jupyter_settings` DROP COLUMN `fault_tolerant`;

ALTER TABLE `jupyter_settings` ADD COLUMN `base_dir` VARCHAR(255) DEFAULT '/Jupyter/';
ALTER TABLE `jupyter_settings` ADD COLUMN `json_config` TEXT NOT NULL;
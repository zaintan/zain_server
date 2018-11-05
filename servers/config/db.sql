--
-- Current Database: `DB_ZYGame`
--

--启动数据库
net start mysql

--连接数据库
mysql -u root -p "edrtwjo*@#3983"

--创建数据库
CREATE DATABASE `DB_ZYGame`;
--选择数据库
USE `DB_ZYGame`;

--
-- Table structure for table `TGame`
--
--创建表
DROP TABLE IF EXISTS `TUser`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TUser` (
  `FUserID` INT UNSIGNED AUTO_INCREMENT,
  `FPlatformID` VARCHAR(40) DEFAULT '',
  `FUserName` VARCHAR(20) DEFAULT '',
  `FHeadUrl` VARCHAR(200) DEFAULT '',
  `FSex` TINYINT DEFAULT 1,
  `FDiamond` INT UNSIGNED NOT NULL DEFAULT 0,
  `FGold` INT UNSIGNED NOT NULL DEFAULT 0,
  `FPlatformType` TINYINT DEFAULT 0,
  `FGameIndex` TINYINT NOT NULL DEFAULT 0,
  `FRegDate` DATE DEFAULT NULL,
  `FLastLoginTime` DATETIME DEFAULT NULL,
  PRIMARY KEY (`FUserID`)
) ENGINE=InnoDB AUTO_INCREMENT=1000 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

-- Dump completed on 2018-11-02  15:26:00

-- phpMyAdmin SQL Dump
-- version 3.1.3.1
-- http://www.phpmyadmin.net
--
-- Host: localhost:3306

-- Generation Time: Apr 26, 2009 at 07:01 PM
-- Server version: 5.1.33
-- PHP Version: 5.2.9-1

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";

--
-- Database: `collector`
--

-- --------------------------------------------------------

--
-- Table structure for table `dirs`
--

CREATE TABLE `dirs` (
  `did` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Directory ID',
  `name` varchar(256) CHARACTER SET utf8 NOT NULL COMMENT 'Folder name',
  `parentdid` int(11) unsigned DEFAULT NULL COMMENT 'Parent dir',
  `dstat` tinyint(4) unsigned NOT NULL DEFAULT '0' COMMENT 'Dir properties',
  PRIMARY KEY (`did`),
  KEY `parentdid` (`parentdid`),
  KEY `dstat` (`dstat`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `files`
--

CREATE TABLE `files` (
  `fid` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'File ID',
  `name` varchar(256) CHARACTER SET utf8 NOT NULL COMMENT 'Filename',
  `did` int(11) NOT NULL COMMENT 'Folder ID',
  `size` bigint(20) unsigned NOT NULL COMMENT 'File size in bytes',
  `mtime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last modification time',
  `fstat` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT 'File properties',
  PRIMARY KEY (`fid`),
  KEY `did` (`did`,`fstat`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;
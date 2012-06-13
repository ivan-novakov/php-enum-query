<?php

/**
 * Example script demonstrating the usage of the class.
 * 
 * Usage: php query.php <number> [domains]
 * 
 * Example:
 * $ php query.php 420234680499 'e164.arpa,e164.org,nrenum.net'
 * 
 * @author Ivan Novakov <ivan.novakov@cesnet.cz>
 */

define('EQ_DIR', realpath(dirname(__FILE__) . '/..') . '/');

require EQ_DIR . 'lib/EnumQuery.php';

$options = array(
    'enum_module_dir' => EQ_DIR . 'perl/', 
    'enum_script_path' => EQ_DIR . 'perl/enum_query.pl'
);

if (! isset($_SERVER['argv'][1])) {
    printf("Usage: %s <number> [domains]\n", $_SERVER['argv'][0]);
    exit(0);
}

$searchString = $_SERVER['argv'][1];

$domains = array();
if (isset($_SERVER['argv'][2])) {
    $domains = explode(',', $_SERVER['argv'][2]);
}

$eq = new EnumQuery($options);
$result = $eq->query($searchString, $domains);
print_r($result);

PHP ENUM Query
==============

Simple PHP class wrapping a perl script implementing ENUM queries

Requirements
------------

* PHP 5
* Perl (Net/Dns)


Usage
-----

    define('EQ_DIR', realpath(dirname(__FILE__) . '/..') . '/');

    require EQ_DIR . 'lib/EnumQuery.php';

    $options = array(
        'enum_module_dir' => EQ_DIR . 'perl/', 
        'enum_script_path' => EQ_DIR . 'perl/enum_query.pl'
    );

    $searchString = '+420234680499';
    $domains = array('e164.arpa', 'e164.org', 'nrenum.net');

    $eq = new EnumQuery($options);
    $result = $eq->query($searchString, $domains);
    



The Perl script
---------------

It's an old script by Kazunori Fujiwara <fujiwara@jprs.co.jp>:

Copyright (c) 2004  Japan Registry Service Co., LTD.
Copyright (c) 2004  Kazunori Fujiwara
<?php


/**
 * Simple class wrapping a perl script for ENUM queries.
 * 
 * Required options:
 * - 'enum_module_dir' - the directory where the ENUM.pm module is located
 * - 'enum_script_path' - the full path to the perl script
 * 
 * @author Ivan Novakov <ivan.novakov@cesnet.cz>
 * @license FreeBSD
 * 
 */
class EnumQuery
{

    /**
     * The options array.
     * 
     * @var array
     */
    protected $_options = array();

    /**
     * Default domains array. Used, when no domain is specified in the query.
     * 
     * @var array
     */
    protected $_defaultDomains = array(
        '.e164.arpa'
    );

    /**
     * The directory, where the module ENUM.pm is located.
     * 
     * @var string
     */
    protected $_moduleDir = '';

    /**
     * The full path to the perl script performing ENUM query.
     * 
     * @var string
     */
    protected $_scriptPath = '';


    /**
     * Constructor.
     * 
     * @param array $options
     */
    public function __construct (Array $options)
    {
        $this->_options = $options;
        
        $this->_moduleDir = $this->_getModuleDir();
        $this->_scriptPath = $this->_getScriptPath();
    }


    /**
     * Performs an ENUM query for the supplied search string and domains.
     * 
     * Returns an array of results per each domain.
     * 
     * @param string $searchString
     * @param array $domains
     * @return array
     */
    public function query ($searchString, Array $domains = array())
    {
        if (empty($domains)) {
            $domains = $this->_defaultDomains;
        }
        
        $result = array();
        foreach ($domains as $domain) {
            $result[$domain] = $this->queryDomain($searchString, $domain);
        }
        
        return $result;
    }


    /**
     * Perform an ENUM query over a single domain.
     * 
     * @param string $searchString
     * @param string $domain
     * @return array
     */
    public function queryDomain ($searchString, $domain)
    {
        $searchString = $this->_normalizeSearchString($searchString);
        $domain = $this->_normalizeDomain($domain);
        
        $result = array(
            'number' => $searchString, 
            'domain' => $domain
        );
        
        try {
            $domainResult = $this->_executeQuery($searchString, $domain);
            
            $result += array(
                'success' => true, 
                'records' => $domainResult
            );
        } catch (Exception $e) {
            $result += array(
                'success' => false, 
                'reason' => $e->getMessage()
            );
        }
        
        return $result;
    }


    /**
     * Executes the external perl script.
     * 
     * @param string $searchString
     * @param string $domain
     * @throws Exception
     * @return array
     */
    protected function _executeQuery ($searchString, $domain)
    {
        $result = array();
        
        $cmd = sprintf("perl -w -I%s %s %s %s", escapeshellarg($this->_moduleDir), escapeshellarg($this->_scriptPath), escapeshellarg($searchString), escapeshellarg($domain));
        
        $returnValue = NULL;
        exec($cmd, $output, $returnValue);
        
        switch ($returnValue) {
            case 1:
                throw new Exception(sprintf("Invalid query for number '%s', domain '%s'", $searchString, $domain));
                break;
            
            case 2:
                throw new Exception(sprintf("Not found - number '%s', domain '%s'", $searchString, $domain));
                break;
            
            default:
                break;
        }
        
        $parsedOutput = $this->_parseOutput($output);
        if ($parsedOutput) {
            $result = $parsedOutput;
        }
        
        return $result;
    }


    /**
     * Returns the module directory. Performs some checks.
     * 
     * @throws Exception
     * @return string
     */
    protected function _getModuleDir ()
    {
        $moduleDir = $this->_getOption('enum_module_dir');
        if (! $moduleDir) {
            throw new Exception("No module directory specified - use the 'enum_module_dir' option");
        }
        
        if (! file_exists($moduleDir) || ! is_dir($moduleDir)) {
            throw new Exception(sprintf("Invalid module directory '%s'", $moduleDir));
        }
        
        return $moduleDir;
    }


    /**
     * Returns the script path. Performs some checks.
     * 
     * @throws Exception
     * @return string
     */
    protected function _getScriptPath ()
    {
        $scriptPath = $this->_getOption('enum_script_path');
        if (! $scriptPath) {
            throw new Exception("No script path specified - use the 'enum_script_path' option");
        }
        
        if (! file_exists($scriptPath)) {
            throw new Exception(sprintf("Non-existent file '%s'", $scriptPath));
        }
        
        if (! is_file($scriptPath) || ! is_executable($scriptPath)) {
            throw new Exception(sprintf("Invalid script file '%s'", $scriptPath));
        }
        
        return $scriptPath;
    }


    /**
     * Parses the output of the perl script.
     * 
     * @param array $output
     * @return array
     */
    protected function _parseOutput (Array $output)
    {
        $parsed = array();
        foreach ($output as $line) {
            $fields = explode("|", $line);
            
            $parsed[] = array(
                "order" => trim($fields[0]), 
                "pref" => trim($fields[1]), 
                "service" => trim($fields[2]), 
                "servicefound" => trim($fields[3]), 
                "uri" => trim($fields[4])
            );
        }
        
        return $parsed;
    }


    /**
     * Performs some normalization over the search string - removes spaces, adds '+' in front if missing.
     * 
     * @param string $searchString
     * @throws Exception
     * @return string
     */
    protected function _normalizeSearchString ($searchString)
    {
        $searchString = str_replace(' ', '', trim($searchString));
        
        if (substr($searchString, 0, 1) != '+') {
            $searchString = '+' . $searchString;
        }
        
        if (! preg_match('/^\+\d+$/', $searchString)) {
            throw new Exception(sprintf("Invalid search string '%s'", $searchString));
        }
        
        return $searchString;
    }


    /**
     * Performs some normalizations over the domain - removes spaces, adds '.' in front if missing.
     * 
     * @param string $domain
     * @return string
     */
    protected function _normalizeDomain ($domain)
    {
        $domain = trim($domain);
        if (substr($domain, 0, 1) != '.') {
            $domain = '.' . $domain;
        }
        
        return $domain;
    }


    /**
     * Returns the specifies option.
     * 
     * @param string $name
     * @return mixed
     */
    protected function _getOption ($name)
    {
        if (isset($this->_options[$name])) {
            return $this->_options[$name];
        }
        
        return NULL;
    }
}
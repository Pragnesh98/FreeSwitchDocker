--[[nitial Developer of the Original Code is
        ucall <https://uvoice.ucall.co.ao/> [ucall]

        Portions created by the Initial Developer are Copyright (C)
        the Initial Developer. All Rights Reserved.

        Contributor(s):
        ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--set the variables
        conf_dir = [[/usr/local/freeswitch/conf]];
        sounds_dir = [[/usr/local/freeswitch/sounds]];
        database_dir = [[/usr/local/freeswitch/db]];
        recordings_dir = [[/usr/local/freeswitch/recordings]];
        storage_dir = [[/usr/local/freeswitch/storage]];
        voicemail_dir = [[/usr/local/freeswitch/storage/voicemail]];
        scripts_dir = [[/usr/local/freeswitch/scripts]];
        php_dir = [[/usr/bin]];
        php_bin = "php";
        document_root = [[/var/www/ucall]];
        project_path = [[]];
        http_protocol = [[http]];

--cache settings
        cache = {}
        cache.method = [[memcache]];
        cache.location = [[/var/cache/ucall]];
        cache.settings = false;

--database information
        database = {}
        database.type = "pgsql";
        database.name = "ucall";
        database.path = [[]];
       -- database.kamailio = "pgsql://hostaddr=127.0.0.1 port=5432 dbname=kamailio user=postgres password=psql options='' application_name='kamailio'";
        --database.system = "pgsql://hostaddr=127.0.0.1 port=5432 dbname=ucc_call_centre_db user=postgres password=psql options=''";
       -- database.switch = "pgsql://hostaddr=127.0.0.1 port=5432 dbname=freeswitch user=postgres password=psql options=''";
        database.system = "pgsql://hostaddr=65.2.67.84 port=5432 dbname=ucall user=postgres password=BngrpF2vAqIdn4MbTVTUVUO9I options='' application_name='ucall'";
        database.kamailio = "pgsql://hostaddr=65.2.67.84 port=5432 dbname=kamailio user=kamailio password=BngrpF2vAqIdn4MbTVTUVUO9I options='' application_name='kamailio'";
        database.switch = "pgsql://hostaddr=65.2.67.84 port=5432 dbname=freeswitch user=postgres password=BngrpF2vAqIdn4MbTVTUVUO9I options='' application_name='freeswitch'";

        database.backend = {}
        database.backend.base64 = 'luasql'

--set defaults
        expire = {}
        expire.default = "3600";
        expire.directory = "3600";
        expire.dialplan = "3600";
        expire.languages = "3600";
        expire.sofia = "3600";
        expire.acl = "3600";
        expire.ivr = "3600";

--set xml_handler
        xml_handler = {}
        xml_handler.fs_path = false;
        xml_handler.reg_as_number_alias = false;
        xml_handler.number_as_presence_id = true;

--set settings
        settings = {}
        settings.recordings = {}
        settings.voicemail = {}
        settings.fax = {}
        settings.recordings.storage_type = "";
        settings.voicemail.storage_type = "";
        settings.fax.storage_type = "";

--set the debug options
        debug.params = false;
        debug.sql = false;
        debug.xml_request = false;
        debug.xml_string = false;
        debug.cache = false;

--additional info
        domain_count = 1;
        temp_dir = [[/tmp]];

--include local.lua
        require("resources.functions.file_exists");
        if (file_exists("/etc/ucall/local.lua")) then
                dofile("/etc/ucall/local.lua");
        elseif (file_exists("/usr/local/etc/ucall/local.lua")) then
                dofile("/usr/local/etc/ucall/local.lua");
        elseif (file_exists(scripts_dir.."/resources/local.lua")) then
                require("resources.local");
        end                                                

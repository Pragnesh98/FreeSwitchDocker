--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]


-- add file_exists function
	require "resources.functions.file_exists";

--find and return path to the config.lua
	function config()
		if (file_exists("/etc/ucall/config.lua")) then
			return "/etc/ucall/config.lua";
		elseif (file_exists("/usr/local/etc/ucall/config.lua")) then
			return "/usr/local/etc/ucall/config.lua";
		else
			return "resources.config";
		end
	end

-- load config
	function load_config()
		local cfg = config()
		if cfg:sub(1,1) == '/' then
			dofile(cfg)
		else
			require(cfg)
		end
	end

	load_config()

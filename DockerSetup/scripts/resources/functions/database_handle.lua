--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--connect to the database
	function database_handle(t)
		if (t == "system") then
			return freeswitch.Dbh(database["system"]);
		elseif (t == "switch") then
			return freeswitch.Dbh(database["switch"]);
		end
	end

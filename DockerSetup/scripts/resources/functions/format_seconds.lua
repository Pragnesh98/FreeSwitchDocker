--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--format seconds to 00:00:00
	function format_seconds(seconds)
		local seconds = tonumber(seconds);
		if seconds == 0 then
			return "00:00:00";
		else
			hours = string.format("%02.f", math.floor(seconds/3600));
			minutes = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
			seconds = string.format("%02.f", math.floor(seconds - hours*3600 - minutes *60));
			return string.format("%02d:%02d:%02d", hours, minutes, seconds);
		end
	end

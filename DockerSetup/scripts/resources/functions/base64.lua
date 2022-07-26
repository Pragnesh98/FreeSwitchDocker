--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]


base64 = {}

-- encode a string and return a base64 string
function base64.encode(s)
	if package.loaded["mime"] then
		local mime = require("mime.core");
		return (mime.b64(s));
	else
		require "resources.functions.base64_alex";
		return base64.enc(s);
	end
end

--decode a base64 string and return a string
function base64.decode(s)
	if package.loaded["mime"] then
		local mime = require("mime.core");
		return (mime.unb64(s));
	else
		require "resources.functions.base64_alex";
		return base64.dec(s);
	end
end

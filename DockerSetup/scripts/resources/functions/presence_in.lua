--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]


require "resources.functions.split"
local api = require "resources.functions.api"
local log = require "resources.functions.log".presence

local function turn_lamp(on, user, uuid)
	log.debugf('turn_lamp: %s - %s(%s)', tostring(user), tostring(on), type(on))

	local userid, domain, proto = split_first(user, "@", true)
	proto, userid = split_first(userid, "+", true)
	if userid then
		user = userid  .. "@" .. domain
	else
		proto = "sip"
	end

	uuid = uuid or api:execute('create_uuid')

	local event = freeswitch.Event("PRESENCE_IN");
	event:addHeader("proto", proto);
	event:addHeader("event_type", "presence");
	event:addHeader("alt_event_type", "dialog");
	event:addHeader("Presence-Call-Direction", "outbound");
	event:addHeader("from", user);
	event:addHeader("login", user);
	event:addHeader("unique-id", uuid);
	event:addHeader("status", "Active (1 waiting)");
	if on then
		event:addHeader("answer-state", "confirmed");
		event:addHeader("rpid", "unknown");
		event:addHeader("event_count", "1");
	else
		event:addHeader("answer-state", "terminated");
	end

	-- log.debug(event:serialize())

	event:fire();
end

return {
	turn_lamp = turn_lamp;
}

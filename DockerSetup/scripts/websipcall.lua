--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--include config.lua
	require "resources.functions.config";

	domain_name = session:getVariable("sip_h_X-context");
	username = session:getVariable("destination_number");
	sipproxy = freeswitch.getGlobalVariable("SIPPROXYIP");
	caller_id_number = session:getVariable("caller_id_number");
	uuid = session:getVariable("uuid");
	api = freeswitch.API();


	if tostring(domain_name) == "hepta-media.heptadial.com" then


		session:setVariable("sofia_str", "{rtp_secure_media_outbound=false}[media_webrtc=false]sofia/external/"..tostring(username).."@"..tostring(domain_name)..";fs_path=sip:"..tostring(sipproxy).."");
		--session:setVariable("sofia_str", "{ignore_early_media=true}[hold_music='"..tostring(hold_music).."',media_webrtc=true]sofia/internal/"..tostring(username).."@"..tostring(domain_name)..";fs_path=sip:"..tostring(sipproxy).."");
	else 
		api_cmd = "user_data "..tostring(username).."@"..tostring(domain_name).." var hold_music"
		hold_music = api:executeString(api_cmd)
		freeswitch.consoleLog("notice", "API CMD : " .. tostring(api_cmd) .. "\n");
		if(hold_music) then
			freeswitch.consoleLog("notice", "Caller Destination MOH  : " .. tostring(hold_music) .. "\n");
			session:setVariable("dst_hold_music", tostring(hold_music));
		end
		session:setVariable("sofia_str", "{ignore_early_media=true}[api_on_answer='luarun callrecord.lua ${uuid}',hold_music='"..tostring(hold_music).."',media_webrtc=true]sofia/internal/"..tostring(username).."@"..tostring(domain_name)..";fs_path=sip:"..tostring(sipproxy).."");
	end

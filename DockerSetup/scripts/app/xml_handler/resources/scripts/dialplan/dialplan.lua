--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

	local cache = require"resources.functions.cache"
	local log = require"resources.functions.log"["xml_handler"]

	if (call_context == nil) then
		call_context = "public";
	end

	if (context_type == nil) then
		context_type = "multiple";
	end
	domain_name = 'global';

	local context_name = call_context;
	if (call_context == "public" or string.sub(call_context, 0, 7) == "public@" or string.sub(call_context, -7) == ".public") then
		context_name = 'public';
	end

	local dialplan_cache_key = "dialplan:" .. call_context;
	if (context_name == 'public' and context_type == "single") then
		dialplan_cache_key = "dialplan:public" 
	end

	XML_STRING, err = cache.get(dialplan_cache_key);
	if (debug['cache']) then
		if XML_STRING then
			log.notice(dialplan_cache_key.." source: cache");
		elseif err ~= 'NOT FOUND' then
			log.notice("error get element from cache: " .. err);
		end
	end

	if (not XML_STRING) then
		
		local Database = require "resources.functions.database";
		dbh = Database.new('system');
		local json
		if (debug["sql"]) then
			json = require "resources.functions.lunajson"
		end
		assert(dbh:connected());
		hostname = trim(api:execute("switchname", ""));
		
		local xml = {}
		table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
		table.insert(xml, [[<document type="freeswitch/xml">]]);
		table.insert(xml, [[	<section name="dialplan" description="">]]);
		table.insert(xml, [[		<context name="]] .. call_context .. [[">]]);
			
		if(context_name == 'public') then
			table.insert(xml, [[		<extension name="from_kamailio" continue="false">]])
			table.insert(xml, [[		<condition field="${description_number}" expression="^(.*)$" break="on-true">]])
			table.insert(xml, [[		<action application="set" data="domain_name=${sip_h_X-context}" inline="true"/>]])
			table.insert(xml, [[		<action application="log" data="info Domain Name : ${domain_name}"/>]])
	--		table.insert(xml, [[		<action application="lua" data="check_sticky.lua"/>]])
			table.insert(xml, [[		<action application="lua" data="didlookup.lua"/>]])
			table.insert(xml, [[		<action application="transfer" data="${destination_number} XML ${domain_name}"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])
			
		elseif(context_name == 'callpark') then
			table.insert(xml, [[		<extension name="callpark" continue="" >]])
			table.insert(xml, [[		<condition field="destination_number" expression="^(.*)$">]])
			table.insert(xml, [[		<action application="set" data="valet_hold_music=local_stream://default"/>]])
			table.insert(xml, [[		<action application="set" data="api_result=${bgapi(lua callbridge.lua ${uuid}}"/>]])
			table.insert(xml, [[		<action application="answer" data=""/>]])
			table.insert(xml, [[		<action application="valet_park" data="callbridge ${uuid}"/>]])
			table.insert(xml, [[		<action application="hangup" data=""/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])
		elseif(context_name == 'CALLBACK') then
			table.insert(xml, [[		<extension name="callback" continue="" >]])
			table.insert(xml, [[		<condition field="destination_number" expression="^(.*)$">]])
			table.insert(xml, [[		<action application="lua" data="callback.lua"/>]])
			table.insert(xml, [[		<action application="hangup" data=""/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])
			
		elseif(context_name == 'callcenter') then
			table.insert(xml, [[		<extension name="callcenter" continue="" >]])
			table.insert(xml, [[		<condition field="destination_number" expression="^(.*)$">]])
			table.insert(xml, [[		<action application="set" data="hangup_after_bridge=true"/>]])
			table.insert(xml, [[		<action application="set" data="cc_exit_keys=#"/>]])
			table.insert(xml, [[		<action application="set" data="nolocal:execute_on_ring=lua ringtime.lua ${uuid}"/>]])
			table.insert(xml, [[		<action application="set" data="cc_export_vars=sip_h_X-xml_cdr_uuid,cc_queue,cc_agent,cc_queue_wrap_up_time,cc_camp_activity_uuid,sip_h_X-context,camp_uuid,camp_name,sip_h_X-CAMP-UUID,sip_auto_answer,cc_record_filename,cc_record_queue,domain_uuid"/>]])
--			table.insert(xml, [[		<action application="answer" data=""/>]])
			table.insert(xml, [[		<action application="callcenter" data="$1 ${domain_uuid}"/>]])
			table.insert(xml, [[		<action application="lua" data="survey.lua"/>]])
			table.insert(xml, [[		<action application="hangup" data=""/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])

		elseif(context_name == 'PLAYBACK') then
			table.insert(xml, [[		<extension name="playback" continue="" >]])
			table.insert(xml, [[		<condition field="destination_number" expression="^(.*)$">]])
			table.insert(xml, [[		<action application="answer" data=""/>]])
			table.insert(xml, [[		<action application="playback" data="/usr/local/freeswitch/prompts/$1"/>]])
			table.insert(xml, [[		<action application="hangup" data=""/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])

		elseif(context_name == 'IVR') then
			table.insert(xml, [[		<extension name="ivr" continue="" >]])
			table.insert(xml, [[		<condition field="destination_number" expression="^(.*)$">]])
			table.insert(xml, [[		<action application="answer" data=""/>]])
			table.insert(xml, [[		<action application="ivr" data="$1"/>]])
			table.insert(xml, [[		<action application="hangup" data=""/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])

		elseif(context_name == 'VOICEMAIL') then
			table.insert(xml, [[		<extension name="voicemail" continue="" >]])
			table.insert(xml, [[		<condition field="destination_number" expression="^(.*)$">]])
			table.insert(xml, [[		<action application="answer" data=""/>]])
			table.insert(xml, [[		<action application="sleep" data="1000"/>]])
			table.insert(xml, [[		<action application="set" data="voicemail_action=save"/>]])
			table.insert(xml, [[		<action application="set" data="voicemail_id=$1"/>]])
			table.insert(xml, [[		<action application="set" data="voicemail_profile=default"/>]])
			table.insert(xml, [[		<action application="lua" data="app.lua voicemail"/>]])
			table.insert(xml, [[		<action application="hangup" data=""/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])
			
		elseif(context_name == 'customeragent') then
			table.insert(xml, [[		<extension name="customeragent" continue="" >]])
			table.insert(xml, [[		<condition field="destination_number" expression="^(.*)$">]])
			table.insert(xml, [[		<action application="set" data="valet_hold_music=local_stream://default"/>]])
			table.insert(xml, [[		<action application="answer" data=""/>]])
			table.insert(xml, [[		<action application="valet_park" data="ccpark ${uuid}"/>]])
			table.insert(xml, [[		<action application="hangup" data=""/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])
			
		else

			table.insert(xml, [[		<extension name="send_to_voicemail" continue="false">]])
			table.insert(xml, [[		<condition field="destination_number" expression="^\*99(\d{2,14})$">]])
			table.insert(xml, [[		<action application="answer" data=""/>]])
			table.insert(xml, [[		<action application="sleep" data="1000"/>]])
			table.insert(xml, [[		<action application="set" data="voicemail_action=save"/>]])
			table.insert(xml, [[		<action application="set" data="voicemail_id=$1"/>]])
			table.insert(xml, [[		<action application="set" data="voicemail_profile=default"/>]])
			table.insert(xml, [[		<action application="set" data="vm_message_ext=${vm_message_ext}"/>]])
			table.insert(xml, [[		<action application="set" data="send_to_voicemail=true"/>]])
			table.insert(xml, [[		<action application="lua" data="app.lua voicemail"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])
			table.insert(xml, [[		<extension name="vmain_user" continue="false">]])
			table.insert(xml, [[		<condition field="destination_number" expression="^\*97$">]])
			table.insert(xml, [[		<action application="answer" data=""/>]])
			table.insert(xml, [[		<action application="sleep" data="1000"/>]])
			table.insert(xml, [[		<action application="set" data="voicemail_action=check"/>]])
			table.insert(xml, [[		<action application="set" data="voicemail_id=${caller_id_number}"/>]])
			table.insert(xml, [[		<action application="set" data="voicemail_profile=default"/>]])
			table.insert(xml, [[		<action application="set" data="vm_message_ext=${vm_message_ext}"/>]])
			table.insert(xml, [[		<action application="lua" data="app.lua voicemail"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])

                        table.insert(xml, [[             <extension name="call_block" continue="true">]])
                        --table.insert(xml,[[             <condition field="call_direction" expression="^(OUTBOUND|INBOUND|LOCAL)$">]])
                        table.insert(xml, [[             <condition field="destination_number" expression="^(.*)$">]])
			table.insert(xml, [[            <action application="set" data="domain_name=${sip_h_X-context}" inline="true"/>]])
			table.insert(xml, [[            <action application="log" data="info Domain Name : ${domain_name}"/>]])
			--table.insert(xml, [[		<action application="lua" data="didlookup.lua"/>]])
                        table.insert(xml, [[             <action application="lua" data="app.lua call_block"/>]])
                        table.insert(xml, [[             </condition>]])
                        table.insert(xml, [[             </extension>]])

			table.insert(xml, [[		<extension name="user_exists" continue="true" uuid="de45d0fa-ac1e-490f-a87e-bdb52fc78103">]])
			table.insert(xml, [[		<condition field="" expression="">]])
			table.insert(xml, [[		<action application="set" data="user_exists=${user_exists id ${destination_number} ${domain_name}}" inline="true"/>]])
			table.insert(xml, [[		<action application="set" data="from_user_exists=${user_exists id ${sip_from_user} ${sip_from_host}}" inline="true"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		<condition field="${from_user_exists}" expression="^true$">]])
			table.insert(xml, [[		<action application="set" data="outbound_caller_id_name=${user_data ${caller_id_number}@${domain_name} var outbound_caller_id_name}" inline="true"/>]])
			table.insert(xml, [[		<action application="set" data="outbound_caller_id_number=${user_data ${caller_id_number}@${domain_name} var outbound_caller_id_number}" inline="true"/>]])
			table.insert(xml, [[		<action application="set" data="hold_music=${user_data ${caller_id_number}@${domain_name} var hold_music}" inline="true"/>]])
			table.insert(xml, [[		</condition>]])
			
			table.insert(xml, [[		<condition field="${user_exists}" expression="^true$">]])
			table.insert(xml, [[		<action application="set" data="hold_music=${user_data ${destination_number}@${domain_name} var hold_music}" inline="true"/>]])
			table.insert(xml, [[		<action application="set" data="call_timeout=${user_data ${destination_number}@${domain_name} var call_timeout}" inline="true"/>]])
			table.insert(xml, [[		<action application="set" data="toll_allow=${user_data ${destination_number}@${domain_name} var toll_allow}" inline="true"/>]])
			table.insert(xml, [[		<action application="set" data="user_record=${user_data ${destination_number}@${domain_name} var user_record}" inline="true"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])

			table.insert(xml, [[		<extension name="echo">]])
			table.insert(xml, [[  		<condition field="destination_number" expression="^9196$">]])
			table.insert(xml, [[        	<action application="answer"/>]])
			table.insert(xml, [[        	<action application="echo"/>]])
			table.insert(xml, [[      	</condition>]])
			table.insert(xml, [[    	</extension>]])

			table.insert(xml, [[		<extension name="call_group">]])
			table.insert(xml, [[  		<condition field="destination_number" expression="^\*44(.*)$">]])
			table.insert(xml, [[        	<action application="answer"/>]])
			table.insert(xml, [[        	<action application="lua" data="group.lua $1"/>]])
			table.insert(xml, [[        	<action application="lua" data="app.lua ring_groups"/>]])
			table.insert(xml, [[      	</condition>]])
			table.insert(xml, [[    	</extension>]])

			table.insert(xml, [[		<extension name="eavesdrop" continue="false" uuid="e862081b-68b3-42ea-9b14-84b2f9dbd998">]])
			table.insert(xml, [[		<condition field="destination_number" expression="^\*33(.*)$">]])
			table.insert(xml, [[		<action application="answer" data=""/>]])
			--table.insert(xml, [[		<action application="set" data="pin_number=91327747"/>]])
			table.insert(xml, [[		<action application="lua" data="eavesdrop.lua $1"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])

			table.insert(xml, [[		<extension name="pstn" continue="false">]])
			table.insert(xml, [[		<condition field="${user_exists}" expression="false"/>]])
			table.insert(xml, [[		<condition field="destination_number" expression="^(0923190067)([0-9]\d{8,17})$" break="on-true">]])
			table.insert(xml, [[		<action application="export" data="call_direction=outbound"/>]])
			table.insert(xml, [[		<action application="unset" data="call_timeout"/>]])
			table.insert(xml, [[		<action application="set" data="hangup_after_bridge=true"/>]])
			table.insert(xml, [[		<action application="lua" data="calleridnumber.lua"/>]])
			table.insert(xml, [[		<action application="set" data="effective_caller_id_name=${outbound_caller_id_name}"/>]])
			table.insert(xml, [[		<action application="set" data="effective_caller_id_number=${outbound_caller_id_number}"/>]])
			table.insert(xml, [[		<action application="set" data="inherit_codec=true"/>]])
			table.insert(xml, [[		<action application="set" data="ignore_display_updates=true"/>]])
			table.insert(xml, [[		<action application="set" data="callee_id_number=$1"/>]])
			table.insert(xml, [[		<action application="set" data="continue_on_fail=true"/>]])
			table.insert(xml, [[		<action application="set" data="sip_h_X-ucall=outbound"/>]])
			table.insert(xml, [[		<action application="bridge" data="{ignore_early_media=true}[api_on_answer='luarun callrecord.lua ${uuid}']sofia/external/${destination_number}@${domain_name};fs_path=sip:$${SIPPROXYIP}"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])
			
			table.insert(xml, [[		<extension name="pstn-US" continue="false">]])
			table.insert(xml, [[		<condition field="${user_exists}" expression="false"/>]])
			table.insert(xml, [[		<condition field="destination_number" expression="^(.*)$" break="on-true">]])
			--table.insert(xml, [[		<condition field="destination_number" expression="^(0923190068)([0-9]\d{8,17})$" break="on-true">]])
			--table.insert(xml, [[		<condition field="destination_number" expression="^19192$|^([0-9]\d{8,17})$|^(\+1|1|9|91|8|81)?([2-9]\d{9})$|^\+?8?9?(011)?([2-9]\d{9,17})$|^\+?9?(01|52)?(\d{10})$|^\+?9?(044|045)(\d{10})$|^\+?9?00(\d{9,17})$|^\+?(00)([1-9]\d{8}\d+)$" break="on-true">]])
			table.insert(xml, [[		<action application="export" data="call_direction=outbound"/>]])
			table.insert(xml, [[		<action application="unset" data="call_timeout"/>]])
			table.insert(xml, [[		<action application="set" data="hangup_after_bridge=true"/>]])
			table.insert(xml, [[		<action application="lua" data="calleridnumber.lua"/>]])
			table.insert(xml, [[		<action application="set" data="effective_caller_id_name=${outbound_caller_id_name}"/>]])
			table.insert(xml, [[		<action application="set" data="effective_caller_id_number=${outbound_caller_id_number}"/>]])
			table.insert(xml, [[		<action application="set" data="inherit_codec=true"/>]])
			table.insert(xml, [[		<action application="set" data="ignore_display_updates=true"/>]])
			table.insert(xml, [[		<action application="set" data="callee_id_number=$1"/>]])
			table.insert(xml, [[		<action application="set" data="continue_on_fail=true"/>]])
			table.insert(xml, [[		<action application="set" data="sip_h_X-ucall=outbound"/>]])
			--table.insert(xml, [[		<action application="set" data="execute_on_answer=avmd_start"/>/>]])
			--table.insert(xml, [[		<action application="set" data="execute_on_answer=amd"/>/>]])
			table.insert(xml, [[		<action application="bridge" data="{ignore_early_media=true}[api_on_answer='luarun callrecord.lua ${uuid}']sofia/external/${destination_number}@${domain_name};fs_path=sip:$${SIPPROXYIP}"/>]])
			table.insert(xml, [[		<action application="lua" data="status.lua"/>/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])

			table.insert(xml, [[		<extension name="agent_status" continue="false" uuid="d84b293a-8243-4169-9d2c-fd2a0deed48a">]])
			table.insert(xml, [[		<condition field="destination_number" expression="^\*22$" break="never">]])
			table.insert(xml, [[		<action application="set" data="agent_id=${sip_from_user}"/>]])
			table.insert(xml, [[		<action application="lua" data="app.lua agent_status"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		<condition field="destination_number" expression="^(agent\+)(.*)$">]])
			table.insert(xml, [[		<action application="set" data="agent_id=${sip_from_user}"/>]])
			table.insert(xml, [[		<action application="lua" data="app.lua agent_status"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])

			table.insert(xml, [[		<extension name="agent_status_id" continue="false" uuid="acd21d72-46e2-4e6c-bf16-33ea0bfb0f85">]])
			table.insert(xml, [[		<condition field="destination_number" expression="^\*23$">]])
			table.insert(xml, [[		<action application="set" data="agent_id="/>]])
			table.insert(xml, [[		<action application="lua" data="app.lua agent_status"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])

			table.insert(xml, [[		<extension name="group-intercept" continue="false" uuid="ff003430-3c92-489e-9e8e-4a2d07add5fd">]])
			table.insert(xml, [[		<condition field="destination_number" expression="^\*8$"/>]])
			table.insert(xml, [[		<condition field="${sip_h_X-intercept_uuid}" expression="^(.+)$" break="on-true">]])
			table.insert(xml, [[		<action application="intercept" data="$1"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		<condition field="" expression="">]])
			table.insert(xml, [[		<action application="answer" data=""/>]])
			table.insert(xml, [[		<action application="lua" data="intercept_group.lua inbound"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])


			table.insert(xml, [[		<extension name="local_extension" continue="true" uuid="a386cf40-b896-45e6-8f4e-a99f66749324">]])
			table.insert(xml, [[		<condition field="${user_exists}" expression="true">]])
			table.insert(xml, [[		<action application="export" data="dialed_extension=${destination_number}" inline="true"/>]])
			table.insert(xml, [[		<action application="export" data="nolocal:hold_music=${dst_hold_music}" inline="true"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		<condition field="" expression="">]])
			table.insert(xml, [[		<action application="set" data="hangup_after_bridge=true"/>]])
			table.insert(xml, [[		<action application="set" data="continue_on_fail=true"/>]])
			table.insert(xml, [[		<action application="lua" data="websipcall.lua"/>]])
-- 			table.insert(xml, [[		<action application="set" data="api_hangup_hook=lua app.lua hangup"/>]])
			table.insert(xml, [[		<action application="export" data="domain_name=${domain_name}"/>]])
-- 			table.insert(xml, [[		<action application="bridge" data="[media_webrtc=${cc_webrtc_media}]sofia/internal/${destination_number}@${domain_name};fs_path=sip:$${SIPPROXYIP}"/>]])
			--table.insert(xml, [[		<action application="set" data="execute_on_answer=amd"/>/>]])
			table.insert(xml, [[		<action application="bridge" data="${sofia_str}"/>]])
			table.insert(xml, [[		<action application="lua" data="app.lua failure_handler"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])
			
			table.insert(xml, [[		<extension name="voicemail" continue="false">]])
			table.insert(xml, [[		<condition field="${user_exists}" expression="true">]])
			table.insert(xml, [[		<action application="answer" data=""/>]])
			table.insert(xml, [[		<action application="sleep" data="1000"/>]])
			table.insert(xml, [[		<action application="set" data="record_append=false"/>]])
			table.insert(xml, [[		<action application="set" data="voicemail_action=save"/>]])
			table.insert(xml, [[		<action application="set" data="voicemail_id=${destination_number}"/>]])
			table.insert(xml, [[		<action application="set" data="voicemail_profile=default"/>]])
			table.insert(xml, [[		<action application="lua" data="app.lua voicemail"/>]])
			table.insert(xml, [[		</condition>]])
			table.insert(xml, [[		</extension>]])

		end
		
	--set the xml array and then concatenate the array to a string
		table.insert(xml, [[		</context>]]);
		table.insert(xml, [[	</section>]]);
		table.insert(xml, [[</document>]]);
		XML_STRING = table.concat(xml, "\n");
		dbh:release();

	--set the cache
		local ok, err = cache.set(dialplan_cache_key, XML_STRING, expire["dialplan"]);
		if debug["cache"] then
			if ok then
				freeswitch.consoleLog("notice", "[xml_handler] " .. dialplan_cache_key .. " stored in the cache\n");
			else
				freeswitch.consoleLog("warning", "[xml_handler] " .. dialplan_cache_key .. " can not be stored in the cache: " .. tostring(err) .. "\n");
			end
		end

	--send to the console
		if (debug["cache"]) then
			freeswitch.consoleLog("notice", "[xml_handler] " .. dialplan_cache_key .. " source: database\n");
		end
	else
	--send to the console
		if (debug["cache"]) then
			freeswitch.consoleLog("notice", "[xml_handler] " .. dialplan_cache_key .. " source: cache\n");
		end
	end --if XML_STRING

--send the xml to the console
	if (debug["xml_string"]) then
		local file = assert(io.open(temp_dir .. "/" .. dialplan_cache_key .. ".xml", "w"));
		file:write(XML_STRING);
		file:close();
	end



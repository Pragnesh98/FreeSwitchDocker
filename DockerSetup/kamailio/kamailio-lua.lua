-- Kamailio - equivalent of routing blocks in LuaScripts v1.0.1

-- global variables corresponding to defined values (e.g., flags) in kamailio.cfg
FLT_ACC=1
FLT_ACCMISSED=2
FLT_ACCFAILED=3
FLT_NATS=5

FLB_NATB=6
FLB_NATSIPPING=7

DEFAULT_DISPATCHER_GRP="1"
DEFAULT_DISPATCHER_ALGR="4"

FLAG_FROM_FS=11
FLAG_FROM_SBC=12

TRUSTED_ADR_GR_SBC="2"
TRUSTED_ADR_GR_FS="1"

PrivateIP = "172.31.23.44"
ExternalIP = "13.36.87.234"

function ksr_request_route()
	KSR.info(" | --> "..KSR.kx.get_method().."\n")

	ksr_route_reqinit();

	ksr_route_natdetect();

	if KSR.is_CANCEL() then
		if KSR.tm.t_check_trans()>0 then
			ksr_route_relay();
		end
		return 1;
	end

	if not KSR.is_ACK() then
		if KSR.tmx.t_precheck_trans()>0 then
			KSR.tm.t_check_trans();
			return 1;
		end
		if KSR.tm.t_check_trans()==0 then return 1 end
	end

	ksr_route_withindlg();

	ksr_route_auth();

	KSR.hdr.remove("Route");
	-- if INVITE or SUBSCRIBE
	if KSR.is_method_in("IS") then
		KSR.rr.record_route();
	end

	if KSR.is_INVITE() then
		hepta_handle_invite();
	end

	ksr_route_sipout();

	-- handle registrations
	ksr_route_registrar();

	if KSR.corex.has_ruri_user() < 0 then
		-- request with no Username in RURI
		KSR.sl.sl_send_reply(484,"Address Incomplete");
		return 1;
	end

	ksr_route_location();

	return 1;
end

-- wrapper around tm relay function
function ksr_route_relay()

	if KSR.is_method_in("IBSU") then
		if KSR.tm.t_is_set("branch_route")<0 then
			KSR.tm.t_on_branch("ksr_branch_manage");
		end
	end

	if KSR.is_method_in("ISU") then
		if KSR.tm.t_is_set("onreply_route")<0 then
			KSR.tm.t_on_reply("ksr_onreply_manage");
		end
	end

	KSR.info("[hepta-cc] =>MESSAGE :: $mb [$ci]\n");
    if(is_method("IBUCA")) then
            setflag(FLT_DLGINFO);
            dlg_manage();
	end

	if KSR.is_INVITE() then
		if KSR.tm.t_is_set("failure_route")<0 then
			KSR.tm.t_on_failure("ksr_failure_manage");
		end
	end

	if KSR.tm.t_relay()<0 then
		KSR.sl.sl_reply_error();
	end
	KSR.x.exit();
end


-- Per SIP request initial checks
function ksr_route_reqinit()
	-- no connect for sending replies
	KSR.set_reply_no_connect();
	-- enforce symmetric signaling
	-- send back replies to the source address of request
	KSR.force_rport();
	if not KSR.is_myself_suri() then
		local srcip = KSR.kx.get_srcip();
		if KSR.htable.sht_match_name("ipban", "eq", srcip) > 0 then
			-- ip is already blocked
			KSR.dbg("request from blocked IP - " .. KSR.kx.get_method()
					.. " from " .. KSR.kx.get_furi() .. " (IP:"
					.. srcip .. ":" .. KSR.kx.get_srcport() .. ")\n");
			KSR.x.exit();
		end
		if KSR.pike.pike_check_req() < 0 then
			KSR.err("ALERT: pike blocking " .. KSR.kx.get_method()
					.. " from " .. KSR.kx.get_furi() .. " (IP:"
					.. srcip .. ":" .. KSR.kx.get_srcport() .. ")\n");
			KSR.htable.sht_seti("ipban", srcip, 1);
			KSR.x.exit();
		end
	end

	local ua = KSR.kx.gete_ua();
	if string.find(ua, "friendly") or string.find(ua, "scanner")
			or string.find(ua, "sipcli") or string.find(ua, "sipvicious") then
		KSR.sl.sl_send_reply(200, "OK");
		KSR.x.exit();
	end

	if KSR.maxfwd.process_maxfwd(10) < 0 then
		KSR.sl.sl_send_reply(483,"Too Many Hops");
		KSR.x.exit();
	end

	if KSR.is_OPTIONS()
			and KSR.is_myself_ruri()
			and KSR.corex.has_ruri_user() < 0 then
		KSR.sl.sl_send_reply(200,"Keepalive");
		KSR.x.exit();
	end

	if KSR.sanity.sanity_check(17895, 7)<0 then
		KSR.err("malformed SIP message from "
				.. KSR.kx.get_srcip() .. ":" .. KSR.kx.get_srcport() .."\n");
		KSR.x.exit();
	end

end


-- Handle requests within SIP dialogs
function ksr_route_withindlg()
	if KSR.siputils.has_totag()<0 then return 1; end

	-- sequential request withing a dialog should
	-- take the path determined by record-routing
	if KSR.rr.loose_route()>0 then
		ksr_route_dlguri();
		if KSR.is_BYE() then
			KSR.setflag(FLT_ACC); -- do accounting ...
			KSR.setflag(FLT_ACCFAILED); -- ... even if the transaction fails
		elseif KSR.is_ACK() then
			-- ACK is forwarded statelessly
			ksr_route_natmanage();
		elseif KSR.is_NOTIFY() then
			-- Add Record-Route for in-dialog NOTIFY as per RFC 6665.
			KSR.rr.record_route();
		end
		ksr_route_relay();
		KSR.x.exit();
	end

	if KSR.is_UPDATE() then
		ksr_route_relay();
	end
	
	if KSR.is_ACK() then
		if KSR.tm.t_check_trans() >0 then
			ksr_route_relay();
			KSR.x.exit();
		else
			KSR.x.exit();
		end
	end

	KSR.sl.sl_send_reply(404, "Not here");
	KSR.x.exit();
end

-- Handle SIP registrations
function ksr_route_registrar()
	if not KSR.is_REGISTER() then return 1; end

	if KSR.is_REGISTER and KSR.permissions.allow_source_address(TRUSTED_ADR_GR_FS) then
		KSR.info("[hepta-cc]==>Request received "..KSR.kx.get_ruri().." From Freeswitch\n");
		KSR.sl.sl_send_reply(200, "OK");
	end

	if KSR.isflagset(FLT_NATS) then
		KSR.setbflag(FLB_NATB);
		-- do SIP NAT pinging
		KSR.setbflag(FLB_NATSIPPING);
	end

	if KSR.registrar.save("location", 0)<0 then
		KSR.sl.sl_reply_error();
	end

	KSR.x.exit();
end

-- User location service
function ksr_route_location()
	local rc = KSR.registrar.lookup("location");

	if rc<0 then
		KSR.tm.t_newtran();
		if rc==-1 or rc==-3 then
			KSR.sl.send_reply(404, "Not Found");
			KSR.x.exit();
		elseif rc==-2 then
			KSR.sl.send_reply(405, "Method Not Allowed");
			KSR.x.exit();
		end
	end

	-- when routing via usrloc, log the missed calls also
	if KSR.is_INVITE() then
		KSR.setflag(FLT_ACCMISSED);
	end

	ksr_route_relay();
	KSR.x.exit();
end


-- IP authorization and user authentication
function ksr_route_auth()
	KSR.info("[hepta-cc]==>Request received ["..KSR.kx.get_srcip()..":"..KSR.kx.get_srcport().."]"..KSR.kx.get_ruri().."\n");
	if not KSR.auth then
		return 1;
	end

	--if KSR.is_REGISTER and KSR.permissions.allow_source_address(TRUSTED_ADR_GR_FS) then
	--	KSR.info("[hepta-cc]==>Request received "..KSR.kx.get_ruri().." From Freeswitch\n")
	--end

	if not KSR.is_REGISTER and KSR.permissions.allow_source_address(TRUSTED_ADR_GR_FS) then
		KSR.info("[hepta-cc]==>Request received "..KSR.kx.get_ruri().." From Freeswitch\n")
		KSR.setflag(FLAG_FROM_FS)
	end

	--if not KSR.is_REGISTER and KSR.pv.get("$si") == PrivateIP then
	--	KSR.info("[hepta-cc]==>Request received "..KSR.kx.get_ruri().." From Freeswitch\n")
	--	KSR.setflag(FLAG_FROM_FS)
	--end

	if not KSR.is_REGISTER and KSR.permissions.allow_source_address(TRUSTED_ADR_GR_SBC) then
		KSR.info("[hepta-cc]==>Request received "..KSR.kx.get_ruri().." From SBC\n")
		KSR.setflag(FLAG_FROM_SBC)
	end

	if KSR.permissions and not KSR.is_REGISTER() then
		if KSR.permissions.allow_source_address(1)>0 then
			-- source IP allowed
			return 1;
		end
	end

	if KSR.is_REGISTER() or KSR.is_myself_furi() then
		-- authenticate requests
		if KSR.auth_db.auth_check(KSR.kx.gete_fhost(), "subscriber", 1)<0 then
			--KSR.info("From Host :"..KSR.kx.gete_fhost().."\n");
			KSR.auth.auth_challenge(KSR.kx.gete_fhost(), 0);
			KSR.x.exit();
		end
		-- user authenticated - remove auth header
		if not KSR.is_method_in("RP") then
			KSR.auth.consume_credentials();
		end
	end

	-- if caller is not local subscriber, then check if it calls
	-- a local destination, otherwise deny, not an open relay here
	if (not KSR.is_myself_furi())
			and (not KSR.is_myself_ruri()) then
		KSR.sl.sl_send_reply(403,"Not relaying");
		KSR.x.exit();
	end

	return 1;
end

-- Caller NAT detection
function ksr_route_natdetect()
	if not KSR.nathelper then
		return 1;
	end

	if KSR.nathelper.nat_uac_test(19)>0 then
		if KSR.is_REGISTER() then
			KSR.nathelper.fix_nated_register();
		elseif KSR.siputils.is_first_hop()>0 then
			KSR.nathelper.set_contact_alias();
		end
		KSR.setflag(FLT_NATS);
	end

	return 1;
end

-- RTPProxy control
function ksr_route_natmanage()

	if not KSR.rtpproxy then
		return 1;
	end

	if KSR.siputils.is_request()>0 then
		if KSR.siputils.has_totag()>0 then
			if KSR.rr.check_route_param("nat=yes")>0 then
				KSR.setbflag(FLB_NATB);
			end
		end
	end

	if (not (KSR.isflagset(FLT_NATS) or KSR.isbflagset(FLB_NATB))) then
		return 1;
	end

	KSR.rtpproxy.rtpproxy_manage("co");

	if KSR.siputils.is_request()>0 then
		if KSR.siputils.has_totag()<0 then
			if KSR.tmx.t_is_branch_route()>0 then
				KSR.rr.add_rr_param(";nat=yes");
			end
		end
	end

	if KSR.siputils.is_reply()>0 then
		if KSR.isbflagset(FLB_NATB) then
			KSR.nathelper.set_contact_alias();
		end
	end

	return 1;
end

-- URI update for dialog requests
function ksr_route_dlguri()
	if not KSR.nathelper then
		return 1;
	end

	if not KSR.isdsturiset() then
		KSR.nathelper.handle_ruri_alias();
	end

	return 1;
end

function ksr_route_xmlrpc()
	if (is_method("POST") or is_method("GET")) and KSR.pv.get("src_ip") == "127.0.0.1" then
		set_reply_no_connect();
		dispatch_rpc();
	end	
	KSR.sl.sl_send_reply(403, "Forbidden");
end

-- Routing to foreign domains
function ksr_route_sipout()
	if KSR.is_myself_ruri() then return 1; end

	KSR.hdr.append("P-Hint: outbound\r\n");
	ksr_route_relay();
	KSR.x.exit();
end

-- Manage outgoing branches
-- equivalent of branch_route[...]{}
function ksr_branch_manage()
	KSR.dbg("new branch [".. KSR.pv.get("$T_branch_idx")
				.. "] to " .. KSR.kx.get_ruri() .. "\n");
	ksr_route_natmanage();
	return 1;
end

-- Manage incoming replies
-- equivalent of onreply_route[...]{}
function ksr_onreply_manage()
	KSR.dbg("incoming reply\n");
	local scode = KSR.kx.get_status();
	if scode>100 and scode<299 then
		ksr_route_natmanage();
	elseif scode == 403 then
		KSR.info("[kamailio] =>Busy Here [403]\n");
		KSR.sl.sl_send_reply(403, "Forbidden");
		KSR.x.exit();
	elseif scode == 487 then
		KSR.info("[kamailio] =>Request Terminated [487]\n");
		KSR.sl.sl_send_reply(403, "Request Terminated");
		KSR.x.exit();
	elseif scode == 480 then
		KSR.info("[kamailio] =>Temporarily Unavailable [480]\n");
		KSR.sl.sl_send_reply(480, "Temporarily Unavailable");
		KSR.x.exit();
	elseif scode == 486 then
		KSR.info("[kamailio] =>Busy Here [486].\n");
		KSR.sl.sl_send_reply(486, "Busy Here");
		KSR.x.exit();
	elseif scode == 603 then
		KSR.info("[kamailio] =>Decline [603].\n");
		KSR.sl.sl_send_reply(603, "Decline");
		KSR.x.exit();
	elseif scode == 404 then
		KSR.info("[kamailio] =>Not Found [404].\n");
		KSR.sl.sl_send_reply(404, "Not Found");
		KSR.x.exit();
	elseif scode >= 500 or scode <= 699 then
		KSR.x.exit();
	elseif scode >= 300 or scode <= 399 then
		KSR.sl.sl_send_reply(404, "Not Found");
		KSR.x.exit();
	end

	return 1;
end

function ksr_failure_manage(REMOTE_AUTH)
	KSR.dbg("Remote Auth reply\n");
	local scode = KSR.kx.get_status();
	ksr_route_natmanage();
	
	if t_is_canceled() then
		KSR.x.exit();
	end

	if scode == 403 then
		KSR.info("[kamailio] =>Busy Here [403]\n");
		KSR.sl.sl_send_reply(403, "Forbidden");
		KSR.x.exit();
	elseif scode == 487 then
		KSR.info("[kamailio] =>Request Terminated [487]\n");
		KSR.sl.sl_send_reply(403, "Request Terminated");
		KSR.x.exit();
	elseif scode == 480 then
		KSR.info("[kamailio] =>Temporarily Unavailable [480]\n");
		KSR.sl.sl_send_reply(480, "Temporarily Unavailable");
		KSR.x.exit();
	elseif scode == 486 then
		KSR.info("[kamailio] =>Busy Here [486].\n");
		KSR.sl.sl_send_reply(486, "Busy Here");
		KSR.x.exit();
	elseif scode == 603 then
		KSR.info("[kamailio] =>Decline [603].\n");
		KSR.sl.sl_send_reply(603, "Decline");
		KSR.x.exit();
	elseif scode == 404 then
		KSR.info("[kamailio] =>Not Found [404].\n");
		KSR.sl.sl_send_reply(404, "Not Found");
		KSR.x.exit();
	elseif scode == 407 then
		KSR.info("[kamailio] =>Remote asked for authentication");
		KSR.sqlops.sql_xquery("dbh", "select siptrunk_username,siptrunk_password from v_siptrunks where  siptrunk_uuid='$hdr(X-siptrunk_uuid)' AND domain_uuid=(select domain_uuid from v_domains where domain_name='$hdr(X-context)')", "ra");
		availUser = KSR.pv.get("$xavp(ra=>siptrunk_username)");
		availPass = KSR.pv.get("$xavp(ra=>siptrunk_password)");
		KSR.pvx.avp_sets("auser", availUser);
		KSR.pvx.avp_sets("apass", availPass);
		KSR.uac.uac_auth();
		ksr_route_relay();
		KSR.x.exit();
	elseif scode >= 500 or scode <= 699 then
		KSR.x.exit();
	elseif scode >= 300 or scode <= 399 then
		KSR.sl.sl_send_reply(404, "Not Found");
		KSR.x.exit();
	end

	return 1;
end

function ksr_failure_manage(SIP_ENDPOINT_FAILED)
	KSR.dbg("Sip endpoint reply\n");
	local scode = KSR.kx.get_status();
	ksr_route_natmanage();
	
	if t_is_canceled() then
		KSR.x.exit();
	end

	if scode == 403 then
		KSR.info("[kamailio] =>Busy Here [403]\n");
		KSR.sl.sl_send_reply(403, "Forbidden");
		KSR.x.exit();
	elseif scode == 487 or scode == 488 then
		KSR.info("[kamailio] =>Request Terminated [487]\n");
		KSR.sl.sl_send_reply(403, "Request Terminated");
		KSR.x.exit();
	elseif scode == 480 then
		KSR.info("[kamailio] =>Temporarily Unavailable [480]\n");
		KSR.sl.sl_send_reply(480, "Temporarily Unavailable");
		KSR.x.exit();
	elseif scode == 486 then
		KSR.info("[kamailio] =>Busy Here [486].\n");
		KSR.sl.sl_send_reply(486, "Busy Here");
		KSR.x.exit();
	elseif scode == 603 then
		KSR.info("[kamailio] =>Decline [603].\n");
		KSR.sl.sl_send_reply(603, "Decline");
		KSR.x.exit();
	elseif scode == 404 then
		KSR.info("[kamailio] =>Not Found [404].\n");
		KSR.sl.sl_send_reply(404, "Not Found");
		KSR.x.exit();
	elseif scode >= 500 or scode <= 699 then
		KSR.x.exit();
	elseif scode >= 300 or scode <= 399 then
		KSR.sl.sl_send_reply(404, "Not Found");
		KSR.x.exit();
	end

	return 1;
end

function ksr_failure_manage(MANAGE_SIPTRUNK_FAILURE)
	revert_uri();
	KSR.info("[kamailio] =>Response From SBC Server [$rs].\n");
	local scode = KSR.kx.get_status();

	if (scode == 408) or (scode >= 500 or scode <= 599) then
		KSR.info("[kamailio] =>Try To Find Another SBC Server.\n");

		if not cr_route("ucall", "fallback", "$rU", "$rU", "call_id") then
			KSR.info("[kamailio] =>No Active SBC Server Found\n");
			KSR.sl.sl_send_reply(403, "Not allowed");
		else
			t_on_failure("MANAGE_SIPTRUNK_FAILURE");
			KSR.info("[kamailio] =>Request Route on SBC [DURI = "..KSR.kx.get_duri().." and RURI = "..KSR.kx.get_ruri().."].\n");
			ksr_route_relay();
			KSR.x.exit();
		end
	end
end

-- Manage failure routing cases
-- equivalent of failure_route[...]{}
function ksr_failure_manage(MANAGE_FAILURE)
	KSR.dbg("Manage Failure\n");
	local scode = KSR.kx.get_status();
	ksr_route_natmanage();
	
	if t_is_canceled() then
		KSR.x.exit();
	end

	if scode == 403 then
		KSR.info("[kamailio] =>Busy Here [403]\n");
		KSR.sl.sl_send_reply(403, "Forbidden");
		KSR.x.exit();
	elseif scode == 487 then
		KSR.info("[kamailio] =>Request Terminated [487]\n");
		KSR.sl.sl_send_reply(403, "Request Terminated");
		KSR.x.exit();
	elseif scode == 480 then
		KSR.info("[kamailio] =>Temporarily Unavailable [480]\n");
		KSR.sl.sl_send_reply(480, "Temporarily Unavailable");
		KSR.x.exit();
	elseif scode == 486 then
		KSR.info("[kamailio] =>Busy Here [486].\n");
		KSR.sl.sl_send_reply(486, "Busy Here");
		KSR.x.exit();
	elseif scode == 603 then
		KSR.info("[kamailio] =>Decline [603].\n");
		KSR.sl.sl_send_reply(603, "Decline");
		KSR.x.exit();
	elseif scode == 404 then
		KSR.info("[kamailio] =>Not Found [404].\n");
		KSR.sl.sl_send_reply(404, "Not Found");
		KSR.x.exit();
	elseif scode == 401 then
		KSR.info("[kamailio] =>Remote asked for authentication");
		KSR.sqlops.sql_xquery("dbh", "select siptrunk_username,siptrunk_password from v_siptrunks where  siptrunk_uuid='$hdr(X-siptrunk_uuid)' AND domain_uuid=(select domain_uuid from v_domains where domain_name='$hdr(X-context)')", "ra");
		availUser = KSR.pv.get("$xavp(ra=>siptrunk_username)");
		availPass = KSR.pv.get("$xavp(ra=>siptrunk_password)");
		KSR.pvx.avp_sets("auser", availUser);
		KSR.pvx.avp_sets("apass", availPass);
		KSR.uac.uac_auth();
		ksr_route_relay();
		KSR.x.exit();
	elseif scode >= 500 or scode <= 699 then
		KSR.x.exit();
	elseif scode >= 300 or scode <= 399 then
		KSR.sl.sl_send_reply(404, "Not Found");
		KSR.x.exit();
	end

	return 1;
end

function hepta_handle_invite()
	sourceIP = KSR.kx.get_srcip();
	sourcePort = KSR.kx.get_srcport();
	routeURI = KSR.kx.get_ruri();

	if KSR.is_INVITE() and KSR.isflagset(FLAG_FROM_SBC) then
		KSR.info("[hepta-cc] =>Request received From Gateway ["..sourceIP..":"..sourcePort.."], ["..routeURI.."]\n");

		KSR.hdr.append("X-direction: Inbound\r\n");
		toUser = KSR.kx.get_tuser()
		KSR.hdr.append("X-DID: "..toUser.."\r\n");
		KSR.info("[hepta-cc] =>DID Number : "..toUser.."\n");

		KSR.sqlops.sql_xquery("dbh", "select domain_uuid::text as d_uuid,destination_data, destination_app,destination_caller_id_name,destination_caller_id_number, destination_cid_name_prefix, regexp_matches('"..toUser.."',destination_number_regex)::text as match from  v_destinations WHERE destination_enabled='true'", "ra");
		domainUUID = KSR.pv.get("$xavp(ra=>d_uuid)");
		KSR.info("[ hepta-cc ] : Domain UUID : "..domainUUID.."\n")

		if domainUUID == nil or domain_uuid == 0 then
			KSR.setflag(FLT_ACCMISSED);
			KSR.info("[hepta-cc] =>DID Lookup Failed, DID "..KSR.kx.get_tuser().." is UNMAPPED.");
			KSR.sl.sl_send_reply(603, "Declined");
		else
			newDST = KSR.pv.get("$xavp(ra=>destination_data)");
			destinationAPP = KSR.pv.get("$xavp(ra=>destination_app)");

			if newDST ~= nil and newDST ~= 0 then
				KSR.sqlops.sql_xquery("dbh", "select domain_name::text as d_name from v_domains WHERE domain_enabled='true' and domain_uuid='"..domainUUID.."'", "ra");
				domainName = KSR.pv.get("$xavp(ra=>d_name)");
				KSR.info("[hepta-cc] =>Domain Name : "..domainName.."\n");

				KSR.hdr.append("X-DESTAPP: "..destinationAPP.."\r\n");
				KSR.info("[ucall-cc] =>New Destination Application : "..destinationAPP.."\n");
				KSR.info("[ucall-cc] =>New Destination Number : "..newDST.."\n");

				if destinationAPP == "campaign" or destinationAPP == "CAMPAIGN" then
					KSR.hdr.append("X-CAMPAIGN: "..newDST.."\r\n");
					KSR.hdr.append("X-CAMP-UUID: "..newDST.."\r\n");

					KSR.pv.sets("$ru","sip:*701@"..domainName);
				else
					KSR.pv.sets("$ru","sip:"..newDST.."@"..domainName);
				end

				KSR.info("[hepta-cc] =>New RU : "..KSR.kx.get_ruri().."\n");

				KSR.hdr.append("X-context: "..domainName.."\r\n");
			end
			KSR.info("[hepta-cc] =>After DID Lookup [ToNum:"..KSR.kx.get_tuser().."][RU:"..KSR.kx.get_ruri().."][DU:"..KSR.kx.get_duri().."]\n");
			ROUTE_TO_FS();
		end
	elseif KSR.is_INVITE() and KSR.isflagset(FLAG_FROM_FS) then
		KSR.info("[hepta-cc] =>Request received From FS - B2BUA ["..sourceIP..":"..sourcePort.."], ["..routeURI.."]\n");
		FROM_FS_ROUTE();
	else
		if KSR.is_INVITE() then
			KSR.hdr.append("X-context: "..KSR.kx.get_fuser()"\r\n");
			KSR.info("[ucall-cc] =>Request received From SIP client ["..sourceIP..":"..sourcePort.."], ["..routeURI.."]\n");
			FROM_SIP_ENDPOINT();
		end
	end
end

function ROUTE_TO_FS() 
	KSR.info("[hepta-cc] =>Lookup dispatcher.\n");
	if(KSR.dispatcher.ds_select_dst(DEFAULT_DISPATCHER_GRP, DEFAULT_DISPATCHER_ALGR) == 1) then
		KSR.info("[hepta-cc] =>Routing call on freeswitch ["..KSR.kx.get_duri().."].\n");
		ksr_route_relay();
	end
	KSR.info("[hepta-cc] No destination found");
    KSR.sl.sl_send_reply(404, "No destination");
    KSR.x.exit();
end

function FROM_FS_ROUTE()
	sourceIP = KSR.kx.get_srcip();
	sourcePort = KSR.kx.get_srcport();
	KSR.info("[hepta-cc] =>Request from freeswitch server ["..sourceIP..":"..sourcePort.."]\n");

	HDR = KSR.hdr.get("X-ucall")
	if HDR ~= nil and HDR == "outbound" then
		KSR.info("[ucall-cc] =>Request from freeswitch server ["..sourceIP..":"..sourcePort.."] -PSTN call\n");
		OUTBOUND_ROUTE();
	else
		KSR.info("[ucall-cc] =>Request from freeswitch server ["..sourceIP..":"..sourcePort.."] -PSTN Local\n");
		SEND_TO_SIP_ENDPOINT();
	end
end

function SEND_TO_SIP_ENDPOINT()
	KSR.tm.t_on_failure("SIP_ENDPOINT_FAILED");
	ROUTE_TO_ALL();
end

function ROUTE_TO_ALL()
	if not KSR.registrar.lookup("location") then
		local rc = KSR.registrar.lookup("location");

		if rc<0 then
			KSR.tm.t_newtran();
			if rc==-1 or rc==-3 then
				KSR.sl.send_reply(404, "Not Found");
				KSR.x.exit();
			elseif rc==-2 then
				KSR.sl.send_reply(405, "Method Not Allowed");
				KSR.x.exit();
			end
		end
	end

	if KSR.kx.get_duri() ~= nil then
		KSR.info("[hepta-cc] =>No Registered ["..KSR.kx.get_ruri().."]\n");
		KSR.x.exit();
	end

	ksr_route_relay();
	KSR.x.exit();
end

function FROM_SIP_ENDPOINT()
	KSR.sqlops.sql_xquery("ca","SELECT username FROM subscriber WHERE username='"..KSR.kx.get_tuser().."' AND domain='"..KSR.kx.get_fhost().."'","ra");
	userName = KSR.pv.get("$xavp(ra=>username)");

	if not userName then
		KSR.sqlops.sql_xquery("dbh","select domain_uuid::text as d_uuid,destination_data, destination_app,destination_caller_id_name,destination_caller_id_number, destination_cid_name_prefix, regexp_matches('$tU',destination_number_regex)::text as match from  v_destinations WHERE destination_enabled='true'","ra");
		domainUUID = KSR.pv.get("$xavp(ra=>d_uuid)");
		destinationDATA = KSR.pv.get("$xavp(ra=>destination_data)");

		if destinationDATA ~= nil and destinationDATA ~= 0 then
			KSR.info("[ hepta-cc ] : Domain UUID : "..domainUUID.."\n");
			KSR.hdr.append("X-direction: Inbound\r\n");
			KSR.hdr.append("X-DID: "..KSR.kx.get_tuser().."\r\n");
			KSR.info("[hepta-cc] =>DID Number : "..KSR.kx.get_tuser().."\n");
			KSR.info("[hepta-cc] =>DID ["..KSR.kx.get_tuser().."] Lookup To Get Domain Name Destination\n");

			domainNAME = KSR.kx.get_fhost();
			KSR.info("[ucall-cc] =>Domain Name : "..domainNAME.."\n");

			newDST = KSR.pv.get("$xavp(ra=>destination_data)");
			destinationAPP = KSR.pv.get("$xavp(ra=>destination_app)");
			KSR.info("[ucall-cc] =>New Destination Application : "..destinationAPP.."\n");

			if destinationAPP == "campaign" or destinationAPP == "CAMPAIGN" then
				KSR.hdr.append("X-CAMPAIGN: "..newDST.."\r\n");
				KSR.hdr.append("X-CAMP-UUID: "..newDST.."\r\n");

				KSR.pv.sets("$ru","sip:*701@"..domainName);
			else
				KSR.pv.sets("$ru","sip:"..newDST.."@"..domainName);
			end

			KSR.info("[hepta-cc] =>New RU : "..KSR.kx.get_ruri().."\n");

			KSR.hdr.append("X-context: "..domainName.."\r\n");
		end
		KSR.info("[hepta-cc] =>After DID Lookup [ToNum:"..KSR.kx.get_tuser().."][RU:"..KSR.kx.get_ruri().."][DU:"..KSR.kx.get_duri().."]\n");
		ROUTE_TO_FS();
		KSR.x.exit();
	end 
end

function OUTBOUND_ROUTE()
	KSR.info("[kamailio] =>Lookup SIP Trunk Server.\n");

	siptrunkUUID = KSR.hdr.get("X-siptrunk_uuid");
	context = KSR.hdr.get("X-context");
	KSR.sqlops.sql_xquery("dbh","select siptrunk_host,siptrunk_prefix,siptrunk_suffix,siptrunk_strip,siptrunk_name from v_siptrunks where siptrunk_uuid='"..siptrunkUUID.."' AND domain_uuid=(select domain_uuid from v_domains where domain_name='"..context.."')","ra");

	siptrunkHOST = KSR.pv.get("$xavp(ra=>siptrunk_host)");
	siptrunkPrefix = KSR.pv.get("$xavp(ra=>siptrunk_prefix)");
	siptrunkSuffix = KSR.pv.get("$xavp(ra=>siptrunk_suffix)");
	siptrunkStrip = KSR.pv.get("$xavp(ra=>siptrunk_strip)");
	siptrunkName = KSR.pv.get("$xavp(ra=>siptrunk_name)");

	if siptrunkHOST ~= nil and siptrunkHOST ~= 0 then
		KSR.info("[kamailio] =>SIPTRUNK Host : "..siptrunkHOST.."\n");
		KSR.info("[kamailio] =>SIPTRUNK strip : "..siptrunkStrip.."\n");
		KSR.info("[kamailio] =>siptrunk_prefix : "..siptrunkPrefix.."\n");
		KSR.info("[kamailio] =>siptrunk_suffix : "..siptrunkSuffix.."\n");
		KSR.info("[kamailio] =>siptrunk_name : "..siptrunkName.."\n");

		toNumber = KSR.kx.get_tuser();
		KSR.info("[kamailio] =>ToNumber : "..toNumber.."\n");

		KSR.pv.sets("$du","sip:"..toNumber.."@"..siptrunkHOST);
		KSR.pv.sets("$ru","sip:"..toNumber.."@"..siptrunkHOST);
		KSR.info("[kamailio] =>Found remote user ["..KSR.kx.get_ruri().."] via ["..KSR.kx.get_duri().."]");
		KSR.info("[kamailio] =>DU ::  ["..KSR.kx.get_duri().."]");

		KSR.tm.t_on_failure("REMOTE_AUTH");
		KSR.hdr.remove("^X-");
		ksr_route_relay();
		KSR.x.exit();
	end
	KSR.info("[kamailio] =>SIPTRUNK NOT FOUND\n");
	KSR.sl.send_reply(404, "SIP Trunk Not Found");
	KSR.x.exit();
end



function PROCESS_OPTIONS()
	KSR.sl.send_reply(200, "OK");
	KSR.x.exit();
end
-- SIP response handling
-- equivalent of reply_route{}
function ksr_reply_route()
	KSR.dbg("response - from kamailio lua script\n");
	if KSR.sanity.sanity_check(17604, 6)<0 then
		KSR.err("malformed SIP response from "
				.. KSR.kx.get_srcip() .. ":" .. KSR.kx.get_srcport() .."\n");
		KSR.x.drop();
	end
	return 1;
end

function hepta_sid()
	return KSR.pv.get("$ci");
end

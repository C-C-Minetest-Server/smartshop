smartshop = {
	user={},
	tmp={},
	dir={{x=0,y=0,z=-1},{x=-1,y=0,z=0},{x=0,y=0,z=1},{x=1,y=0,z=0}},
	dpos={
		{{x=0.2,y=0.2,z=0},{x=-0.2,y=0.2,z=0},{x=0.2,y=-0.2,z=0},{x=-0.2,y=-0.2,z=0}},
		{{x=0,y=0.2,z=0.2},{x=0,y=0.2,z=-0.2},{x=0,y=-0.2,z=0.2},{x=0,y=-0.2,z=-0.2}},
		{{x=-0.2,y=0.2,z=0},{x=0.2,y=0.2,z=0},{x=-0.2,y=-0.2,z=0},{x=0.2,y=-0.2,z=0}},
		{{x=0,y=0.2,z=-0.2},{x=0,y=0.2,z=0.2},{x=0,y=-0.2,z=-0.2},{x=0,y=-0.2,z=0.2}}
	}
}

-- table with itemname: number of items being traded
smartshop.itemstats = {}
smartshop.itemprices = {}
smartshop.stuffsold = {}

local WP = minetest.get_worldpath()



smartshop.itemsatpos = function(pos, item, count)
   -- set number of items of type 'item' sold at position 'pos'
   if smartshop.itemstats[item] == nil then
      smartshop.itemstats[item] = {}
   end
   smartshop.itemstats[item][pos] = count
   local data = minetest.serialize(smartshop.itemstats)
   minetest.safe_file_write(WP .. "/smartshop_itemcounts.txt", data)
end

smartshop.itempriceatpos = function(pos, item, price)
   -- set number of items of type 'item' sold at position 'pos'
   if smartshop.itemprices[item] == nil then
      smartshop.itemprices[item] = {}
   end
   local data = minetest.serialize(smartshop.itemprices)
   minetest.safe_file_write(WP .. "/smartshop_itemprices.txt", data)
   smartshop.itemprices[item][pos] = price
end

smartshop.minegeldtonumber = function(stack)
   -- return number of minegeld in stack, returns nil if stack is not composed of minegeld
   count = stack:get_count()
   if count == 0 then
      return 0
   end
   if stack:get_name() == "currency:minegeld" then
      return count
   elseif stack:get_name() == "currency:minegeld_5" then
      return count * 5
   elseif stack:get_name() == "currency:minegeld_10" then
      return count * 10
   elseif stack:get_name() == "currency:minegeld_50" then
      return count * 50
   else
      return nil
   end
end


minetest.register_craft({
	output = "smartshop:shop",
	recipe = {
		{"default:chest_locked", "default:chest_locked", "default:chest_locked"},
		{"default:sign_wall_wood", "default:chest_locked", "default:sign_wall_wood"},
		{"default:sign_wall_wood", "default:torch", "default:sign_wall_wood"},
	}
})
smartshop.get_human_name = function(item)
   if core.registered_items[item] then
      return core.registered_items[item].short_description or core.registered_items[item].description or item
   else
      return "Unknown Item"
   end
end

smartshop.use_offer=function(pos,player,n)
	local pressed={}
	pressed["buy" .. n]=true
	smartshop.user[player:get_player_name()]=pos
	smartshop.receive_fields(player,pressed)
	smartshop.user[player:get_player_name()]=nil
	smartshop.update(pos)
end

smartshop.get_offer=function(pos)
	if not pos or not minetest.get_node(pos) then return end
	if minetest.get_node(pos).name~="smartshop:shop" then return end
	local meta=minetest.get_meta(pos)
	local inv=meta:get_inventory()
	local offer={}
	for i=1,4,1 do
		offer[i]={
		give=inv:get_stack("give" .. i,1):get_name(),
		give_count=inv:get_stack("give" .. i,1):get_count(),
		pay=inv:get_stack("pay" .. i,1):get_name(),
		pay_count=inv:get_stack("pay" .. i,1):get_count(),
		}
	end
	return offer
end

smartshop.send_mail=function(owner, pos, item, pname)
   if not minetest.get_modpath( "mail" ) then
      return
   end
   local spos = "("..pos.x..", "..pos.y..", "..pos.z..")"
   mail.send("DO NOT REPLY", owner, "Out of "..smartshop.get_human_name(item).." at "..spos, "Your smartshop at "..spos.." is out of "..smartshop.get_human_name(item)..". Please restock! Thanks, " .. pname)
end

local function is_creative(pname)
	return minetest.check_player_privs(pname, {creative=true}) or minetest.check_player_privs(pname, {give=true})
end

smartshop.receive_fields=function(player,pressed)
	local pname = player:get_player_name()
	local pos = smartshop.user[pname]
	if not pos then
		return
	end
		if pressed.customer then
			return smartshop.showform(pos, player, true)
		elseif pressed.tooglelime then
			local meta=minetest.get_meta(pos)
			if not is_creative(pname) then
				meta:set_int("type", 1)
				meta:set_int("creative", 0)
				minetest.chat_send_player(pname, "You are not allowed to make a creative shop!")
				return
			end
			if meta:get_int("type")==0 then
				meta:set_int("type",1)
				minetest.chat_send_player(pname, "Your stock is now limited.")
			else
				meta:set_int("type",0)
				minetest.chat_send_player(pname, "Your stock is now unlimited.")
			end
		elseif not pressed.quit then
			local n=1
			for i=1,4,1 do
				n=i
				if pressed["buy" .. i] then break end
			end
			local meta=minetest.get_meta(pos)
			local type=meta:get_int("type")
			local inv=meta:get_inventory()
			local pinv=player:get_inventory()
			if pressed["buy" .. n] then
				local stack=inv:get_stack("give" .. n,1)
				local name=stack:get_name()
				local pay=inv:get_stack("pay" .. n,1)
				if name~="" then
					if type==1 and inv:room_for_item("main", pay)==false then minetest.chat_send_player(pname, "Error: The owner's stock is full, can't receive, exchange aborted.") return end
					if meta:get_int("ghost") ~=1 then
					   -- transition shops to ghost inventory.
					   for i=1,4 do
					      if inv:room_for_item("main", "pay"..i) and inv:room_for_item("main", "give"..i) then
								meta:set_int("ghost", 1)
								inv:add_item("main", inv:get_stack("pay"..i,1))
								inv:add_item("main", inv:get_stack("give"..i,1))
					      end
					   end
					end
					if type==1 and inv:contains_item("main", stack)==false then
					   minetest.chat_send_player(pname, "Error: "..smartshop.get_human_name(name).." is sold out.")
					   if not meta:get_int("alerted") or meta:get_int("alerted") == 0 then
					      meta:set_int("alerted",1) -- Do not alert twice
					      smartshop.send_mail(meta:get_string("owner"), pos, name, pname)
					   end
					   return
					end
					if not pinv:contains_item("main", pay) then minetest.chat_send_player(pname, "Error: You don't have enough in your inventory to buy this, exchange aborted.") return end
					if not pinv:room_for_item("main", stack) then minetest.chat_send_player(pname, "Error: Your inventory is full, exchange aborted.") return end
					if type == 0 then
						pinv:remove_item("main", pay)
						pinv:add_item("main", stack)
					else
						local item = inv:remove_item("main", stack)
						pinv:add_item("main", item)
						item = pinv:remove_item("main",pay)
						inv:add_item("main", item)
						if not inv:contains_item("main", stack)  and (not meta:get_int("alerted") or meta:get_int("alerted") == 0) then
						   meta:set_int("alerted",1) -- Do not alert twice
						   smartshop.send_mail(meta:get_string("owner"), pos, name, pname)
						end
					end
				end
			end
		else
			smartshop.update_info(pos)
			local meta = minetest.get_meta(pos)
			if meta:get_string("owner") == pname then
				smartshop.update(pos, "update")
			end
			smartshop.user[pname] = nil
		end
end

minetest.register_on_player_receive_fields(function(player, form, pressed)
	if form=="smartshop.showform" then
		smartshop.receive_fields(player,pressed)
	end
end)




smartshop.update_info=function(pos)
        if not pos then
	   return
        end
	local meta=minetest.get_meta(pos)
	local spos=minetest.pos_to_string(pos)
	local inv = meta:get_inventory()
	local owner=meta:get_string("owner")
	if meta:get_int("type")==0 then
		meta:set_string("infotext","(Smartshop by " .. owner ..") Stock is unlimited")
		return false
	end
	local name=""
	local count=0
	local stuff={}
	for i=1,4,1 do
		stuff["count" ..i]=inv:get_stack("give" .. i,1):get_count()
		stuff["name" ..i]=inv:get_stack("give" .. i,1):get_name()
		stuff["stock" ..i]=0 -- stuff["count" ..i]
		local mg_price = smartshop.minegeldtonumber(inv:get_stack("pay" .. i,1))
		if mg_price ~= nil then
		   stuff["pay"..i] = mg_price/stuff["count" ..i]
		end
		stuff["buy" ..i]=0
		for ii=1,32,1 do
			name=inv:get_stack("main",ii):get_name()
			count=inv:get_stack("main",ii):get_count()
			if name==stuff["name" ..i] then
				stuff["stock" ..i]=stuff["stock" ..i]+count
			end
		end
		local nstr=(stuff["stock" ..i]/stuff["count" ..i]) ..""
		nstr=nstr.split(nstr, ".")
		stuff["buy" ..i]=tonumber(nstr[1])
		if stuff["name" ..i]=="" or stuff["buy" ..i]==0 then
			stuff["buy" ..i]=""
			stuff["name" ..i]=""
			if smartshop.stuffsold[spos..i] then
			   smartshop.itemsatpos(spos, smartshop.stuffsold[spos..i], 0)
			   smartshop.itempriceatpos(spos, smartshop.stuffsold[spos..i], nil)
			   smartshop.stuffsold[spos..i] = nil
			end
		else
		   smartshop.itemsatpos(spos, stuff["name"..i], stuff["buy"..i]*stuff["count" ..i])
		   smartshop.itempriceatpos(spos, stuff["name"..i], stuff["pay"..i])
		   smartshop.stuffsold[spos..i] = stuff["name"..i]
		   stuff["name"..i] = smartshop.get_human_name(stuff["name"..i])
		   stuff["buy" ..i]="(" ..stuff["buy" ..i] ..") "
		   stuff["name" ..i]=stuff["name" ..i] .."\n"
		end
	end
		meta:set_string("infotext",
		"(Smartshop by " .. owner ..") Purchases left:\n"
		.. stuff.buy1 ..  stuff.name1
		.. stuff.buy2 ..  stuff.name2
		.. stuff.buy3 ..  stuff.name3
		.. stuff.buy4 ..  stuff.name4
		)
end




smartshop.update=function(pos,stat)
--clear
	local spos=minetest.pos_to_string(pos)
	for _, ob in ipairs(minetest.env:get_objects_inside_radius(pos, 2)) do
		if ob and ob:get_luaentity() and ob:get_luaentity().smartshop and ob:get_luaentity().pos==spos then
			ob:remove()
		end
	end
	if stat=="clear" then return end
--update
	local meta=minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local node=minetest.get_node(pos)
	local dp = smartshop.dir[node.param2+1]
	if not dp then return end
	pos.x = pos.x + dp.x*0.01
	pos.y = pos.y + dp.y*6.5/16
	pos.z = pos.z + dp.z*0.01
	for i=1,4,1 do
		local item=inv:get_stack("give" .. i,1):get_name()
		local pos2=smartshop.dpos[node.param2+1][i]
		if item~="" then
			smartshop.tmp.item=item
			smartshop.tmp.pos=spos
			local e = minetest.env:add_entity({x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z},"smartshop:item")
			e:setyaw(math.pi*2 - node.param2 * math.pi/2)
		end
	end
end


minetest.register_entity("smartshop:item",{
	hp_max = 1,
	visual="wielditem",
	visual_size={x=.20,y=.20},
	collisionbox = {0,0,0,0,0,0},
	physical=false,
	textures={"air"},
	smartshop=true,
	type="",
	on_activate = function(self, staticdata)
		if smartshop.tmp.item ~= nil then
			self.item=smartshop.tmp.item
			self.pos=smartshop.tmp.pos
			smartshop.tmp={}
		else
			if staticdata ~= nil and staticdata ~= "" then
				local data = staticdata:split(';')
				if data and data[1] and data[2] then
					self.item = data[1]
					self.pos = data[2]
				end
			end
		end
		if self.item ~= nil then
			self.object:set_properties({textures={self.item}})
		else
			self.object:remove()
		end
	end,
	get_staticdata = function(self)
		if self.item ~= nil and self.pos ~= nil then
			return self.item .. ';' ..  self.pos
		end
		return ""
	end,
})


smartshop.showform=function(pos,player,re)
	local meta=minetest.get_meta(pos)
	local creative=meta:get_int("creative")
	local inv = meta:get_inventory()
	local gui=""
	local spos=pos.x .. "," .. pos.y .. "," .. pos.z
	local owner=meta:get_string("owner")==player:get_player_name()
	if minetest.check_player_privs(player:get_player_name(), {protection_bypass=true}) then owner=true end
	if re then owner=false end
	smartshop.user[player:get_player_name()]=pos
	if owner then
	        meta:set_int("alerted",0) -- Player has been there to refill
		gui=""
		.."size[8,10]"
		.."button_exit[6,0;1.5,1;customer;Customer]"
		.."label[0,0.2;Item:]"
		.."label[0,1.2;Price:]"
		.."list[nodemeta:" .. spos .. ";give1;2,0;1,1;]"
		.."list[nodemeta:" .. spos .. ";pay1;2,1;1,1;]"
		.."list[nodemeta:" .. spos .. ";give2;3,0;1,1;]"
		.."list[nodemeta:" .. spos .. ";pay2;3,1;1,1;]"
		.."list[nodemeta:" .. spos .. ";give3;4,0;1,1;]"
		.."list[nodemeta:" .. spos .. ";pay3;4,1;1,1;]"
		.."list[nodemeta:" .. spos .. ";give4;5,0;1,1;]"
		.."list[nodemeta:" .. spos .. ";pay4;5,1;1,1;]"
		if creative==1 then
			gui=gui .."label[0.5,-0.4;Your stock is unlimited becaouse you have creative or give]"
			.."button[6,1;2.2,1;tooglelime;Toggle limit]"
		end
		gui=gui
		.."list[nodemeta:" .. spos .. ";main;0,2;8,4;]"
		.."list[current_player;main;0,6.2;8,4;]"
		.."listring[nodemeta:" .. spos .. ";main]"
		.."listring[current_player;main]"
	else
		gui=""
		.."size[8,6]"
		.."list[current_player;main;0,2.2;8,4;]"
		.."label[0,0.2;Item:]"
		.."label[0,1.2;Price:]"
		.."list[nodemeta:" .. spos .. ";give1;2,0;1,1;]"
		.."item_image_button[2,1;1,1;".. inv:get_stack("pay1",1):get_name() ..";buy1;\n\n\b\b\b\b\b" .. inv:get_stack("pay1",1):get_count() .."]"
		.."list[nodemeta:" .. spos .. ";give2;3,0;1,1;]"
		.."item_image_button[3,1;1,1;".. inv:get_stack("pay2",1):get_name() ..";buy2;\n\n\b\b\b\b\b" .. inv:get_stack("pay2",1):get_count() .."]"
		.."list[nodemeta:" .. spos .. ";give3;4,0;1,1;]"
		.."item_image_button[4,1;1,1;".. inv:get_stack("pay3",1):get_name() ..";buy3;\n\n\b\b\b\b\b" .. inv:get_stack("pay3",1):get_count() .."]"
		.."list[nodemeta:" .. spos .. ";give4;5,0;1,1;]"
		.."item_image_button[5,1;1,1;".. inv:get_stack("pay4",1):get_name() ..";buy4;\n\n\b\b\b\b\b" .. inv:get_stack("pay4",1):get_count() .."]"
	end
	minetest.after((0.1), function(gui)
		return minetest.show_formspec(player:get_player_name(), "smartshop.showform",gui)
	end, gui)
end

minetest.register_node("smartshop:shop", {
	description = "Smartshop",
	tiles = {"default_chest_top.png^[colorize:#ffffff77^default_obsidian_glass.png"},
	groups = {choppy = 2, oddly_breakable_by_hand = 1,tubedevice = 1, tubedevice_receiver = 1},
	drawtype="nodebox",
	node_box = {type="fixed",fixed={-0.5,-0.5,-0.0,0.5,0.5,0.5}},
	paramtype2="facedir",
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 10,
	tube = {insert_object = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			local added = inv:add_item("main", stack)
			smartshop.update_info(pos)
			return added
		end,
		can_insert = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			for i=1,4 do
			   local sellitem = inv:get_stack("give"..i,1):get_name()
			   if sellitem == stack:get_name() then
			      return inv:room_for_item("main", stack)
			   end
--			   minetest.chat_send_all(sellitem)
			end
			--
			return false
		end,
		input_inventory = "main",
		connect_sides = {left = 1, right = 1, front = 1, back = 1, top = 1, bottom = 1}},
after_place_node = function(pos, placer)
		local meta=minetest.get_meta(pos)
		meta:set_string("owner",placer:get_player_name())
		meta:set_string("infotext", "Shop by: " .. placer:get_player_name())
		meta:set_int("type",1)
		if is_creative(placer:get_player_name()) then
			meta:set_int("creative",1)
			meta:set_int("type",0)
		end
	end,
on_construct = function(pos)
		local meta=minetest.get_meta(pos)
		meta:set_int("state", 0)
		meta:get_inventory():set_size("main", 32)
		meta:get_inventory():set_size("give1", 1)
		meta:get_inventory():set_size("pay1", 1)
		meta:get_inventory():set_size("give2", 1)
		meta:get_inventory():set_size("pay2", 1)
		meta:get_inventory():set_size("give3", 1)
		meta:get_inventory():set_size("pay3", 1)
		meta:get_inventory():set_size("give4", 1)
		meta:get_inventory():set_size("pay4", 1)
		meta:set_int("ghost", 1)
	end,
on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		smartshop.showform(pos,player)
		smartshop.update(pos, "update")
	end,
allow_metadata_inventory_put = function(pos, listname, index, stack, player)
   if minetest.get_meta(pos):get_string("owner")==player:get_player_name() or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true}) then
      local meta = minetest.get_meta(pos)
      if meta:get_int("ghost") == 1 and (string.find(listname, "pay") or string.find(listname, "give")) then
	 local inv = minetest.get_inventory({type="node", pos=pos})
--	 minetest.chat_send_all( inv:get_stack(listname, index):get_name()..stack:get_name())
	 if inv:get_stack(listname, index):get_name() == stack:get_name() then
	    inv:add_item(listname, stack)
	 else
	    inv:set_stack(listname, index, stack)
	 end
	 return 0
      end
      return stack:get_count()
   end
   return 0
end,
allow_metadata_inventory_take = function(pos, listname, index, stack, player)
   if minetest.get_meta(pos):get_string("owner")==player:get_player_name() or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true}) then
      local meta = minetest.get_meta(pos)
      if meta:get_int("ghost") == 1 and (string.find(listname, "pay") or string.find(listname, "give")) then
	 local inv = minetest.get_inventory({type="node", pos=pos})
	 inv:set_stack(listname, index, ItemStack(""))
	 return 0
      end
      return stack:get_count()
   end
   return 0
end,
allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
   if minetest.get_meta(pos):get_string("owner")==player:get_player_name() or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true}) then
      local meta = minetest.get_meta(pos)
      local inv = minetest.get_inventory({type="node", pos=pos})
      if meta:get_int("ghost") ~= 1 then
	 return count
      end
      if (string.find(from_list, "pay") or string.find(from_list, "give")) and to_list == "main" then
	 inv:set_stack(from_list, from_index, ItemStack(""))
	 return 0
      elseif (string.find(to_list, "pay") or string.find(to_list, "give")) and from_list == "main" then
	 if inv:get_stack(to_list, to_index):get_name() == inv:get_stack(from_list, from_index):get_name() then
	    inv:add_item(to_list, inv:get_stack(from_list, from_index))
	 else
	    inv:set_stack(to_list, to_index, inv:get_stack(from_list, from_index))
	    inv:set_stack(from_list, from_index, inv:get_stack(from_list, from_index))
	 end
	 return 0
      else
	 return count
      end
   end
   return 0
end,
can_dig = function(pos, player)
		local meta=minetest.get_meta(pos)
		local inv=meta:get_inventory()
		if ((meta:get_string("owner")==player:get_player_name() or minetest.check_player_privs(player:get_player_name(), {protection_bypass=true})) and inv:is_empty("main") and inv:is_empty("pay1") and inv:is_empty("pay2") and inv:is_empty("pay3") and inv:is_empty("pay4") and inv:is_empty("give1") and inv:is_empty("give2") and inv:is_empty("give3") and inv:is_empty("give4")) or meta:get_string("owner")=="" then
			smartshop.update(pos,"clear")
			return true
		end
	end,
})

smartshop.get_item_count = function(name)
   sum = 0
   if smartshop.itemstats[name] == nil then
      return 0
   end
   for i, k in pairs(smartshop.itemstats[name]) do
      sum = sum + k
   end
   return sum
end

smartshop.get_shop_count = function(name)
   sum = 0
   if smartshop.itemstats[name] == nil then
      return 0
   end
   for i, k in pairs(smartshop.itemstats[name]) do
      sum = sum + 1
   end
   return sum
end

smartshop.get_item_price = function(name)
   sum = smartshop.get_item_count(name)
   if smartshop.itemprices[name] == nil then
      return 0
   end
   if sum == 0 then
      return 0
   end
   psum = 0
   for i, k in pairs(smartshop.itemprices[name]) do
      psum = psum + k*smartshop.itemstats[name][i]
   end
   return psum/sum
end


minetest.register_chatcommand("smstats", {
	description = "Get number of items sold",
	params = "<item_name>",
	func = function(plname, params)
		local name = params:match("(%S+)")
		if not (name) then
			return false, "Usage: /smstats <itemname>"
		end
		if not smartshop.itemstats[name] then
		   return false, "No stats on "..name
		end
		sum = smartshop.get_item_count(name)
		minetest.chat_send_player(plname, "Number of items: "..sum)
		minetest.chat_send_player(plname, "Number of shops offering item: "..smartshop.get_shop_count(name))
		if sum == 0 then
		   return
		end
		price = smartshop.get_item_price(name)
		minetest.chat_send_player(plname, "Average price: "..string.format("%.3f",price))
		return true
--		local ok, e = xban.ban_player(plname, name, nil, reason)
--		return ok, ok and ("Banned %s."):format(plname) or e
	end,
})

smartshop.report = function ()
   local file = io.open(minetest.get_worldpath().."/smartshop_report.txt", "w")
   if not file then
      return false, "could not write to file"
   end
   for i,k in pairs(smartshop.itemstats) do
      local count = smartshop.get_item_count(i)
      local price = smartshop.get_item_price(i)
      file:write(i.." "..count.." "..string.format("%.3f", price).." "..smartshop.get_shop_count(i).."\n")
   end
   file:close()
end

minetest.register_chatcommand("smreport", {
	description = "Get number of items sold",
	func = function(plname, params)
	   smartshop.report()
	end,
})

local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime;
	if timer >= 100 then
	   smartshop.report()
	   timer = 0
	end
end)


if false then -- This lbm is used to add pre-update smartshops to the price database. Activate with care! Warning: very slow.
   minetest.register_lbm({
	 name = "smartshop:update",
	 nodenames = {"smartshop:shop"},
	 action = function(pos, node)
	    smartshop.update_info(pos)
	 end,
   })
end


-- load itemstats
local file = io.open(minetest.get_worldpath().."/smartshop_itemcounts.txt", "r")
if file then
   local table = minetest.deserialize(file:read("*all"))
   if type(table) == "table" then
      smartshop.itemstats = table
   end
end
local file = io.open(minetest.get_worldpath().."/smartshop_itemprices.txt", "r")
if file then
   local table = minetest.deserialize(file:read("*all"))
   if type(table) == "table" then
      smartshop.itemprices = table
   end
end

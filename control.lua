entityRemoved={}entityCache={}guis={frames={},buttons={}}defaults={itemRotated={},ranks={{name='Owner',shortHand='Owner',tag='[Owner]',power=0,colour={r=170,g=0,b=0}},{name='Community Manager',shortHand='CM',tag='[Com Mngr]',power=1,colour={r=150,g=68,b=161}},{name='Developer',shortHand='Dev',tag='[Dev]',power=1,colour={r=179,g=125,b=46}},{name='Admin',shortHand='Admin',tag='[Admin]',power=2,colour={r=170,g=41,b=170}},{name='Mod',shortHand='Mod',tag='[Mod]',power=3,colour={r=233,g=63,b=233}},{name='Donator',shortHand='P2W',tag='[P2W]',power=4,colour={r=233,g=63,b=233}},{name='Member',shortHand='Mem',tag='[Member]',power=5,colour={r=24,g=172,b=188}},{name='Regular',shortHand='Reg',tag='[Regukar]',power=5,colour={r=24,g=172,b=188}},{name='Guest',shortHand='',tag='[Guest]',power=6,colour={r=255,g=159,b=27}},{name='Jail',shortHand='Jail',tag='[Jail]',power=7,colour={r=50,g=50,b=50}}},autoRanks={Owner={'badgamernl'},['Community Manager']={'arty714'},Developer={'Cooldude2606'},Admin={'eissturm','PropangasEddy'},Mod={'Alanore','Aquaday','cafeslacker','CrashKonijn','Drahc_pro','Flip','freek18','Hobbitkicker','hud','Matthias','MeDDish','Mindxt20','MottledPetrel','Mr_Happy_212','Phoenix27833','Sand3r205','ScarbVis','Smou','steentje77','TopHatGaming123'},Donator={},Member={},Regular={},Guest={},Jail={}},selected={},jail={}}warningAllowed=nil;timeForRegular=180;CHUNK_SIZE=32;function loadVar(a)if a==nil then local b=nil;if game.players[1].gui.left.hidden then b=game.players[1].gui.left.hidden.caption else b=game.players[1].gui.left.add{type='frame',name='hidden',caption=table.tostring(defaults)}.caption;game.players[1].gui.left.hidden.style.visible=false end;gTable=loadstring('return '..b)()else gTable=a end;itemRotated=gTable.itemRotated;ranks=gTable.ranks;autoRanks=gTable.autoRanks;selected=gTable.selected;jail=gTable.jail end;function saveVar()gTable.itemRotated=itemRotated;gTable.ranks=ranks;gTable.autoRanks=autoRanks;gTable.selected=selected;gTable.jail=jail;game.players[1].gui.left.hidden.caption=table.tostring(gTable)end;local function c(d,e)if d.find_entities_filtered{area=e,type="decorative"}then for f,g in pairs(d.find_entities_filtered{area=e,type="decorative"})do if g.name~="red-bottleneck"and g.name~="yellow-bottleneck"and g.name~="green-bottleneck"then g.destroy()end end end end;local function h(d,i,j,k,l)c(d,{{i,j},{i+k,j+l}})end;local function m()local d=game.surfaces["nauvis"]for n in d.get_chunks()do h(d,n.x*CHUNK_SIZE,n.y*CHUNK_SIZE,CHUNK_SIZE-1,CHUNK_SIZE-1)end;callRank("Decoratives have been removed")end;script.on_event(defines.events.on_chunk_generated,function(o)c(o.surface,o.area)end)function getRank(q)if q then for f,rank in pairs(ranks)do if q.tag==rank.tag then return rank end end;return stringToRank('Guest')end end;function stringToRank(string)if type(string)=='string'then local r={}for f,rank in pairs(ranks)do if rank.name:lower()==string:lower()then return rank end;if rank.name:lower():find(string:lower())then table.insert(r,rank)end end;if#r==1 then return r[1]end end end;function callRank(s,rank,t)local rank=stringToRank(rank)or stringToRank('Mod')local t=t or false;for f,q in pairs(game.players)do rankPower=getRank(q).power;if t then if rankPower>=rank.power then q.print(s)end else if rankPower<=rank.power then if rank.shortHand then q.print('['..rank.shortHand..']: '..s)else q.print('[Everyone]: '..s)end end end end end;function giveRank(q,rank,u)local u=u or'system'oldRank=getRank(q)local v='demoted'if rank.power<=oldRank.power then v='promoted'end;callRank(q.name..' was '..v..' to '..rank.name..' by '..u.name,oldRank.name)q.tag=rank.tag;drawToolbar(q)drawPlayerList()end;function autoRank(q)local w=getRank(q)local x=nil;for rank,y in pairs(autoRanks)do local z=false;for f,p in pairs(y)do if q.name==p then x=stringToRank(rank)z=true;break end end;if z then break end end;if x then if w.power>x.power then q.tag=x.tag end elseif ticktominutes(q.online_time)>=timeForRegular then q.tag=stringToRank('Regular').tag end;if getRank(q).power<=3 and not q.admin then callRank(q.name..' needs to be promoted.')end end;function jail(q,A)if q.character then if q.character.active then jail[q.index][1]=true;jail[q.index][2]=getRank(q).name;giveRank(q,'Jail',A)q.character.active=false else jail[q.index][1]=false;local rank=stringToRank(jail[q.index][2])or stringToRank('Guest')giveRank(q,rank,A)q.character.active=true end;saveVar()end end;function ticktohour(B)local C=tostring(math.floor(B/(216000*game.speed)))return C end;function ticktominutes(B)local D=math.floor(B/(3600*game.speed))return D end;function clearSelection(q)selected[q.index]={}end;function autoMessage()rank=stringToRank('Regular')hrank=stringToRank('Mod')callRank('There are '..#game.connected_players..' players online',hrank,true)callRank('This map has been on for '..ticktohour(game.tick)..' Hours and '..ticktominutes(game.tick)-60*ticktohour(game.tick)..' Minutes',hrank,true)callRank('Please join us on:',rank,true)callRank('Discord: https://discord.gg/RPCxzgt',rank,true)callRank('Forum: explosivegaming.nl',rank,true)callRank('Steam: http://steamcommunity.com/groups/tntexplosivegaming',rank,true)callRank('To see these links again goto: Readme > Server Info',rank,true)end;function table.val_to_str(E)if"string"==type(E)then E=string.gsub(E,"\n","\\n")if string.match(string.gsub(E,"[^'\"]",""),'^"+$')then return"'"..E.."'"end;return'"'..string.gsub(E,'"','\\"')..'"'else return"table"==type(E)and table.tostring(E)or tostring(E)end end;function table.key_to_str(F)if"string"==type(F)and string.match(F,"^[_%player][_%player%d]*$")then return F else return"["..table.val_to_str(F).."]"end end;function table.tostring(G)local H,I={},{}for F,E in ipairs(G)do table.insert(H,table.val_to_str(E))I[F]=true end;for F,E in pairs(G)do if not I[F]then table.insert(H,table.key_to_str(F).."="..table.val_to_str(E))end end;return"{"..table.concat(H,",").."}"end;function addFrame(J,rank,K,L,M)guis.frames[J]={{require=rank,caption=L,tooltip=M}}addButton('close',function(q,N)N.parent.parent.parent.destroy()end)addButton('btn_'..J,function(q,N)if q.gui.center[J]then q.gui.center[J].destroy()else drawFrame(q,J,K)end end)end;function addTab(J,O,P,Q)guis.frames[J][O]={O,P,Q}addButton(O,function(q,N)openTab(q,N.parent.parent.parent.name,N.parent.parent.parent.tab,N.name)end)end;function addButton(R,S)guis.buttons[R]={R,S}end;function drawButton(J,R,L,P)J.add{name=R,type="button",caption=L,tooltip=P}end;function openTab(q,T,U,O)local V=q.gui.center[T].tabBarScroll.tabBar;for f,a in pairs(guis.frames[T])do if f~=1 then if a[1]==O then V[a[1]].style.font_color={r=255,g=255,b=255,player=255}clearElement(U)a[3](q,U)else V[a[1]].style.font_color={r=100,g=100,b=100,player=255}end end end end;function drawFrame(q,T,O)if getRank(q).power<=guis.frames[T][1].require then if q.gui.center[T]then q.gui.center[T].destroy()end;local J=q.gui.center.add{name=T,type='frame',caption=T,direction='vertical'}local W=J.add{type="scroll-pane",name="tabBarScroll",vertical_scroll_policy="never",horizontal_scroll_policy="always"}local V=W.add{type='flow',direction='horizontal',name='tabBar'}local U=J.add{type="scroll-pane",name="tab",vertical_scroll_policy="auto",horizontal_scroll_policy="never"}for f,a in pairs(guis.frames[T])do if f~=1 then drawButton(V,a[1],a[1],a[2])end end;openTab(q,T,U,O)drawButton(V,'close','Close','Close this window')U.style.minimal_height=300;U.style.maximal_height=300;U.style.minimal_width=500;U.style.maximal_width=500;W.style.minimal_height=60;W.style.maximal_height=60;W.style.minimal_width=500;W.style.maximal_width=500 end end;function toggleVisable(J)if J then if J.style.visible==nil then J.style.visible=false else J.style.visible=not J.style.visible end end end;function clearElement(X)if X~=nil then for Y,N in pairs(X.children_names)do X[N].destroy()end end end;script.on_event(defines.events.on_player_created,function(o)local q=game.players[o.player_index]q.insert{name="iron-plate",count=8}q.insert{name="pistol",count=1}q.insert{name="firearm-magazine",count=10}q.insert{name="burner-mining-drill",count=1}q.insert{name="stone-furnace",count=1}q.force.chart(q.surface,{{q.position.x-200,q.position.y-200},{q.position.x+200,q.position.y+200}})end)script.on_event(defines.events.on_player_respawned,function(o)local q=game.players[o.player_index]drawPlayerList()q.insert{name="pistol",count=1}q.insert{name="firearm-magazine",count=10}end)script.on_event(defines.events.on_player_joined_game,function(o)loadVar()local q=game.players[o.player_index]autoRank(q)q.print({"","Welcome"})if q.gui.left.PlayerList~=nil then q.gui.left.PlayerList.destroy()end;if q.gui.center.README~=nil then q.gui.center.README.destroy()end;if q.gui.top.PlayerList~=nil then q.gui.top.PlayerList.destroy()end;drawPlayerList()drawToolbar(q)local Z=encode(game.players,"players",{"name","admin","online_time","connected","index"})game.write_file("players.json",Z,false,0)if not q.admin and ticktominutes(q.online_time)<1 then drawFrame(q,'Readme','Rules')end end)script.on_event(defines.events.on_player_left_game,function(o)local q=game.players[o.player_index]drawPlayerList()end)script.on_event(defines.events.on_gui_click,function(o)local q=game.players[o.player_index]if o.element.type=='button'then for f,_ in pairs(guis.buttons)do if _[1]==o.element.name then if _[2]then _[2](q,o.element)else callRank('Invaid Button'.._[1],'Mod')end;break end end elseif o.element.type=='checkbox'then if o.element.name=='select'then if not selected[o.player_index]then selected[o.player_index]={}end;if o.element.state then table.insert(selected[o.player_index],o.element.parent.name)else for f,a0 in pairs(selected[o.player_index])do if a0==o.element.parent.name then table.remove(selected[o.player_index],f)break end end end end;saveVar()end end)script.on_event(defines.events.on_gui_text_changed,function(o)local q=game.players[o.player_index]if o.element.parent.name=='filterTable'then local J=o.element;local a1={}local a2=false;local a3=false;if J.parent.parent.parent.name=='Admin'and not J.parent.sel_input then a2=true;a1[#a1+1]='online'end;if J.parent.parent.parent.name=='Admin'and J.parent.sel_input then a3=true;a1[#a1+1]='lower'end;if J.parent.parent.filterTable.status_input and not a2 then local a4=J.parent.parent.filterTable.status_input.text;if a4=='yes'or a4=='online'or a4=='true'or a4=='y'then a1[#a1+1]='online'elseif a4~=''then a1[#a1+1]='offline'end end;if J.parent.parent.filterTable.hours_input then local a5=J.parent.parent.filterTable.hours_input.text;if tonumber(a5)and tonumber(a5)>0 then a1[#a1+1]=tonumber(a5)end end;if J.parent.parent.filterTable.name_input then local a6=J.parent.parent.filterTable.name_input.text;if a6 then a1[#a1+1]=a6 end end;if J.parent.parent.filterTable.sel_input then local a7=J.parent.parent.filterTable.sel_input.text;if a7=='yes'or a7=='online'or a7=='true'or a7=='y'then a1[#a1+1]='selected'end end;if J.parent.parent.playerTable then J.parent.parent.playerTable.destroy()end;drawPlayerTable(q,J.parent.parent,a2,a3,a1)end end)script.on_event(defines.events.on_marked_for_deconstruction,function(o)local a8=game.players[o.player_index]if not a8.admin and ticktominutes(a8.online_time)<timeForRegular then if o.entity.type~="tree"and o.entity.type~="simple-entity"then o.entity.cancel_deconstruction("player")a8.print("You are not allowed to do this yet, play for player bit longer. Try again in about: "..math.floor(timeForRegular-ticktominutes(a8.online_time)).." minutes")callRank(a8.name.." tryed to deconstruced something")end elseif o.entity.type=="tree"or o.entity.type=="simple-entity"then o.entity.destroy()end end)script.on_event(defines.events.on_built_entity,function(o)local a8=game.players[o.player_index]local timeForRegular=120;if not a8.admin and ticktominutes(a8.online_time)<timeForRegular then if o.created_entity.type=="tile-ghost"then o.created_entity.destroy()a8.print("You are not allowed to do this yet, play for player bit longer. Try: "..math.floor(timeForRegular-ticktominutes(a8.online_time)).." minutes")callRank(a8.name.." tryed to place concrete/stone with robots")end end end)script.on_event(defines.events.on_rocket_launched,function(o)local a9=o.rocket.force;if o.rocket.get_item_count("satellite")==0 then if#game.players<=1 then game.show_message_dialog{text={"gui-rocket-silo.rocket-launched-without-satellite"}}else for aa,q in pairs(a9.players)do q.print({"gui-rocket-silo.rocket-launched-without-satellite"})end end;return end;if not global.satellite_sent then global.satellite_sent={}end;if global.satellite_sent[a9.name]then global.satellite_sent[a9.name]=global.satellite_sent[a9.name]+1 else game.set_game_state{game_finished=true,player_won=true,can_continue=true}global.satellite_sent[a9.name]=1 end;for aa,q in pairs(a9.players)do if q.gui.left.rocket_score then q.gui.left.rocket_score.rocket_count.caption=tostring(global.satellite_sent[a9.name])else local J=q.gui.left.add{name="rocket_score",type="frame",direction="horizontal",caption={"score"}}J.add{name="rocket_count_label",type="label",caption={"",{"rockets-sent"},":"}}J.add{name="rocket_count",type="label",caption=tostring(global.satellite_sent[a9.name])}end end end)script.on_event(defines.events.on_tick,function(o)if game.tick/(3600*game.speed)%15==0 then autoMessage()end end)function encode(table,a0,ab)local ac;local ad;local ae;for Y,af in pairs(table)do ae=nil;for Y,ag in pairs(ab)do if type(af[ag])=="string"then if ae~=nil then ae=ae..",\""..ag.."\": \""..af[ag].."\""else ae="\""..ag.."\": \""..af[ag].."\""end elseif type(af[ag])=="number"then if ae~=nil then ae=ae..",\""..ag.."\": "..tostring(af[ag])else ae="\""..ag.."\": "..tostring(af[ag])end elseif type(af[ag])=="boolean"then if ae~=nil then ae=ae..",\""..ag.."\": "..tostring(af[ag])else ae="\""..ag.."\": "..tostring(af[ag])end end end;if ae~=nil and ad~=nil then ad=ad..", {"..ae.."}"else ad="{"..ae.."}"end end;ac="{".."\""..a0 .."\": ["..ad.."]}"return ac end;addButton("btn_toolbar_playerList",function(q)toggleVisable(q.gui.left.PlayerList)end)addButton("btn_toolbar_rocket_score",function(q)toggleVisable(q.gui.left.rocket_score)end)function drawToolbar(q)local J=q.gui.top;clearElement(J)drawButton(J,"btn_toolbar_playerList","Playerlist","Adds player player list to your game.")drawButton(J,"btn_toolbar_rocket_score","Rocket score","Show the satellite launched counter if player satellite has launched.")for f,ah in pairs(guis.frames)do if getRank(q).power<=ah[1].require then drawButton(J,"btn_"..f,ah[1].caption,ah[1].tooltip)end end end;function drawPlayerList()for Y,q in pairs(game.connected_players)do if q.gui.left.PlayerList==nil then q.gui.left.add{type="frame",name="PlayerList",direction="vertical"}.add{type="scroll-pane",name="PlayerListScroll",direction="vertical",vertical_scroll_policy="always",horizontal_scroll_policy="never"}end;Plist=q.gui.left.PlayerList.PlayerListScroll;clearElement(Plist)Plist.style.maximal_height=200;for Y,q in pairs(game.connected_players)do if q.character then if q.tag=='[Jail]'or q.character.active==false then q.character.active=false;q.tag='[Jail]'end end;playerRank=getRank(q)if playerRank.power<=3 then if playerRank.shortHand~=''then Plist.add{type="label",name=q.name,style="caption_label_style",caption={"",ticktohour(q.online_time)," H - ",q.name,' - '..playerRank.shortHand}}else Plist.add{type="label",name=q.name,style="caption_label_style",caption={"",ticktohour(q.online_time)," H - ",q.name}}end;Plist[q.name].style.font_color=playerRank.colour;q.tag=playerRank.tag end end;for Y,q in pairs(game.connected_players)do playerRank=getRank(q)if playerRank.power>3 then if playerRank.shortHand~=''then Plist.add{type="label",name=q.name,style="caption_label_style",caption={"",ticktohour(q.online_time)," H - ",q.name,' - '..playerRank.shortHand}}else Plist.add{type="label",name=q.name,style="caption_label_style",caption={"",ticktohour(q.online_time)," H - ",q.name}}end;Plist[q.name].style.font_color=playerRank.colour;q.tag=playerRank.tag end end end end;addButton('goto',function(q,J)local p=game.players[J.parent.name]q.teleport(game.surfaces[p.surface.name].find_non_colliding_position("player",p.position,32,1))end)addButton('bring',function(q,J)local p=game.players[J.parent.name]p.teleport(game.surfaces[q.surface.name].find_non_colliding_position("player",q.position,32,1))end)addButton('jail',function(q,J)local p=game.players[J.parent.name]if p.character then if p.character.active then p.character.active=false;p.tag='[Jail]'drawPlayerList()else p.character.active=true;p.tag='[Guest]'drawPlayerList()end end end)addButton('kill',function(q,J)local p=game.players[J.parent.name]if p.character then p.character.die()end end)function drawPlayerTable(q,J,a2,a3,a1)if J.playerTable then J.playerTable.destroy()end;J.add{name='playerTable',type="table",colspan=5}J.playerTable.style.minimal_width=500;J.playerTable.style.maximal_width=500;J.playerTable.style.horizontal_spacing=10;J.playerTable.add{name="id",type="label",caption="Id		"}J.playerTable.add{name="name",type="label",caption="Name		"}if a2==false and a3==false then J.playerTable.add{name="status",type="label",caption="Status		"}end;J.playerTable.add{name="online_time",type="label",caption="Online Time	"}J.playerTable.add{name="rank",type="label",caption="Rank	"}if a2 then J.playerTable.add{name="commands",type="label",caption="Commands"}end;if a3 then J.playerTable.add{name="select_label",type="label",caption="Selection"}end;for Y,p in pairs(game.players)do local ai=true;for f,aj in pairs(a1)do if aj=='admin'then if p.admin==false then ai=false;break end elseif aj=='online'then if p.connected==false then ai=false;break end elseif aj=='offline'then if p.connected==true then ai=false;break end elseif aj=='lower'then if getRank(p).power<=getRank(q).power then ai=false;break end elseif aj=='selected'then local z=nil;for f,a0 in pairs(selected[q.index])do if a0==p.name then z=true;break end end;if not z then ai=false;break end elseif type(aj)=='number'then if aj>ticktominutes(p.online_time)then ai=false;break end elseif type(aj)=='string'then if p.name:lower():find(aj:lower())==nil then ai=false;break end end end;if ai==true and q.name~=p.name then if J.playerTable[p.name]==nil then J.playerTable.add{name=Y.."id",type="label",caption=Y}J.playerTable.add{name=p.name..'_name',type="label",caption=p.name}if not a2 and not a3 then if p.connected==true then J.playerTable.add{name=p.name.."Status",type="label",caption="ONLINE"}else J.playerTable.add{name=p.name.."Status",type="label",caption="OFFLINE"}end end;J.playerTable.add{name=p.name.."Online_Time",type="label",caption=ticktohour(p.online_time)..'H '..ticktominutes(p.online_time)-60*ticktohour(p.online_time)..'M'}J.playerTable.add{name=p.name.."Rank",type="label",caption=p.tag}if a2 then J.playerTable.add{name=p.name,type="flow"}drawButton(J.playerTable[p.name],'goto','Tp','Goto to the players location')drawButton(J.playerTable[p.name],'bring','Br','Bring player player to your location')if getRank(p).power>getRank(q).power then drawButton(J.playerTable[p.name],'jail','Ja','Jail/Unjail player player')drawButton(J.playerTable[p.name],'kill','Ki','Kill this player')end elseif a3 then J.playerTable.add{name=p.name,type="flow"}local ak=false;for f,a0 in pairs(selected[q.index])do if a0==p.name then ak=true;break end end;J.playerTable[p.name].add{name='select',type="checkbox",state=ak}end end end end end;addFrame('Readme',6,'Rules','Readme','Rules, Server info, How to chat, Playerlist, Adminlist.')addTab('Readme','Rules','The rules of the server',function(q,J)local al={"Hacking/cheating, exploiting and abusing bugs is not allowed.","Do not disrespect any player in the server (This includes staff).","Do not spam, this includes stuff such as chat spam, item spam, chest spam etc.","Do not laydown concrete with bots without permission.","Do not use active provider chests without permission.","Do not remove/move major parts of the factory without permission.","Do not walk in player random direction for no reason(to save map size).","Do not remove stuff just because you don't like it, tell people first.","Do not make train roundabouts.","Trains are Left Hand Drive (LHD) only.","Do not complain about lag, low fps and low ups or other things like that.","Do not ask for rank.","Use common sense and what an admin says goes."}for Y,am in pairs(al)do J.add{name=Y,type="label",caption={"",Y,". ",am}}end end)addTab('Readme','Server Info','Info about the server',function(q,J)J.add{name=1,type="label",caption={"","Discord voice and chat server:"}}J.add{name=2,type='textfield',text='https://discord.gg/RPCxzgt'}.style.minimal_width=400;J.add{name=3,type="label",caption={"","Our forum:"}}J.add{name=4,type='textfield',text='https://explosivegaming.nl'}.style.minimal_width=400;J.add{name=5,type="label",caption={"","Steam:"}}J.add{name=6,type='textfield',text='http://steamcommunity.com/groups/tntexplosivegaming'}.style.minimal_width=400 end)addTab('Readme','How to chat','Just in case you dont know how to chat',function(q,J)local an={"Chatting for new players can be difficult because it’s different than other games!","It’s very simple, the button you need to press is the “GRAVE/TILDE key”","it’s located under the “ESC key”. If you would like to change the key go to your","controls tab in options. The key you need to change is “Toggle Lua console”","it’s located in the second column 2nd from bottom."}for Y,ao in pairs(an)do J.add{name=Y,type="label",caption={"",ao}}end end)addTab('Readme','Admins','List of all the people who can ban you :P',function(q,J)local ap={"This list contains all the people that are admin in this world. Do you want to become","an admin dont ask for it! an admin will see what you've made and the time you put","in the server."}for Y,ao in pairs(ap)do J.add{name=Y,type="label",caption={"",ao}}end;drawPlayerTable(q,J,false,false,{'admin'})end)addTab('Readme','Players','List of all the people who have been on the server',function(q,J)local y={"These are the players who have supported us in the making of this factory. Without","you the player we wouldn't have been as far as we are now."}for Y,ao in pairs(y)do J.add{name=Y,type="label",caption={"",ao}}end;J.add{name='filterTable',type='table',colspan=3}J.filterTable.add{name='name_label',type='label',caption='Name'}J.filterTable.add{name='status_label',type='label',caption='Online?'}J.filterTable.add{name='hours_label',type='label',caption='Online Time (minutes)'}J.filterTable.add{name='name_input',type='textfield'}J.filterTable.add{name='status_input',type='textfield'}J.filterTable.add{name='hours_input',type='textfield'}drawPlayerTable(q,J,false,false,{})end)addFrame('Admin',2,'Player List','Admin',"All admin fuctions are here")addButton('btn_toolbar_automessage',function()autoMessage()end)addButton('tp_all',function(q,J)for Y,p in pairs(game.connected_players)do local aq=game.surfaces[q.surface.name].find_non_colliding_position("player",q.position,32,1)if p~=q then p.teleport(aq)end end end)addButton('revive_dead_entitys_range',function(q,J)if tonumber(J.parent.range.text)then local ar=tonumber(J.parent.range.text)for as,g in pairs(game.surfaces[1].find_entities_filtered({area={{q.position.x-ar,q.position.y-ar},{q.position.x+ar,q.position.y+ar}},type="entity-ghost"}))do g.revive()end end end)addButton('add_dev_items',function(q,J)q.insert{name="deconstruction-planner",count=1}q.insert{name="blueprint-book",count=1}q.insert{name="blueprint",count=20}end)addButton('sendMessage',function(q,J)local rank=stringToRank(J.parent.message.rank.text)if rank then callRank(J.parent.message.message.text,rank.name)else for f,rank in pairs(ranks)do q.print(rank.name)end end end)addButton('setRanks',function(q,J)rank=stringToRank(J.parent.rank_input.text)if rank then for f,at in pairs(selected[q.index])do p=game.players[at]if getRank(q).power<getRank(p).power and rank.power>getRank(q).power then giveRank(p,rank,q)else q.print('You can not edit '..p.name.."'s rank there rank is too high (or the rank you have slected is above you)")end end else q.print(J.parent.rank_input.text..' is not a Rank, Ranks are:')for f,rank in pairs(ranks)do if rank.power>getRank(q).power then q.print(rank.name)end end end end)addButton('clearSelection',function(q,J)clearSelection(q)drawPlayerTable(q,J.parent.parent,false,true,{})end)addTab('Admin','Commands','Random useful commands',function(q,J)drawButton(J,'btn_toolbar_automessage','Auto Message','Send the auto message to all online players')drawButton(J,'add_dev_items','Get Blueprints','Get all the blueprints')drawButton(J,'revive_dead_entitys_range','Revive Entitys','Brings all dead machines back to life in player range')J.add{type='textfield',name='range',text='Range'}J.add{type='flow',name='message'}J.message.add{type='textfield',name='message',text='Enter message'}J.message.add{type='textfield',name='rank',text='Enter rank'}drawButton(J,'sendMessage','Send Message','Send a message to all ranks higher than the slected')drawButton(J,'tp_all','TP All Here','Brings all players to you')end)addTab('Admin','Edit Ranks','Edit the ranks of players below you',function(q,J)clearSelection(q)J.add{name='filterTable',type='table',colspan=2}J.filterTable.add{name='name_label',type='label',caption='Name'}J.filterTable.add{name='sel_label',type='label',caption='Selected?'}J.filterTable.add{name='name_input',type='textfield'}J.filterTable.add{name='sel_input',type='textfield'}J.add{type='flow',name='rank',direction='horizontal'}J.rank.add{name='rank_label',type='label',caption='Rank'}J.rank.add{name='rank_input',type='textfield'}drawButton(J.rank,'setRanks','Set Ranks','Sets the rank of all selected players')drawButton(J.rank,'clearSelection','Clear Selection','Clears all currently selected players')drawPlayerTable(q,J,false,true,{'lower'})end)addTab('Admin','Player List','Send player message to all players',function(q,J)J.add{name='filterTable',type='table',colspan=2}J.filterTable.add{name='name_label',type='label',caption='Name'}J.filterTable.add{name='hours_label',type='label',caption='Online Time (minutes)'}J.filterTable.add{name='name_input',type='textfield'}J.filterTable.add{name='hours_input',type='textfield'}drawPlayerTable(q,J,true,false,{'online'})end)addFrame('Admin+',1,'Modifiers','Admin+',"Because we are better")addButton('remove_biters',function(q,J)for as,g in pairs(game.surfaces[1].find_entities_filtered({force='enemy'}))do g.destroy()end end)addButton('toggle_cheat',function(q,J)q.cheat_mode=not q.cheat_mode end)addButton('revive_dead_entitys',function(q,J)for as,g in pairs(game.surfaces[1].find_entities_filtered({type="entity-ghost"}))do g.revive()end end)addButton("btn_Modifier_apply",function(q,J)local au={"manual_mining_speed_modifier","manual_crafting_speed_modifier","character_running_speed_modifier","worker_robots_speed_modifier","worker_robots_storage_bonus","character_build_distance_bonus","character_item_drop_distance_bonus","character_reach_distance_bonus","character_resource_reach_distance_bonus","character_item_pickup_distance_bonus","character_loot_pickup_distance_bonus"}for Y,av in pairs(au)do local aw=tonumber(J.parent.parent.modifierTable[av.."_input"].text:match("[%d]+[.%d+]"))if aw~=nil then if aw>=0 and aw<50 and aw~=q.force[av]then q.force[av]=aw;q.print(av.." changed to number: "..tostring(aw))elseif aw==q.force[av]then q.print(av.." Did not change")else q.print(av.." needs to be player higher number or it contains an letter")end end end end)addTab('Admin+','Commands','Random useful commands',function(q,J)drawButton(J,'btn_toolbar_automessage','Auto Message','Send the auto message to all online players')drawButton(J,'add_dev_items','Get Blueprints','Get all the blueprints')drawButton(J,'revive_dead_entitys','Revive All Entitys','Brings all dead machines back to life')drawButton(J,'revive_dead_entitys_range','Revive Entitys','Brings all dead machines back to life in player range')J.add{type='textfield',name='range',text='Range'}drawButton(J,'remove_biters','Kill Biters','Removes all biters in map')drawButton(J,'tp_all','TP All Here','Brings all players to you')drawButton(J,'toggle_cheat','Toggle Cheat Mode','Toggle your cheat mode')end)addTab('Admin+','Modifiers','Edit in game modifiers',function(q,J)local au={"manual_mining_speed_modifier","manual_crafting_speed_modifier","character_running_speed_modifier","worker_robots_speed_modifier","worker_robots_storage_bonus","character_build_distance_bonus","character_item_drop_distance_bonus","character_reach_distance_bonus","character_resource_reach_distance_bonus","character_item_pickup_distance_bonus","character_loot_pickup_distance_bonus"}J.add{type="flow",name="flowNavigation",direction="horizontal"}J.add{name="modifierTable",type="table",colspan=3}J.modifierTable.add{name="name",type="label",caption="name"}J.modifierTable.add{name="input",type="label",caption="input"}J.modifierTable.add{name="current",type="label",caption="current"}for Y,av in pairs(au)do J.modifierTable.add{name=av,type="label",caption=av}J.modifierTable.add{name=av.."_input",type="textfield",caption="inputTextField"}J.modifierTable.add{name=av.."_current",type="label",caption=tostring(q.force[av])}end;drawButton(J.flowNavigation,"btn_Modifier_apply","Apply","Apply the new values to the game")end)
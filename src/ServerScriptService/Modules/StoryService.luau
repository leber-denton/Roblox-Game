-- Juniper's milestone story. Encounters are earned on the server, found in the world,
-- and completed by winning their real trainer battle. Random drop-in visits are retired.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local GameData = require(ReplicatedStorage.Shared.GameData)
local SaveService = require(script.Parent.SaveService)
local BattleService = require(script.Parent.BattleService)
local TutorialService = require(script.Parent.TutorialService)
local PlayerData = require(script.Parent.PlayerData)
local BaseManager = require(script.Parent.BaseManager)
local NPC = require(script.Parent.NPC)
local StoryRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Story")
local Notify = ReplicatedStorage.Remotes:WaitForChild("Notify")
local StoryService = {}
local state, targets = {}, {}
local NAME, REVEAL = "Juniper", "Juniper  ★  Team Havoc"
local function count(player) return player:GetAttribute("Badges") or 0 end
local function atBadge(n) return function(player) return count(player) >= n end end
local SCENES = {
 { id="intro", title="A flicker at the Healing Center", objective="Heal at Nurse Ivy's Healing Center.", lines={
  "I'm Juniper. Professor Maple is my dad. He's told me all about you, %s. Well... he will.",
  "Keep your creatures close. I need you strong. Really strong.",
  "Huh. The lights never used to flicker here. Look in your Journey's Story tab. We'll meet again." } },
 { id="pier", title="Trouble at Tide Coast", objective="Find Juniper at the Tide Coast pier.", ready=atBadge(2), battle={name="Havoc Grunt Nyx",team={{"Nightfang",19},{"Echoling",20},{"Shadeshroom",21}}}, lines={
  "Those Havoc grunts have blocked the pier. Let's move them out of the way together.",
  {speaker="Havoc Grunt Nyx",text="The crystal shipment belongs to Havoc. No witnesses!"},
  "I'll handle the other guard. You take this one. Watch the sky when we're done." } },
 { id="crystal", title="The stolen crystal", objective="Retrieve the crystal beside Ember Ridge's volcano.", ready=atBadge(4), item="GaleCrystal", lines={
  "The volcano grows crystals that remember the wind. Could you bring me that one?",
  {speaker="Havoc Grunt Nyx",text="Shipment secured! The commander will be pleased."},
  "They took the core! Here, you can keep this Gale Crystal fragment. We'll catch them later... I promise." } },
 { id="journal", title="Notes from tomorrow", objective="Reach the Dark Tower's last room and read Juniper's notes.", ready=function(player) return (player:GetAttribute("Stat_towerBest") or 0)>=10 or (player:GetAttribute("DungeonFloor") or 1)>=11 end, actor=false,item="JuniperJournal", lines={
  {speaker="Juniper's Journal",text="Day 714: If Father remembers me, the timeline will collapse. He must believe I am a stranger."},
  {speaker="Juniper's Journal",text="Havoc follows my orders. But is the future fixed? One trainer keeps changing the numbers."},
  {speaker="Shadow Warden's echo",text="Juniper told me you would come. Take her notes. Ask your Professor who she is."} } },
 { id="lab", title="The daughter he forgot", objective="Return to Professor Maple's lab after earning six badges.",ready=atBadge(6),lines={
  {speaker="Professor Maple",text="My daughter? I don't have a daughter. I've never met this girl in my life."},
  "Dad, please. You remember the garden, the— [signal lost] —no, it hasn't happened yet.",
  {speaker="Professor Maple",text="That flicker wasn't a trick. Her signal is coming from another time. Watch for Havoc on the routes."} } },
 { id="reveal",title="Commander of tomorrow",objective="Meet Juniper at "..GameData.VictoryRoads.League.." before the League.",ready=atBadge(8),battle={name=REVEAL,team={{"Nightfang",56},{"Phantorb",57},{"Stormane",58},{"Skydrake",59}}},lines={
  "Eight badges. The team I needed. Now you deserve the truth.",
  {speaker=REVEAL,text="In my future, Havoc rules everything. I built it. I came back to make sure it happens."},
  {speaker=REVEAL,text="You can still change sides, %s. Or show me what your creatures believe in."} } },
 { id="champion",title="Beyond the mountains",objective="Become Champion, then watch the way to "..GameData.Region2.name.." open.",ready=function(player) return (player:GetAttribute("Stat_leagueWins") or 0)>0 end,automatic=true,lines={
  {speaker=REVEAL,text="Champion %s. Enjoy your moment. My blimp has already crossed the mountains."},
  {speaker="Professor Maple",text="The pass is open. Beyond it lies "..GameData.Region2.region.." and Summit Town. Follow the east road from the Hub."},
  {speaker=REVEAL,text="Three bases. One future. See if you can change it."} } },
 { id="base1",title="Havoc base: Coral Relay",objective="Clear the Havoc relay in Coral Reef after badge ten.",ready=atBadge(10),item="HavocLens",battle={name="Havoc Captain Sable",team={{"Nightfang",80},{"Phantorb",81},{"Tidecrest",82},{"Stormane",82}}},lines={
  {speaker="Havoc Captain Sable",text="This relay anchors the commander's future. You'll never disconnect it."},
  {speaker=REVEAL,text="Careful, %s. Pull one thread and the whole future might unravel."} } },
 { id="base2",title="Havoc base: Bog Reactor",objective="Shut down the Havoc reactor in Toxic Bog after badge twelve.",ready=atBadge(12),item="CrystalAnchor",battle={name="Havoc Captain Vex",team={{"Shadeshroom",88},{"Thornwarden",89},{"Phantorb",90},{"Glaciorn",90}}},lines={
  {speaker="Havoc Captain Vex",text="The bog powers our time engine. The commander cannot fail!"},
  {speaker=REVEAL,text="You keep choosing a future I can't predict. Stop."} } },
 { id="base3",title="Havoc base: Phantom Archive",objective="Destroy the Havoc archive in Phantom Manor after badge fourteen.",ready=atBadge(14),item="TimeClover",battle={name="Havoc Captain Epoch",team={{"Phantorb",96},{"Nightfang",97},{"Skydrake",98},{"Thornwarden",98}}},lines={
  {speaker="Havoc Captain Epoch",text="Every possible future is stored here. In every one, Havoc wins."},
  {speaker=REVEAL,text="Except this one. You weren't in the archive, %s. Meet me at the Summit League."} } },
 { id="final",title="Break the Havoc future",objective="Defeat Juniper before the Summit Champion.",ready=atBadge(16),battle={name=REVEAL,team={{"Phantorb",100,2},{"Stormane",100,2},{"Glaciorn",100,2},{"Thornwarden",100,2},{"Tidecrest",100,3},{"Skydrake",100,3}}},lines={
  {speaker=REVEAL,text="No relay. No reactor. No archive. Only us, and one last future."},
  {speaker=REVEAL,text="These creatures were all I could save. If you win, look after the little one that followed me here."},
  {speaker=REVEAL,text="Show me a future that doesn't need Team Havoc."} } },
}
local byId={}
for _,s in SCENES do byId[s.id]=s end
local function get(player)
 if not state[player] then state[player]={seen={},completed={}} end
 return state[player]
end
local function nextScene(player)
 local s=get(player)
 for _,scene in SCENES do if not s.completed[scene.id] then return scene end end
 return nil
end
local function sync(player)
 local s=get(player)
 local next=nextScene(player)
 player:SetAttribute("MetJuniper",s.completed.intro==true)
 player:SetAttribute("HavocBlimpVisible",s.completed.pier==true)
 player:SetAttribute("HavocBlimpEast",s.completed.reveal==true)
 player:SetAttribute("HavocRoutesActive",s.completed.lab==true and not s.completed.final)
 player:SetAttribute("HavocBreaker",s.completed.final==true)
 if s.completed.final then player:SetAttribute("StoryTitle","Havoc Breaker") end
 player:SetAttribute("StoryNext",next and next.id or "complete")
 player:SetAttribute("StoryObjective",next and next.objective or "Havoc's future is broken. Explore, collect and defend your title!")
 player:SetAttribute("StoryChapter",next and next.title or "Havoc Breaker")
 player:SetAttribute("StoryReady",next and ((next.id=="intro" and s.pendingIntro) or (next.ready and next.ready(player)))==true or false)
 player:SetAttribute("StoryTarget",next and targets[next.id] and targets[next.id].Position or nil)
 player:SetAttribute("JournalUnlocked",s.completed.journal==true)
 local list={}
 for _,sc in SCENES do table.insert(list,{id=sc.id,title=sc.title,done=s.completed[sc.id]==true}) end
 player:SetAttribute("StoryMilestones",HttpService:JSONEncode(list))
end
local function linesFor(player,scene)
 local out={}
 for _,line in scene.lines do
  local speaker,text=NAME,line
  if typeof(line)=="table" then speaker,text=line.speaker,line.text end
  text=text:gsub("%%s",function() return player.DisplayName end)
  table.insert(out,{speaker=speaker,text=text})
 end
 return out
end
local function free(player)
 return player.Parent and not BattleService.isInBattle(player) and not player:GetAttribute("InCutscene") and not player:GetAttribute("Elevating")
end
local function complete(player,scene)
 local s=get(player)
 if s.completed[scene.id] then return end
 s.completed[scene.id]=true;s.seen[scene.id]=true
 if scene.item then PlayerData.addItem(player,scene.item,1) end
 if scene.id=="final" then
  BaseManager.addCreature(player,BaseManager.newRecord("Chronowisp",100),{force=true})
  Notify:FireAllClients(("%s defeated Juniper and became a Havoc Breaker!"):format(player.DisplayName),"announce")
  Notify:FireClient(player,"Havoc's future is broken! Title unlocked: Havoc Breaker. Chronowisp joined your team.","success")
 elseif scene.id=="reveal" then
  Notify:FireAllClients(("%s defeated Commander Juniper! The Havoc blimp is escaping east."):format(player.DisplayName),"announce")
 elseif scene.item then
  local def=GameData.Items[scene.item]
  Notify:FireClient(player,"Story reward: "..(def and def.name or scene.item),"success")
 end
 sync(player);SaveService.requestSave(player)
end
local function begin(player,scene)
 local s=get(player)
 if s.playing or not free(player) or nextScene(player)~=scene then return false end
 if scene.id~="intro" and player:GetAttribute("TutorialStep")~="done" then return false end
 if scene.ready and not scene.ready(player) then return false end
 s.playing=scene.id;s.started=os.clock()
 StoryRemote:FireClient(player,"scene",{id=scene.id,lines=linesFor(player,scene),final=scene.id=="reveal" or scene.id=="final",actor=scene.actor~=false,chapter=scene.title,tour=scene.id=="champion",battle=scene.battle~=nil})
 task.delay(180,function()
  if state[player]==s and s.playing==scene.id then s.playing=nil;sync(player) end
 end)
 return true
end
local function check(player)
 if not player.Parent then return end
 local s=get(player);sync(player)
 if s.playing or not free(player) then return end
 local scene=nextScene(player)
 if not scene then return end
 if scene.id=="intro" then
  local step=player:GetAttribute("TutorialStep")
  if s.pendingIntro and (step=="done" or TutorialService.isGuideStep(step)) then begin(player,scene) end
 elseif scene.automatic and scene.ready(player) then begin(player,scene) end
end
StoryService.check=check
function StoryService.chat() return false end -- retained for old admin integrations; no random visits
function StoryService.onHeal(player)
 local s=get(player)
 if not s.completed.intro then s.pendingIntro=true;task.delay(1.5,check,player) end
end
function StoryService.onLoaded(player)
 local s=get(player)
 if s.guide and TutorialService.isGuideStep(s.guide) and #BaseManager.getTeam(player)>0 then TutorialService.resumeGuide(player,s.guide) end
 for _,attr in {"Badges","Stat_towerBest","DungeonFloor","TutorialStep","InBattle","InCutscene","Stat_leagueWins"} do
  player:GetAttributeChangedSignal(attr):Connect(function() task.delay(3,check,player) end)
 end
 sync(player);task.delay(10,check,player)
end
function StoryService.hasCompleted(player,id) return get(player).completed[id]==true end
function StoryService.requestMilestone(player,id)
 local scene=byId[id]
 if not scene then return false end
 local next=nextScene(player)
 if next~=scene then
  Notify:FireClient(player,"Story: "..(next and next.objective or "Your story is complete."),"info")
  return false
 end
 return begin(player,scene)
end
-- Markers are attached to actual map surfaces so map rearrangements keep story events reachable.
local function laneSpot(key,side,depth)
 local lane=workspace.Map.Lanes:FindFirstChild(key)
 if not lane or not lane:IsA("BasePart") then return nil end
 return lane.Position+Vector3.new(side or 30,lane.Size.Y/2+0.2,-lane.Size.Z/2+(depth or 85))
end
local function part(parent,name,size,position,color,material)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=position;p.Color=color
 p.Material=material or Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.Parent=parent
 return p
end
local function makeGrunt(parent,position,label)
 local template=workspace.Map:FindFirstChild("RouteTrainers")
 template=template and template:FindFirstChildWhichIsA("Model")
 if not template then return end
 local model=template:Clone();model.Name=label
 for _,d in model:GetDescendants() do
  if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Shirt") or d:IsA("Pants") then d:Destroy()
  elseif d:IsA("BasePart") then d.Anchored=true;d.CanCollide=false
   if d.Name:find("Torso") or d.Name:find("Leg") or d.Name:find("Arm") then d.Color=Color3.fromRGB(35,25,45) end
  end
 end
 model:PivotTo(CFrame.new(position+Vector3.new(0,3,0))*CFrame.Angles(0,math.pi,0));model.Parent=parent
 model:SetAttribute("HomeCFrame",model:GetPivot());model:SetAttribute("TrainerType","Havoc")
 local head=model:FindFirstChild("Head")
 if head then
  local tag=Instance.new("BillboardGui");tag.Size=UDim2.fromOffset(170,30);tag.StudsOffset=Vector3.new(0,2.4,0);tag.MaxDistance=70;tag.Parent=head
  local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1;text.Text=label;text.Font=Enum.Font.FredokaOne;text.TextScaled=true;text.TextColor3=Color3.fromRGB(245,90,135);text.Parent=tag
 end
 return model
end
local function setupWorld()
 local map=workspace.Map
 local old=map:FindFirstChild("StoryMilestones")
 if old then old:Destroy() end
 local folder=Instance.new("Folder");folder.Name="StoryMilestones";folder.Parent=map
 local spots={pier=laneSpot("Lane3",35,100),crystal=laneSpot("Lane2",34,110),base1=laneSpot("Lane11",32,120),base2=laneSpot("Lane13",32,120),base3=laneSpot("Lane15",32,120)}
 local professor=map.Hub:FindFirstChild("Lab") and map.Hub.Lab:FindFirstChild("Professor")
 if professor and professor.PrimaryPart then spots.lab=professor.PrimaryPart.Position+Vector3.new(5,-2,3) end
 local last=map.DungeonTower:FindFirstChild("Room11")
 if last and last:FindFirstChild("StartPad") then spots.journal=last.StartPad.Position+Vector3.new(12,0,0) end
 local vr=map.Lanes:FindFirstChild("VictoryRoad")
 if vr then spots.reveal=vr.Position+Vector3.new(20,vr.Size.Y/2+0.3,0) end
 local members=map.League2:FindFirstChild("Members")
 local champion=members and members:FindFirstChild(GameData.League2.champion.npc)
 if champion and champion.PrimaryPart then spots.final=champion.PrimaryPart.Position+Vector3.new(12,-2,12) end
 for id,pos in spots do
  local scene=byId[id]
  local site=Instance.new("Model");site.Name=id;site:SetAttribute("StoryId",id);site.Parent=folder
  local target=part(site,"StoryMarker",Vector3.new(3,1,3),pos+Vector3.new(0,0.6,0),Color3.fromRGB(175,90,245),Enum.Material.Neon)
  targets[id]=target
  if id=="pier" then
   local deck=part(site,"TidePier",Vector3.new(24,1,34),pos-Vector3.new(0,0.7,0),Color3.fromRGB(130,90,55),Enum.Material.WoodPlanks);deck.CanCollide=true
   makeGrunt(site,pos+Vector3.new(6,0,4),"Havoc Grunt Nyx");makeGrunt(site,pos+Vector3.new(-6,0,4),"Havoc Grunt")
  elseif id=="crystal" then
   local core=part(site,"WindCrystal",Vector3.new(2,5,2),pos+Vector3.new(0,3,0),Color3.fromRGB(165,235,255),Enum.Material.Neon);core.CFrame*=CFrame.Angles(0,0,0.3)
   makeGrunt(site,pos+Vector3.new(5,0,4),"Havoc Grunt Nyx")
  elseif id:sub(1,4)=="base" then
   local pad=part(site,"HavocBase",Vector3.new(22,1,25),pos-Vector3.new(0,0.7,0),Color3.fromRGB(40,30,50),Enum.Material.Metal);pad.CanCollide=true
   for _,x in {-8,8} do part(site,"RelayPillar",Vector3.new(2,10,2),pos+Vector3.new(x,5,6),Color3.fromRGB(65,40,80),Enum.Material.Metal) end
   part(site,"TimeCore",Vector3.new(5,6,3),pos+Vector3.new(0,3,8),Color3.fromRGB(185,65,220),Enum.Material.Neon)
   makeGrunt(site,pos+Vector3.new(0,0,4),scene.battle.name)
  elseif id=="journal" then
   part(site,"Journal",Vector3.new(3,0.5,2),pos+Vector3.new(0,1,0),Color3.fromRGB(95,50,130))
  end
  local prompt=NPC.prompt(target,scene.battle and "Story battle" or "Investigate",scene.title,12)
  prompt:SetAttribute("StoryId",id)
  prompt.Triggered:Connect(function(player)
   local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
   if not root or (root.Position-target.Position).Magnitude>18 then return end
   StoryService.requestMilestone(player,id)
  end)
 end
 -- Havoc patrols are optional repeatable encounters that appear after the lab scene.
 for _,key in {"Lane5","Lane6","Lane7"} do
  local pos=laneSpot(key,-34,170)
  if pos then
   local grunt=makeGrunt(folder,pos,"Havoc Route Grunt")
   if grunt and grunt.PrimaryPart then
    NPC.prompt(grunt.PrimaryPart,"Battle","Havoc Route Grunt",12).Triggered:Connect(function(player)
     if not player:GetAttribute("HavocRoutesActive") or not free(player) then return end
     BattleService.startTrainer(player,{name="Havoc Route Grunt",kind="havocPatrol",team={{"Nightfang",42},{"Shadeshroom",43}},reward={coins=80,xp=60}})
    end)
   end
  end
 end
end
function StoryService.init()
 setupWorld()
 SaveService.register("story",{
  serialize=function(player)
   local s=state[player];if not s then return nil end
   local seen,completed={},{}
   for id in s.seen do table.insert(seen,id) end
   for id in s.completed do table.insert(completed,id) end
   local step=player:GetAttribute("TutorialStep")
   return {version=2,seen=seen,completed=completed,guide=TutorialService.isGuideStep(step) and step or nil}
  end,
  load=function(player,saved)
   if typeof(saved)~="table" then return end
   local s=get(player)
   for _,id in (typeof(saved.seen)=="table" and saved.seen or {}) do if typeof(id)=="string" then s.seen[id]=true end end
   if saved.version==2 then
    for _,id in (typeof(saved.completed)=="table" and saved.completed or {}) do if byId[id] then s.completed[id]=true end end
   elseif s.seen.intro then s.completed.intro=true end -- old dialogue never grants new battle rewards
   if typeof(saved.guide)=="string" then s.guide=saved.guide end
  end,
  release=function(player) state[player]=nil end,
 })
 StoryRemote.OnServerEvent:Connect(function(player,action,id)
  local s=state[player]
  if action~="seen" or not s or s.playing~=id or typeof(id)~="string" then return end
  local scene=byId[id]
  if not scene or os.clock()-(s.started or 0)<1 then return end
  s.playing=nil
  if scene.battle then
   if not free(player) then return end
   local def={name=scene.battle.name,team=scene.battle.team,kind="story",storyId=id,boss=id=="reveal" or id=="final",reward={coins=0,xp=0},intro=scene.battle.name.." challenges you!"}
   if not BattleService.startTrainer(player,def) then Notify:FireClient(player,"Heal your team, then return to this story marker.","info") end
  else complete(player,scene);task.delay(4,check,player) end
 end)
 BattleService.onEnded(function(player,b,result)
  if not (b.isTrainer and b.trainer.kind=="story") then return end
  local scene=byId[b.trainer.storyId]
  if scene and result=="won" then complete(player,scene)
  else Notify:FireClient(player,"Juniper's story is waiting. Heal up and try the marker again.","info") end
 end)
 BattleService.onReleased(function(player) task.delay(4,check,player) end)
 Players.PlayerAdded:Connect(get)
 for _,player in Players:GetPlayers() do get(player) end
end
return StoryService

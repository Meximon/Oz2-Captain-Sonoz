functor
export
   isTurnByTurn:IsTurnByTurn
   nRow:NRow
   nColumn:NColumn
   map:FinalMap
   nbPlayer:NbPlayer
   players:Players
   colors:Colors
   thinkMin:ThinkMin
   thinkMax:ThinkMax
   turnSurface:TurnSurface
   maxDamage:MaxDamage
   missile:Missile
   mine:Mine
   sonar:Sonar
   drone:Drone
   minDistanceMine:MinDistanceMine
   maxDistanceMine:MaxDistanceMine
   minDistanceMissile:MinDistanceMissile
   maxDistanceMissile:MaxDistanceMissile
   guiDelay:GUIDelay

   logger:Logger
import
	System
    Application
    OS
define
   IsTurnByTurn
   NRow
   NColumn
   FinalMap
   NbPlayer
   Players
   Colors
   ThinkMin
   ThinkMax
   TurnSurface
   MaxDamage
   Missile
   Mine
   Sonar
   Drone
   MinDistanceMine
   MaxDistanceMine
   MinDistanceMissile
   MaxDistanceMissile
   GUIDelay

   LoggerClass
   Logger

   PercentageIslands
   PercentageIndependantIslands
   GenerateMap
in

%%% LOG %%%


class LoggerClass
	attr isLog
	meth init(Value)
		isLog := Value
	end
	meth debug(Args)
		if @isLog then
			{System.show Args}
		end
	end
	meth warning(Args)
		if @isLog then
			{System.show Args}
		end
	end
	meth err(Args)
		if @isLog then
			{System.show Args}
            {Application.exit 1}
		end
	end
end

Logger = {New LoggerClass init(true)}


%%%% Style of game %%%%

   IsTurnByTurn = false

%%%% Description of the map %%%%

   NRow = 10
   NColumn = 10
   PercentageIslands = 0.1
   PercentageIndependantIslands = 0.5 % from 0:min to 1:max

   FinalMap = {GenerateMap}

   /* FinalMap = [[0 0 0 0 0 0 0 0 0 0]
	  [0 0 0 0 0 0 0 0 0 0]
	  [0 0 0 1 1 0 0 0 0 0]
	  [0 0 1 1 0 0 1 0 0 0]
	  [0 0 0 0 0 0 0 0 0 0]
	  [0 0 0 0 0 0 0 0 0 0]
	  [0 0 0 1 0 0 1 1 0 0]
	  [0 0 1 1 0 0 1 0 0 0]
	  [0 0 0 0 0 0 0 0 0 0]
	  [0 0 0 0 0 0 0 0 0 0]] */

    proc{GenerateMap ?GeneratedMap}
        fun{InitMap}
            proc{InitRows L}
                case L
                of nil then
                    skip
                [] H|T then
                    H = {List.make NColumn}
                    {InitRows T}
                end
            end
            Map
            in
            Map = {List.make NRow}
            {InitRows Map}
            Map
        end
        fun{Get List X Y}
            Row
            in
            Row = {List.nth List X}
            {List.nth Row Y}
        end
        fun{GetCenterIslands Nb}
            if Nb < 1 then
                nil
            else
                node(x:({OS.rand} mod NRow)+1 y=({OS.rand} mod NColumn)+1)|{GetCenterIslands Nb-1}
            end
        end
        proc{FillWater Map}
            proc{FillRows MapList}
                proc{FillColumns Rows}
                    case Rows
                    of nil then
                        skip
                    [] H|T then
                        if H == 1 then
                            skip
                        else
                            H = 0
                        end
                        {FillColumns T}
                    end
                end
                in
                case MapList
                of nil then
                    skip
                [] Row|T then
                    {FillColumns Row}
                end
            end
            in
            {FillRows Map}
        end
        proc{CreateSingleIsland Map N Node}
        /*
            Create a single island
        */
        if N > 0 then
            Elem
            NewX
            NewY
            Dir
            in
            Dir = {OS.rand} mod 4
            case Dir
            of 0 then % DOWN
                NewX = (Node.x) mod NRow +1
                NewY = (Node.y-1) mod NColumn +1
                Elem = {Get Map NewX NewY}
            [] 1 then % UP
                NewX = (Node.x-2) mod NRow +1
                NewY = (Node.y-1) mod NColumn +1
                Elem = {Get Map NewX NewY}
            [] 2 then % LEFT
                NewX = (Node.x-1) mod NRow +1
                NewY = (Node.y-2) mod NColumn +1
                Elem = {Get Map NewX NewY}
            [] 3 then % RIGHT
                NewX = (Node.x-1) mod NRow +1
                NewY = (Node.y) mod NColumn +1
                Elem = {Get Map NewX NewY}
            end
            if Elem == 1 then
                {CreateSingleIsland Map N Node}
            else
                NextNode
                in
                Elem = 1
                NextNode = {OS.rand} mod 2
                case NextNode
                of 0 then % Same node
                    {CreateSingleIsland Map N-1 Node}
                [] 1 then % New Node
                    {CreateSingleIsland Map N-1 node(x:NewX y:NewY)}
                end
            end
        end
        end

        proc{CreateIslands Map State}
            case State.centerIslands
            of nil then
                {FillWater Map}
            [] Node|T then
                {CreateSingleIsland Map State.midNbNodes Node}
                {CreateIslands Map state(nodesRemaining:State.nodesRemaining-State.midNbNodes midNbNodes:State.midNbNodes nIslands:State.NbIslands-1 centerIslands:T)}
            end
        end
        NbNodes
        NbIslands
        MapList
        CenterIslandsList
        MidNbNodesPerIsland
        IslandsList
        InitState

        in
        NbNodes = {Float.toInt NRow*NColumn*PercentageIslands}
        NbIslands = {{OS.rand} mod (NbNodes*PercentageIndependantIslands)}
        MapList = {InitMap}
        CenterIslandsList = {GetCenterIslands NbIslands}
        MidNbNodesPerIsland = NbNodes div NbIslands
        InitState = state(nodesRemaining:NbNodes midNbNodes:MidNbNodesPerIsland nIslands:NbIslands centerIslands:CenterIslandsList)
        {CreateIslands MapList InitState}
        GeneratedMap = MapList
    end

%%%% Players description %%%%

   NbPlayer = 2
   Players = [player100Target playerBasicAi]
   Colors = [red blue]

%%%% Thinking parameters (only in simultaneous) %%%%

   ThinkMin = 500
   ThinkMax = 3000

%%%% Surface time/turns %%%%

   TurnSurface = 3

%%%% Life %%%%

   MaxDamage = 4

%%%% Number of load for each item %%%%

   Missile = 3
   Mine = 3
   Sonar = 3
   Drone = 3

%%%% Distances of placement %%%%

   MinDistanceMine = 1
   MaxDistanceMine = 2
   MinDistanceMissile = 1
   MaxDistanceMissile = 4

%%%% Waiting time for the GUI between each effect %%%%

   GUIDelay = 500 % ms

end

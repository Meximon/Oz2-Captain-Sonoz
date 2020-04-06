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
   PercentageIndependantIslands = 1.0 % from 0:min to 1:max

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
        fun{Get L X Y}
            {List.nth {List.nth L X} Y}
        end
        fun{GetCenterIslands Nb}
            if Nb < 1 then
                nil
            else
                node(x:({OS.rand} mod NRow)+1 y:({OS.rand} mod NColumn)+1)|{GetCenterIslands Nb-1}
            end
        end
        proc{FillWater Map}
            proc{FillRows MapList}
                proc{FillColumns Rows}
                    case Rows
                    of nil then
                        skip
                    [] H|T then
                        if {Value.isFree H} then
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
                    {FillRows T}
                end
            end
            in
            {FillRows Map}
        end
        proc{CreateSingleIsland Map N Node Try}
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
                {System.show dir(n:N dir:down)}
                NewX = ((Node.x) mod NRow) +1
                NewY = ((Node.y-1) mod NColumn) +1
                {Logger debug(info(prevX:Node.x prevY:Node.y x:NewX y:NewY maxX:NRow maxY:NColumn))}
                Elem = {Get Map NewX NewY}
            [] 1 then % UP
                {System.show dir(n:N dir:up)}
                if Node.x > 1 then
                    NewX = Node.x - 1
                else
                    NewX = NRow
                end
                NewY = ((Node.y-1) mod NColumn) +1
                {Logger debug(info(prevX:Node.x prevY:Node.y x:NewX y:NewY maxX:NRow maxY:NColumn))}
                Elem = {Get Map NewX NewY}
            [] 2 then % LEFT
                {System.show dir(n:N dir:left)}
                NewX = ((Node.x-1) mod NRow) +1
                if Node.y > 1 then
                    NewY = Node.y - 1
                else
                    NewY = NColumn
                end
                {Logger debug(info(prevX:Node.x prevY:Node.y x:NewX y:NewY maxX:NRow maxY:NColumn))}
                Elem = {Get Map NewX NewY}
            [] 3 then % RIGHT
                {System.show dir(n:N dir:right)}
                NewX = ((Node.x-1) mod NRow) +1
                NewY = ((Node.y) mod NColumn) +1
                {Logger debug(info(prevX:Node.x prevY:Node.y x:NewX y:NewY maxX:NRow maxY:NColumn))}
                Elem = {Get Map NewX NewY}
            end
            if {Value.isFree Elem} orelse Try == 0 then
                NextNode
                in
                Elem = 1
                NextNode = {OS.rand} mod 2
                case NextNode
                of 0 then % Same node
                    {Logger debug(sameNode)}
                    {CreateSingleIsland Map N-1 Node 5}
                [] 1 then % New Node
                    {Logger debug(nextNode)}
                    {CreateSingleIsland Map N-1 node(x:NewX y:NewY) 5}
                end
            else
                {Logger debug(alreadyBind(x:NewX y:NewY))}
                {CreateSingleIsland Map N Node Try-1}
            end
        end
        end

        proc{CreateIslands Map CenterIslandsList MidNodes}
            case CenterIslandsList
            of nil then
                {FillWater Map}
            [] Node|T then
                {CreateSingleIsland Map MidNodes Node 5}
                {CreateIslands Map T MidNodes}
            end
        end
        NbNodes
        NbIslands
        MapList
        CenterIslandsList
        MidNbNodesPerIsland
        InitState

        in
        NbNodes = {FloatToInt {IntToFloat NRow*NColumn}*PercentageIslands}
        NbIslands = {FloatToInt {IntToFloat NbNodes}*0.25} + {OS.rand} mod {FloatToInt ({IntToFloat NbNodes}*PercentageIndependantIslands*0.5)}
        GeneratedMap = {InitMap}
        CenterIslandsList = {GetCenterIslands NbIslands}
        MidNbNodesPerIsland = NbNodes div NbIslands
        /* InitState = state(nodesRemaining:NbNodes midNbNodes:MidNbNodesPerIsland nIslands:NbIslands centerIslands:CenterIslandsList)
        {System.show InitState} */
        {CreateIslands GeneratedMap CenterIslandsList MidNbNodesPerIsland}
        {System.show GeneratedMap}
    end

    FinalMap = {GenerateMap}
    /* {System.show FinalMap} */

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

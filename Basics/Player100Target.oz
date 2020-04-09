/* This player is going to try to kill the other players one by one. Once a player has
successfully been killed, it resets all it's "known" variables and starts targeting the
following player. */
functor
import
    Input
    OS
	System
export
    portPlayer:StartPlayer

define
    StartPlayer
    TreatStream


    %Custom functions
    Logger
	LoggerClass
    IsIsland
    RandomNoIsland
    TargetPosKnown
	IsInHistory


    %The following functions receive a playerstate and return an updated playerstate
    InitPosition
    Move
    Dive
    ChargeItem
    FireItem
    FireMine
    IsDead
    SayMove
    SaySurface
    SayCharge
    SayMinePlaced
    SayMissileExplode
    SayMineExplode
    SayPassingDrone
    SayAnswerDrone
    SayPassingSonar
    SayAnswerSonar
    SayDeath
    SayDamageTaken


in
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
			{System.show Args}
    	end
    	meth err(Args)
			{System.showError Args}
    	end
    end

    Logger = {New LoggerClass init(true)}

    proc{TreatStream Stream State}
    /*
    *   Treating and dispatching in the stream.
    */
        case Stream
        of
        nil then {Logger debug('[Player.oz] Treatstream end of stream')}
        []initPosition(ID Position)|T then {TreatStream T {InitPosition State ID Position}}
        []move(ID Position Direction)|T then {TreatStream T {Move State ID Position Direction 0}}
        []dive|T then {TreatStream T {Dive State}}
        []chargeItem(ID Kinditem)|T then {TreatStream T {ChargeItem State ID Kinditem}}
        []fireItem(ID KindFire)|T then  {TreatStream T {FireItem State ID KindFire}}
        []fireMine(ID Mine)|T then {TreatStream T {FireMine State ID Mine}}
        []isDead(Answer)|T then {TreatStream T {IsDead State Answer}}
        []sayMove(ID Direction)|T then {TreatStream T {SayMove State ID Direction}}
        []saySurface(ID)|T then {TreatStream T {SaySurface State ID}}
        []sayCharge(ID KindItem)|T then {TreatStream T {SayCharge State ID KindItem}}
        []sayMinePlaced(ID)|T then {TreatStream T {SayMinePlaced State ID}}
        []sayMissileExplode(ID Position Message)|T then {TreatStream T {SayMissileExplode State ID Position Message}}
        []sayMineExplode(ID Position Message)|T then {TreatStream T {SayMineExplode State ID Position Message}}
        []sayPassingDrone(Drone ID Answer)|T then {TreatStream T {SayPassingDrone State Drone ID Answer}}
        []sayAnswerDrone(Drone ID Answer)|T then {TreatStream T {SayAnswerDrone State Drone ID Answer}}
        []sayPassingSonar(ID Answer)|T then{TreatStream T {SayPassingSonar State ID Answer}}
        []sayAnswerSonar(ID Answer)|T then {TreatStream T {SayAnswerSonar State ID Answer}}
        []sayDeath(ID)|T then {TreatStream T {SayDeath State ID}}
        []sayDamageTaken(ID Damage Lifeleft)|T then {TreatStream T {SayDamageTaken State ID Damage Lifeleft}}
        else {Logger err('[Player.oz] Treatstream illegal record')}
        end %Case end
    end %Proc Treatstream end

    %%%
    %%%
    %%%

    fun{InitPosition State ?ID ?Position} Return in
    /* Initialises the player's initial position */
        Position = {RandomNoIsland}
        Return = {AdjoinList State [pos#Position]}
        ID = Return.id
        Return
    end %Fun InitPostion end

    /* Note that InitPosition and move are the movements made by the player.
    Here, I implement them moving in a random way. The moving algorithm has to be optimised
    in order to win the game instead of just randomly moving */
    fun{Move State ?ID ?Position ?Direction Tries}
				
        RandomInt ReturnState Newpos DirTemp in
		
		if Tries>8 then 
			Direction = surface
			Position = State.pos
			ID =State.id
			{AdjoinList State [underwater#false history#nil]}
		else
        if State.underwater ==false then 
        ID = State.id
        Direction = null
        Position = State.pos
        {Logger err('[Player.oz] You asked me to move while Im on the surface')} State else
        RandomInt = {OS.rand}mod 4 % --> returns 0,1,2,3
        %{System.show RandomInt}
        /* 0-1-2-3 NORTH EAST SOUTH WEST */
        case RandomInt of
        0 then
            DirTemp = north
            Newpos = pt(x: State.pos.x y:State.pos.y-1)
            ReturnState = {AdjoinList State [pos#Newpos]}
        []1 then
            DirTemp = east
            Newpos = pt(x: State.pos.x+1 y: State.pos.y)
            ReturnState = {AdjoinList State [pos#Newpos]}
        [] 2 then
            DirTemp= south
            Newpos = pt(x: State.pos.x y: State.pos.y+1)
            ReturnState = {AdjoinList State [pos#Newpos]}
        [] 3 then
            DirTemp = west
            Newpos = pt(x: State.pos.x-1 y: State.pos.y)
            ReturnState = {AdjoinList State [pos#Newpos]}
        end %end of case

        /* Now binding ID and Position to the position chosen. Direction was already bound */
        if ({IsIsland ReturnState.pos.x ReturnState.pos.y} orelse {IsInHistory State ReturnState.pos}) then
                {Move State ID Position Direction Tries+1}
        else
				%I must now check whether I can actually go on this spot
                Direction = DirTemp
                ID = ReturnState.id
                Position=ReturnState.pos
                {AdjoinList ReturnState [history#(Position|ReturnState.history)]}
				end
        end
		end 
    end
    fun{Dive State}
    /* Updating current state to note that I'm underwater */
        {AdjoinList State [underwater#true]}
    end

    fun{ChargeItem State ?ID ?KindItem} ReturnState in
        if {TargetPosKnown State} ==false  then
        /* I must estimate the other's position.  */
            if State.sonarcharge<Input.sonar then
                ReturnState = {AdjoinList State [sonarcharge#State.sonarcharge+1]}
            else
                ReturnState = State
            end
            if ReturnState.sonarcharge == Input.sonar then KindItem = sonar else KindItem = null end
        else
            %If I already know everything about the other's position.
            if State.missilecharge<Input.missile then
                ReturnState = {AdjoinList State [missilecharge#State.missilecharge+1]}
            else
                ReturnState = State
            end
            if ReturnState.missilecharge== Input.missile then KindItem = missile else KindItem = null end
        end
        %%{System.show ReturnState}
        ID = ReturnState.id
        ReturnState
    end

    fun{FireItem State ?ID ?KindFire}
    /* Called to fire an item. We must first check whether we can actually fire an item, and then
    return which one we fired. null otherwise */
        ReturnState in
        if State.missilecharge == Input.missile then
			Dist Targetposition in 
			Targetposition = State.targetpos
			Dist = {Abs State.pos.x-Targetposition.x} + {Abs State.pos.y-Targetposition.y}
			
			if Dist =< 2
			then 
				KindFire = null
				ReturnState = State
			else 
			
            KindFire = missile(Targetposition)
            ReturnState = {AdjoinList State [missilecharge#0]}
			end 
        elseif State.minecharge == Input.mine then
            KindFire = mine({RandomNoIsland})
            ReturnState = {AdjoinList State [minecharge#0]}
        elseif State.sonarcharge == Input.sonar then
            KindFire = sonar
            ReturnState = {AdjoinList State [sonarcharge#0]}
        elseif State.dronecharge == Input.drone then
            KindFire = drone
            ReturnState = {AdjoinList State [drone#0]}
        else
            KindFire = null
            ReturnState = State
        end
        ID = ReturnState.id
        ReturnState
    end

    fun{FireMine State ?ID ?Mine}
        /* Decide whether you want to fire a mine. This player never places mines thus no mine can be
        fired. */
        ID = State.id
        Mine = null
        State
    end

    fun{IsDead State ?Answer}
            if(State.hp<1) then Answer = true else Answer = false end
            State
    end

    fun{SayMove State ID Direction} Newpos in
    /* Involves logging position, ignoring.
    State is thus not being modified */
	if State.target_id == ID then 
        case Direction of
        north then
                Newpos = pt(x: State.targetpos.x y:State.targetpos.y-1)
        [] east then
            Newpos = pt(x: State.targetpos.x+1 y: State.targetpos.y)
        [] south then
            Newpos = pt(x: State.targetpos.x y: State.targetpos.y+1)
        [] west then
            Newpos = pt(x: State.targetpos.x-1 y: State.targetpos.y)
        else
            Newpos = pt(x: State.targetpos.x y: State.targetpos.y)
        end
        if {IsIsland State.targetpos.x State.targetpos.y }then

        {AdjoinList State [targetpos#{RandomNoIsland} target_x_valid#false target_y_valid#false]}

        else
            {AdjoinList State [targetpos#Newpos]}
        end
	else%If targetid does not correspond 
		if ID == State.id then State else
		{AdjoinList State [target_id#ID]}end
	end 
    end

    fun{SaySurface State ID}
    /* Involves logging position, ignoring. */
        State
    end

    fun{SayCharge State ID KindItem}
        /* Involves logging position, ignoring. */
        State
    end

    fun{SayMinePlaced State ID}
        /* Involves logging position, ignoring. */
        State
    end

    fun{SayMissileExplode State ID Position ?Message} ReturnState ManDist Dmg Hp in
    /* Player with ID made a missile explode in a given position. Check whether the position corresponds and reply accordingly by binding Message */
        ManDist = {Abs State.pos.x-Position.x} + {Abs State.pos.y-Position.y}
        case ManDist of
        0 then
            Dmg = 2
        []1 then
            Dmg = 1
        else
            Dmg = 0
        end

		
        Hp = State.hp-Dmg
        ReturnState = {AdjoinList State [hp#Hp]}

        if ReturnState.hp=<0 then
            Message=sayDeath(ReturnState.id)
        else
			if Dmg == 0 then Message = null else Message = sayDamageTaken(State.id Dmg ReturnState.hp) end
        end
    ReturnState
    end

    fun{SayMineExplode State ID Position ?Message}
        /* Apparently is's just the same as missileexplode. */
        {SayMissileExplode State ID Position Message}

    end

    fun{SayPassingDrone State Drone ?ID ?Answer}
        /* Receiving a drone message. I must answer whether I'm on it or not and bind my ID
        <drone> := drone(row <x>)|drone(column <y>) */
        case Drone
        of drone(row X) then
            if X == State.pos.x then Answer = true else Answer = false end
        [] drone(column Y)then
            if Y == State.pos.y then Answer = true else Answer = false end
        else
            {Logger err('[Player.oz] SayPassingDrone invalid drone')}
        end
        ID = State.id
        State
    end

    fun{SayAnswerDrone State Drone ID Answer}
        /* Involves logging other player's positions. Ignoring */
        State
    end

    fun{SayPassingSonar State ?Id ?Answer}
        Rand A in
        Rand = {OS.rand} mod 2
        if Rand == 0 then
            A = {OS.rand} mod Input.nRow+1
            Answer = pt(x:State.pos.x y:A)
        else
            A = {OS.rand} mod Input.nColumn+1
            Answer = pt(y:State.pos.y x:A)
        end
        Id = State.id
        State
    end

    fun{SayAnswerSonar State ID Answer} NewX NewY Xvalid Yvalid  in
            /* I must comparte the sonar position to my known player position.
            Treat X and Y separated.

            if target_x_valid ignore X. else
                if X stored == sonar X then target_x_valid else X stored = sonar stored.

            Do the same with Y . */
			
		if ID == State.id then State else
        if State.target_x_valid == true then
        NewX = State.targetpos.x %keep old results
        Xvalid = true
        else
            if State.targetpos.x == Answer.x then
                Xvalid = true
                NewX = State.targetpos.x
            else
                NewX = Answer.x
                Xvalid = false
            end
        end

        if State.target_y_valid == true then
        NewY = State.targetpos.y %keep old results
        Yvalid = true
        else
            if State.targetpos.x == Answer.x then
                Yvalid = true
                NewY= State.targetpos.y
            else
                NewY = Answer.y
                Yvalid = false
            end
        end
        {AdjoinList State [targetpos#pt(x:NewX y:NewY) target_y_valid#Yvalid target_x_valid#Xvalid]}
		end
    end

    fun{SayDeath State ID}
            /* Involves logging other player's positions. Ignoring */
			if ID == State.target_id then 
				{AdjoinList State [target_id#nil]}
			else
				State
			end
    end

    fun{SayDamageTaken State ID Damage LifeLeft}
            /* Involves logging other player's positions. Ignoring */
        State
    end


    %%%
    %%%
    %%%

    fun{IsIsland X Y}
    /*
    * Returns whether the x and y coordinates correspond to an island.
    */
    %{System.show isisland(x:X y:Y)}
    /* C'est crado qu'on sache pas faire des if A or B or C then .. else .. */
    if Y>Input.nColumn then true else
        if X>Input.nRow then true else
            if X<1 then true else
                if Y<1 then true else

            if({List.nth {List.nth Input.map X} Y}==0)==false then true else false end
            end end end end
    end

    fun{RandomNoIsland}
    /* Returns a random position that is not an island */
        X Y
        in
        X = {OS.rand} mod Input.nRow+1
        Y = {OS.rand} mod Input.nColumn+1
        if{IsIsland X Y} then
        {RandomNoIsland}
        else
            pt(x:X y:Y)
        end
    end
    fun{TargetPosKnown State} Ret in
        if State.target_x_valid == true then
            if State.target_y_valid == true then
                Ret = true
            else
                Ret = false
            end

        else
            Ret = false
        end
        Ret
    end
	
	fun{IsInHistory State Pos}
		
		fun{Recurs A}
			case A of nil then false
			[]pt(x:X y:Y)|T then
				if Pos.x == X andthen Pos.y == Y then true else {Recurs T}end
			end
		end
		in
		{Recurs State.history}
	end


    fun{StartPlayer Color ID}
    /*
    *   Starts the player and returns a port
    */
        Stream
        Port
        State
    in
        {NewPort Stream Port}
        %%Playerstate definition
        /*
        *   Playerstate contains all information about the current player
        */
        State = playerstate(target_id:nil history:nil id:id(name: 'PlayerTargetting' id: ID color:Color) hp:Input.maxDamage underwater:false missilecharge: 0 target_x_valid: false target_y_valid: false sonarcharge:0 targetpos:{RandomNoIsland} minecharge:0 dronecharge:0)


        thread {TreatStream Stream State} end
        Port

    end
end %define... in .. END

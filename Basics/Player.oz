functor
import
    Input
    System
    OS
export
    portPlayer:StartPlayer

define
    StartPlayer
    TreatStream


    %Custom functions
    Logger = Input.logger
    IsIsland
    RandomNoIsland


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


in
    proc{TreatStream Stream State}
    /*
    *   Treating and dispatching in the stream.
    */
        case Stream
        of
        nil then {Logger debug('[Player.oz] Treatstream end of stream')}
        []initPosition(ID Position)|T then {TreatStream T {InitPosition State ID Position}}
        []move(ID Position Direction)|T then {TreatStream T {Move State ID Position Direction}}
        []dive|T then {TreatStream T {Dive State}}
        []chargeItem(ID Kinditem)|T then {TreatStream T {ChargeItem State ID Kinditem}}
        []fireItem(ID KindFire)|T then  {TreatStream T {FireItem State ID KindFire}}
        []fireMine(ID Mine)|T then {TreatStream T {FireMine State ID Mine}}
        []isDead(Answer)|T then {TreatStream T {IsDead State Answer}}
        []sayMove(ID Direction)|T then {TreatStream T {SayMove State ID Direction}}
        []saySurface(ID)|T then {TreatStream T {SaySurface State ID}}
        []sayCharge(ID KindItem)|T then {TreatStream T {SayCharge State ID KindItem}}
        []sayMinePlaced(ID)|T then {TreatStream T {SayMinePlaced State ID}}
        else {Logger err('[Player.oz] Treatstream illegal record')}
        end %Case end
    end %Proc Treatstream end

    %%%
    %This section contains all the characteristic functions of player. They MUST return
    %a State that has been updated.
    fun{InitPosition State ID Position} Return in
        Position = {RandomNoIsland}
        Return = {AdjoinList State [pos#Position]}
        ID = Return.id
        Return
    end %Fun InitPostion end

    fun{RandomNoIsland}
        X Y
        in
        X = {OS.rand} mod Input.nRow +1
        Y = {OS.rand} mod Input.nColumn +1
        if{IsIsland X Y} then
        {RandomNoIsland}
        else
        pt(x:X y:Y)
        end
    end



    /* Note that InitPosition and move are the movements made by the player.
    Here, I implement them moving in a random way. The moving algorithm has to be optimised
    in order to win the game instead of just randomly moving */
    fun{Move State ID Position Direction}
        RandomInt ReturnState Newpos in
        RandomInt = {OS.rand}mod 4 % --> returns 0,1,2,3
        %{System.show RandomInt}
        /* 0-1-2-3 NORTH EAST SOUTH WEST */
        case RandomInt of
        0 then
            Direction = north
            Newpos = pt(x: State.pos.x y:State.pos.y-1)
            ReturnState = {AdjoinList State [pos#Newpos]}
        []1 then
            Direction = east
            Newpos = pt(x: State.pos.x+1 y: State.pos.y)
            ReturnState = {AdjoinList State [pos#Newpos]}
        [] 2 then
            Direction= south
            Newpos = pt(x: State.pos.x y: State.pos.y+1)
            ReturnState = {AdjoinList State [pos#Newpos]}
        [] 3 then
            Direction = west
            Newpos = pt(x: State.pos.x-1 y: State.pos.y)
            ReturnState = {AdjoinList State [pos#Newpos]}
        end %end of case

        /* Now binding ID and Position to the position chosen. Direction was already bound */
        ID = ReturnState.id
        Position=ReturnState.pos
        ReturnState
    end

    fun{Dive State}
        {AdjoinList State [underwater#true]}
    end

    fun{ChargeItem State ID KindItem}
        /* This function gets to charge ONE item and has to choose which one.
        For testing purpose, we'll only charge the sonar in this player. */
        ReturnState SonarCharge in
        SonarCharge = State.sonarcharge
        if SonarCharge+1 == Input.sonar then
            ReturnState = {AdjoinList State [sonarcharge#SonarCharge+1]}
            KindItem=sonar
        elseif SonarCharge+1>Input.sonar then
            ReturnState = State
            KindItem = sonar
        else
            ReturnState = {AdjoinList State [sonarcharge#SonarCharge+1]}
            KindItem = null
        end
        ID = ReturnState.id
        {System.show ReturnState}
        ReturnState
    end

    fun{FireItem State ID KindFire}
        ReturnState in
        if State.missilecharge == Input.missile then
            KindFire = missile({RandomNoIsland})
            ReturnState = {AdjoinList State [missilecharge#0]}

        elseif State.minecharge == Input.mine then
            KindFire = mine({RandomNoIsland})
            ReturnState = {AdjoinList State [minecharge#0]}
        elseif State.sonarcharge == Input.sonar then
            KindFire = sonar
            ReturnState = {AdjoinList State [sonarcharge#0]}
        elseif State.dronecharge = Input.drone then
            KindFire = drone
            ReturnState = {AdjoinList State [drone#0]}
        end
        ID = ReturnState.id
        ReturnState = State
        State
    end

    fun{FireMine State ID Mine}
        {Logger debug('Not implemented')}
        State
    end

    fun{IsDead State Answer}
            if(State.hp<1) then Answer = true else Answer = false end
            State
    end

la */
    fun{SayMove State ID Direction}
        State
    end

    fun{SaySurface State ID}
        State
    end

    fun{SayCharge State ID KindItem}
        State
    end

    fun{SayMinePlaced State ID}
        State
    end

    %%%

    fun{IsIsland X Y}
    /*
    * Returns whether the x and y coordinates correspond to an island.
    */
    if{List.nth {List.nth Input.map X} Y} == 1 then true else false end
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
        State = playerstate(id:id(name: 'BasicPlayer' id: ID color:Color) hp:Input.maxDamage underwater:false missilecharge: 0 minecharge:0 sonarcharge: 0 dronecharge:0)
        thread {TreatStream Stream State} end
        Port

    end
end %define... in .. END

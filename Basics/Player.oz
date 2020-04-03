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
    IsIsland


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
        nil then {System.showInfo '[Player.oz] Treatstream end of stream'}
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
        else skip
        end %Case end
    end %Proc Treatstream end

    %%%
    %This section contains all the characteristic functions of player. They MUST return
    %a State that has been updated.
    fun{InitPosition State ID Position} X Y in
        X = {OS.rand} mod Input.nRow +1
        Y = {OS.rand} mod Input.nColumn +1

        if{IsIsland X Y} then
        {InitPosition State ID Position}
        else
        {AdjoinList State [x#X y#Y]} end %IfElseEnd
    end %Fun InitPostion end



    fun{Move State ID Position Direction}
        State
    end

    fun{Dive State}
        {System.show 'Coucou'}
        State
    end

    fun{ChargeItem State ID KindItem}
        State
    end

    fun{FireItem State ID Kindfire}
        State
    end

    fun{FireMine State ID Mine}
        State
    end

    fun{IsDead State Answer}
        State
    end

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
        State = playerstate(id:ID hp:Input.maxDamage underwater:false missilecharge: 0 minecharge:0 sonarcharge: 0 dronecharge:0)
        thread {TreatStream Stream State} end
        Port

    end
end %define... in .. END

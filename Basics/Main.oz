functor
import
    GUI
    Input
    PlayerManager
    /* System */

define
	%Global Variables

	GUIPORT
	PlayersList

    Logger = Input.logger

	proc{CreatePlayers ?PlayerList}
	/*
		Create a list with all players
	*/
    	fun{RecursiveCreator ID Players Colors}
            if (ID > Input.nbPlayer) then
        			nil % Created all players
            else
    			case Players#Colors
    			of (Kind|T1)#(Color|T2) then
    				{PlayerManager.playerGenerator Kind Color ID}|{RecursiveCreator ID+1 T1 T2}
    			else
    				nil
                end
            end
        end
	in
		PlayerList = {RecursiveCreator 1 Input.players Input.colors}
	end

    proc{InitPlayers List}
	/*
		Initialise all players on the GUI window
	*/
    	case List
        of nil then
            skip
    	[] Player|T then
            ID Position
        in
    		{Send Player initPosition(ID Position)}
    		{Wait ID}
    		{Wait Position}
            {Logger debug(statePlayer(id:ID position:Position))}
    		{Send GUIPORT initPlayer(ID Position)}
    		{InitPlayers T}
    	end
    end

	proc{LaunchGame}
	/*
		Launch the main game
		(Implemented like gym.Environment)
	*/
        proc{Broadcast Message List}
            case List
            of nil then
                skip
            [] Player|T then
                {Send Player Message}
                {Broadcast Message T}
            end
        end

        proc{TreatSurface Player N State ?NextState}
        /*
            Treat the surface attribute of the submarine
        */
            if State.N.isAtSurface then
                NewPlayerState
                in
                if State.N.timeRemaining > 0 then % Time remaining on the surface, just decrease is time remaining
                    NewPlayerState = {Record.adjoinList State.N [timeRemaining#State.N.timeRemaining-1]}
                else % No time remaining, the submarine can dive again
                    NewPlayerState = {Record.adjoinList State.N [isAtSurface#false timeRemaining#0]}
                    {Send Player dive}
                end
                NextState = {Record.adjoinList State [N#NewPlayerState]}
            else % The submarine is not on the surface, continue
                NextState = State
            end
        end

        proc{TreatDirection Player N State ?NextState}
        /*
            Broadcast the next move of the submarine and modify the player state if needed
        */
            Move_ID Move_Position Move_Direction
            in
            {Send Player move(Move_ID Move_Position Move_Direction)}
            {Wait Move_ID}

            if Move_ID == null then
                NextState = State
            elseif Move_Direction == surface then
                NextPlayerState
                in
                {Broadcast saySurface(Move_ID) PlayersList}
                {Send GUIPORT surface(Move_ID)}
                NextPlayerState = {Record.adjoinList State.N [isAtSurface#true timeRemaining#Input.turnSurface]}
                NextState = {Record.adjoinList State [N#NextPlayerState]}
            else
                {Broadcast sayMove(Move_ID Move_Direction) PlayersList}
                {Send GUIPORT movePlayer(Move_ID Move_Position)}
                NextState = State
            end
        end

        proc{TreatCharge Player}
        /*
            Tell the player {Player} that he is able to charge an item
        */
            ID_Item Kind_Item
            in
            {Send Player chargeItem(ID_Item Kind_Item)} % Ask for the ID and the kind of the item
            if ID_Item == null andthen Kind_Item == null then
                skip
            else
                {Broadcast sayCharge(ID_Item Kind_Item) PlayersList} % Broadcats that the player {Player} has charge an item
            end
        end

        proc{TreatFire Player State ?NextState}
        /*
            Ask the player {Player} for firing an item
        */
            ID_Fire Kind_Fire
            in
            {Send Player fireItem(ID_Fire Kind_Fire)}
            {Wait ID_Fire} {Wait Kind_Fire}
            {Logger debug(fireItem(kind:Kind_Fire id:ID_Fire))}
            if ID_Fire == null then % No fire (impossible in theory)
                NextState = State
            else
                case Kind_Fire
                of null then % No fire
                    NextState = State
                [] missile(Position) then % Explode a missile at postion {Position}
                    proc{TreatMissileMessage MissileState PlayersToBroadcast ?NextMissileState}
                        case PlayersToBroadcast
                        of nil then % No more player to treat
                            NextMissileState = MissileState
                        [] H|T then % Next player
                            ReceivedMessage
                            in
                            {Send H sayMissileExplode(ID_Fire Position ReceivedMessage)}
                            {Wait ReceivedMessage}
                            {Logger debug(sayMissileExplode(position:Position message:ReceivedMessage))}
                            case ReceivedMessage
                            of null then % No damage for submarine {H}, continue
                                NextMissileState = {TreatMissileMessage MissileState T}
                            [] sayDeath(ID_Death) then % The submarine {ID_Death} is dead
                                UpdatedPlayerState
                                UpdatedMissileState
                                in
                                UpdatedPlayerState = {Record.adjoinList MissileState.ID_Death [dead#true]}
                                {Broadcast sayDeath(ID_Death) PlayersList}
                                {Send GUIPORT removePlayer(ID_Death)}
                                UpdatedMissileState = {Record.adjoinList MissileState [alives#MissileState.alives-1 ID_Death.id#UpdatedPlayerState]}
                                NextMissileState = {TreatMissileMessage UpdatedMissileState T}
                            [] sayDamageTaken(ID_Damage Damage LifeLeft) then % The submarine {ID_Damage} get {Damage} damage
                                {Broadcast sayDamageTaken(ID_Damage Damage LifeLeft) PlayersList}
                                {Send GUIPORT lifeUpdate(ID_Damage LifeLeft)}
                                NextMissileState = {TreatMissileMessage MissileState T}
                            else % Message not supported
                                {Logger warning(warning(message:ReceivedMessage warn:'sayMissileExplode, received message not understood'))}
                                NextMissileState = {TreatMissileMessage MissileState T}
                            end
                        end
                    end
                    in
                    NextState = {TreatMissileMessage State PlayersList}
                [] mine(Position) then % Treat a placed mine
                    {Broadcast sayMinePlaced(ID_Fire) PlayersList}
                    {Send GUIPORT putMine(ID_Fire Position)}
                    NextState = State
                [] drone(Type Position) then
                    proc{TreatDroneMessage PlayersToBroadcast}
                        case PlayersToBroadcast
                        of nil then % No more player to treat
                            skip
                        [] H|T then
                            ID_Passing_Drone Is_Under_Drone
                            in
                            {Send H sayPassingDrone(drone(Type Position) ID_Passing_Drone Is_Under_Drone)} % Ask the player {H} if is under the drone
                            {Wait ID_Passing_Drone} {Wait Is_Under_Drone}
                            {Logger debug(isUnderDrone(player:ID_Passing_Drone isUnder:Is_Under_Drone drone:drone(Type Position)))}
                            {Send Player sayAnswerDrone(drone(Type Position) ID_Passing_Drone Is_Under_Drone)} % Tell the player {Player} if the player {H} is under the drone
                            {TreatDroneMessage T} % Next player
                        end
                    end
                    in
                    case Type
                    of row then
                        if Position > Input.nRow then % Too big for the map
                            {Logger warning(warning(id:ID_Fire rowAsked:Position nRowMap:Input.nRow warn:'Row asked for a drone too big for the map'))}
                        else
                            {TreatDroneMessage PlayersList}
                        end
                    [] column then
                        if Position > Input.nColumn then % Too big for the map
                            {Logger warning(warning(id:ID_Fire columnAsked:Position nColumnMap:Input.nRow warn:'Column asked for a drone too big for the map'))}
                        else
                            {TreatDroneMessage PlayersList}
                        end
                    else
                        {Logger warning(warning(id:ID_Fire droneType:Type warn:'drone type not understood'))}
                    end
                    NextState = State
                [] sonar then
                    proc{TreatSonarMessage PlayersToBroadcast}
                        case PlayersToBroadcast
                        of nil then % No more player to treat
                            skip
                        [] H|T then
                            ID_Passing_Sonar Position_Sonar
                            in
                            {Send H sayPassingSonar(ID_Passing_Sonar Position_Sonar)} % Ask the player {H} for a sonar
                            {Wait ID_Passing_Sonar} {Wait Position_Sonar}
                            {Logger debug(id:ID_Passing_Sonar answer:Position_Sonar)}
                            {Send Player sayAnswerSonar(ID_Passing_Sonar Position_Sonar)} % Tell the player {Player} if the player {H} is under the drone
                            {TreatSonarMessage T} % Next player
                        end
                    end
                    in
                    {TreatSonarMessage PlayersList}
                else
                    NextState = State
                end
            end
        end

        proc{TreatMine Player State ?NextState}
            ID Mine
            in
            {Send Player fireMine(ID Mine)}
            {Wait ID} {Wait Mine}
            {Logger debug(fireMine(ID Mine))}
            if ID == null then % Impossible in theory
                NextState = State
            else
                case Mine
                of null then % No mine to explode
                    NextState = State
                [] Position then
                    proc{TreatMineMessage MineState PlayersToBroadcast ?NextMineState}
                        case PlayersToBroadcast
                        of nil then % No more player to treat
                            NextMineState = MineState
                        [] H|T then % Next player
                            ReceivedMessage
                            in
                            {Send H sayMineExplode(ID Position ReceivedMessage)}
                            {Wait ReceivedMessage}
                            {Logger debug(sayMineExplode(position:Position message:ReceivedMessage))}
                            case ReceivedMessage
                            of null then % No damage for submarine {H}, continue
                                NextMineState = {TreatMineMessage MineState T}
                            [] sayDeath(ID_Death) then % The submarine {ID_Death} is dead
                                UpdatedPlayerState
                                UpdatedMineState
                                in
                                UpdatedPlayerState = {Record.adjoinList MineState.ID_Death [dead#true]}
                                {Broadcast sayDeath(ID_Death) PlayersList}
                                {Send GUIPORT removePlayer(ID_Death)}
                                UpdatedMineState = {Record.adjoinList MineState [alives#MineState.alives-1 ID_Death.id#UpdatedPlayerState]}
                                NextMineState = {TreatMineMessage UpdatedMineState T}
                            [] sayDamageTaken(ID_Damage Damage LifeLeft) then % The submarine {ID_Damage} get {Damage} damage
                                {Broadcast sayDamageTaken(ID_Damage Damage LifeLeft) PlayersList}
                                {Send GUIPORT lifeUpdate(ID_Damage LifeLeft)}
                                NextMineState = {TreatMineMessage MineState T}
                            else % Message not supported
                                {Logger warning(warning(message:ReceivedMessage warn:'sayMineExplode, received message not understood'))}
                                NextMineState = {TreatMineMessage MineState T}
                            end
                        end
                    end
                    in
                    NextState = {TreatMineMessage State PlayersList}
                else
                    {Logger warning(warning(id:ID mine:Mine warn:'Mine not understood'))}
                    NextState = State
                end
            end
        end

       	fun{Reset}
       	/*
       		Return the first state of the game
       	*/
       		fun{RecursiveReset N PlayersState}
       			NewPlayersState
       		in
       			if N > Input.nbPlayer then
       				PlayersState
       			else
           			NewPlayersState = {Record.adjoinList PlayersState [N#playerState(dead:false isAtSurface:true timeRemaining:0)]}
                    {RecursiveReset N+1 NewPlayersState}
                end
       		end
        in
             {Record.adjoinList {RecursiveReset 1 gameState()} [alives#Input.nbPlayer]}
       	end

        proc{LoopTurnByTurn State}
        /*
         Handle the turn by turn game
        */
            proc{Loop List N Obs ?NextObs}
                case List
                of nil then % All players were treat
                    NextObs = Obs
                [] Player|T then % Treat the next player
                    SurfaceState
                    in
                    SurfaceState = {TreatSurface Player N Obs}
                    if SurfaceState.N.isAtSurface then % The player number N is at surface
                        NextObs = {Loop T N+1 SurfaceState}
                    else % The player number N is not at surface so continue
                        DirectionState
                        in
                        % Treat the direction of the submarine
                        DirectionState = {TreatDirection Player N SurfaceState}
                        % If the direction is surface, return the state
                        if DirectionState.N.isAtSurface then
                            NextObs = {Loop T N+1 DirectionState}
                        else
                            FireState
                            MineState
                            in
                            % Charge item
                            {TreatCharge Player}

                            % The submarine is authorized to fire an item
                            FireState = {TreatFire Player DirectionState}

                            % The submarine is authorized to explode a mine
                            MineState = {TreatMine Player FireState}
                            {Logger debug(nextState(MineState))}
                            NextObs = {Loop T N+1 MineState}
                        end
                    end
                end
            end
            NextState
        in
            NextState = {Loop PlayersList 1 State}
            {Logger debug(NextState)}
            if (NextState.alives < 0) then % More than 1 player still alive, continue
                {LoopTurnByTurn NextState}
            end
            % Game finished
            {Logger debug('Game over.')}
        end

        proc{LoopSimultaneous State}
        /*
         Handle the simultaneous game
        */
         {Logger err('LoopSimultaneous not implemented yet')}
        end

        FirstState
   in
        FirstState = {Reset}
        if (Input.isTurnByTurn) then
            {LoopTurnByTurn FirstState}
        else
            {LoopSimultaneous FirstState}
        end
    end

in
/******************/
/*      MAIN      */
/******************/

    % Create the window
    GUIPORT = {GUI.portWindow}
    {Send GUIPORT buildWindow}

    PlayersList = {CreatePlayers}
    {InitPlayers PlayersList}
    {LaunchGame}
end

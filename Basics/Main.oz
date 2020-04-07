functor
import
    GUI
    Input
    PlayerManager
    OS
    /* Application */
    /* System */

define
	%Global Variables

    SIMPORT     % Handle the information between players during the simultaneous game
    SimStream   % The stream containing informations about the number of players remaining (end game)
	GUIPORT     % Handle the information send to the GUI
	PlayersList % Contains all players ports (list)

    Logger = Input.logger % Used to display log informations (debug, warning, error)

	proc{CreatePlayers ?PlayerList}
	/*
		Create a list with all players
	*/
    	fun{RecursiveCreator ID Players Colors}
            case Players#Colors
            of (Kind|T1)#(Color|T2) then
                {PlayerManager.playerGenerator Kind Color ID}|{RecursiveCreator ID+1 T1 T2}
            else
                nil % Created all players
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
    		{Wait ID} {Wait Position}
            {Logger debug(statePlayer(id:ID position:Position))}
    		{Send GUIPORT initPlayer(ID Position)}
    		{InitPlayers T}
    	end
    end

	proc{LaunchGame}
	/*
		Launch the main game
		(Implemented like gym.Environment from OpenAI (reset, step): https://github.com/openai/gym)
	*/
        proc{Broadcast Message List}
        /*
            Broadcast the message {Message} to all players
        */
            case List
            of nil then
                {Logger debug(broadcast(Message))}
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
            if State.N.isAtSurface andthen {Not State.N.dead} then
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
                {Broadcast saySurface(Move_ID) PlayersList}
                {Send GUIPORT surface(Move_ID)}
                if Input.isTurnByTurn then % If it is turn by turn, change the state of the player: isAtSurface=true and timeRemaining=Input.turnSurface
                    NextPlayerState
                    in
                    NextPlayerState = {Record.adjoinList State.N [isAtSurface#true timeRemaining#Input.turnSurface]}
                    NextState = {Record.adjoinList State [N#NextPlayerState]}
                else % If it is simultaneous, sleep {Input.turnSurface} seconds
                    {Delay (1000*Input.turnSurface)}
                    {Send Player dive} % After sleeping, can dive
                    NextState = State
                end
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
                    proc{TreatMissileMessage MissileState PlayersToBroadcast N ?NextMissileState}
                        case PlayersToBroadcast
                        of nil then % No more player to treat
                            NextMissileState = MissileState
                        [] H|T then % Next player
                            IsPlayerDead
                            in
                            {Send H isDead(IsPlayerDead)} % Ask the player {H} if he is dead
                            {Wait IsPlayerDead}
                            if IsPlayerDead then % Check if is dead
                                NextMissileState = {TreatMissileMessage MissileState T N+1}
                            else
                                ReceivedMessage
                                in
                                {Send H sayMissileExplode(ID_Fire Position ReceivedMessage)}
                                {Wait ReceivedMessage}
                                {Logger debug(sayMissileExplode(position:Position message:ReceivedMessage))}
                                case ReceivedMessage
                                of null then % No damage for submarine {H}, continue
                                    NextMissileState = {TreatMissileMessage MissileState T N+1}
                                [] sayDeath(ID_Death) then % The submarine {ID_Death} is dead
                                    UpdatedPlayerState
                                    UpdatedMissileState
                                    Nplayer
                                    in
                                    Nplayer = ID_Death.id
                                    UpdatedPlayerState = {Record.adjoinList MissileState.Nplayer [dead#true]}
                                    {Logger debug(updatedPlayerState(UpdatedPlayerState))}
                                    {Broadcast sayDeath(ID_Death) PlayersList}
                                    {Send GUIPORT removePlayer(ID_Death)}
                                    {Logger debug(death_remove(ID_Death))}
                                    {Send SIMPORT sayDeath(ID_Death)}
                                    UpdatedMissileState = {Record.adjoinList MissileState [alives#MissileState.alives-1 Nplayer#UpdatedPlayerState]}
                                    {Logger debug(updatedMissileState(UpdatedMissileState))}
                                    NextMissileState = {TreatMissileMessage UpdatedMissileState T N+1}
                                [] sayDamageTaken(ID_Damage Damage LifeLeft) then % The submarine {ID_Damage} get {Damage} damage
                                    {Broadcast sayDamageTaken(ID_Damage Damage LifeLeft) PlayersList}
                                    {Send GUIPORT lifeUpdate(ID_Damage LifeLeft)}
                                    NextMissileState = {TreatMissileMessage MissileState T N+1}
                                else % Message not supported
                                    {Logger warning(warning(message:ReceivedMessage warn:'sayMissileExplode, received message not understood'))}
                                    NextMissileState = {TreatMissileMessage MissileState T N+1}
                                end
                            end
                        end
                    end
                    in
                    {Send GUIPORT explosion(ID_Fire Position)}
                    NextState = {TreatMissileMessage State PlayersList 1}
                [] mine(Position) then % Treat a placed mine
                    {Broadcast sayMinePlaced(ID_Fire) PlayersList}
                    {Send GUIPORT putMine(ID_Fire Position)}
                    NextState = State
                [] drone(Type Position) then
                    proc{TreatDroneMessage PlayersToBroadcast N}
                        case PlayersToBroadcast
                        of nil then % No more player to treat
                            skip
                        [] H|T then
                            IsPlayerDead
                            in
                            {Send H isDead(IsPlayerDead)}
                            {Wait IsPlayerDead}
                            if IsPlayerDead then
                                {TreatDroneMessage T N+1}
                            else
                                ID_Passing_Drone Is_Under_Drone
                                in
                                {Send H sayPassingDrone(drone(Type Position) ID_Passing_Drone Is_Under_Drone)} % Ask the player {H} if is under the drone
                                {Wait ID_Passing_Drone} {Wait Is_Under_Drone}
                                {Logger debug(isUnderDrone(player:ID_Passing_Drone isUnder:Is_Under_Drone drone:drone(Type Position)))}
                                {Send Player sayAnswerDrone(drone(Type Position) ID_Passing_Drone Is_Under_Drone)} % Tell the player {Player} if the player {H} is under the drone
                                {TreatDroneMessage T N+1} % Next player
                            end
                        end
                    end
                    in
                    case Type
                    of row then
                        if Position > Input.nRow then % Too big for the map
                            {Logger warning(warning(id:ID_Fire rowAsked:Position nRowMap:Input.nRow warn:'Row asked for a drone too big for the map'))}
                        else
                            {TreatDroneMessage PlayersList 1}
                            {Send GUIPORT Kind_Fire}
                        end
                    [] column then
                        if Position > Input.nColumn then % Too big for the map
                            {Logger warning(warning(id:ID_Fire columnAsked:Position nColumnMap:Input.nRow warn:'Column asked for a drone too big for the map'))}
                        else
                            {TreatDroneMessage PlayersList 1}
                            {Send GUIPORT Kind_Fire}
                        end
                    else
                        {Logger warning(warning(id:ID_Fire droneType:Type warn:'drone type not understood'))}
                    end
                    NextState = State
                [] sonar then
                    proc{TreatSonarMessage PlayersToBroadcast N}
                        case PlayersToBroadcast
                        of nil then % No more player to treat
                            skip
                        [] H|T then
                            IsPlayerDead
                            in
                            {Send H isDead(IsPlayerDead)}
                            {Wait IsPlayerDead}
                            if IsPlayerDead then
                                {TreatSonarMessage T N+1} % Next player
                            else
                                ID_Passing_Sonar Position_Sonar
                                in
                                {Send H sayPassingSonar(ID_Passing_Sonar Position_Sonar)} % Ask the player {H} for a sonar
                                {Wait ID_Passing_Sonar} {Wait Position_Sonar}
                                {Logger debug(sayPassingSonar(ID_Passing_Sonar Position_Sonar))}
                                {Send Player sayAnswerSonar(ID_Passing_Sonar Position_Sonar)} % Tell the player {Player} if the player {H} is under the drone
                                {TreatSonarMessage T N+1} % Next player
                            end
                        end
                    end
                    in
                    {TreatSonarMessage PlayersList 1}
                    NextState = State
                else
                    NextState = State
                end
            end
        end

        proc{TreatMine Player State ?NextState}
        /*
            Ask the player {Player} for firing a mine
        */
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
                    proc{TreatMineMessage MineState PlayersToBroadcast N ?NextMineState}
                        case PlayersToBroadcast
                        of nil then % No more player to treat
                            NextMineState = MineState
                        [] H|T then % Next player
                            if MineState.N.dead then
                                NextMineState = {TreatMineMessage MineState T N+1}
                            else
                                ReceivedMessage
                                in
                                {Send H sayMineExplode(ID Position ReceivedMessage)}
                                {Wait ReceivedMessage}
                                {Logger debug(sayMineExplode(position:Position message:ReceivedMessage))}
                                case ReceivedMessage
                                of null then % No damage for submarine {H}, continue
                                    NextMineState = {TreatMineMessage MineState T N+1}
                                [] sayDeath(ID_Death) then % The submarine {ID_Death} is dead
                                    UpdatedPlayerState
                                    UpdatedMineState
                                    Nplayer
                                    in
                                    Nplayer = ID_Death.id
                                    UpdatedPlayerState = {Record.adjoinList MineState.Nplayer [dead#true]}
                                    {Broadcast sayDeath(ID_Death) PlayersList}
                                    {Send GUIPORT removePlayer(ID_Death)}
                                    {Logger debug(death_remove(ID_Death))}
                                    {Send SIMPORT sayDeath(ID_Death)} % Update the simultaneous state
                                    UpdatedMineState = {Record.adjoinList MineState [alives#MineState.alives-1 Nplayer#UpdatedPlayerState]}
                                    {Logger debug(updatedMineState(UpdatedMineState))}
                                    NextMineState = {TreatMineMessage UpdatedMineState T N+1}
                                [] sayDamageTaken(ID_Damage Damage LifeLeft) then % The submarine {ID_Damage} get {Damage} damage
                                    {Broadcast sayDamageTaken(ID_Damage Damage LifeLeft) PlayersList}
                                    {Send GUIPORT lifeUpdate(ID_Damage LifeLeft)}
                                    NextMineState = {TreatMineMessage MineState T N+1}
                                else % Message not supported
                                    {Logger warning(warning(message:ReceivedMessage warn:'sayMineExplode, received message not understood'))}
                                    NextMineState = {TreatMineMessage MineState T N+1}
                                end
                            end
                        end
                    end
                    in
                    {Send GUIPORT removeMine(ID Position)}
                    /* {Send GUIPORT explosion(ID Position)} */
                    NextState = {TreatMineMessage State PlayersList 1}
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
            proc{Step List N Obs ?NextObs}
                case List
                of nil then % All players were treat
                    NextObs = Obs
                [] Player|T then % Treat the next player
                    if Obs.N.dead then
                        NextObs = {Step T N+1 Obs}
                    else
                        SurfaceState
                        in
                        SurfaceState = {TreatSurface Player N Obs}
                        if SurfaceState.N.isAtSurface then % The player number N is at surface
                            NextObs = {Step T N+1 SurfaceState}
                        else % The player number N is not at surface so continue
                            DirectionState
                            in
                            % Treat the direction of the submarine
                            DirectionState = {TreatDirection Player N SurfaceState}
                            {Logger debug(direction(DirectionState))}
                            % If the direction is surface, return the state
                            if DirectionState.N.isAtSurface then
                                NextObs = {Step T N+1 DirectionState}
                            else
                                FireState
                                MineState
                                in
                                % Charge item
                                {TreatCharge Player}

                                % The submarine is authorized to fire an item
                                FireState = {TreatFire Player DirectionState}
                                {Logger debug(fire(player:N state:FireState))}

                                % The submarine is authorized to explode a mine
                                MineState = {TreatMine Player FireState}
                                {Logger debug(mine(MineState))}
                                NextObs = {Step T N+1 MineState}
                            end
                        end
                    end
                end
            end
            NextState
        in
            NextState = {Step PlayersList 1 State}
            {Logger debug(nextState(NextState))}
            if (NextState.alives > 1) then % More than 1 player still alive, continue
                {LoopTurnByTurn NextState}
            else % Game finished
                {Logger debug('Game over.')}
            end
        end

        proc{LoopSimultaneous State}
        /*
         Handle the simultaneous game
        */

            proc{SimulateThinking} {Delay Input.thinkMin + ({OS.rand} mod (Input.thinkMax - Input.thinkMin))} end
            /* proc{SimulateThinking} {Delay 5} end */

            proc{Step Player N Obs}
                Answer
                SurfaceState
                DirectionState
                FireState
                MineState
                in

                SurfaceState = {TreatSurface Player N Obs}

                {SimulateThinking}

                % Treat the direction of the submarine
                DirectionState = {TreatDirection Player N SurfaceState}
                {Logger debug(direction(DirectionState))}

                {SimulateThinking}

                % Charge item
                {TreatCharge Player}
                {SimulateThinking}

                % The submarine is authorized to fire an item
                FireState = {TreatFire Player DirectionState}
                {Logger debug(fire(FireState))}
                {SimulateThinking}

                % The submarine is authorized to explode a mine
                MineState = {TreatMine Player FireState}
                {SimulateThinking}
                {Logger debug(mine(MineState))}

                {Send SIMPORT isTerminated(N Answer)}
                {Wait Answer}
                if {Not Answer} then {Step Player N MineState} end
            end

            proc{LaunchEachThread List Obs N}
                case List
                of nil then % No more player
                    skip
                [] Player|T then
                    thread
                        {Step Player N Obs} % WOUHOU
                    end
                    {LaunchEachThread T Obs N+1} % Launch next player thread
                end
            end

            proc{SynchroEndGame Stream GameState}
                case Stream
                of sayDeath(ID)|T then
                    UpdatedPlayerState
                    UpdatedGameState
                    N
                    in
                    N = ID.id
                    UpdatedPlayerState = {Record.adjoinList GameState.N [dead#true]}
                    UpdatedGameState = {Record.adjoinList GameState [alives#GameState.alives-1 N#UpdatedPlayerState]}
                    {SynchroEndGame T UpdatedGameState}
                [] get(EndGame)|T then
                    EndGame = GameState.alives < 2
                    {SynchroEndGame T GameState}
                [] getState(State)|T then
                    State = GameState
                    {SynchroEndGame T GameState}
                [] amIDead(N ?Answer)|T then
                    Answer = GameState.N.dead
                    {SynchroEndGame T GameState}
                [] isTerminated(N ?Answer)|T then
                    Answer = GameState.N.dead orelse GameState.alives < 2
                    {SynchroEndGame T GameState}
                [] H|T then
                    {Logger warning(warning(warn:'message not understood in simultaneous stream handler' message:H))}
                    {SynchroEndGame T GameState}
                end
            end
        in
            thread {SynchroEndGame SimStream State} end % Used to know the end of the game
            {LaunchEachThread PlayersList State 1} % Launch a thread for each player
        end

        FirstState
   in
        FirstState = {Reset}
        SIMPORT = {Port.new SimStream}
        if (Input.isTurnByTurn) then
            {LoopTurnByTurn FirstState}
        else
            {LoopSimultaneous FirstState}
            {Logger debug('Game over.')}
        end
        /* {Application exit(0)} */
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

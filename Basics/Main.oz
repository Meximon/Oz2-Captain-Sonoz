functor
import
    GUI
    Input
    PlayerManager
    System

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

        % TODO
        proc{TreatCharge Player}
            ID_Item Kind_Item
            in
            {Send Player chargeItem(ID_Item Kind_Item)}
            if ID_Item == null andthen Kind_Item == null then
                skip
            else
                {Broadcast sayCharge(ID_Item Kind_Item) PlayersList}
            end
        end

        % TODO
        fun{TreatFire Player N State}
            {Logger err('TreatFire not implemented yet.')}
            State
        end

        % TODO
        fun{TreatMine Player N State}
            {Logger err('TreatMine not implemented yet.')}
            State
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
                [] Player|T then
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
                            FireState = {TreatFire Player N DirectionState}

                            % The submarine is authorized to explode a mine
                            MineState = {TreatMine Player N FireState}
                            NextObs = {Loop T N+1 MineState}
                        end
                    end
                end
            end
            NextState
        in
            NextState = {Loop PlayersList 1 State}
            {Logger debug(NextState)}
            if (NextState.alives > 1) then
                {LoopTurnByTurn NextState}
            end
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

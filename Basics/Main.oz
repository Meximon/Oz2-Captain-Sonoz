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
        FirstState
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
             {Record.AdjoinList {RecursiveReset 1 gameState()} [alives#Input.nbPlayers]}
       	end

          proc{LoopTurnByTurn State}
          /*
             Handle the turn by turn game
          */
             {Logger err('Not implemented')}
          end
          proc{LoopSimultaneous State}
          /*
             Handle the simultaneous game
          */
             {Logger err('Not implemented')}
          end
   in
        FirstState = {Reset}
        if (Input.isTurnByTurn) then
        %{LoopTurnByTurn FirstState}
        	{Logger err('Turn by turn game not implemented yet.')}
        else
        %{LoopSimultaneous FirstState}
        	{Logger err('Simulatneous game not implemented yet.')}
        end
    end

    proc{Iterate List}
        case List of nil then
            skip
        [] H|T then
            {Logger debug('element : '#H)}
            {Iterate T}
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
end

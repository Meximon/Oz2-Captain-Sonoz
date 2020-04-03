functor
import
	Input
	Player1
	Player2
	Player
	PlayerBasicAI
export
	playerGenerator:PlayerGenerator
define
	PlayerGenerator
	Logger = Input.logger
in
	fun{PlayerGenerator Kind Color ID}
		case Kind
		of player2 then {Player2.portPlayer Color ID}
		[] player1 then {Player1.portPlayer Color ID}
		[] player  then {Player.portPlayer Color ID}
		[] playerBasicAi then {PlayerBasicAI.portPlayer Color ID}
		else
			{Logger warning('No player corresponding to '#Kind)}
			nil
		end
	end
end
